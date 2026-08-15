#!/usr/bin/env python3
"""
Iteration 1 — curriculum quality to 10/10 (cards layer).

Phase A: lemma phonetic canon + audit helpers
Phase B: P0 correctness, phonetic unify, gloss canon
Phase C (partial): within-lesson Thai duplicates (translit pairs)

Re-runnable / idempotent where possible.
"""

from __future__ import annotations

import json
import re
from collections import Counter, defaultdict
from copy import deepcopy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LESSONS_PATH = ROOT / "lessons.json"
STEPS_PATH = ROOT / "steps.json"
CANON_PATH = ROOT / "docs" / "curriculum_lemma_canon.json"
REPORT_PATH = ROOT / "docs" / "curriculum_iteration1_report.md"

LEARNABLE = {"word", "phrase", "casual"}


def norm_th(s: str) -> str:
    return re.sub(r"\s+", "", (s or "").strip())


def norm_ru(s: str) -> str:
    s = (s or "").strip().lower().replace("ё", "е")
    s = re.sub(r"[^\wа-я]+", " ", s, flags=re.I)
    return re.sub(r"\s+", " ", s).strip()


def renumber(items: list) -> list:
    out = []
    for i, it in enumerate(items, 1):
        n = deepcopy(it)
        n["order"] = i
        out.append(n)
    return out


def learnable_count(items: list) -> int:
    return sum(1 for it in items if it.get("kind") in LEARNABLE)


# ---------------------------------------------------------------------------
# Phase A — phonetic canon (majority + known corrections)
# ---------------------------------------------------------------------------

# Explicit overrides beat majority vote (pedagogy / accuracy).
PHONETIC_CANON: dict[str, str] = {
    "เจ็ด": "джет↘",
    "เงินสด": "нгён→ сот↘",
    "นี่ครับ": "ни→ кхрап↘",
    "บัตร": "бат→",
    "ไม่กดดัน": "май→ кот→ дан↘",
    "ช่วยหน่อย": "чуай→ ной→",
    "เผ็ดน้อย": "пхет→ ной→",
    "ราคา": "ра→ кха→",
    "แพงไป": "пхэнг→ пай→",
    "ถุง": "тхунг→",
    "ข้าวผัด": "кхау→ пхат↘",
    "โรงพยาบาล": "ронг→ пха→ я→ бан→",
    "พรุ่งนี้": "пхрунг→ ни↘",
    "ช่วย": "чуай↗",
    "เร็ว": "рыу→",
    "ช้า": "ча↗",
    "แล้วเจอกัน": "лэу→ джё→ кан→",
    "นี่พาสปอร์ต": "ни→ пас→ порт→",
    "ไปโรงแรม": "пай→ ронг→ рэм→",
    "สั่ง": "санг→",
    "ฟิตเนส": "фит→ нес→",
    "เรียบร้อย": "риап→ рой→",
    "จีบ": "джип→",
    "ยินดีที่ได้รู้จัก": "йин→ ди↗ ти→ дай→ ру→ джак↘",
    "เข้าใจครับ": "кхао→ джай→ кхрап↘",
    "ยินดี": "йин→ ди↗",
    "ตลก": "тхолок→",
    "กี่โมง": "ги→ монг↗",
    "เลี้ยวซ้าย": "лиао→ сай↘",
    "เลี้ยวขวา": "лиао→ кхва↗",
    "ไม่อยาก": "май↘ яак↘",
    "สุขสันต์วันสงกรานต์": "сук→ сан→ ван→ сонг→ кран↘",
    "อยู่กับเธอแล้วสบายใจ": "ю→ кап→ тхё→ леу→ сабай→ джай↘",
}

# Intentional multi-phonetic (do not force one form).
PHONETIC_ALLOW_MULTI = {
    "สบายดีไหม",  # slow vs native in b_2
}

# Gloss canon: thai → (ru, optional tip_suffix if scene was in old ru)
GLOSS_CANON: dict[str, str] = {
    "ขอบคุณ": "Спасибо",
    "ขอบคุณครับ": "Спасибо",
    "ขอบคุณค่ะ": "Спасибо",
    "ลาก่อน": "До свидания",
    "ลาก่อนครับ": "До свидания",
}

