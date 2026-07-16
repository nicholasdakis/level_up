# Authentication Layer: verifies that incoming requests are from real, authenticated users
from firebase_admin import auth
import logging

logger = logging.getLogger(__name__)

# Verifies the Firebase JWT and returns the uid and full decoded claims
def verify_token(id_token: str) -> tuple[str, dict]:
    try:
        # verify_id_token downloads Google's public keys to verify the JWT signature, and checks the token's claims
        decoded = auth.verify_id_token(id_token)
        # if successful, returns the uid and full decoded claims so callers can extract email etc without re-verifying
        return decoded["uid"], decoded

    except Exception as e:
        logger.warning(f"Token verification failed: {e}") # Real error message logged to server
        raise ValueError("Invalid or expired token") # Generic error message logged to user