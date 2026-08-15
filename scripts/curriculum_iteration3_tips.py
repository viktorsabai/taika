#!/usr/bin/env python3
"""
Iteration 3 — card tips for Taika FM.

`item.tip` on word/phrase/casual = short hint under the card (fun fact / how to use / trap).
Standalone `kind:tip` lifehacks cleaned of meta noise.

Tips should be:
- 1 short sentence (≈20–90 chars)
- useful for saying/remembering the card
- optional [[accent]] for FM
- NOT editor meta ("Один Thai…", "уже в курсе b_5")
"""

from __future__ import annotations

import json
import re
from copy import deepcopy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STEPS_PATH = ROOT / "steps.json"
LESSONS_PATH = ROOT / "lessons.json"
CATALOG_PATH = ROOT / "taika" / "Resourses" / "taika_basa_course.json"
REPORT_PATH = ROOT / "docs" / "curriculum_iteration3_tips_report.md"
CANON_PATH = ROOT / "docs" / "curriculum_lemma_canon.json"

LEARNABLE = {"word", "phrase", "casual"}

# ---------------------------------------------------------------------------
# Hand-crafted tip bank (thai → tip). Highest quality layer.
# ---------------------------------------------------------------------------

TIP_BANK: dict[str, str] = {
    # greetings / politeness
    "สวัสดี": "Универсальное привет и пока. Улыбка усиливает эффект.",
    "สวัสดีครับ": "Мужской вежливый хвост [[кхрап]] — почти всегда к месту.",
    "หวัดดี": "Casual с друзьями. На посту/иммиграции лучше саватди.",
    "ขอบคุณ": "После любой помощи — минимум вежливости, который запоминают.",
    "ขอบคุณครับ": "Спасибо + [[кхрап]]/ка. Коротко и тепло.",
    "ขอบคุณค่ะ": "Женский вариант: спасибо + [[ка]].",
    "ขอโทษ": "Извини за мелочь: задел, переспросил, задержал.",
    "ไม่เป็นไร": "«Ничего страшного» — снимает неловкость у обоих.",
    "ครับ": "Мужской вежливый хвост. Можно почти к любой фразе.",
    "ค่ะ": "Женский вежливый хвост. Тон мягче, чем кажется.",
    "นะ": "Смягчает просьбу: «ладно / пожалуйста по-дружески».",
    "หน่อย": "«Немного / пожалуйста» — просьба звучит менее приказно.",
    # survival
    "เท่าไหร่": "Главный вопрос рынка и кассы. Тон вверх — это вопрос.",
    "แพง": "Можно с улыбкой: констатация, не обвинение.",
    "ลดได้ไหม": "Мягкий торг. После «дорого», не вместо приветствия.",
    "ขอน้ำหน่อย": "Формула «кхо + что + ной» — собирай любые просьбы так.",
    "เช็คบิล": "В кафе/баре. Можно добавить кхрап/ка.",
    "จอดตรงนี้": "Такси/Grab: палец + фраза. Работает лучше длинных объяснений.",
    "ห้องน้ำอยู่ที่ไหน": "Туалет всегда уместен. Говори спокойно, без паники.",
    "ไปไหน": "«Куда?» — и small talk, и реальный вопрос таксисту.",
    "อร่อย": "Комплимент еде. Тайцы искренне радуются.",
    "เผ็ด": "Остро. Если боишься — сразу «май пхет» / «пхет ной».",
    "ไม่เผ็ด": "Спасает желудок. Говори до заказа, не после.",
    "น้ำ": "Вода. Сок — отдельно (нам + фрукт).",
    "น้ำแข็ง": "Лёд. В жару почти по умолчанию — можно отказаться.",
    # tones / traps
    "มา": "Тон ровный: приходить. Не путай с собакой/лошадью.",
    "หมา": "Тон падает: собака. Минимальная пара к «маа→».",
    "ม้า": "Тон вверх: лошадь. Классика для ушей.",
    "ใหม่": "Тон вверх: новый. «Не» — это май↘.",
    "ไม่": "Тон падает: не/нет. Путают чаще всего.",
    "ไม่อยาก": "май↘ + яак. Без падения на май получится «новый хотеть».",
    "ใกล้": "Тон падает: близко. «Далеко» — глай→ (ไกล).",
    "ไกล": "Ровный/средний: далеко. Пара к «близко».",
    "เย็น": "И «холодно», и «вечер» — смысл из контекста.",
    "เจ็ด": "Семь = [[джет]]. Не «дет» — цифра уходит в цены.",
    # people
    "ผม": "«Я» для мужчин. Выбери одно «я» и держись его.",
    "ฉัน": "«Я» нейтрально/женственно. Ок большинству ситуаций.",
    "คุณ": "Вежливое ты/вы. Безопасно с незнакомцами.",
    "เขา": "Он/она в одном слове. Контекст подскажет пол.",
    "เรา": "Мы. Часто включают слушателя — звучит теплее.",
    "เพื่อน": "Друг. Можно и про приятеля, и про «свой человек».",
    "ครอบครัว": "Семья. Тёплая тема small talk после имени.",
    # verbs
    "ไป": "Идти/ехать. Куда — следующим словом.",
    "อยาก": "Хотеть. Коротко: яак + действие/еда.",
    "ชอบ": "Нравится/любить. Мягче, чем страстный «love».",
    "กิน": "Есть. Без спряжений: вчера/сейчас/завтра — тот же кин.",
    "ดื่ม": "Пить. Напитки и тосты.",
    "ซื้อ": "Покупать. На рынке после «тао рай».",
    "พูด": "Говорить. «Пхуут ча» = говори медленнее — золото.",
    "เข้าใจ": "Понимать/понимаю — одна форма, без спряжения.",
    "ไม่เข้าใจ": "Честно и полезно. Лучше, чем кивать мимо.",
    "ช่วย": "Помочь. Вежливо: чуай ной.",
    "อยู่": "Быть/жить/находиться. Контекст решает.",
    # numbers / time
    "กี่โมง": "Который час? ги→ монг↗ — тон вопроса вверх.",
    "วันนี้": "Сегодня. Часто в начале планов.",
    "พรุ่งนี้": "Завтра. Удобно договариваться о визите.",
    "หนึ่ง": "Один. База для цен и порций.",
    "สอง": "Два. «Сон ан» — две штуки на рынке.",
    # culture / soft
    "เกรงใจ": "Крэнг-джай: стесняюсь обременить. Не «мне всё равно».",
    "ใจเย็น": "Джай-йен: спокойное сердце. Просьба не кипятиться.",
    "สบาย": "Сабай: комфорт/ок. Ключевое слово вайба Таиланда.",
    "ไม่ได้": "Нельзя/не получается — часто мягкий отказ.",
    # life scenes
    "พาสปอร์ต": "Паспорт. На посту показывают, не объясняют роман.",
    "วีซ่า": "Виза. Короткий ответ + улыбка.",
    "โรงพยาบาล": "Больница. В срочном — ясность важнее акцента.",
    "ยา": "Лекарство. В аптеке: симптом → я → дозировка.",
    "แอร์": "Кондиционер. В жару — топ тема сервиса.",
    "ส่งของ": "Доставка. Трек-номер спасает нервы.",
    "Grab": "Grab. Можно сказать «граб» — поймут.",
    "สนามบิน": "Аэропорт. В такси: пай + санам бин.",
    "ห้าห้าห้า": "555 = ха-ха-ха в чате. Вслух лучше «кхам».",
    "แซ่บ": "Сэп: вкусно и/или «огонь» про человека — смотри контекст.",
}

