#!/usr/bin/env python3
"""Rebuild База от Тайки: slim b1, no cross-course phrase dumps, b7 as synthesis."""

from __future__ import annotations

import json
from copy import deepcopy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LESSONS_PATH = ROOT / "lessons.json"
STEPS_PATH = ROOT / "steps.json"
CATALOG_PATH = ROOT / "taika" / "Resourses" / "taika_basa_course.json"


def tip(order: int, text: str) -> dict:
    return {"order": order, "kind": "tip", "text": text}


def phrase(order: int, ru: str, thai: str, phonetic: str, tip_text: str | None = None, kind: str = "phrase") -> dict:
    item = {"order": order, "kind": kind, "ru": ru, "thai": thai, "phonetic": phonetic}
    if tip_text:
        item["tip"] = tip_text
    return item


def word(order: int, ru: str, thai: str, phonetic: str, tip_text: str | None = None) -> dict:
    return phrase(order, ru, thai, phonetic, tip_text, kind="word")


def casual(order: int, ru: str, thai: str, phonetic: str, tip_text: str | None = None) -> dict:
    return phrase(order, ru, thai, phonetic, tip_text, kind="casual")


def renumber(items: list[dict]) -> list[dict]:
    out = []
    for i, it in enumerate(items, start=1):
        x = deepcopy(it)
        x["order"] = i
        out.append(x)
    return out


def lesson_meta(
    lesson_id: str,
    order: int,
    title: str,
    subtitle: str,
    duration: int,
    preview: str,
    prereq: list[str],
    is_free: bool,
    card_count: int,
) -> dict:
    return {
        "lesson_id": lesson_id,
        "order": order,
        "title": title,
        "subtitle": subtitle,
        "duration_minutes": duration,
        "card_count": card_count,
        "is_free": is_free,
        "tags": [],
        "preview_phrase": preview,
        "content": [
            {"kind": "intro", "text": ""},
            {"kind": "outline", "text": ""},
            {"kind": "apply", "text": ""},
        ],
        "outcomes": [],
        "prerequisites": prereq,
        "links": {
            "steps_ref": f"{lesson_id}_steps",
            "hometask_ref": f"{lesson_id}_home",
        },
        "assistant_tips": [],
    }


def stepset(course_id: str, lesson_id: str, hints: list[str], items: list[dict]) -> dict:
    items = renumber(items)
    return {
        "id": f"{lesson_id}_steps",
        "course_id": course_id,
        "lesson_id": lesson_id,
        "hints": hints,
        "items": items,
    }


def learnable_count(items: list[dict]) -> int:
    return sum(1 for it in items if it.get("kind") in ("word", "phrase", "casual"))


# ─── course_b_1 Разговорный старт (7 уроков, survival only) ───

B1: list[tuple[dict, dict]] = []

# l1
items = [
    tip(1, "Вай на уровне груди + улыбка. Часто работает даже без слов."),
    tip(2, "Кха / кхрап — вежливые хвостики. Мужчины: кхрап, женщины: кха."),
    phrase(3, "Здравствуйте", "สวัสดี", "са→ ват→ ди↘", "Базовое приветствие без хвостика."),
    phrase(4, "Здравствуйте вежливо", "สวัสดีครับ", "са→ ват→ ди→ кхрап↘", "С кхрап — нейтрально-вежливо."),
    casual(5, "Привет", "หวัดดี", "ват→ ди↘", "Друзьям и сверстникам."),
    phrase(6, "Пока", "ลาไปก่อน", "ла→ пай→ кон→", "Мягкое «я пошёл»."),
    phrase(7, "Приятно познакомиться", "ยินดีที่ได้รู้จัก", "йин→ ди↗ ти→ дай→ ру→ джак↘"),
]
B1.append(
    (
        lesson_meta(
            "course_b_1_l1",
            1,
            "Приветствие",
            "Саватди и улыбка — твой пропуск в любой 7-Eleven",
            3,
            "здравствуйте;са-ват-ди↘",
            [],
            True,
            learnable_count(items),
        ),
        stepset("course_b_1", "course_b_1_l1", ["Кха/кхрап по полу говорящего.", "Улыбка — часть приветствия."], items),
    )
)

