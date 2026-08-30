#!/usr/bin/env python3
"""Heal soul + long-stay: thin lessons and intra-course recap. Do not touch cross-course overlaps."""
from __future__ import annotations

import json
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STEPS = ROOT / "steps.json"
LESSONS = ROOT / "lessons.json"
DIFF = ROOT / "docs/soul_long_curriculum_fix_diff.json"
AUDIT = ROOT / "docs/launch_curriculum_traffic_light.json"
LEARNABLE = {"word", "phrase", "casual"}
PREFIXES = ("course_s_", "course_long_")

REPLACE: list[tuple[str, str, str, str, str, str, str]] = [
    ("course_s_1_l2", "อารมณ์วัน", "phrase", "Сохрани в хайлайтс", "เก็บไฮไลต์เลย", "кеп→ хай→ лайт↘ лёй→", "Следующий шаг сторис, не повтор «вайб дня»."),
    ("course_s_2_l1", "โย", "word", "Йога", "โยคะ", "йо→ ка→", "Полное слово, не обрубок."),
    ("course_s_3_l6", "ตลกแบบไทย", "phrase", "Можно стикер?", "ส่งสติ๊กเกอร์ได้ไหม", "сонг→ са→ тик→ кё→ дай→ май↗", "Живой чат, не повтор «шутки по-тайски»."),
    ("course_s_6_l5", "ความปลอดภัย", "phrase", "В воду недалеко", "อย่าไปไกล", "йаа→ пай→ глай→", "Пляж с ребёнком, не повтор слова «безопасность»."),
    ("course_long_3_l2", "ผลออกหรือยัง", "casual", "Натощак?", "ต้องงดอาหารไหม", "тонг→ нгот→ а→ хаан→ май↗", "Подготовка к анализу, не повтор «результат готов?»."),
]

ADD: dict[str, list[dict]] = {
    "course_s_3_l4": [
        {"kind": "phrase", "ru": "Он правда хороший", "thai": "เขาเป็นคนดีจริง", "phonetic": "кхау→ пэн→ кон→ ди→ дженг→", "tip": "Оценка человека, не возрастное пхи/нонг."},
        {"kind": "phrase", "ru": "Можно без пхи", "thai": "ไม่ต้องเรียกพี่", "phonetic": "май→ тонг→ риак↗ пхи→", "tip": "Когда ровесник, пхи звучит странно."},
        {"kind": "phrase", "ru": "Нонг — про возраст", "thai": "น้องเรื่องอายุ", "phonetic": "нонг↗ рыанг→ а→ йу→", "tip": "Не статус в отношениях, а кто младше."},
        {"kind": "phrase", "ru": "Не обижайся на шутку", "thai": "อย่าโกรธนะ แซวเล่น", "phonetic": "йаа→ кроот→ на↗ сэу→ лэн→", "tip": "Идиома живёт в подколе, не в обиде."},
    ],
    "course_s_4_l2": [
        {"kind": "phrase", "ru": "Во сколько подъём?", "thai": "กี่โมงตื่น", "phonetic": "ги→ монг→ тын→", "tip": "Утро ретрита, не «когда медитация» ещё раз."},
        {"kind": "phrase", "ru": "Не говорить на сидячей", "thai": "ห้ามคุยตอนนั่ง", "phonetic": "хаам↗ кхуй→ тон→ нанг→", "tip": "Правило зала, не расписание."},
    ],
    "course_s_5_l5": [
        {"kind": "phrase", "ru": "Пока не готов встречаться", "thai": "ยังไม่พร้อมคบ", "phonetic": "янг→ май→ пхром↗ кхоп→", "tip": "Ответ на «кто мы», без ссоры."},
        {"kind": "phrase", "ru": "Мы просто друзья", "thai": "แค่เพื่อนนะ", "phonetic": "кэ→ пхыан↗ на↗", "tip": "Статус без кринжа."},
    ],
    "course_s_6_l3": [
        {"kind": "phrase", "ru": "Не беги", "thai": "อย่าวิ่ง", "phonetic": "йаа→ винг↗", "tip": "Мягкий стоп на пляже или у дороги."},
        {"kind": "phrase", "ru": "Горячо", "thai": "ร้อนนะ", "phonetic": "рон↘ на↗", "tip": "Еда, песок, мотоцикл — одна короткая реплика."},
    ],
    "course_s_6_l4": [
        {"kind": "phrase", "ru": "Сколько лет ребёнку?", "thai": "ลูกกี่ขวบ", "phonetic": "луук↘ ги→ кхуап→", "tip": "Разговор с родителем, не комплимент."},
        {"kind": "phrase", "ru": "Есть аллергия на еду?", "thai": "แพ้อาหารอะไรไหม", "phonetic": "пхэ↘ а→ хаан→ а→ рай↗ май↗", "tip": "Перед мороженым или общим столом."},
    ],
}