# Pattern fallbacks (applied if no bank hit)
QUESTION_TIP = "Вопрос: тон в конце чуть [[вверх]]."
POLITE_TIP = "Добавь кхрап/ка — сразу звучишь теплее."
PLEASE_TIP = "Просьба: ной / на смягчают приказной тон."
NEG_TIP = "Отрицание май↘ — тон падает, иначе смысл поедет."


def norm_th(s: str) -> str:
    return re.sub(r"\s+", "", (s or "").strip())


def is_bad_tip(tip: str) -> bool:
    t = (tip or "").strip()
    if not t:
        return True
    low = t.lower()
    bad_markers = (
        "один thai",
        "не дублируем",
        "уже в курсе",
        "уже в «",
        "уже в \"",
        "уже в старте",
        "в сцене:",
        "course_b_",
        "course_l_",
        "из b_",
        "комбинируй с местоимениями из",
        "комбинируй с глаголами из b_",
        "описания оживляют речь. комбинируй",
        "транслит не дублируем",
    )
    return any(m in low for m in bad_markers)


def rewrite_scene_tip(old: str) -> str | None:
    """В сцене: «X» → короткая польза."""
    m = re.search(r"В сцене:\s*«([^»]+)»", old or "")
    if not m:
        return None
    scene = m.group(1).strip()
    # keep short
    if "спасибо" in scene.lower():
        return f"В этой ситуации часто: «{scene}» — тот же кхоп кхун."
    if "до свидания" in scene.lower() or "хорош" in scene.lower() or "удач" in scene.lower():
        return f"Прощание в сцене звучит как «{scene}» — по смыслу ла кон."
    return f"В живой сцене так и говорят: «{scene}»."


