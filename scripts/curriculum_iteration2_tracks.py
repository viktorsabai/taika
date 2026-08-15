#!/usr/bin/env python3
"""
Iteration 2 — cross-track differentiation + lesson shells + review tips.
"""

from __future__ import annotations

import json
import re
from copy import deepcopy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LESSONS_PATH = ROOT / "lessons.json"
STEPS_PATH = ROOT / "steps.json"
REPORT_PATH = ROOT / "docs" / "curriculum_iteration2_report.md"

LEARNABLE = {"word", "phrase", "casual"}


def renumber(items: list) -> list:
    out = []
    for i, it in enumerate(items, 1):
        n = deepcopy(it)
        n["order"] = i
        out.append(n)
    return out


def learnable_count(items: list) -> int:
    return sum(1 for it in items if it.get("kind") in LEARNABLE)


def ensure_tip(items: list, text: str, *, at_start: bool = True) -> list:
    texts = [it.get("text") for it in items if it.get("kind") == "tip"]
    if text in texts:
        return items
    t = {"order": 0, "kind": "tip", "text": text}
    return ([t] + items) if at_start else (items + [t])


def replace_thai(items: list, old_thai: str, new_card: dict) -> tuple[list, bool]:
    out = []
    hit = False
    for it in items:
        if it.get("kind") in LEARNABLE and it.get("thai") == old_thai:
            n = deepcopy(new_card)
            n["order"] = it.get("order", 0)
            if "kind" not in n:
                n["kind"] = it.get("kind") or "phrase"
            out.append(n)
            hit = True
        else:
            out.append(it)
    return out, hit


# --- replacements ---

E1_REPL = {
    "นุ่มนวล": {
        "kind": "phrase",
        "ru": "Говори чётче",
        "thai": "พูดให้ชัด",
        "phonetic": "пхуут→ хай→ чат↘",
        "tip": "Ясность без резкости — цель курса e_1 (частицы мягкости — в «Мягкий тайский»).",
    },
    "นะ": {
        "kind": "phrase",
        "ru": "Помедленнее",
        "thai": "ช้าๆ",
        "phonetic": "ча↗ ча↗",
        "tip": "Ритм ясности. Частица «на» — в курсе «Мягкий тайский».",
    },
    "ท้ายประโยค": {
        "kind": "phrase",
        "ru": "Скажи коротко",
        "thai": "พูดสั้นๆ",
        "phonetic": "пхуут→ сан↗ сан↗",
        "tip": "Коротко и понятно. Куда ставить хвост — в «Мягкий тайский».",
    },
}

E3_REPL = {
    "ทำความสะอาด": {
        "kind": "phrase",
        "ru": "Уберите номер пожалуйста",
        "thai": "ช่วยเก็บห้องหน่อย",
        "phonetic": "чуай→ кеп→ хонг↘ ной→",
        "tip": "Мягкая просьба персоналу. Базовая «уборка» — в курсе отеля.",
    },
    "เก็บได้ไหม": {
        "kind": "phrase",
        "ru": "Извините что беспокою",
        "thai": "รบกวนนะ",
        "phonetic": "роп→ куан→ на→",
        "tip": "Открывает любую сервисную просьбу без давления.",
    },
    "แอร์เสีย": {
        "kind": "phrase",
        "ru": "Есть небольшая проблема",
        "thai": "มีปัญหาหน่อย",
        "phonetic": "ми→ пан→ ха→ ной→",
        "tip": "Мягкий вход. Конкретный «кондиционер сломан» — в отеле / жилье.",
    },
    "ช่วยซ่อมหน่อย": {
        "kind": "phrase",
        "ru": "Посмотрите пожалуйста",
        "thai": "ช่วยดูหน่อย",
        "phonetic": "чуай→ ду→ ной→",
        "tip": "Сервисная рамка; ремонт как лексика — в Life.",
    },
    "ซ่อม": {
        "kind": "word",
        "ru": "Помощь с этим",
        "thai": "ช่วยเรื่องนี้",
        "phonetic": "чуай→ рыанг→ ни↘",
        "tip": "Общая просьба помощи персоналу.",
    },
    "ไม่เย็น": {
        "kind": "phrase",
        "ru": "Ещё не готово?",
        "thai": "ยังไม่เสร็จไหม",
        "phonetic": "янг→ май→ сет↘ май↗",
        "tip": "Мягкий статус без упрёка.",
    },
    "พรุ่งนี้ได้ไหม": {
        "kind": "phrase",
        "ru": "Можно на другой день?",
        "thai": "อีกวันได้ไหม",
        "phonetic": "ик→ ван→ дай→ май↗",
        "tip": "Альтернатива «завтра можно?» из жилья.",
    },
    "มาเมื่อไหร่": {
        "kind": "phrase",
        "ru": "Во сколько подойдёте?",
        "thai": "มากี่โมง",
        "phonetic": "маа→ ги→ монг↗",
        "tip": "Уточнение времени мягко.",
    },
    "สิบโมงได้ไหม": {
        "kind": "phrase",
        "ru": "Удобно после обеда?",
        "thai": "บ่ายสะดวกไหม",
        "phonetic": "бай→ са→ дуак↘ май↗",
        "tip": "Предложить окно, не приказывать время.",
    },
}

