#!/usr/bin/env python3
"""
Читает steps.json, собирает все фразы для спикера (phrase/casual/word с thai).
Режимы:
  1) --manifest-only — вывести manifest.json: список { step_id, course_id, lesson_id, thai, phonetic }.
  2) --audio-dir DIR — для каждого шага искать WAV (step_id.wav или <thai>.wav), гнать pitch_tracker,
     сохранить reference_contours.json: { step_id: { "syllables": [ { "syllable", "f0_contour" } ] } }.
Пример:
  python steps_to_contours.py --steps ../../steps.json --manifest-only -o manifest.json
  python steps_to_contours.py --steps ../../steps.json --audio-dir ./reference_wavs -o reference_contours.json
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

def _log(msg: str) -> None:
    print(f"[steps_to_contours] {msg}", file=sys.stderr, flush=True)


# Стрелки в phonetic → ожидаемый тон для expected_tones
PHONETIC_ARROWS = {"↘": "Falling", "→": "Mid", "↗": "Rising", "↓": "Low", "↑": "High"}


def parse_expected_tones_from_phonetic(phonetic: str) -> str | None:
    """Из phonetic вида 'са-ват-ди↘ тук-кхон→' вытащить comma-separated тона по слогам."""
    if not phonetic or not phonetic.strip():
        return None
    # Разбиваем по пробелу и дефису, ищем стрелки в конце слогов
    parts = re.split(r"[\s\-·]+", phonetic.strip())
    tones = []
    for p in parts:
        p = p.strip()
        if not p:
            continue
        for arrow, tone in PHONETIC_ARROWS.items():
            if p.endswith(arrow):
                tones.append(tone)
                break
        else:
            tones.append("Mid")
    return ",".join(tones) if tones else None


def collect_speaker_items(steps_path: Path) -> list[dict]:
    """Собрать все шаги с thai для спикера (kind phrase, casual, word)."""
    with open(steps_path, "r", encoding="utf-8") as f:
        data = json.load(f)
    out = []
    for stepset in data.get("stepsets", []):
        course_id = stepset.get("course_id", "")
        lesson_id = stepset.get("lesson_id", "")
        stepset_id = stepset.get("id", "")
        for item in stepset.get("items", []):
            kind = item.get("kind", "")
            if kind not in ("phrase", "casual", "word"):
                continue
            thai = (item.get("thai") or "").strip()
            if not thai or thai == "…":
                continue
            order = item.get("order", 0)
            phonetic = (item.get("phonetic") or "").strip()
            step_id = f"{stepset_id}_{order}" if stepset_id else f"{course_id}_{lesson_id}_{order}"
            expected_tones = parse_expected_tones_from_phonetic(phonetic)
            out.append({
                "step_id": step_id,
                "course_id": course_id,
                "lesson_id": lesson_id,
                "order": order,
                "kind": kind,
                "thai": thai,
                "phonetic": phonetic,
                "expected_tones": expected_tones,
            })
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description="Steps.json → manifest or reference contours from WAVs.")
    ap.add_argument("--steps", default=None, help="Path to steps.json (default: repo root steps.json)")
    ap.add_argument("-o", "--output", default=None, help="Output JSON path")
    ap.add_argument("--manifest-only", action="store_true", help="Only output manifest of phrases (no audio)")
    ap.add_argument("--audio-dir", default=None, help="Dir with WAVs: step_id.wav or <thai>.wav")
    args = ap.parse_args()

    # Script lives in repo/scripts/thai_tone_assessment/ → repo root is parent.parent.parent
    repo_root = Path(__file__).resolve().parent.parent.parent
    steps_path = Path(args.steps) if args.steps else (repo_root / "steps.json")
    if not steps_path.is_file():
        _log(f"steps not found: {steps_path}")
        return 1

    items = collect_speaker_items(steps_path)
    _log(f"collected {len(items)} speaker phrases from {steps_path}")

    if args.manifest_only:
        out_path = Path(args.output or (repo_root / "scripts" / "thai_tone_assessment" / "manifest.json"))
        out_path.parent.mkdir(parents=True, exist_ok=True)
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump({"steps": items}, f, ensure_ascii=False, indent=2)
        _log(f"wrote manifest to {out_path}")
        return 0

    if args.audio_dir:
        from pitch_tracker import extract_pitch_contours
        from tone_compare import hz_to_semitones, contour_to_fixed_length
        from tone_templates import TEMPLATE_LEN
        import numpy as np

        audio_dir = Path(args.audio_dir)
        if not audio_dir.is_dir():
            _log(f"audio-dir not found: {audio_dir}")
            return 1
        contours_by_step: dict[str, dict] = {}
        for it in items:
            step_id = it["step_id"]
            thai = it["thai"]
            # Ищем WAV: step_id.wav или имя из thai (без пробелов)
            wav_name = f"{step_id}.wav"
            alt_name = re.sub(r"\s+", "_", thai) + ".wav"
            wav_path = audio_dir / wav_name
            if not wav_path.is_file():
                wav_path = audio_dir / alt_name
            if not wav_path.is_file():
                _log(f"skip {step_id}: no WAV {wav_name} or {alt_name}")
                continue
            try:
                contours = extract_pitch_contours(str(wav_path), thai)
            except Exception as e:
                _log(f"skip {step_id}: {e}")
                continue
            if not contours:
                _log(f"skip {step_id}: no contours")
                continue
            syllables = []
            for c in contours:
                f0_hz = c.get("f0_hz")
                times = c.get("times")
                if f0_hz is None or times is None or len(f0_hz) == 0:
                    continue
                st = hz_to_semitones(np.asarray(f0_hz))
                fixed = contour_to_fixed_length(
                    np.asarray(times), st, TEMPLATE_LEN
                )
                syllables.append({
                    "syllable": c.get("syllable", "?"),
                    "f0_contour": [round(float(x), 2) for x in fixed],
                })
            contours_by_step[step_id] = {"syllables": syllables, "thai": thai}
            _log(f"ok {step_id} ({len(syllables)} syllables)")
        out_path = Path(args.output or (audio_dir / "reference_contours.json"))
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(contours_by_step, f, ensure_ascii=False, indent=2)
        _log(f"wrote reference contours to {out_path} ({len(contours_by_step)} steps)")
        return 0

    _log("use --manifest-only or --audio-dir")
    return 1


if __name__ == "__main__":
    sys.exit(main())
