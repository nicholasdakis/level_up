import os
import re
import json
import random
import logging
import requests
from datetime import timedelta, timezone, datetime, date
from flask import Flask, jsonify, request, g
from flask_cors import CORS
from pydantic import ValidationError
from firebase_admin import messaging
import firebase_admin
from firebase_admin import credentials as firebase_credentials
from supabase import create_client, Client
from redis.exceptions import LockNotOwnedError, LockError
from backend.token_manager import TokenManager
from backend.repository import UserRepository, ReminderRepository, RateLimitRepository, AchievementRepository
from backend.services import ProgressionService, FoodService, POIService, SnapshotService
from backend.schemas import (
    ClaimDailyRewardRequest,
    GetProgressRequest,
    DailyRewardResponse,
    ProgressResponse,
    UpdateUsernameRequest,
    UpdateUsernameResponse,
    SearchFoodRequest,
    NearbyPOIRequest,
    NearbyPOIResponse,
    POIItem,
    CheckInPOIRequest,
    CheckInPOIResponse,
    GetUserDataRequest,
    GetUserDataResponse,
    UpdatePfpRequest,
    UpdateAppColorRequest,
    UpdateNotificationsRequest,
    AddFcmTokenRequest,
    RemoveFcmTokenRequest,
    UpsertFoodLogRequest,
    SimpleSuccessResponse,
    GetLeaderboardRequest,
    GetLeaderboardResponse,
    LeaderboardUserEntry,
    GetRemindersRequest,
    SetReminderRequest,
    ReminderItem,
    GetRemindersResponse,
    DeleteReminderRequest,
    GetAchievementsRequest,
    GetAchievementsResponse,
    AchievementProgressEntry,
    AchievementClaimEntry,
    ClaimAchievementRequest,
    ClaimTrivialAchievementRequest,
    UpdateUtcOffsetRequest,
    UpdateGoalsRequest
)
from backend.auth import verify_token
from backend.valid_achievements import TRIVIAL_ACHIEVEMENT_IDS
from backend.utils import to_utc_datetime
from backend.redis_cache import FOOD_CACHE_TTL, redis

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

# Helper method for verifying the user's JWT token
def _try_verify_token(id_token: str):
    try:
        return verify_token(id_token), None  # (uid, no error)
    except ValueError as e:
        return None, (jsonify({"error": str(e)}), 401)  # (no uid, 401 error response)

# Helper method for deserializing the JSON request body into the appropriate schema and verifying the user's identity
def _parse_and_auth(schema):
    # Parse the JSON into the schema
    try:
        body = schema(**request.get_json(force=True))
    except (ValidationError, TypeError) as e:
        return None, None, (jsonify({"error": "Invalid request", "details": str(e)}), 400)

    # Verify the JWT
    uid, err = _try_verify_token(body.id_token)
    if err:
        return None, None, err
    g.uid = uid  # stored so after_request can log it for every route
    return uid, body, None

def send_due_reminders():
    try:
        now_dt = datetime.now(timezone.utc)
        print(f'[reminders] Checking for due reminders at {now_dt.isoformat()}')

        # Query the reminders table for all rows where the time is due (i.e. time <= now)
        due_reminders = reminder_repo.get_due_reminders(now_dt.isoformat())

        count = 0
        for reminder in due_reminders:
            reminder_id = reminder["id"]
            uid = reminder["uid"]

            # Atomically claim the reminder by deleting it, so skip if another instance already claimed it
            if not reminder_repo.delete_reminder(reminder_id):
                # Another instance already deleted/claimed this reminder, skip it
                print(f'[reminders] Reminder {reminder_id} already claimed by another instance, skipping')
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
            print(f'[reminders] Sent to {uid}: success={response.success_count}, failure={response.failure_count}')

            # Clean up tokens with unregistered / invalid error codes (e.g. user uninstalled the app or revoked permissions)
            if response.failure_count > 0:
                invalid_tokens = []
                for i, res in enumerate(response.responses):
                    if not res.success and res.exception:
                        code = getattr(res.exception, 'code', None)
                        print(f'[reminders] Token {i} failed: code={code} error={res.exception}')
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
            print(f'[reminders] No due reminders found')

    except Exception as e:
        print(f'Error sending reminders: {e}')

@app.route("/ping")
def ping():
    return jsonify({
        "message": "Pinged."
    }), 200

MINUTES_IN_DAY = 1440 # for wrapping around the time when converting it

# Method to calculate utc time in mins for the formula local time in mins = utc time in mins + offset in mins
def utc_minute_of_day():
    now = datetime.now(timezone.utc)
    return now.hour * 60 + now.minute

# Method that returns the offsets in minutes that are currently at midnight (with a 1 minute buffer on either side to account for slight timing differences between the CRON job and the server)
def find_utc_midnight_offset_mins(utc_min):
    # the raw offset that would be at midnight exactly in local time
    raw = -utc_min
    # normalize the offsets to be between -720 and 720, which correspond to the furthest timezones UTC-12 and UTC+12
    # includes buffers of 1 minute on either side, so 3 offsets are returned in total
    offsets = [(raw + delta + 720) % MINUTES_IN_DAY - 720 for delta in [-1, 0, 1]]
    # edge case for UTC-12 and UTC+12, which have the same utc_min but different offsets
    if -720 in offsets:
        offsets.append(720)
    return offsets

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