S2_REPL = {
    "ยิม": {
        "kind": "word",
        "ru": "Студия",
        "thai": "สตูดิโอ",
        "phonetic": "са→ ту→ дио→",
        "tip": "Хобби-студия. «Зал/фитнес» — в курсе «Между подходами».",
    },
    "ฟิตเนส": {
        "kind": "word",
        "ru": "Клуб по интересу",
        "thai": "ชมรม",
        "phonetic": "чом→ ром→",
        "tip": "Кружок/клуб. Тренажёрка — в Life про зал.",
    },
    "บัตรสมาชิก": {
        "kind": "word",
        "ru": "Запись на класс",
        "thai": "สมัครคลาส",
        "phonetic": "са→ мак↘ кхлас↘",
        "tip": "Записаться на хобби-класс. Членская карта зала — в «Между подходами».",
    },
    "ครั้งเดียว": {
        "kind": "phrase",
        "ru": "По занятию",
        "thai": "เรียนทีละครั้ง",
        "phonetic": "риан→ тхи→ ла→ кхранг↘",
        "tip": "Оплата за разовое занятие хобби.",
    },
    "ตาราง": {
        "kind": "word",
        "ru": "Календарь классов",
        "thai": "ปฏิทินคลาส",
        "phonetic": "па→ ти→ тхин→ кхлас↘",
        "tip": "Когда занятия по хобби. Сетка зала — в Life.",
    },
    "เช้าเย็น": {
        "kind": "phrase",
        "ru": "На выходных",
        "thai": "เสาร์อาทิตย์",
        "phonetic": "сау↗ аа→ тит→",
        "tip": "Типичное время для хобби.",
    },
    "ยิมอยู่ที่ไหน": {
        "kind": "phrase",
        "ru": "Где студия?",
        "thai": "สตูดิโออยู่ที่ไหน",
        "phonetic": "са→ ту→ дио→ ю→ ти→ най↗",
        "tip": "Хобби-студия, не тренажёрный зал.",
    },
    "ถามเรื่องยิม": {
        "kind": "phrase",
        "ru": "Спросить про класс",
        "thai": "ถามเรื่องคลาส",
        "phonetic": "тхаам→ рыанг→ кхлас↘",
        "tip": "Про хобби-класс.",
    },
}

