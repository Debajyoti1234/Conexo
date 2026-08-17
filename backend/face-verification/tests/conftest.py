import os
import sys
import types
import numpy as np
from unittest.mock import MagicMock, patch

import pytest

# Ensure backend package is importable
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

os.environ.setdefault("SUPABASE_URL", "https://test.supabase.co")
os.environ.setdefault("SUPABASE_SERVICE_ROLE_KEY", "test-service-role-key")
os.environ.setdefault("VERIFICATION_THRESHOLD", "0.4")
os.environ.setdefault("MAX_SELFIE_SIZE_MB", "5")
os.environ.setdefault("RATE_LIMIT_WINDOW_SECONDS", "3600")
os.environ.setdefault("RATE_LIMIT_MAX_ATTEMPTS", "5")
os.environ.setdefault("ALLOWED_ORIGINS", "")
os.environ.setdefault("PORT", "8000")
os.environ.setdefault("LOG_LEVEL", "INFO")


@pytest.fixture(autouse=True)
def _reset_rate_limiter():
    from app.rate_limiter import _attempts, _lock

    with _lock:
        _attempts.clear()
    yield
    with _lock:
        _attempts.clear()


@pytest.fixture(autouse=True)
def _reset_face_analysis():
    from app import face as face_module

    face_module._FACE_ANALYSIS = None
    yield
    face_module._FACE_ANALYSIS = None


@pytest.fixture(autouse=True)
def _reset_settings():
    from app.config import _settings

    _settings = None
    yield
    _settings = None


@pytest.fixture()
def mock_supabase():
    mock = MagicMock()
    with patch("app.storage.create_client", return_value=mock), patch(
        "app.verification.create_client", return_value=mock
    ):
        yield mock


@pytest.fixture()
def mock_face_analysis():
    mock_app = MagicMock()
    mock_face = MagicMock()
    mock_face.get.return_value = [mock_face]
    mock_face.__getitem__.return_value = np.array([0.1, 0.2, 0.3], dtype=np.float32)
    mock_app.get.return_value = [mock_face]
    mock_app.prepare.return_value = None

    with patch("app.face.FaceAnalysis", return_value=mock_app):
        yield mock_app, mock_face


@pytest.fixture()
def client():
    from fastapi.testclient import TestClient
    from app.main import app

    return TestClient(app)
