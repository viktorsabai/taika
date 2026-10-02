#!/usr/bin/env python3
"""Base P1/P2 polish: B0 tones→Magiya, B4 preps, B5 particles, B6 states, B7 conjunctions."""
from __future__ import annotations

import json
from pathlib import Path

from fix_phonetic_tones import load_retone, retone_steps

ROOT = Path(__file__).resolve().parents[1]
STEPS = ROOT / "steps.json"
LESSONS = ROOT / "lessons.json"
CATALOG = ROOT / "taika" / "Resourses" / "taika_basa_course.json"


def tip(order: int, headline: str, body: str) -> dict:
    return {"order": order, "kind": "tip", "tip": headline, "text": body}


def word(order: int, ru: str, thai: str, phonetic: str, hint: str) -> dict:
    return {"order": order, "kind": "word", "ru": ru, "thai": thai, "phonetic": phonetic, "tip": hint}


def phrase(order: int, ru: str, thai: str, phonetic: str, hint: str) -> dict:
    return {"order": order, "kind": "phrase", "ru": ru, "thai": thai, "phonetic": phonetic, "tip": hint}


def casual(order: int, ru: str, thai: str, phonetic: str, hint: str) -> dict:
    return {"order": order, "kind": "casual", "ru": ru, "thai": thai, "phonetic": phonetic, "tip": hint}


def renumber(items: list[dict]) -> list[dict]:
    out = []
    for i, it in enumerate(items, 1):
        x = dict(it)
        x["order"] = i
        out.append(x)
    return out


def find_ss(doc: dict, lesson_id: str) -> dict:
    for s in doc["stepsets"]:
        if s["lesson_id"] == lesson_id:
            return s
    raise KeyError(lesson_id)


def find_course(doc: dict, course_id: str) -> dict:
    for c in doc["courses"]:
        if c["course_id"] == course_id:
            return c
    raise KeyError(course_id)


def upsert_lesson(course: dict, lesson: dict) -> None:
    lessons = course["lessons"]
    for i, l in enumerate(lessons):
        if l["lesson_id"] == lesson["lesson_id"]:
            lessons[i] = lesson
            return
    lessons.append(lesson)
    lessons.sort(key=lambda x: x["order"])


def insert_stepset_after(doc: dict, after_lesson_id: str, new_ss: dict) -> None:
    # remove if exists
    doc["stepsets"] = [s for s in doc["stepsets"] if s["lesson_id"] != new_ss["lesson_id"]]
    out = []
    placed = False
    for s in doc["stepsets"]:
        out.append(s)
        if s["lesson_id"] == after_lesson_id:
            out.append(new_ss)
            placed = True
    if not placed:
        raise SystemExit(f"after {after_lesson_id} not found")
    doc["stepsets"] = out


def lesson_meta(
    course_id: str,
    n: int,
    title: str,
    subtitle: str,
    minutes: int,
    cards: int,
    free: bool,
    preview: str,
    intro: str,
    outline: str,
    apply: str,
    outcome: str,
    prereq: str,
) -> dict:
    return {
        "lesson_id": f"{course_id}_l{n}",
        "order": n,
        "title": title,
        "subtitle": subtitle,
        "duration_minutes": minutes,
        "card_count": cards,
        "is_free": free,
        "tags": [],
        "preview_phrase": preview,
        "content": [
            {"kind": "intro", "text": intro},
            {"kind": "outline", "text": outline},
            {"kind": "apply", "text": apply},
        ],
        "outcomes": [outcome],
        "prerequisites": [prereq],
        "links": {
            "steps_ref": f"{course_id}_l{n}_steps",
            "hometask_ref": f"{course_id}_l{n}_home",
        },
        "assistant_tips": [],
    }