@app.route("/get_food", methods=["POST"])
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
        logger.warning(f"[Redis Error]: {e}") # Real error message logged to server
        print("Redis error, falling back to the API search.") # Generic error message for user
    
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
    )

    # Step 3: Return updated state
    return jsonify({
        "success": True,
        "goals": result
    }), 200

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
        body.poi_lat,
        body.poi_lng,
        body.user_lat,
        body.user_lng,
    )

    # Step 3: Build and return the validated response
    response = CheckInPOIResponse(**result)
    status = 200 if result["success"] else 409 # 409 = conflict
    return jsonify(response.model_dump()), status

@app.route("/update_username", methods=["POST"]) # POST because the route is for modifying data
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

@app.route("/claim_daily_reward", methods=["POST"]) # POST because the route is for modifying data
def claim_daily_reward():
    # Step 1: Validate request body and verify the user's identity
    uid, body, err = _parse_and_auth(ClaimDailyRewardRequest)
    if err:
        return err

    # Step 2: The service calculates XP and level-ups, and the repository (in the service) writes to Postgres atomically
    result = progression_service.claim_daily_reward(uid)

    # Step 3: Build the expected response schema
    response = DailyRewardResponse(
        claimed=result["claimed"],
        xp_gained=result["xp_gained"],
        new_level=result["new_level"],
        new_exp=result["new_exp"],
        seconds_remaining=result["seconds_remaining"],
    )

    return jsonify(response.model_dump()), 200 # model_dump() converts the Pydantic model to a dict for jsonify, because jsonify only accepts plain dicts


@app.route("/get_progress", methods=["POST"]) # POST because the id_token is sent in the request body
def get_progress():
    # Step 1: Validate request body and verify the user's identity
    uid, body, err = _parse_and_auth(GetProgressRequest)
    if err:
        return err

    # Step 2: Fetch the user's current state through the service layer
    result = progression_service.get_progress(uid)

    # Step 3: Return validated response
    response = ProgressResponse(**result)
    return jsonify(response.model_dump()), 200

@app.route("/get_user_data", methods=["POST"])
def get_user_data():
    # Method that returns all user data in a single call
    uid, body, err = _parse_and_auth(GetUserDataRequest)
    if err:
        return err

    result = progression_service.get_user_data(uid)
    response = GetUserDataResponse(**result)
    return jsonify(response.model_dump()), 200


@app.route("/update_pfp", methods=["POST"])
def update_pfp():
    # Method that updates the user's profile picture, stored as a Base64 string
    uid, body, err = _parse_and_auth(UpdatePfpRequest)
    if err:
        return err

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

@app.route("/get_leaderboard", methods=["POST"]) # POST because the id_token is sent in the request body
def get_leaderboard():
    # Method that returns all users sorted by level and XP descending for the leaderboard
    uid, body, err = _parse_and_auth(GetLeaderboardRequest)
    if err:
        return err

    result = progression_service.get_leaderboard()
    response = GetLeaderboardResponse(
        users=[LeaderboardUserEntry(**entry) for entry in result]
    )
    return jsonify(response.model_dump()), 200

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

@app.route("/get_reminders", methods=["POST"])  # Endpoint to get the user's reminders
def get_reminders():
    # Parse JSON body into Pydantic schema and verify Firebase ID token
    uid, body, err = _parse_and_auth(GetRemindersRequest)
    if err:
        return err

    # fetch from service
    result = progression_service.get_reminders(uid=uid)

    # map DB rows → Pydantic models
    reminders = [ReminderItem(**r) for r in result]
    
    response = GetRemindersResponse(reminders=reminders)

    # Return all reminders
    return jsonify(response.model_dump()), 200

@app.route("/delete_reminder", methods=["POST"])
def delete_reminder():
    uid, body, err = _parse_and_auth(DeleteReminderRequest)
    if err:
        return err

    progression_service.delete_reminder(uid, body.reminder_id)
    return jsonify(SimpleSuccessResponse(success=True).model_dump()), 200

@app.route("/get_achievements", methods=["POST"])  # POST because the id_token is sent in the request body
def get_achievements():
    # Step 1: Validate request body and verify the user's identity
    uid, body, err = _parse_and_auth(GetAchievementsRequest)
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


@app.route("/claim_achievement", methods=["POST"]) # POST because the id_token is sent in the request body
def claim_achievement():
    # Step 1: Validate request body and verify the user's identity
    uid, body, err = _parse_and_auth(ClaimAchievementRequest)
    if err:
        return err

    # Step 2: Call the method and get the new progress response
    try:
        result = progression_service.claim_achievement(uid, body.achievement_id, body.tier)
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

if __name__ == "__main__": # Only run when the application starts
    app.run(debug=False)