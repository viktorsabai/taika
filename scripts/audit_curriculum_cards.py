#!/usr/bin/env python3
"""Read-only curriculum quality gate for learnable cards."""

from __future__ import annotations

import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STEPS = ROOT / "steps.json"
CANON = ROOT / "docs" / "curriculum_lemma_canon.json"

LEARNABLE = {"word", "phrase", "casual"}


def norm_th(s: str) -> str:
    return re.sub(r"\s+", "", (s or "").strip())


def norm_ru(s: str) -> str:
    s = (s or "").strip().lower().replace("ё", "е")
    return re.sub(r"\s+", " ", re.sub(r"[^\wа-я]+", " ", s, flags=re.I)).strip()


def main() -> int:
    steps = json.loads(STEPS.read_text(encoding="utf-8"))
    canon_doc = json.loads(CANON.read_text(encoding="utf-8")) if CANON.exists() else {}
    ph_canon = canon_doc.get("phonetic_canon") or {}
    allow = set(canon_doc.get("phonetic_allow_multi") or [])
    gloss = canon_doc.get("gloss_canon") or {}

    rows = []
    empty = []
    for ss in steps["stepsets"]:
        for it in ss.get("items") or []:
            if it.get("kind") not in LEARNABLE:
                continue
            r = {
                "course": ss.get("course_id"),
                "lesson": ss.get("lesson_id"),
                "ru": it.get("ru") or "",
                "th": it.get("thai") or "",
                "ph": it.get("phonetic") or "",
            }
            rows.append(r)
            if not r["ru"] or not r["th"] or not r["ph"]:
                empty.append(r)

    by_th = defaultdict(list)
    for r in rows:
        if r["th"]:
            by_th[norm_th(r["th"])].append(r)

    ph_conflicts = []
    for th, vs in by_th.items():
        if th in allow:
            continue
        phs = sorted({x["ph"] for x in vs})
        if len(phs) > 1:
            ph_conflicts.append((th, phs))

    canon_miss = []
    for th, want in ph_canon.items():
        for r in by_th.get(th, []):
            if r["ph"] != want:
                canon_miss.append((r["lesson"], th, r["ph"], want))

    within = []
    by_les = defaultdict(list)
    for r in rows:
        by_les[r["lesson"]].append(r)
    for lid, grp in by_les.items():
        cnt = Counter(norm_th(x["th"]) for x in grp if x["th"])
        dups = [t for t, n in cnt.items() if n > 1]
        if lid == "course_b_2_l4":
            dups = [t for t in dups if t != "สบายดีไหม" or cnt[t] > 2]
        if dups:
            within.append((lid, dups))

    gloss_bad = []
    ok_map = {
        "ขอบคุณ": {"спасибо"},
        "ขอบคุณครับ": {"спасибо", "спасибо вежливо"},
        "ขอบคุณค่ะ": {"спасибо", "спасибо вежливо"},
        "ลาก่อน": {"до свидания"},
        "ลาก่อนครับ": {"до свидания", "до свидания вежливо"},
    }
    for th, canon_ru in gloss.items():
        for r in by_th.get(th, []):
            if norm_ru(r["ru"]) not in ok_map.get(th, {norm_ru(canon_ru)}):
                gloss_bad.append((r["lesson"], th, r["ru"]))

    # known semantic smoke checks
    smoke = []
    for r in rows:
        if r["th"] == "น้ำ" and norm_ru(r["ru"]) == "сок":
            smoke.append(("water_as_juice", r))
        if r["th"] == "ร่ม" and norm_ru(r["ru"]) == "тень":
            smoke.append(("umbrella_as_shade", r))
        if r["th"] == "หนวด" and "бород" in r["ru"].lower():
            smoke.append(("mustache_as_beard", r))
        if r["th"] == "สระผม" and "массаж" in r["ru"].lower():
            smoke.append(("wash_as_massage", r))

    print("learnable_cards", len(rows))
    print("unique_thai", len(by_th))
    print("empty_fields", len(empty))
    print("phonetic_conflicts", len(ph_conflicts))
    print("canon_mismatches", len(canon_miss))
    print("within_lesson_thai_dups", len(within))
    print("gloss_inflation", len(gloss_bad))
    print("semantic_smoke", len(smoke))

    bad = ph_conflicts or canon_miss or within or gloss_bad or smoke or empty
    if bad:
        for label, data in [
            ("ph_conflicts", ph_conflicts[:10]),
            ("canon_miss", canon_miss[:10]),
            ("within", within[:10]),
            ("gloss_bad", gloss_bad[:10]),
            ("smoke", smoke[:10]),
            ("empty", empty[:10]),
        ]:
            if data:
                print(f"\n{label}:")
                for row in data:
                    print(" ", row)
        return 1
    print("\nOK — curriculum card gate passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
