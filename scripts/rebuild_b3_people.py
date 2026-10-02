#!/usr/bin/env python3
"""Rebuild course_b_3 as people-lab: pronouns, family, whose, who/what, ask about a person, guests."""
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


def stepset(n: int, hints: list[str], items: list[dict]) -> dict:
    return {
        "id": f"course_b_3_l{n}_steps",
        "course_id": "course_b_3",
        "lesson_id": f"course_b_3_l{n}",
        "hints": hints,
        "items": items,
    }


B3_STEPS = [
    stepset(
        1,
        [
            "Выбери одно «я» и держись его в разговоре.",
            "Кхун — вежливое ты/вы. Между своими позже будет мягче.",
        ],
        [
            tip(
                1,
                "Одно «я» на весь разговор",
                "Мужчины чаще говорят **пхом**, женщины — **чхан**. Выбери одно и не прыгай. Тайцам важна стабильность обращения сильнее идеальной грамматики.",
            ),
            word(2, "Я мужчина", "ผม", "пхом→", "«Я» для мужчин. Держись одного варианта."),
            word(3, "Я женщина", "ฉัน", "чхан→", "«Я» для женщин. Можно и мягкое я между своими — позже."),
            word(4, "Ты вы", "คุณ", "кхун→", "Вежливое ты/вы. Безопасно с незнакомыми."),
            word(5, "Мы", "เรา", "рау→", "Мы/нас. Часто без отдельного «вы все»."),
            phrase(6, "Это я", "นี่ฉัน", "ни→ чхан→", "Или ни↘ пхом↗ — подставь своё «я»."),
            phrase(7, "Это ты?", "คุณใช่ไหม", "кхун→ чай→ май↗", "Вежливая проверка: это вы?"),
            phrase(8, "Я тоже", "ฉันด้วย", "чхан→ дуай→", "Дуай = тоже. Подставь пхом, если ты парень."),
            phrase(9, "Мы вместе", "เราด้วยกัน", "рау→ дуай→ кан→", "Вместе/с нами. Коротко и по делу."),
            tip(
                10,
                "Местоимение можно не повторять",
                "Если и так понятно, кто говорит, «я» часто опускают. **кин лэу** уже может значить «уже поел». Местоимение нужно, когда важно подчеркнуть, кто именно.",
            ),
        ],
    ),
    stepset(
        2,
        [
            "Кхау — он/она по умолчанию. Тхё — мягче, между своими.",
            "Пхуак кхау — они.",
        ],
        [
            tip(
                1,
                "Он и она часто одно слово",
                "**кхау** закрывает и «он», и «она». Пол подсказывает ситуация. **тхё** — мягкое «она/ты» между своими; с незнакомкой безопаснее **кхау** или **кхун**.",
            ),
            word(2, "Он она", "เขา", "кхау→", "Он/она в одном слове. Контекст подскажет пол."),
            word(3, "Она мягко", "เธอ", "тхё→", "Между своими. Не для первого разговора с незнакомкой."),
            word(4, "Они", "พวกเขา", "пхуак→ кхау→", "Они. Пхуак собирает группу."),
            phrase(5, "Его зовут", "เขาชื่อ", "кхау→ чыу→", "Дальше имя. Не повторяем урок знакомства из старта."),
            phrase(6, "Он таец", "เขาเป็นคนไทย", "кхау→ пэн→ кон→ тай→", "Пэн = является. Кон тай = таец/тайка."),
            phrase(7, "Она моя подруга", "เธอเป็นเพื่อนฉัน", "тхё→ пэн→ пхыан→ чхан→", "Подставь пхом/чхан под себя."),
            phrase(8, "Они друзья", "พวกเขาเป็นเพื่อน", "пхуак→ кхау→ пэн→ пхыан→", "Группа людей — коротко."),
            phrase(9, "Она работает здесь", "เธอทำงานที่นี่", "тхё→ там→ нгаан→ ти→ ни→", "Ти ни = здесь. Не урок «где туалет»."),
            casual(10, "Он классный", "เขาน่ารัก", "кхау→ на→ рак→", "Casual: милый/приятный. С незнакомцем — осторожнее."),
        ],
    ),
    stepset(
        3,
        [
            "Семья сближает быстрее small talk про погоду.",
            "Пхи — старший, нонг — младший.",
        ],
        [
            tip(
                1,
                "Семья — быстрый мост",
                "Спросить про маму, папу или братьев/сестёр в Таиланде нормально. Это не допрос — это тёплый вход. Не путай с повторным «как тебя зовут» из старта.",
            ),
            word(2, "Мама", "แม่", "мэ→", "Мама. Короткое и частое."),
            word(3, "Папа", "พ่อ", "пхо→", "Папа."),
            word(4, "Брат сестра", "พี่น้อง", "пхи→ нонг→", "Братья и сёстры вместе. Пхи старше, нонг младше."),
            word(5, "Семья", "ครอบครัว", "кхроп→ кхруа→", "Семья как целое."),
            phrase(6, "У меня есть мама", "ฉันมีแม่", "чхан→ ми→ мэ→", "Ми = есть/иметь. Подставь своё «я»."),
            phrase(7, "Моя семья в России", "ครอบครัวฉันอยู่รัสเซีย", "кхроп→ кхруа→ чхан→ ю→ рас→ сиа→", "Ю = находится. Страна — носитель."),
            phrase(8, "Сколько братьев сестёр?", "คุณมีพี่น้องกี่คน", "кхун→ ми→ пхи→ нонг→ ги→ кон→", "Ги кон = сколько человек."),
            phrase(9, "У меня один брат", "ฉันมีพี่ชายหนึ่งคน", "чхан→ ми→ пхи→ чай→ нынг→ кон→", "Пхи чай = старший брат."),
            casual(10, "Моя сестра", "น้องสาวฉัน", "нонг→ сао→ чхан→", "Младшая сестра. Casual и тёплое."),
        ],
    ),
    stepset(
        4,
        [
            "Кхонг + человек = чья вещь.",
            "Сначала вещь, потом «чей».",
        ],
        [
            tip(
                1,
                "Чей = кхонг плюс человек",
                "**кхонг чхан** — моё, **кхонг кхун** — твоё, **кхонг кхау** — его/её. Часто **кхонг** слышится коротко или почти проглатывается, но смысл «чья» остаётся.",
            ),
            word(2, "Мой", "ของฉัน", "кхонг→ чхан→", "Моё. После вещи или вместо неё."),
            word(3, "Твой", "ของคุณ", "кхонг→ кхун→", "Твоё/ваше."),
            word(4, "Его её", "ของเขา", "кхонг→ кхау→", "Его/её."),
            word(5, "Наш", "ของเรา", "кхонг→ рау→", "Наше."),
            phrase(6, "Это моя сумка", "นี่กระเป๋าของฉัน", "ни→ кра→ пау→ кхонг→ чхан→", "Вещь + кхонг + я."),
            phrase(7, "Это твой телефон?", "นี่โทรศัพท์ของคุณไหม", "ни→ то→ ра→ сап→ кхонг→ кхун→ май↗", "Вопросный хвост май, не новый словарь магазина."),
            phrase(8, "Наш дом", "บ้านของเรา", "баан→ кхонг→ рау→", "Дом наш."),
            phrase(9, "Его машина", "รถของเขา", "рот→ кхонг→ кхау→", "Его/её машина."),
            phrase(10, "Это наша семья", "นี่ครอบครัวของเรา", "ни→ кхроп→ кхруа→ кхонг→ рау→", "Склейка: семья + наш."),
        ],
    ),
    stepset(
        5,
        [
            "Кхрай = кто. Арай = что.",
            "Не повторяем «где туалет» из старта — здесь люди и вещи рядом.",
        ],
        [
            tip(
                1,
                "Кто и что — разные дырки",
                "**кхрай** спрашивает про человека. **арай** — про вещь или дело. В тайском вопросительное слово часто стоит там, где был бы ответ: **ни кхрай** — «это кто?».",
            ),
            word(2, "Кто", "ใคร", "кхрай→", "Кто. Про человека."),
            word(3, "Что", "อะไร", "а→ рай↗", "Что. Про вещь, имя, действие."),
            phrase(4, "Кто это?", "นี่ใคร", "ни→ кхрай→", "Базовый вопрос про человека рядом."),
            phrase(5, "Это кто такой?", "เขาเป็นใคร", "кхау→ пэн→ кхрай→", "Кто он/она?"),
            phrase(6, "Что это?", "นี่อะไร", "ни→ а→ рай↗", "Про вещь перед глазами."),
            phrase(7, "Ты что делаешь?", "คุณทำอะไร", "кхун→ там→ а→ рай↗", "Там арай = что делаешь. Не дубль «как зовут»."),
            phrase(8, "Это чей?", "นี่ของใคร", "ни→ кхонг→ кхрай→", "Чей это? Кхонг + кто."),
            phrase(9, "Кто пришёл?", "ใครมา", "кхрай→ маа→", "Кто пришёл/приходит."),
            casual(10, "А это что?", "อันนี้อะไร", "ан→ ни→ а→ рай↗", "Casual: вот это — что?"),
        ],
    ),
    stepset(
        6,
        [
            "Спрашиваем про человека: возраст, работа, когда, почему, как.",
            "Не повторяем урок «как тебя зовут / откуда ты» из старта.",
        ],
        [
            tip(
                1,
                "Спроси про человека, не про визитку",
                "Имя и «откуда ты» уже были в старте. Здесь — возраст, работа и три дырки: **когда**, **почему**, **как**. Так разговор про человека становится глубже без второго знакомства.",
            ),
            word(2, "Когда", "เมื่อไหร่", "мыа→ рай↗", "Когда? Отдельного урока в Базе ещё не было."),
            word(3, "Почему", "ทำไม", "там→ май→", "Почему?"),
            word(4, "Как", "ยังไง", "янг→ нгай→", "Как / каким образом? Живой разговорный вариант."),
            phrase(5, "Сколько тебе лет?", "คุณอายุเท่าไหร่", "кхун→ а→ ю→ тао→ рай↗", "В Таиланде спросить возраст — норма."),
            phrase(6, "Мне тридцать", "ฉันอายุสามสิบ", "чхан→ а→ ю→ саам→ сип→", "Число — носитель. Подставь своё."),
            phrase(7, "Кем работаешь?", "คุณทำงานอะไร", "кхун→ там→ нгаан→ а→ рай↗", "Работа/профессия. Не путай с «что делаешь?» из прошлого урока."),
            phrase(8, "Когда приехал?", "มาเมื่อไหร่", "маа→ мыа→ рай↗", "Когда приехал/приехала?"),
            phrase(9, "Почему учишь тайский?", "ทำไมเรียนภาษาไทย", "там→ май→ риан→ пха→ саа→ тай→", "Почему + действие."),
            phrase(10, "Как это сказать?", "พูดยังไง", "пхуут→ янг→ нгай→", "Как сказать? Полезный repair про язык."),
        ],
    ),
    stepset(
        7,
        [
            "Друг, гость, заходи — без повторного приветствия из старта.",
            "Чён = приглашаю. Маа йиам = приходи в гости.",
        ],
        [
            tip(
                1,
                "Звать людей, не знакомиться заново",
                "**пхыан** — друг. **хэк** — гость. **чён** — приглашаю. **маа йиам** — приходи в гости. Приветствие и «рад познакомиться» уже в старте — здесь только люди рядом.",
            ),
            word(2, "Друг", "เพื่อน", "пхыан→", "Друг/подруга."),
            word(3, "Гость", "แขก", "хэк↘", "Гость."),
            word(4, "Пригласить", "เชิญ", "чён→", "Приглашаю / прошу пройти."),
            phrase(5, "Мой друг", "เพื่อนฉัน", "пхыан→ чхан→", "Мой друг. Без лишнего кхонг тоже ок."),
            phrase(6, "Прийти в гости", "มาเยี่ยม", "маа→ йиам→", "Навестить / прийти в гости."),
            phrase(7, "Приходи в гости", "มาเยี่ยมนะ", "маа→ йиам→ на→", "На смягчает. Не урок частиц — только тёплый хвост."),
            phrase(8, "Приглашаю на кофе", "เชิญดื่มกาแฟ", "чён→ дым→ ка→ фэ→", "Приглашение на кофе."),
            phrase(9, "У меня гости", "มีแขก", "ми→ хэк↘", "Коротко: есть гости."),
            casual(10, "Заходи", "เข้ามา", "кау→ маа→", "Casual: заходи / проходи."),
        ],
    ),
]


