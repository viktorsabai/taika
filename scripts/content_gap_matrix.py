#!/usr/bin/env python3
"""
Матрица «дыр» по контенту steps.json для аналитика.
- По курсам/урокам: количество word, phrase, casual, tip.
- Уникальные ru (нормализованные) — для сверки с частотным списком (Oxford/Longman).

Запуск из корня репо:
  python3 scripts/content_gap_matrix.py
  python3 scripts/content_gap_matrix.py --csv docs/content_matrix.csv
  python3 scripts/content_gap_matrix.py --unique-ru docs/unique_ru_list.txt
"""
import argparse
import csv
import json
import os
import sys

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STEPS_PATH = os.path.join(BASE, "steps.json")


def normalize_ru(s: str) -> str:
    return (s or "").strip().lower()


def main() -> int:
    ap = argparse.ArgumentParser(description="Export gap matrix and unique ru list from steps.json")
    ap.add_argument("--csv", dest="csv_path", default=None, help="Write matrix to CSV")
    ap.add_argument("--unique-ru", dest="unique_ru_path", default=None, help="Write unique ru (one per line)")
    ap.add_argument("--steps", dest="steps_path", default=None, help="Path to steps.json (default: repo steps.json)")
    args = ap.parse_args()

    steps_path = args.steps_path or STEPS_PATH
    if not os.path.isfile(steps_path):
        print(f"File not found: {steps_path}", file=sys.stderr)
        return 1

    with open(steps_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    rows = []
    all_ru = set()

    for s in data.get("stepsets", []):
        cid = s.get("course_id", "")
        lid = s.get("lesson_id", "")
        word = phrase = casual = tip = 0
        for it in s.get("items", []):
            k = (it.get("kind") or "").strip().lower()
            if k == "word":
                word += 1
            elif k == "phrase":
                phrase += 1
            elif k == "casual":
                casual += 1
            elif k == "tip":
                tip += 1
            if k in ("word", "phrase", "casual"):
                ru = (it.get("ru") or "").strip()
                if ru:
                    all_ru.add(normalize_ru(ru))
        rows.append({
            "course_id": cid,
            "lesson_id": lid,
            "word": word,
            "phrase": phrase,
            "casual": casual,
            "tip": tip,
            "total_learnable": word + phrase + casual,
        })

    # Sort by course_id, lesson_id
    rows.sort(key=lambda r: (r["course_id"], r["lesson_id"]))

    if args.csv_path:
        os.makedirs(os.path.dirname(args.csv_path) or ".", exist_ok=True)
        with open(args.csv_path, "w", encoding="utf-8", newline="") as f:
            w = csv.DictWriter(f, fieldnames=["course_id", "lesson_id", "word", "phrase", "casual", "tip", "total_learnable"])
            w.writeheader()
            w.writerows(rows)
        print(f"Matrix written: {args.csv_path}")

    if args.unique_ru_path:
        os.makedirs(os.path.dirname(args.unique_ru_path) or ".", exist_ok=True)
        with open(args.unique_ru_path, "w", encoding="utf-8") as f:
            for ru in sorted(all_ru):
                f.write(ru + "\n")
        print(f"Unique ru ({len(all_ru)} items) written: {args.unique_ru_path}")

    if not args.csv_path and not args.unique_ru_path:
        # Console summary
        print("Course / Lesson                    | word phrase casual tip | total")
        print("-" * 70)
        for r in rows:
            print(f"{r['course_id']} {r['lesson_id']:<24} | {r['word']:4} {r['phrase']:6} {r['casual']:6} {r['tip']:3} | {r['total_learnable']}")
        print()
        print(f"Unique ru (normalized): {len(all_ru)}. Use --unique-ru to export.")
        print("CSV matrix: use --csv path to export.")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
