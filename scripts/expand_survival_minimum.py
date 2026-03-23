#!/usr/bin/env python3
"""
Аналитика по функциональному минимуму (survival minimum) и добавление недостающих
слов/фраз в steps.json. Использует survival_minimum_data.SURVIVAL_ITEMS и добавляет
только те, которых ещё нет в steps (по полю ru, нормализованному).

Режимы:
  --report     только отчёт: что есть, чего не хватает, по каким урокам.
  --expand     добавить недостающие карточки в course_b_1 (и обновить steps.json).

Запуск из корня репо:
  python3 scripts/expand_survival_minimum.py --steps steps.json --report
  python3 scripts/expand_survival_minimum.py --steps steps.json --expand [--backup]
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

# Данные функционального минимума
sys.path.insert(0, str(Path(__file__).resolve().parent))
from survival_minimum_data import SURVIVAL_ITEMS

BASE = Path(__file__).resolve().parent.parent
DEFAULT_STEPS = BASE / "steps.json"


def normalize_ru(s: str) -> str:
    return (s or "").strip().lower()


def collect_existing_ru(steps_path: Path) -> set[str]:
    """Собрать множество нормализованных ru из steps.json."""
    with open(steps_path, "r", encoding="utf-8") as f:
        data = json.load(f)
    out = set()
    for stepset in data.get("stepsets", []):
        for item in stepset.get("items", []):
            if item.get("kind") in ("word", "phrase", "casual"):
                ru = item.get("ru") or ""
                if ru.strip():
                    out.add(normalize_ru(ru))
    return out


def run_report(steps_path: Path) -> None:
    """Вывести отчёт: покрытие survival minimum по текущему steps.json."""
    existing = collect_existing_ru(steps_path)
    missing = []
    covered = []
    for it in SURVIVAL_ITEMS:
        ru = (it.get("ru") or "").strip()
        if not ru:
            continue
        if normalize_ru(ru) in existing:
            covered.append((ru, it.get("target_lesson", "")))
        else:
            missing.append((ru, it.get("target_lesson", ""), it.get("thai", "")))

    print("=== Survival minimum: отчёт по покрытию ===\n")
    print(f"Всего в чек-листе: {len(SURVIVAL_ITEMS)}")
    print(f"Уже есть в steps:  {len(covered)}")
    print(f"Не хватает:        {len(missing)}\n")

    if covered:
        print("--- Уже есть в steps ---")
        for ru, lesson in sorted(covered, key=lambda x: (x[1], x[0])):
            print(f"  {lesson}: {ru}")
    if missing:
        print("\n--- Не хватает (будут добавлены при --expand) ---")
        for ru, lesson, thai in sorted(missing, key=lambda x: (x[1], x[0])):
            print(f"  {lesson}: {ru}  ({thai})")
    print()


def find_stepset_by_lesson(data: dict, lesson_id: str) -> dict | None:
    for stepset in data.get("stepsets", []):
        if stepset.get("lesson_id") == lesson_id:
            return stepset
    return None


def expand_steps(steps_path: Path, backup: bool) -> None:
    """Добавить в steps.json недостающие пункты из SURVIVAL_ITEMS."""
    with open(steps_path, "r", encoding="utf-8") as f:
        data = json.load(f)
    existing = collect_existing_ru(steps_path)

    to_add_by_lesson: dict[str, list[dict]] = {}
    for it in SURVIVAL_ITEMS:
        ru = (it.get("ru") or "").strip()
        if not ru or normalize_ru(ru) in existing:
            continue
        lesson = it.get("target_lesson") or "course_b_1_l3"
        to_add_by_lesson.setdefault(lesson, []).append(it)

    if not to_add_by_lesson:
        print("Нечего добавлять: все пункты survival minimum уже есть в steps.")
        return

    added_total = 0
    for lesson_id, items in sorted(to_add_by_lesson.items()):
        stepset = find_stepset_by_lesson(data, lesson_id)
        if not stepset:
            print(f"Warning: stepset for {lesson_id} not found, skip {len(items)} items.", file=sys.stderr)
            continue
        items_arr = stepset.get("items") or []
        max_order = max((it.get("order") or 0) for it in items_arr) if items_arr else 0
        for i, it in enumerate(items_arr):
            if (it.get("order") or 0) > max_order:
                max_order = it.get("order")
        for idx, raw in enumerate(items):
            order = max_order + 1 + idx
            kind = (raw.get("kind") or "word").strip().lower()
            if kind not in ("word", "phrase", "casual"):
                kind = "word"
            new_item = {
                "order": order,
                "kind": kind,
                "ru": raw.get("ru", "").strip(),
                "thai": (raw.get("thai") or "").strip(),
                "phonetic": (raw.get("phonetic") or "").strip(),
            }
            if raw.get("tip"):
                new_item["tip"] = raw["tip"].strip()
            items_arr.append(new_item)
            added_total += 1
        stepset["items"] = items_arr

    print(f"Добавлено карточек: {added_total}")

    if backup:
        backup_path = steps_path.with_suffix(steps_path.suffix + ".bak")
        backup_path.write_text(steps_path.read_text(encoding="utf-8"), encoding="utf-8")
        print(f"Backup: {backup_path}")

    with open(steps_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print(f"Written: {steps_path}")


def main() -> int:
    ap = argparse.ArgumentParser(description="Survival minimum: report and expand steps.json")
    ap.add_argument("--steps", type=Path, default=DEFAULT_STEPS, help="Path to steps.json")
    ap.add_argument("--report", action="store_true", help="Only print coverage report")
    ap.add_argument("--expand", action="store_true", help="Add missing items to steps.json")
    ap.add_argument("--backup", action="store_true", help="Backup steps.json before writing (with --expand)")
    args = ap.parse_args()

    steps_path = args.steps.resolve()
    if not steps_path.is_file():
        print(f"Error: not a file: {steps_path}", file=sys.stderr)
        return 1

    if args.report:
        run_report(steps_path)
        return 0
    if args.expand:
        expand_steps(steps_path, args.backup)
        return 0

    # По умолчанию — отчёт
    run_report(steps_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