# RU forms that are fine for ขอบคุณ / don't rewrite if already canon-ish
GLOSS_OK = {
    "ขอบคุณ": {"спасибо"},
    "ขอบคุณครับ": {"спасибо", "спасибо вежливо"},
    "ลาก่อน": {"до свидания"},
    "ลาก่อนครับ": {"до свидания", "до свидания вежливо"},
}


def build_majority_canon(steps_doc: dict) -> dict[str, str]:
    by_th: dict[str, Counter] = defaultdict(Counter)
    for ss in steps_doc["stepsets"]:
        for it in ss.get("items", []):
            if it.get("kind") not in LEARNABLE:
                continue
            th = norm_th(it.get("thai") or "")
            ph = (it.get("phonetic") or "").strip()
            if th and ph:
                by_th[th][ph] += 1
    out = {}
    for th, cnt in by_th.items():
        if th in PHONETIC_ALLOW_MULTI:
            continue
        if len(cnt) > 1:
            out[th] = cnt.most_common(1)[0][0]
    # explicit overrides
    out.update(PHONETIC_CANON)
    return out


# ---------------------------------------------------------------------------
# Phase B — semantic P0 patches (lesson-scoped)
# ---------------------------------------------------------------------------

def patch_semantic(steps_doc: dict, log: list[str]) -> None:
    for ss in steps_doc["stepsets"]:
        lid = ss.get("lesson_id") or ""
        items = ss.get("items") or []
        changed = False

        # l_7: น้ำ labeled «Сок» → Вода
        if lid == "course_l_7_l3":
            for it in items:
                if it.get("thai") == "น้ำ" and norm_ru(it.get("ru") or "") == "сок":
                    it["ru"] = "Вода"
                    it["tip"] = "น้ำ = вода. Сок — น้ำผลไม้ / уточни фрукт."
                    changed = True
                    log.append("P0: l_7 «Сок»/น้ำ → «Вода»")

        # l_7: drop «Тень» duplicate of ร่ม (keep Зонт; shade already ที่ร่ม)
        if lid == "course_l_7_l1":
            before = len(items)
            items = [it for it in items if not (
                it.get("kind") in LEARNABLE
                and it.get("thai") == "ร่ม"
                and norm_ru(it.get("ru") or "") == "тень"
            )]
            if len(items) != before:
                changed = True
                log.append("P0: l_7 drop «Тень»/ร่ม (оставить Зонт; тень = ที่ร่ม)")

        # l_12: drop wrong «Борода»/หนวด if «Усы» already present; else rename
        if lid.startswith("course_l_12"):
            has_usy = any(
                it.get("thai") == "หนวด" and "ус" in (it.get("ru") or "").lower()
                for it in items if it.get("kind") in LEARNABLE
            )
            before = len(items)
            if has_usy:
                items = [it for it in items if not (
                    it.get("kind") in LEARNABLE
                    and it.get("thai") == "หนวด"
                    and "бород" in (it.get("ru") or "").lower()
                )]
            else:
                for it in items:
                    if it.get("thai") == "หนวด" and "бород" in (it.get("ru") or "").lower():
                        it["ru"] = "Усы"
                        it["tip"] = "หนวด = усы. Борода — เครา."
            if len(items) != before or any(
                (it.get("tip") or "").startswith("หนวด = усы") for it in items
            ):
                changed = True
                log.append(f"P0: {lid} หนวด — убрать «Борода» / оставить «Усы»")

        # l_12: drop «Массаж головы» if same Thai as мытьё
        if lid.startswith("course_l_12"):
            has_wash = any(
                it.get("thai") == "สระผม" and "мыть" in (it.get("ru") or "").lower()
                for it in items if it.get("kind") in LEARNABLE
            )
            if has_wash:
                before = len(items)
                items = [it for it in items if not (
                    it.get("kind") in LEARNABLE
                    and it.get("thai") == "สระผม"
                    and "массаж" in (it.get("ru") or "").lower()
                )]
                if len(items) != before:
                    changed = True
                    log.append(f"P0: {lid} drop «Массаж головы»/สระผม (это мытьё)")

        # l_10: абонемент
        if lid.startswith("course_l_10"):
            for it in items:
                ru = (it.get("ru") or "").lower()
                if it.get("thai") == "บัตร" and "абонемент" in ru:
                    it["ru"] = "Членская карта"
                    it["thai"] = "บัตรสมาชิก"
                    it["phonetic"] = "бат→ са→ ма→ чик↘"
                    it["tip"] = "Абонемент в зал = บัตรสมาชิก."
                    changed = True
                    log.append(f"P0: {lid} บัตร/абонемент → บัตรสมาชิก")
                elif it.get("thai") == "ซื้อบัตร" and "абонемент" in ru:
                    it["ru"] = "Купить карту"
                    it["thai"] = "ซื้อบัตรสมาชิก"
                    it["phonetic"] = "сы→ бат→ са→ ма→ чик↘"
                    it["tip"] = "Купить абонемент в зал."
                    changed = True
                    log.append(f"P0: {lid} ซื้อบัตร → ซื้อบัตรสมาชิก")

        # e_5: within-lesson concept cards — keep translit as word, drop pure RU twin if identical thai
        # handled in phase C generally

        if changed:
            ss["items"] = renumber(items)
        else:
            ss["items"] = items


