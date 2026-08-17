from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer
from fastapi import File, UploadFile
from fastapi.responses import JSONResponse
from typing import Any
from uuid import UUID
import asyncio
import logging

from .config import get_settings
from .auth import get_current_user_id
from .storage import get_primary_photo_metadata
from .verification import verify_face, verify_face_multi, MULTI_ANGLE_LABELS
from .matching import get_threshold

logger = logging.getLogger(__name__)
settings = get_settings()

app = FastAPI(
    title="Conexo Face Verification",
    description="Server-authoritative profile-photo face matching for Conexo.",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health", tags=["Health"])
async def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/api/v1/auth/me", tags=["Auth"])
async def auth_me(
    current_user_id: UUID = Depends(get_current_user_id),
) -> dict[str, str]:
    return {"user_id": str(current_user_id)}


@app.get("/api/v1/profile/primary-photo", tags=["Profile"])
async def get_profile_primary_photo(
    current_user_id: UUID = Depends(get_current_user_id),
) -> dict[str, Any]:
    metadata = get_primary_photo_metadata(str(current_user_id))
    return metadata


@app.post("/api/v1/verify-face", tags=["Verification"])
async def verify_face_endpoint(
    current_user_id: UUID = Depends(get_current_user_id),
    selfie: UploadFile = File(...),
) -> dict[str, Any]:
    content_type = selfie.content_type or ""
    selfie_bytes = await selfie.read()
    if not selfie_bytes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "match": False,
                "threshold": get_threshold(),
                "reason": "missing_selfie",
            },
        )

    print(
        f"Verification upload filename={selfie.filename} "
        f"content_type={content_type} "
        f"bytes={len(selfie_bytes)}",
        flush=True,
    )

    try:
        result = await asyncio.wait_for(
            asyncio.to_thread(verify_face, selfie_bytes, content_type, str(current_user_id)),
            timeout=30.0,
        )
    except asyncio.TimeoutError:
        logger.exception("Verification timeout for user %s", current_user_id)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={
                "match": False,
                "threshold": get_threshold(),
                "reason": "internal_error",
            },
        )
    return result.model_dump()


@app.post("/api/v1/verify-face-multi", tags=["Verification"])
async def verify_face_multi_endpoint(
    current_user_id: UUID = Depends(get_current_user_id),
    selfie_front: UploadFile = File(...),
    selfie_left: UploadFile = File(...),
    selfie_right: UploadFile = File(...),
) -> dict[str, Any]:
    """Additive 3-angle verification. The single /verify-face endpoint above is
    left intact as a fallback."""
    uploads = {
        "front": selfie_front,
        "left": selfie_left,
        "right": selfie_right,
    }

    images: list[tuple[bytes, str, str]] = []
    for label in MULTI_ANGLE_LABELS:
        upload = uploads[label]
        content_type = upload.content_type or ""
        selfie_bytes = await upload.read()
        if not selfie_bytes:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={
                    "match": False,
                    "threshold": get_threshold(),
                    "reason": "missing_selfie",
                    "angle": label,
                },
            )
        print(
            f"VerificationMulti upload angle={label} filename={upload.filename} "
            f"content_type={content_type} bytes={len(selfie_bytes)}",
            flush=True,
        )
        images.append((selfie_bytes, content_type, label))

    try:
        result = await asyncio.wait_for(
            asyncio.to_thread(verify_face_multi, images, str(current_user_id)),
            timeout=45.0,
        )
    except asyncio.TimeoutError:
        logger.exception("Multi verification timeout for user %s", current_user_id)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={
                "match": False,
                "threshold": get_threshold(),
                "reason": "internal_error",
            },
        )
    return result.model_dump()
async def generic_exception_handler(request, exc):
    logger.exception("Unhandled exception: %s", exc)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "match": False,
            "threshold": get_threshold(),
            "reason": "internal_error",
        },
    )


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=settings.PORT,
        reload=True,
    )