def in_scope(cid_or_lid: str) -> bool:
    s = str(cid_or_lid or "")
    return s.startswith(PREFIXES)


def audit_slice(payload: dict) -> dict:
    courses = []
    for c in payload.get("courses") or []:
        if not in_scope(c.get("id") or ""):
            continue
        courses.append({
            "id": c["id"],
            "title": c.get("title") or c["id"],
            "color": c.get("color"),
            "learnable": c.get("learnable"),
            "thin": c.get("thin"),
            "dups": c.get("dups"),
            "flags": c.get("flags") or [],
            "lessons": [
                {
                    "id": les["id"],
                    "title": les.get("title") or les["id"],
                    "n": les.get("n"),
                    "color": les.get("color"),
                    "flags": [
                        {"sev": f.get("sev"), "code": f.get("code"), "msg": f.get("msg")}
                        for f in (les.get("flags") or [])
                        if f.get("code") not in {"no_tip", "dup_across_courses", "thin_lesson_copy"}
                    ],
                }
                for les in (c.get("lessons") or [])
            ],
        })
    return {"totals": payload.get("totals") or {}, "courses": courses}


def learnable(items):
    return [it for it in items if (it.get("kind") or "") in LEARNABLE]


def snapshot(stepsets):
    out = {}
    for ss in stepsets:
        lid = ss.get("lesson_id") or ""
        if not in_scope(lid):
            continue
        rows = []
        for it in ss.get("items") or []:
            k = (it.get("kind") or "").strip()
            if k == "tip":
                rows.append({"kind": "tip", "ru": (it.get("text") or "").strip(), "thai": "", "ph": ""})
            elif k in LEARNABLE:
                rows.append({
                    "kind": k,
                    "ru": (it.get("ru") or "").strip(),
                    "thai": (it.get("thai") or "").strip(),
                    "ph": (it.get("phonetic") or "").strip(),
                })
        out[lid] = rows
    return out


def renumber(items):
    out = []
    for i, it in enumerate(items, start=1):
        n = dict(it)
        n["order"] = i
        out.append(n)
    return out


def lid_key(x: str):
    parts = x.split("_")
    try:
        if parts[1] == "long":
            return (1, int(parts[2]), int(parts[3][1:]))
        return (0, int(parts[2]), int(parts[3][1:]))
    except (IndexError, ValueError):
        return (9, 0, x)


