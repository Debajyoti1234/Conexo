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

    allowed_types = {"image/jpeg", "image/png", "image/webp"}
    if content_type and content_type not in allowed_types:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "match": False,
                "threshold": threshold,
                "reason": "invalid_file_type",
            },
        )

    selfie_result = get_face_embedding(selfie_bytes)
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
