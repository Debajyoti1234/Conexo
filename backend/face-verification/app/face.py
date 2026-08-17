import threading

import cv2
import numpy as np
from insightface.app import FaceAnalysis

from .config import get_settings

_FACE_ANALYSIS: FaceAnalysis | None = None
_LOCK = threading.Lock()


def _get_face_analysis() -> FaceAnalysis:
    global _FACE_ANALYSIS
    if _FACE_ANALYSIS is None:
        with _LOCK:
            if _FACE_ANALYSIS is None:
                app = FaceAnalysis(
                    name="buffalo_s",
                    root="/home/appuser/.insightface",
                    providers=["CPUExecutionProvider"],
                    allowed_modules=["detection", "recognition"],
                )
                app.prepare(ctx_id=-1, det_size=(640, 640))
                _FACE_ANALYSIS = app
    return _FACE_ANALYSIS


class FaceResult:
    def __init__(
        self,
        success: bool,
        reason: str | None = None,
        embedding: np.ndarray | None = None,
    ) -> None:
        self.success = success
        self.reason = reason
        self.embedding = embedding

    def to_dict(self) -> dict:
        return {
            "success": self.success,
            "reason": self.reason,
            "embedding": (
                self.embedding.tolist() if self.embedding is not None else None
            ),
        }


def decode_image(image_bytes: bytes) -> np.ndarray:
    if not image_bytes:
        raise ValueError("empty image bytes")

    buffer = np.frombuffer(image_bytes, np.uint8)
    image = cv2.imdecode(buffer, cv2.IMREAD_COLOR)
    if image is None:
        raise ValueError("unsupported image format or corrupt image")
    return image


def detect_single_face(image: np.ndarray) -> tuple[np.ndarray | None, str | None]:
    app = _get_face_analysis()
    faces = app.get(image)

    print(
        f"[FaceDetection] image_shape=({image.shape[0]}x{image.shape[1]}) "
        f"num_faces={len(faces)}",
        flush=True,
    )
    for i, face in enumerate(faces):
        bbox = face.get("bbox")
        det_score = face.get("det_score")
        if bbox is not None and len(bbox) == 4:
            x1, y1, x2, y2 = bbox
            w = max(0.0, x2 - x1)
            h = max(0.0, y2 - y1)
            area = w * h
            img_area = max(1.0, image.shape[0] * image.shape[1])
            area_ratio = area / img_area
            print(
                f"[FaceDetection] face_{i} bbox=({x1:.0f},{y1:.0f},{x2:.0f},{y2:.0f}) "
                f"size=({w:.0f}x{h:.0f}) area_ratio={area_ratio:.3f} "
                f"det_score={det_score:.3f}",
                flush=True,
            )

    if len(faces) == 0:
        return None, "no_face"
    if len(faces) > 1:
        return None, "multiple_faces"

    face = faces[0]
    embedding = face.get("embedding")
    if embedding is None:
        return None, "embedding_failed"

    return np.asarray(embedding, dtype=np.float32), None


def get_face_embedding(image_bytes: bytes) -> FaceResult:
    try:
        image = decode_image(image_bytes)
    except ValueError:
        return FaceResult(success=False, reason="invalid_image")

    embedding, reason = detect_single_face(image)
    if reason is not None:
        return FaceResult(success=False, reason=reason)

    return FaceResult(success=True, embedding=embedding)
