import os
import re
import json
import random
import logging
import requests
from datetime import timedelta, timezone, datetime
from flask import Flask, jsonify, request, g
from flask_cors import CORS
from pydantic import ValidationError
from firebase_admin import messaging
import firebase_admin
from firebase_admin import credentials as firebase_credentials
from supabase import create_client, Client
from redis.exceptions import LockNotOwnedError, LockError
from backend.token_manager import TokenManager
from backend.repository import UserRepository, ReminderRepository, RateLimitRepository, AchievementRepository, WorkoutRepository, PremiumPerksRepository
from backend.services import ProgressionService, FoodService, POIService, SnapshotService
from backend.services.workout_service import WorkoutService
from backend.schemas import (
    DailyRewardResponse,
    ProgressResponse,
    UpdateUsernameRequest,
    UpdateUsernameResponse,
    SearchFoodRequest,
    GetFoodDetailRequest,
    NearbyPOIRequest,
    NearbyPOIResponse,
    POIItem,
    CheckInPOIRequest,
    CheckInPOIResponse,
    GetUserDataResponse,
    UpdatePfpRequest,
    UpdateAppColorRequest,
    UpdateNotificationsRequest,
    UpdateUnitsRequest,
    AddFcmTokenRequest,
    RemoveFcmTokenRequest,
    UpsertFoodLogRequest,
    UpsertFoodLogV2Request,
    UpsertWaterLogRequest,
    UpsertWeightLogRequest,
    DeleteWeightLogRequest,
    SimpleSuccessResponse,
    GetLeaderboardResponse,
    LeaderboardUserEntry,
    SetReminderRequest,
    ReminderItem,
    GetRemindersResponse,
    FoodLogItem,
    GetFoodLogsV2Response,
    WaterLogItem,
    GetWaterLogsResponse,
    WeightLogItem,
    GetWeightLogsResponse,
    DeleteReminderRequest,
    GetAchievementsResponse,
    AchievementProgressEntry,
    AchievementClaimEntry,
    ClaimAchievementRequest,
    ClaimTrivialAchievementRequest,
    UpdateUtcOffsetRequest,
    UpdateGoalsRequest,
    UpdateNutritionGoalsRequest,
    UpdateWeightGoalRequest,
    UpdateWaterGoalRequest,
    UpdateWeeklyWorkoutsGoalRequest,
    GetStreaksResponse,
    StreakEntry,
    AchievementDefItem,
    ReferralCodeResponse,
    UseReferralRequest,
    UseReferralResponse,
    ClaimReferralRewardRequest,
    ClaimReferralRewardResponse,
    SearchExercisesResponse,
    LogWorkoutRequest,
    LogWorkoutResponse,
    GetRecentWorkoutsResponse,
    GetWeeklyWorkoutCountResponse,
    GetTodayOverviewResponse,
    GetWorkoutHeatmapResponse,
    HeatmapDay,
    RecentWorkoutItem,
    RecentExerciseItem,
    GetRecentExercisesResponse,
    CreateCustomExerciseRequest,
    CreateCustomExerciseResponse,
    EditCustomExerciseRequest,
    DeleteCustomExerciseRequest,
    CreateRoutineRequest,
    CreateRoutineResponse,
    GetEveryPrevSetRequest,
    PrevSetItem,
    GetEveryPrevSetResponse,
    ExerciseStatItem,
    GetExerciseStatsResponse,
    CopyRoutineRequest,
    DeleteRoutineRequest,
    LikeRoutineRequest,
    UnlikeRoutineRequest,
    GetMyRoutinesResponse,
    MyRoutineItem,
    MyRoutineExerciseItem,
    BrowseRoutineItem,
    GetBrowseRoutinesResponse,
    VerifyPurchaseRequest,
    PremiumStatusResponse,
    PremiumPerksResponse,
    UseShieldResponse,
)
from backend.auth import verify_token
from backend.valid_achievements import TRIVIAL_ACHIEVEMENT_IDS, ACHIEVEMENT_DEFINITIONS
from backend.utils import utc_minute_of_day, find_utc_midnight_offset_mins
from backend.redis_cache import FOOD_CACHE_TTL, redis
from google.oauth2 import service_account
from googleapiclient.discovery import build as google_build

logger = logging.getLogger(__name__)

# Get the environmental variables from Render
CLIENT_ID = os.environ.get("CLIENT_ID")
CLIENT_SECRET = os.environ.get("CLIENT_SECRET")
MAX_TOKENS = int(os.getenv("MAX_TOKENS", "5000"))

# Set up Supabase
supabase_client = create_client(os.environ.get("SUPABASE_URL"), os.environ.get("SUPABASE_KEY"))

# TokenManager reads/writes rate_limits via Supabase Postgres
token_manager = TokenManager(supabase_client)

# Initialize the repository and service layers, passing Supabase to each repository so it can read / write data
user_repo = UserRepository(supabase_client)
reminder_repo = ReminderRepository(supabase_client)
rate_limit_repo = RateLimitRepository(supabase_client)
achievement_repo = AchievementRepository(supabase_client)

progression_service = ProgressionService(user_repo, reminder_repo, achievement_repo)
food_service = FoodService(token_manager, rate_limit_repo, CLIENT_ID, CLIENT_SECRET)
poi_service = POIService()
snapshot_service = SnapshotService(user_repo)
workout_repo = WorkoutRepository(supabase_client)
workout_service = WorkoutService(workout_repo)
premium_perks_repo = PremiumPerksRepository(supabase_client)

# Initialize Firebase Admin SDK for FCM (for notifications)
if not firebase_admin._apps:
    firebase_cred = firebase_credentials.Certificate(json.loads(os.environ.get("FIREBASE_SERVICE_ACCOUNT")))
    firebase_admin.initialize_app(firebase_cred)

app = Flask(__name__)
CORS(app) # allow requests from desktop device browsers

# Logs every request with the uid and status code for debugging user-specific issues in Render logs
@app.after_request
def log_request(response):
    uid = getattr(g, 'uid', 'unauthenticated')
    logger.info(f"[{request.method}] {request.path} uid={uid} status={response.status_code}")
    return response

@app.after_request # runs after every request
# This method adds CORS headers even when responses are unsuccessful to prevent CORS errors when trying to debug
def add_cors_headers(response):
    origin = request.headers.get('Origin')
    if origin == 'https://nicholasdakis.github.io' or (origin and origin.startswith('http://localhost')):
        response.headers['Access-Control-Allow-Origin'] = origin
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type,Authorization'
    response.headers['Access-Control-Allow-Methods'] = 'GET,POST,OPTIONS'
    return response

