import os
import json
from dotenv import load_dotenv
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime, timedelta, timezone

load_dotenv()
MAX_TOKENS = int(os.getenv("MAX_TOKENS", 5000))

# initialize firebase_admin
if not firebase_admin._apps:
    service_account_json = os.getenv("FIREBASE_SERVICE_ACCOUNT")
    cred = credentials.Certificate(json.loads(service_account_json))
    firebase_admin.initialize_app(cred)

db = firestore.client()

class TokenManager:
    def __init__(self, collection="rate_limits", document="food_logging"):
        self.doc_ref = db.collection(collection).document(document)
        
    def consume(self, amount=1):
        try:
            @firestore.transactional
            def update_tokens(transaction):
                snapshot = self.doc_ref.get(transaction=transaction)
                now = datetime.now(timezone.utc)
                # create fields if they don't exist
                if not snapshot.exists:
                    transaction.set(self.doc_ref, {
                        "current_tokens": MAX_TOKENS - amount,
                        "last_refill": firestore.SERVER_TIMESTAMP
                    })
                    return True
                
                data = snapshot.to_dict()
                current_tokens = data.get("current_tokens", MAX_TOKENS)
                last_refill = data.get("last_refill")
                
                # Handle timestamp conversion
                if last_refill:
                    if hasattr(last_refill, 'to_datetime'):
                        last_refill_dt = last_refill.to_datetime().replace(tzinfo=timezone.utc)
                    elif hasattr(last_refill, 'timestamp'):
                        last_refill_dt = datetime.fromtimestamp(last_refill.timestamp(), timezone.utc)
                    elif isinstance(last_refill, datetime):
                        last_refill_dt = last_refill.replace(tzinfo=timezone.utc)
                    else:
                        last_refill_dt = now
                else:
                    last_refill_dt = now
                
                # Check if 24 hours have passed for token refill
                if (now - last_refill_dt) >= timedelta(days=1):
                    current_tokens = MAX_TOKENS
                
                if current_tokens < amount:
                    return False
                
                new_token_count = current_tokens - amount
                transaction.update(self.doc_ref, {
                    "current_tokens": new_token_count,
                    "last_refill": firestore.SERVER_TIMESTAMP
                })
                return True
            
            transaction = db.transaction()
            return update_tokens(transaction)
            
        except Exception as e:
            return False

    def refund(self, amount=1):
        try:
            @firestore.transactional
            def refund_tokens(transaction):
                snapshot = self.doc_ref.get(transaction=transaction)
                
                if not snapshot.exists:
                    return False
                    
                data = snapshot.to_dict()
                current_tokens = data.get("current_tokens", 0)
                new_tokens = min(current_tokens + amount, MAX_TOKENS)
                
                transaction.update(self.doc_ref, {
                    "current_tokens": new_tokens
                })
                return True
            
            transaction = db.transaction()
            return refund_tokens(transaction)
            
        except Exception as e:
            return False

    def has_tokens(self):
        try:
            doc = self.doc_ref.get()
            if not doc.exists:
                return True
                
            data = doc.to_dict()
            current_tokens = data.get("current_tokens", MAX_TOKENS)
            return current_tokens > 0
            
        except Exception as e:
            return False

    def reset_tokens(self):
        try:
            self.doc_ref.set({
                "current_tokens": MAX_TOKENS,
                "last_refill": firestore.SERVER_TIMESTAMP
            })
            return True
        except Exception as e:
            return False