def patch_b0(steps: dict, lessons: dict) -> None:
    ss = find_ss(steps, "course_b_0_l2")
    ss["hints"] = [
        "Тон меняет смысл. Детали — в курсе «Магия интонации».",
    ]
    ss["items"] = renumber(
        [
            tip(
                1,
                "Тон — часть слова",
                "В тайском мелодия слога может менять значение. Одной «правильной буквы» мало — важен голос.",
            ),
            tip(
                2,
                "Пока достаточно трёх движений",
                "Ровно, вверх, вниз. Названия всех тонов учить не нужно. Стрелки в карточках — твоя подсказка.",
            ),
            tip(
                3,
                "Дальше — «Магия интонации»",
                "Этот урок только ориентир. Разницу «собака / лошадь / приходить» и другие пары разбирает курс **Магия интонации**. Если тон сбил — повтори медленнее, не молчи.",
            ),
        ]
    )
    course = find_course(lessons, "course_b_0")
    for l in course["lessons"]:
        if l["lesson_id"] == "course_b_0_l2":
            l["card_count"] = 3
            l["subtitle"] = "Короткий ориентир. Пары и тренировка — в Магии интонации."
            l["content"] = [
                {"kind": "intro", "text": "Только карта: тон меняет смысл. Не фонетический тренажёр."},
                {"kind": "outline", "text": "Тон = смысл · три движения · дальше Magiya."},
                {"kind": "apply", "text": "Запомни: сначала услышь стрелку, детали — в следующем tone-курсе."},
            ]
            l["outcomes"] = ["Понять, что тон часть слова, и знать, куда идти за тренировкой."]
            break
    course["summary"] = {
        "total_lessons": 3,
        "total_duration_minutes": sum(l["duration_minutes"] for l in course["lessons"]),
    }


def patch_b4(steps: dict, lessons: dict) -> None:
    # soft-recycle tip on L5
    ss5 = find_ss(steps, "course_b_4_l5")
    for it in ss5["items"]:
        if it.get("kind") == "tip":
            it["tip"] = "Навигация, не тон"
            it["text"] = (
                "В такси: **тронг пай** + палец. **Близко/далеко** ты уже слышал в Магии интонации как пару тонов — "
                "здесь это просто «рядом или нет»."
            )
        if it.get("thai") in ("ใกล้", "ไกลไหม", "ใกล้ๆ ตรงนี้"):
            it["tip"] = "Уже был тон в Magiya. Здесь — расстояние в такси/пешком."
    # new L7 prepositions
    items = renumber(
        [
            tip(
                1,
                "Предлог ставит вещь в пространство",
                "После глагола часто идёт маленькое слово места: **в / на / из / с / до**. Это не новый survival-курс — карта пространства для цифр и навигации.",
            ),
            word(2, "В", "ใน", "най→", "Внутри. В доме, в сумке, в Таиланде."),
            word(3, "На", "บน", "бон→", "На поверхности. На столе, на полке."),
            word(4, "Под", "ใต้", "тай→", "Под. Под столом, под домом."),
            word(5, "Из от", "จาก", "джак→", "Из/от. Уже мелькало в «откуда» — теперь само слово."),
            word(6, "С с кем", "กับ", "кап→", "С (с кем/с чем). С другом, с рисом."),
            word(7, "До", "ถึง", "тхынг→", "До места/момента. До рынка, до двух."),
            phrase(8, "В доме", "ในบ้าน", "най→ баан→", "В + дом."),
            phrase(9, "На столе", "บนโต๊ะ", "бон→ то→", "На + стол."),
            phrase(10, "Из России", "จากรัสเซีย", "джак→ рас→ сиа→", "Из + страна. Не повтор «я из» целиком из старта."),
            phrase(11, "С другом", "กับเพื่อน", "кап→ пхыан→", "С + друг."),
            phrase(12, "До рынка", "ถึงตลาด", "тхынг→ та→ лат→", "До + рынок."),
        ]
    )
    new_ss = {
        "id": "course_b_4_l7_steps",
        "course_id": "course_b_4",
        "lesson_id": "course_b_4_l7",
        "hints": [
            "В / на / из / с / до — карта пространства.",
            "Не зубри отдельно от навигации: стыкуй с «прямо/налево».",
        ],
        "items": items,
    }
    insert_stepset_after(steps, "course_b_4_l6", new_ss)

    course = find_course(lessons, "course_b_4")
    # update L5 meta soft
    for l in course["lessons"]:
        if l["lesson_id"] == "course_b_4_l5":
            l["subtitle"] = "Навигация пешком и в такси. Близко/далеко — уже из Magiya."
    upsert_lesson(
        course,
        lesson_meta(
            "course_b_4",
            7,
            "Где именно",
            "В, на, из, с, до — короткая карта пространства.",
            4,
            12,
            False,
            "В;най→",
            "Предлоги места без нового survival-словаря.",
            "в · на · под · из · с · до · в доме · на столе · с другом.",
            "Скажи «в доме», «на столе», «с другом», «до рынка».",
            "Поставить вещь или человека в пространство: в/на/из/с/до.",
            "course_b_4_l5",
        ),
    )
    course["description"] = (
        "Числа, время, дни, навигация и предлоги места — чтобы договориться в Таиланде без догадок."
    )
    course["summary"] = {
        "total_lessons": len(course["lessons"]),
        "total_duration_minutes": sum(l["duration_minutes"] for l in course["lessons"]),
    }