def _get_token():
    auth = request.headers.get("Authorization", "")  # e.g. "Bearer 12345..."
    if not auth.startswith("Bearer "):  # reject if header is missing or malformed
        return None, (jsonify({"error": "Missing or invalid Authorization header"}), 401)
    return auth.removeprefix("Bearer ").strip(), None  # strip the "Bearer " prefix to get the raw token

def _parse_body(schema):
    try:
        return schema(**request.get_json(force=True)), None
    except (ValidationError, TypeError) as e:
        return None, (jsonify({"error": "Invalid request", "details": str(e)}), 400)

def _try_verify_token(id_token: str):
    try:
        return verify_token(id_token), None  # (uid, no error)
    except ValueError as e:
        return None, (jsonify({"error": str(e)}), 401)  # (no uid, 401 error response)

def _parse_and_auth(schema=None):
    token, err = _get_token()
    if err:
        return None, None, err

    body = None
    if schema is not None:
        body, err = _parse_body(schema)
        if err:
            return None, None, err

    uid, err = _try_verify_token(token)
    if err:
        return None, None, err
    g.uid = uid  # stored so after_request can log it for every route
    return uid, body, None

def send_due_reminders():
    try:
        now_dt = datetime.now(timezone.utc)
        logger.info(f'[reminders] Checking for due reminders at {now_dt.isoformat()}')

        # Query the reminders table for all rows where the time is due (i.e. time <= now)
        due_reminders = reminder_repo.get_due_reminders(now_dt.isoformat())

        count = 0
        for reminder in due_reminders:
            reminder_id = reminder["id"]
            uid = reminder["uid"]

            # Atomically claim the reminder by deleting it, so skip if another instance already claimed it
            if not reminder_repo.delete_reminder(reminder_id):
                # Another instance already deleted/claimed this reminder, skip it
                logger.info(f'[reminders] Reminder {reminder_id} already claimed by another instance, skipping')
                continue

            count += 1

            # Get the user's FCM tokens from the users table
            fcm_tokens = user_repo.get_user_fcm_tokens(uid)
            if fcm_tokens is None:
                # User no longer exists, reminder already deleted above so just move on
                continue

            # If empty, the user has no devices to notify
            if not fcm_tokens:
                continue

            # Send a notification + data payload so browsers show it even when minimized
            message = messaging.MulticastMessage(
                notification=messaging.Notification(
                    title="Level Up! Reminder",
                    body=reminder.get('message', 'You have a reminder!')
                ),
                data={
                    'body': reminder.get('message', 'You have a reminder!'),
                    'reminderId': reminder_id
                },
                tokens=fcm_tokens,
            )
            response = messaging.send_each_for_multicast(message)
            logger.info(f'[reminders] Sent to {uid}: success={response.success_count}, failure={response.failure_count}')

            # Clean up tokens with unregistered / invalid error codes (e.g. user uninstalled the app or revoked permissions)
            if response.failure_count > 0:
                invalid_tokens = []
                for i, res in enumerate(response.responses):
                    if not res.success and res.exception:
                        code = getattr(res.exception, 'code', None)
                        logger.warning(f'[reminders] Token {i} failed: code={code} error={res.exception}')
                        if code in (
                            'NOT_FOUND',
                            'registration-token-not-registered',
                            'invalid-registration-token',
                        ):
                            invalid_tokens.append(fcm_tokens[i])
                # Remove each invalid token atomically so no valid tokens are accidentally wiped
                for token in invalid_tokens:
                    user_repo.remove_fcm_token(uid, token)

        if count == 0:
            logger.info('[reminders] No due reminders found')

    except Exception as e:
        logger.exception(f'Error sending reminders: {e}')

MIN_APP_VERSION = "1.2.0"

@app.route("/app_config")
def app_config():
    return jsonify({"min_version": MIN_APP_VERSION}), 200

@app.route("/ping")
def ping():
    return jsonify({
        "message": "Pinged."
    }), 200

# Checks if a user exists in Supabase by email before Google Sign-In
# This allows TOS enforcement without ever touching Firebase Auth for new users
@app.route("/check_user_email_exists", methods=["POST"])
def check_user_exists():
    data = request.get_json()
    if not data or 'email' not in data:
        return jsonify({"error": "Missing email"}), 400
    email = data['email']
    exists = user_repo.user_exists_by_email(email)
    return jsonify({"exists": exists}), 200

# Route called by the CRON job every 30 minutes
@app.route("/daily_snapshot")
def trigger_snapshot():
    # Only the CRON job has access
    secret = request.args.get("key") or request.headers.get("X-Cron-Key")
    if secret != os.environ.get("CRON_SECRET"):
        return jsonify({"error": "Unauthorized"}), 401

    utc_min = utc_minute_of_day()
    target = find_utc_midnight_offset_mins(utc_min) # compared with stored user utc offsets

    # Run the snapshot build for -utc_min with the buffers included
    count = snapshot_service.run(list(target))

    return jsonify({"success": True, "count": count}), 200

# Route accessed by the CRON JOB once per minute
@app.route("/send_reminders")
def trigger_reminders():
    # Only the CRON-JOB can trigger the route
    secret = request.args.get("key") or request.headers.get("X-Cron-Key")
    expected = os.environ.get("CRON_SECRET")
    if not expected or secret != expected:
        return jsonify({"error": "Unauthorized"}), 401
    send_due_reminders()
    return jsonify({"message": "Reminders checked."}), 200

