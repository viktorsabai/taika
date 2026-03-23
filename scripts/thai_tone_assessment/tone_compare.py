"""
Normalize user F0 contour (Hz -> semitones from median), DTW vs 5 tone templates,
assign tone_actual, tone_score (0–100), and feedback text.
"""
from __future__ import annotations

import sys
import math
import numpy as np
from fastdtw import fastdtw


def _log(msg: str) -> None:
    print(f"[tone_assess] {msg}", file=sys.stderr, flush=True)

from tone_templates import THAI_TONE_NAMES, get_tone_templates, TEMPLATE_LEN


# Диапазон речи для медианы: если медиана вне его, берём ближайшую границу (короткий фрагмент = неверная медиана).
REF_HZ_MIN, REF_HZ_MAX = 80.0, 350.0


def hz_to_semitones(f0_hz: np.ndarray, ref_hz: float | None = None) -> np.ndarray:
    """
    Convert F0 in Hz to semitones relative to ref_hz.
    If ref_hz is None, use median of valid f0, clamped to [REF_HZ_MIN, REF_HZ_MAX] for short/noisy clips.
    """
    out = np.full_like(f0_hz, np.nan, dtype=np.float64)
    valid = np.isfinite(f0_hz) & (f0_hz > 0)
    if not np.any(valid):
        _log("    в сегменте нет валидного F0 (pYIN не нашёл голос)")
        return out
    if ref_hz is None:
        ref_hz = float(np.nanmedian(f0_hz[valid]))
        ref_hz = max(REF_HZ_MIN, min(REF_HZ_MAX, ref_hz))
        _log(f"    медиана F0 (ref для полутонов): {ref_hz:.0f} Hz (после clamp [{REF_HZ_MIN},{REF_HZ_MAX}])")
    if ref_hz <= 0:
        return out
    out[valid] = 12.0 * np.log2(f0_hz[valid] / ref_hz)
    return out


def contour_to_fixed_length(
    times: np.ndarray,
    values: np.ndarray,
    n: int = TEMPLATE_LEN,
) -> np.ndarray:
    """
    Resample (times, values) to n points. Drops NaN; if no valid data, return flat zeros.
    """
    valid = np.isfinite(values)
    if not np.any(valid):
        return np.zeros(n)
    t = times[valid]
    v = values[valid]
    if len(t) < 2:
        return np.full(n, np.nanmean(v) if np.any(np.isfinite(v)) else 0.0)
    t_norm = (t - t.min()) / (t.max() - t.min() + 1e-10)
    target_t = np.linspace(0, 1, n)
    interp = np.interp(target_t, t_norm, v)
    return interp.astype(np.float64)


