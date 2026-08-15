import numpy as np
from unittest.mock import MagicMock

import pytest

from app.face import (
    FaceResult,
    decode_image,
    detect_single_face,
    get_face_embedding,
)


def _encode_fake_image() -> bytes:
    image = np.zeros((10, 10, 3), dtype=np.uint8)
    import cv2

    _, buf = cv2.imencode(".jpg", image)
    return buf.tobytes()


def test_decode_image_valid():
    image = decode_image(_encode_fake_image())
    assert image.shape == (10, 10, 3)


def test_decode_image_empty():
    with pytest.raises(ValueError):
        decode_image(b"")


def test_decode_image_invalid():
    with pytest.raises(ValueError):
        decode_image(b"not-an-image")


def test_get_face_embedding_invalid_image():
    result = get_face_embedding(b"not-an-image")
    assert result.success is False
    assert result.reason == "invalid_image"


def test_detect_single_face_no_face():
    from app import face as face_module

    mock_app = MagicMock()
    mock_app.get.return_value = []
    face_module._FACE_ANALYSIS = mock_app
    try:
        embedding, reason = detect_single_face(np.zeros((10, 10, 3), dtype=np.uint8))
    finally:
        face_module._FACE_ANALYSIS = None
    assert embedding is None
    assert reason == "no_face"


def test_detect_single_face_multiple_faces():
    from app import face as face_module

    mock_app = MagicMock()
    mock_face = MagicMock()
    mock_app.get.return_value = [mock_face, mock_face]
    face_module._FACE_ANALYSIS = mock_app
    try:
        embedding, reason = detect_single_face(np.zeros((10, 10, 3), dtype=np.uint8))
    finally:
        face_module._FACE_ANALYSIS = None
    assert embedding is None
    assert reason == "multiple_faces"


def test_detect_single_face_success():
    from app import face as face_module

    mock_app = MagicMock()
    mock_face = MagicMock()
    mock_app.get.return_value = [mock_face]
    mock_face.get.return_value = np.array([0.1, 0.2, 0.3], dtype=np.float32)
    face_module._FACE_ANALYSIS = mock_app
    try:
        embedding, reason = detect_single_face(np.zeros((10, 10, 3), dtype=np.uint8))
    finally:
        face_module._FACE_ANALYSIS = None
    assert reason is None
    assert embedding is not None
    assert embedding.shape == (3,)


def test_detect_single_face_embedding_failed():
    from app import face as face_module

    mock_app = MagicMock()
    mock_face = MagicMock()
    mock_app.get.return_value = [mock_face]
    mock_face.get.return_value = None
    face_module._FACE_ANALYSIS = mock_app
    try:
        embedding, reason = detect_single_face(np.zeros((10, 10, 3), dtype=np.uint8))
    finally:
        face_module._FACE_ANALYSIS = None
    assert embedding is None
    assert reason == "embedding_failed"