@app.route("/food", methods=["POST"])
def get_food():
    # Validate request body with the Pydantic schema
    uid, body, err = _parse_and_auth(SearchFoodRequest)
    if err:
        return err

    # Normalize the food name to reduce redundant API calls
    food_name = re.sub(r'\s+', ' ', body.food_name.lower()).strip()
    cache_key = f"food:{food_name}"

    # First, check the cache
    try:
        cached = redis.get(cache_key)
        if cached:
            redis.incr("cache_hits")
            # Return the cached food as a json as expected
            return jsonify(json.loads(cached))

    except Exception as e: # Prints exception and continues with the API call as fallback
        logger.warning(f"[Redis Error]: {e}")
    
    # Lock to prevent race conditions and redundant API calls
    # The timeout is to prevent the lock from being stuck if the server crashes
    # The blocking_timeout is to prevent a pileup of many workers from waiting for the lock, instead giving an error
    lock_timeout_seconds = 10
    try:
        with redis.lock(f"lock:food:{food_name}", timeout=lock_timeout_seconds, blocking_timeout=5): # The locks are per-key so only one worker for that exact food query can call the API at a time
            # Re-check cache after acquiring the lock because another worker may have
            # already populated it while this request was waiting on the lock
            try:
                cached = redis.get(cache_key)
                if cached:
                    redis.incr("cache_hits")
                    return jsonify(json.loads(cached))
            except Exception as e:
                logger.warning(f"[Redis Error]: {e}")

            # Not in cache and lock is active, so use the fatSecret API
            if not token_manager.consume():
                # Retrieve the next reset time
                reset_time = food_service.get_next_reset_time()
                if reset_time is None:
                    return jsonify({
                        "error": "Token limit exceeded",
                        "message": "No reset time available"
                    }), 500
            
                # Calculate time until next reset
                time_left = reset_time - datetime.now(timezone.utc)
                return jsonify({
                    "error": "Token limit exceeded",
                    "next_reset_time": reset_time.isoformat(),
                    "time_left": str(time_left)  # Converted to string for JSON serializable
                }), 429
        
            # Call FatSecret API if tokens are available, refunding tokens upon failure
            try:
                api_response = food_service.call_fatsecret(food_name, lock_timeout_seconds - 1)
            except RuntimeError as e:
                return jsonify({"error": str(e)}), 500

            try:
                # Add the response into the cache
                redis.setex(cache_key, FOOD_CACHE_TTL, api_response.text) # foods are stored for 30 days before expiring
                redis.incr("cache_misses")

                # Return the jsonified response from the API
                return jsonify(api_response.json())
            except ValueError:
                token_manager.refund()  # Give back token on invalid JSON
                return jsonify({"error": "Invalid JSON from FatSecret API", "raw": api_response.text})

    except (LockNotOwnedError, LockError):
        return jsonify({"error": "Server busy, try again"}), 503
    except Exception:
        return jsonify({"error": "Internal server error"}), 500

@app.route("/food_detail", methods=["POST"])
def get_food_detail():
    uid, body, err = _parse_and_auth(GetFoodDetailRequest)
    if err:
        return err

    cache_key = f"food_detail:{body.food_id}"
    try:
        cached = redis.get(cache_key)
        if cached:
            redis.incr("cache_hits")
            return jsonify(json.loads(cached))
    except Exception as e:
        logger.warning(f"[Redis Error]: {e}")

    try:
        api_response = food_service.get_food_detail(body.food_id, timeout=9)
    except RuntimeError as e:
        return jsonify({"error": str(e)}), 500

    try:
        redis.setex(cache_key, FOOD_CACHE_TTL, api_response.text)
        redis.incr("cache_misses")
        return jsonify(api_response.json())
    except ValueError:
        return jsonify({"error": "Invalid JSON from FatSecret API", "raw": api_response.text}), 500

@app.route("/update_goals", methods=["POST"])
def update_goals():
    # Step 1: Validate request body and verify the user's identity
    uid, body, err = _parse_and_auth(UpdateGoalsRequest)
    if err:
        return err

    # Step 2: Update goals through service layer (upsert behavior)
    result = progression_service.update_goals(
        uid=uid,
        calories_goal=body.calories_goal,
        protein_goal=body.protein_goal,
        carbs_goal=body.carbs_goal,
        fat_goal=body.fat_goal,
        weight_goal_type=body.weight_goal_type,
        weekly_workouts_goal=body.weekly_workouts_goal,
    )

    # Step 3: Return updated state
    return jsonify({
        "success": True,
        "goals": result
    }), 200

@app.route("/update_nutrition_goals", methods=["POST"])
def update_nutrition_goals():
    uid, body, err = _parse_and_auth(UpdateNutritionGoalsRequest)
    if err:
        return err
    result = progression_service.update_nutrition_goals(
        uid=uid,
        calories_goal=body.calories_goal,
        protein_goal=body.protein_goal,
        carbs_goal=body.carbs_goal,
        fat_goal=body.fat_goal,
    )
    return jsonify(result), 200

@app.route("/update_weight_goal", methods=["POST"])
def update_weight_goal():
    uid, body, err = _parse_and_auth(UpdateWeightGoalRequest)
    if err:
        return err
    result = progression_service.update_weight_goal(
        uid=uid,
        weight_goal_type=body.weight_goal_type,
        weight_kg_goal=body.weight_kg_goal,
    )
    return jsonify(result), 200

@app.route("/update_water_goal", methods=["POST"])
def update_water_goal():
    uid, body, err = _parse_and_auth(UpdateWaterGoalRequest)
    if err:
        return err
    result = progression_service.update_water_goal(
        uid=uid,
        water_ml_goal=body.water_ml_goal,
    )
    return jsonify(result), 200

@app.route("/update_weekly_workouts_goal", methods=["POST"])
def update_weekly_workouts_goal():
    uid, body, err = _parse_and_auth(UpdateWeeklyWorkoutsGoalRequest)
    if err:
        return err
    result = progression_service.update_weekly_workouts_goal(
        uid=uid,
        weekly_workouts_goal=body.weekly_workouts_goal,
    )
    return jsonify(result), 200

@app.route("/get_nearby_pois", methods=["POST"])
def get_nearby_pois():
    # Step 1: Validate request body and verify the user's identity
    uid, body, err = _parse_and_auth(NearbyPOIRequest)
    if err:
        return err

    # Step 2: Reject the request if the user has moved too fast too quickly
    # in comparison to their previous POI request
    if progression_service.is_moving_too_fast_for_poi(uid, body.lat, body.lng):
        return jsonify({
            "error": "Moving too far too quickly. Please try again.",
            "code": "moving_too_fast",
        }), 429

    # Step 3: Fetch POIs from the Overpass API
    data = poi_service.fetch_pois(body.lat, body.lng)
    if data is None:
        return jsonify({"error": "overpass_unavailable"}), 503

    # Step 4: Parse the raw Overpass data into POI objects
    all_pois = poi_service.parse_overpass_response(data)

    # Step 5: If there are more than 20 POIs found, a random subset of the 20 are shown
    if len(all_pois) > 20:
        all_pois = random.sample(all_pois, 20)

    # Step 6: Build and return the validated response
    response = NearbyPOIResponse(pois=all_pois)
    return jsonify(response.model_dump()), 200

@app.route("/generate_fake_pois", methods=["POST"])
def get_fake_pois():
    _, body, err = _parse_and_auth(NearbyPOIRequest)
    if err:
        return err

    pois = poi_service.generate_fake_pois(body.lat, body.lng)
    response = NearbyPOIResponse(pois=pois)
    return jsonify(response.model_dump()), 200

@app.route("/check_in_poi", methods=["POST"])
def check_in_poi():
    # Step 1: Validate request body and verify the user's identity
    uid, body, err = _parse_and_auth(CheckInPOIRequest)
    if err:
        return err

    # Step 2: Run the check-in through the service layer
    result = progression_service.check_in_poi(
        uid,
        body.poi_name,
        body.poi_category,
        body.poi_lat,
        body.poi_lng,
        body.user_lat,
        body.user_lng,
    )

    # Step 3: Build and return the validated response
    response = CheckInPOIResponse(**result)
    status = 200 if result["success"] else 409 # 409 = conflict
    return jsonify(response.model_dump()), status

