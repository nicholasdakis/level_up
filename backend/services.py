# Service Layer: Contains business logic for progression, XP calculation, and cooldowns, etc
# Doesn't touch the Supabase Postgres DB directly, it only acts through repository.py and returns the results for the route in the end

import random
from math import pow, radians, sin, cos, sqrt, atan2
from datetime import datetime, timezone
from backend.utils import to_utc_datetime
from backend.repository import UserRepository

def experience_needed(level: int):
    # Calculate the XP required to reach the next level based on the formula in user_data_manager.dart
    raw = 100 * pow(1.25, level - 0.5) * 1.05 + (level * 10)
    return round(round(raw) / 10) * 10

def calculate_daily_reward_xp(level: int):
    # Calculate how much XP a daily reward gives, based on the formula in daily_rewards.dart
    return 25 * level + 2 * random.randint(1, level)

def calculate_level_up(current_level: int, current_exp: int, xp_gained: int):
    # Calculate the user's new level and XP after gaining XP, applying the level-up logic from user_data_manager.dart
    new_exp = current_exp + xp_gained
    new_level = current_level

    # Keeps leveling up as long as XP exceeds the threshold
    needed = experience_needed(new_level)
    while new_exp >= needed:
        new_exp -= needed        # carry over the remainder
        new_level += 1           # bump the level
        needed = experience_needed(new_level)  # recalculate for the new level

    return new_level, new_exp


