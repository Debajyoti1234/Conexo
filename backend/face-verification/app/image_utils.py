import io
from typing import Optional

import cv2
import numpy as np

_HEIC_MIME_TYPES = {"image/heic", "image/heif"}
_HEIC_EXTENSIONS = {".heic", ".heif"}


def _is_heic_by_type(content_type: Optional[str], filename: Optional[str]) -> bool:
    if content_type and content_type.lower() in _HEIC_MIME_TYPES:
        return True
    if filename:
        ext = "." + filename.rsplit(".", 1)[-1].lower() if "." in filename else ""
        return ext in _HEIC_EXTENSIONS
    return False


def _detect_heic_by_magic(image_bytes: bytes) -> bool:
    if len(image_bytes) < 12:
        return False
    if image_bytes[4:12] == b"ftypheic" or image_bytes[4:12] == b"ftypmif1":
        return True
    return False


def _convert_heic_to_jpeg(image_bytes: bytes) -> bytes:
    try:
        from PIL import Image
        from pillow_heif import register_heif_opener

        register_heif_opener()
        with Image.open(io.BytesIO(image_bytes)) as img:
            if img.mode in ("RGBA", "P"):
                img = img.convert("RGB")
            buffer = io.BytesIO()
            img.save(buffer, format="JPEG", quality=95)
            return buffer.getvalue()
    except Exception as exc:
        raise ValueError(f"unsupported image format or corrupt image: {exc}") from exc


def normalize_image(
    image_bytes: bytes,
    content_type: Optional[str] = None,
    filename: Optional[str] = None,
) -> bytes:
    if not image_bytes:
        raise ValueError("empty image bytes")

    if _is_heic_by_type(content_type, filename) or _detect_heic_by_magic(image_bytes):
        return _convert_heic_to_jpeg(image_bytes)

    return image_bytes