LONG7_REPL = {
    "ห้าห้าห้า": {
        "kind": "phrase",
        "ru": "Очень смешно",
        "thai": "ขำมาก",
        "phonetic": "кхам→ мак↘",
        "tip": "Живой смех. «555» как чат-код — в «О чём говорят».",
    },
    "ตลก": {
        "kind": "word",
        "ru": "Шутка / панчлайн",
        "thai": "มุก",
        "phonetic": "мук↘",
        "tip": "Мук = шутка. Базовое «смешно» — в сленг-курсе.",
    },
    "น้อง": {
        "kind": "phrase",
        "ru": "Обращение в сериале",
        "thai": "เรียกน้องในซีรีส์",
        "phonetic": "риак→ нонг↘ най→ си→ ри↗",
        "tip": "Поп-культура. Само น้อง — в сленге/семье.",
    },
    "แซ่บ": {
        "kind": "word",
        "ru": "Огонь (сленг)",
        "thai": "เด็ด",
        "phonetic": "дет↘",
        "tip": "เด็ด ≈ круто. แซ่บ как база — в «О чём говорят».",
    },
    "แซ่บมาก": {
        "kind": "phrase",
        "ru": "Кайф полный",
        "thai": "โคตรดี",
        "phonetic": "кхот→ ди→",
        "tip": "Сильный разговорный акцент (осторожно с регистром).",
    },
    "ไวบ์โอเค": {
        "kind": "phrase",
        "ru": "Настроение топ",
        "thai": "อารมณ์ดี",
        "phonetic": "а→ ром→ ди→",
        "tip": "Эмодзи-вайб в речи. «Вайб ок» — в сленг-курсе.",
    },
}

# Unify long_3 glosses that overlap l_5
LONG3_GLOSS = {
    "ยา": "Лекарство",
    "ร้านยา": "Аптека",
    "ไข้": "Температура",
    "หลังกินข้าว": "После еды",
    "ไม่แพ้": "Нет аллергии",
}


def apply_replacements(steps_doc: dict, course_id: str, mapping: dict, log: list[str]) -> None:
    for ss in steps_doc["stepsets"]:
        if ss.get("course_id") != course_id:
            continue
        items = ss.get("items") or []
        for old, new in mapping.items():
            items, hit = replace_thai(items, old, new)
            if hit:
                log.append(f"{ss['lesson_id']}: {old} → {new['thai']} («{new['ru']}»)")
        # role tip once per touched course lesson if any replace happened
        ss["items"] = renumber(items)


def add_course_role_hints(steps_doc: dict, log: list[str]) -> None:
    hints = {
        "course_e_1": "Курс про ясность речи. Мягкие частицы и «на/ной» — в «Мягкий тайский».",
        "course_e_6": "Курс про мягкость и хвосты. Ясность формулировок — в «Понятный тайский».",
        "course_e_3": "Как просить персонал мягко. Конкретный отель/жильё — в Life.",
        "course_s_2": "Хобби и студии. Зал и абонемент — в «Между подходами».",
        "course_long_7": "Поп-культура и мемы глубже. Базовый сленг — в «О чём говорят».",
        "course_long_3": "Углубление медицины для резидента. Аптечный минимум — в «Доктор Тайка».",
    }
    for ss in steps_doc["stepsets"]:
        cid = ss.get("course_id")
        if cid not in hints:
            continue
        # only first lesson of course
        if not str(ss.get("lesson_id") or "").endswith("_l1"):
            continue
        before = list(ss.get("hints") or [])
        if hints[cid] not in before:
            ss["hints"] = [hints[cid]] + before
            log.append(f"hint {cid}")


def unify_long3_gloss(steps_doc: dict, log: list[str]) -> None:
    for ss in steps_doc["stepsets"]:
        if ss.get("course_id") != "course_long_3":
            continue
        for it in ss.get("items") or []:
            th = it.get("thai")
            if th in LONG3_GLOSS and it.get("kind") in LEARNABLE:
                if it.get("ru") != LONG3_GLOSS[th]:
                    old = it.get("ru")
                    it["ru"] = LONG3_GLOSS[th]
                    tip = (it.get("tip") or "").strip()
                    note = "Тот же минимум, что в аптеке Life — здесь в медицинском контексте."
                    if note not in tip:
                        it["tip"] = f"{note} {tip}".strip() if tip else note
                    log.append(f"{ss['lesson_id']}: gloss {th} «{old}» → «{LONG3_GLOSS[th]}»")


