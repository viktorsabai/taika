#!/usr/bin/env python3
"""
Build product-facing content report:
1) Audit by category/course (learnable, tips, thin lessons, high-tip lessons)
2) Lesson-count consistency checks (course meta vs lessons vs steps)
3) Dialogue warning aggregation (is_question without incoming reply_to)
4) Oxford + Taika matrix (readiness and gaps, heuristic)
"""
from __future__ import annotations

import argparse
import json
import re
from collections import defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
STEPS = ROOT / "steps.json"
LESSONS = ROOT / "lessons.json"
COURSES = ROOT / "taika" / "Resourses" / "taika_basa_course.json"
OXFORD = ROOT / "scripts" / "data" / "oxford_3000_master.json"
OUT_MD = ROOT / "scripts" / "data" / "product_content_report.md"
OUT_JSON = ROOT / "scripts" / "data" / "product_content_report.json"


def cat_of(course_id: str) -> str:
    if course_id.startswith("course_b_"):
        return "base"
    if course_id.startswith("course_l_"):
        return "life"
    if course_id.startswith("course_e_"):
        return "etiquette"
    if course_id.startswith("course_s_"):
        return "soul"
    if course_id.startswith("course_long_"):
        return "longplay"
    return "other"


def norm(value: str | None) -> str:
    if not value:
        return ""
    return re.sub(r"\s+", " ", value.strip().lower())


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def compute_dialogue_warnings(steps_data: dict) -> dict[str, int]:
    by_course = defaultdict(int)
    for ss in steps_data.get("stepsets", []):
        cid = ss.get("course_id", "")
        items = ss.get("items", [])
        incoming = defaultdict(int)
        for it in items:
            rt = it.get("reply_to")
            if isinstance(rt, int):
                incoming[rt] += 1
        for it in items:
            if it.get("is_question") is True:
                order = it.get("order")
                if isinstance(order, int) and incoming.get(order, 0) == 0:
                    by_course[cid] += 1
    return dict(by_course)


def build_report():
    steps = load_json(STEPS)
    lessons = load_json(LESSONS)
    courses = load_json(COURSES)
    oxford = load_json(OXFORD)

    lesson_counts_lessons = {c.get("course_id", ""): len(c.get("lessons", [])) for c in lessons.get("courses", [])}
    lesson_counts_steps = defaultdict(int)
    per_course_stats = defaultdict(lambda: defaultdict(int))
    low_lessons = defaultdict(list)
    high_tip_lessons = defaultdict(list)

    for ss in steps.get("stepsets", []):
        cid = ss.get("course_id", "")
        lid = ss.get("lesson_id", "")
        lesson_counts_steps[cid] += 1
        learnable = 0
        tips = 0
        for it in ss.get("items", []):
            k = (it.get("kind") or "").strip().lower()
            if k in {"word", "phrase", "casual"}:
                learnable += 1
                per_course_stats[cid]["learnable"] += 1
            elif k == "tip":
                tips += 1
                per_course_stats[cid]["tip"] += 1
        per_course_stats[cid]["lessons"] += 1
        if learnable < 8:
            low_lessons[cid].append(lid)
        total = max(1, learnable + tips)
        if (tips / total) >= 0.35:
            high_tip_lessons[cid].append(lid)

    dialogue_warn = compute_dialogue_warnings(steps)

    # Cross-category base overlap should already be 0 by pipeline, but report it explicitly.
    base_th = set()
    by_category_th = defaultdict(set)
    for ss in steps.get("stepsets", []):
        cid = ss.get("course_id", "")
        cat = cat_of(cid)
        for it in ss.get("items", []):
            if (it.get("kind") or "").strip().lower() not in {"word", "phrase", "casual"}:
                continue
            th = norm(it.get("thai"))
            if not th:
                continue
            by_category_th[cat].add(th)
            if cat == "base":
                base_th.add(th)
    base_overlap = {}
    for cat, bag in by_category_th.items():
        if cat == "base":
            continue
        base_overlap[cat] = len(bag & base_th)

    # Oxford matrix (heuristic, product planning oriented)
    pos_counts = defaultdict(int)
    level_counts = defaultdict(int)
    for e in oxford.get("entries", []):
        for pos in e.get("parts_of_speech", []):
            pos_counts[pos] += 1
        for lvl in e.get("levels", []):
            level_counts[lvl] += 1

    course_meta = {c.get("id", ""): c for c in courses}
    course_rows = []
    for cid in sorted(per_course_stats.keys()):
        meta = course_meta.get(cid, {})
        declared = meta.get("lesson_count")
        lessons_from_lessons = lesson_counts_lessons.get(cid)
        lessons_from_steps = lesson_counts_steps.get(cid, 0)
        course_rows.append(
            {
                "course_id": cid,
                "category": cat_of(cid),
                "title": meta.get("title", ""),
                "declared_lessons": declared,
                "lessons_json": lessons_from_lessons,
                "steps_lessons": lessons_from_steps,
                "learnable": per_course_stats[cid]["learnable"],
                "tips": per_course_stats[cid]["tip"],
                "thin_lessons_under_8": len(low_lessons.get(cid, [])),
                "high_tip_lessons": len(high_tip_lessons.get(cid, [])),
                "dialogue_warnings": dialogue_warn.get(cid, 0),
            }
        )

    by_cat = defaultdict(lambda: defaultdict(int))
    for row in course_rows:
        c = row["category"]
        by_cat[c]["courses"] += 1
        by_cat[c]["lessons"] += row["steps_lessons"]
        by_cat[c]["learnable"] += row["learnable"]
        by_cat[c]["tips"] += row["tips"]
        by_cat[c]["thin_lessons_under_8"] += row["thin_lessons_under_8"]
        by_cat[c]["high_tip_lessons"] += row["high_tip_lessons"]
        by_cat[c]["dialogue_warnings"] += row["dialogue_warnings"]

    payload = {
        "summary": {
            "courses_total": len(course_rows),
            "stepsets_total": len(steps.get("stepsets", [])),
            "oxford_entry_count": oxford.get("entry_count", 0),
        },
        "oxford": {
            "levels": dict(sorted(level_counts.items())),
            "parts_of_speech": dict(sorted(pos_counts.items())),
        },
        "base_overlap_by_category": base_overlap,
        "categories": {k: dict(v) for k, v in sorted(by_cat.items())},
        "courses": course_rows,
    }
    return payload


