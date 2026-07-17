import re
from supabase import Client
from backend.utils import paginate_query


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

    def log_workout(self, uid: str, name: str | None, date: str, duration_seconds: int, exercises: list[dict], workout_id: str | None = None) -> dict:
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
            "p_workout_id": workout_id,
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
        workouts = paginate_query(query)

        if not workouts:
            return {"workouts": [], "primary_muscles": {}, "secondary_muscles": {}, "pr_counts": {"weight": 0, "reps": 0, "volume": 0}}

        workout_ids = [w["workout_id"] for w in workouts]

        # fetch exercises for these workouts with muscle data in one query
        ex_rows = paginate_query(
            self._supabase.table("workout_exercises")
                .select("workout_id, workout_exercise_id, exercise_id")
                .in_("workout_id", workout_ids)
        )

        ex_ids = [e["workout_exercise_id"] for e in ex_rows]

        # fetch sets to compute volume per workout
        set_rows = paginate_query(
            self._supabase.table("workout_sets")
                .select("workout_exercise_id, reps, weight_kg")
                .in_("workout_exercise_id", ex_ids)
        ) if ex_ids else []

        # fetch muscle groups for built-in exercises
        builtin_ex_ids = list({e["exercise_id"] for e in ex_rows if e["exercise_id"] is not None})
        primary_counts: dict[str, int] = {}
        secondary_counts: dict[str, int] = {}
        if builtin_ex_ids:
            muscle_rows = self._supabase.table("exercise_muscles") \
                .select("exercise_id, muscle_type, muscle_groups(name)") \
                .in_("exercise_id", builtin_ex_ids) \
                .execute().data or []
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
        ex_rows = self._supabase.table("workout_exercises") \
            .select("workout_exercise_id, exercise_id") \
            .in_("workout_id", workout_ids) \
            .execute().data or []
        exercise_count = len(ex_rows)
        ex_ids = [exercise_row["workout_exercise_id"] for exercise_row in ex_rows]
        if not ex_ids:
            return {"volume_kg": 0.0, "exercises": 0, "sets": 0, "reps": 0, "duration_seconds": duration_seconds, "primary_muscles": [], "secondary_muscles": []}
        set_rows = self._supabase.table("workout_sets") \
            .select("reps, weight_kg") \
            .in_("workout_exercise_id", ex_ids) \
            .execute().data or []
        total_sets = len(set_rows)
        total_reps = sum(set_row["reps"] or 0 for set_row in set_rows)
        total_volume = sum((set_row["reps"] or 0) * (set_row["weight_kg"] or 0.0) for set_row in set_rows)
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
        ex_by_template: dict[str, list[dict]] = {}
        for exercise_row in ex_rows:
            tid = exercise_row["template_id"]
            if tid not in ex_by_template:
                ex_by_template[tid] = []
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
        ex_by_template: dict[str, list[dict]] = {}
        for exercise_row in ex_rows:
            tid = exercise_row["template_id"]
            if tid not in ex_by_template:
                ex_by_template[tid] = []
            ex_by_template[tid].append({"exercise_name": exercise_row["exercise_name"], "exercise_order": exercise_row["exercise_order"]})
        community_uids = list({routine_row["uid"] for routine_row in community_rows if routine_row.get("uid")})
        username_map: dict[str, str] = {}
        if community_uids:
            user_rows = self._supabase.table("users") \
                .select("uid, username") \
                .in_("uid", community_uids) \
                .execute().data or []
            for user_row in user_rows:
                username_map[user_row["uid"]] = user_row["username"]
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
                    _placeholders = ["Level Up! User", "Mystery Athlete", "Anonymous Lifter", "Unknown Warrior"]
                    item["creator_username"] = _placeholders[hash(routine_row["template_id"]) % len(_placeholders)]
            return item

        return {
            "featured": [build_item(routine_row, False) for routine_row in featured_rows],
            "community": [build_item(routine_row, True) for routine_row in community_rows],
        }

    def delete_routine(self, uid: str, template_id: str) -> None:
        row = self._supabase.table("workout_templates") \
            .select("is_public") \
            .eq("template_id", template_id) \
            .eq("uid", uid) \
            .single() \
            .execute().data
        if not row:
            return
        if row.get("is_public"):
            # public routines appear in the community browse section so we keep the row but
            # detach it from the user by setting uid to null
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
