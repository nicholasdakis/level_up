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
