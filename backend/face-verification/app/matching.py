import numpy as np

from .config import get_settings


def cosine_similarity(embedding_a: np.ndarray, embedding_b: np.ndarray) -> float:
    a = np.asarray(embedding_a, dtype=np.float32)
    b = np.asarray(embedding_b, dtype=np.float32)

    if a.shape != b.shape:
        raise ValueError("embeddings must have the same shape")

    norm_a = np.linalg.norm(a)
    norm_b = np.linalg.norm(b)

    if norm_a == 0.0 or norm_b == 0.0:
        return 0.0

    similarity = float(np.dot(a, b) / (norm_a * norm_b))
    return float(np.clip(similarity, -1.0, 1.0))


def is_match(similarity: float, threshold: float) -> bool:
    return similarity >= threshold


def get_threshold() -> float:
    settings = get_settings()
    return float(settings.VERIFICATION_THRESHOLD)
