"""
Phase C: Load WAV, segment by syllables (PyThaiNLP + equal-duration split), extract F0 per segment (librosa.pyin).
"""
from __future__ import annotations

import sys
import numpy as np
import librosa
from scipy.io import wavfile


def _log(msg: str) -> None:
    print(f"[tone_assess] {msg}", file=sys.stderr, flush=True)


# Target sample rate for consistent F0 estimation
SR = 16000
# pYIN typical range for speech (Hz)
FMIN = 65
FMAX = 400


# Порог тишины для trim: выше = режем агрессивнее. 20 = мягче (тихий iPhone не «съест» запись).
TRIM_TOP_DB = 20

# Ограничение длительности аудио для pYIN (длинные фразы умного спикера — до ~25 с).
MAX_AUDIO_S = 25.0


def _load_wav_scipy(audio_path: str) -> tuple[np.ndarray, int]:
    """Load WAV with scipy (avoids librosa.load hang on some systems). Returns (y_float_mono, sample_rate)."""
    file_sr, data = wavfile.read(audio_path)
    if data.dtype in (np.int16, np.int32):
        y = data.astype(np.float64) / (32768.0 if data.dtype == np.int16 else 2147483648.0)
    else:
        y = np.asarray(data, dtype=np.float64)
    if y.ndim > 1:
        y = y.mean(axis=1)
    return y, int(file_sr)


def load_and_trim(audio_path: str, sr: int = SR) -> tuple[np.ndarray, int]:
    """Load WAV, convert to mono, trim leading/trailing silence, resample to sr."""
    path_lower = audio_path.lower()
    if path_lower.endswith(".wav") or path_lower.endswith(".wave"):
        _log("load_and_trim: scipy wavfile.read ...")
        y, file_sr = _load_wav_scipy(audio_path)
    else:
        _log("load_and_trim: librosa.load ...")
        y, file_sr = librosa.load(audio_path, sr=None, mono=True)
    if len(y) == 0 or file_sr <= 0:
        return np.asarray([], dtype=np.float64), sr
    dur0 = len(y) / float(file_sr)
    _log(f"load_and_trim: raw duration={dur0:.2f}s sr={file_sr}")
    if dur0 > MAX_AUDIO_S:
        _log(f"load_and_trim: cap to first {MAX_AUDIO_S:.1f}s (was {dur0:.2f}s)")
        y = y[: int(MAX_AUDIO_S * file_sr)]
    if file_sr != sr:
        _log(f"load_and_trim: resample {file_sr} -> {sr}")
        y = librosa.resample(y, orig_sr=file_sr, target_sr=sr)
    _log("load_and_trim: trim silence ...")
    y_trim, _ = librosa.effects.trim(y, top_db=TRIM_TOP_DB, frame_length=2048, hop_length=512)
    # Если trim отрезал почти всё (тихий микрофон) — не применяем trim, работаем с полной записью.
    if len(y_trim) < 0.15 * len(y):
        _log(f"trim отрезал почти всё ({len(y_trim)}/{len(y)} сэмплов) — используем полную запись")
        y_trim = y
    dur_s = len(y_trim) / sr
    _log(f"аудио: {dur_s:.2f} с ({len(y_trim)} сэмплов), sr={sr}")
    return y_trim, sr


# Частицы в конце фразы — отдельный слог для тона (สวัสดีครับ → ... + ครับ).
_TRAILING_PARTICLES = ("ครับ", "ค่ะ", "คะ", "นะ")

# Известные слова с фиксированным разбиением на слоги (са-ват-ди = 3), когда han_solo недоступен.
_KNOWN_WORD_SYLLABLES: dict[str, list[str]] = {
    "สวัสดี": ["ส", "วัส", "ดี"],  # sa-wat-dee (3 syllables)
}