def rebuild_b5_lesson(ss: dict, tip_headline: str, tip_body: str, extras: list[dict], drop_thai: set[str] | None = None) -> None:
    drop_thai = set(drop_thai or set())
    drop_thai |= {it.get("thai") for it in extras if it.get("thai")}
    kept = []
    for it in ss["items"]:
        if it.get("kind") == "tip":
            continue
        if it.get("thai") in drop_thai:
            continue
        kept.append(it)
    for it in kept:
        if it.get("thai") == "ไม่อยาก":
            it["phonetic"] = "май↘ яак↘"
            it["tip"] = "май↘ + яак. Отрицание перед хотеть."
    extra_thais = {it.get("thai") for it in extras if it.get("thai")}
    items = [tip(1, tip_headline, tip_body)] + extras + kept
    seen = set()
    uniq = []
    for it in items:
        th = it.get("thai")
        key = th if th else ("tip:" + (it.get("tip") or ""))
        if key in seen:
            continue
        seen.add(key)
        uniq.append(it)
    if len(uniq) > 13:
        head = uniq[: 1 + len(extras)]
        rest = [it for it in uniq[1 + len(extras) :] if it.get("thai") not in extra_thais]
        uniq = head + rest
        uniq = uniq[:13]
    ss["items"] = renumber(uniq)