@app.route("/update_username", methods=["POST"])
def update_username():
    # Step 1: Validate request body and verify the user's identity
    uid, body, err = _parse_and_auth(UpdateUsernameRequest)
    if err:
        return err

    # Step 2: The service calculates if the update is valid, and the repository (in the service) reads Postgres atomically
    result = progression_service.update_username(uid, body.username) # Returns a dict, and update_username is successful if the uniqueness check passes

    # Step 3: Build the expected response schema
    response = UpdateUsernameResponse(
        success=result["success"],
        error=result.get("error"), # .get to safely return if the error is None
    )
    
    if not result["success"]:
        return jsonify(response.model_dump()), 409 # The update was unsuccessful since success = False, so give a separate response
    return jsonify(response.model_dump()), 200 # model_dump() converts the Pydantic model to a dict for jsonify, because jsonify only accepts plain dicts

@app.route("/claim_daily_reward", methods=["POST"])
def claim_daily_reward():
    # Step 1: Validate request body and verify the user's identity
    uid, _, err = _parse_and_auth()
    if err:
        return err

    # Step 2: The service calculates XP and level-ups, and the repository (in the service) writes to Postgres atomically
    result = progression_service.claim_daily_reward(uid)

    # Step 3: Build the expected response schema
    response = DailyRewardResponse(
        claimed=result["claimed"],
        xp_gained=result["xp_gained"],
        base_xp=result.get("base_xp", result["xp_gained"]),
        new_level=result["new_level"],
        new_exp=result["new_exp"],
        seconds_remaining=result["seconds_remaining"],
        daily_streak=result.get("daily_streak", 0),
        streak_multiplier=result.get("streak_multiplier", 1.0),
    )

    return jsonify(response.model_dump()), 200 # model_dump() converts the Pydantic model to a dict for jsonify, because jsonify only accepts plain dicts


@app.route("/progress", methods=["GET"])
def get_progress():
    # Step 1: Verify the user's identity from the Authorization header
    uid, _, err = _parse_and_auth()
    if err:
        return err

    # Step 2: Fetch the user's current state through the service layer
    result = progression_service.get_progress(uid)

    # Step 3: Return validated response
    response = ProgressResponse(**result)
    return jsonify(response.model_dump()), 200

@app.route("/user_data", methods=["GET"])
def get_user_data():
    uid, _, err = _parse_and_auth()
    if err:
        return err

    # Extract email from the Firebase token to store on new user creation
    from firebase_admin import auth as fb_auth
    token, _ = _get_token()
    try:
        decoded = fb_auth.verify_id_token(token)
        email = decoded.get("email")
    except Exception:
        email = None

    result = progression_service.get_user_data(uid, email=email)
    response = GetUserDataResponse(**result)
    return jsonify(response.model_dump()), 200

@app.route("/streaks", methods=["GET"])
def get_streaks():
    # Step 1: Verify the user's identity from the Authorization header
    uid, _, err = _parse_and_auth()
    if err:
        return err

    # Step 2: Fetch all streaks for the user through the service layer
    result = progression_service.get_streaks(uid)

    # Step 3: Build and return the validated response
    response = GetStreaksResponse(streaks=[StreakEntry(**s) for s in result])
    return jsonify(response.model_dump()), 200

@app.route("/update_pfp", methods=["POST"])
def update_pfp():
    # Method that updates the user's profile picture, stored as a Base64 string
    uid, body, err = _parse_and_auth(UpdatePfpRequest)
    if err:
        return err

    # 200 KB base64 limit (~150 KB raw image)
    if len(body.pfp_base64) > 200 * 1024:
        return jsonify({"error": "Image too large"}), 413

    progression_service.update_pfp(uid, body.pfp_base64)
    return jsonify(SimpleSuccessResponse(success=True).model_dump()), 200


@app.route("/update_app_color", methods=["POST"])
def update_app_color():
    # Method that updates the user's app theme color, stored as an ARGB integer
    uid, body, err = _parse_and_auth(UpdateAppColorRequest)
    if err:
        return err

    progression_service.update_app_color(uid, body.app_color)
    return jsonify(SimpleSuccessResponse(success=True).model_dump()), 200

@app.route("/update_utc_offset_minutes", methods=["POST"])
def update_utc_offset_minutes():
    uid, body, err = _parse_and_auth(UpdateUtcOffsetRequest)
    if err:
        return err
    progression_service.update_utc_offset_minutes(uid, body.utc_offset)
    return jsonify(SimpleSuccessResponse(success=True).model_dump()), 200

@app.route("/update_notifications", methods=["POST"])
def update_notifications():
    # Method that updates whether the user has notifications enabled
    uid, body, err = _parse_and_auth(UpdateNotificationsRequest)
    if err:
        return err

    progression_service.update_notifications_enabled(uid, body.enabled)
    return jsonify(SimpleSuccessResponse(success=True).model_dump()), 200

@app.route("/update_units", methods=["POST"])
def update_units():
    uid, body, err = _parse_and_auth(UpdateUnitsRequest)
    if err:
        return err
    progression_service.update_units(uid, body.units)
    return jsonify(SimpleSuccessResponse(success=True).model_dump()), 200


@app.route("/add_fcm_token", methods=["POST"])
def add_fcm_token():
    # Method that adds an FCM token to the user's token list for push notifications, ignoring duplicates
    uid, body, err = _parse_and_auth(AddFcmTokenRequest)
    if err:
        return err

    progression_service.add_fcm_token(uid, body.token)
    return jsonify(SimpleSuccessResponse(success=True).model_dump()), 200


@app.route("/remove_fcm_token", methods=["POST"])
def remove_fcm_token():
    # Method that removes an FCM token from the user's token list, called on logout
    uid, body, err = _parse_and_auth(RemoveFcmTokenRequest)
    if err:
        return err

    progression_service.remove_fcm_token(uid, body.token)
    return jsonify(SimpleSuccessResponse(success=True).model_dump()), 200


# kept for users on older app versions that still write to the old food_logs table, remove after forced update
@app.route("/upsert_food_log", methods=["POST"])
def upsert_food_log():
    # Method that inserts or updates a food log entry for a specific date
    uid, body, err = _parse_and_auth(UpsertFoodLogRequest)
    if err:
        return err

    progression_service.upsert_food_log(
        uid, body.date, body.breakfast, body.lunch, body.dinner, body.snack
    )
    return jsonify(SimpleSuccessResponse(success=True).model_dump()), 200

