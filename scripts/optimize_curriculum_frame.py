#!/usr/bin/env python3
"""Rename generator leftovers, rewrite lesson copy, sync counts. Does not move cards across courses."""
from __future__ import annotations

import json
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "taika/Resourses/taika_basa_course.json"
LESSONS = ROOT / "lessons.json"
STEPS = ROOT / "steps.json"
CONTENT = {"word", "phrase", "casual"}

TITLE_RENAME = {
    "Мини-диалог знакомства": "Представиться",
    "Мягкая сцена": "Мягкая просьба",
    "Small talk на работе": "Неформально на работе",
    "Рабочая сцена": "Рабочий разговор",
    "Уточнить смысл в сцене": "Уточнить смысл",
    "Small talk": "Короткий разговор",
    "Ночная сценка": "Ночной разговор",
    "Диалоги в баре": "В баре",
    "Сценка такси": "Вся поездка",
    "В аптеке диалог": "От симптома до инструкции",
    "В отеле сценка": "Весь визит в отель",
    "Доставка сценка": "Вся доставка",
    "На пляже сценка": "Весь пляж",
    "Магазин сценка": "Вся покупка",
    "Экстренный диалог": "Срочный вызов",
    "Зал сценка": "Весь зал",
    "Фестиваль сценка": "На празднике",
    "Салон сценка": "Весь салон",
    "Repair-сцена": "Договориться заново",
    "Сторис сценка": "Сторис целиком",
    "С тренером сценка": "С тренером",
    "Неформальное сценка": "Живой разговор",
    "Ретрит сценка": "На ретрите",
    "Романтика сценка": "Весь разговор",
    "Тай кидс сценка": "С детьми",
    "90-day report": "Отчёт 90 дней",
    "Иммиграция сценка": "Весь визит в иммиграцию",
    "Банк сценка": "Весь визит в банк",
    "Медицина сценка": "Весь визит к врачу",
    "Транспорт сценка": "Вся дорога",
    "Кондо сценка": "Весь дом",
    "Питомцы сценка": "Весь визит к ветеринару",
    "Юмор сценка": "Шутки и мемы",
    "Диалог с тренером": "С тренером в зале",
}

CARD_RU_RENAME = {
    "В аптеке диалог": "В аптеке",
    "Сторис сценка": "Сценарий сторис",
    "С тренером сценка": "С тренером",
    "Неформальное сценка": "Неформально",
    "Ретрит сценка": "На ретрите",
    "Внутренний сабай сценка": "Внутренний сабай",
    "Романтика сценка": "Романтика",
    "Тай кидс сценка": "С детьми",
    "От сленга к диалогу": "От сленга к разговору",
}

POLICE_APPEND = {
    "course_l_1_l1": [
        {"kind": "phrase", "ru": "Подождите", "thai": "รอหน่อย", "phonetic": "ро→ ной→", "tip": "Короткая пауза, без спора."},
        {"kind": "phrase", "ru": "Я турист", "thai": "เป็นนักท่องเที่ยว", "phonetic": "пен→ нак→ тхонг→ тхиао→", "tip": "Факт, без истории."},
        {"kind": "phrase", "ru": "Слушаю", "thai": "ฟังอยู่", "phonetic": "фан→ ю→", "tip": "Покажи, что слышишь инструкцию."},
    ],
    "course_l_1_l2": [
        {"kind": "phrase", "ru": "Это аренда", "thai": "นี่รถเช่า", "phonetic": "ни→ рот→ чау↘", "tip": "Коротко про байк, без истории."},
        {"kind": "phrase", "ru": "Можно копию?", "thai": "ขอสำเนาได้ไหม", "phonetic": "кхо→ сам→ нау→ дай→ май↗", "tip": "Вопрос: в конце тон чуть вверх."},
        {"kind": "word", "ru": "Страховка", "thai": "ประกัน", "phonetic": "пра→ кан→", "tip": "Назови, если просят показать."},
    ],
    "course_l_1_l3": [
        {"kind": "phrase", "ru": "Шлем надет", "thai": "สวมหมวกแล้ว", "phonetic": "суам→ муак→ лэу→", "tip": "Факт безопасности, коротко."},
        {"kind": "phrase", "ru": "Пассажира нет", "thai": "ไม่มีผู้โดยสาร", "phonetic": "май→ ми→ пху→ дои→ сан↗", "tip": "Май↘ в начале — отрицание."},
        {"kind": "phrase", "ru": "Вот шлем", "thai": "นี่หมวก", "phonetic": "ни→ муак→", "tip": "Покажи предмет, не объясняй."},
    ],
    "course_l_1_l4": [
        {"kind": "phrase", "ru": "Повторите", "thai": "พูดอีกที", "phonetic": "пхуут→ ик→ тхи→", "tip": "Одна просьба — повторить."},
        {"kind": "phrase", "ru": "Проще, пожалуйста", "thai": "พูดง่ายหน่อย", "phonetic": "пхуут→ нгай↘ ной→", "tip": "Просьба упростить, не спорить."},
        {"kind": "phrase", "ru": "На английском?", "thai": "พูดภาษาอังกฤษได้ไหม", "phonetic": "пхуут→ пха→ са→ анг→ грит→ дай→ май↗", "tip": "Вопрос: в конце тон чуть вверх."},
    ],
    "course_l_1_l5": [
        {"kind": "phrase", "ru": "Картой можно?", "thai": "จ่ายบัตรได้ไหม", "phonetic": "джай→ бат→ дай→ май↗", "tip": "Уточни способ оплаты."},
        {"kind": "phrase", "ru": "Наличными", "thai": "จ่ายเงินสด", "phonetic": "джай→ нген→ сот↘", "tip": "Коротко назови способ."},
        {"kind": "phrase", "ru": "Понял сумму", "thai": "เข้าใจยอดแล้ว", "phonetic": "кау→ джай→ йот→ лэу→", "tip": "Подтверди, когда цифра ясна."},
    ],
    "course_l_1_l6": [
        {"kind": "phrase", "ru": "Завтра привезу", "thai": "พรุ่งนี้เอามา", "phonetic": "пхрунг→ ни→ ау→ маа→", "tip": "Следующий шаг, без оправданий."},
        {"kind": "phrase", "ru": "Это копия", "thai": "นี่สำเนา", "phonetic": "ни→ сам→ нау→", "tip": "Назови то, что в руках."},
        {"kind": "phrase", "ru": "Нужно время", "thai": "ขอเวลาหน่อย", "phonetic": "кхо→ ве→ ла→ ной→", "tip": "Просьба, не спор."},
    ],
}

