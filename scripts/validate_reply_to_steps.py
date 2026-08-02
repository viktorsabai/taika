#!/usr/bin/env python3
"""
Проверка полей reply_to / is_question в steps.json для Grand Dialogue.

Правила (уровень урока):
- Если у карточки задан reply_to, в том же stepset должна быть карточка с order == reply_to.
- is_question допускается без reply_to (метка сценария); предупреждение, если есть reply_to без пары.

Запуск из корня репозитория:
  python3 scripts/validate_reply_to_steps.py
  python3 scripts/validate_reply_to_steps.py path/to/steps.json
"""
from __future__ import annotations

import json
import sys
from pathlib import Path
import argparse


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    ap = argparse.ArgumentParser(description="Validate reply_to/is_question graph integrity.")
    ap.add_argument("path", nargs="?", default=str(root / "steps.json"))
    ap.add_argument("--require-links-per-lesson", action="store_true", help="Fail if a lesson has no reply_to links.")
    ap.add_argument("--require-prompts-per-lesson", action="store_true", help="Fail if a lesson has no is_question.")
    ap.add_argument("--require-links-per-course", action="store_true", help="Fail if a course has no reply_to links.")
    ap.add_argument(
        "--exclude-course-prefix",
        action="append",
        default=[],
        help="Exclude courses with this prefix from validation requirements (repeatable).",
    )
    args = ap.parse_args()

    path = Path(args.path)
    if not path.is_file():
        print(f"[validate_reply_to] file not found: {path}")
        return 2

    data = json.loads(path.read_text(encoding="utf-8"))
    stepsets = data.get("stepsets") or []
    errors = 0
    warnings = 0

    course_link_counts: dict[str, int] = {}
    excluded_prefixes = tuple(args.exclude_course_prefix or [])

    for ss in stepsets:
        lid = ss.get("lesson_id", "?")
        cid = ss.get("course_id", "?")
        if excluded_prefixes and any(str(cid).startswith(p) for p in excluded_prefixes):
            continue
        items = ss.get("items") or []
        orders = {it.get("order") for it in items if isinstance(it.get("order"), int)}
        lesson_links = 0
        lesson_prompts = 0

        for it in items:
            if not isinstance(it, dict):
                continue
            ro = it.get("reply_to")
            if ro is None:
                continue
            if not isinstance(ro, int):
                print(f"[E] {lid} order={it.get('order')}: reply_to must be int, got {ro!r}")
                errors += 1
                continue
            if ro not in orders:
                print(f"[E] {lid} order={it.get('order')}: reply_to={ro} — нет карточки с таким order в уроке")
                errors += 1
            else:
                lesson_links += 1

        # dangling prompts: is_question true but no incoming reply_to
        for it in items:
            if not isinstance(it, dict):
                continue
            if not it.get("is_question"):
                continue
            lesson_prompts += 1
            o = it.get("order")
            if not isinstance(o, int):
                continue
            has_answer = any(
                isinstance(x, dict) and x.get("reply_to") == o for x in items
            )
            if not has_answer:
                print(f"[W] {lid} order={o}: is_question без карточки с reply_to={o}")
                warnings += 1

        if args.require_links_per_lesson and lesson_links == 0:
            print(f"[E] {lid}: no reply_to links in lesson")
            errors += 1
        if args.require_prompts_per_lesson and lesson_prompts == 0:
            print(f"[E] {lid}: no is_question prompts in lesson")
            errors += 1

        course_link_counts[cid] = course_link_counts.get(cid, 0) + lesson_links

    if args.require_links_per_course:
        for cid, count in sorted(course_link_counts.items()):
            if count == 0:
                print(f"[E] {cid}: no reply_to links in course")
                errors += 1

    print(f"[validate_reply_to] stepsets={len(stepsets)} errors={errors} warnings={warnings}")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
