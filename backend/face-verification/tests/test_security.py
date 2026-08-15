import os
from unittest.mock import patch, MagicMock

from fastapi.testclient import TestClient
from jose import jwt as jose_jwt

from app.main import app
from app.config import get_settings
from app.verification import verify_face


def test_no_service_role_key_in_health_response(client: TestClient):
    response = client.get("/health")
    assert response.status_code == 200
    body = response.text
    assert "sb_secret_" not in body
    assert "service-role" not in body.lower()


def test_generic_exception_handler_format():
    from app.main import generic_exception_handler
    import asyncio

    mock_request = MagicMock()
    exc = RuntimeError("secret-boom")
    response = asyncio.run(generic_exception_handler(mock_request, exc))
    assert response.status_code == 500
    body = response.body.decode()
    assert "secret-boom" not in body
    assert "internal_error" in body


def test_cors_allows_configured_origin():
    os.environ["ALLOWED_ORIGINS"] = "https://conexo.app,https://admin.conexo.app"

    import app.config

    app.config._settings = None
    settings = get_settings()
    assert "https://conexo.app" in settings.allowed_origins
    assert "https://admin.conexo.app" in settings.allowed_origins
    assert "*" not in settings.allowed_origins
    app.config._settings = None


def test_cors_localhost_fallback_when_empty():
    os.environ["ALLOWED_ORIGINS"] = ""

    import app.config

    app.config._settings = None
    settings = get_settings()
    assert "http://localhost:5000" in settings.allowed_origins
    assert "http://127.0.0.1:5000" in settings.allowed_origins
    app.config._settings = None
