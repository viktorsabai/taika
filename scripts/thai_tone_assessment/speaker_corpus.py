"""
Прогон Smart Speaker по корпусу живых фраз с авто-проверками.

    python3 speaker_corpus.py                      # прод, сохраняет speaker_corpus_<ts>.json
    python3 speaker_corpus.py --url http://127.0.0.1:8000
    python3 speaker_corpus.py --report saved.json  # пересчитать проверки по сохранённому прогону

Проверки (всё детерминированно, без модели):
- numbers   — каждое число пользователя есть в тайском словами;
- tones     — стрелка каждого слога совпадает с тоном по тайскому написанию;
- syllables — слоги фонетики сопоставимы с тайским 1:1 (иначе тон не проверить);
- particle  — женский вопрос заканчивается на คะ, мужская частица ครับ↑;
- gloss     — у каждого слова фонетики есть непустое значение.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import requests

import speaker_quality as q

PROD = "https://taika-production.up.railway.app"

CORPUS: list[tuple[str, str, str]] = [
    # (категория, фраза, politeness)
    ("numbers", "я живу тут 4 года", "female"),
    ("numbers", "я живу тут четыре года", "male"),
    ("numbers", "сколько стоит 250 бат", "female"),
    ("numbers", "дайте 2 кофе и 1 воду", "male"),
    ("numbers", "мне 35 лет", "female"),
    ("numbers", "у меня 3 детей", "male"),
    ("numbers", "нас будет 12 человек", "female"),
    ("numbers", "это стоит 1500 бат", "male"),
    ("numbers", "позвони мне 0812345678", "female"),
    ("numbers", "комната 305", "male"),
    ("numbers", "я ждал 20 минут", "male"),
    ("numbers", "скидка 10 процентов", "female"),
    ("numbers", "мы тут на 7 дней", "female"),
    ("numbers", "встретимся в 8 вечера", "female"),
    ("question_f", "где туалет?", "female"),
    ("question_f", "сколько это стоит?", "female"),
    ("question_f", "ты говоришь по-английски?", "female"),
    ("question_f", "можно счёт?", "female"),
    ("question_f", "это острое?", "female"),
    ("question_f", "как тебя зовут", "female"),
    ("question_m", "где ближайшая аптека?", "male"),
    ("question_m", "у вас есть свободный номер?", "male"),
    ("negation", "я не ем мясо", "female"),
    ("negation", "не надо сахар", "male"),
    ("negation", "я не понимаю по-тайски", "female"),
    ("everyday", "мне очень нравится тайская еда", "female"),
    ("everyday", "я хочу пить", "male"),
    ("everyday", "отвезите меня в аэропорт", "female"),
    ("everyday", "я ищу свой отель", "male"),
    ("everyday", "завтра будет дождь", "female"),
    ("everyday", "у меня болит голова", "female"),
    ("everyday", "я вегетарианец", "male"),
    ("everyday", "сделайте не очень остро", "female"),
    ("names", "меня зовут Анна", "female"),
    ("names", "я из России", "male"),
    ("names", "мы живём на Пхукете", "female"),
    ("names", "где ближайший 7-Eleven", "male"),
    ("long", "я приехал в Таиланд в отпуск со своей семьёй на две недели", "male"),
    ("long", "извините, вы не подскажете, как дойти до рынка", "female"),
    ("long", "мне нужно поменять деньги, где здесь обменник", "female"),
    ("names", "меня зовут Анна, я из России", "female"),
    ("names", "скидка 10 процентов в 7-Eleven", "male"),
]


def _arrows(s: str) -> list[str]:
    return [ch for ch in s or "" if ch in q.ARROWS]


def check(ru: str, politeness: str, resp: dict) -> dict:
    thai = (resp.get("thai") or "").strip()
    ph = (resp.get("phonetic") or "").strip()
    parts = resp.get("parts") or []
    out: dict = {"issues": []}
    if not thai or not ph:
        out["issues"].append("empty")
        return out
    nums = q.number_problems(ru, thai)
    if nums:
        out["issues"].append("numbers")
        out["numbers"] = nums
    import api  # noqa: PLC0415 — пословная сверка та же, что на сервере

    expected, _, verifiable, engine_read = api._final_reading(thai, ph)
    got = _arrows(ph)
    out["syllables_total"] = len(got)
    got_letters = [api._strip_arrows(s) for s in q.syllable_chunks(ph)]
    want_letters = [api._strip_arrows(s) for s in q.syllable_chunks(expected)]
    letter_bad = sum(1 for a, b in zip(got_letters, want_letters) if a != b) + abs(
        len(got_letters) - len(want_letters)
    )
    out["letter_errors"] = letter_bad
    if letter_bad or not engine_read:
        out["issues"].append("letters")
        out["letters_expected"] = expected
    if not verifiable:
        out["issues"].append("syllables")
        out["tone_unverifiable"] = True
    else:
        want = _arrows(expected)
        bad = sum(1 for a, b in zip(got, want) if a != b) + abs(len(got) - len(want))
        out["tone_errors"] = bad
        if bad:
            out["issues"].append("tones")
            out["tone_expected"] = expected
    question = q.is_question(ru, thai)
    bare = re.sub(r"\s+", "", thai)
    if politeness == "male":
        if not bare.endswith("ครับ") or not ph.endswith("кхрап↑"):
            out["issues"].append("particle")
    elif question:
        if not bare.endswith("คะ") or bare.endswith("ค่ะ") or not ph.endswith("кха↑"):
            out["issues"].append("particle")
    elif not bare.endswith("ค่ะ") or not ph.endswith("кха↘"):
        out["issues"].append("particle")
    groups = [g for g in ph.split(" ") if g]
    if len(parts) != len(groups) or any(not (p.get("m") or "").strip() for p in parts):
        out["issues"].append("gloss")
    return out


def _call(url: str, ru: str, politeness: str) -> dict:
    t0 = time.monotonic()
    try:
        r = requests.post(
            f"{url}/smart_speaker", json={"text_ru": ru, "politeness": politeness}, timeout=60
        )
        body = r.json() if r.headers.get("content-type", "").startswith("application/json") else {}
        return {"status": r.status_code, "resp": body, "seconds": round(time.monotonic() - t0, 1)}
    except Exception as e:  # noqa: BLE001
        return {"status": 0, "resp": {}, "error": str(e), "seconds": round(time.monotonic() - t0, 1)}


def summarize(rows: list[dict]) -> dict:
    n = len(rows)
    by_issue: dict[str, int] = {}
    tone_err = syl_total = letter_err = 0
    for r in rows:
        for i in r["check"]["issues"]:
            by_issue[i] = by_issue.get(i, 0) + 1
        tone_err += r["check"].get("tone_errors", 0)
        letter_err += r["check"].get("letter_errors", 0)
        syl_total += r["check"].get("syllables_total", 0)
    clean = sum(1 for r in rows if not r["check"]["issues"])
    return {
        "phrases": n,
        "clean_phrases": clean,
        "issues": dict(sorted(by_issue.items())),
        "tone_errors_syllables": f"{tone_err}/{syl_total}",
        "letter_diff_vs_engine_syllables": f"{letter_err}/{syl_total}",
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--url", default=PROD)
    ap.add_argument("--report", help="пересчитать проверки по сохранённому JSON")
    ap.add_argument("--out")
    args = ap.parse_args()

    if args.report:
        rows = json.loads(Path(args.report).read_text(encoding="utf-8"))["rows"]
    else:
        with ThreadPoolExecutor(max_workers=6) as pool:
            calls = list(pool.map(lambda c: _call(args.url, c[1], c[2]), CORPUS))
        rows = [
            {"category": c[0], "ru": c[1], "politeness": c[2], **res}
            for c, res in zip(CORPUS, calls)
        ]
    for r in rows:
        r["check"] = check(r["ru"], r["politeness"], r.get("resp") or {})
    summary = summarize(rows)
    for r in rows:
        issues = ",".join(r["check"]["issues"]) or "ok"
        resp = r.get("resp") or {}
        print(f"[{issues:>22}] {r['ru']!r} → {resp.get('thai')!r} | {resp.get('phonetic')!r}")
        if r["check"].get("tone_expected"):
            print(f"{'':>25}rule: {r['check']['tone_expected']!r}")
        if r["check"].get("letters_expected"):
            print(f"{'':>25}engine: {r['check']['letters_expected']!r}")
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    if not args.report:
        out = Path(args.out or f"speaker_corpus_{time.strftime('%Y%m%d-%H%M%S')}.json")
        out.write_text(
            json.dumps({"url": args.url, "summary": summary, "rows": rows}, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        print(f"saved {out}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
