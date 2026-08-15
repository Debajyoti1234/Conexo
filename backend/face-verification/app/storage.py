from typing import Any

from supabase import create_client
from postgrest.exceptions import APIError as PostgrestException

from .config import get_settings

_BUCKET = "profile-photos"


def _get_supabase_client() -> Any:
    settings = get_settings()
    return create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_ROLE_KEY)


def get_profile(user_id: str) -> dict[str, Any]:
    client = _get_supabase_client()
    try:
        result = (
            client.from_("profiles")
            .select("id, photos")
            .eq("id", user_id)
            .single()
            .execute()
        )
        return result.data
    except PostgrestException:
        raise
    except Exception as exc:
        raise RuntimeError("Unable to load profile") from exc


def resolve_primary_photo(photos: Any) -> dict[str, Any] | None:
    if not isinstance(photos, list) or len(photos) == 0:
        return None

    selected = None
    for photo in photos:
        if isinstance(photo, dict) and photo.get("isPrimary"):
            selected = photo
            break

    if selected is None:
        selected = photos[0]

    if not isinstance(selected, dict):
        return None

    return selected


def validate_storage_path(path: Any, user_id: str) -> str:
    if not isinstance(path, str) or not path.strip():
        raise ValueError("missing storage path")

    path = path.strip()

    if path.startswith("/"):
        raise ValueError("absolute path not allowed")

    if ".." in path:
        raise ValueError("path traversal not allowed")

    expected_prefix = f"profiles/{user_id}/"
    if not path.startswith(expected_prefix):
        raise ValueError("path does not belong to user")

    return path


def download_primary_photo(user_id: str) -> bytes:
    profile = get_profile(user_id)
    if not isinstance(profile, dict):
        raise RuntimeError("Unable to load primary profile photo")

    photos = profile.get("photos")
    primary = resolve_primary_photo(photos)
    if primary is None:
        raise RuntimeError("Unable to load primary profile photo")

    remote_url = primary.get("remoteUrl")
    if not isinstance(remote_url, str) or not remote_url.strip():
        raise RuntimeError("Unable to load primary profile photo")

    path = validate_storage_path(remote_url, user_id)

    client = _get_supabase_client()
    try:
        result = client.storage.from_(_BUCKET).download(path)
    except Exception as exc:
        raise RuntimeError("Unable to load primary profile photo") from exc

    if not isinstance(result, bytes) or len(result) == 0:
        raise RuntimeError("Unable to load primary profile photo")

    return result


def get_primary_photo_metadata(user_id: str) -> dict[str, Any]:
    profile = get_profile(user_id)
    if not isinstance(profile, dict):
        raise RuntimeError("Unable to load primary profile photo")

    photos = profile.get("photos")
    primary = resolve_primary_photo(photos)
    if primary is None:
        raise RuntimeError("Unable to load primary profile photo")

    remote_url = primary.get("remoteUrl")
    if not isinstance(remote_url, str) or not remote_url.strip():
        raise RuntimeError("Unable to load primary profile photo")

    path = validate_storage_path(remote_url, user_id)

    client = _get_supabase_client()
    try:
        files = client.storage.from_(_BUCKET).list(path)
    except Exception as exc:
        raise RuntimeError("Unable to load primary profile photo") from exc

    size_bytes = 0
    if isinstance(files, list):
        for item in files:
            if isinstance(item, dict):
                size_bytes += int(item.get("metadata", {}).get("size", 0) or 0)

    return {
        "user_id": user_id,
        "photo_id": primary.get("id", ""),
        "storage_path": path,
        "size_bytes": size_bytes,
    }