@app.route("/upsert_food_log_v2", methods=["POST"])
def upsert_food_log_v2():
    uid, body, err = _parse_and_auth(UpsertFoodLogV2Request)
    if err:
        return err
    results = progression_service.upsert_food_log_v2(uid, body.date, body.items)
    return jsonify({"success": True, "items": results}), 200

@app.route("/upsert_water_log", methods=["POST"])
def upsert_water_log():
    uid, body, err = _parse_and_auth(UpsertWaterLogRequest)
    if err:
        return err
    progression_service.upsert_water_log(uid, body.date, body.entries_ml)
    return jsonify(SimpleSuccessResponse(success=True).model_dump()), 200

@app.route("/upsert_weight_log", methods=["POST"])
def upsert_weight_log():
    uid, body, err = _parse_and_auth(UpsertWeightLogRequest)
    if err:
        return err
    progression_service.upsert_weight_log(uid, body.date, body.weight_kg)
    return jsonify(SimpleSuccessResponse(success=True).model_dump()), 200

@app.route("/delete_weight_log", methods=["POST"])
def delete_weight_log():
    uid, body, err = _parse_and_auth(DeleteWeightLogRequest)
    if err:
        return err
    progression_service.delete_weight_log(uid, body.date)
    return jsonify(SimpleSuccessResponse(success=True).model_dump()), 200

@app.route("/leaderboard", methods=["GET"])
def get_leaderboard():
    _, _, err = _parse_and_auth()
    if err:
        return err

    type_ = request.args.get("type", "xp")
    period = request.args.get("period", "all_time")

    result = progression_service.get_leaderboard(type=type_, period=period)
    response = GetLeaderboardResponse(
        users=[LeaderboardUserEntry(**entry) for entry in result]
    )
    return jsonify(response.model_dump()), 200

@app.route("/leaderboard_standing", methods=["GET"])
def get_leaderboard_standing():
    uid, _, err = _parse_and_auth()
    if err:
        return err

    type_ = request.args.get("type", "xp")
    result = progression_service.get_leaderboard_standing(uid, type=type_)
    if result is None:
        return jsonify({"error": "User not found"}), 404

    return jsonify(result), 200

@app.route("/set_reminder", methods=["POST"])  # Endpoint to create a new reminder
def set_reminder():
    # Parse JSON body into Pydantic schema and verify Firebase ID token
    uid, body, err = _parse_and_auth(SetReminderRequest)
    if err:
        return err

    # Pass validated, trusted data into business logic
    progression_service.set_reminder(
        uid=uid,
        message=body.message,
        scheduled_at=body.scheduled_at,
        notification_id=body.notification_id,
    )

    return jsonify({"success": True}), 200

@app.route("/reminders", methods=["GET"])
def get_reminders():
    uid, _, err = _parse_and_auth()
    if err:
        return err

    result = progression_service.get_reminders(uid=uid)
    reminders = [ReminderItem(**r) for r in result]
    response = GetRemindersResponse(reminders=reminders)
    return jsonify(response.model_dump()), 200

# TODO: once old app versions are gone, remove food_logs_v2 from the /user_data response and rely solely on this endpoint
@app.route("/food_logs_v2", methods=["GET"])
def get_food_logs_v2():
    uid, _, err = _parse_and_auth()
    if err:
        return err
    # TODO: step 3 of analytics gate migration: after client-side gate ships and MIN_APP_VERSION is bumped, switch to get_food_logs_v2_gated with a 14-day cutoff for free users
    logs = progression_service.get_food_logs_v2(uid=uid)
    response = GetFoodLogsV2Response(food_logs_v2=[FoodLogItem(**l) for l in logs])
    return jsonify(response.model_dump()), 200

@app.route("/water_logs", methods=["GET"])
def get_water_logs():
    uid, _, err = _parse_and_auth()
    if err:
        return err
    # TODO: step 3 of analytics gate migration: after client-side gate ships and MIN_APP_VERSION is bumped, switch to get_water_logs_gated with a 14-day cutoff for free users
    logs = progression_service.get_water_logs(uid=uid)
    response = GetWaterLogsResponse(water_logs=[WaterLogItem(**l) for l in logs])
    return jsonify(response.model_dump()), 200

@app.route("/weight_logs", methods=["GET"])
def get_weight_logs():
    uid, _, err = _parse_and_auth()
    if err:
        return err
    # TODO: step 3 of analytics gate migration: after client-side gate ships and MIN_APP_VERSION is bumped, switch to get_weight_logs_gated with a 14-day cutoff for free users
    logs = progression_service.get_weight_logs(uid=uid)
    response = GetWeightLogsResponse(weight_logs=[WeightLogItem(**l) for l in logs])
    return jsonify(response.model_dump()), 200

@app.route("/delete_reminder", methods=["POST"])
def delete_reminder():
    uid, body, err = _parse_and_auth(DeleteReminderRequest)
    if err:
        return err

    progression_service.delete_reminder(uid, body.reminder_id)
    return jsonify(SimpleSuccessResponse(success=True).model_dump()), 200

@app.route("/achievements", methods=["GET"])
def get_achievements():
    # Step 1: Verify the user's identity from the Authorization header
    uid, _, err = _parse_and_auth()
    if err:
        return err

    # Step 2: Fetch all progress and claims through the service layer
    result = progression_service.get_achievements(uid)

    # Step 3: Build and return the validated response
    response = GetAchievementsResponse(
        progress=[AchievementProgressEntry(**p) for p in result["progress"]],
        claims=[AchievementClaimEntry(**c) for c in result["claims"]],
    )
    return jsonify(response.model_dump()), 200


@app.route("/achievement_defs", methods=["GET"])
def get_achievement_defs():
    # Public endpoint, no auth needed since definitions are the same for all users
    defs = [AchievementDefItem(**{k: v for k, v in d.items() if k != "server_tracked"}) for d in ACHIEVEMENT_DEFINITIONS]
    return jsonify([d.model_dump() for d in defs]), 200


@app.route("/claim_achievement", methods=["POST"])
def claim_achievement():
    # Step 1: Validate request body and verify the user's identity
    uid, body, err = _parse_and_auth(ClaimAchievementRequest)
    if err:
        return err

    # Step 2: Call the method and get the new progress response
    try:
        progression_service.claim_achievement(uid, body.achievement_id, body.tier)
    except ValueError as e: # error if the user's progress isn't high enough
        return jsonify({"error": str(e)}), 409

    # Step 3: Build and return the validated response
    response = SimpleSuccessResponse(success=True)
    return jsonify(response.model_dump()), 200