B3_LESSONS = {
    "course_id": "course_b_3",
    "course_title": "Я, ты, он, семья",
    "lessons": [
        {
            "lesson_id": "course_b_3_l1",
            "order": 1,
            "title": "Я и ты",
            "subtitle": "Кто говорит и к кому — без таблицы местоимений.",
            "duration_minutes": 3,
            "card_count": 10,
            "is_free": True,
            "tags": [],
            "preview_phrase": "Я мужчина;пхом→",
            "content": [
                {"kind": "intro", "text": "Сначала участники разговора: я, ты и мы. Одно «я» — на весь разговор."},
                {"kind": "outline", "text": "пхом / чхан · кхун · рау · это я · я тоже."},
                {"kind": "apply", "text": "Выбери своё «я» и скажи «это я» и «я тоже»."},
            ],
            "outcomes": ["Выбрать стабильное «я» и обратиться к собеседнику вежливо."],
            "prerequisites": ["course_b_1_l1"],
            "links": {"steps_ref": "course_b_3_l1_steps", "hometask_ref": "course_b_3_l1_home"},
            "assistant_tips": [],
        },
        {
            "lesson_id": "course_b_3_l2",
            "order": 2,
            "title": "Он, она, они",
            "subtitle": "Говорим о другом человеке без поиска рода.",
            "duration_minutes": 3,
            "card_count": 10,
            "is_free": True,
            "tags": [],
            "preview_phrase": "Он она;кхау→",
            "content": [
                {"kind": "intro", "text": "Кхау закрывает он/она. Тхё — мягче. Пхуак кхау — они."},
                {"kind": "outline", "text": "кхау · тхё · они · его зовут · она подруга · работают здесь."},
                {"kind": "apply", "text": "Скажи про друга: он/она таец и работает здесь."},
            ],
            "outcomes": ["Рассказать о третьем лице без путаницы он/она."],
            "prerequisites": ["course_b_3_l1"],
            "links": {"steps_ref": "course_b_3_l2_steps", "hometask_ref": "course_b_3_l2_home"},
            "assistant_tips": [],
        },
        {
            "lesson_id": "course_b_3_l3",
            "order": 3,
            "title": "Семья",
            "subtitle": "Семья в коротких живых фразах.",
            "duration_minutes": 4,
            "card_count": 10,
            "is_free": False,
            "tags": [],
            "preview_phrase": "Мама;мэ→",
            "content": [
                {"kind": "intro", "text": "Мама, папа, братья и сёстры — быстрый мост в разговоре."},
                {"kind": "outline", "text": "мама · папа · пхи нонг · семья · сколько братьев · один брат."},
                {"kind": "apply", "text": "Скажи, есть ли у тебя брат или сестра, одной короткой фразой."},
            ],
            "outcomes": ["Назвать близких и ответить, сколько братьев/сестёр."],
            "prerequisites": ["course_b_3_l2"],
            "links": {"steps_ref": "course_b_3_l3_steps", "hometask_ref": "course_b_3_l3_home"},
            "assistant_tips": [],
        },
        {
            "lesson_id": "course_b_3_l4",
            "order": 4,
            "title": "Чей это",
            "subtitle": "Мой, твой, его — через кхонг.",
            "duration_minutes": 4,
            "card_count": 10,
            "is_free": False,
            "tags": [],
            "preview_phrase": "Мой;кхонг→ чхан→",
            "content": [
                {"kind": "intro", "text": "Кхонг плюс человек = чья вещь. Без нового магазинного словаря."},
                {"kind": "outline", "text": "мой · твой · его · наш · сумка · телефон · дом · семья."},
                {"kind": "apply", "text": "Покажи на вещь и скажи «это моё» / «это твоё?»."},
            ],
            "outcomes": ["Сказать, чья вещь: моя, твоя, его, наша."],
            "prerequisites": ["course_b_3_l3"],
            "links": {"steps_ref": "course_b_3_l4_steps", "hometask_ref": "course_b_3_l4_home"},
            "assistant_tips": [],
        },
        {
            "lesson_id": "course_b_3_l5",
            "order": 5,
            "title": "Кто и что",
            "subtitle": "Кхрай про человека, арай про вещь.",
            "duration_minutes": 4,
            "card_count": 10,
            "is_free": False,
            "tags": [],
            "preview_phrase": "Кто;кхрай→",
            "content": [
                {"kind": "intro", "text": "Два вопросительных слова про людей и вещи рядом. Не survival «где туалет»."},
                {"kind": "outline", "text": "кто · что · кто это · что это · что делаешь · чей · кто пришёл."},
                {"kind": "apply", "text": "Спроси про человека рядом «кто это?» и про вещь «что это?»."},
            ],
            "outcomes": ["Отличить вопросы «кто» и «что» и задать их в простой ситуации."],
            "prerequisites": ["course_b_3_l4"],
            "links": {"steps_ref": "course_b_3_l5_steps", "hometask_ref": "course_b_3_l5_home"},
            "assistant_tips": [],
        },
        {
            "lesson_id": "course_b_3_l6",
            "order": 6,
            "title": "Спроси про человека",
            "subtitle": "Возраст, работа, когда, почему, как — без второго знакомства.",
            "duration_minutes": 4,
            "card_count": 10,
            "is_free": False,
            "tags": [],
            "preview_phrase": "Когда;мыа→ рай↗",
            "content": [
                {"kind": "intro", "text": "Имя и «откуда» уже в старте. Здесь углубляем разговор про человека."},
                {"kind": "outline", "text": "когда · почему · как · возраст · работа · когда приехал · как сказать."},
                {"kind": "apply", "text": "Спроси возраст или «когда приехал?» — без повторного «как зовут»."},
            ],
            "outcomes": ["Спросить про человека: возраст, занятие, когда, почему, как."],
            "prerequisites": ["course_b_3_l5"],
            "links": {"steps_ref": "course_b_3_l6_steps", "hometask_ref": "course_b_3_l6_home"},
            "assistant_tips": [],
        },
        {
            "lesson_id": "course_b_3_l7",
            "order": 7,
            "title": "Друзья и гости",
            "subtitle": "Друг, гость и приглашение — без допроса.",
            "duration_minutes": 4,
            "card_count": 10,
            "is_free": False,
            "tags": [],
            "preview_phrase": "Друг;пхыан→",
            "content": [
                {"kind": "intro", "text": "Зовём людей рядом. Приветствие из старта не повторяем."},
                {"kind": "outline", "text": "друг · гость · пригласить · в гости · на кофе · заходи."},
                {"kind": "apply", "text": "Пригласи друга на кофе или скажи «приходи в гости»."},
            ],
            "outcomes": ["Назвать друга/гостя и коротко пригласить."],
            "prerequisites": ["course_b_3_l6"],
            "links": {"steps_ref": "course_b_3_l7_steps", "hometask_ref": "course_b_3_l7_home"},
            "assistant_tips": [],
        },
    ],
    "summary": {"total_lessons": 7, "total_duration_minutes": 26},
    "description": "Люди рядом: я/ты/он, семья, чья вещь, кто/что и вопрос про человека — без повторного знакомства из старта.",
}


