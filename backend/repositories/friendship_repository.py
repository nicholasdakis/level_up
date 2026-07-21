from supabase import Client

class FriendshipRepository:
    def __init__(self, supabase: Client):
        self._supabase = supabase

    def send_request(self, sender_uid: str, recipient_uid: str) -> dict:
        return self._supabase.rpc("send_friend_request", {
            "p_sender_uid": sender_uid,
            "p_recipient_uid": recipient_uid,
        }).execute().data

    def accept_request(self, target_uid: str, sender_uid: str) -> dict:
        return self._supabase.rpc("accept_friend_request", {
            "p_target_uid": target_uid,
            "p_sender_uid": sender_uid,
        }).execute().data

    def decline_request(self, target_uid: str, sender_uid: str) -> dict:
        return self._supabase.rpc("decline_friend_request", {
            "p_target_uid": target_uid,
            "p_sender_uid": sender_uid,
        }).execute().data

    def cancel_request(self, sender_uid: str, target_uid: str) -> dict:
        return self._supabase.rpc("cancel_friend_request", {
            "p_sender_uid": sender_uid,
            "p_recipient_uid": target_uid,
        }).execute().data

    def unfriend(self, uid: str, other_uid: str) -> dict:
        return self._supabase.rpc("unfriend", {
            "p_uid": uid,
            "p_other_uid": other_uid,
        }).execute().data

    def get_friends(self, uid: str, limit: int, offset: int) -> list:
        # get all accepted friendship rows involving this uid
        rows = self._supabase.table("friendships") \
            .select("sender_uid, recipient_uid") \
            .eq("status", "accepted") \
            .or_(f"sender_uid.eq.{uid},recipient_uid.eq.{uid}") \
            .range(offset, offset + limit - 1) \
            .execute().data
        other_uids = [
            row["recipient_uid"] if row["sender_uid"] == uid else row["sender_uid"]
            for row in rows
        ]
        if not other_uids:
            return []
        users = self._supabase.table("users") \
            .select("uid, username, level, exp_points, pfp_base64, is_premium") \
            .in_("uid", other_uids) \
            .order("username", desc=False) \
            .execute().data
        return users

    def search_friends(self, uid: str, query: str, limit: int) -> list:
        return self._supabase.rpc("search_friends", {
            "p_uid": uid,
            "p_query": query,
            "p_limit": limit,
        }).execute().data or []

    def get_incoming_requests(self, uid: str, limit: int, offset: int) -> list:
        rows = self._supabase.table("friendships") \
            .select("sender_uid, created_at, users!friendships_sender_uid_fkey(uid, username, level, exp_points, pfp_base64, is_premium)") \
            .eq("recipient_uid", uid) \
            .eq("status", "pending") \
            .order("created_at", desc=True) \
            .range(offset, offset + limit - 1) \
            .execute().data
        return [row["users"] for row in rows if row.get("users")]

    def get_outgoing_requests(self, uid: str, limit: int, offset: int) -> list:
        rows = self._supabase.table("friendships") \
            .select("recipient_uid, created_at, users!friendships_recipient_uid_fkey(uid, username, level, exp_points, pfp_base64, is_premium)") \
            .eq("sender_uid", uid) \
            .eq("status", "pending") \
            .order("created_at", desc=True) \
            .range(offset, offset + limit - 1) \
            .execute().data
        return [row["users"] for row in rows if row.get("users")]

    def get_status(self, uid: str, other_uid: str) -> str:
        result = self._supabase.table("friendships") \
            .select("sender_uid, status") \
            .or_(f"and(sender_uid.eq.{uid},recipient_uid.eq.{other_uid}),and(sender_uid.eq.{other_uid},recipient_uid.eq.{uid})") \
            .execute()
        rows = result.data
        if not rows:
            return "none"
        row = rows[0]
        if row["status"] == "accepted":
            return "accepted"
        if row["sender_uid"] == uid:
            return "pending_sent"
        return "pending_received"
