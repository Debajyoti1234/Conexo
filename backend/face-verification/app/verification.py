import time
from typing import Any

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer
from pydantic import BaseModel
from postgrest.exceptions import APIError as PostgrestException
from supabase import create_client

from .auth import get_current_user_id
from .config import get_settings
from .face import get_face_embedding
from .image_utils import normalize_image
from .matching import cosine_similarity, get_threshold, is_match
from .rate_limiter import check_rate_limit
from .storage import _get_supabase_client, _BUCKET, get_profile, resolve_primary_photo, validate_storage_path, download_primary_photo

security = HTTPBearer(auto_error=False)


class VerificationRequest(BaseModel):
    selfie: bytes


class VerificationResponse(BaseModel):
    match: bool
    threshold: float
    reason: str
    similarity: float | None = None


async def _require_auth(
    credentials: HTTPBearer | None = Depends(security),
) -> str:
    from .auth import get_current_user_id as _get_current_user_id

    user_id = await _get_current_user_id(credentials)
    return str(user_id)


def _update_verification_status(user_id: str, verified: bool) -> None:
    client = _get_supabase_client()
    value = "verified" if verified else "notVerified"
    try:
        client.from_("profiles").update(
            {
                "verification_status": value,
                "updated_at": _now_iso(),
            }
        ).eq("id", user_id).execute()
    except PostgrestException:
        raise RuntimeError("verification_update_failed")
    except Exception as exc:
        raise RuntimeError("verification_update_failed") from exc


def _now_iso() -> str:
    import datetime
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def verify_face(selfie_bytes: bytes, content_type: str | None, user_id: str) -> VerificationResponse:
    settings = get_settings()
    threshold = get_threshold()
    max_size = settings.MAX_SELFIE_SIZE_MB * 1024 * 1024

    check_rate_limit(user_id)

    if len(selfie_bytes) > max_size:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "match": False,
                "threshold": threshold,
                "reason": "file_too_large",
            },
        )

    allowed_types = {
        "image/jpeg",
        "image/jpg",
        "image/png",
        "image/webp",
        "image/heic",
        "image/heif",
    }
    if content_type and content_type not in allowed_types:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "match": False,
                "threshold": threshold,
                "reason": "invalid_file_type",
            },
        )

    try:
        normalized_bytes = normalize_image(selfie_bytes, content_type)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "match": False,
                "threshold": threshold,
                "reason": "invalid_file_type",
            },
        )

    selfie_result = get_face_embedding(normalized_bytes)
    if not selfie_result.success:
        reason = selfie_result.reason or "invalid_image"
        if reason == "invalid_image":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={
                    "match": False,
                    "threshold": threshold,
                    "reason": reason,
                },
            )
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={
                "match": False,
                "threshold": threshold,
                "reason": reason,
            },
        )

    try:
        profile = get_profile(user_id)
    except RuntimeError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "match": False,
                "threshold": threshold,
                "reason": "profile_not_found",
            },
        )

    photos = profile.get("photos")
    primary = resolve_primary_photo(photos)
    if primary is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "match": False,
                "threshold": threshold,
                "reason": "no_primary_photo",
            },
        )

    remote_url = primary.get("remoteUrl")
    if not isinstance(remote_url, str) or not remote_url.strip():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "match": False,
                "threshold": threshold,
                "reason": "invalid_primary_photo",
            },
        )

    try:
        path = validate_storage_path(remote_url, user_id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "match": False,
                "threshold": threshold,
                "reason": "invalid_primary_photo",
            },
        )

    try:
        primary_bytes = download_primary_photo(user_id)
    except RuntimeError:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={
                "match": False,
                "threshold": threshold,
                "reason": "storage_failure",
            },
        )

    primary_result = get_face_embedding(primary_bytes)
    if not primary_result.success:
        reason = primary_result.reason or "invalid_primary_photo"
        if reason in ("no_face", "multiple_faces"):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail={
                    "match": False,
                    "threshold": threshold,
                    "reason": "invalid_primary_photo",
                },
            )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={
                "match": False,
                "threshold": threshold,
                "reason": "primary_photo_embedding_failed",
            },
        )

    try:
        similarity = cosine_similarity(selfie_result.embedding, primary_result.embedding)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={
                "match": False,
                "threshold": threshold,
                "reason": "matching_failed",
            },
        )

    match = is_match(similarity, threshold)

    print(
        f"[Verification] user={user_id} "
        f"selfie_bytes={len(selfie_bytes)} primary_bytes={len(primary_bytes)} "
        f"similarity={similarity:.4f} threshold={threshold:.2f} "
        f"match={match} reason={'match' if match else 'low_similarity'}",
        flush=True,
    )

    try:
        _update_verification_status(user_id, match)
    except RuntimeError:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={
                "match": False,
                "threshold": threshold,
                "reason": "verification_update_failed",
            },
        )

    return VerificationResponse(
        match=match,
        threshold=threshold,
        reason="match" if match else "low_similarity",
        similarity=round(similarity, 4),
    )


# ── Multi-angle verification (additive; single-photo verify_face is untouched) ──

# Angle labels for the three controlled captures, in canonical order.
MULTI_ANGLE_LABELS = ("front", "left", "right")


class MultiVerificationResponse(VerificationResponse):
    """Response for the additive multi-angle flow.

    Extends the base contract with per-angle similarities. The single-photo
    :class:`VerificationResponse` (and therefore the `/api/v1/verify-face`
    response body) is intentionally left byte-for-byte unchanged.
    """

    angle_similarities: dict[str, float] | None = None

