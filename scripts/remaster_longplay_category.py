#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_STEPS = ROOT / "steps.json"


def norm(v: str | None) -> str:
    if not v:
        return ""
    return re.sub(r"\s+", " ", v.strip().lower())


def is_learnable(it: dict) -> bool:
    return (it.get("kind") or "").strip().lower() in {"word", "phrase", "casual"}


def is_placeholder_tip(it: dict) -> bool:
    if (it.get("kind") or "").strip().lower() != "tip":
        return False
    t = (it.get("text") or "").strip().lower()
    return (
        t.startswith("контекст из базы:")
        or "долгожитель: поверх база/жизнь/волна/душа" in t
        or "линейка с иммигрейшеном в чате" in t
    )


def reindex(items: list[dict]) -> list[dict]:
    out = []
    for i, it in enumerate(items, 1):
        c = dict(it)
        c["order"] = i
        out.append(c)
    return out


def remaster(stepsets: list[dict], min_learnable: int = 8) -> tuple[int, int, int]:
    by_course = defaultdict(list)
    for ss in stepsets:
        if (ss.get("course_id") or "").startswith("course_long_"):
            by_course[ss.get("course_id")].append(ss)

    lessons_touched = tips_replaced = learnables_added = 0
    for _, lessons in by_course.items():
        pool = []
        usage = defaultdict(int)
        for ss in lessons:
            for it in ss.get("items", []):
                if not is_learnable(it):
                    continue
                key = (norm(it.get("ru")), norm(it.get("thai")))
                if key[0] and key[1]:
                    pool.append(it)
                    usage[key] += 1

        lessons_sorted = sorted(lessons, key=lambda s: (sum(1 for it in s.get("items", []) if is_learnable(it)), s.get("lesson_id", "")))
        for ss in lessons_sorted:
            items = []
            changed = False
            for it in ss.get("items", []):
                if is_placeholder_tip(it):
                    tips_replaced += 1
                    changed = True
                    continue
                items.append(it)

            have = {(norm(it.get("ru")), norm(it.get("thai"))) for it in items if is_learnable(it) and norm(it.get("ru")) and norm(it.get("thai"))}
            cur = sum(1 for it in items if is_learnable(it))
            need = max(0, min_learnable - cur)
            if need > 0:
                cand = []
                for src in pool:
                    key = (norm(src.get("ru")), norm(src.get("thai")))
                    if not key[0] or not key[1] or key in have:
                        continue
                    cand.append((usage[key], key, src))
                cand.sort(key=lambda x: (x[0], x[1][0], x[1][1]))
                added = 0
                for _, key, src in cand:
                    if added >= need:
                        break
                    items.append(
                        {
                            "order": 0,
                            "kind": (src.get("kind") or "phrase"),
                            "ru": src.get("ru", ""),
                            "thai": src.get("thai", ""),
                            "phonetic": src.get("phonetic", ""),
                        }
                    )
                    have.add(key)
                    usage[key] += 1
                    added += 1
                    learnables_added += 1
                    changed = True
            if changed:
                lessons_touched += 1
            ss["items"] = reindex(items)

    return lessons_touched, tips_replaced, learnables_added


def demote_orphans(stepsets: list[dict]) -> int:
    dem = 0
    for ss in stepsets:
        if not (ss.get("course_id") or "").startswith("course_long_"):
            continue
        items = ss.get("items", [])
        incoming = defaultdict(int)
        for it in items:
            rt = it.get("reply_to")
            if isinstance(rt, int):
                incoming[rt] += 1
        for it in items:
            if it.get("is_question") is True and incoming.get(it.get("order"), 0) == 0:
                it.pop("is_question", None)
                dem += 1
    return dem


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--steps", type=Path, default=DEFAULT_STEPS)
    ap.add_argument("--min-learnable", type=int, default=8)
    args = ap.parse_args()
    data = json.loads(args.steps.read_text(encoding="utf-8"))
    stepsets = data.get("stepsets", [])
    lt, tr, la = remaster(stepsets, args.min_learnable)
    dem = demote_orphans(stepsets)
    data["stepsets"] = stepsets
    args.steps.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"[remaster_longplay] lessons_touched={lt} tips_replaced={tr} learnables_added={la} orphan_prompts_demoted={dem}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