KUN_KRU_SCENE = re.compile(
    r"^Кун Кру объясняет сцену «[^»]+» через реальный бытовой момент:\s*(.+)$"
)
KUN_KRU_SHOW = re.compile(r"^Кун Кру покажет, как\s+(.+)$")


def dump(path: Path, data) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def rename_title(title: str) -> str:
    if title in TITLE_RENAME:
        return TITLE_RENAME[title]
    if title.endswith(" сценка"):
        stem = title[: -len(" сценка")].strip()
        return stem or title
    return title


def rewrite_intro(text: str, subtitle: str) -> str:
    raw = (text or "").strip()
    m = KUN_KRU_SCENE.match(raw)
    if m:
        body = m.group(1).rstrip(" .")
        return body + "."
    m = KUN_KRU_SHOW.match(raw)
    if m:
        body = m.group(1)
        body = re.sub(r"\s*— без длинных объяснений и без давления\.?$", "", body)
        body = body.rstrip(" .")
        if body:
            return body[0].upper() + body[1:] + "."
    if "phrase bank" in raw.lower():
        sub = subtitle.rstrip(" .")
        return f"Короткий набор фраз: {sub}." if sub else "Короткий набор фраз на одну задачу."
    if "survival phrase bank" in raw.lower():
        sub = subtitle.rstrip(" .")
        return f"Короткий набор фраз: {sub}." if sub else raw
    return raw


def rewrite_apply(text: str) -> str:
    raw = (text or "").strip()
    if (
        "как короткий диалог" in raw
        or "попробуй сцену" in raw
        or "phrase bank" in raw.lower()
        or raw.startswith("Выбери нужную короткую фразу")
    ):
        return "Скажи одну фразу из урока вслух — сначала со стрелками, потом в темпе."
    return raw


def rewrite_any_text(text: str) -> str:
    out = text or ""
    for old, new in sorted(TITLE_RENAME.items(), key=lambda kv: -len(kv[0])):
        out = out.replace(f"«{old}»", f"«{new}»")
        out = out.replace(old, new)
    return out


def first_learnable(items: list[dict]) -> dict | None:
    for it in items:
        if it.get("kind") in CONTENT and (it.get("ru") or "").strip():
            return it
    return None


def learnable_count(items: list[dict]) -> int:
    return sum(1 for it in items if it.get("kind") in CONTENT)


