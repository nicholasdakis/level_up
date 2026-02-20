import os
import json
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime, timedelta, timezone

# maximum tokens allowed per 24 hours
MAX_TOKENS = int(os.getenv("MAX_TOKENS", "5000"))

# initialize firebase_admin if not already initialized
if not firebase_admin._apps:
    service_account_json = os.getenv("FIREBASE_SERVICE_ACCOUNT")
    cred = credentials.Certificate(json.loads(service_account_json))
    firebase_admin.initialize_app(cred)

# create firestore client for database operations
db = firestore.client()

class TokenManager:
    def __init__(self, collection="rate_limits", document="food_logging"):
        # reference to the Firestore document managing tokens
        self.doc_ref = db.collection(collection).document(document)
        
    def consume(self, amount=1):
        try:
            @firestore.transactional  # atomically update tokens
            def update_tokens(transaction):
                snapshot = self.doc_ref.get(transaction=transaction)
                now = datetime.now(timezone.utc)  # current UTC time so time is not dependent on user's device
                
                if not snapshot.exists:
                    # first time setup
                    transaction.set(self.doc_ref, {
                        "current_tokens": MAX_TOKENS - amount,
                        "last_refill_time": now
                    })
                    return True
                
                data = snapshot.to_dict()
                current_tokens = data.get("current_tokens", MAX_TOKENS)
                last_refill_time = data.get("last_refill_time")
                
                # convert Firestore timestamp to datetime if necessary
                if last_refill_time:
                    if hasattr(last_refill_time, 'to_datetime'):
                        last_refill_dt = last_refill_time.to_datetime().replace(tzinfo=timezone.utc)
                    elif hasattr(last_refill_time, 'timestamp'):
                        last_refill_dt = datetime.fromtimestamp(last_refill_time.timestamp(), timezone.utc)
                    elif isinstance(last_refill_time, datetime):
                        last_refill_dt = last_refill_time.replace(tzinfo=timezone.utc)
                    else:
                        last_refill_dt = now
                else:
                    last_refill_dt = now
                
                # check if 24 hours passed since last refill and reset tokens if so
                if (now - last_refill_dt) >= timedelta(days=1):
                    current_tokens = MAX_TOKENS
                    last_refill_dt = now
                
                # not enough tokens to consume
                if current_tokens < amount:
                    return False
                
                # consume the requested amount of tokens
                new_token_count = current_tokens - amount
                transaction.update(self.doc_ref, {
                    "current_tokens": new_token_count,
                    "last_refill_time": last_refill_dt
                })
                return True
            
            transaction = db.transaction()  # create a Firestore transaction
            return update_tokens(transaction)
            
        except Exception as e:
            # return False if any error occurs
            return False
        
    # refund token when a search fails
    def refund(self, amount=1):
        try:
            @firestore.transactional  # ensure atomic update for refund
            def refund_tokens(transaction):
                snapshot = self.doc_ref.get(transaction=transaction)
                
                if not snapshot.exists:
                    # cannot refund if document doesn't exist
                    return False
                    
                data = snapshot.to_dict()
                current_tokens = data.get("current_tokens", 0)
                new_tokens = min(current_tokens + amount, MAX_TOKENS)  # prevent exceeding max
                
                transaction.update(self.doc_ref, {
                    "current_tokens": new_tokens
                })
                return True
            
            transaction = db.transaction()  # create Firestore transaction
            return refund_tokens(transaction)
            
        except Exception as e:
            # return False if error occurs during refund
            return False

    # check if there are any tokens left
    def has_tokens(self):
        try:
            doc = self.doc_ref.get()
            if not doc.exists:
                # treat as having tokens if document not created yet
                return True
                
            data = doc.to_dict()
            current_tokens = data.get("current_tokens", MAX_TOKENS)
            return current_tokens > 0
            
        except Exception as e:
            # return False if error occurs during check
            return False