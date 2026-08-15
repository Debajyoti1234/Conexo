from unittest.mock import patch, MagicMock
from uuid import UUID

from fastapi.testclient import TestClient
from jose import jwt as jose_jwt

from app.main import app
from app.auth import get_current_user_id
from app.config import get_settings
from app.verification import verify_face


def _generate_rsa_key_pair():
    from cryptography.hazmat.primitives import serialization
    from cryptography.hazmat.primitives.asymmetric import rsa

    private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    public_key = private_key.public_key()
    private_pem = private_key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )
    public_pem = public_key.public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    )
    return private_pem, public_pem


_PRIVATE_KEY, _PUBLIC_KEY = _generate_rsa_key_pair()


def _make_token(payload: dict) -> str:
    return jose_jwt.encode(payload, _PRIVATE_KEY, algorithm="RS256")


def test_verify_face_requires_auth(client: TestClient):
    response = client.post(
        "/api/v1/verify-face",
        files={"selfie": ("test.jpg", b"fake-image", "image/jpeg")},
    )
    assert response.status_code == 401


def test_verify_face_missing_selfie(client: TestClient):
    app.dependency_overrides[get_current_user_id] = lambda: UUID("00000000-0000-0000-0000-000000000000")
    try:
        response = client.post("/api/v1/verify-face")
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 422


def test_verify_face_oversized(client: TestClient):
    app.dependency_overrides[get_current_user_id] = lambda: UUID("00000000-0000-0000-0000-000000000000")
    try:
        large_bytes = b"x" * (5 * 1024 * 1024 + 1)
        response = client.post(
            "/api/v1/verify-face",
            files={"selfie": ("test.jpg", large_bytes, "image/jpeg")},
        )
        assert response.status_code == 400
    finally:
        app.dependency_overrides.clear()


def test_verify_face_invalid_file_type(client: TestClient):
    app.dependency_overrides[get_current_user_id] = lambda: UUID("00000000-0000-0000-0000-000000000000")
    try:
        response = client.post(
            "/api/v1/verify-face",
            files={"selfie": ("test.txt", b"hello", "text/plain")},
        )
        assert response.status_code == 400
    finally:
        app.dependency_overrides.clear()


def test_verify_face_invalid_image(client: TestClient):
    app.dependency_overrides[get_current_user_id] = lambda: UUID("00000000-0000-0000-0000-000000000000")
    try:
        response = client.post(
            "/api/v1/verify-face",
            files={"selfie": ("test.jpg", b"not-an-image", "image/jpeg")},
        )
        assert response.status_code == 400
    finally:
        app.dependency_overrides.clear()


def test_verify_face_function_success():
    mock_profile = {
        "id": "user-1",
        "photos": [
            {
                "id": "photo-1",
                "isPrimary": True,
                "remoteUrl": "profiles/user-1/photo-1.jpg",
            }
        ],
    }

    with patch("app.verification.check_rate_limit"), patch(
        "app.verification.get_face_embedding"
    ) as mock_selfie_face, patch(
        "app.verification.get_profile", return_value=mock_profile
    ), patch(
        "app.verification.download_primary_photo", return_value=b"primary-bytes"
    ) as mock_download, patch(
        "app.verification.cosine_similarity", return_value=0.85
    ), patch(
        "app.verification.is_match", return_value=True
    ), patch(
        "app.verification._update_verification_status"
    ) as mock_update:
        mock_selfie_face.return_value = MagicMock(
            success=True, embedding=b"embedding"
        )
        mock_download.return_value = b"primary-bytes"

        with patch("app.verification.get_face_embedding", side_effect=[
            MagicMock(success=True, embedding=b"embedding1"),
            MagicMock(success=True, embedding=b"embedding2"),
        ]):
            result = verify_face(b"selfie-bytes", "image/jpeg", "user-1")

    assert result.match is True
    assert result.reason == "match"
    mock_update.assert_called_once_with("user-1", True)


def test_verify_face_function_low_similarity():
    mock_profile = {
        "id": "user-1",
        "photos": [
            {
                "id": "photo-1",
                "isPrimary": True,
                "remoteUrl": "profiles/user-1/photo-1.jpg",
            }
        ],
    }

    with patch("app.verification.check_rate_limit"), patch(
        "app.verification.get_profile", return_value=mock_profile
    ), patch(
        "app.verification.download_primary_photo", return_value=b"primary-bytes"
    ), patch(
        "app.verification.cosine_similarity", return_value=0.3
    ), patch(
        "app.verification.is_match", return_value=False
    ), patch(
        "app.verification._update_verification_status"
    ) as mock_update:
        with patch("app.verification.get_face_embedding", side_effect=[
            MagicMock(success=True, embedding=b"embedding1"),
            MagicMock(success=True, embedding=b"embedding2"),
        ]):
            result = verify_face(b"selfie-bytes", "image/jpeg", "user-1")

    assert result.match is False
    assert result.reason == "low_similarity"
    mock_update.assert_called_once_with("user-1", False)