# l2
items = [
    tip(1, "Только имя и «откуда». Вопросы «где/кто/когда» — в курсе «Время, место, цифры»."),
    tip(2, "Сложное имя — придумай короткий тайский ник. Тайцы любят."),
    phrase(3, "Как тебя зовут?", "คุณชื่ออะไร", "кун→ чыу→ а→ рай↗"),
    phrase(4, "Меня зовут …", "ฉันชื่อ …", "чхан→ чыу→ …→", "Подставь имя после чыу."),
    phrase(5, "Откуда ты?", "คุณมาจากไหน", "кун→ ма→ джак→ най↗"),
    phrase(6, "Я из России", "ฉันมาจากรัสเซีย", "чхан→ ма→ джак→ рас→ сиа→"),
    phrase(7, "Очень приятно", "ยินดีที่ได้รู้จัก", "йин→ ди↗ ти→ дай→ ру→ джак↘"),
    casual(8, "Рад встрече", "ดีใจที่เจอ", "ди→ джай→ ти→ джё→"),
]
B1.append(
    (
        lesson_meta(
            "course_b_1_l2",
            2,
            "Знакомство",
            "Имя и откуда — без допроса и грамматики",
            3,
            "как тебя зовут?;кун чыу а-рай↗",
            ["course_b_1_l1"],
            True,
            learnable_count(items),
        ),
        stepset("course_b_1", "course_b_1_l2", ["Держи один вариант «я» — чхан или пхом (в курсе про местоимения)."], items),
    )
)

# l3
items = [
    tip(1, "Сабай = комфортно. Май сабай = не очень. Переключатель small talk."),
    phrase(2, "Как дела?", "สบายดีไหม", "са→ бай→ ди→ май↗"),
    phrase(3, "Хорошо", "สบายดี", "са→ бай→ ди→"),
    phrase(4, "Всё chill", "สบายๆ", "са→ бай→ са→ бай→"),
    phrase(5, "Нормально", "เรื่อยๆ", "рый→ рый→"),
    phrase(6, "Так себе", "ไม่ค่อยดี", "май→ кхой→ ди→"),
    phrase(7, "Всё супер", "สบายมาก", "са→ бай→ мак↘"),
    casual(8, "Всё ок", "โอเค", "о→ кэ→"),
]
B1.append(
    (
        lesson_meta(
            "course_b_1_l3",
            3,
            "Как дела?",
            "Сабай ди май и короткие ответы",
            3,
            "как дела?;са-бай-ди май↗",
            ["course_b_1_l2"],
            False,
            learnable_count(items),
        ),
        stepset("course_b_1", "course_b_1_l3", ["После приветствия почти всегда спрашивают сабай ди май."], items),
    )
)

# l4 requests
items = [
    tip(1, "Формула дня: кхо … ной / дай май? — вежливая просьба на всё."),
    tip(2, "Глаголы «хочу/могу/надо» как система — в курсе «Главные глаголы». Здесь только просьбы."),
    phrase(3, "Можно?", "ได้ไหม", "дай→ май↗"),
    phrase(4, "Можно воды?", "ขอน้ำหน่อย", "кхо→ нам→ ной→"),
    phrase(5, "Пожалуйста это", "ขออันนี้", "кхо→ ан→ ни↘"),
    phrase(6, "Хочу это", "อยากได้อันนี้", "яак→ дай→ ан→ ни↘"),
    phrase(7, "Без острого", "ไม่เผ็ดนะ", "май→ пхет→ на→", "На = мягкая просьба."),
    phrase(8, "Счёт пожалуйста", "เช็คบิล", "чек→ бин→"),
    phrase(9, "Пакет пожалуйста", "ถุงด้วย", "тхунг→ дуай↘"),
    phrase(10, "Ещё один", "เอาอีกอัน", "ау→ ик→ ан→"),
    phrase(11, "Не хочу", "ไม่อยากได้", "май→ яак→ дай↘"),
]
B1.append(
    (
        lesson_meta(
            "course_b_1_l4",
            4,
            "Просьбы",
            "Вода, счёт, без острого — формулы на кассе и в кафе",
            4,
            "можно воды?;кхо нам ной→",
            ["course_b_1_l3"],
            False,
            learnable_count(items),
        ),
        stepset("course_b_1", "course_b_1_l4", ["Кхо + что нужно + ной — звучит по-домашнему вежливо."], items),
    )
)

