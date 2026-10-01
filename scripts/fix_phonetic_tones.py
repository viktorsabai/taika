#!/usr/bin/env python3
"""
Нормализация phonetic в steps.json:
1. У каждого слога в phonetic должен быть ровно один из 5 тонов: → (Mid), ↓ (Low), ↘ (Falling), ↑ (High), ↗ (Rising).
2. Тон каждого слога пересчитывается по тайской орфографии (thai_taika_phonetic.retone_phonetic):
   меняются только стрелки, кириллица остаётся авторской. Если слоги тайского и phonetic
   не сопоставились 1:1 — стрелки остаются как были.
3. Слоги без стрелки (и без сопоставления) получают → (Mid).
4. Замена en-dash (U+2011) на ASCII hyphen для корректного разбора по слогам.

Использование:
  python fix_phonetic_tones.py --steps ../steps.json [--dry-run] [--backup] [--report out.json]
  --dry-run              только отчёт, не менять файл
  --backup               перед записью скопировать steps.json в steps.json.bak-<время>
  --keep-authored-tones  не пересчитывать тоны (только п.3–4); не требует pythainlp
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

# Пять тонов для Speaker и tone API (как в SpeakerManager.swift и steps_to_contours.py)
TONES = ("→", "↓", "↘", "↑", "↗")  # Mid, Low, Falling, High, Rising


def normalize_phonetic(phonetic: str) -> str:
    """
    Приводит phonetic к виду, где каждый слог заканчивается ровно одной стрелкой тона.
    Слоги без стрелки получают → (Mid). En-dash заменяется на ASCII hyphen.
    """
    if not phonetic or not phonetic.strip():
        return phonetic
    # Единый hyphen между слогами (spec: только ASCII -)
    raw = phonetic.strip().replace("\u2011", "-")
    words = raw.split()
    result_words = []
    for word in words:
        # Разбиваем по дефису и middle dot (как в steps_to_contours)
        parts = re.split(r"[-·]+", word)
        new_parts = []
        for p in parts:
            p = p.strip()
            if not p:
                continue
            # Уже есть одна из 5 стрелок в конце — оставляем как есть
            if any(p.endswith(t) for t in TONES):
                new_parts.append(p)
                continue
            # Убираем любые хвостовые стрелки (если вдруг дубль или лишний символ), потом добавляем тон
            s = p
            while s and s[-1] in TONES:
                s = s[:-1]
            if not s:
                continue
            new_parts.append(s + "→")
        result_words.append("-".join(new_parts))
    return " ".join(result_words)


def load_retone():
    """thai_taika_phonetic.retone_phonetic; exits with an install hint when pythainlp is missing."""
    try:
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        from thai_taika_phonetic import retone_phonetic
    except ImportError as e:
        print(
            f"Error: tone engine unavailable ({e}).\n"
            "pip3 install pythainlp python-crfsuite, or pass --keep-authored-tones",
            file=sys.stderr,
        )
        sys.exit(1)
    return retone_phonetic


def retone_steps(data: dict, retone=None) -> tuple[list[dict], list[dict]]:
    """Normalize every card phonetic in a steps document in place. Returns (changed, skipped).

    Generators that write steps.json call this right before saving, so hand-typed
    arrows never reach the app unchecked.
    """
    changed: list[dict] = []
    skipped: list[dict] = []
    for stepset in data.get("stepsets", []):
        for item in stepset.get("items", []):
            if item.get("kind") not in ("word", "phrase", "casual"):
                continue
            phonetic = item.get("phonetic")
            if phonetic is None:
                continue
            new_phonetic = normalize_phonetic(phonetic)
            if retone:
                thai = (item.get("thai") or "").strip()
                toned = retone(thai, new_phonetic)
                if toned is None:
                    skipped.append({"lesson": stepset.get("lesson_id"), "order": item.get("order"),
                                    "thai": thai, "phonetic": phonetic})
                else:
                    new_phonetic = toned
            if new_phonetic != phonetic:
                changed.append({"lesson": stepset.get("lesson_id"), "order": item.get("order"),
                                "thai": item.get("thai"), "from": phonetic, "to": new_phonetic})
                item["phonetic"] = new_phonetic
    return changed, skipped


def main() -> None:
    ap = argparse.ArgumentParser(description="Normalize phonetic tones in steps.json")
    ap.add_argument("--steps", type=Path, default=Path("steps.json"), help="Path to steps.json")
    ap.add_argument("--dry-run", action="store_true", help="Report only, do not write")
    ap.add_argument("--backup", action="store_true", help="Backup steps.json before writing")
    ap.add_argument(
        "--keep-authored-tones",
        action="store_true",
        help="Only fill missing arrows with →; do not recompute tones from Thai spelling",
    )
    ap.add_argument("--report", type=Path, help="Write every tone change / skip to this JSON")
    args = ap.parse_args()

    steps_path = args.steps.resolve()
    if not steps_path.is_file():
        print(f"Error: not a file: {steps_path}", file=sys.stderr)
        sys.exit(1)

    retone = None if args.keep_authored_tones else load_retone()

    with open(steps_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    changed, skipped = retone_steps(data, retone)

    print(f"Updated {len(changed)} items with normalized phonetic.")
    if retone:
        print(f"Tones kept as authored (Thai/phonetic syllables don't align): {len(skipped)}")
    if args.report:
        args.report.write_text(
            json.dumps({"changed": changed, "skipped": skipped}, ensure_ascii=False, indent=1),
            encoding="utf-8",
        )
        print(f"Report: {args.report}")
    if args.dry_run:
        print("(dry-run: file not written)")
        return
    if args.backup:
        from datetime import datetime

        stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        backup_path = steps_path.with_name(f"{steps_path.name}.bak-{stamp}")
        backup_path.write_text(steps_path.read_text(encoding="utf-8"), encoding="utf-8")
        print(f"Backup: {backup_path}")
    with open(steps_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"Written: {steps_path}")


if __name__ == "__main__":
    main()
