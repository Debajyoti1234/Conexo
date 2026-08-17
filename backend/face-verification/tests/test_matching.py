import numpy as np

from app.matching import cosine_similarity, is_match


def test_identical_vectors():
    a = np.array([1.0, 0.0, 0.0], dtype=np.float32)
    b = np.array([1.0, 0.0, 0.0], dtype=np.float32)
    similarity = cosine_similarity(a, b)
    assert abs(similarity - 1.0) < 1e-5


def test_orthogonal_vectors():
    a = np.array([1.0, 0.0, 0.0], dtype=np.float32)
    b = np.array([0.0, 1.0, 0.0], dtype=np.float32)
    similarity = cosine_similarity(a, b)
    assert abs(similarity - 0.0) < 1e-5


def test_opposite_vectors():
    a = np.array([1.0, 0.0, 0.0], dtype=np.float32)
    b = np.array([-1.0, 0.0, 0.0], dtype=np.float32)
    similarity = cosine_similarity(a, b)
    assert abs(similarity - (-1.0)) < 1e-5


def test_zero_vector():
    a = np.array([0.0, 0.0, 0.0], dtype=np.float32)
    b = np.array([1.0, 0.0, 0.0], dtype=np.float32)
    similarity = cosine_similarity(a, b)
    assert similarity == 0.0


def test_no_nan_or_inf():
    a = np.array([1.0, 2.0, 3.0], dtype=np.float32)
    b = np.array([4.0, 5.0, 6.0], dtype=np.float32)
    similarity = cosine_similarity(a, b)
    assert not np.isnan(similarity)
    assert not np.isinf(similarity)


def test_threshold_boundary():
    assert is_match(0.4, 0.4) is True
    assert is_match(0.4000001, 0.4) is True
    assert is_match(0.3999999, 0.4) is False


def test_below_threshold():
    assert is_match(0.3, 0.4) is False


def test_above_threshold():
    assert is_match(0.8, 0.4) is True
