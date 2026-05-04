import random
from math import radians, sin, cos, sqrt, atan2
from datetime import datetime, timezone
from backend.utils import to_utc_datetime
from backend.repository import UserRepository, ReminderRepository, AchievementRepository
from backend.valid_achievements import SERVER_ACHIEVEMENT_IDS


def experience_needed(level: int):
    # Calculate the XP required to reach the next level based on the formula in user_data_manager.dart
    raw = 100 * (1.25 ** (level - 0.5)) * 1.05 + (level * 10)
    exp = round(raw)
    return round(exp / 10) * 10

def calculate_daily_reward_xp(level: int):
    # Calculate how much XP a daily reward gives, based on the formula in daily_rewards.dart
    return 25 * level + 2 * random.randint(1, level)

def streak_multiplier(streak: int) -> float:
    # Returns a bonus XP multiplier based on the user's current daily claim streak
    if streak >= 50:
        return 1.5
    elif streak >= 30:
        return 1.4
    elif streak >= 10:
        return 1.25
    elif streak >= 3:
        return 1.1
    return 1.0

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


# Threshold for if a user is moving too fast during a POI request
_POI_SPEED_THRESHOLD_MPS = 12.0


class ProgressionService: # Service class to handle all progression-related business logic, called by server.py after authentication and validation
    def __init__(self, repo: UserRepository, reminder_repo: ReminderRepository, achievement_repo: AchievementRepository):
        # Store the repositories so all methods can access the Supabase Postgres DB through them
        self._repo = repo
        self._reminder_repo = reminder_repo
        self._achievement_repo = achievement_repo
        # Per-user in-memory dictionary of the last POI fetch location and time for estimating if they have moved too fast between two requests
        self._last_poi_fetch: dict[str, tuple[float, float, datetime]] = {}

    # Helper method for checking if 23 hours have passed since the last daily claim
    def _can_claim_daily_reward(self, user: dict) -> bool:
        last_claim = user.get("last_daily_claim")
        if last_claim is None:
            return True
        seconds_since = (datetime.now(timezone.utc) - to_utc_datetime(last_claim)).total_seconds()
        return seconds_since >= 82800

    def is_moving_too_fast_for_poi(self, uid: str, lat: float, lng: float):

        now = datetime.now(timezone.utc)
        # Get the user's previous POI location and time if it exists
        prev = self._last_poi_fetch.get(uid)

        too_fast = False

        # Only runs if there is a previous location
        if prev is not None:
            prev_lat, prev_lng, prev_ts = prev

            elapsed = (now - prev_ts).total_seconds()

            if elapsed > 0:
                distance_moved = self._haversine(prev_lat, prev_lng, lat, lng)
                speed = distance_moved / elapsed
                # Check if speed exceeds threshold (likely impossible movement)
                too_fast = speed > _POI_SPEED_THRESHOLD_MPS

        # Update stored position for next comparison
        self._last_poi_fetch[uid] = (lat, lng, now)

        # Return whether movement was suspiciously fast
        return too_fast

    def update_utc_offset_minutes(self, uid: str, utc_offset: int):
        self._repo.update_utc_offset_minutes(uid, utc_offset)

    def _track_achievement(self, uid: str, achievement_id: str):
        # Silently increments achievement progress by 1, never breaking the caller if it fails
        if achievement_id not in SERVER_ACHIEVEMENT_IDS:
            print(f"[achievements] Rejected unknown server achievement: {achievement_id}")
            return
        try:
            self._achievement_repo.upsert_achievement_progress(uid, achievement_id, 1)
        except Exception as e:
            print(f"[achievements] Failed to track {achievement_id} for {uid}: {e}")

    def update_username(self, uid: str, username: str):
        if self._repo.username_exists(uid, username):
            return {"success": False, "error": "Username taken"} # Reads via the repository class and returns early without ever writing the update
        # Not atomic, but username is marked as UNIQUE so the same username write is impossible
        # Check if the user already has a real username (not their uid) before writing
        user = self._repo.get_user(uid)
        had_username = user and user.get("username") and user["username"] != uid

        self._repo.set_user_data(uid, {"username": username}) # Successful, so write via the repository class
        self._track_achievement(uid, "set_username")
        if had_username:
            self._track_achievement(uid, "change_username")
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
        can_claim = self._can_claim_daily_reward(user)

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

        # Step 2: Fetch current streak to apply multiplier
        streaks = self._repo.get_streaks(uid)
        current_streak = next(
            (s["streak"] for s in streaks if s["streak_type"] == "daily_consecutive_streak"),
            0,
        )

        # If more than 48 hours have passed since the last claim, the streak will reset to 1
        # inside the transaction. In that case the bonus doesn't apply
        last_claim_raw = user.get("last_daily_claim")
        streak_will_reset = True
        if last_claim_raw:
            seconds_since = (datetime.now(timezone.utc) - to_utc_datetime(last_claim_raw)).total_seconds()
            streak_will_reset = seconds_since >= 172800

        multiplier = 1.0 if streak_will_reset else streak_multiplier(current_streak)

        # Step 3: Calculate XP reward with streak multiplier and apply level-ups
        base_xp = calculate_daily_reward_xp(current_level)
        xp_gained = round(base_xp * multiplier)
        bonus_xp = xp_gained - base_xp
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

        # Track achievements for the successful claim
        self._track_achievement(uid, "daily_claims")
        if new_level > current_level:
            try:
                self._achievement_repo.set_achievement_progress(uid, "level", new_level)
            except Exception as e:
                print(f"[achievements] Failed to set level for {uid}: {e}")

        # Set the consecutive-day streak progress to the exact value from the DB
        daily_streak = result.get("daily_streak", 1)
        try:
            self._achievement_repo.set_achievement_progress(uid, "daily_claim_streak", daily_streak)
        except Exception as e:
            print(f"[achievements] Failed to set daily_claim_streak for {uid}: {e}")

        # Successful return with the new progression state
        return {
            "claimed": True,
            "xp_gained": xp_gained,
            "base_xp": base_xp,
            "bonus_xp": bonus_xp,
            "new_level": new_level,
            "new_exp": new_exp,
            "seconds_remaining": 0,
            "daily_streak": daily_streak,
            "streak_multiplier": multiplier,
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
        self._track_achievement(uid, "poi_visits")

        if new_level > current_level:
            try:
                self._achievement_repo.set_achievement_progress(uid, "level", new_level)
            except Exception as e:
                print(f"[achievements] Failed to sync level achievement: {e}")

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
        can_claim = self._can_claim_daily_reward(user)

        food_logs = self._repo.get_food_logs(uid)
        reminders = self._reminder_repo.get_reminders(uid)
        goals = self._repo.get_goals(uid)

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
            "goals": goals,
        }

    def update_pfp(self, uid: str, pfp_base64: str):
        # Updates the user's profile picture
        self._repo.set_user_data(uid, {"pfp_base64": pfp_base64})
        self._track_achievement(uid, "set_pfp")

    def update_app_color(self, uid: str, app_color: str):
        # Updates the user's app theme color (stored as a string)
        self._repo.set_user_data(uid, {"app_color": app_color})
        self._track_achievement(uid, "change_app_color")
        self._track_achievement(uid, "color_indecisive")

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
        self._track_achievement(uid, "food_logs")

        # Update the food logging streak and sync it to achievement progress
        try:
            food_streak = self._repo.update_food_streak(uid)
            self._achievement_repo.set_achievement_progress(uid, "food_streak", food_streak)
        except Exception as e:
            print(f"[achievements] Failed to update food_streak for {uid}: {e}")

    def get_reminders(self, uid: str):
        # Returns all reminders for a user
        return self._reminder_repo.get_reminders(uid)

    def set_reminder(self, uid: str, message: str, scheduled_at: str, notification_id: int):
        result = self._reminder_repo.set_reminder(
            uid=uid,
            message=message,
            scheduled_at=scheduled_at,
            notification_id=notification_id,
        )
        self._track_achievement(uid, "set_reminder")
        return result

    def delete_reminder(self, uid: str, reminder_id: str):
        # Verify the reminder belongs to this user before deleting
        reminders = self._reminder_repo.get_reminders(uid)
        if not any(r["id"] == reminder_id for r in reminders):
            return False
        deleted = self._reminder_repo.delete_reminder(reminder_id)
        if deleted:
            self._track_achievement(uid, "delete_reminder")
        return deleted

    def get_leaderboard(self):
        # Returns all users sorted by level and XP for the leaderboard
        return self._repo.get_leaderboard()

    def get_streaks(self, uid: str):
        # Fetches all streak rows for the user from the streaks table
        return self._repo.get_streaks(uid)

    def get_achievements(self, uid: str):
        # Fetches all achievement progress and claims for a user in one call
        progress = self._achievement_repo.get_achievement_progress(uid)
        claims = self._achievement_repo.get_achievement_claims(uid)
        return {
            "progress": progress,
            "claims": claims,
        }

    def claim_achievement(self, uid: str, achievement_id: str, tier: int):
        result = self._achievement_repo.claim_achievement(uid, achievement_id, tier)
        self._track_achievement(uid, "total_achievements")
        return result

    def update_goals(
        self,
        uid: str,
        calories_goal: int | None,
        protein_goal: int | None,
        carbs_goal: int | None,
        fat_goal: int | None,
        weight_goal_type: str | None,
    ):
        data = {
            "calories_goal": calories_goal,
            "protein_goal": protein_goal,
            "carbs_goal": carbs_goal,
            "fat_goal": fat_goal,
            "weight_goal_type": weight_goal_type,
            "last_updated": datetime.now(timezone.utc).isoformat(),
        }

        # Remove None values to not overwrite existing fields
        data = {k: v for k, v in data.items() if v is not None}

        # Call the repository to update the goals
        self._repo.upsert_goals(uid, data)
        return {"success": True}