def patch_b5(steps: dict, lessons: dict) -> None:
    rebuild_b5_lesson(
        find_ss(steps, "course_b_5_l1"),
        "Глагол + май / джа / лэу",
        "Тот же **пай/маа**. **май пай** — не иду. **джа пай** — собираюсь. **маа лэу** — уже пришёл. Частицы из B0 — теперь на живых глаголах.",
        [
            phrase(0, "Не иду", "ไม่ไป", "май↘ пай→", "Отрицание перед глаголом."),
            phrase(0, "Собираюсь идти", "จะไป", "джа→ пай→", "Джа = буду/собираюсь."),
            phrase(0, "Уже пришёл", "มาแล้ว", "маа→ лэу→", "Лэу = уже/готово."),
        ],
    )
    rebuild_b5_lesson(
        find_ss(steps, "course_b_5_l2"),
        "Хотеть и любить с частицами",
        "**май яак** — не хочу. **джа кин** — буду есть. **чоп лэу** — уже нравится / ладно, беру по вкусу ситуации.",
        [
            phrase(0, "Буду есть", "จะกิน", "джа→ кин→", "Джа + есть."),
            phrase(0, "Уже хочу", "อยากแล้ว", "яак↘ лэу→", "Хотеть + уже."),
        ],
        drop_thai={"ต้องได้น้ำ"},  # awkward
    )
    rebuild_b5_lesson(
        find_ss(steps, "course_b_5_l3"),
        "Говорить и понимать с частицами",
        "**май кау-джай** уже знаешь. Добавь **джа пхуут** — скажу, и **кау-джай лэу** — понял.",
        [
            phrase(0, "Сейчас скажу", "จะพูด", "джа→ пхуут→", "Джа + говорить."),
            phrase(0, "Уже сказал", "พูดแล้ว", "пхуут→ лэу→", "Говорить + уже."),
        ],
        drop_thai={"พูดอีกที"},  # close to B1 repair; keep space
    )
    rebuild_b5_lesson(
        find_ss(steps, "course_b_5_l4"),
        "Есть и покупать с частицами",
        "**кин лэу** — уже ел. **май кин** — не ем. **джа сы** — куплю.",
        [
            phrase(0, "Не ем", "ไม่กิน", "май↘ кин→", "Отрицание + есть."),
            phrase(0, "Куплю", "จะซื้อ", "джа→ сы→", "Джа + покупать."),
            phrase(0, "Уже ел", "กินแล้ว", "кин→ лэу→", "Есть + уже."),
        ],
        drop_thai={"กินต้ม", "ฉันกินแล้ว"},
    )
    rebuild_b5_lesson(
        find_ss(steps, "course_b_5_l5"),
        "Делать и работать с частицами",
        "**май там** — не делаю. **джа пхак** — отдохну. **там лэу** — уже сделал.",
        [
            phrase(0, "Не делаю", "ไม่ทำ", "май↘ там→", "Отрицание + делать."),
            phrase(0, "Отдохну", "จะพัก", "джа→ пхак↘", "Джа + отдыхать."),
            phrase(0, "Уже сделал", "ทำแล้ว", "там→ лэу→", "Делать + уже."),
        ],
        drop_thai={"ทำการบ้าน", "ทำงานบ้าน"},
    )
    rebuild_b5_lesson(
        find_ss(steps, "course_b_5_l6"),
        "Спать и брать с частицами",
        "**май ау** — не беру. **джа нон** — пойду спать. **нон лэу** — уже сплю/лёг.",
        [
            phrase(0, "Пойду спать", "จะนอน", "джа→ нон→", "Джа + спать."),
            phrase(0, "Уже сплю", "นอนแล้ว", "нон→ лэу→", "Спать + уже."),
        ],
        drop_thai={"นอนเร็ว"},
    )
    rebuild_b5_lesson(
        find_ss(steps, "course_b_5_l7"),
        "Знать и видеть с частицами",
        "**май руу / май хэн** уже есть. Добавь **джа ю** — буду жить/останусь, и **руу лэу** — уже знаю.",
        [
            phrase(0, "Останусь здесь", "จะอยู่ที่นี่", "джа→ ю→ ти→ ни→", "Джа + жить/быть."),
            phrase(0, "Уже знаю", "รู้แล้ว", "руу↘ лэу→", "Знать + уже."),
        ],
        drop_thai={"เห็นแล้ว"},  # replaced by รู้แล้ว pattern; keep ไม่เห็น
    )

    course = find_course(lessons, "course_b_5")
    for l in course["lessons"]:
        ss = find_ss(steps, l["lesson_id"])
        l["card_count"] = len(ss["items"])
    course["description"] = (
        "Главные глаголы и частицы вокруг них: не / буду / уже — конструктор коротких фраз."
    )
    course["summary"] = {
        "total_lessons": len(course["lessons"]),
        "total_duration_minutes": sum(l["duration_minutes"] for l in course["lessons"]),
    }


