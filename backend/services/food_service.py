import json
import logging
import requests
from datetime import timedelta
from backend.utils import to_utc_datetime
from backend.repository import RateLimitRepository
from backend.redis_cache import FOOD_CACHE_TTL

logger = logging.getLogger(__name__)


class FoodService:
    def __init__(self, token_manager, rate_limit_repo: RateLimitRepository, client_id: str, client_secret: str, redis=None):
        self._token_manager = token_manager
        self._rate_limit_repo = rate_limit_repo
        self._client_id = client_id
        self._client_secret = client_secret
        self._redis = redis  # optional, used for caching food detail lookups

    def get_access_token(self):
        # Request an access token from FatSecret
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

    def _fetch_food_detail(self, food_id: str, timeout: int):
        # Calls food.get to retrieve full nutrition including fiber, sugar, sodium
        access_token = self.get_access_token()
        if not access_token:
            raise RuntimeError("Failed to get access token")

        headers = {"Authorization": f"Bearer {access_token}"}
        data = {
            "method": "food.get",
            "food_id": food_id,
            "format": "json",
        }

        try:
            api_response = requests.post(
                "https://platform.fatsecret.com/rest/server.api",
                headers=headers,
                data=data,
                timeout=timeout,
            )
            if api_response.status_code != 200:
                raise RuntimeError(f"FatSecret API error: {api_response.status_code}")
            return api_response
        except requests.RequestException as e:
            raise RuntimeError(str(e))

    def get_food_detail(self, food_id: str, timeout: int = 5) -> dict | None:
        # Returns the food detail dict from Redis cache or FatSecret, caching the result
        # Returns None if the lookup fails so callers can silently skip enrichment
        cache_key = f"food_detail:{food_id}"
        if self._redis:
            try:
                cached = self._redis.get(cache_key)
                if cached:
                    self._redis.incr("detail_cache_hits")
                    return json.loads(cached)
            except Exception as e:
                logger.warning(f"[Redis] food detail cache read failed for {food_id}: {e}")
        try:
            api_response = self._fetch_food_detail(food_id, timeout=timeout)
            detail = api_response.json()
            if self._redis:
                try:
                    self._redis.setex(cache_key, FOOD_CACHE_TTL, api_response.text)
                    self._redis.incr("detail_cache_misses")
                except Exception as e:
                    logger.warning(f"[Redis] food detail cache write failed for {food_id}: {e}")
            return detail
        except Exception as e:
            logger.warning(f"[FatSecret] food detail fetch failed for {food_id}: {e}")
            return None

    def extract_micros(self, detail: dict) -> dict:
        # Parses fiber, sugar, sodium from a food.get response
        # uses the first serving since it usually has the most complete data
        try:
            servings = detail.get("food", {}).get("servings", {}).get("serving", [])
            if isinstance(servings, dict):
                servings = [servings]
            if not servings:
                return {}
            s = servings[0]
            result = {}
            if s.get("fiber") is not None:
                result["fiber"] = float(s["fiber"])
            if s.get("sugar") is not None:
                result["sugar"] = float(s["sugar"])
            if s.get("sodium") is not None:
                result["sodium"] = float(s["sodium"])
            return result
        except Exception:
            return {}

    def enrich_search_response(self, response_dict: dict) -> dict:
        # Injects micros into each food item in a raw FatSecret foods.search response
        foods = response_dict.get("foods", {})
        items = foods.get("food")
        if not items:
            return response_dict
        if isinstance(items, dict):
            items = [items]
        enriched = []
        for item in items:
            item = dict(item)
            food_id = item.get("food_id")
            if food_id:
                detail = self.get_food_detail(food_id)
                if detail:
                    item.update(self.extract_micros(detail))
            enriched.append(item)
        response_dict = dict(response_dict)
        response_dict["foods"] = {**foods, "food": enriched}
        return response_dict

    def enrich_items_with_micros(self, items: list) -> list:
        # For each item with a food_id and no micros, fetch and inject fiber/sugar/sodium
        enriched = []
        for item in items:
            item = dict(item)
            food_id = item.get("food_id")
            missing = item.get("fiber") is None and item.get("sugar") is None and item.get("sodium") is None
            if food_id and missing:
                detail = self.get_food_detail(food_id)
                if detail:
                    item.update(self.extract_micros(detail))
            enriched.append(item)
        return enriched

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