def replace_course_stepsets(course_id: str, new_sets: list[dict]) -> None:
    doc = json.loads(STEPS.read_text(encoding="utf-8"))
    out: list[dict] = []
    done = False
    for s in doc["stepsets"]:
        if s.get("course_id") == course_id:
            if not done:
                out.extend(new_sets)
                done = True
            continue
        out.append(s)
    if not done:
        raise SystemExit(f"{course_id} stepsets not found")
    doc["stepsets"] = out
    retone_steps(doc, load_retone())
    STEPS.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def replace_course_lessons(course_id: str, new_course: dict) -> None:
    doc = json.loads(LESSONS.read_text(encoding="utf-8"))
    for i, c in enumerate(doc["courses"]):
        if c.get("course_id") == course_id:
            doc["courses"][i] = new_course
            break
    else:
        raise SystemExit(f"{course_id} missing in lessons.json")
    LESSONS.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def replace_catalog() -> None:
    data = json.loads(CATALOG.read_text(encoding="utf-8"))
    for course in data:
        if course.get("id") == "course_b_3":
            course["description"] = "Люди рядом: я/ты/он, семья, чья вещь, кто/что и вопрос про человека."
            course["duration_minutes"] = 26
            course["lesson_count"] = 7
            course["learning_outcomes"] = [
                {"type": "Местоимения", "count": 10},
                {"type": "Семья и люди", "count": 12},
                {"type": "Вопросы", "count": 8},
            ]
            course["short_description"] = "Кто рядом — без дубля старта"
            break
    else:
        raise SystemExit("course_b_3 missing in catalog")
    CATALOG.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def validate() -> None:
    steps = json.loads(STEPS.read_text(encoding="utf-8"))
    lessons = json.loads(LESSONS.read_text(encoding="utf-8"))
    b3 = [s for s in steps["stepsets"] if s.get("course_id") == "course_b_3"]
    assert [s["lesson_id"] for s in b3] == [f"course_b_3_l{i}" for i in range(1, 8)]
    course = next(c for c in lessons["courses"] if c["course_id"] == "course_b_3")
    for ss, lesson in zip(b3, course["lessons"]):
        n = len(ss["items"])
        assert [it["order"] for it in ss["items"]] == list(range(1, n + 1))
        assert lesson["card_count"] == n, (lesson["lesson_id"], lesson["card_count"], n)
        for it in ss["items"]:
            if it["kind"] == "tip":
                assert it.get("text") and it.get("tip")
            else:
                assert it.get("ru") and it.get("thai") and it.get("phonetic")
    # no B1 intro duplicates
    ban = {"คุณชื่ออะไร", "คุณมาจากไหน", "ยินดีที่ได้รู้จัก", "ดีใจที่เจอ", "สวัสดี คุณชื่ออะไร"}
    thais = {it.get("thai") for s in b3 for it in s["items"]}
    assert not (ban & thais), ban & thais
    print("OK", {s["lesson_id"]: len(s["items"]) for s in b3})
    print("titles", [l["title"] for l in course["lessons"]])


def main() -> None:
    replace_course_stepsets("course_b_3", B3_STEPS)
    replace_course_lessons("course_b_3", B3_LESSONS)
    replace_catalog()
    validate()


if __name__ == "__main__":
    main()