def heuristic_tip(ru: str, th: str, ph: str, kind: str) -> str | None:
    th_n = norm_th(th)
    if th_n in TIP_BANK:
        return TIP_BANK[th_n]
    ru_l = (ru or "").lower()
    # questions
    if "ไหม" in th_n or (ph or "").endswith("↗") or ru_l.endswith("?"):
        if "сколько" in ru_l or "เท่า" in th_n:
            return "Спрашивай цену спокойно — торг начинается после ответа."
        return QUESTION_TIP
    if th_n.endswith("ครับ") or th_n.endswith("ค่ะ") or "кхрап" in (ph or "").lower():
        return POLITE_TIP
    if "หน่อย" in th_n or "ной" in (ph or "").lower():
        return PLEASE_TIP
    if th_n.startswith("ไม่") or (ph or "").startswith("май↘"):
        return NEG_TIP
    if kind == "casual":
        return "Casual: с друзьями ок. С незнакомцем лучше вежливее."
    if kind == "word" and len(th_n) <= 4:
        return "Короткое слово — сначала тон, потом скорость."
    # light default for phrases
    if kind == "phrase":
        return "Скажи вслух 2 раза, потом представь реальную сцену."
    return "Свяжи с ситуацией — так запомнится быстрее."


def improve_card_tips(steps_doc: dict, log: list[str], tip_bank: dict[str, str] | None = None) -> dict:
    bank = tip_bank or TIP_BANK
    stats = {
        "rewritten_bad": 0,
        "filled_new": 0,
        "kept_good": 0,
        "bank_hits": 0,
    }
    for ss in steps_doc["stepsets"]:
        for it in ss.get("items") or []:
            if it.get("kind") not in LEARNABLE:
                continue
            th = it.get("thai") or ""
            ru = it.get("ru") or ""
            ph = it.get("phonetic") or ""
            tip = (it.get("tip") or "").strip()
            th_n = norm_th(th)

            if tip.startswith("В сцене:"):
                new = rewrite_scene_tip(tip)
                if new:
                    it["tip"] = new
                    tip = new
                    stats["rewritten_bad"] += 1

            # Bank always wins for known lemmas (FM quality).
            if th_n in bank:
                it["tip"] = bank[th_n]
                stats["bank_hits"] += 1
                continue

            if tip and not is_bad_tip(tip):
                stats["kept_good"] += 1
                continue

            new = heuristic_tip(ru, th, ph, it.get("kind") or "phrase")
            # heuristic_tip uses TIP_BANK; patch to use bank
            if th_n in bank:
                new = bank[th_n]
            it["tip"] = new
            if is_bad_tip(tip) and tip:
                stats["rewritten_bad"] += 1
            else:
                stats["filled_new"] += 1
    log.append(
        f"card tips: filled={stats['filled_new']} rewritten={stats['rewritten_bad']} "
        f"kept={stats['kept_good']} bank_hits={stats['bank_hits']}"
    )
    return stats


def load_bank() -> dict[str, str]:
    bank = dict(TIP_BANK)
    if CANON_PATH.exists():
        doc = json.loads(CANON_PATH.read_text(encoding="utf-8"))
        bank.update(doc.get("card_tip_bank") or {})
    return bank


def clean_standalone_tips(steps_doc: dict, log: list[str]) -> None:
    """Remove/replace meta lifehack cards; keep useful ones."""
    removed = 0
    rewritten = 0
    replacements = {
        "один thai": None,  # delete
        "транслит не дублируем": None,
        "сборка / review": "Это [[сборка]] сцены: порядок реплик важнее новых слов.",
        "глаголы из b_5": "Глагол не спрягается: выучил — собирай с «я/ты» и местом.",
        "описания оживляют речь": "Оценка (вкусно/дорого/красиво) оживляет любую бытовую фразу.",
        "комбинируй с глаголами из «главные глаголы»": "Склейка: глагол + оценка. Пример: кин + а-рой.",
        "не дублируем базу и жизнь": "Здесь — мягкость и код общения, не новый словарь выживания.",
        "тайский для души": "Ниша поверх базы: говори естественнее, не зубри дубли.",
        "линейка с иммигрейшеном": "Резидентские темы: спокойный тон важнее идеального акцента.",
    }

    for ss in steps_doc["stepsets"]:
        new_items = []
        for it in ss.get("items") or []:
            if it.get("kind") != "tip":
                new_items.append(it)
                continue
            text = (it.get("text") or "").strip()
            low = text.lower()
            drop = False
            for key, repl in replacements.items():
                if key in low:
                    if repl is None:
                        drop = True
                    else:
                        it = deepcopy(it)
                        it["text"] = repl
                        rewritten += 1
                    break
            else:
                # other meta with course codes
                if re.search(r"\bb_[0-9]\b|course_[a-z]", low) and (
                    "уже" in low or "не дубл" in low or "верн" in low
                ):
                    # soften: keep if has real advice after dash
                    if "—" in text or "." in text:
                        # strip course-code heavy openings when possible
                        pass
                    else:
                        drop = True
            if drop:
                removed += 1
                continue
            new_items.append(it)
        # renumber
        out = []
        for i, it in enumerate(new_items, 1):
            n = deepcopy(it)
            n["order"] = i
            out.append(n)
        ss["items"] = out

    log.append(f"standalone tips: removed_meta={removed} rewritten={rewritten}")