# l5 where survival
items = [
    tip(1, "Только «где тут» для выживания. Прямо/налево/цифры — в «Время, место, цифры»."),
    tip(2, "Покажи на карте и скажи ти-ни — часто понятнее слов."),
    phrase(3, "Где это?", "อยู่ที่ไหน", "ю→ ти→ най↗"),
    phrase(4, "Где туалет?", "ห้องน้ำอยู่ที่ไหน", "хонг→ нам→ ю→ ти→ най↗"),
    phrase(5, "Здесь", "ที่นี่", "ти→ ни↘", kind="word"),
    phrase(6, "Сюда пожалуйста", "มาที่นี่หน่อย", "маа→ ти→ ни→ ной→"),
    phrase(7, "Останови здесь", "จอดตรงนี้", "чот→ тронг→ ни↘", "Такси и байк-такси."),
]
B1.append(
    (
        lesson_meta(
            "course_b_1_l5",
            5,
            "Где тут?",
            "Туалет, здесь, останови — без полной навигации",
            3,
            "где туалет?;хонг-нам ю ти-най↗",
            ["course_b_1_l4"],
            False,
            learnable_count(items),
        ),
        stepset("course_b_1", "course_b_1_l5", ["Не учи сразу все стороны света — хватит «где» и «здесь»."], items),
    )
)

# l6 price micro
items = [
    tip(1, "Мини-набор для кассы. Описания «дорогой/дешёвый» в предложениях — в курсе про прилагательные."),
    phrase(2, "Сколько стоит?", "เท่าไหร่", "тао→ рай↗"),
    phrase(3, "Сколько за это?", "อันนี้เท่าไหร่", "ан→ ни→ тао→ рай↗"),
    phrase(4, "Дорого", "แพง", "пхэнг→"),
    phrase(5, "Можно скидку?", "ลดได้ไหม", "лот→ дай→ май↗"),
    phrase(6, "Картой можно?", "รับบัตรได้ไหม", "раб→ бат→ дай→ май↗"),
    phrase(7, "Ок беру", "โอเค เอา", "о→ кэ→ ау→"),
]
B1.append(
    (
        lesson_meta(
            "course_b_1_l6",
            6,
            "Цена",
            "Сколько, дорого, скидка, карта — день на рынке",
            3,
            "сколько стоит?;тао-рай↗",
            ["course_b_1_l5"],
            False,
            learnable_count(items),
        ),
        stepset("course_b_1", "course_b_1_l6", ["Скажи цену и улыбнись — часто дадут микро-скидку."], items),
    )
)

# l7 politeness
items = [
    tip(1, "Кхоп-кхун и кхо тхот — говори чаще, чем кажется нужным."),
    phrase(2, "Спасибо", "ขอบคุณ", "кхоп→ кхун→"),
    phrase(3, "Спасибо большое", "ขอบคุณมาก", "кхоп→ кхун→ мак↘"),
    phrase(4, "Извини", "ขอโทษ", "кхо→ тхот↘"),
    phrase(5, "Извините пожалуйста", "ขอโทษครับ", "кхо→ тхот→ кхрап↘"),
    phrase(6, "Ничего страшного", "ไม่เป็นไร", "май→ пэн→ рай→", "И «пожалуйста» после извинения, и «не за что»."),
    casual(7, "Сорри", "ขอโทษนะ", "кхо→ тхот→ на→"),
]
B1.append(
    (
        lesson_meta(
            "course_b_1_l7",
            7,
            "Спасибо и извини",
            "Вежливый минимум, без которого не обойтись",
            3,
            "спасибо;кхоп-кхун→",
            ["course_b_1_l6"],
            False,
            learnable_count(items),
        ),
        stepset("course_b_1", "course_b_1_l7", ["После старта собирай сцены в курсе «Диалоги как у местных»."], items),
    )
)


def replace_course_lessons(lessons_doc: dict, course_id: str, pairs: list[tuple[dict, dict]]) -> None:
    courses = lessons_doc["courses"]
    for i, c in enumerate(courses):
        if c["course_id"] == course_id:
            lessons = [p[0] for p in pairs]
            total_min = sum(l["duration_minutes"] for l in lessons)
            courses[i] = {
                "course_id": course_id,
                "course_title": c["course_title"],
                "lessons": lessons,
                "summary": {
                    "total_lessons": len(lessons),
                    "total_duration_minutes": total_min,
                },
            }
            return
    raise KeyError(course_id)