def patch_b6(steps: dict, lessons: dict) -> None:
    # fix ใหม่ recycle + correct low tone
    ss6 = find_ss(steps, "course_b_6_l6")
    for it in ss6["items"]:
        if it.get("thai") == "ใหม่":
            it["phonetic"] = "май↓"
            it["tip"] = "Тон из Magiya: май↓ «новый». Здесь — прилагательное, не вопрос."
        if it.get("kind") == "tip" and "เร็ว" in (it.get("text") or ""):
            it["tip"] = "Быстрый и новый"
            it["text"] = (
                "**เร็ว** — и «быстрый», и «быстро». **ใหม่** ты уже отличал от «не» в Magiya — здесь просто описание вещи."
            )

    items = renumber(
        [
            tip(
                1,
                "Состояние — тоже описание",
                "Не междометия «ой/вау», а слова про себя: рад, грустно, весело, скучно, боюсь. Так отвечают на «как дела?» глубже, чем «норм».",
            ),
            word(2, "Рад", "ดีใจ", "ди→ джай→", "Рад/рада. Уже мелькало в «рад встрече» — само слово."),
            word(3, "Грустно", "เสียใจ", "сиа→ джай→", "Жалко / грустно / сочувствую."),
            word(4, "Весело", "สนุก", "са→ нук→", "Весело / интересно."),
            word(5, "Скучно", "เบื่อ", "быа→", "Скучно / надоело."),
            word(6, "Боюсь", "กลัว", "глуа→", "Боюсь / страшно."),
            word(7, "Злюсь", "โกรธ", "грот→", "Злюсь. Осторожно в сервисе — лучше мягче."),
            phrase(8, "Я рад", "ฉันดีใจ", "чхан→ ди→ джай→", "Состояние + я."),
            phrase(9, "Мне скучно", "ฉันเบื่อ", "чхан→ быа→", "Коротко про себя."),
            phrase(10, "Боюсь собаки", "กลัวหมา", "глуа→ маа↗", "Боюсь + собака. маа↗ из Magiya."),
            phrase(11, "Очень весело", "สนุกมาก", "са→ нук→ мак↘", "Весело + очень."),
            casual(12, "Жалко", "เสียใจด้วย", "сиа→ джай→ дуай→", "Сочувствую. Тёплая реакция."),
        ]
    )
    new_ss = {
        "id": "course_b_6_l7_steps",
        "course_id": "course_b_6",
        "lesson_id": "course_b_6_l7",
        "hints": [
            "Состояния, не возгласы.",
            "Для «как дела?» глубже, чем «норм».",
        ],
        "items": items,
    }
    insert_stepset_after(steps, "course_b_6_l6", new_ss)

    course = find_course(lessons, "course_b_6")
    upsert_lesson(
        course,
        lesson_meta(
            "course_b_6",
            7,
            "Рад, скучно, боюсь",
            "Состояния для жизни — не междометия.",
            4,
            12,
            False,
            "Рад;ди→ джай→",
            "Описываем себя: рад, грустно, весело, скучно, боюсь.",
            "рад · грустно · весело · скучно · боюсь · злюсь · жалко.",
            "Ответь на «как дела?» одним состоянием.",
            "Сказать, как себя чувствуешь, одним коротким словом или фразой.",
            "course_b_6_l5",
        ),
    )
    course["description"] = (
        "Описываем еду, вещи, цену, размер и своё состояние в бытовых ситуациях."
    )
    course["summary"] = {
        "total_lessons": len(course["lessons"]),
        "total_duration_minutes": sum(l["duration_minutes"] for l in course["lessons"]),
    }