_ALLOWED_SELFIE_TYPES = {
    "image/jpeg",
    "image/jpg",
    "image/png",
    "image/webp",
    "image/heic",
    "image/heif",
}


def _load_primary_embedding(user_id: str, threshold: float) -> tuple[Any, int]:
    """Fetch + embed the user's primary profile photo.

    Mirrors the primary-photo handling inside :func:`verify_face` exactly so the
    proven single-photo path is left byte-for-byte untouched. Raises the same
    HTTPExceptions/reasons on failure.
    """
    try:
        profile = get_profile(user_id)
    except RuntimeError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"match": False, "threshold": threshold, "reason": "profile_not_found"},
        )

    primary = resolve_primary_photo(profile.get("photos"))
    if primary is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"match": False, "threshold": threshold, "reason": "no_primary_photo"},
        )

    remote_url = primary.get("remoteUrl")
    if not isinstance(remote_url, str) or not remote_url.strip():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"match": False, "threshold": threshold, "reason": "invalid_primary_photo"},
        )

    try:
        validate_storage_path(remote_url, user_id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"match": False, "threshold": threshold, "reason": "invalid_primary_photo"},
        )

    try:
        primary_bytes = download_primary_photo(user_id)
    except RuntimeError:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"match": False, "threshold": threshold, "reason": "storage_failure"},
        )

    primary_result = get_face_embedding(primary_bytes)
    if not primary_result.success:
        reason = primary_result.reason or "invalid_primary_photo"
        if reason in ("no_face", "multiple_faces"):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail={"match": False, "threshold": threshold, "reason": "invalid_primary_photo"},
            )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={
                "match": False,
                "threshold": threshold,
                "reason": "primary_photo_embedding_failed",
            },
        )

    return primary_result.embedding, len(primary_bytes)


def _embed_angle(selfie_bytes: bytes, content_type: str | None, label: str, threshold: float, max_size: int) -> Any:
    """Validate + embed a single captured angle, tagging failures with the angle."""
    if not selfie_bytes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"match": False, "threshold": threshold, "reason": "missing_selfie", "angle": label},
        )

    if len(selfie_bytes) > max_size:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"match": False, "threshold": threshold, "reason": "file_too_large", "angle": label},
        )

    if content_type and content_type not in _ALLOWED_SELFIE_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"match": False, "threshold": threshold, "reason": "invalid_file_type", "angle": label},
        )

    try:
        normalized_bytes = normalize_image(selfie_bytes, content_type)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"match": False, "threshold": threshold, "reason": "invalid_file_type", "angle": label},
        )

    result = get_face_embedding(normalized_bytes)
    if not result.success:
        reason = result.reason or "invalid_image"
        code = (
            status.HTTP_400_BAD_REQUEST
            if reason == "invalid_image"
            else status.HTTP_422_UNPROCESSABLE_ENTITY
        )
        raise HTTPException(
            status_code=code,
            detail={"match": False, "threshold": threshold, "reason": reason, "angle": label},
        )

    return result.embedding


def verify_face_multi(images: list[tuple[bytes, str | None, str]], user_id: str) -> MultiVerificationResponse:
    """Verify a user from three controlled angles (front/left/right).

    Additive counterpart to :func:`verify_face`. Reuses the exact same
    embedding, cosine-similarity and threshold logic. Decision rule (approved):
    ``match = max(sim_front, sim_left, sim_right) >= threshold`` — never stricter
    than the single-front behaviour, robust to pose and to one poor capture. The
    per-angle similarities are returned for observability. This function never
    stores the captures anywhere; they exist only in memory for this request.
    """
    settings = get_settings()
    threshold = get_threshold()
    max_size = settings.MAX_SELFIE_SIZE_MB * 1024 * 1024

    check_rate_limit(user_id)

    angle_embeddings: dict[str, Any] = {}
    for selfie_bytes, content_type, label in images:
        angle_embeddings[label] = _embed_angle(
            selfie_bytes, content_type, label, threshold, max_size
        )

    primary_embedding, primary_len = _load_primary_embedding(user_id, threshold)

    similarities: dict[str, float] = {}
    for label, embedding in angle_embeddings.items():
        try:
            similarities[label] = cosine_similarity(embedding, primary_embedding)
        except Exception:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail={"match": False, "threshold": threshold, "reason": "matching_failed"},
            )

    best_similarity = max(similarities.values())
    match = is_match(best_similarity, threshold)

    print(
        f"[VerificationMulti] user={user_id} primary_bytes={primary_len} "
        f"similarities={{"
        + ", ".join(f"{k}:{v:.4f}" for k, v in similarities.items())
        + "}} "
        f"best={best_similarity:.4f} threshold={threshold:.2f} match={match} "
        f"reason={'match' if match else 'low_similarity'}",
        flush=True,
    )

    try:
        _update_verification_status(user_id, match)
    except RuntimeError:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={
                "match": False,
                "threshold": threshold,
                "reason": "verification_update_failed",
            },
        )

    return MultiVerificationResponse(
        match=match,
        threshold=threshold,
        reason="match" if match else "low_similarity",
        similarity=round(best_similarity, 4),
        angle_similarities={k: round(v, 4) for k, v in similarities.items()},
    )
