from postgrest.exceptions import APIError
from backend.repositories.friendship_repository import FriendshipRepository

class FriendshipService:
    def __init__(self, repo: FriendshipRepository):
        self._repo = repo

    def send_friend_request(self, uid: str, target_uid: str) -> dict:
        if uid == target_uid:
            return {"ok": False, "reason": "self_request"}
        try:
            return self._repo.send_request(uid, target_uid) or {}
        except APIError as e:
            msg = str(e).lower()
            if "unique" in msg:
                status = self._repo.get_status(uid, target_uid)
                if status == "accepted":
                    return {"ok": False, "reason": "already_friends"}
                return {"ok": False, "reason": "request_already_exists"}
            if "foreign key" in msg:
                return {"ok": False, "reason": "user_not_found"}
            raise

    def accept_friend_request(self, target_uid: str, sender_uid: str) -> dict:
        return self._repo.accept_request(target_uid, sender_uid) or {}

    def decline_friend_request(self, target_uid: str, sender_uid: str) -> dict:
        return self._repo.decline_request(target_uid, sender_uid) or {}

    def cancel_friend_request(self, sender_uid: str, target_uid: str) -> dict:
        return self._repo.cancel_request(sender_uid, target_uid) or {}

    def unfriend(self, uid: str, other_uid: str) -> dict:
        return self._repo.unfriend(uid, other_uid) or {}

    def get_friends(self, uid: str, limit: int, offset: int) -> list:
        return self._repo.get_friends(uid, limit, offset)

    def get_incoming_requests(self, uid: str, limit: int, offset: int) -> list:
        return self._repo.get_incoming_requests(uid, limit, offset)

    def get_outgoing_requests(self, uid: str, limit: int, offset: int) -> list:
        return self._repo.get_outgoing_requests(uid, limit, offset)
