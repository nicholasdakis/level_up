# Repository Layer: the only place in the backend that reads/writes Supabase, so DB logic is only in these classes and can be easily swapped if ever needed

import re
from supabase import Client
from backend.valid_achievements import VALID_ACHIEVEMENT_IDS

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
        # Checks if a user exists by email — used before Google Sign-In to enforce TOS for new users
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

    def get_referral_count(self, uid: str) -> int:
        result = self._supabase.table("referrals").select("referee_uid", count="exact").eq("referrer_uid", uid).execute()
        return result.count or 0

    def has_used_referral(self, uid: str) -> bool:
        result = self._supabase.table("referrals").select("referee_uid").eq("referee_uid", uid).limit(1).execute()
        return len(result.data) > 0

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

    # Method to update the user's data
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

    # Atomically record the visit, update XP, and set a 24 hour cooldown for that poi
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
        # query is built incrementally so the cutoff filter can be conditionally added before executing
        query = (
            self._supabase.table("food_logs_v2")
            .select("*")
            .eq("uid", uid)
        )
        if cutoff:
            query = query.gte("date", cutoff)  # filter in the DB to avoid fetching rows that will be discarded
        return query.order("date", desc=False).order("logged_at", desc=False).execute().data

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
            query = query.gte("date", cutoff)  # filter in the DB to avoid fetching rows that will be discarded
        return query.execute().data

    def upsert_water_log(self, uid: str, date: str, entries_ml: list):
        self._supabase.table("water_logs").upsert({
            "uid": uid,
            "date": date,
            "entries_ml": entries_ml,
        }).execute()

    def get_weight_logs(self, uid: str, cutoff: str | None = None):
        query = self._supabase.table("weight_logs").select("*").eq("uid", uid)
        if cutoff:
            query = query.gte("date", cutoff)  # filter in the DB to avoid fetching rows that will be discarded
        return query.execute().data

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
            **data # unpack the data which is in the same format as the goals table
        }).execute()
    
    def get_goals(self, uid: str):
        result = self._supabase.table("goals").select("*").eq("uid", uid).execute()
        if result.data:
            return result.data[0]
        return None