def write_markdown(payload: dict, path: Path) -> None:
    lines = []
    s = payload["summary"]
    lines.append("# Product Content Report")
    lines.append("")
    lines.append(f"- Courses: {s['courses_total']}")
    lines.append(f"- Stepsets: {s['stepsets_total']}")
    lines.append(f"- Oxford entries: {s['oxford_entry_count']}")
    lines.append("")
    lines.append("## Category Snapshot")
    lines.append("")
    lines.append("| Category | Courses | Lessons | Learnable | Tips | Thin(<8) | High-tip | Dialogue warnings | Base overlap |")
    lines.append("|---|---:|---:|---:|---:|---:|---:|---:|---:|")
    for cat in ["base", "life", "etiquette", "longplay", "soul", "other"]:
        row = payload["categories"].get(cat, {})
        if not row:
            continue
        ov = payload["base_overlap_by_category"].get(cat, 0)
        lines.append(
            f"| {cat} | {row.get('courses',0)} | {row.get('lessons',0)} | {row.get('learnable',0)} | {row.get('tips',0)} | {row.get('thin_lessons_under_8',0)} | {row.get('high_tip_lessons',0)} | {row.get('dialogue_warnings',0)} | {ov} |"
        )
    lines.append("")
    lines.append("## Oxford + Taika Matrix (planning)")
    lines.append("")
    lines.append("- Oxford levels available: " + ", ".join(f"{k}={v}" for k, v in payload["oxford"]["levels"].items()))
    lines.append("- Oxford POS available: " + ", ".join(f"{k}={v}" for k, v in payload["oxford"]["parts_of_speech"].items()))
    lines.append("- Current Taika side is optimized for Thai scenario coverage and dedupe; exact lemma-to-lemma Oxford alignment needs explicit bilingual mapping layer.")
    lines.append("")
    lines.append("## Courses Needing Product Attention")
    lines.append("")
    lines.append("| Course | Category | Learnable | Tips | Thin(<8) | High-tip | Dialogue warnings |")
    lines.append("|---|---|---:|---:|---:|---:|---:|")
    rows = sorted(
        payload["courses"],
        key=lambda r: (r["thin_lessons_under_8"], r["high_tip_lessons"], r["dialogue_warnings"], r["tips"]),
        reverse=True,
    )
    for r in rows[:25]:
        if r["thin_lessons_under_8"] == 0 and r["high_tip_lessons"] == 0 and r["dialogue_warnings"] == 0:
            continue
        lines.append(
            f"| {r['course_id']} | {r['category']} | {r['learnable']} | {r['tips']} | {r['thin_lessons_under_8']} | {r['high_tip_lessons']} | {r['dialogue_warnings']} |"
        )

    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser(description="Build product-facing content report and matrix.")
    ap.add_argument("--out-md", type=Path, default=OUT_MD)
    ap.add_argument("--out-json", type=Path, default=OUT_JSON)
    args = ap.parse_args()

    payload = build_report()
    args.out_json.parent.mkdir(parents=True, exist_ok=True)
    args.out_md.parent.mkdir(parents=True, exist_ok=True)
    args.out_json.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    write_markdown(payload, args.out_md)
    print(f"[product_report] json={args.out_json} md={args.out_md}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