def upsert_stepsets(steps_doc: dict, course_id: str, pairs: list[tuple[dict, dict]], drop_prefix_extra: list[str] | None = None) -> None:
    keep_ids = {p[0]["lesson_id"] for p in pairs}
    new_sets = [p[1] for p in pairs]
    out = []
    for s in steps_doc["stepsets"]:
        lid = s["lesson_id"]
        cid = s.get("course_id", "")
        if cid == course_id or lid.startswith(course_id):
            continue  # drop old for this course
        if drop_prefix_extra and any(lid.startswith(x) for x in drop_prefix_extra):
            continue
        out.append(s)
    # insert new sets near start for readability: append then stable
    out.extend(new_sets)
    steps_doc["stepsets"] = out


def filter_items(ss: dict, drop_ru: set[str], extra_tips: list[str] | None = None) -> dict:
    drop = {r.strip().lower() for r in drop_ru}
    items = []
    for it in ss["items"]:
        if it.get("kind") in ("word", "phrase", "casual"):
            ru = (it.get("ru") or "").strip().lower()
            if ru in drop:
                continue
        items.append(it)
    if extra_tips:
        for t in extra_tips:
            items.insert(0, tip(0, t))
    ss = deepcopy(ss)
    ss["items"] = renumber(items)
    return ss


def patch_b3(steps_doc: dict) -> None:
    """b3 teaches pronouns/people — not a second intro course."""
    for s in steps_doc["stepsets"]:
        if s["lesson_id"] != "course_b_3_l1":
            continue
        new_items = [
            tip(1, "Имя и «я из России» уже в «Разговорном старте». Здесь — кто ты: ผม / ฉัน / คุณ."),
            tip(2, "Выбери один «я» и держись его. Тайцам важна стабильность."),
            word(3, "Я мужчина", "ผม", "пхом→", "Мужской «я»."),
            word(4, "Я женщина", "ฉัน", "чхан→", "Женский / нейтральный «я»."),
            word(5, "Ты вы", "คุณ", "кун→", "Безопасное обращение к взрослому."),
            word(6, "Мы", "เรา", "рао→"),
            word(7, "Он она", "เขา", "кхау→"),
            phrase(8, "Это мой друг", "นี่เพื่อนของฉัน", "ни→ пхыан→ кхонг→ чхан→"),
            phrase(9, "Это ты?", "คุณใช่ไหม", "кун→ чай→ май↗"),
        ]
        s["items"] = renumber(new_items)
        s["hints"] = ["После старта не повторяй знакомство — учи местоимения."]
        return


def patch_b6(steps_doc: dict) -> None:
    """Adjectives course: descriptive phrases, not a second price/food survival dump."""
    for s in steps_doc["stepsets"]:
        lid = s["lesson_id"]
        if lid == "course_b_6_l1":
            # taste system — keep unique descriptors, drop exact b1 survival lines
            s["items"] = renumber(
                [
                    tip(1, "«Без острого» как просьба — в старте. Здесь учим описывать вкус."),
                    tip(2, "Комбинируй с глаголами из «Главные глаголы»: кин + арой."),
                    word(3, "Вкусно", "อร่อย", "а→ рой→"),
                    word(4, "Остро", "เผ็ด", "пхет→"),
                    word(5, "Сладкий", "หวาน", "ваан→"),
                    phrase(6, "Очень вкусно", "อร่อยมาก", "а→ рой→ мак↘"),
                    phrase(7, "Мало остро", "เผ็ดน้อย", "пхет→ ной→"),
                    phrase(8, "Сделайте мало остро", "เผ็ดน้อยนะ", "пхет→ ной→ на→"),
                    phrase(9, "Не сладко", "ไม่หวาน", "май→ ваан→"),
                    phrase(10, "Сладкий кофе", "กาแฟหวาน", "ка→ фэ→ ваан→"),
                    phrase(11, "Вкусно очень", "อร่อยมากเลย", "а→ рой→ мак→ лёй→"),
                ]
            )
            s["hints"] = ["Описания оживляют речь. Не путай с просьбами из старта."]
        elif lid == "course_b_6_l2":
            s["items"] = renumber(
                [
                    tip(1, "Пхэнг/тук как торг на рынке — в старте. Здесь — описания вещей и мест."),
                    word(2, "Красиво", "สวย", "суай→"),
                    phrase(3, "Очень красиво", "สวยมาก", "суай→ мак↘"),
                    phrase(4, "Красивое место", "ที่สวย", "ти→ суай→"),
                    word(5, "Цена", "ราคา", "ра→ кха→"),
                    phrase(6, "Это дёшево", "อันนี้ถูก", "ан→ ни→ тук↘", "Уже знаешь тук — теперь в фразе."),
                    phrase(7, "Дешёвый отель", "โรงแรมถูก", "ронг→ рэм→ тук↘"),
                    phrase(8, "Дорогой телефон", "โทรศัพท์แพง", "тхо→ ра→ сап→ пхэнг→"),
                    phrase(9, "Слишком дорого для меня", "แพงไปสำหรับฉัน", "пхэнг→ пай→ сам→ рап→ чхан→"),
                ]
            )
            s["hints"] = ["Прилагательное + существительное = живая речь."]


