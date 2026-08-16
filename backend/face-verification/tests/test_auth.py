import base64
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa, ec
from fastapi.testclient import TestClient
from jose import jwt as jose_jwt
from unittest.mock import patch

from app.main import app
from app.config import get_settings


def _generate_rsa_key_pair():
    private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    public_key = private_key.public_key()
    private_pem = private_key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )
    public_numbers = public_key.public_numbers()
    n = base64.urlsafe_b64encode(
        public_numbers.n.to_bytes(
            (public_numbers.n.bit_length() + 7) // 8, byteorder="big"
        )
    ).decode("utf-8").rstrip("=")
    e = base64.urlsafe_b64encode(
        public_numbers.e.to_bytes(3, byteorder="big")
    ).decode("utf-8").rstrip("=")
    return private_pem, {"kid": "test-kid", "kty": "RSA", "n": n, "e": e}


_PRIVATE_KEY, _PUBLIC_JWK = _generate_rsa_key_pair()


def _make_token(payload: dict) -> str:
    return jose_jwt.encode(
        payload,
        _PRIVATE_KEY,
        algorithm="RS256",
        headers={"kid": "test-kid"},
    )


def test_missing_auth_header(client: TestClient):
    response = client.get("/api/v1/auth/me")
    assert response.status_code == 401
    assert response.json()["detail"] == "Invalid authentication credentials"


def test_malformed_auth_header(client: TestClient):
    response = client.get(
        "/api/v1/auth/me",
        headers={"Authorization": "Basic invalid"},
    )
    assert response.status_code == 401


def test_invalid_jwt(client: TestClient):
    response = client.get(
        "/api/v1/auth/me",
        headers={"Authorization": "Bearer invalid.token.here"},
    )
    assert response.status_code == 401


def test_expired_jwt(client: TestClient):
    payload = {
        "sub": "00000000-0000-0000-0000-000000000000",
        "exp": 1000000000,
        "iss": "https://test.supabase.co/auth/v1",
        "aud": "authenticated",
    }
    token = _make_token(payload)
    response = client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 401


def _generate_ec_key_pair():
    private_key = ec.generate_private_key(ec.SECP256R1())
    public_key = private_key.public_key()
    private_pem = private_key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )
    public_numbers = public_key.public_numbers()
    x = base64.urlsafe_b64encode(
        public_numbers.x.to_bytes(
            (public_numbers.x.bit_length() + 7) // 8, byteorder="big"
        )
    ).decode("utf-8").rstrip("=")
    y = base64.urlsafe_b64encode(
        public_numbers.y.to_bytes(
            (public_numbers.y.bit_length() + 7) // 8, byteorder="big"
        )
    ).decode("utf-8").rstrip("=")
    return private_pem, {"kid": "test-es256-kid", "kty": "EC", "crv": "P-256", "x": x, "y": y}


_EC_PRIVATE_KEY, _EC_PUBLIC_JWK = _generate_ec_key_pair()


def _make_es256_token(payload: dict) -> str:
    return jose_jwt.encode(
        payload,
        _EC_PRIVATE_KEY,
        algorithm="ES256",
        headers={"kid": "test-es256-kid"},
    )


def test_valid_es256_jwt(client: TestClient):
    payload = {
        "sub": "00000000-0000-0000-0000-000000000000",
        "exp": 9999999999,
        "iss": "https://test.supabase.co/auth/v1",
        "aud": "authenticated",
    }
    token = _make_es256_token(payload)

    with patch("app.auth._fetch_jwks", return_value={"test-es256-kid": _EC_PUBLIC_JWK}):
        response = client.get(
            "/api/v1/auth/me",
            headers={"Authorization": f"Bearer {token}"},
        )
    assert response.status_code == 200
    assert response.json()["user_id"] == "00000000-0000-0000-0000-000000000000"


def test_valid_jwt(client: TestClient):
    payload = {
        "sub": "00000000-0000-0000-0000-000000000000",
        "exp": 9999999999,
        "iss": "https://test.supabase.co/auth/v1",
        "aud": "authenticated",
    }
    token = _make_token(payload)

    with patch("app.auth._fetch_jwks", return_value={"test-kid": _PUBLIC_JWK}):
        response = client.get(
            "/api/v1/auth/me",
            headers={"Authorization": f"Bearer {token}"},
        )
    assert response.status_code == 200
    assert response.json()["user_id"] == "00000000-0000-0000-0000-000000000000"
