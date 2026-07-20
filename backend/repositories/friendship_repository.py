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

    def get_status(self, uid: str, other_uid: str) -> str:
        row = self._supabase.table("friendships") \
            .select("sender_uid, status") \
            .or_(f"and(sender_uid.eq.{uid},recipient_uid.eq.{other_uid}),and(sender_uid.eq.{other_uid},recipient_uid.eq.{uid})") \
            .maybe_single() \
            .execute()
        if not row.data:
            return "none"
        if row.data["status"] == "accepted":
            return "accepted"
        if row.data["sender_uid"] == uid:
            return "pending_sent"
        return "pending_received"
