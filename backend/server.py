from unittest import result

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
    DailyRewardResponse,
    ProgressResponse,
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

# Get the environmental variables from Render
CLIENT_ID = os.environ.get("CLIENT_ID")
CLIENT_SECRET = os.environ.get("CLIENT_SECRET")
MAX_TOKENS = int(os.getenv("MAX_TOKENS", "5000"))

token_manager = TokenManager()

app = Flask(__name__)
CORS(app) # allow requests from desktop device browsers

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
                    'body': data.get('message', 'You have a reminder!'),  # fallback for your SW
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
    last_refill_dt = last_refill_time.to_datetime() if hasattr(last_refill_time, 'to_datetime') else last_refill_time
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
    send_due_reminders()
    return jsonify({"message": "Reminders checked."}), 200

@app.route("/get_food/<food_name>")
def get_food(food_name):
    # Normalize the food name to reduce API calls
    food_name = re.sub(r'\s+', ' ', food_name.lower()).strip() # lowercase and remove unneeded whitespace

    if not token_manager.consume():
        # retrieve the next reset time
        reset_time = get_next_reset_time()
        if reset_time is None:
            # no reset time, return
            return jsonify({
                "error": "Token limit exceeded",
                "message": "No reset time available"
            }), 500
        
        # calculate time till next reset
        time_left = reset_time - datetime.now(timezone.utc)

        return jsonify({
            "error": "Token limit exceeded",
            "next_reset_time": reset_time.isoformat(),
            "time_left": str(time_left)  # Converted to string for JSON serializable
        }), 429
    
    # Continue if tokens are available
    access_token = get_access_token()
    # If we can't get access token, refund the consumed token
    if not access_token:
        token_manager.refund()  # Give back the token since we failed early
        return jsonify({"error": "Failed to get access token"}), 500
    headers = {"Authorization": f"Bearer {access_token}"}
    # FatSecret REST API expects form-encoded data
    data = {
        "method": "foods.search",
        "search_expression": food_name,
        "format": "json"
    }

    try:
        api_response = requests.post(
            "https://platform.fatsecret.com/rest/server.api",
            headers=headers,
            data=data
        )
        # If FatSecret API call fails, refund the token
        if api_response.status_code != 200:
            token_manager.refund()  # Give back token on API failure
            return jsonify({"error": "FatSecret API error", "status_code": api_response.status_code}), 500
        # Possibly a XML response if the above request fails
        try:
            return jsonify(api_response.json())
        except ValueError:
            token_manager.refund()  # Give back token on invalid JSON
            return jsonify({"error": "Invalid JSON from FatSecret API", "raw": api_response.text})
    except requests.RequestException as e:
        token_manager.refund()  # Give back token on network error
        return jsonify({"error": str(e)}), 500

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

if __name__ == "__main__": # Only run when the application starts
    app.run(debug=False)