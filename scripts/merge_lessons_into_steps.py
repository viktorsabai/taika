#!/usr/bin/env python3
"""
Merge draft steps from Desktop/lessons.json into taika/steps.json.
- lessons.json is 3 concatenated JSON arrays (course_b_1, course_b_3, course_b_2).
- Replaces matching stepsets by id; adds course_b_1_l5, course_b_2_l6, course_b_3_l6.
- Normalizes: no 'type' field; phonetic: only ASCII hyphen, no combining acute when arrow present.
"""
import json
import re
import sys

LESSONS_PATH = "/Users/product/Desktop/lessons.json"
STEPS_PATH = "/Users/product/Desktop/taika/steps.json"

# Combining chars to remove from phonetic when we use arrows (spec: don't duplicate with arrow)
COMBINING_REMOVE = re.compile(r"[\u0300\u0301\u0302\u030C\u0306\u0307]")
# Non-ASCII dashes → ASCII hyphen
DASH_REPLACE = re.compile(r"[\u2011\u2014\u2212\u2010\u2013]")


def normalize_phonetic(s: str) -> str:
    if not s or not isinstance(s, str):
        return s
    s = DASH_REPLACE.sub("-", s)
    # If there's a tone arrow, remove combining accents on same syllable (simplify: remove all)
    if "↗" in s or "↘" in s or "→" in s:
        s = COMBINING_REMOVE.sub("", s)
    return s.strip()


def normalize_item(item: dict) -> dict:
    out = {}
    for k, v in item.items():
        if k == "type":
            continue
        if k == "phonetic" and isinstance(v, str):
            v = normalize_phonetic(v)
        if isinstance(v, str):
            v = v.strip()
        out[k] = v
    return out


def load_draft_lessons(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        raw = f.read()
    # Split by "]\n [" or "]\n\n [" to get 3 arrays
    parts = re.split(r"\][\s]*\[", raw)
    by_id = {}
    for part in parts:
        part = part.strip()
        if not part:
            continue
        # Restore brackets
        if not part.startswith("["):
            part = "[" + part
        if not part.endswith("]"):
            part = part + "]"
        try:
            arr = json.loads(part)
        except json.JSONDecodeError as e:
            print("Parse error in part:", e, file=sys.stderr)
            continue
        for stepset in arr:
            sid = stepset.get("id")
            if not sid:
                continue
            stepset = dict(stepset)
            stepset["items"] = [normalize_item(it) for it in stepset.get("items", [])]
            by_id[sid] = stepset
    return by_id


def main():
    draft = load_draft_lessons(LESSONS_PATH)
    with open(STEPS_PATH, "r", encoding="utf-8") as f:
        app = json.load(f)

    stepsets = app["stepsets"]
    new_stepsets = []
    insert_b_1_l5 = None
    insert_b_2_l6 = None
    insert_b_3_l6 = None

    for ss in stepsets:
        sid = ss.get("id", "")
        if sid in draft:
            new_stepsets.append(draft[sid])
            if sid == "course_b_1_l4_steps":
                insert_b_1_l5 = draft.get("course_b_1_l5_steps")
            elif sid == "course_b_2_l5_steps":
                insert_b_2_l6 = draft.get("course_b_2_l6_steps")
            elif sid == "course_b_3_l5_steps":
                insert_b_3_l6 = draft.get("course_b_3_l6_steps")
        else:
            if sid == "course_b_1_l4_steps":
                insert_b_1_l5 = draft.get("course_b_1_l5_steps")
            elif sid == "course_b_2_l5_steps":
                insert_b_2_l6 = draft.get("course_b_2_l6_steps")
            elif sid == "course_b_3_l5_steps":
                insert_b_3_l6 = draft.get("course_b_3_l6_steps")
            new_stepsets.append(ss)

        if insert_b_1_l5 and sid == "course_b_1_l4_steps" and (not new_stepsets or new_stepsets[-1].get("id") != "course_b_1_l5_steps"):
            # Insert right after current (which was just appended)
            if new_stepsets[-1].get("id") == "course_b_1_l4_steps":
                new_stepsets.append(insert_b_1_l5)
            insert_b_1_l5 = None
        if insert_b_2_l6 and sid == "course_b_2_l5_steps" and new_stepsets and new_stepsets[-1].get("id") == "course_b_2_l5_steps":
            new_stepsets.append(insert_b_2_l6)
            insert_b_2_l6 = None
        if insert_b_3_l6 and sid == "course_b_3_l5_steps" and new_stepsets and new_stepsets[-1].get("id") == "course_b_3_l5_steps":
            new_stepsets.append(insert_b_3_l6)
            insert_b_3_l6 = None

    # Insert new stepsets that we might have missed (e.g. when we replaced by draft)
    # We already appended draft steps; so when we had course_b_1_l4_steps we replaced with draft and then need to insert l5 after it.
    # Redo: after each "course_b_1_l4_steps" (draft) add course_b_1_l5_steps if not present.
    final = []
    for i, ss in enumerate(new_stepsets):
        final.append(ss)
        sid = ss.get("id", "")
        if sid == "course_b_1_l4_steps" and draft.get("course_b_1_l5_steps"):
            # Next should be l5 or l6; if next is l6, insert l5
            next_id = new_stepsets[i + 1].get("id", "") if i + 1 < len(new_stepsets) else ""
            if next_id != "course_b_1_l5_steps":
                final.append(draft["course_b_1_l5_steps"])
        elif sid == "course_b_2_l5_steps" and draft.get("course_b_2_l6_steps"):
            next_id = new_stepsets[i + 1].get("id", "") if i + 1 < len(new_stepsets) else ""
            if next_id != "course_b_2_l6_steps":
                final.append(draft["course_b_2_l6_steps"])
        elif sid == "course_b_3_l5_steps" and draft.get("course_b_3_l6_steps"):
            next_id = new_stepsets[i + 1].get("id", "") if i + 1 < len(new_stepsets) else ""
            if next_id != "course_b_3_l6_steps":
                final.append(draft["course_b_3_l6_steps"])

    app["stepsets"] = final
    with open(STEPS_PATH, "w", encoding="utf-8") as f:
        json.dump(app, f, ensure_ascii=False, indent=2)
    print("Merged steps.json: replaced b_1/b_2/b_3 steps from lessons.json, added b_1_l5, b_2_l6, b_3_l6.")


if __name__ == "__main__":
    main()