def dtw_distance(a: np.ndarray, b: np.ndarray) -> float:
    """Euclidean DTW distance between two 1D sequences."""
    a = np.asarray(a).reshape(-1, 1)
    b = np.asarray(b).reshape(-1, 1)
    dist, _ = fastdtw(a, b, radius=min(len(a), len(b)) // 2 + 1)
    return float(dist)


# Scale DTW distance to 0–100 score: score = max(0, 100 - k * dist)
# Меньше k = мягче к отклонениям. 5.0 было строго (dist 15 → 25%). 2.5: dist 15 → 62%, dist 20 → 50%.
DTW_K = 2.5


# Минимальный балл, чтобы не показывать 0% при «плохом» совпадении — пользователь видит, что оценка есть.
SCORE_FLOOR = 25


def tone_score_from_distance(dtw_dist: float, k: float = DTW_K) -> int:
    """Map DTW distance to 0–100 score. Ниже SCORE_FLOOR не опускаем (кроме пустого контура)."""
    s = 100.0 - k * dtw_dist
    return max(SCORE_FLOOR, min(100, int(round(s))))


def get_feedback(tone_expected: str, tone_actual: str, score: int) -> str:
    """Specific feedback for UI: match vs 'You used X instead of Y' + hint."""
    if tone_expected == tone_actual:
        if score >= 90:
            return "Perfect tone!"
        if score >= 70:
            return "Good tone."
        return "Right tone; try clearer pitch."
    # Mismatch: always say what they used vs what was expected
    base = f"You used {tone_actual} instead of {tone_expected}."
    hints = {
        ("Falling", "Mid"): "Your pitch stayed flat; it should fall at the end.",
        ("Falling", "Rising"): "Your pitch went up; it should fall.",
        ("Rising", "Mid"): "Your pitch stayed flat; it should rise at the end.",
        ("Rising", "Falling"): "Your pitch fell; it should rise.",
        ("Mid", "Falling"): "Your pitch fell; keep it flat and mid.",
        ("Mid", "Rising"): "Your pitch rose; keep it flat and mid.",
        ("Mid", "High"): "Your pitch was too high; keep it mid.",
        ("Mid", "Low"): "Your pitch was too low; keep it mid.",
        ("High", "Mid"): "Keep pitch high and flat.",
        ("Low", "Mid"): "Keep pitch low and flat.",
    }
    specific = hints.get((tone_expected, tone_actual))
    return f"{base} {specific}" if specific else base


def classify_contour(
    contour_semitones: np.ndarray,
    templates: dict[str, np.ndarray] | None = None,
) -> tuple[str, int, dict[str, float]]:
    """
    Compare contour (length TEMPLATE_LEN) to 5 templates via DTW.
    Returns (tone_actual, tone_score, distances_by_tone).
    """
    if templates is None:
        templates = get_tone_templates(len(contour_semitones))
    # Ensure same length
    n = len(contour_semitones)
    if np.any(np.isnan(contour_semitones)):
        contour_semitones = np.nan_to_num(contour_semitones, nan=0.0)
    distances = {}
    for name, tpl in templates.items():
        if len(tpl) != n:
            tpl = np.interp(np.linspace(0, 1, n), np.linspace(0, 1, len(tpl)), tpl)
        distances[name] = dtw_distance(contour_semitones, tpl)
    best = min(distances, key=distances.get)
    score = tone_score_from_distance(distances[best])
    dist_best = distances[best]
    _log(f"    DTW: {dict((k, round(v, 2)) for k, v in distances.items())} -> best={best} dist={dist_best:.2f} -> score={score}")
    return best, score, distances


# Если контур пустой/плоский (нет реального F0), не ставим 0% и случайный тон — отдаём нейтральную оценку.
CONTOUR_EMPTY_THRESHOLD = 0.5


def process_syllable_contour(
    times: np.ndarray,
    f0_hz: np.ndarray,
    tone_expected: str,
) -> tuple[str, int, str, np.ndarray]:
    """
    Normalize F0 to semitones, resample to template length, classify, get feedback.
    Returns (tone_actual, tone_score, feedback, contour_semitones) for optional UI plot.
    If contour has no usable pitch, returns (tone_expected, 50, "Not enough pitch data...", contour).
    """
    semitones = hz_to_semitones(f0_hz)
    contour = contour_to_fixed_length(times, semitones, TEMPLATE_LEN)
    contour_max = float(np.max(np.abs(contour)))
    if contour_max < CONTOUR_EMPTY_THRESHOLD:
        _log(f"  слог ожид.{tone_expected}: контур пустой (max_abs={contour_max:.2f} < {CONTOUR_EMPTY_THRESHOLD}) -> 50%, 'Not enough pitch data'")
        return (
            tone_expected,
            50,
            "Not enough pitch data to assess. Speak clearly, closer to the mic.",
            contour,
        )
    tone_actual, tone_score, _ = classify_contour(contour)
    # Логика для пользователя: верный тон → 100%; неверный тон → не выше 89%, чтобы не показывать «Идеальный тон!» при ошибке.
    if tone_actual == tone_expected:
        tone_score = 100
    else:
        tone_score = min(tone_score, 89)
    feedback = get_feedback(tone_expected, tone_actual, tone_score)
    return tone_actual, tone_score, feedback, contour