def main() -> int:
    before_audit = audit_slice(json.loads(AUDIT.read_text(encoding="utf-8"))) if AUDIT.exists() else {}
    steps = json.loads(STEPS.read_text(encoding="utf-8"))
    lessons = json.loads(LESSONS.read_text(encoding="utf-8"))
    before = snapshot(steps["stepsets"])
    ss_by_lesson = {s["lesson_id"]: s for s in steps["stepsets"]}
    changed: set[str] = set()
    replaced_log: dict[str, list[dict]] = defaultdict(list)

    used_replace: set[tuple[str, str]] = set()
    for lid, old_th, kind, ru, thai, ph, tip in REPLACE:
        ss = ss_by_lesson.get(lid)
        if not ss:
            print("missing lesson", lid, file=sys.stderr)
            return 1
        hit = None
        for it in ss.get("items") or []:
            if (it.get("kind") or "") not in LEARNABLE:
                continue
            if (it.get("thai") or "").strip() != old_th:
                continue
            hit = it
            break
        if hit is None:
            print("replace miss", lid, old_th, file=sys.stderr)
            return 1
        used_replace.add((lid, old_th))
        replaced_log[lid].append({
            "ru_before": (hit.get("ru") or "").strip(),
            "thai_before": (hit.get("thai") or "").strip(),
            "ph_before": (hit.get("phonetic") or "").strip(),
            "ru_after": ru,
            "thai_after": thai,
            "ph_after": ph,
        })
        hit["kind"] = kind
        hit["ru"] = ru
        hit["thai"] = thai
        hit["phonetic"] = ph
        hit["tip"] = tip
        changed.add(lid)

    for lid, extras in ADD.items():
        ss = ss_by_lesson.get(lid)
        if not ss:
            print("missing lesson", lid, file=sys.stderr)
            return 1
        have_th = {(it.get("thai") or "").strip() for it in learnable(ss["items"])}
        have_ru = {(it.get("ru") or "").strip().lower() for it in learnable(ss["items"])}
        for card in extras:
            if card["thai"] in have_th or card["ru"].strip().lower() in have_ru:
                print("skip dup add", lid, card["ru"])
                continue
            ss["items"].append(dict(card))
            have_th.add(card["thai"])
            have_ru.add(card["ru"].strip().lower())
            changed.add(lid)
        ss["items"] = renumber(ss["items"])

    for lid in changed:
        ss_by_lesson[lid]["items"] = renumber(ss_by_lesson[lid]["items"])

    after = snapshot(steps["stepsets"])

    for course in lessons.get("courses") or []:
        if not in_scope(course.get("course_id") or ""):
            continue
        for les in course.get("lessons") or []:
            ss = ss_by_lesson.get(les.get("lesson_id"))
            if ss:
                les["card_count"] = len(ss.get("items") or [])

    titles, courses_of = {}, {}
    for course in lessons.get("courses") or []:
        for les in course.get("lessons") or []:
            titles[les["lesson_id"]] = les.get("title") or les["lesson_id"]
            courses_of[les["lesson_id"]] = course.get("course_title") or course.get("course_id")

    diff_lessons = []
    for lid in sorted(changed, key=lid_key):
        b_learn = [x for x in (before.get(lid) or []) if x["kind"] in LEARNABLE]
        a_learn = [x for x in (after.get(lid) or []) if x["kind"] in LEARNABLE]
        b_keys = {(x["kind"], x["ru"], x["thai"]) for x in b_learn}
        added = [x for x in a_learn if (x["kind"], x["ru"], x["thai"]) not in b_keys]
        added = [x for x in added if not any(r["ru_after"] == x["ru"] and r["thai_after"] == x["thai"] for r in replaced_log.get(lid) or [])]
        diff_lessons.append({
            "id": lid,
            "title": titles.get(lid, lid),
            "course": courses_of.get(lid, ""),
            "n_before": len(b_learn),
            "n_after": len(a_learn),
            "added": added,
            "replaced": replaced_log.get(lid) or [],
            "changed": [],
        })

    STEPS.write_text(json.dumps(steps, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    LESSONS.write_text(json.dumps(lessons, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("changed lessons", len(diff_lessons))
    for row in diff_lessons:
        print(f"  {row['id']} {row['n_before']}→{row['n_after']} +{len(row['added'])} repl={len(row['replaced'])}")
    subprocess.check_call([sys.executable, str(ROOT / "scripts/check_steps_json.py")], cwd=ROOT)
    subprocess.check_call([sys.executable, str(ROOT / "scripts/launch_curriculum_traffic_light.py")], cwd=ROOT)
    after_audit = audit_slice(json.loads(AUDIT.read_text(encoding="utf-8")))
    DIFF.write_text(
        json.dumps(
            {
                "title": "Дифф «Душа + долгожители» — было → стало",
                "html_id": "soul-diff",
                "foot": "Пересечения между курсами не трогали. Только thin и внутренний recap.",
                "note": "Блок 3. Йога โย починена. «Границы» между ретритом и романтикой оставлены.",
                "before": before_audit,
                "after": after_audit,
                "lessons": diff_lessons,
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    subprocess.check_call([sys.executable, str(ROOT / "scripts/launch_curriculum_traffic_light.py")], cwd=ROOT)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