def get_syllables_from_text(thai_text: str) -> list[str]:
    """Split Thai text into syllables. Prefer known words (e.g. สวัสดี→3), then PyThaiNLP, then fallbacks."""
    thai_text = (thai_text or "").strip()
    if not thai_text:
        return []
    # Сначала отрезаем конечную частицу (ครับ, ค่ะ и т.д.)
    rest = thai_text
    particle_suffix: str | None = None
    for particle in _TRAILING_PARTICLES:
        if thai_text.endswith(particle) and len(thai_text) > len(particle):
            rest = thai_text[: -len(particle)].strip()
            particle_suffix = particle
            break
    # Известные слова дают стабильное разбиение (напр. สวัสดี → 3 слога); приоритет над PyThaiNLP.
    if rest in _KNOWN_WORD_SYLLABLES:
        out = _KNOWN_WORD_SYLLABLES[rest].copy()
        if particle_suffix:
            out.append(particle_suffix)
        return out
    try:
        from pythainlp.tokenize import syllable_tokenize

        # Важно: не схлопывать всю фразу без частицы в один «слог» — иначе /assess даёт 2 слога (тело + кхрап).
        if rest:
            syllables = syllable_tokenize(rest, engine="han_solo", keep_whitespace=False)
            syllables = [s for s in syllables if s and not s.isspace()]
            if syllables:
                if particle_suffix:
                    syllables.append(particle_suffix)
                return syllables
        syllables = syllable_tokenize(thai_text, engine="han_solo", keep_whitespace=False)
        syllables = [s for s in syllables if s and not s.isspace()]
        if syllables:
            return syllables
    except Exception:
        pass
    if particle_suffix and rest:
        return [rest, particle_suffix]
    return [thai_text]