@app.route("/claim_trivial_achievement", methods=["POST"])
def claim_trivial_achievement():
    # Restricted route that only accepts low-stakes achievement IDs the client can trigger directly
    uid, body, err = _parse_and_auth(ClaimTrivialAchievementRequest)
    if err:
        return err

    if body.achievement_id not in TRIVIAL_ACHIEVEMENT_IDS:
        return jsonify({"error": "Achievement not allowed via this route"}), 403

    achievement_repo.upsert_achievement_progress(uid, body.achievement_id, 1)
    return jsonify(SimpleSuccessResponse(success=True).model_dump()), 200

@app.route("/referral_code", methods=["GET"])
def get_referral_code():
    uid, _, err = _parse_and_auth()
    if err:
        return err

    referral_code = progression_service.get_referral_code(uid)
    if referral_code is None:
        return jsonify({"error": "No referral code found"}), 404

    return jsonify(ReferralCodeResponse(referral_code=referral_code).model_dump()), 200


@app.route("/referral_code", methods=["POST"])
def create_referral_code():
    uid, _, err = _parse_and_auth()
    if err:
        return err

    try:
        referral_code = progression_service.create_referral_code(uid)
    except ValueError as e:
        return jsonify({"error": str(e)}), 409

    return jsonify(ReferralCodeResponse(referral_code=referral_code).model_dump()), 201

@app.route("/use_referral", methods=["POST"])
def use_referral():
    uid, body, err = _parse_and_auth(UseReferralRequest)
    if err:
        return err

    try:
        result = progression_service.use_referral(uid, body.referral_code)
    except ValueError as e:
        return jsonify({"error": str(e)}), 409

    return jsonify(UseReferralResponse(**result).model_dump()), 200

@app.route("/pending_referral_reward", methods=["GET"])
def pending_referral_reward():
    uid, _, err = _parse_and_auth()
    if err:
        return err

    data = progression_service.get_pending_referral_reward(uid)
    if not data:
        return jsonify({"pending": False}), 200

    row = data[0]
    username = (row.get("users") or {}).get("username") or "Someone"
    return jsonify({"pending": True, "referee_uid": row["referee_uid"], "referee_username": username}), 200

@app.route("/claim_referral_reward", methods=["POST"])
def claim_referral_reward():
    uid, body, err = _parse_and_auth(ClaimReferralRewardRequest)
    if err:
        return err

    try:
        result = progression_service.claim_referral_reward(uid, body.referee_uid)
    except ValueError as e:
        return jsonify({"error": str(e)}), 409

    return jsonify(ClaimReferralRewardResponse(**result).model_dump()), 200

@app.route("/admob_ssv", methods=["GET"])
def admob_ssv():
    try:
        # Extract required params from Google's SSV callback
        query_string = request.query_string.decode("utf-8")
        signature = request.args.get("signature")
        key_id = request.args.get("key_id")
        uid = request.args.get("custom_data")  # the Flutter client passes the user's UID as custom_data

        if not signature or not key_id:
            return jsonify({"error": "Missing required parameters"}), 400

        # Fetch Google's public keys for SSV verification
        keys_response = requests.get(
            "https://gstatic.com/admob/reward/verifier-keys.json",
            timeout=5
        )
        if keys_response.status_code != 200:
            logger.error("Failed to fetch AdMob verifier keys")
            return jsonify({"error": "Could not verify signature"}), 500

        keys = keys_response.json()["keys"]
        public_key_pem = None
        for key in keys:
            if str(key["keyId"]) == str(key_id):
                public_key_pem = key["pem"]
                break

        if not public_key_pem:
            return jsonify({"error": "Key not found"}), 400

        # Verify the ECDSA signature, the message is everything before &signature=
        from cryptography.hazmat.primitives import hashes, serialization
        from cryptography.hazmat.primitives.asymmetric import ec
        from cryptography.exceptions import InvalidSignature
        import base64

        msg_end = query_string.rfind("&signature=")
        message = query_string[:msg_end].encode("utf-8")
        sig_bytes = base64.urlsafe_b64decode(signature + "==")

        public_key = serialization.load_pem_public_key(public_key_pem.encode())
        public_key.verify(sig_bytes, message, ec.ECDSA(hashes.SHA256()))

        # Signature valid, only award XP if uid is present
        if not uid:
            logger.info("[admob_ssv] Signature verified but no uid (test request)")
            return jsonify({"success": True, "xp_gained": 0}), 200

        xp_gained = progression_service.award_ad_xp(uid)
        logger.info(f"[admob_ssv] Awarded {xp_gained} XP to {uid}")
        return jsonify({"success": True, "xp_gained": xp_gained}), 200

    except InvalidSignature:
        logger.warning("[admob_ssv] Invalid signature")
        return jsonify({"error": "Invalid signature"}), 400
    except Exception as e:
        logger.error(f"[admob_ssv] Error: {e}")
        return jsonify({"error": "Internal error"}), 500


@app.route("/unity_ssv", methods=["GET"])
def unity_ssv():
    try:
        import hmac
        import hashlib

        # Unity sends sid (user id), oid (offer id), and hmac as query params
        sid = request.args.get("sid", "")
        oid = request.args.get("oid", "")
        received_hmac = request.args.get("hmac", "")

        if not sid or not oid or not received_hmac:
            return jsonify({"error": "Missing required parameters"}), 400

        # Secret key from Unity Ads Support — set as environment variable UNITY_ADS_SECRET
        secret = os.environ.get("UNITY_ADS_SECRET", "")
        if not secret:
            logger.error("[unity_ssv] UNITY_ADS_SECRET not set")
            return jsonify({"error": "Server misconfigured"}), 500

        # Build the message: all params except hmac, sorted alphabetically, joined by commas
        params = {k: v for k, v in request.args.items() if k != "hmac"}
        message = ",".join(f"{k}={v}" for k, v in sorted(params.items()))

        expected_hmac = hmac.new(
            secret.encode("utf-8"),
            message.encode("utf-8"),
            hashlib.md5,
        ).hexdigest()

        if not hmac.compare_digest(received_hmac, expected_hmac):
            logger.warning("[unity_ssv] Invalid HMAC")
            return "1", 200  # Unity expects "1" even on failure to prevent retries

        xp_gained = progression_service.award_ad_xp(sid)
        logger.info(f"[unity_ssv] Awarded {xp_gained} XP to {sid}")
        return "1", 200  # Unity requires body to be "1" on success

    except Exception as e:
        logger.error(f"[unity_ssv] Error: {e}")
        return jsonify({"error": "Internal error"}), 500