def patch_b7(steps: dict, lessons: dict) -> None:
    items = renumber(
        [
            tip(
                1,
                "Маленькие слова склеивают фразу",
                "**и / но / или / потому что / если** — не новый разговорный курс. Это клей для фраз, которые ты уже знаешь из Базы.",
            ),
            word(2, "И", "และ", "лэ→", "И. Коротко между словами."),
            word(3, "Но", "แต่", "тэ→", "Но / однако."),
            word(4, "Или", "หรือ", "ры→", "Или. Уже мелькало в «уже ел?» — само слово."),
            word(5, "Потому что", "เพราะ", "пхро→", "Потому что."),
            word(6, "Если", "ถ้า", "та→", "Если."),
            phrase(7, "Рис и курица", "ข้าวและไก่", "кхаау↘ лэ→ кай↓", "И между едой."),
            phrase(8, "Хочу но устал", "อยากแต่เหนื่อย", "яак↘ тэ→ ныа↘", "Но между желанием и состоянием."),
            phrase(9, "Кофе или чай?", "กาแฟหรือชา", "ка→ фэ→ ры→ чаа→", "Или в выборе."),
            phrase(10, "Потому что жарко", "เพราะร้อน", "пхро→ рон↘", "Потому что + жарко."),
            phrase(11, "Если свободен", "ถ้าว่าง", "та→ ваанг→", "Если + свободен из смолтока."),
            casual(12, "Но ладно", "แต่ก็ได้", "тэ→ го→ дай→", "Мягкий разворот: но ок."),
        ]
    )
    new_ss = {
        "id": "course_b_7_l7_steps",
        "course_id": "course_b_7",
        "lesson_id": "course_b_7_l7",
        "hints": [
            "И / но / или / потому что / если.",
            "Склеивай уже знакомые куски Базы.",
        ],
        "items": items,
    }
    insert_stepset_after(steps, "course_b_7_l6", new_ss)

    course = find_course(lessons, "course_b_7")
    upsert_lesson(
        course,
        lesson_meta(
            "course_b_7",
            7,
            "И, но, потому что",
            "Клей для фраз: и / но / или / потому что / если.",
            4,
            12,
            False,
            "И;лэ→",
            "Финал склейки: маленькие союзы без нового быта.",
            "и · но · или · потому что · если · рис и курица · если свободен.",
            "Склей две знакомые мысли через «но» или «потому что».",
            "Соединить две короткие идеи союзом без нового словаря темы.",
            "course_b_7_l6",
        ),
    )
    course["description"] = (
        "Финал базы: смолток как у местных плюс склейка фраз союзами."
    )
    course["summary"] = {
        "total_lessons": len(course["lessons"]),
        "total_duration_minutes": sum(l["duration_minutes"] for l in course["lessons"]),
    }