def apply_phonetic_canon(steps_doc: dict, canon: dict[str, str], log: list[str]) -> int:
    n = 0
    for ss in steps_doc["stepsets"]:
        for it in ss.get("items", []):
            if it.get("kind") not in LEARNABLE:
                continue
            th = norm_th(it.get("thai") or "")
            if not th or th in PHONETIC_ALLOW_MULTI:
                continue
            want = canon.get(th)
            if want and (it.get("phonetic") or "") != want:
                it["phonetic"] = want
                n += 1
    log.append(f"P0/B: phonetic canon applied to {n} cards")
    return n


def apply_gloss_canon(steps_doc: dict, log: list[str]) -> int:
    n = 0
    for ss in steps_doc["stepsets"]:
        for it in ss.get("items", []):
            if it.get("kind") not in LEARNABLE:
                continue
            th = norm_th(it.get("thai") or "")
            if th not in GLOSS_CANON:
                continue
            ru = it.get("ru") or ""
            ok = GLOSS_OK.get(th, set())
            if norm_ru(ru) in ok:
                continue
            # scene was encoded in RU — park into tip
            old = ru.strip()
            canon_ru = GLOSS_CANON[th]
            if th.endswith("ครับ") or th.endswith("ค่ะ"):
                # polite particle already in Thai
                pass
            tip = (it.get("tip") or "").strip()
            scene = f"В сцене: «{old}»."
            if old and old != canon_ru:
                it["ru"] = canon_ru
                if scene not in tip:
                    it["tip"] = f"{tip} {scene}".strip() if tip else scene
                n += 1
    log.append(f"P0/B: gloss canon on สวัสดี-family thanks/bye: {n} cards")
    return n


# ---------------------------------------------------------------------------
# Phase C — within-lesson duplicate Thai (keep best RU)
# ---------------------------------------------------------------------------

TRANSLIT_HEAVY = re.compile(
    r"^[a-zа-яё0-9\s\-\']+$",
    re.I,
)


def looks_like_translit_label(ru: str) -> bool:
    """Heuristic: mostly Latin/translit token without normal Russian gloss words."""
    s = (ru or "").strip()
    if not s:
        return False
    # known translit-only titles in curriculum
    low = s.lower()
    markers = (
        "май", "лэн", "нонг", "пхи", "кхау", "пад", "джинг", "раванг",
        "кэнг", "луук", "сабай", "крэнг", "джай", "555",
    )
    # if RU is just the phonetic-ish name duplicated
    cyr_words = re.findall(r"[а-яё]+", low, flags=re.I)
    # pure transliteration cards often short and match thai reading
    if len(s) <= 24 and any(m in low for m in markers) and not any(
        w in low for w in ("пожалуйста", "сколько", "можно", "где", "как", "спасибо", "болит", "игра", "осторож", "младш", "старш", "хорош", "серьёз", "ребён", "мыть", "жарен")
    ):
        # e.g. «Лэн май», «Кхау пад», «Нонг»
        if " " in s or len(s) <= 12:
            return True
    return False


