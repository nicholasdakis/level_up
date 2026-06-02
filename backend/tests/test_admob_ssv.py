import pytest
import base64
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.exceptions import InvalidSignature


def _generate_key_pair():
    private_key = ec.generate_private_key(ec.SECP256R1())
    public_key = private_key.public_key()
    pem = public_key.public_bytes(
        serialization.Encoding.PEM,
        serialization.PublicFormat.SubjectPublicKeyInfo,
    ).decode()
    return private_key, pem


def _sign_message(private_key, message: str) -> str:
    sig = private_key.sign(message.encode(), ec.ECDSA(hashes.SHA256()))
    return base64.urlsafe_b64encode(sig).decode().rstrip("=")


def _verify(query_string: str, pem: str):
    # Mirrors the verification logic in server.py's admob_ssv route
    sig_start = query_string.rfind("&signature=")
    message = query_string[:sig_start].encode()
    sig_part = query_string[sig_start + len("&signature="):]
    signature = sig_part.split("&")[0]
    sig_bytes = base64.urlsafe_b64decode(signature + "==")
    public_key = serialization.load_pem_public_key(pem.encode())
    public_key.verify(sig_bytes, message, ec.ECDSA(hashes.SHA256()))


# A correctly signed message must pass verification without raising
def test_valid_signature_verifies():
    private_key, pem = _generate_key_pair()
    message = "custom_data=user_abc&reward_amount=1&reward_item=xp&timestamp=1234"
    sig = _sign_message(private_key, message)
    query = f"{message}&signature={sig}&key_id=12345"
    _verify(query, pem)  # must not raise


# A tampered message must fail verification
def test_tampered_message_fails():
    private_key, pem = _generate_key_pair()
    message = "custom_data=user_abc&reward_amount=1&reward_item=xp&timestamp=1234"
    sig = _sign_message(private_key, message)
    tampered = "custom_data=user_evil&reward_amount=1&reward_item=xp&timestamp=1234"
    query = f"{tampered}&signature={sig}&key_id=12345"
    with pytest.raises(InvalidSignature):
        _verify(query, pem)


# A signature from a different key must fail verification
def test_wrong_key_fails():
    private_key, _ = _generate_key_pair()
    _, other_pem = _generate_key_pair()
    message = "custom_data=user_abc&reward_amount=1&reward_item=xp&timestamp=1234"
    sig = _sign_message(private_key, message)
    query = f"{message}&signature={sig}&key_id=12345"
    with pytest.raises(InvalidSignature):
        _verify(query, other_pem)


# A truncated/corrupted signature must fail verification
def test_corrupted_signature_fails():
    _, pem = _generate_key_pair()
    query = "custom_data=user_abc&reward_amount=1&signature=AAAA&key_id=12345"
    with pytest.raises(Exception):
        _verify(query, pem)


# Message extraction must stop exactly at &signature= so the signed content is correct
def test_message_extraction_stops_at_signature():
    message = "a=1&b=2"
    sig_start = f"{message}&signature=FAKE&key_id=99".rfind("&signature=")
    extracted = f"{message}&signature=FAKE&key_id=99"[:sig_start]
    assert extracted == message