def _rms_frames(y: np.ndarray, frame_length: int = 512, hop_length: int = 256) -> np.ndarray:
    """RMS energy per frame (non-overlapping would be frame_length=hop_length; overlap for smoother)."""
    n_frames = max(1, (len(y) - frame_length) // hop_length + 1)
    rms = np.zeros(n_frames, dtype=np.float64)
    for i in range(n_frames):
        start = i * hop_length
        end = min(start + frame_length, len(y))
        if end > start:
            rms[i] = np.sqrt(np.mean(y[start:end] ** 2))
    return rms


def _boundaries_from_energy(
    y: np.ndarray,
    sr: int,
    n_segments: int,
    frame_length: int = 512,
    hop_length: int = 256,
    silence_threshold_percentile: float = 25.0,
) -> list[tuple[float, float]]:
    """
    Find n_segments boundaries by low energy (pauses) or dips.
    Returns list of (start_s, end_s) for each segment.
    """
    rms = _rms_frames(y, frame_length=frame_length, hop_length=hop_length)
    if len(rms) < n_segments:
        duration_s = len(y) / sr
        seg_dur = duration_s / n_segments
        return [(i * seg_dur, (i + 1) * seg_dur) for i in range(n_segments)]
    # Time (seconds) per frame
    t_per_frame = hop_length / sr
    # Cumulative energy (so we can prefer cuts at low energy)
    rms_smooth = np.maximum(rms, 1e-10)
    # Score each frame as a cut point: lower energy = better cut
    # We want n_segments-1 cut points (between segments)
    n_cuts = n_segments - 1
    # Prefer cuts where rms is low relative to neighbors
    window = max(2, len(rms) // (n_segments * 4))
    local_min = np.full_like(rms, np.nan)
    for i in range(window, len(rms) - window):
        local_min[i] = rms[i] if rms[i] <= np.min(rms[i - window : i + window + 1]) else np.nan
    valid = np.where(np.isfinite(local_min))[0]
    if len(valid) < n_cuts:
        # Fallback: spread cuts evenly
        indices = np.linspace(0, len(rms) - 1, n_cuts + 2).astype(int)[1:-1]
    else:
        # Choose n_cuts cut points at local energy minima, spread along time
        target_times = np.linspace(0, len(rms) - 1, n_cuts + 2)[1:-1]
        indices = []
        used = set()
        for t in target_times:
            i_center = int(round(t))
            best = i_center
            best_rms = float("inf")
            for j in range(max(0, i_center - len(rms) // (n_segments * 2)), min(len(rms), i_center + len(rms) // (n_segments * 2))):
                if j in used:
                    continue
                if np.isfinite(local_min[j]) and rms[j] < best_rms:
                    best_rms = rms[j]
                    best = j
            indices.append(best)
            used.add(best)
        indices = sorted(indices)
    cut_times_s = [0.0] + [float(i * t_per_frame) for i in indices] + [len(y) / sr]
    return [(cut_times_s[i], cut_times_s[i + 1]) for i in range(len(cut_times_s) - 1)]


def segment_audio_by_syllables(
    y: np.ndarray,
    sr: int,
    syllables: list[str],
    use_energy: bool = True,
) -> list[tuple[float, float]]:
    """
    Return time segments (start_s, end_s) for each syllable.
    If use_energy=True, uses energy/silence to find boundaries (better than equal split).
    Fallback: equal-duration split.
    """
    n = max(1, len(syllables))
    duration_s = len(y) / sr
    if use_energy and duration_s > 0.15 * n:
        try:
            segments = _boundaries_from_energy(y, sr, n)
            if len(segments) == n and all(b - a >= 0.05 for a, b in segments):
                return segments
        except Exception:
            pass
    segment_dur = duration_s / n
    return [(i * segment_dur, (i + 1) * segment_dur) for i in range(n)]


def extract_f0_segment(
    y: np.ndarray,
    sr: int,
    start_s: float,
    end_s: float,
    fmin: float = FMIN,
    fmax: float = FMAX,
) -> tuple[np.ndarray, np.ndarray]:
    """
    Extract F0 contour for a segment. Returns (times, f0_hz).
    Unvoiced frames are NaN; caller can interpolate or drop.
    """
    start_sample = int(start_s * sr)
    end_sample = int(end_s * sr)
    if start_sample >= end_sample:
        return np.array([]), np.array([])
    segment = y[start_sample:end_sample]
    seg_dur = len(segment) / float(sr) if sr > 0 else 0.0
    _log(f"    pyin: segment {start_s:.2f}-{end_s:.2f}s ({seg_dur:.2f}s) ...")
    f0, voiced_flag, _ = librosa.pyin(
        segment,
        sr=sr,
        fmin=fmin,
        fmax=fmax,
        fill_na=None,
    )
    # times relative to segment start
    hop = 512
    n_frames = len(f0)
    times = (np.arange(n_frames) * hop / sr).astype(np.float64)
    return times, np.asarray(f0, dtype=np.float64)


def extract_pitch_contours(
    audio_path: str,
    thai_text: str,
) -> list[dict]:
    """
    Load WAV and Thai text; return one dict per syllable with keys:
    - syllable: str
    - start_s, end_s: float
    - times: 1D array (time in segment)
    - f0_hz: 1D array (F0 per frame; NaN where unvoiced)
    """
    _log("extract_pitch_contours: load_and_trim...")
    y, sr = load_and_trim(audio_path, SR)
    _log("extract_pitch_contours: get_syllables_from_text...")
    syllables = get_syllables_from_text(thai_text)
    if not syllables:
        return []

    _log("extract_pitch_contours: segment_audio_by_syllables...")
    segments = segment_audio_by_syllables(y, sr, syllables)
    _log(f"слогов: {len(syllables)} {syllables}, сегменты: {[(round(a, 2), round(b, 2)) for a, b in segments]}")
    out = []
    for i, (start_s, end_s) in enumerate(segments):
        syl = syllables[i] if i < len(syllables) else ""
        times, f0_hz = extract_f0_segment(y, sr, start_s, end_s)
        n_valid = int(np.sum(np.isfinite(f0_hz) & (f0_hz > 0)))
        f0_min = float(np.nanmin(f0_hz)) if n_valid > 0 else float("nan")
        f0_max = float(np.nanmax(f0_hz)) if n_valid > 0 else float("nan")
        _log(f"  слог {i+1} '{syl}' [{start_s:.2f}-{end_s:.2f}s]: F0 кадров с голосом={n_valid}/{len(f0_hz)}, F0 мин/макс={f0_min:.0f}/{f0_max:.0f} Hz")
        out.append({
            "syllable": syl,
            "start_s": start_s,
            "end_s": end_s,
            "times": times,
            "f0_hz": f0_hz,
        })
    return out
