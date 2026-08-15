import time
from threading import Lock

from fastapi import HTTPException, status

from .config import get_settings

_attempts: dict[str, list[float]] = {}
_lock = Lock()


def _cleanup(user_id: str, window: float) -> None:
    cutoff = time.time() - window
    timestamps = _attempts.get(user_id, [])
    _attempts[user_id] = [t for t in timestamps if t > cutoff]
    if not _attempts[user_id]:
        _attempts.pop(user_id, None)


def check_rate_limit(user_id: str) -> None:
    settings = get_settings()
    window = float(settings.RATE_LIMIT_WINDOW_SECONDS)
    max_attempts = int(settings.RATE_LIMIT_MAX_ATTEMPTS)
    threshold = float(settings.VERIFICATION_THRESHOLD)

    with _lock:
        _cleanup(user_id, window)
        timestamps = _attempts.get(user_id, [])
        if len(timestamps) >= max_attempts:
            retry_after = 0.0
            if timestamps:
                oldest = timestamps[0]
                retry_after = max(0.0, oldest + window - time.time())
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail={
                    "match": False,
                    "threshold": threshold,
                    "reason": "rate_limit_exceeded",
                },
                headers={"Retry-After": str(int(retry_after))},
            )
        timestamps.append(time.time())
        _attempts[user_id] = timestamps