class ProgressionService: # Service class to handle all progression-related business logic, called by server.py after authentication and validation
    def __init__(self, repo: UserRepository):
        # Store the repository so all methods can access the Supabase Postgres DB through it
        self._repo = repo

    def update_username(self, uid: str, username: str):
        if self._repo.username_exists(uid, username):
            return {"success": False, "error": "Username taken"} # Reads via the repository class and returns early without ever writing the update
        # Not atomic, but username is marked as UNIQUE so the same username write is impossible
        self._repo.set_user_data(uid, {"username": username}) # Successful, so write via the repository class
        return {"success": True}

    def get_progress(self, uid: str):
        # Gets a user's current progression state

        # Get the user's data to determine level, XP, and reward cooldown status
        user = self._repo.get_user(uid)

        # Fallback for users with no row yet
        if user is None:
            self._repo.initialize_user_if_new(uid)
            user = {"level": 1, "exp_points": 0, "last_daily_claim": None, "can_claim_daily_reward": True}

        level = user.get("level", 1) # default to level 1 if missing
        exp = user.get("exp_points", 0) # default to 0 XP if missing

        # Determine if the user can claim (23-hour cooldown)
        can_claim = True
        last_claim = user.get("last_daily_claim")
        if last_claim is not None:
            last_claim_dt = to_utc_datetime(last_claim)
            seconds_since = (datetime.now(timezone.utc) - last_claim_dt).total_seconds()

            # 23 hours = 82800 seconds
            can_claim = seconds_since >= 82800

        # Return user's data in the format expected by schemas.py
        return {
            "level": level,
            "exp_points": exp,
            "exp_needed": experience_needed(level),
            "can_claim_daily_reward": can_claim,
        }

    def claim_daily_reward(self, uid: str):
        # Processes a daily reward claim attempt, applying cooldown checks, XP calculation, and level-ups
        # Step 1: Get current state
        user = self._repo.get_user(uid)
        if user is None:
            # Fallback if user somehow claims before initialization
            self._repo.initialize_user_if_new(uid)
            user = {"level": 1, "exp_points": 0}

        current_level = user.get("level", 1) # default to level 1 if missing
        current_exp = user.get("exp_points", 0) # default to 0 XP if missing

        # Step 2: Calculate XP reward and apply level-ups based on the current state of the user
        xp_gained = calculate_daily_reward_xp(current_level)
        new_level, new_exp = calculate_level_up(current_level, current_exp, xp_gained)

        # Step 3: Write atomically via transaction so that if two requests come in at the same time, only one goes through
        result = self._repo.claim_daily_reward_transaction(uid, new_level, new_exp)

        if not result["claimed"]:
            # Cooldown not met. Return the rejection with time remaining
            return {
                "claimed": False,
                "xp_gained": 0,
                "new_level": current_level,
                "new_exp": current_exp,
                "seconds_remaining": result.get("seconds_remaining", 0),
            }

        # Successful return with the new progression state
        return {
            "claimed": True,
            "xp_gained": xp_gained,
            "new_level": new_level,
            "new_exp": new_exp,
            "seconds_remaining": 0,
        }
    
    # Method to handle POI check-ins by verifying proximity, checking cooldowns, and granting XP
    def check_in_poi(self, uid: str, poi_name: str, poi_lat: float, poi_lng: float, user_lat: float, user_lng: float):
        # Step 1: Verify the user is actually close to the POI (within 30 meters using the haversine formula)
        distance = self._haversine(user_lat, user_lng, poi_lat, poi_lng)
        if distance > 30:
            return {
                "success": False,
                "xp_gained": 0,
                "new_level": 1,
                "new_exp": 0,
                "error": "Too far from this spot",
            }

        # Step 2: Get the user's current level and XP
        user = self._repo.get_user(uid)
        if user is None:
            self._repo.initialize_user_if_new(uid)
            user = {"level": 1, "exp_points": 0}

        current_level = user.get("level", 1)
        current_exp = user.get("exp_points", 0)

        # Step 3: Calculate XP reward for checking in (the higher the level, the higher the small bonus)
        xp_gained = 100 + random.randint(0, max(current_level, 0))

        # Step 4: Calculate the new level and XP after applying the reward
        new_level, new_exp = calculate_level_up(current_level, current_exp, xp_gained)

        # Step 5: Atomically record the visit and update XP (also checks 24h cooldown inside the transaction)
        result = self._repo.record_poi_visit_transaction(uid, poi_name, new_level, new_exp)

        if not result["success"]:
            return {
                "success": False,
                "xp_gained": 0,
                "new_level": current_level,
                "new_exp": current_exp,
                "error": result.get("error", "Check-in failed"),
            }

        # Step 6: Successful check-in
        return {
            "success": True,
            "xp_gained": xp_gained,
            "new_level": new_level,
            "new_exp": new_exp,
            "error": None,
        }

    # The haversine formula finds the shortest path between two points (lat1, lng1 and lat2, lng2) on a sphere (Earth)
    def _haversine(self, lat1: float, lng1: float, lat2: float, lng2: float):
        earth_radius = 6371000 # Earth's radius in meters
        d_lat = radians(lat2 - lat1) # change / difference in latitude, converted to radians because the formula assumes radians
        d_lng = radians(lng2 - lng1) # change / difference in longitude, converted to radians because the formula assumes radians
        lat1 = radians(lat1)
        lat2 = radians(lat2)
        # The formula is d = R * c, where R = earth_radius and c is:
        a = (
            sin(d_lat / 2) ** 2 +
            cos(lat1) * cos(lat2) *
            sin(d_lng / 2) ** 2
        )
        c = 2 * atan2(sqrt(a), sqrt(1 - a)) # convert angular distance to radians
        return earth_radius * c # multiply by Earth's radius to get meters

    def get_user_data(self, uid: str):
        # Returns all user fields plus food logs and reminders in one call
        user = self._repo.get_user(uid)
        if user is None:
            self._repo.initialize_user_if_new(uid)
            user = self._repo.get_user(uid)

        # Determine daily reward eligibility
        can_claim = True
        last_claim = user.get("last_daily_claim")
        if last_claim is not None:
            last_claim_dt = to_utc_datetime(last_claim)
            seconds_since = (datetime.now(timezone.utc) - last_claim_dt).total_seconds()
            can_claim = seconds_since >= 82800

        food_logs = self._repo.get_food_logs(uid)
        reminders = self._repo.get_reminders(uid)

        return {
            "level": user.get("level", 1),
            "exp_points": user.get("exp_points", 0),
            "exp_needed": experience_needed(user.get("level", 1)),
            "can_claim_daily_reward": can_claim,
            "pfp_base64": user.get("pfp_base64"),
            "username": user.get("username") or uid,
            "app_color": user.get("app_color"),
            "fcm_tokens": user.get("fcm_tokens") or [],
            "notifications_enabled": user.get("notifications_enabled", True),
            "last_daily_claim": user.get("last_daily_claim"),
            "food_logs": food_logs,
            "reminders": reminders,
        }

    def update_pfp(self, uid: str, pfp_base64: str):
        # Updates the user's profile picture
        self._repo.set_user_data(uid, {"pfp_base64": pfp_base64})

    def update_app_color(self, uid: str, app_color: str):
        # Updates the user's app theme color (stored as a string)
        self._repo.set_user_data(uid, {"app_color": app_color})

    def update_notifications_enabled(self, uid: str, enabled: bool):
        # Updates the user's notification preference
        self._repo.set_user_data(uid, {"notifications_enabled": enabled})

    def add_fcm_token(self, uid: str, token: str):
        # Adds an FCM token to the user's list
        self._repo.add_fcm_token(uid, token)

    def remove_fcm_token(self, uid: str, token: str):
        # Removes an FCM token from the user's list
        self._repo.remove_fcm_token(uid, token)

    def get_food_logs(self, uid: str):
        # Returns all food logs for a user
        return self._repo.get_food_logs(uid)

    def upsert_food_log(self, uid: str, date: str, breakfast: list, lunch: list, dinner: list, snack: list):
        # Upserts a food log for a specific date
        self._repo.upsert_food_log(uid, date, breakfast, lunch, dinner, snack)

    def get_reminders(self, uid: str):
        # Returns all reminders for a user
        return self._repo.get_reminders(uid)

    def update_exp(self, uid: str, event: str, event_id: str):

        # Self-note: Make sure the events it checks are only handled by the backend and can't be written solely by the client

        # check which event triggered the XP gain and verify it actually happened
        xp_gained = 0

        # xp is granted based on verifying the event actually happened by checking the Supabase Postgres DB for the relevant data
        if event == "event1":
            pass  # TODO: verify workout exists in the Supabase Postgres DB and award XP
        elif event == "event2":
            pass  # TODO: verify badge exists and hasn't already awarded XP
        elif event == "event3":
            pass  # TODO: verify quest completion and award XP
        else:
            return {"error": "Unknown event type"}

        # no XP awarded yet since events are not implemented
        return {"new_level": None, "new_exp": None, "error": "Event not implemented yet"}