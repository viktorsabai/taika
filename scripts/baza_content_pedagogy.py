#!/usr/bin/env python3
"""
Педагогические правки курса «База от Тайки» (course_b_1):

1. Scaffolding: в каждом уроке сначала word, потом tip, потом phrase/casual
   (чтобы «Хочу это» шло после слов «Хочу» и «Это»).

2. Разгрузка l3: урок «Как дела?» ограничить 8–10 карточками; союзы (и, но, потому что,
   если, поэтому) вынести в новый урок course_b_1_l3b «Союзы и связки».

3. Базовые вопросы в начало: Где, Кто, Когда добавить в урок l2 (Знакомство) в начало.

Обновляет steps.json и lessons.json. Использует те же приёмы, что и full_courses_analytics.
Запуск из корня репо:
  python3 scripts/baza_content_pedagogy.py --steps steps.json --lessons lessons.json [--dry-run] [--backup]
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

BASE = Path(__file__).resolve().parent.parent


def learnable_count(items: list[dict]) -> int:
    return sum(
        1
        for it in items
        if (it.get("kind") or "").strip().lower() in ("word", "phrase", "casual")
    )


def reorder_scaffolding(items: list[dict]) -> list[dict]:
    """Сначала word, потом tip, потом phrase/casual. Сохраняем относительный порядок внутри групп."""
    words = [it for it in items if (it.get("kind") or "").strip().lower() == "word"]
    tips = [it for it in items if (it.get("kind") or "").strip().lower() == "tip"]
    rest = [
        it
        for it in items
        if (it.get("kind") or "").strip().lower() in ("phrase", "casual", "dialog")
    ]
    out = []
    for i, it in enumerate(words + tips + rest, start=1):
        new_it = dict(it)
        new_it["order"] = i
        out.append(new_it)
    return out


def run(
    steps_path: Path,
    lessons_path: Path,
    dry_run: bool = False,
    backup: bool = False,
) -> None:
    with open(steps_path, "r", encoding="utf-8") as f:
        steps_data = json.load(f)
    with open(lessons_path, "r", encoding="utf-8") as f:
        lessons_data = json.load(f)

    stepsets = {s["id"]: s for s in steps_data.get("stepsets", [])}
    # Найти курс course_b_1 в lessons
    course_b1 = None
    for c in lessons_data.get("courses", []):
        if c.get("course_id") == "course_b_1":
            course_b1 = c
            break
    if not course_b1:
        print("course_b_1 not found in lessons.json", file=sys.stderr)
        sys.exit(1)

    lessons_list = course_b1.get("lessons", [])
    lesson_by_id = {l["lesson_id"]: l for l in lessons_list}

    changes = []

    # ---- 1. Переставить order в l4 (и во всех уроках базы): word → tip → phrase ----
    for lid in ["course_b_1_l1_steps", "course_b_1_l2_steps", "course_b_1_l3_steps", "course_b_1_l4_steps",
                "course_b_1_l5_steps", "course_b_1_l6_steps", "course_b_1_l7_steps", "course_b_1_l8_steps"]:
        if lid not in stepsets:
            continue
        stepset = stepsets[lid]
        items = stepset.get("items", [])
        reordered = reorder_scaffolding(items)
        if reordered != items:
            stepset["items"] = reordered
            changes.append(f"{lid}: scaffolding order (word → tip → phrase)")

    # ---- 2. Разбить l3: оставить 1–10, союзы 11–15 → новый stepset l3b ----
    l3_id = "course_b_1_l3_steps"
    l3b_id = "course_b_1_l3b_steps"
    created_l3b = False
    if l3_id in stepsets:
        items = stepsets[l3_id]["items"]
        # Союзы: И, Но, Потому что, Если, Поэтому (order 11–15)
        conj_ru = {"И", "Но", "Потому что", "Если", "Поэтому"}
        main_items = [it for it in items if it.get("ru") not in conj_ru]
        conj_items = [it for it in items if it.get("ru") in conj_ru]
        if len(main_items) > 10:
            # Оставляем первые 10 по смыслу (фразы «Как дела» + 2 tip)
            main_items = main_items[:10]
        for i, it in enumerate(main_items, start=1):
            it["order"] = i
        stepsets[l3_id]["items"] = main_items
        changes.append(f"{l3_id}: reduced to {len(main_items)} items")

        created_l3b = False
        if conj_items and l3b_id not in stepsets:
            for i, it in enumerate(conj_items, start=1):
                it = dict(it)
                it["order"] = i
                conj_items[i - 1] = it
            new_stepset = {
                "id": l3b_id,
                "course_id": "course_b_1",
                "lesson_id": "course_b_1_l3b",
                "hints": ["Союзы связывают фразы.", "И, но, потому что — кирпичи предложений."],
                "items": conj_items,
            }
            steps_data["stepsets"].append(new_stepset)
            stepsets[l3b_id] = new_stepset
            created_l3b = True
            changes.append(f"{l3b_id}: created with {len(conj_items)} conjunction words")

    # ---- 3. Добавить урок l3b в lessons.json (только если создали stepset) ----
    if created_l3b and "course_b_1_l3b" not in lesson_by_id:
        new_lesson = {
            "lesson_id": "course_b_1_l3b",
            "order": 4,
            "title": "Союзы и связки",
            "subtitle": "И, но, потому что, если — чтобы собирать фразы",
            "duration_minutes": 2,
            "card_count": 5,
            "is_free": False,
            "tags": [],
            "preview_phrase": "и;лэ→",
            "content": [{"kind": "intro", "text": ""}, {"kind": "outline", "text": ""}, {"kind": "apply", "text": ""}],
            "outcomes": [],
            "prerequisites": ["course_b_1_l3"],
            "links": {"steps_ref": "course_b_1_l3b_steps", "hometask_ref": "course_b_1_l3b_home"},
            "assistant_tips": [],
        }
        # Вставить после l3 (order 3), сдвинуть l4..l8
        idx = next(i for i, l in enumerate(lessons_list) if l["lesson_id"] == "course_b_1_l3") + 1
        lessons_list.insert(idx, new_lesson)
        for i, l in enumerate(lessons_list):
            if l["lesson_id"] == "course_b_1_l1":
                l["order"] = 1
            elif l["lesson_id"] == "course_b_1_l2":
                l["order"] = 2
            elif l["lesson_id"] == "course_b_1_l3":
                l["order"] = 3
            elif l["lesson_id"] == "course_b_1_l3b":
                l["order"] = 4
            elif l["lesson_id"] == "course_b_1_l4":
                l["order"] = 5
            elif l["lesson_id"] == "course_b_1_l5":
                l["order"] = 6
            elif l["lesson_id"] == "course_b_1_l6":
                l["order"] = 7
            elif l["lesson_id"] == "course_b_1_l7":
                l["order"] = 8
            elif l["lesson_id"] == "course_b_1_l8":
                l["order"] = 9
        # Обновить prerequisites у l4: теперь после l3b
        for l in lessons_list:
            if l["lesson_id"] == "course_b_1_l4":
                l["prerequisites"] = ["course_b_1_l3b"]
                break
        # card_count для l3
        for l in lessons_list:
            if l["lesson_id"] == "course_b_1_l3":
                l["card_count"] = learnable_count(stepsets[l3_id]["items"])
                break
        changes.append("lessons.json: added course_b_1_l3b, reordered l4..l8")

    # ---- 4. Базовые вопросы в l2: добавить Где, Кто, Когда в начало ----
    l2_id = "course_b_1_l2_steps"
    if l2_id in stepsets:
        items = stepsets[l2_id]["items"]
        rus = [it.get("ru") for it in items]
        if not any(r in rus for r in ("Где", "Где?", "Кто", "Кто?", "Когда", "Когда?")):
            question_words = [
                {"order": 1, "kind": "word", "ru": "Где?", "thai": "ที่ไหน", "phonetic": "ти→ най↗", "tip": "Где? Ти най — вопрос о месте."},
                {"order": 2, "kind": "word", "ru": "Кто?", "thai": "ใคร", "phonetic": "кхрай→", "tip": "Кто? Кхрай — вопрос о человеке."},
                {"order": 3, "kind": "word", "ru": "Когда?", "thai": "เมื่อไหร่", "phonetic": "мыа→ рай↘", "tip": "Когда? Мыа рай — вопрос о времени."},
            ]
            for it in items:
                it["order"] = it.get("order", 0) + 3
            stepsets[l2_id]["items"] = question_words + items
            changes.append(f"{l2_id}: added Где?, Кто?, Когда? at start")
            # Обновить card_count для l2
            for l in lessons_list:
                if l["lesson_id"] == "course_b_1_l2":
                    l["card_count"] = learnable_count(stepsets[l2_id]["items"])
                    break

    # Синхронизировать card_count для затронутых уроков
    for stepset in steps_data.get("stepsets", []):
        sid = stepset.get("id", "")
        lid = stepset.get("lesson_id", "")
        if lid in lesson_by_id or lid == "course_b_1_l3b":
            n = learnable_count(stepset.get("items", []))
            for l in lessons_list:
                if l.get("lesson_id") == lid:
                    l["card_count"] = n
                    break

    if not changes:
        print("No changes needed.")
        return

    print("Changes:")
    for c in changes:
        print(" ", c)

    if dry_run:
        print("(dry-run: files not written)")
        return
    if backup:
        steps_path.with_suffix(steps_path.suffix + ".bak").write_text(
            steps_path.read_text(encoding="utf-8"), encoding="utf-8"
        )
        lessons_path.with_suffix(lessons_path.suffix + ".bak").write_text(
            lessons_path.read_text(encoding="utf-8"), encoding="utf-8"
        )
        print("Backups created.")
    with open(steps_path, "w", encoding="utf-8") as f:
        json.dump(steps_data, f, ensure_ascii=False, indent=2)
    with open(lessons_path, "w", encoding="utf-8") as f:
        json.dump(lessons_data, f, ensure_ascii=False, indent=2)
    print(f"Written: {steps_path}, {lessons_path}")


def main() -> None:
    ap = argparse.ArgumentParser(description="Baza course pedagogy: scaffolding, split l3, questions in l2.")
    ap.add_argument("--steps", type=Path, default=BASE / "steps.json")
    ap.add_argument("--lessons", type=Path, default=BASE / "lessons.json")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--backup", action="store_true")
    args = ap.parse_args()
    run(args.steps, args.lessons, args.dry_run, args.backup)


if __name__ == "__main__":
    main()
