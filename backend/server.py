from flask import Flask, jsonify, request
import os
import requests
from flask_cors import CORS
from backend.token_manager import TokenManager
from backend.repository import UserRepository
from backend.services import ProgressionService
from backend.schemas import (
    ClaimDailyRewardRequest,
    GetProgressRequest,
    UpdateExpRequest,
    UpdateExpResponse,
    DailyRewardResponse,
    ProgressResponse,
    UpdateUsernameRequest,
    UpdateUsernameResponse,
    SearchFoodRequest,
    NearbyPOIRequest,
    NearbyPOIResponse,
    POIItem,
    CheckInPOIRequest,
    CheckInPOIResponse
)
from backend.auth import verify_token
from datetime import timedelta, timezone, datetime
from google.cloud import firestore
from google.oauth2 import service_account
from firebase_admin import messaging
from pydantic import ValidationError
import firebase_admin
import json
import re
import random
from backend.utils import to_utc_datetime
from backend.redis_cache import FOOD_CACHE_TTL, redis
import logging
from redis.exceptions import LockNotOwnedError, LockError

logger = logging.getLogger(__name__)

# Get the environmental variables from Render
CLIENT_ID = os.environ.get("CLIENT_ID")
CLIENT_SECRET = os.environ.get("CLIENT_SECRET")
MAX_TOKENS = int(os.getenv("MAX_TOKENS", "5000"))

token_manager = TokenManager()

app = Flask(__name__)
CORS(app) # allow requests from desktop device browsers

@app.after_request # runs after every request
# This method adds CORS headers even when responses are unsuccessful to prevent CORS errors when trying to debug
def add_cors_headers(response):
    origin = request.headers.get('Origin')
    if origin == 'https://nicholasdakis.github.io' or (origin and origin.startswith('http://localhost')):
        response.headers['Access-Control-Allow-Origin'] = origin
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type,Authorization'
    response.headers['Access-Control-Allow-Methods'] = 'GET,POST,OPTIONS'
    return response

# Initialize Firestore client
# Load credentials JSON string from env var
cred_json = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS_JSON")

# Parse JSON string into a dict
credentials_info = json.loads(cred_json)

# Create Credentials object
credentials = service_account.Credentials.from_service_account_info(credentials_info)

# Create Firestore client with explicit credentials
db = firestore.Client(credentials=credentials)

# Initialize the repository and service layers, passing the Firestore client to the repository so it can read/write data
user_repo = UserRepository(db)
progression_service = ProgressionService(user_repo)

