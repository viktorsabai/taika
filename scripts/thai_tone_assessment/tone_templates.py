"""
Reference contours for the 5 Thai tones (normalized semitones over 0–1 time).
Used for DTW comparison with user pitch contours.
"""
from __future__ import annotations

import numpy as np

# Standard names for API output
THAI_TONE_NAMES = ["Mid", "Low", "Falling", "High", "Rising"]

# Number of points per template (fixed length for DTW)
TEMPLATE_LEN = 32


def _mid_contour(n: int) -> np.ndarray:
    """Mid tone: relatively flat around 0."""
    return np.zeros(n)

def _low_contour(n: int) -> np.ndarray:
    """Low tone: low flat (e.g. -3 semitones)."""
    return np.full(n, -3.0)

def _high_contour(n: int) -> np.ndarray:
    """High tone: high flat (e.g. +3 semitones)."""
    return np.full(n, 3.0)

def _falling_contour(n: int) -> np.ndarray:
    """Falling: start high, end low (e.g. +2 to -2 semitones)."""
    t = np.linspace(0, 1, n)
    return 2.0 - 4.0 * t

def _rising_contour(n: int) -> np.ndarray:
    """Rising: start low, end high (e.g. -2 to +2 semitones)."""
    t = np.linspace(0, 1, n)
    return -2.0 + 4.0 * t


def get_tone_templates(n: int = TEMPLATE_LEN) -> dict[str, np.ndarray]:
    """
    Return dict mapping tone name (Mid, Low, Falling, High, Rising) to 1D contour
    of length n (semitones, normalized).
    """
    return {
        "Mid": _mid_contour(n),
        "Low": _low_contour(n),
        "Falling": _falling_contour(n),
        "High": _high_contour(n),
        "Rising": _rising_contour(n),
    }


def get_template_array(n: int = TEMPLATE_LEN) -> np.ndarray:
    """Return (5, n) array in order: Mid, Low, Falling, High, Rising."""
    templates = get_tone_templates(n)
    return np.array([templates[name] for name in THAI_TONE_NAMES])
