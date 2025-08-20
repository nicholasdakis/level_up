from flask import Flask, jsonify
import os
import requests
from dotenv import load_dotenv

# Load the .env file
load_dotenv()
CLIENT_ID = os.getenv("CLIENT_ID")
CLIENT_SECRET = os.getenv("CLIENT_SECRET")

app = Flask(__name__)

def get_access_token():
    """Request an access token from FatSecret"""
    token_url = "https://oauth.fatsecret.com/connect/token"
    data = {"grant_type": "client_credentials", "scope": "basic"}
    try:
        response = requests.post(token_url, data=data, auth=(CLIENT_ID, CLIENT_SECRET))
        response.raise_for_status()
        return response.json().get("access_token")
    except requests.RequestException as e:
        print("Error getting access token:", e)
        return None

@app.route("/get_food/<food_name>")
def get_food(food_name):
    access_token = get_access_token()
    if not access_token:
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
        # Possibly a XML response if the above request fails
        try:
            return jsonify(api_response.json())
        except ValueError:
            return jsonify({"error": "Invalid JSON from FatSecret API", "raw": api_response.text})
    except requests.RequestException as e:
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__": # Only run when the application starts
    app.run()