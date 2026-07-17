import re
from supabase import Client
from backend.utils import paginate_query


class UserRepository:
    # Repository class to handle all Postgres operations related to user data

    def __init__(self, supabase: Client):
        self._supabase = supabase

    # Read operations

    def user_exists(self, uid: str) -> bool:
        # Checks if a user row exists in Supabase without creating anything
        result = self._supabase.table("users").select("uid").eq("uid", uid).execute()
        return len(result.data) > 0

    def user_exists_by_email(self, email: str) -> bool:
        # Checks if a user exists by email, used before Google Sign-In to enforce TOS for new users
        result = self._supabase.table("users").select("uid").eq("email", email).execute()
        return len(result.data) > 0

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

    def get_leaderboard_standing(self, uid: str, type: str = "xp"):
        # Returns the user's rank and total player count for the given leaderboard type
        if type == "foods":
            result = self._supabase.rpc("get_foods_standing", {"p_uid": uid}).execute().data
            row = result[0] if result else {}
            return {"rank": row.get("rank"), "total": row.get("total", 0)}
        if type == "workouts":
            result = self._supabase.rpc("get_workouts_standing", {"p_uid": uid}).execute().data
            row = result[0] if result else {}
            return {"rank": row.get("rank"), "total": row.get("total", 0)}
        user = self._supabase.table("users").select("level, exp_points").eq("uid", uid).single().execute().data
        if not user:
            return None
        result = self._supabase.rpc("get_xp_standing", {
            "p_level": user["level"],
            "p_exp_points": user["exp_points"],
            "p_uid": uid,
        }).execute().data
        row = result[0] if result else {}
        return {"rank": row.get("rank"), "total": row.get("total", 0)}

    def get_leaderboard(self):
        # Fetches top 100 users ordered by level and XP descending for the leaderboard
        result = self._supabase.table("users").select("uid, username, level, exp_points, pfp_base64, is_premium").order("level", desc=True).order("exp_points", desc=True).order("uid", desc=False).limit(101).execute()
        return result.data

    def get_leaderboard_by_foods(self, since: str | None):
        # Delegates to a Supabase RPC that does the GROUP BY and LIMIT 100 in SQL
        params = {"since_date": since} if since else {}
        return self._supabase.rpc("leaderboard_by_foods", params).execute().data

    def get_leaderboard_by_workouts(self, since: str | None):
        # Delegates to a Supabase RPC that does the GROUP BY and LIMIT 100 in SQL
        params = {"since_date": since} if since else {}
        return self._supabase.rpc("leaderboard_by_workouts", params).execute().data

    def get_users_by_offsets(self, offsets: list[int]):
        # Fetch the users whose utc_offset_minutes matches the targets
        result = (
            self._supabase.table("users")
            .select("*")
            .in_("utc_offset_minutes", offsets)
            .execute()
        )
        return result.data

    def get_streaks_by_uids(self, uids: list[str]):
        # Fetch all streaks for snapshot users
        result = (
            self._supabase.table("streaks")
            .select("*")
            .in_("uid", uids)
            .execute()
        )
        return result.data

    def get_achievements_by_uids(self, uids: list[str]):
        # Fetch achievement progress for snapshot users
        result = (
            self._supabase.table("achievement_progress")
            .select("*")
            .in_("uid", uids)
            .execute()
        )
        return result.data

    def get_claims_by_uids(self, uids: list[str]):
        # Fetch achievement claims for snapshot users
        result = (
            self._supabase.table("achievement_claims")
            .select("*")
            .in_("uid", uids)
            .execute()
        )
        return result.data

    def get_food_logs_v2_by_uids_and_date(self, uids: list[str], date: str):
        # Fetch normalized food log rows for snapshot users on a given date
        result = (
            self._supabase.table("food_logs_v2")
            .select("uid, meal, food_name, calories, protein, carbs, fat")
            .in_("uid", uids)
            .eq("date", date)
            .execute()
        )
        return result.data

    def get_streaks(self, uid: str):
        # Fetches all streak rows for a user
        result = self._supabase.table("streaks").select("streak_type, streak, highest_streak, last_date").eq("uid", uid).execute()
        return result.data

    def get_referral_code(self, uid: str):
        # Returns the user's referral code, or None if they don't have one yet
        result = self._supabase.table("users").select("referral_code").eq("uid", uid).limit(1).execute()
        if result.data:
            return result.data[0]["referral_code"]
        return None

    def get_referral_summary(self, uid: str) -> dict:
        result = self._supabase.rpc("get_referral_summary", {"p_uid": uid}).execute()
        row = result.data[0] if result.data else {}
        return {"referral_count": row.get("referral_count", 0), "referral_used": row.get("referral_used", False)}

    def referral_code_exists(self, code: str) -> bool:
        result = self._supabase.table("users").select("referral_code").eq("referral_code", code).limit(1).execute()
        return len(result.data) > 0

    def store_referral_code(self, uid: str, code: str):
        # Stores the generated referral code on the user's row
        self._supabase.table("users").update({"referral_code": code}).eq("uid", uid).execute()

    def get_pending_referral_reward(self, uid: str):
        # Returns referrals where the referee used the code but the referrer hasn't received their XP yet
        result = self._supabase.table("referrals").select(
            "referee_uid, users!referrals_referee_uid_fkey(username)"
        ).eq("referrer_uid", uid).eq("referee_xp_awarded", True).eq("referrer_xp_awarded", False).limit(1).execute()
        return result.data

    def claim_referral_reward(self, referrer_uid: str, referee_uid: str) -> dict:
        result = self._supabase.rpc("claim_referral_reward", {
            "p_referrer_uid": referrer_uid,
            "p_referee_uid": referee_uid,
        }).execute()
        return result.data

    def use_referral(self, uid: str, referral_code: str) -> dict:
        result = self._supabase.rpc("use_referral", {
            "p_referee_uid": uid,
            "p_referral_code": referral_code,
        }).execute()
        return result.data

    def get_user_settings(self, uid: str) -> dict:
        result = self._supabase.table("user_settings").select("*").eq("uid", uid).execute()
        defaults = {"units": "metric", "notifications_enabled": True, "recent_foods_max": 20}
        if not result.data:
            return defaults
        return {**defaults, **result.data[0]}

    # Write operations

    def set_user_data(self, uid: str, data: dict):
        self._supabase.table("users").update(data).eq("uid", uid).execute()

    def set_user_settings(self, uid: str, data: dict):
        self._supabase.table("user_settings").upsert({"uid": uid, **data}).execute()

    def upsert_daily_snapshots(self, rows: list[dict]):
        # Method for adding the user's snapshot into the table
        self._supabase.table("daily_snapshots").upsert(rows).execute()

    # Atomic instructions

    def claim_daily_reward_transaction(self, uid: str, new_level: int, new_exp: int):
        # Call the Supabase RPC to ensure the operation is done atomically
        result = self._supabase.rpc("claim_daily_reward", {
            "p_uid": uid,
            "p_new_level": new_level,
            "p_new_exp": new_exp
        }).execute()
        return result.data

    def record_poi_visit_transaction(self, uid: str, poi_name: str, poi_category: str, new_level: int, new_exp: int):
        # Call the record_poi_visit Postgres function via RPC to handle the operation atomically, which also handles the 24-hour cooldown and achievements
        result = self._supabase.rpc("record_poi_visit", {
            "p_uid": uid,
            "p_poi_name": poi_name,
            "p_category": poi_category,
            "p_new_level": new_level,
            "p_new_exp": new_exp
        }).execute()
        return result.data

    def initialize_user_if_new(self, uid: str, email: str = None):
        # Insert a default row for a first-time user, but do nothing if they already exist
        from datetime import datetime, timezone
        row = {"uid": uid, "username": uid, "created_at": datetime.now(timezone.utc).isoformat()}
        if email:
            row["email"] = email # store email so it can be looked up later for TOS enforcement
        self._supabase.table("users").upsert(
            row,
            on_conflict="uid",  # If a row with this uid already exists, do nothing
            ignore_duplicates=True
        ).execute()

    # Methods for the full user data load

    def get_food_logs_v2(self, uid: str, cutoff: str | None = None):
        # Fetches normalized food log rows, one per food item, sorted by date and logged_at
        query = self._supabase.table("food_logs_v2").select("*").eq("uid", uid)
        if cutoff:
            query = query.gte("date", cutoff)
        return paginate_query(query.order("date", desc=False).order("logged_at", desc=False))

    def upsert_food_log_v2(self, uid: str, date: str, items: list):
        # Upserts food log rows for a given date
        # Items with an id are upserted in place (preserving logged_at)
        # Items without an id are inserted fresh
        # Rows in the DB for this (uid, date) that are not in the incoming list are deleted
        def build_row(item):
            desc = item.get("food_description") or ""
            def from_desc(pattern, d=desc):
                m = re.search(pattern, d, re.IGNORECASE)
                return float(m.group(1)) if m else None
            def macro(key, pattern):
                v = item.get(key)
                return float(v) if v is not None else from_desc(pattern)
            return {
                "uid": uid,
                "date": date,
                "meal": item.get("meal"),
                "food_name": item.get("food_name"),
                "brand_name": item.get("brand_name"),
                "food_description": desc or None,
                "food_id": item.get("food_id"),
                "calories": item.get("calories"),
                "protein": macro("protein", r"Protein:\s*([\d.]+)"),
                "carbs": macro("carbs", r"Carbs:\s*([\d.]+)"),
                "fat": macro("fat", r"Fat:\s*([\d.]+)"),
                "fiber": macro("fiber", r"Fiber:\s*([\d.]+)"),
                "sugar": macro("sugar", r"Sugar:\s*([\d.]+)"),
                "sodium": macro("sodium", r"Sodium:\s*([\d.]+)"),
                "serving_size": item.get("serving_size") or (re.search(r"Per\s+(.+?)\s*-", desc) or [None, None])[1],
            }

        valid_items = [i for i in items if i and i.get("food_name")]

        # Split into existing rows (have an id, upsert in place) and new rows (no id, insert fresh)
        existing = [i for i in valid_items if i.get("id")]
        new_items = [i for i in valid_items if not i.get("id")]

        results = []

        if existing:
            # batch all existing rows into a single upsert instead of one per row
            rows = []
            for item in existing:
                row = build_row(item)
                row["id"] = item["id"]  # include id so Postgres matches the existing row
                rows.append(row)
            res = self._supabase.table("food_logs_v2").upsert(rows).execute()
            results.extend(res.data)

        if new_items:
            # No id provided, Postgres generates one and sets logged_at to NOW()
            rows = [build_row(i) for i in new_items]
            res = self._supabase.table("food_logs_v2").insert(rows).execute()
            results.extend(res.data)

        # Delete DB rows for this date whose id is not in the final result set
        # Uses result IDs (not incoming_ids) so newly inserted rows are included in the exclusion list
        # Done after writes succeed so a failed insert does not wipe existing rows
        # Skip the delete sweep entirely when valid_items is empty to avoid wiping every food log for this entire day
        if valid_items:
            result_ids = [r["id"] for r in results if r.get("id")]
            query = self._supabase.table("food_logs_v2").delete().eq("uid", uid).eq("date", date)
            if result_ids:
                query = query.not_.in_("id", result_ids)
            query.execute()

        return results

    def get_recent_foods(self, uid: str, limit: int) -> list:
        # Uses an RPC so DISTINCT ON runs inside Postgres before any rows are sent to the client
        result = self._supabase.rpc("get_recent_foods", {"p_uid": uid, "p_limit": limit}).execute()
        return result.data or []

    def get_suggested_foods(self, uid: str, meal: str) -> list:
        # Uses an RPC so scoring runs inside Postgres, no row limit issues
        result = self._supabase.rpc(
            "get_suggested_foods",
            {"p_uid": uid, "p_meal": meal if meal else None, "p_limit": 20}
        ).execute()
        return result.data or []

    def get_food_logs_for_date(self, uid: str, date: str) -> list:
        return (
            self._supabase.table("food_logs_v2")
            .select("*")
            .eq("uid", uid)
            .eq("date", date)
            .order("logged_at", desc=False)
            .execute()
            .data
        )

    def add_food_log(self, uid: str, date: str, item: dict) -> dict:
        row = {
            "uid": uid,
            "date": date,
            "meal": item.get("meal"),
            "food_name": item.get("food_name"),
            "brand_name": item.get("brand_name"),
            "food_description": item.get("food_description") or None,
            "food_id": item.get("food_id"),
            "calories": item.get("calories"),
            "protein": item.get("protein"),
            "carbs": item.get("carbs"),
            "fat": item.get("fat"),
            "fiber": item.get("fiber"),
            "sugar": item.get("sugar"),
            "sodium": item.get("sodium"),
            "serving_size": item.get("serving_size"),
        }
        res = self._supabase.table("food_logs_v2").insert(row).execute()
        return res.data[0] if res.data else {}

    def delete_food_log(self, uid: str, food_id: str):
        self._supabase.table("food_logs_v2").delete().eq("id", food_id).eq("uid", uid).execute()

    def get_water_logs(self, uid: str, cutoff: str | None = None):
        query = self._supabase.table("water_logs").select("*").eq("uid", uid)
        if cutoff:
            query = query.gte("date", cutoff)
        return paginate_query(query.order("date", desc=False))

    def upsert_water_log(self, uid: str, date: str, entries_ml: list):
        self._supabase.table("water_logs").upsert({
            "uid": uid,
            "date": date,
            "entries_ml": entries_ml,
        }).execute()

    def get_weight_logs(self, uid: str, cutoff: str | None = None):
        query = self._supabase.table("weight_logs").select("*").eq("uid", uid)
        if cutoff:
            query = query.gte("date", cutoff)
        return paginate_query(query.order("date", desc=False))

    def upsert_weight_log(self, uid: str, date: str, weight_kg: float):
        self._supabase.table("weight_logs").upsert({
            "uid": uid,
            "date": date,
            "weight_kg": weight_kg,
        }).execute()

    def delete_weight_log(self, uid: str, date: str):
        self._supabase.table("weight_logs").delete().eq("uid", uid).eq("date", date).execute()

    def update_food_streak(self, uid: str):
        # Calls the update_food_streak RPC to compute and update the food logging streak
        result = self._supabase.rpc("update_food_streak", {
            "p_uid": uid,
        }).execute()
        return result.data

    def add_fcm_token(self, uid: str, token: str):
        # Single atomic UPDATE via RPC
        self._supabase.rpc("add_fcm_token", {"p_uid": uid, "p_token": token}).execute()

    def remove_fcm_token(self, uid: str, token: str):
        # Single atomic UPDATE via RPC
        self._supabase.rpc("remove_fcm_token", {"p_uid": uid, "p_token": token}).execute()

    def update_utc_offset_minutes(self, uid: str, utc_offset: int):
        self._supabase.table("users").update({"utc_offset_minutes": utc_offset}).eq("uid", uid).execute()

    def set_premium(self, uid: str, is_premium: bool, expires_at: str | None, purchase_token: str | None = None):
        # Sets the user's premium status and expiry timestamp
        payload: dict = {
            "is_premium": is_premium,
            "premium_expires_at": expires_at,
        }
        if purchase_token is not None:
            payload["purchase_token"] = purchase_token
        self._supabase.table("users").update(payload).eq("uid", uid).execute()

    def get_uid_by_purchase_token(self, token: str) -> str | None:
        # Looks up the uid associated with a Play purchase token
        result = self._supabase.table("users").select("uid").eq("purchase_token", token).limit(1).execute()
        return result.data[0]["uid"] if result.data else None

    def get_premium_status(self, uid: str) -> dict:
        # Returns is_premium and premium_expires_at for the user
        result = self._supabase.table("users") \
            .select("is_premium, premium_expires_at") \
            .eq("uid", uid) \
            .execute()
        return result.data[0] if result.data else {"is_premium": False, "premium_expires_at": None}

    def update_user_xp(self, uid: str, new_level: int, new_exp: int):
        # Uses award_ad_xp RPC for row-level locking to prevent double-awarding from concurrent SSV callbacks
        self._supabase.rpc("award_ad_xp", {
            "p_uid": uid,
            "p_new_level": new_level,
            "p_new_exp": new_exp,
        }).execute()

    def upsert_goals(self, uid: str, data: dict):
        # Insert or update goals row for this user
        self._supabase.table("goals").upsert({
            "uid": uid,
            **data
        }).execute()

    def get_goals(self, uid: str):
        result = self._supabase.table("goals").select("*").eq("uid", uid).execute()
        if result.data:
            return result.data[0]
        return None