def rebuild_b7(steps_doc: dict, lessons_doc: dict) -> None:
    """Scene synthesis: tips = dialog script; cards = only NEW lines."""
    scenes = [
        (
            "course_b_7_l1",
            1,
            "7-Eleven",
            "Собери привет + просьбу + спасибо из старта в один заход",
            "воды пожалуйста;кхо нам ной→",
            [
                tip(
                    1,
                    "Диалог: саватди кхрап → кхо нам ной → чек бин → кхоп кхун.\nПривет, счёт и спасибо уже из «Разговорного старта» — здесь только связка и новые реплики кассира.",
                ),
                phrase(2, "Воды пожалуйста", "ขอน้ำหน่อย", "кхо→ нам→ ной→", "Та же просьба, что в старте — вставь в сцену."),
                phrase(3, "Вот пожалуйста", "นี่ครับ", "ни→ кхрап↘", "Реплика кассира / тебя, когда отдаёшь."),
                phrase(4, "Пакет", "ถุง", "тхунг→"),
                phrase(5, "Готово", "เรียบร้อย", "риап→ рой→"),
                tip(6, "Не учи заново саватди и кхоп кхун — собери их в порядке очереди."),
            ],
            ["Сцена кассы: порядок важнее новых слов."],
        ),
        (
            "course_b_7_l2",
            2,
            "Кафе",
            "Заказ напитка: старт + новые реплики заказа",
            "ещё один кофе;ка-фэ ик кэу→",
            [
                tip(
                    1,
                    "Диалог: привет → заказ → «без острого» из старта → ещё кофе → чек бин → спасибо.\nНиже — только то, чего не было в survival.",
                ),
                word(2, "Заказ", "สั่ง", "санг→"),
                phrase(3, "Ещё один кофе", "กาแฟอีกแก้ว", "ка→ фэ→ ик→ кэу→"),
                phrase(4, "Ещё воды", "น้ำอีกแก้ว", "нам→ ик→ кэу→"),
                phrase(5, "Очень вкусно", "อร่อยมาก", "а→ рой→ мак↘"),
                tip(6, "«Без острого» и «счёт» уже в старте — вставь их между этими репликами."),
            ],
            ["Кафе = старт + 2–3 новых куска заказа."],
        ),
        (
            "course_b_7_l3",
            3,
            "Такси",
            "Место + повороты из курса цифр + «останови» из старта",
            "в аэропорт;пай санам-бин→",
            [
                tip(
                    1,
                    "Диалог: пай + место → тао рай (цена из старта) → прямо/налево (из «Время, место, цифры») → чот тронг ни.\nНиже — места и прощание.",
                ),
                phrase(2, "В аэропорт", "ไปสนามบิน", "пай→ са→ нам→ бин→"),
                phrase(3, "В отель", "ไปโรงแรม", "пай→ ронг→ рэм→"),
                phrase(4, "Налево", "เลี้ยวซ้าย", "лиау→ сай→"),
                phrase(5, "Направо", "เลี้ยวขวา", "лиау→ ква→"),
                phrase(6, "До свидания", "ลาก่อน", "ла→ кон→"),
                tip(6, "Прямо и «сколько стоит» не дублируем — они уже в базе раньше."),
            ],
            ["Такси: место + поворот + остановись."],
        ),
        (
            "course_b_7_l4",
            4,
            "Рынок",
            "Торг из старта + упаковка и количество",
            "упакуйте;хо хай ной→",
            [
                tip(
                    1,
                    "Диалог: ан ни тао рай → пхэнг → лот дай май → ок ау (всё из старта) → упакуйте / две штуки.\nНиже — только добор сцены.",
                ),
                phrase(2, "Две штуки", "สองอัน", "сон→ ан→"),
                phrase(3, "Упакуйте", "ห่อให้หน่อย", "хо→ хай→ ной→"),
                phrase(4, "Вот держите", "นี่ครับ", "ни→ кхрап↘"),
                tip(5, "Цену и скидку не учи заново — открой «Цена» в старте и собери сцену."),
            ],
            ["Рынок = старт (цена) + упаковка."],
        ),
        (
            "course_b_7_l5",
            5,
            "Сосед",
            "Знакомство из старта + люди из «Я, ты, он»",
            "семья;кхроп-кхруа→",
            [
                tip(
                    1,
                    "Диалог: саватди → имя/откуда (старт) → сабай ди май → семья / сосед.\nНиже — только «люди рядом», без второго знакомства с нуля.",
                ),
                word(2, "Семья", "ครอบครัว", "кхроп→ кхруа→"),
                phrase(3, "Я живу рядом", "ฉันอยู่แถวนี้", "чхан→ ю→ тхэу→ ни↘"),
                phrase(4, "Это сосед", "นี่เพื่อนบ้าน", "ни→ пхыан→ бан→"),
                phrase(5, "Давно здесь?", "อยู่ที่นี่นานหรือยัง", "ю→ ти→ ни→ нан→ ры→ янг→"),
                tip(6, "Имя и «я из России» уже в старте — не повторяй карточками."),
            ],
            ["Сосед = старт + люди, не клон знакомства."],
        ),
        (
            "course_b_7_l6",
            6,
            "Сборный день",
            "Время + куда + до встречи — финальная склейка базы",
            "до встречи;лэу джё кан→",
            [
                tip(
                    1,
                    "Собери день: который час (цифры) → куда идёшь → поехали → до встречи.\nСпасибо и «вкусно» уже были — не дублируем.",
                ),
                phrase(2, "Который час?", "กี่โมง", "ки→ монг→"),
                phrase(3, "Куда идёшь?", "ไปไหน", "пай→ най↗"),
                phrase(4, "Поехали", "ไปกัน", "пай→ кан→"),
                phrase(5, "Хороший день", "วันดี", "ван→ ди→"),
                phrase(6, "До встречи", "แล้วเจอกัน", "лэу→ джё→ кан→"),
                tip(7, "Это капстоун базы: если спотыкаешься — вернись в старт или цифры, не зубри заново здесь."),
            ],
            ["Финал базы — склейка, не новый словарь."],
        ),
    ]

    pairs = []
    for lid, order, title, subtitle, preview, items, hints in scenes:
        # fix duplicate order in taxi tip
        items = renumber(items)
        meta = lesson_meta(
            lid,
            order,
            title,
            subtitle,
            4,
            preview,
            [] if order == 1 else [f"course_b_7_l{order-1}" if order != 1 else ""],
            order <= 2,
            learnable_count(items),
        )
        if order == 1:
            meta["prerequisites"] = []
        elif order == 2:
            meta["prerequisites"] = ["course_b_7_l1"]
        else:
            meta["prerequisites"] = [f"course_b_7_l{order-1}"]
        pairs.append((meta, stepset("course_b_7", lid, hints, items)))

    # fix l3 prereq chain ids: l1,l2,l3,l4,l5,l6 — already set
    replace_course_lessons(lessons_doc, "course_b_7", pairs)
    # update titles in lessons course_title
    for c in lessons_doc["courses"]:
        if c["course_id"] == "course_b_7":
            c["course_title"] = "Диалоги как у местных"
    upsert_stepsets(steps_doc, "course_b_7", pairs)


