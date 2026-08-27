#!/usr/bin/env python3
"""Strict structural/content-format gate for steps.json.

This intentionally does not judge translation quality or curriculum logic. It blocks
only malformed JSON, schema/identity/link errors, unsafe strings, and parser-breaking
phonetic formatting.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path
from typing import Any

ALLOWED_KINDS = {"word", "phrase", "casual", "tip", "dialog"}
TONE_ARROWS = set("→↓↘↑↗")
ALLOWED_PHONETIC_CHARS = set(
    "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ"
    "абвгдеёжзийклмнопрстуфхцчшщъыьэюя"
    " -→↓↘↑↗"
)
PHONETIC_TOKEN_RE = re.compile(r"^[А-Яа-яЁё]+(?:[А-Яа-яЁё]+)*[→↓↘↑↗]$")


def is_string(value: Any) -> bool:
    return isinstance(value, str)


def nonempty_string(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def add(errors: list[dict[str, Any]], code: str, location: str, message: str, **extra: Any) -> None:
    row = {"code": code, "location": location, "message": message}
    row.update(extra)
    errors.append(row)


def warn(warnings: list[dict[str, Any]], code: str, location: str, message: str, **extra: Any) -> None:
    row = {"code": code, "location": location, "message": message}
    row.update(extra)
    warnings.append(row)


def check_phonetic(value: Any, location: str, errors: list[dict[str, Any]]) -> None:
    if not isinstance(value, str):
        add(errors, "phonetic_type", location, "phonetic must be a string")
        return
    if not value.strip():
        add(errors, "phonetic_empty", location, "phonetic must not be empty")
        return
    if value != value.strip():
        add(errors, "outer_whitespace", location, "phonetic has leading/trailing whitespace")
    bad = sorted({ch for ch in value if ch not in ALLOWED_PHONETIC_CHARS})
    if bad:
        add(errors, "phonetic_character", location, "phonetic contains unsupported characters", characters=bad)
    if "/" in value:
        add(errors, "phonetic_slash", location, "phonetic must not contain slash alternatives")
    if any(ch in value for ch in ("‑", "–", "—", "−")):
        add(errors, "phonetic_non_ascii_dash", location, "phonetic may use only ASCII hyphen-minus")
    if "- " in value or " -" in value:
        add(errors, "phonetic_dash_spacing", location, "phonetic must not have spaces around hyphens")
    if "--" in value or value.startswith("-") or value.endswith("-"):
        add(errors, "phonetic_dash_shape", location, "phonetic has malformed hyphen placement")
    for token in value.split():
        parts = token.split("-")
        for part in parts:
            if not PHONETIC_TOKEN_RE.fullmatch(part):
                add(errors, "phonetic_token", location, "every phonetic syllable must be Cyrillic and end with one tone arrow", token=part)


def load_json(path: Path, label: str, errors: list[dict[str, Any]]) -> Any | None:
    try:
        raw = path.read_bytes()
        raw.decode("utf-8")
    except FileNotFoundError:
        add(errors, "file_missing", str(path), f"{label} file does not exist")
        return None
    except UnicodeDecodeError as exc:
        add(errors, "utf8", str(path), f"{label} is not valid UTF-8: {exc}")
        return None
    try:
        return json.loads(raw)
    except json.JSONDecodeError as exc:
        add(errors, "json_syntax", str(path), f"{label} is invalid JSON: {exc}")
        return None


def validate_steps(doc: Any, errors: list[dict[str, Any]], warnings: list[dict[str, Any]]) -> dict[str, Any]:
    if not isinstance(doc, dict):
        add(errors, "root_type", "steps.json", "root must be an object")
        return {}
    if not isinstance(doc.get("version"), int) or isinstance(doc.get("version"), bool):
        add(errors, "version", "steps.version", "version must be an integer")
    stepsets = doc.get("stepsets")
    if not isinstance(stepsets, list):
        add(errors, "stepsets_type", "steps.stepsets", "stepsets must be an array")
        return doc
    stepset_ids: list[str] = []
    lesson_ids: list[str] = []
    total_items = 0
    kind_counts: Counter[str] = Counter()
    items_by_lesson: dict[str, int] = {}
    for si, stepset in enumerate(stepsets):
        base = f"stepsets[{si}]"
        if not isinstance(stepset, dict):
            add(errors, "stepset_type", base, "stepset must be an object")
            continue
        sid = stepset.get("id")
        course_id = stepset.get("course_id")
        lesson_id = stepset.get("lesson_id")
        for field, value in (("id", sid), ("course_id", course_id), ("lesson_id", lesson_id)):
            if not nonempty_string(value):
                add(errors, "stepset_field", f"{base}.{field}", f"{field} must be a non-empty string")
        if isinstance(sid, str): stepset_ids.append(sid)
        if isinstance(lesson_id, str): lesson_ids.append(lesson_id)
        if "hints" in stepset and not (isinstance(stepset["hints"], list) and all(is_string(x) for x in stepset["hints"])):
            add(errors, "hints_type", f"{base}.hints", "hints must be an array of strings")
        if "tags" in stepset and not (isinstance(stepset["tags"], list) and all(is_string(x) for x in stepset["tags"])):
            add(errors, "tags_type", f"{base}.tags", "tags must be an array of strings")
        items = stepset.get("items")
        if not isinstance(items, list):
            add(errors, "items_type", f"{base}.items", "items must be an array")
            continue
        orders: list[int] = []
        for ii, item in enumerate(items):
            loc = f"{base}.items[{ii}]"
            if not isinstance(item, dict):
                add(errors, "item_type", loc, "item must be an object")
                continue
            order = item.get("order")
            if not isinstance(order, int) or isinstance(order, bool) or order < 1:
                add(errors, "order", f"{loc}.order", "order must be an integer >= 1")
            else:
                orders.append(order)
            kind = item.get("kind")
            if kind not in ALLOWED_KINDS:
                add(errors, "kind", f"{loc}.kind", "kind must be one of word, phrase, casual, tip, dialog", value=kind)
            else:
                kind_counts[kind] += 1
            for field in ("ru", "thai", "phonetic", "tip", "text"):
                if field in item and isinstance(item[field], str) and item[field] != item[field].strip():
                    add(errors, "outer_whitespace", f"{loc}.{field}", f"{field} has leading/trailing whitespace")
            if kind in {"word", "phrase", "casual"}:
                for field in ("ru", "thai", "phonetic"):
                    if not nonempty_string(item.get(field)):
                        add(errors, "required_field", f"{loc}.{field}", f"{field} is required for {kind}")
                check_phonetic(item.get("phonetic"), f"{loc}.phonetic", errors)
            elif kind == "tip":
                if not (nonempty_string(item.get("text")) or nonempty_string(item.get("tip"))):
                    add(errors, "tip_text", loc, "tip requires non-empty text or tip")
            elif kind == "dialog":
                lines = item.get("lines")
                if lines is not None:
                    if not isinstance(lines, list):
                        add(errors, "dialog_lines_type", f"{loc}.lines", "dialog lines must be an array")
                    else:
                        for li, line in enumerate(lines):
                            l_loc = f"{loc}.lines[{li}]"
                            if not isinstance(line, dict):
                                add(errors, "dialog_line_type", l_loc, "dialog line must be an object")
                                continue
                            for field in ("who", "ru"):
                                if not nonempty_string(line.get(field)):
                                    add(errors, "dialog_line_field", f"{l_loc}.{field}", f"dialog line {field} is required")
        if len(orders) != len(set(orders)):
            duplicates = sorted(order for order, count in Counter(orders).items() if count > 1)
            add(errors, "duplicate_order", f"{base}.items", "order must be unique inside a stepset", values=duplicates)
        if orders != sorted(orders):
            warn(warnings, "unsorted_items", f"{base}.items", "items are not sorted by order")
        total_items += len(items)
        if isinstance(lesson_id, str):
            items_by_lesson[lesson_id] = len(items)
    for value, count in Counter(stepset_ids).items():
        if count > 1:
            add(errors, "duplicate_stepset_id", "steps.stepsets", "stepset id must be unique", value=value)
    for value, count in Counter(lesson_ids).items():
        if count > 1:
            add(errors, "duplicate_lesson_id", "steps.stepsets", "lesson_id must be unique", value=value)
    return {"stepsets": len(stepsets), "items": total_items, "kinds": dict(kind_counts), "stepset_ids": set(stepset_ids), "lesson_ids": set(lesson_ids), "items_by_lesson": items_by_lesson}


def validate_lessons(doc: Any, steps_meta: dict[str, Any], errors: list[dict[str, Any]], warnings: list[dict[str, Any]]) -> None:
    if doc is None:
        return
    if not isinstance(doc, dict) or not isinstance(doc.get("courses"), list):
        add(errors, "lessons_root", "lessons.json", "lessons root must contain courses array")
        return
    lesson_ids: set[str] = set()
    refs: list[str] = []
    for ci, course in enumerate(doc["courses"]):
        if not isinstance(course, dict) or not isinstance(course.get("lessons"), list):
            add(errors, "lessons_course", f"courses[{ci}]", "course must contain lessons array")
            continue
        for li, lesson in enumerate(course["lessons"]):
            loc = f"courses[{ci}].lessons[{li}]"
            if not isinstance(lesson, dict):
                add(errors, "lesson_type", loc, "lesson must be an object")
                continue
            lesson_id = lesson.get("lesson_id")
            if not nonempty_string(lesson_id):
                add(errors, "lesson_id", f"{loc}.lesson_id", "lesson_id must be a non-empty string")
            elif lesson_id in lesson_ids:
                add(errors, "duplicate_lesson_id", f"{loc}.lesson_id", "lesson_id must be unique", value=lesson_id)
            else:
                lesson_ids.add(lesson_id)
            card_count = lesson.get("card_count")
            if not isinstance(card_count, int) or isinstance(card_count, bool) or card_count < 0:
                add(errors, "card_count_type", f"{loc}.card_count", "card_count must be an integer >= 0")
            elif isinstance(lesson_id, str) and lesson_id in steps_meta.get("items_by_lesson", {}):
                expected_count = steps_meta["items_by_lesson"][lesson_id]
                if card_count != expected_count:
                    add(errors, "card_count_mismatch", f"{loc}.card_count", "card_count must equal the number of StepSet.items", declared=card_count, actual=expected_count, lesson_id=lesson_id)
            links = lesson.get("links")
            if not isinstance(links, dict) or not nonempty_string(links.get("steps_ref")):
                add(errors, "steps_ref_missing", f"{loc}.links.steps_ref", "lesson must have non-empty links.steps_ref")
            else:
                refs.append(links["steps_ref"])
            for field in ("title", "subtitle"):
                if field in lesson and isinstance(lesson[field], str) and lesson[field] != lesson[field].strip():
                    add(errors, "outer_whitespace", f"{loc}.{field}", f"{field} has leading/trailing whitespace")
    step_lesson_ids = steps_meta.get("lesson_ids", set())
    step_stepset_ids = steps_meta.get("stepset_ids", set())
    for ref in refs:
        if ref not in step_stepset_ids:
            add(errors, "orphan_steps_ref", "lessons.links.steps_ref", "steps_ref does not match any StepSet.id", value=ref)
    for lesson_id in lesson_ids:
        if lesson_id not in step_lesson_ids:
            add(errors, "missing_stepset", "lessons.lesson_id", "lesson has no matching StepSet.lesson_id", value=lesson_id)
    for lesson_id in step_lesson_ids:
        if lesson_id not in lesson_ids:
            add(errors, "orphan_stepset", "steps.stepsets.lesson_id", "StepSet has no matching lesson", value=lesson_id)


def main() -> int:
    parser = argparse.ArgumentParser(description="Strict structural gate for steps.json")
    parser.add_argument("--root", type=Path, default=Path.cwd(), help="repository root containing steps.json and lessons.json")
    parser.add_argument("--steps", type=Path, help="override steps.json path")
    parser.add_argument("--lessons", type=Path, help="override lessons.json path")
    parser.add_argument("--warnings-as-errors", action="store_true")
    args = parser.parse_args()
    root = args.root.resolve()
    steps_path = (args.steps or (root / "steps.json")).resolve()
    lessons_path = (args.lessons or (root / "lessons.json")).resolve()
    errors: list[dict[str, Any]] = []
    warnings: list[dict[str, Any]] = []
    steps_doc = load_json(steps_path, "steps.json", errors)
    lessons_doc = load_json(lessons_path, "lessons.json", errors)
    meta = validate_steps(steps_doc, errors, warnings) if steps_doc is not None else {}
    validate_lessons(lessons_doc, meta, errors, warnings)
    report = {"steps": str(steps_path), "lessons": str(lessons_path), "errors": errors, "warnings": warnings, "summary": {"errors": len(errors), "warnings": len(warnings), **{k: v for k, v in meta.items() if k not in {"stepset_ids", "lesson_ids", "items_by_lesson"}}}}
    print(json.dumps(report["summary"], ensure_ascii=False, sort_keys=True))
    for row in errors[:200]: print("ERROR", json.dumps(row, ensure_ascii=False))
    for row in warnings[:100]: print("WARN", json.dumps(row, ensure_ascii=False))
    if errors or (args.warnings_as_errors and warnings):
        return 1
    print("STEPS_JSON_CHECK_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
