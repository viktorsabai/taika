#!/usr/bin/env python3
"""
Проверка наличия слова/фразы в steps.json перед добавлением (дедупликация).
Поиск по ru, thai, phonetic (подстрока, без учёта регистра для ru).

Примеры:
  python3 scripts/content_check_word_in_steps.py "хочу"
  python3 scripts/content_check_word_in_steps.py --ru "хочу"
  python3 scripts/content_check_word_in_steps.py --thai "อยาก"
  python3 scripts/content_check_word_in_steps.py --phonetic "яак"
"""
import argparse
import json
import os
import re

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STEPS_PATH = os.path.join(BASE, "steps.json")


def normalize_for_search(s: str) -> str:
    if not s:
        return ""
    return (s or "").strip().lower()


def main() -> int:
    ap = argparse.ArgumentParser(description="Search steps.json for word/phrase (dedup before add)")
    ap.add_argument("query", nargs="?", default=None, help="Search in ru, thai, phonetic")
    ap.add_argument("--ru", dest="ru", default=None, help="Search only in ru")
    ap.add_argument("--thai", dest="thai", default=None, help="Search only in thai")
    ap.add_argument("--phonetic", dest="phonetic", default=None, help="Search only in phonetic")
    args = ap.parse_args()

    if not os.path.isfile(STEPS_PATH):
        print(f"File not found: {STEPS_PATH}")
        return 1

    with open(STEPS_PATH, "r", encoding="utf-8") as f:
        data = json.load(f)

    # Build search targets
    search_ru = search_thai = search_phonetic = None
    if args.ru is not None:
        search_ru = normalize_for_search(args.ru)
    if args.thai is not None:
        search_thai = normalize_for_search(args.thai)
    if args.phonetic is not None:
        search_phonetic = normalize_for_search(args.phonetic)
    if args.query is not None and not (search_ru or search_thai or search_phonetic):
        q = normalize_for_search(args.query)
        search_ru = search_thai = search_phonetic = q

    if not (search_ru or search_thai or search_phonetic):
        print("Specify query or --ru / --thai / --phonetic")
        return 1

    def matches(ru: str, thai: str, phonetic: str) -> bool:
        nr = normalize_for_search(ru)
        nt = normalize_for_search(thai)
        np = normalize_for_search(phonetic)
        if search_ru and search_ru in nr:
            return True
        if search_thai and search_thai in nt:
            return True
        if search_phonetic and search_phonetic in np:
            return True
        return False

    hits = []
    for s in data.get("stepsets", []):
        cid = s.get("course_id", "")
        lid = s.get("lesson_id", "")
        for it in s.get("items", []):
            if it.get("kind") not in ("word", "phrase", "casual"):
                continue
            ru = (it.get("ru") or "").strip()
            thai = (it.get("thai") or "").strip()
            phonetic = (it.get("phonetic") or "").strip()
            if matches(ru, thai, phonetic):
                hits.append((cid, lid, ru, thai, phonetic))

    if not hits:
        print("No matches. Safe to add (no duplicate found).")
        return 0

    print(f"Found {len(hits)} match(es). Consider reusing or synonym to avoid duplicate.\n")
    for cid, lid, ru, thai, phonetic in hits[:50]:
        print(f"  {cid} / {lid}")
        print(f"    ru: {ru}")
        print(f"    thai: {thai}")
        print(f"    phonetic: {phonetic}")
        print()
    if len(hits) > 50:
        print(f"  ... and {len(hits) - 50} more.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
