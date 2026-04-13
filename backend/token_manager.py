import os
from supabase import Client
from datetime import datetime, timedelta, timezone
from backend.utils import to_utc_datetime

# maximum tokens allowed per 24 hours
MAX_TOKENS = int(os.getenv("MAX_TOKENS", "5000"))

class TokenManager:
    def __init__(self, supabase: Client, document="food_logging"):
        # reference to the Postgres row managing tokens
        self.supabase = supabase
        self.document = document

    def consume(self, amount=1):
        try:
            result = self.supabase.rpc("consume_tokens", {
                "p_id": self.document,
                "p_amount": amount,
                "p_max_tokens": MAX_TOKENS
            }).execute()
            return result.data  # the RPC returns true/false
        except Exception as e:
            # return False if any error occurs
            return False

    # refund token when a search fails
    def refund(self, amount=1):
        try:
            result = self.supabase.rpc("refund_tokens", {
                "p_id": self.document,
                "p_amount": amount,
                "p_max_tokens": MAX_TOKENS
            }).execute()
            return result.data  # the RPC returns true/false
        except Exception as e:
            # return False if error occurs during refund
            return False

    # check if there are any tokens left
    def has_tokens(self):
        try:
            result = self.supabase.table("rate_limits").select("current_tokens").eq("id", self.document).execute()
            if not result.data:
                # treat as having tokens if row not created yet
                return True

            current_tokens = result.data[0].get("current_tokens", MAX_TOKENS)
            return current_tokens > 0
        except Exception as e:
            # return False if error occurs during check
            return False