def patch_catalog(steps: dict, lessons: dict) -> None:
    cat = json.loads(CATALOG.read_text(encoding="utf-8"))

    def counts(cid: str) -> tuple[int, int, int]:
        c = find_course(lessons, cid)
        n_lessons = len(c["lessons"])
        n_cards = sum(len(find_ss(steps, l["lesson_id"])["items"]) for l in c["lessons"])
        mins = sum(l["duration_minutes"] for l in c["lessons"])
        return n_lessons, n_cards, mins

    updates = {
        "course_b_0": {
            "description": "Карта тайского без паники: логика языка, частицы и короткий мост к тонам.",
            "short_description": "Карта языка без страха",
            "learning_outcomes": [
                {"type": "Логика языка", "count": 10},
                {"type": "Тоны — ориентир", "count": 3},
                {"type": "Живое общение", "count": 9},
            ],
        },
        "course_b_4": {
            "description": "Числа, время, дни, навигация и предлоги места.",
            "short_description": "Числа, место, предлоги",
            "learning_outcomes": [
                {"type": "Числа", "count": 25},
                {"type": "Время и дни", "count": 15},
                {"type": "Место и предлоги", "count": 18},
            ],
        },
        "course_b_5": {
            "description": "Главные глаголы плюс не / буду / уже вокруг них.",
            "short_description": "Глаголы и частицы",
            "learning_outcomes": [
                {"type": "Глаголы", "count": 20},
                {"type": "Частицы", "count": 15},
                {"type": "Фразы", "count": 40},
            ],
        },
        "course_b_6": {
            "description": "Описания еды, вещей и своего состояния.",
            "short_description": "Описания и состояния",
            "learning_outcomes": [
                {"type": "Описания", "count": 30},
                {"type": "Состояния", "count": 10},
                {"type": "Фразы", "count": 20},
            ],
        },
        "course_b_7": {
            "description": "Смолток как у местных и склейка фраз союзами.",
            "short_description": "Смолток и склейка",
            "learning_outcomes": [
                {"type": "Смолток", "count": 40},
                {"type": "Союзы", "count": 10},
                {"type": "Фразы", "count": 12},
            ],
        },
    }
    for course in cat:
        cid = course.get("id")
        if cid in updates:
            n_lessons, _, mins = counts(cid)
            course["lesson_count"] = n_lessons
            course["duration_minutes"] = mins
            course.update(updates[cid])
    CATALOG.write_text(json.dumps(cat, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def sync_card_counts(steps: dict, lessons: dict) -> None:
    for cid in ["course_b_0", "course_b_4", "course_b_5", "course_b_6", "course_b_7"]:
        course = find_course(lessons, cid)
        for l in course["lessons"]:
            l["card_count"] = len(find_ss(steps, l["lesson_id"])["items"])
        course["summary"] = {
            "total_lessons": len(course["lessons"]),
            "total_duration_minutes": sum(x["duration_minutes"] for x in course["lessons"]),
        }


def validate(steps: dict, lessons: dict) -> None:
    b1 = set()
    for s in steps["stepsets"]:
        if s["course_id"] == "course_b_1":
            for it in s["items"]:
                if it.get("thai"):
                    b1.add(it["thai"])
    # new lessons should not clone B1 greeting block
    ban = {"สวัสดี", "คุณชื่ออะไร", "คุณมาจากไหน", "ขอบคุณ", "เท่าไหร่"}
    for cid in ["course_b_4", "course_b_5", "course_b_6", "course_b_7"]:
        th = {it.get("thai") for s in steps["stepsets"] if s["course_id"] == cid for it in s["items"]}
        hit = ban & th
        # เท่าไหร่ only ok in b1; ensure new lessons don't add it
        assert not hit, (cid, hit)
    for cid in ["course_b_0", "course_b_4", "course_b_5", "course_b_6", "course_b_7"]:
        course = find_course(lessons, cid)
        for l in course["lessons"]:
            ss = find_ss(steps, l["lesson_id"])
            assert l["card_count"] == len(ss["items"]), (l["lesson_id"], l["card_count"], len(ss["items"]))
            orders = [it["order"] for it in ss["items"]]
            assert orders == list(range(1, len(orders) + 1)), l["lesson_id"]
    # required new content present
    must = {
        "course_b_4_l7": ["ใน", "บน", "จาก", "กับ", "ถึง"],
        "course_b_6_l7": ["ดีใจ", "เบื่อ", "กลัว"],
        "course_b_7_l7": ["และ", "แต่", "เพราะ", "ถ้า"],
        "course_b_5_l1": ["ไม่ไป", "จะไป", "มาแล้ว"],
    }
    for lid, thais in must.items():
        have = {it.get("thai") for it in find_ss(steps, lid)["items"]}
        missing = [t for t in thais if t not in have]
        assert not missing, (lid, missing)
    print("OK B0 L2 cards", len(find_ss(steps, "course_b_0_l2")["items"]))
    for cid in ["course_b_4", "course_b_5", "course_b_6", "course_b_7"]:
        c = find_course(lessons, cid)
        print(cid, "lessons", len(c["lessons"]), "titles", [l["title"] for l in c["lessons"]])


def main() -> None:
    steps = json.loads(STEPS.read_text(encoding="utf-8"))
    lessons = json.loads(LESSONS.read_text(encoding="utf-8"))
    patch_b0(steps, lessons)
    patch_b4(steps, lessons)
    patch_b5(steps, lessons)
    patch_b6(steps, lessons)
    patch_b7(steps, lessons)
    sync_card_counts(steps, lessons)
    patch_catalog(steps, lessons)
    retone_steps(steps, load_retone())
    STEPS.write_text(json.dumps(steps, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    LESSONS.write_text(json.dumps(lessons, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    # reload catalog already written; re-validate from disk
    steps = json.loads(STEPS.read_text(encoding="utf-8"))
    lessons = json.loads(LESSONS.read_text(encoding="utf-8"))
    validate(steps, lessons)


if __name__ == "__main__":
    main()
