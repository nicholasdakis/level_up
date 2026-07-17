from supabase import Client


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
