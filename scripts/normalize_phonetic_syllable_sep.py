#!/usr/bin/env python3
"""
Замена дефисов между слогами на пробелы в phonetic, когда у каждого слога уже есть стрелка тона.
Спека: при наличии стрелок (→↓↘↑↗) разделитель слогов может быть пробел — парсеры (Speaker, steps_to_contours)
разбивают по [\\s\\-·]+, так что «са→ бай→ ди↘» обрабатывается корректно.

Использование:
  python3 scripts/normalize_phonetic_syllable_sep.py --steps steps.json [--dry-run] [--backup]
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ARROWS = "→↓↘↑↗"


def hyphen_after_arrow_to_space(phonetic: str) -> str:
    """После каждой стрелки тона заменяем следующий дефис на пробел: са→-бай→ → са→ бай→."""
    if not phonetic or not phonetic.strip():
        return phonetic
    s = phonetic.strip()
    for arr in ARROWS:
        s = s.replace(arr + "-", arr + " ")
    # Убираем двойные пробелы
    s = re.sub(r" +", " ", s)
    return s.strip()


def main() -> None:
    ap = argparse.ArgumentParser(description="Replace hyphen after tone arrow with space in phonetic.")
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
            if phonetic is None or "-" not in phonetic:
                continue
            new_phonetic = hyphen_after_arrow_to_space(phonetic)
            if new_phonetic != phonetic:
                item["phonetic"] = new_phonetic
                updated += 1

    print(f"Updated {updated} items: hyphen after tone arrow → space.")
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
