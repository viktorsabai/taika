#!/usr/bin/env python3
"""
Phase C CLI: --text "มา" --audio path/to.wav.
Output: JSON with syllables[].syllable, tone_expected, tone_actual, tone_score, feedback.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

# Run from scripts/thai_tone_assessment so local imports work
sys.path.insert(0, str(Path(__file__).resolve().parent))

from pitch_tracker import extract_pitch_contours
from syllable_contract import expected_tones_for_chunks, phonetic_syllable_chunks
from tone_compare import process_syllable_contour


def _log(msg: str) -> None:
    print(f"[tone_assess] {msg}", file=sys.stderr, flush=True)


def parse_expected_tones(opt: str | None, n_syllables: int) -> list[str]:
    """
    Parse --expected-tones "Mid,Falling" to list; if missing or short, pad with "Mid".
    """
    default = "Mid"
    if not opt or not opt.strip():
        return [default] * n_syllables
    parts = [p.strip() for p in opt.split(",") if p.strip()]
    valid = {"Mid", "Low", "Falling", "High", "Rising"}
    out = []
    for p in parts:
        out.append(p if p in valid else default)
    while len(out) < n_syllables:
        out.append(default)
    return out[:n_syllables]


def assess(
    audio_path: str,
    text: str,
    expected_tones: str | None = None,
    phonetic: str | None = None,
) -> dict:
    """
    Run tone assessment; returns Phase D–compatible dict with total_score and syllables.
    Used by both CLI and API. On error returns {"error": "..."}.

    When `phonetic` is present, syllable count follows teaching chunks (same as iOS
    breakdown rows), not Thai tokenizer length.
    """
    chunks = phonetic_syllable_chunks(phonetic)
    _log(
        f"assess: audio={audio_path!r} text={text!r} expected_tones={expected_tones!r} "
        f"phonetic_chunks={len(chunks)}"
    )
    try:
        _log("extract_pitch_contours: start")
        contours = extract_pitch_contours(
            audio_path,
            text,
            syllable_labels=chunks or None,
        )
        _log("extract_pitch_contours: done")
    except Exception as e:
        _log(f"ошибка extract_pitch_contours: {e}")
        return {"error": str(e)}

    if not contours:
        _log("контуров нет (пустое аудио или текст)")
        return {"total_score": 0, "syllables": []}

    if chunks and len(chunks) == len(contours):
        expected_list = expected_tones_for_chunks(chunks)
        parsed = parse_expected_tones(expected_tones, len(contours))
        supplied = [p.strip() for p in (expected_tones or "").split(",") if p.strip()]
        if len(supplied) == len(contours):
            expected_list = parsed
    else:
        expected_list = parse_expected_tones(expected_tones, len(contours))
    syllables_out = []
    scores = []
    for idx, (c, tone_expected) in enumerate(zip(contours, expected_list)):
        syl_name = c.get("syllable", "?")
        _log(f"слог {idx+1} '{syl_name}' ожид.тон={tone_expected}:")
        tone_actual, tone_score, feedback, contour = process_syllable_contour(
            c["times"], c["f0_hz"], tone_expected
        )
        _log(f"  -> actual={tone_actual} score={tone_score}")
        syl_item = {
            "syllable": c["syllable"],
            "phoneme_score": None,
            "tone_expected": tone_expected,
            "tone_actual": tone_actual,
            "tone_score": tone_score,
            "feedback": feedback,
            "start_s": round(float(c.get("start_s", 0)), 3),
            "end_s": round(float(c.get("end_s", 0)), 3),
        }
        # Normalized pitch contour (semitones) for UI "wow" graph
        contour_list = contour.tolist() if hasattr(contour, "tolist") else list(contour)
        syl_item["f0_contour"] = [round(x, 2) for x in contour_list]
        syllables_out.append(syl_item)
        scores.append(tone_score)

    total_score = int(round(sum(scores) / len(scores))) if scores else 0
    _log(f"итог: scores={scores} total_score={total_score}")
    return {"total_score": total_score, "syllables": syllables_out}


def main() -> int:
    parser = argparse.ArgumentParser(description="Phase C: Thai tone assessment from WAV + text.")
    parser.add_argument("--text", required=True, help="Target Thai word or phrase")
    parser.add_argument("--audio", required=True, help="Path to WAV file (user recording)")
    parser.add_argument(
        "--expected-tones",
        default=None,
        help="Comma-separated expected tones per syllable, e.g. Mid,Falling (default: all Mid)",
    )
    parser.add_argument(
        "--phonetic",
        default=None,
        help="Cyrillic teaching phonetic; when set, audio is split into these chunks",
    )
    parser.add_argument("--pretty", action="store_true", help="Pretty-print JSON")
    args = parser.parse_args()

    audio_path = Path(args.audio)
    if not audio_path.is_file():
        print(json.dumps({"error": f"Audio file not found: {args.audio}"}), file=sys.stderr)
        return 1

    result = assess(str(audio_path), args.text, args.expected_tones, args.phonetic)
    if "error" in result:
        print(json.dumps(result), file=sys.stderr)
        return 1
    print(json.dumps(result, indent=2 if args.pretty else None, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
