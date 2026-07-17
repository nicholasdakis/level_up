from supabase import Client


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
