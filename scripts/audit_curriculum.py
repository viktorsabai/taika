#!/usr/bin/env python3
"""Full curriculum gate: catalog + lessons + cards. Writes JSON report, does not mutate content."""
from __future__ import annotations

import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "taika/Resourses/taika_basa_course.json"
LESSONS = ROOT / "lessons.json"
STEPS = ROOT / "steps.json"

ARROWS = set("→↓↘↑↗")
LATIN = re.compile(r"[A-Za-z]")
CYR = re.compile(r"[а-яёА-ЯЁ]")
THAI = re.compile(r"[\u0E00-\u0E7F]")
COMBINING = re.compile(r"[\u0300-\u036f]")
CONTENT_KINDS = {"word", "phrase", "casual"}
PARTICLE_ONLY = {"ครับ", "ค่ะ", "คะ"}
PH_PARTICLE = re.compile(r"^(кхрап|крап|кха)[→↓↘↑↗]?$", re.I)
GENERIC_TIPS = (
    "Используй как короткую реплику",
    "детали и объяснение держи отдельно",
    "Не строй длинный диалог",
)


def load(path: Path):
    with path.open(encoding="utf-8") as f:
        return json.load(f)


def loc(stepset, item) -> str:
    return f"{stepset.get('course_id')}/{stepset.get('lesson_id')}#{item.get('order')} {item.get('kind')}"