def sync_catalog(lessons_doc: dict, log: list[str]) -> None:
    if not CATALOG_PATH.exists():
        log.append("catalog: skip (file missing)")
        return
    catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    by_id = {c["course_id"]: c for c in lessons_doc["courses"]}
    n = 0
    for row in catalog:
        cid = row.get("id")
        src = by_id.get(cid)
        if not src:
            continue
        if src.get("description"):
            row["description"] = src["description"]
            n += 1
        # lesson count sync
        row["lesson_count"] = len(src.get("lessons") or [])
        if src.get("summary", {}).get("total_duration_minutes"):
            row["duration_minutes"] = src["summary"]["total_duration_minutes"]
    CATALOG_PATH.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    log.append(f"catalog: synced descriptions for {n} courses")


def metrics(steps_doc: dict) -> dict:
    with_tip = 0
    without = 0
    bad = 0
    tips_n = 0
    for ss in steps_doc["stepsets"]:
        for it in ss.get("items") or []:
            if it.get("kind") == "tip":
                tips_n += 1
                if is_bad_tip(it.get("text") or ""):
                    bad += 1
            elif it.get("kind") in LEARNABLE:
                tip = (it.get("tip") or "").strip()
                if tip:
                    with_tip += 1
                    if is_bad_tip(tip):
                        bad += 1
                else:
                    without += 1
    total = with_tip + without
    return {
        "card_with_tip": with_tip,
        "card_without_tip": without,
        "coverage": round(with_tip / total, 3) if total else 0,
        "standalone_tips": tips_n,
        "bad_tips_remaining": bad,
    }


def persist_bank_into_canon(log: list[str]) -> None:
    if not CANON_PATH.exists():
        return
    doc = json.loads(CANON_PATH.read_text(encoding="utf-8"))
    doc["card_tip_bank"] = TIP_BANK
    CANON_PATH.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    log.append(f"canon: stored tip bank ({len(TIP_BANK)} lemmas)")


def main() -> None:
    steps_doc = json.loads(STEPS_PATH.read_text(encoding="utf-8"))
    lessons_doc = json.loads(LESSONS_PATH.read_text(encoding="utf-8"))
    log: list[str] = []
    before = metrics(steps_doc)

    tip_bank = load_bank()
    improve_card_tips(steps_doc, log, tip_bank)
    clean_standalone_tips(steps_doc, log)
    sync_catalog(lessons_doc, log)
    # persist merged bank
    global TIP_BANK
    TIP_BANK = tip_bank
    persist_bank_into_canon(log)

    after = metrics(steps_doc)

    STEPS_PATH.write_text(json.dumps(steps_doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    lines = [
        "# Curriculum iteration 3 — card tips (Taika FM)",
        "",
        "Tips on learnable cards = short useful/fun hints shown with the card.",
        "",
        "## Coverage",
        "",
        "| | Before | After |",
        "|---|---:|---:|",
        f"| Cards with tip | {before['card_with_tip']} | {after['card_with_tip']} |",
        f"| Cards without tip | {before['card_without_tip']} | {after['card_without_tip']} |",
        f"| Coverage | {before['coverage']:.0%} | {after['coverage']:.0%} |",
        f"| Standalone tip items | {before['standalone_tips']} | {after['standalone_tips']} |",
        f"| Bad/meta tips remaining | {before['bad_tips_remaining']} | {after['bad_tips_remaining']} |",
        "",
        "## Changelog",
        "",
    ]
    for x in log:
        lines.append(f"- {x}")
    lines += [
        "",
        "## Quality bar for tips",
        "",
        "- 1 short sentence, learning value or fun fact",
        "- Optional `[[accent]]` for FM",
        "- No editor meta, no bare «В сцене:»",
        "",
        "## Next",
        "",
        "- Expand TIP_BANK for long-tail lemmas (manual editorial)",
        "- Spot-check FM rendering on Base + top Life courses",
        "",
    ]
    REPORT_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("BEFORE", before)
    print("AFTER ", after)
    for x in log:
        print(" ", x)


if __name__ == "__main__":
    main()
