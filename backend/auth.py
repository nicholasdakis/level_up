# Authentication Layer: verifies that incoming requests are from real, authenticated users
from firebase_admin import auth

# Method to verify the JWT and return the user's UID
def verify_token(id_token: str) -> str:
    try:
        # verify_id_token downloads Google's public keys to verify the JWT signature, and checks the token's claims
        decoded = auth.verify_id_token(id_token)
        # if successful, it returns the user's Firebase UID
        return decoded["uid"]

    except Exception as e:
        raise ValueError(f"Invalid Firebase ID token: {e}")