def main() -> int:
    stats = Counter()
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    lessons = json.loads(LESSONS.read_text(encoding="utf-8"))
    steps = json.loads(STEPS.read_text(encoding="utf-8"))
    step_by_lesson = {s["lesson_id"]: s for s in steps["stepsets"]}

    for course in catalog:
        if course.get("id") == "course_b_7":
            course["title"] = "Короткие ответы в сервисе"
            course["description"] = "Нет нужной позиции, изменить заказ, коротко ответить и закончить контакт — без длинного диалога."
            course["short_description"] = "Короткие ответы в сервисе"
            stats["catalog_b7"] += 1

    cat_title = {c["id"]: c["title"] for c in catalog}

    for ss in steps["stepsets"]:
        lid = ss.get("lesson_id")
        for it in ss.get("items") or []:
            if it.get("kind") in CONTENT:
                ru = (it.get("ru") or "").strip()
                if ru in CARD_RU_RENAME:
                    it["ru"] = CARD_RU_RENAME[ru]
                    stats["card_ru"] += 1
            for key in ("text", "tip"):
                if it.get(key):
                    new = rewrite_any_text(it[key])
                    if new != it[key]:
                        it[key] = new
                        stats["step_copy"] += 1
        hints = ss.get("hints") or []
        new_hints = [rewrite_any_text(h) for h in hints]
        if new_hints != hints:
            ss["hints"] = new_hints
            stats["hints"] += 1

        if lid == "course_l_2_l6":
            for it in ss.get("items") or []:
                if it.get("thai") == "ไปสนามบิน":
                    it["ru"] = "По счётчику"
                    it["thai"] = "ตามมิเตอร์"
                    it["phonetic"] = "там→ ми→ тё→"
                    it["tip"] = "Договорись о счётчике до посадки."
                    stats["taxi_dup"] += 1
            for it in ss.get("items") or []:
                if it.get("kind") == "tip" and "Место → цена" in (it.get("text") or ""):
                    it["text"] = "Собери поездку: место → цена → стоп → оплата."

        if lid == "course_l_1_l2":
            for it in ss.get("items") or []:
                if it.get("thai") == "เอกสารรถ" and "↓" in (it.get("phonetic") or ""):
                    it["phonetic"] = "ек→ сан→ рот→"
                    stats["phonetic_fix"] += 1

        extras = POLICE_APPEND.get(lid)
        if extras:
            existing_th = {(it.get("thai") or "").strip() for it in ss.get("items") or []}
            orders = [it.get("order") or 0 for it in ss.get("items") or []]
            nxt = (max(orders) if orders else 0) + 1
            for extra in extras:
                if extra["thai"] in existing_th:
                    continue
                row = dict(extra)
                row["order"] = nxt
                nxt += 1
                ss["items"].append(row)
                stats["police_added"] += 1

    for block in lessons["courses"]:
        cid = block.get("course_id")
        if cid in cat_title and block.get("course_title") != cat_title[cid]:
            block["course_title"] = cat_title[cid]
            stats["course_title_sync"] += 1
        for les in block.get("lessons") or []:
            old = les.get("title") or ""
            new = rename_title(old)
            if new != old:
                les["title"] = new
                stats["lesson_title"] += 1
            subtitle = (les.get("subtitle") or "").strip()
            for block_c in les.get("content") or []:
                kind = block_c.get("kind")
                if kind == "intro":
                    rewritten = rewrite_intro(block_c.get("text") or "", subtitle)
                    if rewritten != (block_c.get("text") or "").strip():
                        block_c["text"] = rewritten
                        stats["intro"] += 1
                elif kind == "apply":
                    rewritten = rewrite_apply(block_c.get("text") or "")
                    if rewritten != (block_c.get("text") or "").strip():
                        block_c["text"] = rewritten
                        stats["apply"] += 1
                if block_c.get("text"):
                    t2 = rewrite_any_text(block_c["text"])
                    if t2 != block_c["text"]:
                        block_c["text"] = t2
            outcomes = les.get("outcomes") or []
            new_out = [rewrite_any_text(o) for o in outcomes]
            if new_out != outcomes:
                les["outcomes"] = new_out
                stats["outcomes"] += 1

            ss = step_by_lesson.get(les.get("lesson_id"))
            items = (ss or {}).get("items") or []
            first = first_learnable(items)
            if first:
                ru = (first.get("ru") or "").strip()
                ph = (first.get("phonetic") or "").strip()
                preview = f"{ru};{ph}" if ph else ru
                if les.get("preview_phrase") != preview:
                    les["preview_phrase"] = preview
                    stats["preview"] += 1
            n = len(items)
            if n and les.get("card_count") != n:
                les["card_count"] = n
                stats["card_count"] += 1

    dump(CATALOG, catalog)
    dump(LESSONS, lessons)
    dump(STEPS, steps)
    print(dict(stats))
    leftover = [t for t in TITLE_RENAME if True]
    leftover_titles = []
    for block in lessons["courses"]:
        for les in block.get("lessons") or []:
            t = les.get("title") or ""
            if "сценка" in t.lower() or "диалог" in t.lower() or t.startswith("Repair") or t == "Small talk":
                leftover_titles.append((les.get("lesson_id"), t))
    print("leftover_titles", leftover_titles)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
