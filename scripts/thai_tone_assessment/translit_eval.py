"""
Сверка движка букв (thai_translit) с карточками курса.

    python3 translit_eval.py            # сводка + частые расхождения
    python3 translit_eval.py --dump x   # все расхождения в JSON

Курс сам пишет один слог по-разному (งาน: нган/нгаан, จะ: ча/джа), поэтому считаем
две метрики: точное совпадение и совпадение после стилевой нормализации
(долгота, тх/т, ч/дж/чх), которая не меняет чтение.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent))

import thai_translit as tl  # noqa: E402
import api  # noqa: E402

ARROWS = "→↓↘↑↗"


def style_norm(s: str) -> str:
    s = s.lower().replace("ё", "е")
    s = s.replace("я", "йа").replace("ю", "йу")
    s = s.replace("тх", "т").replace("пх", "п").replace("кх", "к").replace("чх", "ч").replace("дж", "ч")
    s = s.replace("э", "е").replace("г", "к").replace("ао", "ау")
    s = re.sub(r"^й(?=[еи])", "", s)
    s = re.sub(r"([аеиоуы])\1+", r"\1", s)
    return s


def course_pairs() -> list[tuple[str, str]]:
    d = json.loads((HERE.parent.parent / "steps.json").read_text(encoding="utf-8"))
    pairs = set()
    for ss in d["stepsets"]:
        for it in ss.get("items", []):
            th = (it.get("thai") or "").strip()
            ph = (it.get("phonetic") or "").strip()
            if th and ph and "/" not in th and not re.search(r"[A-Za-z0-9]", th):
                pairs.add((th, ph))
    return sorted(pairs)


def engine_syllables(thai: str) -> list[str] | None:
    out: list[str] = []
    for chunk in thai.split():
        for w in api._thai_word_tokens(chunk):
            w = "".join(api._THAI_SCRIPT_RE.findall(w))
            if not w:
                continue
            if w == "ๆ" and out:
                out.append(out[-1])
                continue
            letters = tl.word_letters(w)
            if letters is None:
                return None
            out.extend(letters)
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dump")
    args = ap.parse_args()
    total = exact = styled = 0
    count_mismatch = failed = 0
    diffs: Counter[tuple[str, str]] = Counter()
    examples: dict[tuple[str, str], str] = {}
    for th, ph in course_pairs():
        course = [c.strip(ARROWS).lower() for c in re.split(r"[\s\-·]+", ph) if c.strip(ARROWS)]
        eng = engine_syllables(th)
        if eng is None:
            failed += 1
            continue
        if len(eng) != len(course):
            count_mismatch += 1
            continue
        for a, b in zip(eng, course):
            total += 1
            if a == b:
                exact += 1
                styled += 1
            elif style_norm(a) == style_norm(b):
                styled += 1
            else:
                diffs[(a, b)] += 1
                examples.setdefault((a, b), th)
    print(f"cards: {len(course_pairs())}, engine failed: {failed}, syllable count differs: {count_mismatch}")
    print(f"syllables compared: {total}")
    print(f"exact: {exact / total:.1%}  same reading (style-normalized): {styled / total:.1%}")
    for (a, b), n in diffs.most_common(60):
        print(f"{n:4} engine={a!r:12} course={b!r:12} {examples[(a, b)]}")
    if args.dump:
        Path(args.dump).write_text(
            json.dumps(
                [{"engine": a, "course": b, "n": n, "thai": examples[(a, b)]} for (a, b), n in diffs.most_common()],
                ensure_ascii=False,
                indent=1,
            ),
            encoding="utf-8",
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
