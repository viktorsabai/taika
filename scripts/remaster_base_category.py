#!/usr/bin/env python3
"""
Base category remaster (course_b_*):
1) Ensure each lesson has at least N learnable cards.
2) Reduce orphan dialogue prompts (is_question without incoming reply_to).

This script only modifies `steps.json`.
"""
from __future__ import annotations

import argparse
import json
import re
from collections import defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_STEPS = ROOT / "steps.json"


def norm(value: str | None) -> str:
    if not value:
        return ""
    return re.sub(r"\s+", " ", value.strip().lower())


def is_learnable(item: dict) -> bool:
    return (item.get("kind") or "").strip().lower() in {"word", "phrase", "casual"}


def learnable_count(items: list[dict]) -> int:
    return sum(1 for it in items if is_learnable(it))


def existing_ru_set(items: list[dict]) -> set[str]:
    out = set()
    for it in items:
        if is_learnable(it):
            ru = norm(it.get("ru"))
            if ru:
                out.add(ru)
    return out


def existing_thai_set(items: list[dict]) -> set[str]:
    out = set()
    for it in items:
        if is_learnable(it):
            th = norm(it.get("thai"))
            if th:
                out.add(th)
    return out


def reindex(items: list[dict]) -> list[dict]:
    out = []
    for i, it in enumerate(items, start=1):
        cloned = dict(it)
        cloned["order"] = i
        out.append(cloned)
    return out


def fill_base_thin_lessons(stepsets: list[dict], min_cards: int = 8) -> int:
    by_course: dict[str, list[dict]] = defaultdict(list)
    for ss in stepsets:
        cid = ss.get("course_id", "")
        if cid.startswith("course_b_"):
            by_course[cid].append(ss)

    added_total = 0
    for cid, lessons in by_course.items():
        # Build a course-local pool from existing learnables.
        pool = []
        usage = defaultdict(int)  # thai token -> occurrences across lessons in this course
        for ss in lessons:
            for it in ss.get("items", []):
                if not is_learnable(it):
                    continue
                th = norm(it.get("thai"))
                if th:
                    usage[th] += 1
                pool.append(it)

        # Deterministic: process thinnest lessons first.
        lessons_sorted = sorted(lessons, key=lambda s: (learnable_count(s.get("items", [])), s.get("lesson_id", "")))
        for ss in lessons_sorted:
            items = list(ss.get("items", []))
            current = learnable_count(items)
            need = max(0, min_cards - current)
            if need == 0:
                ss["items"] = reindex(items)
                continue

            have_ru = existing_ru_set(items)
            have_th = existing_thai_set(items)
            max_order = max([it.get("order", 0) for it in items] + [0])

            # Candidate strategy:
            # - same course only
            # - avoid duplicate ru/thai inside lesson
            # - prefer lower usage thai in this course
            candidates = []
            for src in pool:
                ru = norm(src.get("ru"))
                th = norm(src.get("thai"))
                if not ru or not th:
                    continue
                if ru in have_ru or th in have_th:
                    continue
                candidates.append((usage.get(th, 0), ru, th, src))
            candidates.sort(key=lambda x: (x[0], x[1], x[2]))

            added = 0
            for _, ru, th, src in candidates:
                if added >= need:
                    break
                max_order += 1
                new_item = {
                    "order": max_order,
                    "kind": (src.get("kind") or "phrase"),
                    "ru": src.get("ru", ""),
                    "thai": src.get("thai", ""),
                    "phonetic": src.get("phonetic", ""),
                }
                if src.get("tip"):
                    new_item["tip"] = src.get("tip")
                items.append(new_item)
                have_ru.add(ru)
                have_th.add(th)
                usage[th] += 1
                added += 1
                added_total += 1

            ss["items"] = reindex(items)
    return added_total


def reduce_base_orphan_prompts(stepsets: list[dict]) -> int:
    demoted = 0
    for ss in stepsets:
        cid = ss.get("course_id", "")
        if not cid.startswith("course_b_"):
            continue
        items = ss.get("items", [])
        incoming = defaultdict(int)
        for it in items:
            rt = it.get("reply_to")
            if isinstance(rt, int):
                incoming[rt] += 1

        for it in items:
            if it.get("is_question") is not True:
                continue
            order = it.get("order")
            if isinstance(order, int) and incoming.get(order, 0) == 0:
                it.pop("is_question", None)
                demoted += 1
    return demoted


def main() -> int:
    ap = argparse.ArgumentParser(description="Remaster base category lessons in steps.json")
    ap.add_argument("--steps", type=Path, default=DEFAULT_STEPS)
    ap.add_argument("--min-cards", type=int, default=8)
    args = ap.parse_args()

    data = json.loads(args.steps.read_text(encoding="utf-8"))
    stepsets = data.get("stepsets", [])

    added = fill_base_thin_lessons(stepsets, min_cards=args.min_cards)
    demoted = reduce_base_orphan_prompts(stepsets)

    data["stepsets"] = stepsets
    args.steps.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"[remaster_base] min_cards={args.min_cards} learnables_added={added} orphan_prompts_demoted={demoted}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