def prefer_keep(a: dict, b: dict) -> dict:
    """Prefer clearer Russian gloss over translit twin."""
    ra, rb = a.get("ru") or "", b.get("ru") or ""
    ta, tb = looks_like_translit_label(ra), looks_like_translit_label(rb)
    if ta and not tb:
        return b
    if tb and not ta:
        return a
    # prefer longer descriptive RU
    if len(rb) > len(ra) + 2:
        return b
    return a


def drop_within_lesson_thai_dups(steps_doc: dict, log: list[str]) -> int:
    removed = 0
    for ss in steps_doc["stepsets"]:
        items = ss.get("items") or []
        learn = [(i, it) for i, it in enumerate(items) if it.get("kind") in LEARNABLE]
        by_th: dict[str, list] = defaultdict(list)
        for i, it in learn:
            th = norm_th(it.get("thai") or "")
            if th:
                by_th[th].append((i, it))

        drop_idx = set()
        for th, group in by_th.items():
            if len(group) < 2:
                continue
            # intentional pedagogical pair in b_2 fast speech
            if th == "สบายดีไหม" and (ss.get("lesson_id") or "").startswith("course_b_2"):
                continue
            # cultural code lessons: translit name + gloss is intentional
            cid = ss.get("course_id") or ""
            if cid in ("course_e_5", "course_s_3") and looks_like_translit_label(
                next((it.get("ru") or "" for _, it in group), "")
            ):
                # only drop if BOTH are translit OR both are full glosses with same thai
                translit_n = sum(1 for _, it in group if looks_like_translit_label(it.get("ru") or ""))
                if translit_n == 1 and len(group) == 2:
                    continue
            # score each candidate: prefer non-translit, then longer RU
            def score(it: dict) -> tuple:
                ru = it.get("ru") or ""
                return (0 if looks_like_translit_label(ru) else 1, len(ru), -(it.get("order") or 0))

            keep_i, _ = max(group, key=lambda pair: score(pair[1]))
            for i, _it in group:
                if i != keep_i:
                    drop_idx.add(i)

        if drop_idx:
            lid = ss.get("lesson_id")
            new_items = [it for i, it in enumerate(items) if i not in drop_idx]
            tip_txt = "Один Thai — одна карточка: транслит не дублируем отдельной карточкой."
            tips = [it.get("text") for it in new_items if it.get("kind") == "tip"]
            if tip_txt not in tips:
                new_items.append({"order": 0, "kind": "tip", "text": tip_txt})
            ss["items"] = renumber(new_items)
            removed += len(drop_idx)
            log.append(f"C: {lid} removed {len(drop_idx)} within-lesson Thai dup card(s)")
    log.append(f"C: total within-lesson cards removed: {removed}")
    return removed


def sync_card_counts(lessons_doc: dict, steps_doc: dict) -> None:
    by_lesson = {s["lesson_id"]: s for s in steps_doc["stepsets"]}
    for c in lessons_doc["courses"]:
        for les in c.get("lessons") or []:
            ss = by_lesson.get(les["lesson_id"])
            if ss:
                les["card_count"] = learnable_count(ss["items"])
        mins = sum(int(les.get("duration_minutes") or 0) for les in c.get("lessons") or [])
        c["summary"] = {
            "total_lessons": len(c.get("lessons") or []),
            "total_duration_minutes": mins,
        }