def build_b0(lessons_doc: dict, steps_doc: dict) -> None:
    """Ship minimal theory-bonus course so catalog isn't empty."""
    pairs = []
    specs = [
        (
            "course_b_0_l1",
            1,
            "Тоны не страшны",
            "Пять мелодий — зачем они тебе",
            [
                tip(1, "В тайском высота голоса меняет слово. Это не «акцент» — это смысл."),
                tip(2, "Не учи тоны отдельно от слов: бери фразы из старта и слушай мелодию."),
                tip(3, "Дальше курс «Магия интонации» даст уши. Здесь — только спокойствие."),
            ],
        ),
        (
            "course_b_0_l2",
            2,
            "Кха и кхрап",
            "Вежливые хвостики без паники",
            [
                tip(1, "Кхрап — чаще у мужчин, кха — у женщин. Это вежливость, не «обязательный пол»."),
                tip(2, "В старте уже есть саватди кхрап. Повтори вслух 5 раз — привыкнет рот."),
                tip(3, "Если не уверен — улыбка + короткое саватди. Работает."),
            ],
        ),
        (
            "course_b_0_l3",
            3,
            "Как учить без выгорания",
            "Короткие сессии, голос, уличные сцены",
            [
                tip(1, "10–15 минут вслух лучше часа «глазами»."),
                tip(2, "Путь базы: старт → тоны → люди/цифры/глаголы → сцены в диалогах."),
                tip(3, "Не зубри два курса с одними и теми же фразами — у каждого курса своя работа."),
            ],
        ),
    ]
    for lid, order, title, subtitle, items in specs:
        items = renumber(items)
        meta = lesson_meta(
            lid,
            order,
            title,
            subtitle,
            2,
            "лайфхак;теория",
            [] if order == 1 else [f"course_b_0_l{order-1}"],
            True,
            0,
        )
        pairs.append((meta, stepset("course_b_0", lid, ["Теория без карточек на заучивание."], items)))

    # insert or replace in lessons
    entry = {
        "course_id": "course_b_0",
        "course_title": "Тайский без паники",
        "lessons": [p[0] for p in pairs],
        "summary": {"total_lessons": 3, "total_duration_minutes": 6},
    }
    found = False
    for i, c in enumerate(lessons_doc["courses"]):
        if c["course_id"] == "course_b_0":
            lessons_doc["courses"][i] = entry
            found = True
            break
    if not found:
        lessons_doc["courses"].insert(0, entry)
    upsert_stepsets(steps_doc, "course_b_0", pairs)