@app.route("/search_exercises", methods=["GET"])
def search_exercises():
    uid, _, err = _parse_and_auth()
    if err:
        return err

    q = request.args.get("q", "").strip()
    equipment = [e for e in request.args.get("equipment", "").split(",") if e]
    muscle = [m for m in request.args.get("muscle", "").split(",") if m]
    level = [l for l in request.args.get("level", "").split(",") if l]

    results = workout_service.search_exercises(uid=uid, q=q, equipment=equipment, muscle=muscle, level=level)
    # normalize None lists to empty lists so Flutter never sees null for instructions or secondary_muscles
    for r in results:
        r['instructions'] = r.get('instructions') or []
        r['secondary_muscles'] = r.get('secondary_muscles') or []
    return jsonify([SearchExercisesResponse(**r).model_dump() for r in results]), 200


@app.route("/create_custom_exercise", methods=["POST"])
def create_custom_exercise():
    uid, body, err = _parse_and_auth(CreateCustomExerciseRequest)
    if err:
        return err
    try:
        result = workout_service.create_custom_exercise(
            uid=uid,
            name=body.name,
            primary_muscle=body.primary_muscle,
            secondary_muscles=body.secondary_muscles,
            equipment=body.equipment,
            level=body.level,
        )
        return jsonify(CreateCustomExerciseResponse(**result).model_dump()), 200
    except Exception as e:
        if 'exercises_name_created_by_unique' in str(e):  # constraint defined in schema.sql on (name, created_by)
            return jsonify({"error": "You already have an exercise with that name"}), 409
        raise


@app.route("/edit_custom_exercise", methods=["POST"])
def edit_custom_exercise():
    uid, body, err = _parse_and_auth(EditCustomExerciseRequest)
    if err:
        return err
    try:
        workout_service.edit_custom_exercise(
            uid=uid,
            exercise_id=body.exercise_id,
            name=body.name,
            primary_muscle=body.primary_muscle,
            secondary_muscles=body.secondary_muscles,
            equipment=body.equipment,
            level=body.level,
        )
        return jsonify(SimpleSuccessResponse(success=True).model_dump()), 200
    except ValueError as e:
        return jsonify(SimpleSuccessResponse(success=False, error=str(e)).model_dump()), 403


@app.route("/every_prev_set", methods=["POST"])
def every_prev_set():
    uid, body, err = _parse_and_auth(GetEveryPrevSetRequest)
    if err:
        return err
    sets = workout_service.get_every_prev_set(uid=uid, exercise_names=body.exercise_names)
    return jsonify(GetEveryPrevSetResponse(
        sets=[PrevSetItem(**prev_set) for prev_set in sets]
    ).model_dump()), 200


@app.route("/exercise_stats", methods=["GET"])
def get_exercise_stats():
    uid, _, err = _parse_and_auth()
    if err:
        return err
    stats = workout_service.get_exercise_stats(uid=uid)
    return jsonify(GetExerciseStatsResponse(
        stats=[ExerciseStatItem(**stat) for stat in stats]
    ).model_dump()), 200


@app.route("/browse_routines", methods=["GET"])
def browse_routines():
    uid, _, err = _parse_and_auth()
    if err:
        return err
    data = workout_service.get_browse_routines(uid=uid)
    return jsonify(GetBrowseRoutinesResponse(
        featured=[BrowseRoutineItem(**{**r, "exercises": [MyRoutineExerciseItem(**e) for e in r["exercises"]]}) for r in data["featured"]],
        community=[BrowseRoutineItem(**{**r, "exercises": [MyRoutineExerciseItem(**e) for e in r["exercises"]]}) for r in data["community"]],
    ).model_dump()), 200


@app.route("/delete_routine", methods=["POST"])
def delete_routine():
    uid, body, err = _parse_and_auth(DeleteRoutineRequest)
    if err:
        return err
    workout_service.delete_routine(uid=uid, template_id=body.template_id)
    return jsonify({"success": True}), 200


@app.route("/like_routine", methods=["POST"])
def like_routine():
    uid, body, err = _parse_and_auth(LikeRoutineRequest)
    if err:
        return err
    workout_service.like_routine(uid=uid, template_id=body.template_id)
    return jsonify({"success": True}), 200


@app.route("/unlike_routine", methods=["POST"])
def unlike_routine():
    uid, body, err = _parse_and_auth(UnlikeRoutineRequest)
    if err:
        return err
    workout_service.unlike_routine(uid=uid, template_id=body.template_id)
    return jsonify({"success": True}), 200


@app.route("/my_routines", methods=["GET"])
def get_my_routines():
    uid, _, err = _parse_and_auth()
    if err:
        return err
    routines = workout_service.get_my_routines(uid=uid)
    return jsonify(GetMyRoutinesResponse(
        routines=[
            MyRoutineItem(
                **{**r, "exercises": [MyRoutineExerciseItem(**e) for e in r["exercises"]]}
            )
            for r in routines
        ]
    ).model_dump()), 200


@app.route("/create_routine", methods=["POST"])
def create_routine():
    uid, body, err = _parse_and_auth(CreateRoutineRequest)
    if err:
        return err
    template_id = workout_service.create_routine(
        uid=uid,
        name=body.name,
        exercises=[e.model_dump() for e in body.exercises],
        estimated_duration_minutes=body.estimated_duration_minutes,
    )
    return jsonify(CreateRoutineResponse(template_id=template_id).model_dump()), 200


@app.route("/copy_routine", methods=["POST"])
def copy_routine():
    # saves a browse routine to the user's own routines as a private copy
    uid, body, err = _parse_and_auth(CopyRoutineRequest)
    if err:
        return err
    try:
        template_id = workout_service.copy_routine(uid=uid, template_id=body.template_id)
        return jsonify(CreateRoutineResponse(template_id=template_id).model_dump()), 200
    except ValueError as e:
        return jsonify({"error": str(e)}), 404


@app.route("/delete_custom_exercise", methods=["POST"])
def delete_custom_exercise():
    uid, body, err = _parse_and_auth(DeleteCustomExerciseRequest)
    if err:
        return err
    try:
        workout_service.delete_custom_exercise(uid=uid, exercise_id=body.exercise_id)
        return jsonify(SimpleSuccessResponse(success=True).model_dump()), 200
    except ValueError as e:
        return jsonify(SimpleSuccessResponse(success=False, error=str(e)).model_dump()), 403


@app.route("/log_workout", methods=["POST"])
def log_workout():
    # Called when the user taps Finish on the active workout screen
    # Inserts workouts, workout_exercises, and workout_sets rows and returns the generated workout_id
    uid, body, err = _parse_and_auth(LogWorkoutRequest)
    if err:
        return err
    try:
        result = workout_service.log_workout(
            uid=uid,
            name=body.name,
            date=body.date,
            duration_seconds=body.duration_seconds,
            exercises=[ex.model_dump() for ex in body.exercises],
        )
    except ValueError as e:
        return jsonify({"error": str(e)}), 400
    return jsonify(LogWorkoutResponse(**result).model_dump()), 200