def fill_shells(lessons_doc: dict, log: list[str]) -> int:
    n = 0
    for c in lessons_doc["courses"]:
        cid = c.get("course_id") or ""
        if cid.startswith("course_b_"):
            continue  # already filled in baza audit
        ctitle = c.get("course_title") or ""
        for les in c.get("lessons") or []:
            texts = [(b.get("text") or "").strip() for b in (les.get("content") or [])]
            if any(texts):
                continue
            title = les.get("title") or ""
            sub = les.get("subtitle") or ""
            intro = f"Урок «{title}» курса «{ctitle}»: {sub}".strip(" :")
            if not sub:
                intro = f"Урок «{title}» в курсе «{ctitle}» — практические фразы для ситуации."
            outline = f"Карточки урока → произношение со стрелками → сборка в короткие реплики по теме «{title}»."
            apply = f"Сегодня используй 1–2 фразы из «{title}» в реальной или проговорённой вслух сцене."
            # finales
            low = title.lower()
            if any(k in low for k in ("сценк", "диалог", "полный")):
                intro = f"Сборка курса «{ctitle}»: склеиваем уже изученные реплики в одну сцену («{title}»)."
                outline = "Повтор ключевых реплик → порядок сцены → проговор целиком."
                apply = "Проговори сцену целиком; если спотыкаешься — вернись к уроку, где фраза появилась впервые."
            les["content"] = [
                {"kind": "intro", "text": intro},
                {"kind": "outline", "text": outline},
                {"kind": "apply", "text": apply},
            ]
            n += 1
    log.append(f"filled intro/outline/apply for {n} non-База lessons")
    return n


def add_review_tips(steps_doc: dict, lessons_doc: dict, log: list[str]) -> int:
    titles = {}
    for c in lessons_doc["courses"]:
        for les in c.get("lessons") or []:
            titles[les["lesson_id"]] = les.get("title") or ""
    n = 0
    tip = "Сборка / review: мало новых слов — склейка уже известного. Не зубри как новый словарь."
    for ss in steps_doc["stepsets"]:
        lid = ss.get("lesson_id") or ""
        title = titles.get(lid, "")
        low = title.lower()
        if not any(k in low for k in ("сценк", "диалог", "полный диалог", "сборн")):
            continue
        before = len(ss.get("items") or [])
        ss["items"] = renumber(ensure_tip(ss.get("items") or [], tip, at_start=True))
        if len(ss["items"]) >= before:
            # tip added or already there
            texts = [it.get("text") for it in ss["items"] if it.get("kind") == "tip"]
            if tip in texts:
                n += 1
    log.append(f"review tips on scene/dialogue lessons: {n}")
    return n


def update_catalog_blurbs(lessons_doc: dict, log: list[str]) -> None:
    blurbs = {
        "course_e_1": "Ясность без резкости: коротко, понятно, без давления. Мягкие хвосты — соседний курс.",
        "course_e_6": "Мягкий тайский: на, ной, ка/кхрап и тон просьбы. Ясность формулировок — в «Понятный тайский».",
        "course_e_3": "Сервис без конфликта: как просить персонал мягко. Отель и жильё — отдельные Life-курсы.",
        "course_s_2": "Хобби и студии: муай-тай, йога, керамика, серф. Зал и абонемент — в «Между подходами».",
        "course_s_3": "Живой сленг и мемы для чата. Поп-культура глубже — в курсе долгожителей.",
        "course_long_7": "Мемы, дорамы, тренды для своих. Базовый сленг — в «О чём говорят».",
        "course_long_3": "Медицина и страховка для резидента. Аптечный минимум — в «Доктор Тайка».",
    }
    for c in lessons_doc["courses"]:
        cid = c.get("course_id")
        if cid in blurbs:
            c["description"] = blurbs[cid]
            log.append(f"description {cid}")


