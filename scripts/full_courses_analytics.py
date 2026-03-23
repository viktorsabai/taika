#!/usr/bin/env python3
"""
Аналитика по ВСЕМ курсам приложения и распространение контента по «тонким» урокам.

1. Отчёт (--report): по каждому курсу — уроки, число карточек (word+phrase+casual),
   помечаются уроки с < 8 карточек (тонкие). Итог по приложению.

2. Заполнение (--fill-thin): для каждого stepset с числом обучаемых карточек < 8
   добавляются карточки из пула (существующие в steps), пока в уроке не станет >= 8.
   Карточка из пула берётся только если её ещё нет в этом уроке и она встречается
   менее чем в 2 stepsets (правило: не дублировать одну и ту же карточку в > 2 уроках).

Пуло: все уникальные (ru, thai, phonetic, kind, tip) из steps.json. Таким образом
контент «перетекает» из плотных уроков в тонкие по всем 41 курсу.

Запуск из корня репо:
  python3 scripts/full_courses_analytics.py --steps steps.json --report
  python3 scripts/full_courses_analytics.py --steps steps.json --fill-thin [--backup] [--min-cards 8]
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

BASE = Path(__file__).resolve().parent.parent
DEFAULT_STEPS = BASE / "steps.json"
MAX_STEPSETS_PER_CARD = 2  # одна карточка не чаще чем в 2 уроках


def normalize_ru(s: str) -> str:
    return (s or "").strip().lower()


def load_data(steps_path: Path) -> dict:
    with open(steps_path, "r", encoding="utf-8") as f:
        return json.load(f)


def learnable_count(items: list[dict]) -> int:
    return sum(1 for it in items if (it.get("kind") or "").strip().lower() in ("word", "phrase", "casual"))


def build_pool_and_usage(data: dict) -> tuple[dict, dict]:
    """
    Пуло: (norm_ru, thai) -> { kind, ru, thai, phonetic, tip? }.
    Использование: (norm_ru, thai) -> set(stepset_id).
    """
    pool = {}
    usage = {}
    for stepset in data.get("stepsets", []):
        sid = stepset.get("id") or ""
        for it in stepset.get("items", []):
            k = (it.get("kind") or "").strip().lower()
            if k not in ("word", "phrase", "casual"):
                continue
            ru = (it.get("ru") or "").strip()
            thai = (it.get("thai") or "").strip()
            if not ru:
                continue
            key = (normalize_ru(ru), thai)
            if key not in pool:
                pool[key] = {
                    "kind": k,
                    "ru": ru,
                    "thai": thai,
                    "phonetic": (it.get("phonetic") or "").strip(),
                    "tip": (it.get("tip") or "").strip() or None,
                }
                if pool[key]["tip"] is None:
                    del pool[key]["tip"]
            usage.setdefault(key, set()).add(sid)
    return pool, usage


def run_report(data: dict, min_cards: int = 8) -> None:
    print("=== Аналитика по всем курсам приложения ===\n")
    by_course = {}
    thin_list = []
    for stepset in data.get("stepsets", []):
        cid = stepset.get("course_id", "")
        lid = stepset.get("lesson_id", "")
        sid = stepset.get("id", "")
        items = stepset.get("items", [])
        n = learnable_count(items)
        by_course.setdefault(cid, []).append((lid, sid, n))
        if n < min_cards:
            thin_list.append((cid, lid, sid, n))

    courses = sorted(by_course.keys())
    print(f"Всего курсов: {len(courses)}")
    print(f"Уроков с числом карточек < {min_cards}: {len(thin_list)}\n")

    total_learnable = 0
    for cid in courses:
        rows = by_course[cid]
        total_in_course = sum(r[2] for r in rows)
        total_learnable += total_in_course
        thin_in_course = sum(1 for r in rows if r[2] < min_cards)
        print(f"{cid}: уроков {len(rows)}, карточек {total_in_course}, тонких (<{min_cards}) {thin_in_course}")
        for lid, sid, n in sorted(rows, key=lambda x: (x[0], x[2])):
            mark = "  ← тонкий" if n < min_cards else ""
            print(f"    {lid}  {n} карточек{mark}")

    print(f"\nИтого обучаемых карточек по приложению: {total_learnable}")
    print(f"Тонких уроков (будут заполняться при --fill-thin): {len(thin_list)}")
    if thin_list:
        print("\nСписок тонких уроков (course_id, lesson_id, текущее кол-во):")
        for cid, lid, sid, n in thin_list[:50]:
            print(f"  {cid}  {lid}  {n}")
        if len(thin_list) > 50:
            print(f"  ... и ещё {len(thin_list) - 50}")


def fill_thin_stepsets(data: dict, min_cards: int, backup_path: Path | None) -> int:
    """
    Для каждого stepset с learnable < min_cards добавляем карточки из пула,
    пока не станет >= min_cards. Карточка используется не более чем в MAX_STEPSETS_PER_CARD stepsets.
    Возвращает число добавленных карточек.
    """
    pool, usage = build_pool_and_usage(data)
    # stepset_id -> stepset ref
    stepset_by_id = {s.get("id"): s for s in data.get("stepsets", []) if s.get("id")}
    # stepset_id -> set(norm_ru) уже в этом уроке
    existing_ru_by_sid = {}
    for stepset in data.get("stepsets", []):
        sid = stepset.get("id")
        if not sid:
            continue
        existing_ru_by_sid[sid] = set()
        for it in stepset.get("items", []):
            if (it.get("kind") or "").strip().lower() in ("word", "phrase", "casual"):
                ru = (it.get("ru") or "").strip()
                if ru:
                    existing_ru_by_sid[sid].add(normalize_ru(ru))

    thin = [
        (s.get("id"), s, learnable_count(s.get("items", [])))
        for s in data.get("stepsets", [])
        if learnable_count(s.get("items", [])) < min_cards
    ]
    added_total = 0
    # Сортируем тонкие по course_id, lesson_id — предсказуемый порядок
    thin.sort(key=lambda x: (x[1].get("course_id", ""), x[1].get("lesson_id", "")))

    for sid, stepset, current in thin:
        need = min_cards - current
        if need <= 0:
            continue
        existing_ru = existing_ru_by_sid.get(sid, set())
        items_arr = stepset.get("items") or []
        max_order = max((it.get("order") or 0) for it in items_arr) if items_arr else 0

        # Кандидаты: из пула, нет в этом уроке (по ru), карточка в < MAX_STEPSETS_PER_CARD stepsets
        candidates = [
            key for key, stepset_ids in usage.items()
            if key[0] not in existing_ru and len(stepset_ids) < MAX_STEPSETS_PER_CARD
        ]
        added = 0
        for key in candidates:
            if added >= need:
                break
            if key[0] in existing_ru:
                continue
            if len(usage[key]) >= MAX_STEPSETS_PER_CARD:
                continue
            rec = pool[key]
            max_order += 1
            new_item = {
                "order": max_order,
                "kind": rec.get("kind", "word"),
                "ru": rec["ru"],
                "thai": rec["thai"],
                "phonetic": rec.get("phonetic", ""),
            }
            if rec.get("tip"):
                new_item["tip"] = rec["tip"]
            items_arr.append(new_item)
            existing_ru.add(key[0])
            usage[key].add(sid)
            added += 1
            added_total += 1
        stepset["items"] = items_arr

    return added_total


def main() -> int:
    ap = argparse.ArgumentParser(description="Full courses analytics and fill thin lessons")
    ap.add_argument("--steps", type=Path, default=DEFAULT_STEPS, help="Path to steps.json")
    ap.add_argument("--report", action="store_true", help="Print full report for all courses")
    ap.add_argument("--fill-thin", action="store_true", help="Add cards to thin stepsets (from pool)")
    ap.add_argument("--backup", action="store_true", help="Backup steps.json before writing")
    ap.add_argument("--min-cards", type=int, default=8, help="Target minimum learnable cards per lesson (default 8)")
    args = ap.parse_args()

    steps_path = args.steps.resolve()
    if not steps_path.is_file():
        print(f"Error: not a file: {steps_path}", file=sys.stderr)
        return 1

    data = load_data(steps_path)

    if args.report:
        run_report(data, args.min_cards)
        return 0

    if args.fill_thin:
        if args.backup:
            backup_path = steps_path.with_suffix(steps_path.suffix + ".bak")
            backup_path.write_text(steps_path.read_text(encoding="utf-8"), encoding="utf-8")
            print(f"Backup: {backup_path}")
        added = fill_thin_stepsets(data, args.min_cards, steps_path.with_suffix(steps_path.suffix + ".bak") if args.backup else None)
        print(f"Добавлено карточек в тонкие уроки: {added}")
        with open(steps_path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        print(f"Written: {steps_path}")
        return 0

    run_report(data, args.min_cards)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
