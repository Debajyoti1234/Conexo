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


def test_verify_face_jpg_content_type(client: TestClient):
    app.dependency_overrides[get_current_user_id] = lambda: UUID("00000000-0000-0000-0000-000000000000")
    try:
        response = client.post(
            "/api/v1/verify-face",
            files={"selfie": ("test.jpg", b"fake-image", "image/jpg")},
        )
        assert response.status_code == 400
        assert response.json()["detail"]["reason"] == "invalid_image"
    finally:
        app.dependency_overrides.clear()


def test_verify_face_heic_content_type(client: TestClient):
    app.dependency_overrides[get_current_user_id] = lambda: UUID("00000000-0000-0000-0000-000000000000")
    try:
        heic_bytes = b"\x00" * 12 + b"ftypheic" + b"\x00" * 100
        mock_profile = {
            "id": "00000000-0000-0000-0000-000000000000",
            "photos": [
                {
                    "id": "photo-1",
                    "isPrimary": True,
                    "remoteUrl": "profiles/00000000-0000-0000-0000-000000000000/photo-1.jpg",
                }
            ],
        }
        with patch("app.verification.normalize_image", return_value=b"jpeg-bytes") as mock_norm, \
             patch("app.verification.get_face_embedding", side_effect=[
                 MagicMock(success=True, embedding=b"embedding1"),
                 MagicMock(success=True, embedding=b"embedding2"),
             ]), \
             patch("app.verification.get_profile", return_value=mock_profile), \
             patch("app.verification.download_primary_photo", return_value=b"primary-bytes"), \
             patch("app.verification.cosine_similarity", return_value=0.85), \
             patch("app.verification.is_match", return_value=True), \
             patch("app.verification._update_verification_status"):
            response = client.post(
                "/api/v1/verify-face",
                files={"selfie": ("test.heic", heic_bytes, "image/heic")},
            )
            mock_norm.assert_called_once()
            assert response.status_code == 200
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


# ── Multi-angle endpoint contract (/api/v1/verify-face-multi) ────────────────

_ZERO_UUID = "00000000-0000-0000-0000-000000000000"

_MULTI_PROFILE = {
    "id": _ZERO_UUID,
    "photos": [
        {
            "id": "photo-1",
            "isPrimary": True,
            "remoteUrl": f"profiles/{_ZERO_UUID}/photo-1.jpg",
        }
    ],
}


def _multi_files() -> dict:
    return {
        "selfie_front": ("selfie_front.jpg", b"front-bytes", "image/jpeg"),
        "selfie_left": ("selfie_left.jpg", b"left-bytes", "image/jpeg"),
        "selfie_right": ("selfie_right.jpg", b"right-bytes", "image/jpeg"),
    }


def test_verify_face_multi_requires_auth(client: TestClient):
    response = client.post("/api/v1/verify-face-multi", files=_multi_files())
    assert response.status_code == 401


def test_verify_face_multi_requires_all_three_angles(client: TestClient):
    app.dependency_overrides[get_current_user_id] = lambda: UUID(_ZERO_UUID)
    try:
        # Missing selfie_right -> FastAPI validation error.
        response = client.post(
            "/api/v1/verify-face-multi",
            files={
                "selfie_front": ("selfie_front.jpg", b"x", "image/jpeg"),
                "selfie_left": ("selfie_left.jpg", b"x", "image/jpeg"),
            },
        )
        assert response.status_code == 422
    finally:
        app.dependency_overrides.clear()


def test_verify_face_multi_matches_on_best_angle(client: TestClient):
    app.dependency_overrides[get_current_user_id] = lambda: UUID(_ZERO_UUID)
    try:
        # is_match is intentionally NOT mocked so the real max(...) >= 0.4
        # decision is exercised. Angle sims 0.2 / 0.85 / 0.3 -> best 0.85.
        with patch("app.verification.normalize_image", return_value=b"jpeg-bytes"), \
             patch("app.verification.get_face_embedding", side_effect=[
                 MagicMock(success=True, embedding=b"front"),
                 MagicMock(success=True, embedding=b"left"),
                 MagicMock(success=True, embedding=b"right"),
                 MagicMock(success=True, embedding=b"primary"),
             ]), \
             patch("app.verification.get_profile", return_value=_MULTI_PROFILE), \
             patch("app.verification.download_primary_photo", return_value=b"primary"), \
             patch("app.verification.cosine_similarity", side_effect=[0.2, 0.85, 0.3]), \
             patch("app.verification._update_verification_status") as mock_update:
            response = client.post("/api/v1/verify-face-multi", files=_multi_files())

        assert response.status_code == 200
        body = response.json()
        assert body["match"] is True
        assert body["reason"] == "match"
        assert body["threshold"] == 0.4
        assert body["similarity"] == 0.85
        assert body["angle_similarities"] == {
            "front": 0.2,
            "left": 0.85,
            "right": 0.3,
        }
        mock_update.assert_called_once_with(_ZERO_UUID, True)
    finally:
        app.dependency_overrides.clear()


def test_verify_face_multi_low_similarity_when_all_below_threshold(client: TestClient):
    app.dependency_overrides[get_current_user_id] = lambda: UUID(_ZERO_UUID)
    try:
        with patch("app.verification.normalize_image", return_value=b"jpeg-bytes"), \
             patch("app.verification.get_face_embedding", side_effect=[
                 MagicMock(success=True, embedding=b"front"),
                 MagicMock(success=True, embedding=b"left"),
                 MagicMock(success=True, embedding=b"right"),
                 MagicMock(success=True, embedding=b"primary"),
             ]), \
             patch("app.verification.get_profile", return_value=_MULTI_PROFILE), \
             patch("app.verification.download_primary_photo", return_value=b"primary"), \
             patch("app.verification.cosine_similarity", side_effect=[0.10, 0.20, 0.39]), \
             patch("app.verification._update_verification_status") as mock_update:
            response = client.post("/api/v1/verify-face-multi", files=_multi_files())

        assert response.status_code == 200
        body = response.json()
        assert body["match"] is False
        assert body["reason"] == "low_similarity"
        assert body["similarity"] == 0.39
        mock_update.assert_called_once_with(_ZERO_UUID, False)
    finally:
        app.dependency_overrides.clear()


def test_verify_face_multi_reports_offending_angle(client: TestClient):
    app.dependency_overrides[get_current_user_id] = lambda: UUID(_ZERO_UUID)
    try:
        # Front embeds fine; left has no detectable face -> 422 tagged "left".
        with patch("app.verification.normalize_image", return_value=b"jpeg-bytes"), \
             patch("app.verification.get_face_embedding", side_effect=[
                 MagicMock(success=True, embedding=b"front"),
                 MagicMock(success=False, reason="no_face", embedding=None),
             ]):
            response = client.post("/api/v1/verify-face-multi", files=_multi_files())

        assert response.status_code == 422
        detail = response.json()["detail"]
        assert detail["reason"] == "no_face"
        assert detail["angle"] == "left"
    finally:
        app.dependency_overrides.clear()