class WorkoutRepository:
    def __init__(self, supabase: Client):
        self._supabase = supabase

    def _create_workout(self, uid: str, name: str | None, date: str, duration_seconds: int) -> str:
        workout_row = self._supabase.table("workouts").insert({
            "uid": uid,
            "name": name,
            "date": date,
            "duration_seconds": duration_seconds,
            "completed": True,
        }).execute().data[0]
        return workout_row["workout_id"]

    def log_workout(self, uid: str, name: str | None, date: str, duration_seconds: int, exercises: list[dict]) -> dict:
        # strip parenthetical suffixes from exercise names before sending to the RPC
        clean = []
        for ex in exercises:
            clean.append({
                **ex,
                "exercise_name": re.sub(r'\s*\(.*?\)\s*$', '', ex["exercise_name"]).strip(),
            })
        result = self._supabase.rpc("log_workout", {
            "p_uid": uid,
            "p_name": name,
            "p_date": date,
            "p_duration_seconds": duration_seconds,
            "p_exercises": clean,
        }).execute()
        return result.data

    def get_workout_analytics(self, uid: str, since: str | None = None) -> dict:
        # fetch workouts
        query = self._supabase.table("workouts") \
            .select("workout_id, name, date, duration_seconds") \
            .eq("uid", uid) \
            .eq("completed", True) \
            .order("date", desc=False)
        if since:
            query = query.gte("date", since)
        workouts = query.execute().data or []

        if not workouts:
            return {"workouts": [], "primary_muscles": {}, "secondary_muscles": {}, "pr_counts": {"weight": 0, "reps": 0, "volume": 0}}

        workout_ids = [w["workout_id"] for w in workouts]

        # fetch exercises for these workouts with muscle data in one query
        ex_rows = self._supabase.table("workout_exercises") \
            .select("workout_id, workout_exercise_id, exercise_id") \
            .in_("workout_id", workout_ids) \
            .execute().data or []

        ex_ids = [e["workout_exercise_id"] for e in ex_rows]

        # fetch sets to compute volume per workout
        set_rows = self._supabase.table("workout_sets") \
            .select("workout_exercise_id, reps, weight_kg") \
            .in_("workout_exercise_id", ex_ids) \
            .execute().data or [] if ex_ids else []

        # fetch muscle groups for built-in exercises
        builtin_ex_ids = list({e["exercise_id"] for e in ex_rows if e["exercise_id"] is not None})
        primary_counts: dict[str, int] = {}
        secondary_counts: dict[str, int] = {}
        if builtin_ex_ids:
            muscle_rows = self._supabase.table("exercise_muscles") \
                .select("exercise_id, muscle_type, muscle_groups(name)") \
                .in_("exercise_id", builtin_ex_ids) \
                .execute().data or []
            # map exercise_id -> muscles so we can count per workout occurrence
            ex_id_to_muscles: dict[int, dict] = {}
            for row in muscle_rows:
                eid = row["exercise_id"]
                name = (row.get("muscle_groups") or {}).get("name")
                if not name:
                    continue
                if eid not in ex_id_to_muscles:
                    ex_id_to_muscles[eid] = {"primary": set(), "secondary": set()}
                ex_id_to_muscles[eid][row["muscle_type"]].add(name)
            for ex in ex_rows:
                eid = ex["exercise_id"]
                if eid is None:
                    continue
                muscles = ex_id_to_muscles.get(eid, {})
                for m in muscles.get("primary", set()):
                    primary_counts[m] = primary_counts.get(m, 0) + 1
                for m in muscles.get("secondary", set()):
                    secondary_counts[m] = secondary_counts.get(m, 0) + 1

        # compute volume per workout
        vol_by_weid: dict[str, float] = {}
        for s in set_rows:
            weid = s["workout_exercise_id"]
            vol_by_weid[weid] = vol_by_weid.get(weid, 0.0) + (s["reps"] or 0) * (s["weight_kg"] or 0.0)
        ex_by_wid: dict[str, list] = {}
        for e in ex_rows:
            ex_by_wid.setdefault(e["workout_id"], []).append(e["workout_exercise_id"])
        vol_by_wid: dict[str, float] = {}
        for wid, weids in ex_by_wid.items():
            vol_by_wid[wid] = sum(vol_by_weid.get(weid, 0.0) for weid in weids)

        # fetch PR counts for the range
        pr_query = self._supabase.table("pr_history").select("pr_type").eq("uid", uid)
        if since:
            pr_query = pr_query.gte("achieved_at", since)
        pr_rows = pr_query.execute().data or []
        pr_counts = {"weight": 0, "reps": 0, "volume": 0}
        for r in pr_rows:
            t = r["pr_type"]
            if t in pr_counts:
                pr_counts[t] += 1

        workout_list = [
            {
                "workout_id": w["workout_id"],
                "name": w["name"],
                "date": w["date"],
                "duration_seconds": w["duration_seconds"] or 0,
                "volume_kg": round(vol_by_wid.get(w["workout_id"], 0.0), 2),
            }
            for w in workouts
        ]

        return {
            "workouts": workout_list,
            "primary_muscles": primary_counts,
            "secondary_muscles": secondary_counts,
            "pr_counts": pr_counts,
        }

    def get_pr_summary(self, uid: str, since: str | None = None) -> dict:
        # counts PRs broken per type in the given date range
        query = self._supabase.table("pr_history") \
            .select("pr_type") \
            .eq("uid", uid)
        if since:
            query = query.gte("achieved_at", since)
        rows = query.execute().data or []
        counts = {"weight": 0, "reps": 0, "volume": 0}
        for r in rows:
            t = r["pr_type"]
            if t in counts:
                counts[t] += 1
        return counts

    def get_every_prev_set(self, uid: str, exercise_names: list[str]) -> list[dict]:
        # calls the RPC that returns all sets from the most recent session per exercise
        return self._supabase.rpc("get_every_prev_set", {
            "p_uid": uid,
            "p_exercise_names": exercise_names,
        }).execute().data or []

    def get_exercise_stats(self, uid: str) -> list[dict]:
        return self._supabase.table("user_exercise_stats") \
            .select("exercise_name, pr_weight_kg, pr_reps, pr_volume_kg, estimated_1rm, last_weight_kg, last_reps, total_sets") \
            .eq("uid", uid) \
            .execute().data or []

    def get_recent_workouts(self, uid: str, limit: int = 10) -> list[dict]:
        # Orders by created_at (timestamp) rather than date (date-only) so two sessions
        # on the same day are returned in the correct chronological order
        result = self._supabase.table("workouts") \
            .select("workout_id, name, date, duration_seconds, created_at") \
            .eq("uid", uid) \
            .eq("completed", True) \
            .order("created_at", desc=True) \
            .limit(limit) \
            .execute()
        return result.data or []

    def delete_workout(self, uid: str, workout_id: str) -> bool:
        # uid filter enforces ownership so a user cannot delete another user's workout
        result = self._supabase.table("workouts").delete().eq("workout_id", workout_id).eq("uid", uid).execute()
        return bool(result.data)

    def get_workout_heatmap(self, uid: str, weeks: int = 12) -> list[dict]:
        from datetime import date, timedelta
        since = (date.today() - timedelta(weeks=weeks)).isoformat()
        rows = self._supabase.table("workouts") \
            .select("date") \
            .eq("uid", uid) \
            .eq("completed", True) \
            .gte("date", since) \
            .execute().data or []
        counts: dict[str, int] = {}
        for row in rows:
            d = row["date"]
            counts[d] = counts.get(d, 0) + 1
        return [{"date": d, "count": c} for d, c in sorted(counts.items())]

    def get_pr_summary(self, uid: str, since: str | None = None) -> dict:
        # counts PRs broken per type in the given date range
        query = self._supabase.table("pr_history") \
            .select("pr_type") \
            .eq("uid", uid)
        if since:
            query = query.gte("achieved_at", since)
        rows = query.execute().data or []
        counts = {"weight": 0, "reps": 0, "volume": 0}
        for r in rows:
            t = r["pr_type"]
            if t in counts:
                counts[t] += 1
        return counts

    def get_workout_history(self, uid: str, since: str | None = None) -> list[dict]:
        query = self._supabase.table("workouts") \
            .select("workout_id, name, date, duration_seconds, created_at") \
            .eq("uid", uid) \
            .eq("completed", True) \
            .order("date", desc=False)
        if since:
            query = query.gte("date", since)
        workouts = query.execute().data or []
        if not workouts:
            return []
        workout_ids = [w["workout_id"] for w in workouts]
        ex_rows = self._supabase.table("workout_exercises") \
            .select("workout_id, workout_exercise_id") \
            .in_("workout_id", workout_ids) \
            .execute().data or []
        ex_ids = [e["workout_exercise_id"] for e in ex_rows]
        set_rows = self._supabase.table("workout_sets") \
            .select("workout_exercise_id, reps, weight_kg") \
            .in_("workout_exercise_id", ex_ids) \
            .execute().data or [] if ex_ids else []
        volume_by_workout: dict[str, float] = {}
        for s in set_rows:
            weid = s["workout_exercise_id"]
            vol = (s["reps"] or 0) * (s["weight_kg"] or 0.0)
            volume_by_workout[weid] = volume_by_workout.get(weid, 0.0) + vol
        ex_count_by_workout: dict[str, int] = {}
        volume_by_workout_id: dict[str, float] = {}
        for e in ex_rows:
            wid = e["workout_id"]
            weid = e["workout_exercise_id"]
            ex_count_by_workout[wid] = ex_count_by_workout.get(wid, 0) + 1
            volume_by_workout_id[wid] = volume_by_workout_id.get(wid, 0.0) + volume_by_workout.get(weid, 0.0)
        return [
            {
                "workout_id": w["workout_id"],
                "name": w["name"],
                "date": w["date"],
                "duration_seconds": w["duration_seconds"] or 0,
                "volume_kg": round(volume_by_workout_id.get(w["workout_id"], 0.0), 2),
                "exercise_count": ex_count_by_workout.get(w["workout_id"], 0),
            }
            for w in workouts
        ]

    def get_today_overview(self, uid: str) -> dict:
        from datetime import date
        today = date.today().isoformat()
        # fetch all completed workouts for today
        workouts = self._supabase.table("workouts") \
            .select("workout_id, duration_seconds") \
            .eq("uid", uid) \
            .eq("completed", True) \
            .eq("date", today) \
            .execute().data or []
        if not workouts:
            return {"volume_kg": 0.0, "exercises": 0, "sets": 0, "reps": 0, "duration_seconds": 0, "primary_muscles": [], "secondary_muscles": []}
        workout_ids = [w["workout_id"] for w in workouts]
        duration_seconds = sum(w["duration_seconds"] or 0 for w in workouts)
        # fetch all exercises logged in those workouts
        ex_rows = self._supabase.table("workout_exercises") \
            .select("workout_exercise_id, exercise_id") \
            .in_("workout_id", workout_ids) \
            .execute().data or []
        exercise_count = len(ex_rows)
        ex_ids = [exercise_row["workout_exercise_id"] for exercise_row in ex_rows]
        if not ex_ids:
            return {"volume_kg": 0.0, "exercises": 0, "sets": 0, "reps": 0, "duration_seconds": duration_seconds, "primary_muscles": [], "secondary_muscles": []}
        # fetch all sets for those exercises
        set_rows = self._supabase.table("workout_sets") \
            .select("reps, weight_kg") \
            .in_("workout_exercise_id", ex_ids) \
            .execute().data or []
        total_sets = len(set_rows)
        total_reps = sum(set_row["reps"] or 0 for set_row in set_rows)
        total_volume = sum((set_row["reps"] or 0) * (set_row["weight_kg"] or 0.0) for set_row in set_rows)
        # fetch primary and secondary muscles worked via the exercises table
        builtin_ex_ids = [exercise_row["exercise_id"] for exercise_row in ex_rows if exercise_row["exercise_id"] is not None]
        primary_muscles: list[str] = []
        secondary_muscles: list[str] = []
        if builtin_ex_ids:
            muscle_rows = self._supabase.table("exercise_muscles") \
                .select("muscle_type, muscle_groups(name)") \
                .in_("exercise_id", builtin_ex_ids) \
                .execute().data or []
            seen_primary: set[str] = set()
            seen_secondary: set[str] = set()
            for row in muscle_rows:
                name = (row.get("muscle_groups") or {}).get("name")
                if not name:
                    continue
                if row["muscle_type"] == "primary" and name not in seen_primary:
                    seen_primary.add(name)
                    primary_muscles.append(name)
                elif row["muscle_type"] == "secondary" and name not in seen_secondary:
                    seen_secondary.add(name)
                    secondary_muscles.append(name)
        return {
            "volume_kg": round(total_volume, 2),
            "exercises": exercise_count,
            "sets": total_sets,
            "reps": total_reps,
            "duration_seconds": duration_seconds,
            "primary_muscles": primary_muscles,
            "secondary_muscles": secondary_muscles,
        }

    def get_weekly_workout_count(self, uid: str) -> int:
        from datetime import date, timedelta
        today = date.today()
        week_start = today - timedelta(days=today.weekday())  # most recent Monday
        result = self._supabase.table("workouts") \
            .select("workout_id", count="exact") \
            .eq("uid", uid) \
            .eq("completed", True) \
            .gte("date", week_start.isoformat()) \
            .execute()
        return result.count or 0

    def get_recent_exercises(self, uid: str, limit: int = 8) -> list[dict]:
        # DISTINCT ON keeps the latest occurrence of each exercise_name across all sessions
        result = self._supabase.rpc("get_recent_exercises", {
            "p_uid": uid,
            "p_limit": limit,
        }).execute()
        return result.data or []

    def search_exercises(self, uid: str, q: str, equipment: list[str], muscle: list[str], level: list[str], limit: int = 30) -> list[dict]:
        result = self._supabase.rpc("search_exercises", {
            "p_uid": uid,
            "p_q": q,
            "p_equipment": [e.lower() for e in equipment],
            "p_muscle": [m.lower() for m in muscle],
            "p_level": [l.lower() for l in level],
            "p_limit": limit,
        }).execute()
        return result.data or []

    def _resolve_muscle_ids(self, muscles: list[str]) -> list[int]:
        # Looks up muscle_group ids by name, returns only those that matched
        if not muscles:
            return []
        ids = []
        for muscle in muscles:
            row = self._supabase.table("muscle_groups") \
                .select("id").ilike("name", muscle).limit(1).execute().data
            if row:
                ids.append(row[0]["id"])
        return ids

    def create_custom_exercise(self, uid: str, name: str, primary_muscle: str | None, secondary_muscles: list[str], equipment: str | None, level: str | None) -> dict:
        # Insert the custom exercise row
        row = self._supabase.table("exercises").insert({
            "name": name,
            "equipment": equipment,
            "level": level,
            "is_custom": True,
            "is_public": False,
            "created_by": uid,
        }).execute().data[0]
        exercise_id = row["id"]
        muscle_rows = []
        if primary_muscle:
            primary_ids = self._resolve_muscle_ids([primary_muscle])
            for mid in primary_ids:
                muscle_rows.append({"exercise_id": exercise_id, "muscle_id": mid, "muscle_type": "primary"})
        for mid in self._resolve_muscle_ids(secondary_muscles):
            muscle_rows.append({"exercise_id": exercise_id, "muscle_id": mid, "muscle_type": "secondary"})
        if muscle_rows:
            self._supabase.table("exercise_muscles").insert(muscle_rows).execute()
        return {"exercise_id": exercise_id, "name": name}

    def edit_custom_exercise(self, uid: str, exercise_id: int, name: str, primary_muscle: str | None, secondary_muscles: list[str], equipment: str | None, level: str | None) -> None:
        # Verify ownership before updating
        existing = self._supabase.table("exercises") \
            .select("id") \
            .eq("id", exercise_id) \
            .eq("created_by", uid) \
            .eq("is_custom", True) \
            .limit(1).execute().data
        if not existing:
            raise ValueError("Exercise not found or not owned by user")
        self._supabase.table("exercises").update({
            "name": name,
            "equipment": equipment,
            "level": level,
        }).eq("id", exercise_id).execute()
        # Replace all muscle links
        self._supabase.table("exercise_muscles").delete().eq("exercise_id", exercise_id).execute()
        muscle_rows = []
        if primary_muscle:
            for mid in self._resolve_muscle_ids([primary_muscle]):
                muscle_rows.append({"exercise_id": exercise_id, "muscle_id": mid, "muscle_type": "primary"})
        for mid in self._resolve_muscle_ids(secondary_muscles):
            muscle_rows.append({"exercise_id": exercise_id, "muscle_id": mid, "muscle_type": "secondary"})
        if muscle_rows:
            self._supabase.table("exercise_muscles").insert(muscle_rows).execute()

    def create_routine(self, uid: str, name: str, exercises: list[dict], source_template_id: str | None = None, estimated_duration_minutes: int | None = None) -> str:
        row = self._supabase.table("workout_templates").insert({
            "uid": uid,
            "name": name,
            "is_public": False,
            "source_template_id": source_template_id,
            "estimated_duration_minutes": estimated_duration_minutes,
        }).execute().data[0]
        template_id = row["template_id"]
        if exercises:
            self._supabase.table("workout_template_exercises").insert([
                {
                    "template_id": template_id,
                    "exercise_id": ex.get("exercise_id"),
                    "exercise_name": ex["exercise_name"],
                    "exercise_order": ex["exercise_order"],
                    "default_sets": ex.get("default_sets", 3),
                }
                for ex in exercises
            ]).execute()
        return template_id

    def get_my_routines(self, uid: str) -> list[dict]:
        # fetch all templates owned by the user, newest first
        templates = self._supabase.table("workout_templates") \
            .select("template_id, name, created_at, source_template_id") \
            .eq("uid", uid) \
            .order("created_at", desc=True) \
            .execute().data or []
        if not templates:
            return []
        template_ids = [template["template_id"] for template in templates]
        # batch-fetch all exercises for those templates, joining muscle data via the exercises table
        ex_rows = self._supabase.table("workout_template_exercises") \
            .select("template_id, exercise_id, exercise_name, exercise_order, exercises(exercise_muscles(muscle_type, muscle_groups(name)))") \
            .in_("template_id", template_ids) \
            .order("exercise_order") \
            .execute().data or []
        # group exercises by template_id to attach them without N+1 queries
        ex_by_template: dict[str, list[dict]] = {}
        for exercise_row in ex_rows:
            tid = exercise_row["template_id"]
            if tid not in ex_by_template:
                ex_by_template[tid] = []
            # extract primary and secondary muscles from the joined data
            primary_muscle = None
            secondary_muscles = []
            for em in (exercise_row.get("exercises") or {}).get("exercise_muscles") or []:
                muscle_name = (em.get("muscle_groups") or {}).get("name")
                if not muscle_name:
                    continue
                if em.get("muscle_type") == "primary" and primary_muscle is None:
                    primary_muscle = muscle_name
                elif em.get("muscle_type") == "secondary":
                    secondary_muscles.append(muscle_name)
            ex_by_template[tid].append({
                "exercise_id": exercise_row["exercise_id"],
                "exercise_name": exercise_row["exercise_name"],
                "exercise_order": exercise_row["exercise_order"],
                "primary_muscle": primary_muscle or "",
                "secondary_muscles": secondary_muscles,
            })
        return [
            {
                "template_id": template["template_id"],
                "name": template["name"],
                "exercise_count": len(ex_by_template.get(template["template_id"], [])),
                "exercises": ex_by_template.get(template["template_id"], []),
                "created_at": template["created_at"],
                "source_template_id": template.get("source_template_id"),
            }
            for template in templates
        ]

    def copy_routine(self, uid: str, template_id: str) -> str:
        # copy a public browse template into the user's own routines (uid set, is_public false)
        template = self._supabase.table("workout_templates") \
            .select("name, estimated_duration_minutes") \
            .eq("template_id", template_id) \
            .single() \
            .execute().data
        if not template:
            raise ValueError("template not found")
        exercises = self._supabase.table("workout_template_exercises") \
            .select("exercise_id, exercise_name, exercise_order") \
            .eq("template_id", template_id) \
            .order("exercise_order") \
            .execute().data or []
        # insert into routine_downloads; primary key (uid, template_id) prevents duplicates
        # only increment download_count if this is the first time this user downloads this template
        result = self._supabase.table("routine_downloads").upsert(
            {"uid": uid, "template_id": template_id},
            on_conflict="uid,template_id",
            ignore_duplicates=True,
        ).execute()
        if result.data:
            self._supabase.rpc("increment_download_count", {"tid": template_id}).execute()
        # reuse create_routine so the new copy gets its own template_id, tracking the source
        return self.create_routine(uid=uid, name=template["name"], exercises=exercises, estimated_duration_minutes=template.get("estimated_duration_minutes"), source_template_id=template_id)

    def get_browse_routines(self, uid: str) -> dict:
        # featured routines are curated (is_featured = true); community routines are user-submitted (is_public = true, is_featured = false)
        featured_rows = self._supabase.table("workout_templates") \
            .select("template_id, name, estimated_duration_minutes, like_count, download_count") \
            .eq("is_featured", True) \
            .eq("is_public", True) \
            .order("like_count", desc=True) \
            .order("download_count", desc=True) \
            .order("created_at", desc=True) \
            .execute().data or []
        community_rows = self._supabase.table("workout_templates") \
            .select("template_id, name, estimated_duration_minutes, uid, like_count, download_count") \
            .eq("is_featured", False) \
            .eq("is_public", True) \
            .order("like_count", desc=True) \
            .order("download_count", desc=True) \
            .order("created_at", desc=True) \
            .limit(20) \
            .execute().data or []
        all_ids = [r["template_id"] for r in featured_rows + community_rows]
        if not all_ids:
            return {"featured": [], "community": []}
        ex_rows = self._supabase.table("workout_template_exercises") \
            .select("template_id, exercise_name, exercise_order") \
            .in_("template_id", all_ids) \
            .order("exercise_order") \
            .execute().data or []
        # group exercises by template_id to avoid N+1 queries
        ex_by_template: dict[str, list[dict]] = {}
        for exercise_row in ex_rows:
            tid = exercise_row["template_id"]
            if tid not in ex_by_template:
                ex_by_template[tid] = []
            ex_by_template[tid].append({"exercise_name": exercise_row["exercise_name"], "exercise_order": exercise_row["exercise_order"]})
        # fetch usernames for community routine creators
        community_uids = list({routine_row["uid"] for routine_row in community_rows if routine_row.get("uid")})
        username_map: dict[str, str] = {}
        if community_uids:
            user_rows = self._supabase.table("users") \
                .select("uid, username") \
                .in_("uid", community_uids) \
                .execute().data or []
            for user_row in user_rows:
                username_map[user_row["uid"]] = user_row["username"]
        # fetch which templates this user has already liked in one query
        liked_rows = self._supabase.table("likes") \
            .select("content_id") \
            .eq("uid", uid) \
            .eq("content_type", "routine") \
            .in_("content_id", all_ids) \
            .execute().data or []
        liked_ids = {like_row["content_id"] for like_row in liked_rows}

        def build_item(routine_row: dict, is_community: bool) -> dict:
            exercises = ex_by_template.get(routine_row["template_id"], [])
            item = {
                "template_id": routine_row["template_id"],
                "name": routine_row["name"],
                "exercise_count": len(exercises),
                "exercises": exercises,
                "estimated_duration_minutes": routine_row.get("estimated_duration_minutes"),
                "like_count": routine_row.get("like_count", 0),
                "download_count": routine_row.get("download_count", 0),
                "liked_by_me": routine_row["template_id"] in liked_ids,
            }
            if is_community:
                if routine_row.get("uid"):
                    item["creator_username"] = username_map.get(routine_row["uid"])
                else:
                    # uid is null when the creator deleted their copy; pick a placeholder deterministically
                    # using template_id so the same routine always shows the same name across requests
                    _placeholders = ["Level Up! User", "Mystery Athlete", "Anonymous Lifter", "Unknown Warrior"]
                    item["creator_username"] = _placeholders[hash(routine_row["template_id"]) % len(_placeholders)]
            return item

        return {
            "featured": [build_item(routine_row, False) for routine_row in featured_rows],
            "community": [build_item(routine_row, True) for routine_row in community_rows],
        }

    def delete_routine(self, uid: str, template_id: str) -> None:
        # fetch the routine owned by this user to check its visibility before deciding how to delete it
        row = self._supabase.table("workout_templates") \
            .select("is_public") \
            .eq("template_id", template_id) \
            .eq("uid", uid) \
            .single() \
            .execute().data
        if not row:
            # row is None if the template_id doesn't exist or doesn't belong to this user, nothing to do
            return
        if row.get("is_public"):
            # public routines appear in the community browse section so we keep the row but
            # detach it from the user by setting uid to null; it will show a placeholder username
            self._supabase.table("workout_templates") \
                .update({"uid": None}) \
                .eq("template_id", template_id) \
                .eq("uid", uid) \
                .execute()
        else:
            # private routines are only visible to the owner so it is safe to fully delete them
            self._supabase.table("workout_templates") \
                .delete() \
                .eq("template_id", template_id) \
                .eq("uid", uid) \
                .execute()

    def like_routine(self, uid: str, template_id: str) -> None:
        # insert is a no-op if already liked due to the unique constraint
        self._supabase.table("likes").upsert({
            "uid": uid,
            "content_type": "routine",
            "content_id": template_id,
        }, on_conflict="uid,content_type,content_id").execute()

    def unlike_routine(self, uid: str, template_id: str) -> None:
        self._supabase.table("likes") \
            .delete() \
            .eq("uid", uid) \
            .eq("content_type", "routine") \
            .eq("content_id", template_id) \
            .execute()

    def delete_custom_exercise(self, uid: str, exercise_id: int) -> None:
        # Verify ownership before deleting
        existing = self._supabase.table("exercises") \
            .select("id") \
            .eq("id", exercise_id) \
            .eq("created_by", uid) \
            .eq("is_custom", True) \
            .limit(1).execute().data
        if not existing:
            raise ValueError("Exercise not found or not owned by user")
        self._supabase.table("exercises").delete().eq("id", exercise_id).execute()

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
        if achievement_id not in VALID_ACHIEVEMENT_IDS:
            raise ValueError(f"Unknown achievement: {achievement_id}")
        # Call the RPC method which atomically updates and returns the new progress amount
        result = self._supabase.rpc("upsert_achievement_progress", {
            "p_uid": uid,
            "p_achievement_id": achievement_id,
            "p_increment_amount": increment_amount,
        }).execute()
        return {"achievement_id": achievement_id, "new_progress_amount": result.data}

    def set_achievement_progress(self, uid: str, achievement_id: str, value: int):
        if achievement_id not in VALID_ACHIEVEMENT_IDS:
            raise ValueError(f"Unknown achievement: {achievement_id}")
        # Sets progress to an exact value instead of incrementing (e.g. used for streaks)
        result = self._supabase.rpc("set_achievement_progress", {
            "p_uid": uid,
            "p_achievement_id": achievement_id,
            "p_value": value,
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
        result = self._supabase.table("reminders").select("*").eq("uid", uid).order("scheduled_at", desc=False).execute()
        return result.data

    def get_due_reminders(self, now_iso: str):
        # Fetches all reminders where the scheduled time has passed
        return self._supabase.table("reminders").select("*").lte("scheduled_at", now_iso).execute().data

    def delete_reminder(self, reminder_id: str, uid: str | None = None):
        # uid=None is used by the FCM dispatcher so multiple server instances don't double-send the same reminder
        # uid=uid is used by user-facing deletes to enforce ownership at the DB level in the same query
        query = self._supabase.table("reminders").delete().eq("id", reminder_id)
        if uid:
            query = query.eq("uid", uid)
        result = query.execute()
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


class PremiumPerksRepository:
    # Handles the premium_perks table, monthly consumable allowances for premium users

    def __init__(self, supabase: Client):
        self._supabase = supabase

    def get_or_create_perks(self, uid: str) -> dict:
        # Fetches the row, creating it with defaults if it doesn't exist yet
        result = self._supabase.table("premium_perks").select("*").eq("uid", uid).execute()
        if result.data:
            return result.data[0]
        from datetime import datetime, timezone
        now = datetime.now(timezone.utc)
        # Calculate the 1st of next month as the initial reset date
        next_reset = datetime(now.year if now.month < 12 else now.year + 1, now.month % 12 + 1, 1, tzinfo=timezone.utc)
        row = {"uid": uid, "shield_count": 3, "shields_reset_at": next_reset.isoformat()}
        self._supabase.table("premium_perks").insert(row).execute()
        return row

    def reset_perks_if_month_elapsed(self, uid: str, row: dict) -> dict:
        # Refills shield_count to 3 if shields_reset_at has passed, then advances the reset date
        from datetime import datetime, timezone
        reset_at_str = row.get("shields_reset_at", "")
        if not reset_at_str:
            return row
        reset_at = datetime.fromisoformat(reset_at_str.replace("Z", "+00:00"))
        if datetime.now(timezone.utc) < reset_at:
            return row  # still within the current month window, no reset needed
        now = datetime.now(timezone.utc)
        next_reset = datetime(now.year if now.month < 12 else now.year + 1, now.month % 12 + 1, 1, tzinfo=timezone.utc)
        updated = {"shield_count": 3, "shields_reset_at": next_reset.isoformat()}
        self._supabase.table("premium_perks").update(updated).eq("uid", uid).execute()
        return {**row, **updated}

    def apply_streak_shield(self, uid: str) -> dict:
        # Spends one shield and restores the daily streak atomically via RPC
        result = self._supabase.rpc("apply_streak_shield", {"p_uid": uid}).execute()
        row = result.data[0] if result.data else {}
        return {"shield_count": row.get("out_shield_count", 0), "restored_streak": row.get("out_restored_streak", 0)}
