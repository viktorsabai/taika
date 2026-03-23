#!/usr/bin/env python3
"""
Нормализация phonetic в steps.json:
1. У каждого слога в phonetic должен быть ровно один из 5 тонов: → (Mid), ↓ (Low), ↘ (Falling), ↑ (High), ↗ (Rising).
2. Слоги без стрелки получают по умолчанию → (Mid).
3. Замена en-dash (U+2011) на ASCII hyphen для корректного разбора по слогам.

Использование:
  python fix_phonetic_tones.py --steps ../steps.json [--dry-run] [--backup]
  --dry-run   только отчёт, не менять файл
  --backup    перед записью скопировать steps.json в steps.json.bak
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


def main() -> None:
    ap = argparse.ArgumentParser(description="Normalize phonetic tones in steps.json")
    ap.add_argument("--steps", type=Path, default=Path("steps.json"), help="Path to steps.json")
    ap.add_argument("--dry-run", action="store_true", help="Report only, do not write")
    ap.add_argument("--backup", action="store_true", help="Backup steps.json before writing")
    args = ap.parse_args()

    steps_path = args.steps.resolve()
    if not steps_path.is_file():
        print(f"Error: not a file: {steps_path}", file=sys.stderr)
        sys.exit(1)

    with open(steps_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    updated = 0
    for stepset in data.get("stepsets", []):
        for item in stepset.get("items", []):
            if item.get("kind") not in ("word", "phrase", "casual"):
                continue
            phonetic = item.get("phonetic")
            if phonetic is None:
                continue
            new_phonetic = normalize_phonetic(phonetic)
            if new_phonetic != phonetic:
                item["phonetic"] = new_phonetic
                updated += 1

    print(f"Updated {updated} items with normalized phonetic.")
    if args.dry_run:
        print("(dry-run: file not written)")
        return
    if args.backup:
        backup_path = steps_path.with_suffix(steps_path.suffix + ".bak")
        backup_path.write_text(steps_path.read_text(encoding="utf-8"), encoding="utf-8")
        print(f"Backup: {backup_path}")
    with open(steps_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print(f"Written: {steps_path}")


if __name__ == "__main__":
    main()
