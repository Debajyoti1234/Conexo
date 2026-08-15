import pytest

from app.storage import (
    _BUCKET,
    _get_supabase_client,
    download_primary_photo,
    get_profile,
    get_primary_photo_metadata,
    resolve_primary_photo,
    validate_storage_path,
)


def test_resolve_primary_photo_empty():
    assert resolve_primary_photo([]) is None


def test_resolve_primary_photo_first_when_no_is_primary():
    photos = [
        {"id": "1", "isPrimary": False},
        {"id": "2", "isPrimary": False},
    ]
    result = resolve_primary_photo(photos)
    assert result["id"] == "1"


def test_resolve_primary_photo_prefers_is_primary():
    photos = [
        {"id": "1", "isPrimary": False},
        {"id": "2", "isPrimary": True},
    ]
    result = resolve_primary_photo(photos)
    assert result["id"] == "2"


def test_validate_storage_path_valid():
    path = validate_storage_path("profiles/user-1/photo.jpg", "user-1")
    assert path == "profiles/user-1/photo.jpg"


def test_validate_storage_path_rejects_absolute():
    with pytest.raises(ValueError):
        validate_storage_path("/profiles/user-1/photo.jpg", "user-1")


def test_validate_storage_path_rejects_traversal():
    with pytest.raises(ValueError):
        validate_storage_path("profiles/user-1/../other/photo.jpg", "user-1")


def test_validate_storage_path_rejects_wrong_user():
    with pytest.raises(ValueError):
        validate_storage_path("profiles/other-user/photo.jpg", "user-1")


def test_get_profile_returns_data(mock_supabase):
    mock_supabase.from_.return_value.select.return_value.eq.return_value.single.return_value.execute.return_value.data = {
        "id": "user-1",
        "photos": [],
    }
    result = get_profile("user-1")
    assert result["id"] == "user-1"


def test_download_primary_photo_missing_profile(mock_supabase):
    mock_supabase.from_.return_value.select.return_value.eq.return_value.single.return_value.execute.return_value.data = None
    with pytest.raises(RuntimeError):
        download_primary_photo("user-1")


def test_get_primary_photo_metadata_success(mock_supabase):
    mock_supabase.from_.return_value.select.return_value.eq.return_value.single.return_value.execute.return_value.data = {
        "id": "user-1",
        "photos": [
            {"id": "photo-1", "isPrimary": True, "remoteUrl": "profiles/user-1/photo-1.jpg"}
        ],
    }
    mock_supabase.storage.from_.return_value.list.return_value = [
        {"metadata": {"size": 1234}}
    ]
    result = get_primary_photo_metadata("user-1")
    assert result["photo_id"] == "photo-1"
    assert result["storage_path"] == "profiles/user-1/photo-1.jpg"
    assert result["size_bytes"] == 1234