def send_due_reminders():
    try:
        now_dt = datetime.now(timezone.utc)
        # Format to match Flutter's toUtc().toIso8601String() output (e.g. 2026-03-30T15:00:00.000Z)
        now = now_dt.strftime('%Y-%m-%dT%H:%M:%S.') + f'{now_dt.microsecond // 1000:03d}Z'
        print(f'[reminders] Checking for due reminders at {now}')

        # collection_group queries the reminders subcollection across all users at once
        # Requires a Firestore composite index on reminders.dateTime (collection group ASC)
        due_reminders = db.collection_group('reminders').where('dateTime', '<=', now).stream()

        count = 0
        for doc in due_reminders:
            # Atomically claim the reminder, so skip if another instance already claimed it
            @firestore.transactional
            def claim(transaction, doc_ref):
                snapshot = doc_ref.get(transaction=transaction)
                if not snapshot.exists or snapshot.to_dict().get('processing'):
                    return False
                transaction.update(doc_ref, {'processing': True})
                return True

            transaction = db.transaction()
            try:
                claimed = claim(transaction, doc.reference)
            except Exception as e:
                print(f'[reminders] Failed to claim reminder {doc.id}: {e}')
                continue

            if not claimed:
                print(f'[reminders] Reminder {doc.id} already claimed by another instance, skipping')
                continue

            count += 1
            data = doc.to_dict()

            # Extract the user's UID from the document path: users-private/{uid}/reminders/{docId}
            uid = doc.reference.parent.parent.id

            # Get the user's private document to retrieve their FCM tokens
            user_doc = db.collection('users-private').document(uid).get()
            if not user_doc.exists:
                doc.reference.delete()  # user no longer exists, clean up the reminder
                continue

            # Get the user's FCM tokens. if empty or missing, the user has no devices to notify
            fcm_tokens = user_doc.to_dict().get('fcmTokens', [])
            if not fcm_tokens:
                doc.reference.delete()
                continue

            # Send a notification + data payload so browsers show it even when minimized
            message = messaging.MulticastMessage(
                notification=messaging.Notification(
                    title="Level Up! Reminder",
                    body=data.get('message', 'You have a reminder!')
                ),
                data={
                    'body': data.get('message', 'You have a reminder!'),
                    'reminderId': doc.id
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
                            'registration-token-not-registered',
                            'invalid-registration-token',
                        ):
                            invalid_tokens.append(fcm_tokens[i])
                # Remove invalid tokens from Firestore as to not keep trying to send to them
                if invalid_tokens:
                    db.collection('users-private').document(uid).update({
                        'fcmTokens': firestore.ArrayRemove(invalid_tokens)
                    })

            # Delete the reminder after sending so it does not fire again
            doc.reference.delete()

        if count == 0:
            print(f'[reminders] No due reminders found')

    except Exception as e:
        print(f'Error sending reminders: {e}')


def get_next_reset_time():
    # Get the document reference for rate limit tracking
    doc_ref = db.collection('rate_limits').document('food_logging')
    doc = doc_ref.get()
    if not doc.exists:
        return None  # If doc doesn't exist, no reset time available
    data = doc.to_dict()
    last_refill_time = data.get("last_refill_time")
    # no reset time, return None
    if not last_refill_time:
        return None
    # Timestamp to datetime conversion (handles Firestore Timestamp)
    last_refill_dt = to_utc_datetime(last_refill_time)
    # reset time is 1 day after the last refill
    reset_time = last_refill_dt + timedelta(days=1)
    return reset_time

def get_access_token():
    """Request an access token from FatSecret"""
    token_url = "https://oauth.fatsecret.com/connect/token"
    data = {"grant_type": "client_credentials", "scope": "basic"}
    try:
        response = requests.post(token_url, data=data, auth=(CLIENT_ID, CLIENT_SECRET))
        response.raise_for_status()
        return response.json().get("access_token")
    except requests.RequestException as e:
        return None

@app.route("/ping")
def ping():
    return jsonify({
        "message": "Pinged."
    }), 200

@app.route("/send_reminders")
def trigger_reminders():
    # Only the CRON-JOB can trigger the route
    secret = request.args.get("key") or request.headers.get("X-Cron-Key")
    expected = os.environ.get("CRON_SECRET")
    if not expected or secret != expected:
        return jsonify({"error": "Unauthorized"}), 401
    send_due_reminders()
    return jsonify({"message": "Reminders checked."}), 200

# Helper method for get_food
def call_fatsecret(food_name: str, timeout: int):
    access_token = get_access_token()
    if not access_token:
        token_manager.refund()
        raise RuntimeError("Failed to get access token")

    headers = {"Authorization": f"Bearer {access_token}"}
    data = {
        "method": "foods.search",
        "search_expression": food_name,
        "format": "json"
    }

    try:
        api_response = requests.post(
            "https://platform.fatsecret.com/rest/server.api",
            headers=headers,
            data=data,
            timeout=timeout
        )
        if api_response.status_code != 200:
            token_manager.refund()
            raise RuntimeError(f"FatSecret API error: {api_response.status_code}")
        return api_response
    except requests.RequestException as e:
        token_manager.refund()
        raise RuntimeError(str(e))

@app.route("/get_food", methods=["POST"])
def get_food():
    # Validate request body with the Pydantic schema
    try:
        body = SearchFoodRequest(**request.get_json(force=True))
    except (ValidationError, TypeError) as e:
        return jsonify({"error": "Invalid request", "details": str(e)}), 400

    # Make sure the user is who they say they are
    try:
        uid = verify_token(body.id_token)
    except ValueError as e:
        return jsonify({"error": str(e)}), 401

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
                reset_time = get_next_reset_time()
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
                api_response = call_fatsecret(food_name, lock_timeout_seconds - 1)
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

# Overpass API endpoints
OVERPASS_URLS = ["https://overpass-api.de/api/interpreter","https://overpass.private.coffee/api/interpreter"]

# Overpass QL query template for fetching general POIs near a location
# {lat}, {lng}, {radius} are filled in at request time
# Each tag key (amenity, leisure, shop, tourism) produces category values
# used by POIIcons.fromCategory on the client side
OVERPASS_QUERY = """
[out:json][timeout:20];
(
  node["amenity"](around:{radius},{lat},{lng});
  node["leisure"](around:{radius},{lat},{lng});
  node["shop"](around:{radius},{lat},{lng});
  node["tourism"](around:{radius},{lat},{lng});
);
out body 100;
"""

# Method to turn the Overpass JSON into POIItem objects for the useful fields
def parse_overpass_response(data):
    pois = []
    seen_locations = set()
    elements = data.get("elements", []) # Overpass returns results in an "elements" array

    for element in elements:
        tags = element.get("tags", {}) # tags hold metadata like name, amenity type
        name = tags.get("name") # to skip unnamed nodes

        if not name:
            continue

        # Figure out the node's category by going through all categories
        category = (
            tags.get("amenity") or
            tags.get("leisure") or
            tags.get("shop") or
            tags.get("tourism") or
            "other" # fallback
        )

        lat = element["lat"] # Overpass always includes lat/lon for nodes
        lng = element["lon"] # self-note: Overpass uses "lon" for longtitude

        # Round to 5 decimal places (1.1m) to prevent duplicate elements returned by Overpass
        location_key = f"{round(lat, 5)},{round(lng, 5)}"
        if location_key in seen_locations:
            continue
        seen_locations.add(location_key)

        pois.append(POIItem(
            name=name,
            lat=lat,
            lng=lng,
            category=category,
        ))

    return pois

@app.route("/get_nearby_pois", methods=["POST"])
def get_nearby_pois():
    # Step 1: Validate request body with the Pydantic schema
    try:
        body = NearbyPOIRequest(**request.get_json(force=True))
    except (ValidationError, TypeError) as e:
        return jsonify({"error": "Invalid request", "details": str(e)}), 400

    # Step 2: Make sure the user is who they say they are
    try:
        uid = verify_token(body.id_token)
    except ValueError as e:
        return jsonify({"error": str(e)}), 401

    # Step 3: Build the Overpass query by filling in the user's coordinates
    query = OVERPASS_QUERY.format(
        lat=body.lat,
        lng=body.lng,
        radius=500, # scans 500 meters within the user's location
    )

    # Step 4: Send the query to the Overpass API, retry once if it fails
    overpass_response = None
    latest_error = None

    for url in OVERPASS_URLS:
        try:
            overpass_response = requests.post(url, data={"data": query}, timeout=25) # Overpass expects the query in a "data" form field
            if overpass_response.status_code == 200:
                break
            else: # Responses other than 200
                latest_error = f"HTTP {overpass_response.status_code}: {overpass_response.text}"
                overpass_response = None
        except requests.RequestException as e:
            latest_error = e
            overpass_response = None

    if overpass_response is None or overpass_response.status_code != 200:
        print(f"Overpass API error: {latest_error}")
        return jsonify({"error": "Overpass API unavailable, try again later"}), 503

    # Step 5: Parse the raw Overpass data into POI objects
    all_pois = parse_overpass_response(overpass_response.json())

    # Step 6: If there are more than 20 POIs found, a random subset of the 20 are shown
    if len(all_pois) > 20:
        all_pois = random.sample(all_pois, 20)

    # Step 7: Build and return the validated response
    response = NearbyPOIResponse(pois=all_pois)
    return jsonify(response.model_dump()), 200

@app.route("/check_in_poi", methods=["POST"])
def check_in_poi():
    # Step 1: Validate request body with the Pydantic schema
    try:
        body = CheckInPOIRequest(**request.get_json(force=True))
    except (ValidationError, TypeError) as e:
        return jsonify({"error": "Invalid request", "details": str(e)}), 400

    # Step 2: Make sure the user is who they say they are
    try:
        uid = verify_token(body.id_token)
    except ValueError as e:
        return jsonify({"error": str(e)}), 401

    # Step 3: Run the check-in through the service layer
    result = progression_service.check_in_poi(
        uid,
        body.poi_name,
        body.poi_lat,
        body.poi_lng,
        body.user_lat,
        body.user_lng,
    )

    # Step 4: Build and return the validated response
    response = CheckInPOIResponse(**result)
    status = 200 if result["success"] else 409 # 409 = conflict
    return jsonify(response.model_dump()), status

@app.route("/update_username", methods=["POST"]) # POST because the route is for modifying data
def update_username():
    # Step 1: Validate request body with the Pydantic schema
    try:
        body = UpdateUsernameRequest(**request.get_json(force=True))
    except (ValidationError, TypeError) as e: # Stops early with a detailed error
        return jsonify({"error": "Invalid request", "details": str(e)}), 400

    # Step 2: Make sure the user is who they say they are by verifying the JWT
    try:
        uid = verify_token(body.id_token)
    except ValueError as e:
        return jsonify({"error": str(e)}), 401

    # Step 3: # The service calculates if the update is valid, and the repository (in the service) reads Firestore atomically
    result = progression_service.update_username(uid, body.username) # Returns a dict, and update_username is successful if the uniqueness check passes

    # Step 4: Build the expected response schema
    response = UpdateUsernameResponse(
        success=result["success"],
        error=result.get("error"), # .get to safely return if the error is None
    )
    
    if not result["success"]:
        return jsonify(response.model_dump()), 409 # The update was unsuccessful since success = False, so give a separate response
    return jsonify(response.model_dump()), 200 # model_dump() converts the Pydantic model to a dict for jsonify, because jsonify only accepts plain dicts

@app.route("/claim_daily_reward", methods=["POST"]) # POST because the route is for modifying data
def claim_daily_reward():
    # Step 1: Validate request body with the Pydantic schema
    try:
        body = ClaimDailyRewardRequest(**request.get_json(force=True))
    except (ValidationError, TypeError) as e: # Stops early with a detailed error
        return jsonify({"error": "Invalid request", "details": str(e)}), 400

    # Step 2: Make sure the user is who they say they are by verifying the JWT
    try:
        uid = verify_token(body.id_token)
    except ValueError as e:
        return jsonify({"error": str(e)}), 401

    # Step 3: # The service calculates XP and level-ups, and the repository (in the service) writes to Firestore atomically
    result = progression_service.claim_daily_reward(uid)

    # Step 4: Build the expected response schema
    response = DailyRewardResponse(
        claimed=result["claimed"],
        xp_gained=result["xp_gained"],
        new_level=result["new_level"],
        new_exp=result["new_exp"],
        seconds_remaining=result["seconds_remaining"],
    )

    return jsonify(response.model_dump()), 200 # model_dump() converts the Pydantic model to a dict for jsonify, because jsonify only accepts plain dicts


@app.route("/get_progress", methods=["POST"]) # POST because the route is for modifying data
def get_progress():
    # Step 1: Make sure the reponse matches the schema
    try:
        body = GetProgressRequest(**request.get_json(force=True)) # force=True is a safety net to make sure the data is parsed as JSON
    except (ValidationError, TypeError) as e:
        return jsonify({"error": "Invalid request", "details": str(e)}), 400

    # Step 2: Verify the user is who they say they are
    try:
        uid = verify_token(body.id_token)
    except ValueError as e:
        return jsonify({"error": str(e)}), 401

    # Step 3: Fetch the user's current state through the service layer
    result = progression_service.get_progress(uid)

    # Step 4: Return validated response
    response = ProgressResponse(**result)
    return jsonify(response.model_dump()), 200

@app.route("/update_exp", methods=["POST"]) # POST because this route modifies data
def update_exp():
    # Step 1: Make sure the response matches the schema
    try:
        body = UpdateExpRequest(**request.get_json(force=True))
    except (ValidationError, TypeError) as e:
        return jsonify({"error": "Invalid request", "details": str(e)}), 400

    # Step 2: Verify the user is who they say they are
    try:
        uid = verify_token(body.id_token)
    except ValueError as e:
        return jsonify({"error": str(e)}), 401

    # Step 3: Run XP update through the service layer
    result = progression_service.update_exp(uid, body.event, body.event_id)

    # Step 4: Return validated response
    response = UpdateExpResponse(**result)
    return jsonify(response.model_dump()), 200

if __name__ == "__main__": # Only run when the application starts
    app.run(debug=False)