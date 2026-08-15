import time

import pytest
from fastapi import HTTPException

from app.rate_limiter import check_rate_limit


def test_rate_limit_allows_up_to_max():
    user_id = "user-rate-1"
    for _ in range(5):
        check_rate_limit(user_id)


def test_rate_limit_blocks_after_max():
    user_id = "user-rate-2"
    for _ in range(5):
        check_rate_limit(user_id)

    with pytest.raises(HTTPException) as exc_info:
        check_rate_limit(user_id)
    assert exc_info.value.status_code == 429
    assert exc_info.value.detail["reason"] == "rate_limit_exceeded"
    assert "Retry-After" in exc_info.value.headers


def test_rate_limit_independent_users():
    user_a = "user-rate-a"
    user_b = "user-rate-b"

    for _ in range(5):
        check_rate_limit(user_a)

    with pytest.raises(HTTPException):
        check_rate_limit(user_a)

    # user_b should still be allowed
    check_rate_limit(user_b)
