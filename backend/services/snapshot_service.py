from datetime import datetime, timezone
from collections import defaultdict
from backend.repository import UserRepository


class SnapshotService: # Service for building daily snapshots for users

    def __init__(self, user_repo: UserRepository):
        self.user_repo = user_repo

    def run(self, offsets: list[int]):
        # Get users in the target timezone
        users = self.user_repo.get_users_by_offsets(offsets)

        if not users:
            return 0

        uids = [u["uid"] for u in users]
        today = datetime.now(timezone.utc).date().isoformat()

        # Fetch related data in bulk
        streaks = self.user_repo.get_streaks_by_uids(uids)
        achievements = self.user_repo.get_achievements_by_uids(uids)
        claims = self.user_repo.get_claims_by_uids(uids)
        food_logs = self.user_repo.get_food_logs_by_uids_and_date(uids, today)

        # Index by uid
        streaks_by_uid = defaultdict(list)
        achievements_by_uid = defaultdict(list)
        claims_by_uid = defaultdict(list)
        food_by_uid = {f["uid"]: f for f in food_logs}

        for s in streaks:
            streaks_by_uid[s["uid"]].append(s)

        for a in achievements:
            achievements_by_uid[a["uid"]].append(a)

        for c in claims:
            claims_by_uid[c["uid"]].append(c)

        # Build snapshot rows
        rows = []

        for user in users:
            uid = user["uid"]
            food = food_by_uid.get(uid)

            rows.append({
                "uid": uid,
                "snapshot_date": today,
                "data": {
                    "level": user["level"],
                    "exp_points": user["exp_points"],
                    "app_color": user["app_color"],
                    "can_claim_daily_reward": user["can_claim_daily_reward"],
                    "last_daily_claim": user["last_daily_claim"],

                    "streaks": {
                        s["streak_type"]: {
                            "streak": s["streak"],
                            "highest_streak": s["highest_streak"],
                            "last_date": s["last_date"],
                        }
                        for s in streaks_by_uid.get(uid, [])
                    },

                    "achievement_progress": {
                        a["achievement_id"]: a["progress"]
                        for a in achievements_by_uid.get(uid, [])
                    },

                    "achievement_claims": [
                        {"achievement_id": c["achievement_id"], "tier": c["tier"]}
                        for c in claims_by_uid.get(uid, [])
                    ],

                    "food_logs": {
                        "breakfast": food["breakfast"] or [],
                        "lunch": food["lunch"] or [],
                        "dinner": food["dinner"] or [],
                        "snack": food["snack"] or [],
                    } if food else None,
                }
            })

        # Write snapshots
        self.user_repo.upsert_daily_snapshots(rows)

        return len(rows)
