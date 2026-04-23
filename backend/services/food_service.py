import requests
from datetime import timedelta
from backend.utils import to_utc_datetime
from backend.repository import RateLimitRepository


class FoodService:
    def __init__(self, token_manager, rate_limit_repo: RateLimitRepository, client_id: str, client_secret: str):
        self._token_manager = token_manager
        self._rate_limit_repo = rate_limit_repo
        self._client_id = client_id
        self._client_secret = client_secret

    def get_access_token(self):
        """Request an access token from FatSecret"""
        token_url = "https://oauth.fatsecret.com/connect/token"
        data = {"grant_type": "client_credentials", "scope": "basic"}
        try:
            response = requests.post(token_url, data=data, auth=(self._client_id, self._client_secret))
            response.raise_for_status()
            return response.json().get("access_token")
        except requests.RequestException:
            return None

    def get_next_reset_time(self):
        # Get the rate_limits row for food_logging from Postgres
        last_refill_time = self._rate_limit_repo.get_last_refill_time("food_logging")
        if not last_refill_time:
            return None
        # Timestamp to datetime conversion
        last_refill_dt = to_utc_datetime(last_refill_time)
        # Reset time is 1 day after the last refill
        reset_time = last_refill_dt + timedelta(days=1)
        return reset_time

    def call_fatsecret(self, food_name: str, timeout: int):
        # Calls the FatSecret API, refunding the token on any failure
        access_token = self.get_access_token()
        if not access_token:
            self._token_manager.refund()
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
                self._token_manager.refund()
                raise RuntimeError(f"FatSecret API error: {api_response.status_code}")
            return api_response
        except requests.RequestException as e:
            self._token_manager.refund()
            raise RuntimeError(str(e))