@app.route("/recent_exercises", methods=["GET"])
def get_recent_exercises():
    # Returns the user's most recently used unique exercises for the exercise picker's Recent section
    uid, _, err = _parse_and_auth()
    if err:
        return err
    exercises = workout_service.get_recent_exercises(uid)
    return jsonify(GetRecentExercisesResponse(
        exercises=[RecentExerciseItem(**e) for e in exercises]
    ).model_dump()), 200

@app.route("/workout_heatmap", methods=["GET"])
def get_workout_heatmap():
    # Returns workout counts per day for the last 12 weeks for the heatmap grid
    uid, _, err = _parse_and_auth()
    if err:
        return err
    days = workout_service.get_workout_heatmap(uid)
    return jsonify(GetWorkoutHeatmapResponse(days=[HeatmapDay(**d) for d in days]).model_dump()), 200


@app.route("/today_overview", methods=["GET"])
def get_today_overview():
    # Returns today's workout totals: volume, exercises, sets, reps, duration, muscles worked
    uid, _, err = _parse_and_auth()
    if err:
        return err
    data = workout_service.get_today_overview(uid)
    return jsonify(GetTodayOverviewResponse(**data).model_dump()), 200


@app.route("/weekly_workout_count", methods=["GET"])
def get_weekly_workout_count():
    # Returns the number of completed workouts since the most recent Monday
    uid, _, err = _parse_and_auth()
    if err:
        return err
    count = workout_service.get_weekly_workout_count(uid)
    return jsonify(GetWeeklyWorkoutCountResponse(count=count).model_dump()), 200


@app.route("/recent_workouts", methods=["GET"])
def get_recent_workouts():
    # Returns the 10 most recently completed sessions for the workout tab history card
    uid, _, err = _parse_and_auth()
    if err:
        return err
    workouts = workout_service.get_recent_workouts(uid)
    return jsonify(GetRecentWorkoutsResponse(workouts=[RecentWorkoutItem(**w) for w in workouts]).model_dump()), 200


@app.route("/premium_status", methods=["GET"])
def get_premium_status():
    # Returns the user's current premium status and expiry, checking if it has lapsed
    uid, _, err = _parse_and_auth()
    if err:
        return err
    row = user_repo.get_premium_status(uid)
    is_premium = row.get("is_premium", False)
    expires_at = row.get("premium_expires_at")
    # Revoke premium if the expiry has passed
    if is_premium and expires_at:
        expiry_dt = datetime.fromisoformat(expires_at.replace("Z", "+00:00"))
        if datetime.now(timezone.utc) > expiry_dt:
            user_repo.set_premium(uid, False, None)
            is_premium = False
            expires_at = None
    return jsonify(PremiumStatusResponse(is_premium=is_premium, premium_expires_at=expires_at).model_dump()), 200


@app.route("/verify_purchase", methods=["POST"])
def verify_purchase():
    # Validates a Google Play subscription purchase token and grants premium if active
    uid, body, err = _parse_and_auth(VerifyPurchaseRequest)
    if err:
        return err
    try:
        raw_sa = os.environ.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON", "")
        logger.error(f"verify_purchase: env_var_length={len(raw_sa)}, first_10={raw_sa[:10]!r}")
        try:
            sa_json = json.loads(raw_sa)
        except Exception as e:
            logger.error(f"verify_purchase: failed to parse service account JSON: {e}")
            return jsonify({"error": "Service account config error"}), 500
        logger.error(f"verify_purchase: service_account_email={sa_json.get('client_email', 'NOT FOUND')}")
        credentials = service_account.Credentials.from_service_account_info(
            sa_json,
            scopes=["https://www.googleapis.com/auth/androidpublisher"],
        )
        service = google_build("androidpublisher", "v3", credentials=credentials)
        result = service.purchases().subscriptionsv2().get(
            packageName="com.nicholasdakis.levelup",
            token=body.purchase_token,
        ).execute()

        # lineItems contains the subscription info for each product in the purchase
        line_items = result.get("lineItems", [])
        if not line_items:
            return jsonify({"error": "No subscription line items found"}), 400

        # Check subscription state: ACTIVE or IN_GRACE_PERIOD means the user has access
        subscription_state = result.get("subscriptionState", "")
        active_states = {"SUBSCRIPTION_STATE_ACTIVE", "SUBSCRIPTION_STATE_IN_GRACE_PERIOD"}
        if subscription_state not in active_states:
            return jsonify({"error": f"Subscription not active: {subscription_state}"}), 402

        # Pull expiry from the first line item
        expiry_time = line_items[0].get("expiryTime")
        user_repo.set_premium(uid, True, expiry_time)
        return jsonify(PremiumStatusResponse(is_premium=True, premium_expires_at=expiry_time).model_dump()), 200

    except Exception as e:
        logger.error(f"verify_purchase error for uid={uid}: {e}")
        return jsonify({"error": "Failed to verify purchase"}), 500


@app.route("/premium_perks", methods=["GET"])
def get_premium_perks():
    # Returns the user's current premium perk allowances, applying a monthly reset first if needed
    uid, _, err = _parse_and_auth()
    if err:
        return err
    if not user_repo.get_premium_status(uid).get("is_premium", False):
        return jsonify(PremiumPerksResponse(shield_count=0, shields_reset_at="").model_dump()), 200
    row = premium_perks_repo.get_or_create_perks(uid)
    row = premium_perks_repo.reset_perks_if_month_elapsed(uid, row)
    return jsonify(PremiumPerksResponse(
        shield_count=row["shield_count"],
        shields_reset_at=row["shields_reset_at"],
    ).model_dump()), 200


@app.route("/use_streak_shield", methods=["POST"])
def use_streak_shield():
    # Spends one streak shield to restore the user's daily_consecutive_streak to their highest recorded streak
    uid, _, err = _parse_and_auth()
    if err:
        return err
    if not user_repo.get_premium_status(uid).get("is_premium", False):
        return jsonify({"error": "Premium required"}), 403
    row = premium_perks_repo.get_or_create_perks(uid)
    row = premium_perks_repo.reset_perks_if_month_elapsed(uid, row)
    if row["shield_count"] <= 0:
        return jsonify({"error": "No streak shields remaining this month"}), 400
    result = premium_perks_repo.apply_streak_shield(uid)
    return jsonify(UseShieldResponse(
        shield_count=result["shield_count"],
        restored_streak=result["restored_streak"],
    ).model_dump()), 200


if __name__ == "__main__": # Only run when the application starts
    app.run(debug=False)