def sync_card_counts(lessons_doc: dict, steps_doc: dict) -> None:
    by = {s["lesson_id"]: s for s in steps_doc["stepsets"]}
    for c in lessons_doc["courses"]:
        for les in c.get("lessons") or []:
            ss = by.get(les["lesson_id"])
            if ss:
                les["card_count"] = learnable_count(ss["items"])
        mins = sum(int(x.get("duration_minutes") or 0) for x in c.get("lessons") or [])
        c["summary"] = {
            "total_lessons": len(c.get("lessons") or []),
            "total_duration_minutes": mins,
        }


def overlap_count(steps_doc: dict, a: str, b: str) -> int:
    def thais(cid):
        s = set()
        for ss in steps_doc["stepsets"]:
            if ss.get("course_id") != cid:
                continue
            for it in ss.get("items") or []:
                if it.get("kind") in LEARNABLE and it.get("thai"):
                    s.add(re.sub(r"\s+", "", it["thai"]))
        return s
    return len(thais(a) & thais(b))


def main() -> None:
    lessons_doc = json.loads(LESSONS_PATH.read_text(encoding="utf-8"))
    steps_doc = json.loads(STEPS_PATH.read_text(encoding="utf-8"))
    log: list[str] = []

    before_pairs = {
        "e1∩e6": overlap_count(steps_doc, "course_e_1", "course_e_6"),
        "e3∩l6": overlap_count(steps_doc, "course_e_3", "course_l_6"),
        "e3∩l13": overlap_count(steps_doc, "course_e_3", "course_l_13"),
        "s2∩l10": overlap_count(steps_doc, "course_s_2", "course_l_10"),
        "s3∩long7": overlap_count(steps_doc, "course_s_3", "course_long_7"),
    }

    apply_replacements(steps_doc, "course_e_1", E1_REPL, log)
    apply_replacements(steps_doc, "course_e_3", E3_REPL, log)
    apply_replacements(steps_doc, "course_s_2", S2_REPL, log)
    apply_replacements(steps_doc, "course_long_7", LONG7_REPL, log)
    unify_long3_gloss(steps_doc, log)
    add_course_role_hints(steps_doc, log)
    update_catalog_blurbs(lessons_doc, log)
    fill_shells(lessons_doc, log)
    add_review_tips(steps_doc, lessons_doc, log)
    sync_card_counts(lessons_doc, steps_doc)

    after_pairs = {
        "e1∩e6": overlap_count(steps_doc, "course_e_1", "course_e_6"),
        "e3∩l6": overlap_count(steps_doc, "course_e_3", "course_l_6"),
        "e3∩l13": overlap_count(steps_doc, "course_e_3", "course_l_13"),
        "s2∩l10": overlap_count(steps_doc, "course_s_2", "course_l_10"),
        "s3∩long7": overlap_count(steps_doc, "course_s_3", "course_long_7"),
    }

    LESSONS_PATH.write_text(json.dumps(lessons_doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    STEPS_PATH.write_text(json.dumps(steps_doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    lines = [
        "# Curriculum iteration 2 — track roles + shells",
        "",
        "## Overlap Thai (before → after)",
        "",
        "| Pair | Before | After |",
        "|---|---:|---:|",
    ]
    for k in before_pairs:
        lines.append(f"| {k} | {before_pairs[k]} | {after_pairs[k]} |")
    lines += ["", "## Changelog", ""]
    for x in log:
        lines.append(f"- {x}")
    lines += [
        "",
        "## Scoreboard delta",
        "",
        "- Cross-track role clarity: raised (exact Thai overlaps cut on conflict pairs)",
        "- Intro/outline/apply: all non-База lessons filled",
        "- Scene finales: review tip added",
        "",
        "## Next iteration",
        "",
        "- Tips/lifehack quality pass",
        "- Catalog JSON descriptions sync (`taika_basa_course.json`)",
        "- Semantic smoke expansion beyond known P0 list",
        "",
    ]
    REPORT_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")

    print("BEFORE", before_pairs)
    print("AFTER ", after_pairs)
    print("log lines", len(log))


if __name__ == "__main__":
    main()