def main() -> int:
    catalog = load(CATALOG)
    lessons_root = load(LESSONS)
    steps_root = load(STEPS)

    issues: list[dict] = []
    stats = Counter()

    cat_ids = [c["id"] for c in catalog]
    stats["catalog_courses"] = len(cat_ids)
    if len(cat_ids) != len(set(cat_ids)):
        issues.append({"sev": "error", "kind": "dup_catalog_id", "ids": [k for k, n in Counter(cat_ids).items() if n > 1]})

    lesson_courses = {c["course_id"]: c for c in lessons_root["courses"]}
    stepsets = steps_root["stepsets"]
    stepset_by_id = {s["id"]: s for s in stepsets}
    stepset_by_lesson = {s["lesson_id"]: s for s in stepsets}

    stats["lesson_courses"] = len(lesson_courses)
    stats["stepsets"] = len(stepsets)

    for cid in cat_ids:
        if cid not in lesson_courses:
            issues.append({"sev": "error", "kind": "catalog_missing_lessons", "course": cid})
    for cid in lesson_courses:
        if cid not in cat_ids:
            issues.append({"sev": "error", "kind": "lessons_orphan_course", "course": cid})

    declared = {c["id"]: c.get("lesson_count") for c in catalog}
    catalog_titles = {c["id"]: c.get("title") for c in catalog}
    for cid, block in lesson_courses.items():
        n = len(block.get("lessons") or [])
        stats["lessons_total"] += n
        want = declared.get(cid)
        if want is not None and want != n:
            issues.append({"sev": "error", "kind": "lesson_count_mismatch", "course": cid, "declared": want, "actual": n})
        cat_title = catalog_titles.get(cid)
        if cat_title and block.get("course_title") != cat_title:
            issues.append({"sev": "error", "kind": "course_title_mismatch", "course": cid, "catalog": cat_title, "lessons": block.get("course_title")})
        orders = [l.get("order") for l in block.get("lessons") or []]
        if orders != list(range(1, n + 1)):
            issues.append({"sev": "warn", "kind": "lesson_order_gap", "course": cid, "orders": orders})
        for les in block.get("lessons") or []:
            lid = les.get("lesson_id")
            ref = (les.get("links") or {}).get("steps_ref")
            if not lid:
                issues.append({"sev": "error", "kind": "lesson_no_id", "course": cid})
                continue
            if not ref:
                issues.append({"sev": "error", "kind": "lesson_no_steps_ref", "lesson": lid})
            elif ref not in stepset_by_id:
                issues.append({"sev": "error", "kind": "broken_steps_ref", "lesson": lid, "ref": ref})
            elif stepset_by_id[ref].get("lesson_id") != lid:
                issues.append({"sev": "error", "kind": "steps_ref_lesson_mismatch", "lesson": lid, "ref": ref})
            if lid not in stepset_by_lesson:
                issues.append({"sev": "error", "kind": "lesson_no_stepset", "lesson": lid})
            content = les.get("content") or []
            if len(content) < 3:
                issues.append({"sev": "warn", "kind": "thin_lesson_content", "lesson": lid, "blocks": len(content)})
            if not (les.get("outcomes") or []):
                issues.append({"sev": "warn", "kind": "empty_outcomes", "lesson": lid})
            title = les.get("title") or ""
            if re.search(r"сценка|Мини-диалог|Repair-сцен", title, re.I) or title in {"Small talk"}:
                issues.append({"sev": "error", "kind": "generator_lesson_title", "lesson": lid, "title": title})
            preview = les.get("preview_phrase") or ""
            if LATIN.search(preview.split(";")[-1] if ";" in preview else preview):
                issues.append({"sev": "error", "kind": "latin_preview_phrase", "lesson": lid, "preview": preview})
            if COMBINING.search(preview) or "кхрап/" in preview.lower() or "кха̂" in preview:
                issues.append({"sev": "error", "kind": "polite_or_diacritic_preview", "lesson": lid, "preview": preview})
            intro = next((b.get("text") or "" for b in (les.get("content") or []) if b.get("kind") == "intro"), "")
            apply = next((b.get("text") or "" for b in (les.get("content") or []) if b.get("kind") == "apply"), "")
            blob = f"{intro}\n{apply}"
            if "phrase bank" in blob.lower() or "Кун Кру объясняет сцену" in blob or "как короткий диалог" in blob:
                issues.append({"sev": "error", "kind": "generator_lesson_copy", "lesson": lid, "intro": intro[:160]})

    for ss in stepsets:
        if ss.get("course_id") not in cat_ids:
            issues.append({"sev": "error", "kind": "stepset_orphan_course", "id": ss.get("id")})
        known_lessons = {l.get("lesson_id") for b in lesson_courses.values() for l in b.get("lessons") or []}
        if ss.get("lesson_id") not in known_lessons:
            issues.append({"sev": "error", "kind": "stepset_orphan_lesson", "id": ss.get("id")})

    by_thai: dict[str, list[str]] = defaultdict(list)

    for ss in stepsets:
        items = ss.get("items") or []
        stats["cards_total"] += len(items)
        orders = [it.get("order") for it in items]
        if len(orders) != len(set(orders)):
            issues.append({"sev": "error", "kind": "dup_order", "stepset": ss.get("id"), "orders": orders})
        content_n = 0
        for it in items:
            kind = it.get("kind")
            stats[f"kind_{kind}"] += 1
            where = loc(ss, it)
            if kind == "tip":
                text = (it.get("text") or "").strip()
                if not text:
                    issues.append({"sev": "error", "kind": "empty_tip", "where": where})
                continue
            if kind not in CONTENT_KINDS:
                issues.append({"sev": "error", "kind": "unknown_kind", "where": where, "value": kind})
                continue
            content_n += 1
            ru = (it.get("ru") or "").strip()
            thai = (it.get("thai") or "").strip()
            ph = (it.get("phonetic") or "").strip()
            tip = (it.get("tip") or "").strip()

            if not ru:
                issues.append({"sev": "error", "kind": "empty_ru", "where": where})
            if not thai:
                issues.append({"sev": "error", "kind": "empty_thai", "where": where})
            if not ph:
                issues.append({"sev": "error", "kind": "empty_phonetic", "where": where})

            if thai and not THAI.search(thai):
                issues.append({"sev": "error", "kind": "thai_not_thai_script", "where": where, "thai": thai})
            if "/" in thai:
                issues.append({"sev": "error", "kind": "slash_in_thai", "where": where, "thai": thai})
            if "/" in ph:
                issues.append({"sev": "error", "kind": "slash_in_phonetic", "where": where, "phonetic": ph})
            compact_th = re.sub(r"\s+", "", thai)
            if compact_th not in PARTICLE_ONLY:
                if "ครับ" in thai or "ค่ะ" in thai:
                    issues.append({"sev": "error", "kind": "baked_politeness_particle", "where": where, "thai": thai})
                if any(PH_PARTICLE.match(p) for p in ph.split()):
                    issues.append({"sev": "error", "kind": "baked_politeness_in_phonetic", "where": where, "phonetic": ph, "thai": thai})

            if ph:
                has_latin = bool(LATIN.search(ph))
                has_cyr = bool(CYR.search(ph))
                has_thai = bool(THAI.search(ph))
                has_comb = bool(COMBINING.search(ph))
                has_arrow = any(a in ph for a in ARROWS)
                if has_latin:
                    issues.append({"sev": "error", "kind": "latin_phonetic", "where": where, "phonetic": ph, "thai": thai, "ru": ru})
                if has_thai:
                    issues.append({"sev": "error", "kind": "thai_in_phonetic", "where": where, "phonetic": ph})
                if has_comb:
                    issues.append({"sev": "error", "kind": "diacritic_phonetic", "where": where, "phonetic": ph, "thai": thai, "ru": ru})
                if has_cyr and not has_latin and not has_arrow and not has_comb:
                    issues.append({"sev": "error", "kind": "missing_tone_arrows", "where": where, "phonetic": ph, "thai": thai, "ru": ru})
                if has_cyr and has_arrow and not has_latin and not has_comb:
                    stats["phonetic_ok"] += 1

            if tip:
                if any(g.lower() in tip.lower() for g in GENERIC_TIPS):
                    issues.append({"sev": "warn", "kind": "generic_agent_tip", "where": where, "tip": tip})
                if THAI.search(tip):
                    issues.append({"sev": "warn", "kind": "thai_script_in_tip", "where": where, "tip": tip})
                letters = re.findall(r"[A-Za-zА-Яа-яЁё]", tip)
                latin_n = sum(1 for c in letters if ("A" <= c <= "Z" or "a" <= c <= "z"))
                if letters and latin_n / len(letters) > 0.55:
                    issues.append({"sev": "error", "kind": "english_tip", "where": where, "tip": tip})

            if thai:
                by_thai[thai].append(where)

        if content_n == 0 and not str(ss.get("course_id") or "").startswith("course_b_0"):
            # b0 — теоретический курс: карточки-правила без word/phrase, это задумано.
            issues.append({"sev": "error", "kind": "lesson_no_learnable_cards", "stepset": ss.get("id")})
        stats["learnable_cards"] += content_n

    for thai, places in by_thai.items():
        if len(places) > 1:
            stats["dup_thai_cards"] += len(places) - 1
        courses = {p.split("/")[0] for p in places}
        if len(courses) > 1:
            issues.append({"sev": "info", "kind": "thai_shared_across_courses", "thai": thai, "places": places[:8], "n": len(places)})

    by_kind = Counter(i["kind"] for i in issues)
    by_sev = Counter(i["sev"] for i in issues)

    def course_of(i):
        if i.get("course"):
            return i["course"]
        if i.get("where"):
            return i["where"].split("/")[0]
        if i.get("lesson"):
            return i["lesson"].rsplit("_l", 1)[0]
        return ""

    latin_by_course = Counter(course_of(i) for i in issues if i["kind"] == "latin_phonetic")
    dia_by_course = Counter(course_of(i) for i in issues if i["kind"] == "diacritic_phonetic")
    arrow_by_course = Counter(course_of(i) for i in issues if i["kind"] == "missing_tone_arrows")
    courses_with_errors = sorted({course_of(i) for i in issues if i["sev"] == "error"} - {""})

    report = {
        "stats": dict(stats),
        "severity": dict(by_sev),
        "issue_kinds": dict(by_kind),
        "courses_with_errors": courses_with_errors,
        "latin_by_course": dict(latin_by_course),
        "diacritic_by_course": dict(dia_by_course),
        "missing_arrows_by_course": dict(arrow_by_course),
        "issues": issues,
    }
    out = ROOT / "curriculum_audit_report.json"
    out.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    print(f"courses={stats['catalog_courses']} lessons={stats['lessons_total']} cards={stats['cards_total']} learnable={stats['learnable_cards']} phonetic_ok={stats['phonetic_ok']}")
    print("severity", dict(by_sev))
    print("issue_kinds")
    for k, n in by_kind.most_common():
        print(f"  {n:4d}  {k}")
    print("latin_by_course", dict(latin_by_course.most_common()))
    print("diacritic_by_course", dict(dia_by_course.most_common()))
    print("missing_arrows_by_course", dict(arrow_by_course.most_common()))
    print("wrote", out)
    return 0 if by_sev.get("error", 0) == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