def update_catalog(catalog: list) -> list:
    by_id = {c["id"]: c for c in catalog}
    order = [
        "course_b_0",
        "course_b_1",
        "course_b_2",
        "course_b_3",
        "course_b_4",
        "course_b_5",
        "course_b_6",
        "course_b_7",
    ]
    # patch meta
    patches = {
        "course_b_0": {
            "lesson_count": 3,
            "duration_minutes": 6,
            "description": "Короткая теория перед практикой: тоны, вежливость, как учить без паники.",
            "short_description": "Спокойный вход в базу",
        },
        "course_b_1": {
            "lesson_count": 7,
            "duration_minutes": 22,
            "description": "Survival на первые дни: привет, имя, как дела, просьбы, где тут, цена, спасибо. Без грамматического свалки.",
            "short_description": "Что сказать в первый день",
        },
        "course_b_2": {
            "description": "Тоны и мелодия на уже знакомых фразах из старта. Не второй словарь — уши.",
            "short_description": "Слушай тон, не зубри заново",
        },
        "course_b_3": {
            "description": "Местоимения и люди. Знакомство уже в старте — здесь «кто я / кто ты».",
            "short_description": "Я, ты, он — без повтора старта",
        },
        "course_b_4": {
            "description": "Числа, время, прямо/налево. Навигация системно — после survival «где тут».",
            "short_description": "Считать и ориентироваться",
        },
        "course_b_5": {
            "description": "Главные глаголы как строительные блоки. Просьбы из старта сюда не копируем.",
            "short_description": "Глагольный каркас",
        },
        "course_b_6": {
            "description": "Описания: вкусно, красиво, дешёвый отель. Торг и «без острого» — в старте.",
            "short_description": "Описывать, не торговаться снова",
        },
        "course_b_7": {
            "lesson_count": 6,
            "duration_minutes": 24,
            "description": "Сцены 7-Eleven, кафе, такси, рынок, сосед. Собираешь старт и блоки — без копипаста одних и тех же фраз.",
            "short_description": "Склейка базы в диалоги",
        },
    }
    for cid, patch in patches.items():
        if cid in by_id:
            by_id[cid].update(patch)

    base = [by_id[i] for i in order if i in by_id]
    rest = [c for c in catalog if c["id"] not in order]
    # keep relative order of rest as before, but ensure base block first
    # original file mixed base in middle — put all base first then others excluding base
    rest = [c for c in catalog if not str(c.get("id", "")).startswith("course_b_")]
    return base + rest


def sync_card_counts(lessons_doc: dict, steps_doc: dict) -> None:
    by_lesson = {s["lesson_id"]: s for s in steps_doc["stepsets"]}
    for c in lessons_doc["courses"]:
        if not str(c["course_id"]).startswith("course_b_"):
            continue
        total = 0
        mins = 0
        for les in c["lessons"]:
            ss = by_lesson.get(les["lesson_id"])
            if ss:
                n = learnable_count(ss["items"])
                les["card_count"] = n
                total += n
            mins += int(les.get("duration_minutes") or 0)
        c["summary"] = {
            "total_lessons": len(c["lessons"]),
            "total_duration_minutes": mins,
        }


