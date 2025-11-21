from flask import Flask, jsonify
import os
import requests
from dotenv import load_dotenv
from backend.token_manager import TokenManager
from datetime import timedelta, timezone, datetime
from google.cloud import firestore
from google.oauth2 import service_account
import json

# Load the .env file
load_dotenv()
CLIENT_ID = os.getenv("CLIENT_ID")
CLIENT_SECRET = os.getenv("CLIENT_SECRET")
MAX_TOKENS = int(os.getenv("MAX_TOKENS", 5000))

token_manager = TokenManager()

app = Flask(__name__)

# Initialize Firestore client
# Load credentials JSON string from env var
cred_json = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS_JSON")

# Parse JSON string into a dict
credentials_info = json.loads(cred_json)

# Create Credentials object
credentials = service_account.Credentials.from_service_account_info(credentials_info)

# Create Firestore client with explicit credentials
db = firestore.Client(credentials=credentials)

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

@app.route("/get_food/<food_name>")
def get_food(food_name):
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
        }), 500
    
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

@app.route("/reset_tokens")
def reset_tokens():
    """Reset tokens for testing"""
    success = token_manager.reset_tokens()
    return jsonify({"success": success, "message": "Tokens reset to 5000"})

if __name__ == "__main__": # Only run when the application starts
    app.run(debug=False)