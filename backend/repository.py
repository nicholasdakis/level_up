# Repository Layer: the only place in the backend that reads/writes Firestore, so DB logic is only in this class and can be easily swapped if ever needed

from datetime import datetime, timezone
from google.cloud import firestore
import re
from backend.utils import to_utc_datetime

class UserRepository:
    # Repository class to handle all Firestore operations related to user data

    def __init__(self, db: firestore.Client):
        # Store the Firestore client passed in from server.py
        self._db = db
        self._public = db.collection("users-public")
        self._private = db.collection("users-private")
    
    def _sanitize_poi_id(self, poi_name: str) -> str:
        # Replace any character that isn't a letter, number, hyphen, or underscore with an underscore as Firestore Document IDs don't allow special characters
        return re.sub(r'[^a-zA-Z0-9_-]', '_', poi_name)[:500]

    # Read operations

    def username_exists(self, uid: str, username: str):
        docs = self._public.where("username", "==", username.lower()).stream() # See if the proposed username is in the users-public document
        for doc in docs: # If it is, it can only be written by that same user. This allows changing capitalization of the same username (e.g. john to John)
            if doc.id != uid:
                return True
        return False

    def get_public_user(self, uid: str):
        # Fetches the user's user-public document if it exists
        doc = self._public.document(uid).get()
        return doc.to_dict() if doc.exists else None

    def get_private_user(self, uid: str):
        # Fetches the user's user-private document if it exists
        doc = self._private.document(uid).get()
        return doc.to_dict() if doc.exists else None

    # Write operations (non-atomic)

    def set_public_fields(self, uid: str, data: dict):
        self._public.document(uid).set(data, merge=True) # merge=True so only the passed in fields are updated

    def set_private_fields(self, uid: str, data: dict):
        self._private.document(uid).set(data, merge=True) # merge=True so only the passed in fields are updated

    # Atomic instructions

    def claim_daily_reward_transaction(
        self, uid: str, new_level: int, new_exp: int
    ):
        # Method to atomically claim the daily reward, update XP/level, and set cooldown
        # Forces Firestore to retry if the user's document changes mid-transaction, guaranteeing it is atomic

        public_ref = self._public.document(uid)
        private_ref = self._private.document(uid)

        @firestore.transactional
        def _run(transaction):
            # Step 1: Read both docs inside the transaction to make sure they don't change
            private_snap = private_ref.get(transaction=transaction)
            private_data = private_snap.to_dict() if private_snap.exists else {}

            # Step 2: Check the 23-hour cooldown server-side
            last_claim = private_data.get("lastDailyClaim")
            now = datetime.now(timezone.utc)

            if last_claim is not None:
                # Convert the Firestore timestamp to datetime
                last_claim_dt = to_utc_datetime(last_claim)

                seconds_since_claim = (now - last_claim_dt).total_seconds() 

                if seconds_since_claim < 82800: # 23 hours = 82800 seconds (the cooldown for claiming)
                    # Not enough time has passed
                    return {
                        "claimed": False,
                        "reason": "cooldown",
                        "seconds_remaining": int(82800 - seconds_since_claim),
                    }

            # Step 3: Write the new state atomically
            # Update the variables in the users-public collection
            transaction.set(
                public_ref,
                {"level": new_level, "expPoints": new_exp},
                merge=True,
            )

            # Update the variables in the users-private collection
            transaction.set(
                private_ref,
                {
                    "lastDailyClaim": now,
                    "canClaimDailyReward": False,
                },
                merge=True,
            )

            return {
                "claimed": True,
                "new_level": new_level,
                "new_exp": new_exp,
                "claimed_at": now.isoformat(),
            }

        # Execute the transaction (Firestore retries automatically on conflict)
        transaction = self._db.transaction()
        return _run(transaction)

    # Atomically record the visit, update XP, and set a 24 hour cooldown for that poi
    def record_poi_visit_transaction(self, uid: str, poi_name: str, new_level: int, new_exp: int):
        safe_name = self._sanitize_poi_id(poi_name)
        public_ref = self._public.document(uid)
        visit_ref = self._private.document(uid).collection('poi-visits').document(safe_name)

        @firestore.transactional
        def _run(transaction):
            # Step 1: Read the visit doc inside the transaction to prevent race conditions
            visit_snap = visit_ref.get(transaction=transaction)
            visit_data = visit_snap.to_dict() if visit_snap.exists else {}

            # Step 2: Check the 24-hour cooldown
            last_visit = visit_data.get('last_visit')
            now = datetime.now(timezone.utc)

            if last_visit is not None:
                # Convert Firestore timestamp to datetime if needed
                last_visit_dt = to_utc_datetime(last_visit)
            
                seconds_since = (now - last_visit_dt).total_seconds()
                if seconds_since < 86400: # 24 hours
                    return {
                        "success": False,
                        "error": "Already visited in the last 24 hours",
                        "seconds_remaining": int(86400 - seconds_since),
                    }

            # Step 3: Write the visit timestamp and update XP atomically
            transaction.set(visit_ref, {'last_visit': now}) # record the visit time
            transaction.set(
                public_ref,
                {'level': new_level, 'expPoints': new_exp},
                merge=True, # merge=True to only update level and XP without overwriting other fields
            )

            return {"success": True}

        # Execute the transaction (Firestore retries on conflict)
        transaction = self._db.transaction()
        return _run(transaction)

    def initialize_user_if_new(self, uid: str):
        # Creates default public/private docs for a first-time user

        self._public.document(uid).set(
            {"level": 1, "expPoints": 0},
            merge=True, # merge=True means if the doc already exists, it won't overwrite it, just add any missing fields
        ) 
        self._private.document(uid).set(
            {"lastDailyClaim": None, "canClaimDailyReward": True},
            merge=True, # same merge logic as above, so if the user already has a doc, it won't overwrite their existing claim time or cooldown status
        )
