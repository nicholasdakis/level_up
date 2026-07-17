from supabase import Client
from backend.valid_achievements import VALID_ACHIEVEMENT_IDS


class AchievementRepository:
    # Repository class to handle all Postgres operations related to achievements

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