def cleanup_residual_overlaps(steps_doc: dict) -> None:
    """Remove leftover exact dumps that still collide with slim b1."""
    for s in steps_doc["stepsets"]:
        lid = s["lesson_id"]
        if lid == "course_b_3_l6":
            s["items"] = [
                it
                for it in s["items"]
                if (it.get("ru") or "").strip().lower() != "очень приятно"
            ]
            s["items"].append(
                tip(
                    99,
                    "«Очень приятно» уже в старте — здесь собирай мини-диалог из местоимений и семьи.",
                )
            )
            s["items"] = renumber(s["items"])
        elif lid == "course_b_4_l5":
            s["items"] = [
                it
                for it in s["items"]
                if (it.get("ru") or "").strip().lower() != "останови здесь"
            ]
            s["items"] = renumber(s["items"])
        elif lid == "course_b_6_l5":
            for it in s["items"]:
                if (it.get("ru") or "").strip().lower() == "нормально" and it.get("thai") == "ปกติ":
                    it["ru"] = "Обычный"
                    it["tip"] = "Не путать с «нормально» (рый-рый) из small talk в старте."


def main() -> None:
    lessons_doc = json.loads(LESSONS_PATH.read_text(encoding="utf-8"))
    steps_doc = json.loads(STEPS_PATH.read_text(encoding="utf-8"))
    catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))

    # b1 full replace
    replace_course_lessons(lessons_doc, "course_b_1", B1)
    for c in lessons_doc["courses"]:
        if c["course_id"] == "course_b_1":
            c["course_title"] = "Разговорный старт"
    upsert_stepsets(steps_doc, "course_b_1", B1)

    build_b0(lessons_doc, steps_doc)
    patch_b3(steps_doc)
    patch_b6(steps_doc)
    rebuild_b7(steps_doc, lessons_doc)
    cleanup_residual_overlaps(steps_doc)

    # b2: clarify role via hint on first lesson
    for s in steps_doc["stepsets"]:
        if s["lesson_id"] == "course_b_2_l1":
            hints = s.get("hints") or []
            note = "Фразы могут быть знакомы из старта — здесь работаем тоном, не словарём."
            if note not in hints:
                s["hints"] = [note] + list(hints)
            break

    # b4 tip on directions lesson if exists
    for s in steps_doc["stepsets"]:
        if s["lesson_id"] in ("course_b_4_l5", "course_b_4_l4"):
            # add tip at start if not present
            texts = [it.get("text") for it in s["items"] if it.get("kind") == "tip"]
            note = "«Останови здесь» уже в старте. Здесь — полная навигация: прямо, налево, направо."
            if note not in texts:
                s["items"] = renumber([tip(0, note)] + s["items"])
            break

    sync_card_counts(lessons_doc, steps_doc)
    catalog = update_catalog(catalog)

    # sync catalog lesson_count from lessons summary
    lessons_by_id = {c["course_id"]: c for c in lessons_doc["courses"]}
    for c in catalog:
        cid = c["id"]
        if cid in lessons_by_id:
            sm = lessons_by_id[cid].get("summary") or {}
            if "total_lessons" in sm:
                c["lesson_count"] = sm["total_lessons"]
            if "total_duration_minutes" in sm:
                c["duration_minutes"] = sm["total_duration_minutes"]

    LESSONS_PATH.write_text(json.dumps(lessons_doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    STEPS_PATH.write_text(json.dumps(steps_doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    CATALOG_PATH.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    # report overlaps
    by_c = {}
    for s in steps_doc["stepsets"]:
        cid = s.get("course_id") or ""
        if not cid.startswith("course_b_"):
            continue
        by_c.setdefault(cid, set())
        for it in s["items"]:
            if it.get("kind") in ("word", "phrase", "casual") and it.get("ru"):
                by_c[cid].add(it["ru"].strip().lower())

    print("Base learnable counts:")
    for cid in sorted(by_c):
        print(f"  {cid}: {len(by_c[cid])}")
    b1 = by_c.get("course_b_1", set())
    print("\nOverlaps with b1:")
    for cid in sorted(by_c):
        if cid == "course_b_1":
            continue
        ov = sorted(b1 & by_c[cid])
        print(f"  {cid}: {len(ov)} -> {ov[:12]}")


if __name__ == "__main__":
    main()
