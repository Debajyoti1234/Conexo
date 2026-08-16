from unittest.mock import patch

import pytest

from app.image_utils import (
    _detect_heic_by_magic,
    _is_heic_by_type,
    normalize_image,
)


def test_normalize_image_empty_bytes():
    with pytest.raises(ValueError, match="empty image bytes"):
        normalize_image(b"")


def test_normalize_image_jpeg_passthrough():
    jpeg_bytes = b"\xff\xd8\xff\xe0\x00\x10JFIF" + b"\x00" * 100
    result = normalize_image(jpeg_bytes, content_type="image/jpeg")
    assert result == jpeg_bytes


def test_normalize_image_png_passthrough():
    png_bytes = b"\x89PNG\r\n\x1a\n" + b"\x00" * 100
    result = normalize_image(png_bytes, content_type="image/png")
    assert result == png_bytes


def test_normalize_image_webp_passthrough():
    webp_bytes = b"RIFF\x00\x00\x00\x00WEBP" + b"\x00" * 100
    result = normalize_image(webp_bytes, content_type="image/webp")
    assert result == webp_bytes


def test_normalize_image_heic_by_content_type():
    heic_bytes = b"\x00" * 12 + b"ftypheic" + b"\x00" * 100
    with patch("app.image_utils._convert_heic_to_jpeg", return_value=b"jpeg-bytes") as mock_convert:
        result = normalize_image(heic_bytes, content_type="image/heic")
        mock_convert.assert_called_once_with(heic_bytes)
        assert result == b"jpeg-bytes"


def test_normalize_image_heic_by_filename():
    heic_bytes = b"\x00" * 12 + b"ftypheic" + b"\x00" * 100
    with patch("app.image_utils._convert_heic_to_jpeg", return_value=b"jpeg-bytes") as mock_convert:
        result = normalize_image(heic_bytes, filename="photo.heic")
        mock_convert.assert_called_once_with(heic_bytes)
        assert result == b"jpeg-bytes"


def test_normalize_image_heic_by_magic_bytes():
    heic_bytes = b"\x00" * 4 + b"ftypheic" + b"\x00" * 100
    with patch("app.image_utils._convert_heic_to_jpeg", return_value=b"jpeg-bytes") as mock_convert:
        result = normalize_image(heic_bytes)
        mock_convert.assert_called_once_with(heic_bytes)
        assert result == b"jpeg-bytes"


def test_normalize_image_heif_by_magic_bytes():
    heif_bytes = b"\x00" * 4 + b"ftypmif1" + b"\x00" * 100
    with patch("app.image_utils._convert_heic_to_jpeg", return_value=b"jpeg-bytes") as mock_convert:
        result = normalize_image(heif_bytes)
        mock_convert.assert_called_once_with(heif_bytes)
        assert result == b"jpeg-bytes"


def test_normalize_image_heic_conversion_failure():
    heic_bytes = b"\x00" * 12 + b"ftypheic" + b"\x00" * 100
    with patch("app.image_utils._convert_heic_to_jpeg", side_effect=ValueError("bad heic")):
        with pytest.raises(ValueError, match="bad heic"):
            normalize_image(heic_bytes, content_type="image/heic")


def test_detect_heic_by_magic_positive():
    heic_bytes = b"\x00" * 4 + b"ftypheic" + b"\x00" * 100
    assert _detect_heic_by_magic(heic_bytes) is True


def test_detect_heic_by_magic_negative():
    jpeg_bytes = b"\xff\xd8\xff\xe0\x00\x10JFIF" + b"\x00" * 100
    assert _detect_heic_by_magic(jpeg_bytes) is False


def test_is_heic_by_type_content_type():
    assert _is_heic_by_type("image/heic", None) is True
    assert _is_heic_by_type("image/heif", None) is True
    assert _is_heic_by_type("image/jpeg", None) is False


def test_is_heic_by_type_filename():
    assert _is_heic_by_type(None, "photo.heic") is True
    assert _is_heic_by_type(None, "photo.heif") is True
    assert _is_heic_by_type(None, "photo.jpg") is False
