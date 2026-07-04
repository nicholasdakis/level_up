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
    
    def get_leaderboard_standing(self, uid: str):
        # Returns the user's rank and total player count using a single SQL query
        user = self._supabase.table("users").select("level, exp_points").eq("uid", uid).single().execute().data
        if not user:
            return None

        level = user["level"]
        exp_points = user["exp_points"]

        # Count users ranked strictly above using the same tiebreaker as the leaderboard (level DESC, exp_points DESC, uid ASC)
        above = self._supabase.rpc("count_users_above_rank", {
            "p_level": level,
            "p_exp_points": exp_points,
            "p_uid": uid,
        }).execute().data

        total = self._supabase.table("users").select("uid", count="exact").execute().count

        return {
            "rank": (above or 0) + 1,
            "total": total,
        }

    def get_leaderboard(self):
        # Fetches all users ordered by level and XP descending for the leaderboard
        result = self._supabase.table("users").select("uid, username, level, exp_points, pfp_base64").order("level", desc=True).order("exp_points", desc=True).order("uid", desc=False).execute()
        return result.data

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

    def get_food_logs_by_uids_and_date(self, uids: list[str], date: str):
        # Fetch food logs for snapshot users on given date
        result = (
            self._supabase.table("food_logs")
            .select("*")
            .in_("uid", uids)
            .eq("date", date)
            .execute()
        )
        return result.data
    
    def get_streaks(self, uid: str):
        # Fetches all streak rows for a user
        result = self._supabase.table("streaks").select("streak_type, streak, highest_streak").eq("uid", uid).execute()
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

    # Write operations

    # Method to update the user's data
    def set_user_data(self, uid: str, data: dict):
        self._supabase.table("users").update(data).eq("uid", uid).execute()

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

    def get_food_logs(self, uid: str):
        # Fetches all food log rows for a user
        result = self._supabase.table("food_logs").select("*").eq("uid", uid).execute()
        return result.data

    def get_food_logs_v2(self, uid: str):
        # Fetches normalized food log rows, one per food item, sorted by date and logged_at
        result = (
            self._supabase.table("food_logs_v2")
            .select("*")
            .eq("uid", uid)
            .order("date", desc=False)
            .order("logged_at", desc=False)
            .execute()
        )
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
        incoming_ids = [i["id"] for i in valid_items if i.get("id")]

        # Delete any DB rows for this date whose id is not in the incoming list (handles deletions)
        # If no ids are incoming at all, delete everything for this date
        query = self._supabase.table("food_logs_v2").delete().eq("uid", uid).eq("date", date)
        if incoming_ids:
            query = query.not_.in_("id", incoming_ids)
        query.execute()

        # Split into existing rows (have an id, upsert in place) and new rows (no id, insert fresh)
        existing = [i for i in valid_items if i.get("id")]
        new_items = [i for i in valid_items if not i.get("id")]

        results = []

        if existing:
            for item in existing:
                row = build_row(item)
                row["id"] = item["id"]  # include id so Postgres matches the existing row
                res = self._supabase.table("food_logs_v2").upsert(row).execute()
                results.extend(res.data)

        if new_items:
            # No id provided, Postgres generates one and sets logged_at to NOW()
            rows = [build_row(i) for i in new_items]
            res = self._supabase.table("food_logs_v2").insert(rows).execute()
            results.extend(res.data)

        return results

    def get_water_logs(self, uid: str):
        result = self._supabase.table("water_logs").select("*").eq("uid", uid).execute()
        return result.data

    def upsert_water_log(self, uid: str, date: str, entries_ml: list):
        self._supabase.table("water_logs").upsert({
            "uid": uid,
            "date": date,
            "entries_ml": entries_ml,
        }).execute()

    def get_weight_logs(self, uid: str):
        result = self._supabase.table("weight_logs").select("*").eq("uid", uid).execute()
        return result.data

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

    def _save_sets_and_collect_stats(self, workout_exercise_id: str, sets: list[dict]) -> dict:
        # batch inserts all sets for one exercise and returns per-set stats needed for PR tracking
        set_count = 0
        best_weight: float | None = None
        best_reps: int | None = None
        last_weight: float | None = None
        last_reps: int | None = None
        session_volume = 0.0
        set_rows = []
        for set_data in sets:
            reps = set_data.get("reps")
            weight_kg = set_data.get("weight_kg")
            set_rows.append({
                "workout_exercise_id": workout_exercise_id,
                "set_number": set_data["set_number"],
                "reps": reps,
                "weight_kg": weight_kg,
                "set_type": "working",
            })
            set_count += 1
            last_weight = weight_kg
            last_reps = reps
            if weight_kg is not None and reps is not None:
                session_volume += weight_kg * reps
                if best_weight is None or weight_kg > best_weight:
                    best_weight = weight_kg
                if best_reps is None or reps > best_reps:
                    best_reps = reps
        if set_rows:
            self._supabase.table("workout_sets").insert(set_rows).execute()
        return {
            "set_count": set_count,
            "best_weight": best_weight,
            "best_reps": best_reps,
            "last_weight": last_weight,
            "last_reps": last_reps,
            "session_volume": session_volume,
        }

    def _upsert_exercise_stats(self, uid: str, exercise_name: str, stats: dict) -> None:
        # last_* always updated, PR fields only updated if this session beat the stored value
        best_weight = stats["best_weight"]
        best_reps = stats["best_reps"]
        session_volume = stats["session_volume"]

        # Epley formula: weight * (1 + reps/30) estimates the 1-rep max from a submaximal set
        estimated_1rm: float | None = None
        if best_weight and best_reps:
            estimated_1rm = round(best_weight * (1 + best_reps / 30), 2)

        existing_stats = self._supabase.table("user_exercise_stats") \
            .select("pr_weight_kg, pr_reps, pr_volume_kg, estimated_1rm, total_sets") \
            .eq("uid", uid) \
            .eq("exercise_name", exercise_name) \
            .execute().data
        if existing_stats:
            current = existing_stats[0]
            new_pr_weight = best_weight if (best_weight and (current["pr_weight_kg"] is None or best_weight > current["pr_weight_kg"])) else current["pr_weight_kg"]
            new_pr_reps = best_reps if (best_reps and (current["pr_reps"] is None or best_reps > current["pr_reps"])) else current["pr_reps"]
            new_pr_volume = round(session_volume, 2) if (session_volume and (current["pr_volume_kg"] is None or session_volume > current["pr_volume_kg"])) else current["pr_volume_kg"]
            new_1rm = estimated_1rm if (estimated_1rm and (current["estimated_1rm"] is None or estimated_1rm > current["estimated_1rm"])) else current["estimated_1rm"]
            self._supabase.table("user_exercise_stats").update({
                "pr_weight_kg": new_pr_weight,
                "pr_reps": new_pr_reps,
                "pr_volume_kg": new_pr_volume,
                "estimated_1rm": new_1rm,
                "last_weight_kg": stats["last_weight"],
                "last_reps": stats["last_reps"],
                "last_logged_at": "now()",
                "total_sets": (current["total_sets"] or 0) + stats["set_count"],
            }).eq("uid", uid).eq("exercise_name", exercise_name).execute()
        else:
            self._supabase.table("user_exercise_stats").insert({
                "uid": uid,
                "exercise_name": exercise_name,
                "pr_weight_kg": best_weight,
                "pr_reps": best_reps,
                "pr_volume_kg": round(session_volume, 2) if session_volume else None,
                "estimated_1rm": estimated_1rm,
                "last_weight_kg": stats["last_weight"],
                "last_reps": stats["last_reps"],
                "last_logged_at": "now()",
                "total_sets": stats["set_count"],
            }).execute()

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

    def get_recent_exercises(self, uid: str, limit: int = 25) -> list[dict]:
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
            .select("name") \
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
        return self.create_routine(uid=uid, name=template["name"], exercises=exercises, source_template_id=template_id)

    def get_browse_routines(self, uid: str) -> dict:
        # fetch featured (uid IS NULL) and community (uid not null, is_public true) separately
        featured_rows = self._supabase.table("workout_templates") \
            .select("template_id, name, estimated_duration_minutes, like_count, download_count") \
            .is_("uid", "null") \
            .eq("is_public", True) \
            .order("like_count", desc=True) \
            .order("download_count", desc=True) \
            .order("created_at", desc=True) \
            .execute().data or []
        community_rows = self._supabase.table("workout_templates") \
            .select("template_id, name, estimated_duration_minutes, uid, like_count, download_count") \
            .not_.is_("uid", "null") \
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
                item["creator_username"] = username_map.get(routine_row["uid"])
            return item

        return {
            "featured": [build_item(routine_row, False) for routine_row in featured_rows],
            "community": [build_item(routine_row, True) for routine_row in community_rows],
        }

    def delete_routine(self, uid: str, template_id: str) -> None:
        # only delete if the user owns the routine
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