def audit_metrics(steps_doc: dict) -> dict:
    rows = []
    for ss in steps_doc["stepsets"]:
        for it in ss.get("items", []):
            if it.get("kind") not in LEARNABLE:
                continue
            rows.append({
                "course": ss.get("course_id"),
                "lesson": ss.get("lesson_id"),
                "ru": it.get("ru") or "",
                "th": it.get("thai") or "",
                "ph": it.get("phonetic") or "",
            })

    by_th: dict[str, list] = defaultdict(list)
    for r in rows:
        th = norm_th(r["th"])
        if th:
            by_th[th].append(r)

    ph_conflict = 0
    for th, vs in by_th.items():
        if th in PHONETIC_ALLOW_MULTI:
            continue
        phs = {(x["ph"] or "") for x in vs}
        if len(phs) > 1:
            ph_conflict += 1

    within = 0
    by_les: dict[str, list] = defaultdict(list)
    for r in rows:
        by_les[r["lesson"]].append(r)
    for lid, grp in by_les.items():
        cnt = Counter(norm_th(x["th"]) for x in grp if x["th"])
        if any(n > 1 for n in cnt.values()):
            # allow b_2 สบายดีไหม
            if lid == "course_b_2_l4":
                rest = {t: n for t, n in cnt.items() if not (t == "สบายดีไหม" and n == 2)}
                if any(n > 1 for n in rest.values()) or cnt.get("สบายดีไหม", 0) > 2:
                    within += 1
            else:
                within += 1

    gloss_bad = 0
    for th, canon_ru in GLOSS_CANON.items():
        for r in by_th.get(th, []):
            if norm_ru(r["ru"]) not in GLOSS_OK.get(th, {norm_ru(canon_ru)}):
                gloss_bad += 1

    return {
        "learnable_cards": len(rows),
        "unique_thai": len(by_th),
        "phonetic_conflicts": ph_conflict,
        "lessons_with_within_thai_dup": within,
        "gloss_inflation_remaining": gloss_bad,
    }


def write_report(log: list[str], before: dict, after: dict, canon: dict) -> None:
    lines = [
        "# Curriculum iteration 1 — cards quality",
        "",
        "Phases A–C (partial): canon, P0 correctness, phonetics, gloss, within-lesson dups.",
        "",
        "## Metrics",
        "",
        "| Metric | Before | After |",
        "|---|---:|---:|",
        f"| Learnable cards | {before['learnable_cards']} | {after['learnable_cards']} |",
        f"| Unique Thai | {before['unique_thai']} | {after['unique_thai']} |",
        f"| Phonetic conflicts | {before['phonetic_conflicts']} | {after['phonetic_conflicts']} |",
        f"| Lessons with within-Thai dups | {before['lessons_with_within_thai_dup']} | {after['lessons_with_within_thai_dup']} |",
        f"| Gloss-inflation (thanks/bye) | {before['gloss_inflation_remaining']} | {after['gloss_inflation_remaining']} |",
        "",
        f"Phonetic canon entries: **{len(canon)}** → `{CANON_PATH.name}`",
        "",
        "## Changelog",
        "",
    ]
    for line in log:
        lines.append(f"- {line}")
    lines += [
        "",
        "## Next iteration",
        "",
        "- Phase C continued: cross-track course role splits (e_1/e_6, e_3↔l_6, s_2↔l_10, s_3↔long_7)",
        "- Phase D: intro/outline/apply for non-База lessons; review flags for scene finales",
        "- Phase E: tips pass",
        "",
    ]
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    lessons_doc = json.loads(LESSONS_PATH.read_text(encoding="utf-8"))
    steps_doc = json.loads(STEPS_PATH.read_text(encoding="utf-8"))

    before = audit_metrics(steps_doc)
    log: list[str] = []

    canon = build_majority_canon(steps_doc)
    # merge explicit
    canon.update(PHONETIC_CANON)
    CANON_PATH.parent.mkdir(parents=True, exist_ok=True)
    CANON_PATH.write_text(
        json.dumps(
            {
                "version": 1,
                "phonetic_canon": {k: canon[k] for k in sorted(canon.keys())},
                "gloss_canon": GLOSS_CANON,
                "phonetic_allow_multi": sorted(PHONETIC_ALLOW_MULTI),
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    log.append(f"A: wrote lemma canon ({len(canon)} phonetic entries)")

    patch_semantic(steps_doc, log)
    apply_phonetic_canon(steps_doc, canon, log)
    apply_gloss_canon(steps_doc, log)
    drop_within_lesson_thai_dups(steps_doc, log)
    sync_card_counts(lessons_doc, steps_doc)
    log.append("A/B/C: synced card_count for all courses")

    after = audit_metrics(steps_doc)
    write_report(log, before, after, canon)

    LESSONS_PATH.write_text(
        json.dumps(lessons_doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    STEPS_PATH.write_text(
        json.dumps(steps_doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    print("=== BEFORE ===")
    print(before)
    print("=== AFTER ===")
    print(after)
    print("=== LOG ===")
    for line in log:
        print(" ", line)


if __name__ == "__main__":
    main()
