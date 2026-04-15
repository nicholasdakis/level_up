# Repository Layer: the only place in the backend that reads/writes Supabase, so DB logic is only in these classes and can be easily swapped if ever needed

from supabase import Client

class UserRepository:
    # Repository class to handle all Postgres operations related to user data

    def __init__(self, supabase: Client):
        self._supabase = supabase

    # Read operations

    def username_exists(self, uid: str, username: str):
        # Check if the proposed username is taken by another user (case-insensitive because username is a CITEXT), ignoring the user themselves
        result = self._supabase.table("users").select("uid").eq("username", username).neq("uid", uid).execute()
        return len(result.data) > 0

    def get_user(self, uid: str):
        # Fetches the user's row from the users table
        result = self._supabase.table("users").select("*").eq("uid", uid).execute()
        return result.data[0] if result.data else None

    def get_user_fcm_tokens(self, uid: str):
        # Fetches only the fcm_tokens array for a given user
        result = self._supabase.table("users").select("fcm_tokens").eq("uid", uid).execute()
        if not result.data:
            return None
        return result.data[0].get("fcm_tokens") or []
    
    def get_leaderboard(self):
        # Fetches all users ordered by level and XP descending for the leaderboard
        result = self._supabase.table("users").select("uid, username, level, exp_points, pfp_base64").order("level", desc=True).order("exp_points", desc=True).execute()
        return result.data

    # Write operations (non-atomic)

    # Method to update the user's data
    def set_user_data(self, uid: str, data: dict):
        self._supabase.table("users").update(data).eq("uid", uid).execute()

    def update_fcm_tokens(self, uid: str, tokens: list):
        # Overwrites the user's fcm_tokens list
        self._supabase.table("users").update({"fcm_tokens": tokens}).eq("uid", uid).execute()

    # Atomic instructions

    def claim_daily_reward_transaction(self, uid: str, new_level: int, new_exp: int):
        # Call the Supabase RPC to ensure the operation is done atomically
        result = self._supabase.rpc("claim_daily_reward", {
            "p_uid": uid,
            "p_new_level": new_level,
            "p_new_exp": new_exp
        }).execute()
        return result.data

    # Atomically record the visit, update XP, and set a 24 hour cooldown for that poi
    def record_poi_visit_transaction(self, uid: str, poi_name: str, new_level: int, new_exp: int):
        # Call the record_poi_visit Postgres function via RPC to handle the operation atomically, which also handles the 24-hour cooldown
        result = self._supabase.rpc("record_poi_visit", {
            "p_uid": uid,
            "p_poi_name": poi_name,
            "p_new_level": new_level,
            "p_new_exp": new_exp
        }).execute()
        return result.data

    def initialize_user_if_new(self, uid: str):
        # Insert a default row for a first-time user, but do nothing if they already exist
        self._supabase.table("users").upsert(
            {
                "uid": uid,
                "level": 1,
                "exp_points": 0,
                "last_daily_claim": None,
                "can_claim_daily_reward": True
            },
            on_conflict="uid",  # If a row with this uid already exists, do nothing
            ignore_duplicates=True
        ).execute()

    # Methods for the full user data load

    def get_food_logs(self, uid: str):
        # Fetches all food log rows for a user
        result = self._supabase.table("food_logs").select("*").eq("uid", uid).execute()
        return result.data

    def upsert_food_log(self, uid: str, date: str, breakfast: list, lunch: list, dinner: list, snack: list):
        # Upserts a single date's food log (insert or update based on the (uid, date) primary key)
        self._supabase.table("food_logs").upsert({
            "uid": uid,
            "date": date,
            "breakfast": breakfast,
            "lunch": lunch,
            "dinner": dinner,
            "snack": snack,
        }).execute()

    def add_fcm_token(self, uid: str, token: str):
        # Appends a token to the fcm_tokens array if not already present
        user = self.get_user(uid)
        if user is None:
            return
        tokens = user.get("fcm_tokens") or []
        if token not in tokens:
            tokens.append(token)
            self._supabase.table("users").update({"fcm_tokens": tokens}).eq("uid", uid).execute()

    def remove_fcm_token(self, uid: str, token: str):
        # Removes a token from the fcm_tokens array
        user = self.get_user(uid)
        if user is None:
            return
        tokens = user.get("fcm_tokens") or []
        if token in tokens:
            tokens.remove(token)
            self._supabase.table("users").update({"fcm_tokens": tokens}).eq("uid", uid).execute()


class AchievementRepository: # Repository class to handle all Postgres operations related to achievements

    def __init__(self, supabase: Client):
        self._supabase = supabase

    def get_achievement_progress(self, uid: str):
        # Fetches all achievement progress rows for a user
        result = self._supabase.table("achievement_progress").select("achievement_id, progress").eq("uid", uid).execute()
        return result.data

    def get_achievement_claims(self, uid: str):
        # Fetches all claimed tiers for a user
        result = self._supabase.table("achievement_claims").select("achievement_id, tier, claimed_at").eq("uid", uid).execute()
        return result.data
    
    def upsert_achievement_progress(self, uid: str, achievement_id: str, increment_amount: int):
        # Call the RPC method which atomically updates and returns the new progress amount
        result = self._supabase.rpc("upsert_achievement_progress", {
            "p_uid": uid,
            "p_achievement_id": achievement_id,
            "p_increment_amount": increment_amount,
        }).execute()
        return {"achievement_id": achievement_id, "new_progress_amount": result.data}

    def claim_achievement(self, uid: str, achievement_id: str, tier: int):
        # Call the RPC method which atomically checks the claim is valid and claims the achievement
        try:
            self._supabase.rpc("claim_achievement", {
            "p_uid": uid,
            "p_achievement_id": achievement_id,
            "p_tier": tier,
            }).execute()
        except Exception as e:
            raise ValueError(str(e))

class ReminderRepository:
    # Repository class to handle all Postgres operations related to reminders

    def __init__(self, supabase: Client):
        self._supabase = supabase

    def set_reminder(self, uid: str, message: str, scheduled_at: str, notification_id: int):
        # Insert reminder into Postgres via Supabase
        result = (
            self._supabase
            .table("reminders")
            .insert({
                "uid": uid,
                "message": message,
                "scheduled_at": scheduled_at,
                "notification_id": notification_id,
            })
            .execute()
        )
        return result.data

    def get_reminders(self, uid: str):
        # Fetches all reminders for a user
        result = self._supabase.table("reminders").select("*").eq("uid", uid).execute()
        return result.data

    def get_due_reminders(self, now_iso: str):
        # Fetches all reminders where the scheduled time has passed
        return self._supabase.table("reminders").select("*").lte("scheduled_at", now_iso).execute().data

    def delete_reminder(self, reminder_id: str):
        # Atomically claims a reminder by deleting it; returns True if this instance claimed it
        result = self._supabase.table("reminders").delete().eq("id", reminder_id).execute()
        return bool(result.data)


class RateLimitRepository:
    # Repository class to handle all Postgres operations related to rate limits

    def __init__(self, supabase: Client):
        self._supabase = supabase

    def get_last_refill_time(self, limit_id: str):
        # Fetches the last_refill_time for a given rate_limit row
        result = self._supabase.table("rate_limits").select("last_refill_time").eq("id", limit_id).execute()
        if not result.data:
            return None
        return result.data[0].get("last_refill_time")
