#!/usr/bin/env python3
"""Repair production steps.json: Taika phonetic, no baked politeness particle, no agent boilerplate.

Syllable pronunciations are taken from cards that already follow the house style
(Cyrillic + arrows). Unknown syllables fall back to orthography-based generation.
ครับ/ค่ะ live on the speaker, not on the card — except particle-only teaching cards.
"""
from __future__ import annotations

import json
import re
import shutil
import sys
from collections import Counter
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from pythainlp.tokenize import syllable_tokenize  # noqa: E402
from thai_taika_phonetic import thai_to_taika  # noqa: E402

STEPS = ROOT / "steps.json"
ARROWS = set("→↓↘↑↗")
THAI_RE = re.compile(r"[\u0E00-\u0E7F]")
LATIN_RE = re.compile(r"[A-Za-z]")
COMB_RE = re.compile(r"[\u0300-\u036f]")
GENERIC = "Используй как короткую реплику"
POLITE_SLASH = re.compile(r"ครับ\s*/\s*ค่ะ|ครับ\s*/\s*คะ|ค่ะ\s*/\s*ครับ")
PH_PARTICLE = re.compile(r"^(кхрап|крап|кха)[→↓↘↑↗]?$", re.I)
PARTICLE_ONLY = {"ครับ", "ค่ะ", "คะ"}
CONTENT = {"word", "phrase", "casual"}


def is_good_ph(ph: str) -> bool:
    if not ph:
        return False
    if LATIN_RE.search(ph) or COMB_RE.search(ph) or THAI_RE.search(ph):
        return False
    if not any(a in ph for a in ARROWS):
        return False
    if "/" in ph:
        return False
    return True


def is_particle_card(th: str) -> bool:
    return re.sub(r"\s+", "", th or "") in PARTICLE_ONLY


def clean_thai(th: str) -> str:
    th = th or ""
    if is_particle_card(th):
        return re.sub(r"\s+", " ", th).strip()
    th = POLITE_SLASH.sub(" ", th)
    th = re.sub(r"ครับ|ค่ะ", " ", th)
    th = th.replace("ผม/ฉัน", "ผม").replace("ฉัน/ผม", "ผม")
    th = th.replace("ผม / ฉัน", "ผม")
    return re.sub(r"\s+", " ", th).strip()


def syllables(th: str) -> list[str]:
    return [
        s
        for s in syllable_tokenize(th, keep_whitespace=False)
        if THAI_RE.search(s) or LATIN_RE.search(s) or re.search(r"[0-9.]", s)
    ]


def build_lexicon(stepsets) -> dict[str, str]:
    pair: dict[str, Counter] = {}
    for ss in stepsets:
        for it in ss.get("items") or []:
            th = clean_thai(it.get("thai") or "")
            ph = (it.get("phonetic") or "").strip()
            if it.get("kind") not in CONTENT or not th or not is_good_ph(ph):
                continue
            syls = syllables(th)
            chunks = ph.split()
            if len(syls) != len(chunks):
                continue
            for s, c in zip(syls, chunks):
                pair.setdefault(s, Counter())[c] += 1
    return {s: cnt.most_common(1)[0][0] for s, cnt in pair.items()}


def rebuild_phonetic(th: str, lex: dict[str, str]) -> str:
    th = clean_thai(th)
    parts = []
    for s in syllables(th):
        if s in lex:
            parts.append(lex[s])
            continue
        gen = thai_to_taika(s).strip()
        parts.append(gen if gen else s)
    if not is_particle_card(th):
        parts = [p for p in parts if not PH_PARTICLE.match(p)]
    return " ".join(p for p in parts if p)


def needs_phonetic_repair(ph: str) -> bool:
    ph = ph or ""
    if not ph:
        return True
    if LATIN_RE.search(ph) or COMB_RE.search(ph) or THAI_RE.search(ph):
        return True
    if "/" in ph:
        return True
    if not any(a in ph for a in ARROWS):
        return True
    return False


def repair_tip(it: dict) -> bool:
    tip = (it.get("tip") or "").strip()
    if GENERIC not in tip:
        return False
    ru = (it.get("ru") or "").strip()
    if ru.endswith("?"):
        it["tip"] = "Короткий вопрос — без пояснений."
    else:
        it["tip"] = "Короткая реплика — без пояснений."
    return True


def main() -> int:
    backup = ROOT / f"steps.json.bak-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
    shutil.copy2(STEPS, backup)
    data = json.loads(STEPS.read_text(encoding="utf-8"))
    stepsets = data["stepsets"]
    lex = build_lexicon(stepsets)
    stats = Counter()
    stats["lexicon"] = len(lex)

    for ss in stepsets:
        for it in ss.get("items") or []:
            kind = it.get("kind")
            # mislabeled tip that is actually a word card
            if kind == "tip" and not (it.get("text") or "").strip() and (it.get("thai") or "").strip():
                it["kind"] = "word"
                kind = "word"
                stats["tip_to_word"] += 1

            if kind == "tip":
                continue
            if kind not in CONTENT:
                continue

            th0 = it.get("thai") or ""
            th = clean_thai(th0)
            if th != th0:
                it["thai"] = th
                stats["thai_politeness"] += 1

            ph0 = it.get("phonetic") or ""
            if needs_phonetic_repair(ph0) or POLITE_SLASH.search(th0) or "/" in ph0:
                new_ph = rebuild_phonetic(th, lex)
                if new_ph and new_ph != ph0:
                    it["phonetic"] = new_ph
                    stats["phonetic_rewritten"] += 1

            if repair_tip(it):
                stats["generic_tip"] += 1

    STEPS.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("backup", backup.name)
    print(dict(stats))
    return 0


if __name__ == "__main__":
    sys.exit(main())
