#!/usr/bin/env python3
"""Rebuild course_b_2 «Магия интонации» as a tone-lab (minimal pairs)."""
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
        "id": f"course_b_2_l{n}_steps",
        "course_id": "course_b_2",
        "lesson_id": f"course_b_2_l{n}",
        "hints": hints,
        "items": items,
    }


B2_STEPS = [
    stepset(
        1,
        [
            "Стрелки: → ровно, ↓ низко, ↘ падает, ↑ высоко, ↗ вверх.",
            "Сначала жест рукой, потом голос.",
        ],
        [
            tip(
                1,
                "Тон — это другое слово",
                "Русский может сказать «мама!» злее или нежнее — смысл тот же. В тайском слог **маа** с другой мелодией — уже другое слово. Стрелка после слога показывает, куда едет голос.",
            ),
            tip(
                2,
                "Рука помнит тон лучше головы",
                "**→** ладонь ровно. **↗** снизу вверх. **↑** рука наверху, коротко. Сначала жест, потом голос. Названия тонов учить не нужно.",
            ),
            word(3, "Приходить", "มา", "маа→", "Ровный. Не собака и не лошадь."),
            word(4, "Собака", "หมา", "маа↗", "Подъём в конце слога. Если ровно — получится «приходить»."),
            word(5, "Лошадь", "ม้า", "маа↑", "Высокий и плотный. Не путай с подъёмом «собака»."),
            phrase(6, "Это собака", "นี่หมา", "ни→ маа↗", "Весь смысл на втором слоге. Держи ↗."),
            phrase(7, "Это лошадь", "นี่ม้า", "ни→ маа↑", "Сравни с предыдущей: разница только в маа."),
            phrase(8, "Три маа подряд", "มา หมา ม้า", "маа→ маа↗ маа↑", "Медленно. Если все три звучат одинаково — ещё раз с рукой."),
            casual(9, "Пс, собака", "หมา", "маа↗", "Оклик. Подъём должен быть слышен даже коротко."),
            word(10, "Ворона", "กา", "каа→", "Второй ровный якорь. Дальше на этом слоге будут все пять тонов."),
        ],
    ),
    stepset(
        2,
        [
            "Три май: ↘ не, ↗ вопрос, ↓ новый.",
            "Слушай хвост слога, не удар по началу.",
        ],
        [
            tip(
                1,
                "Три май — три роли",
                "**май↘** в начале = «не». **май↗** в конце = вопрос да/нет. **май↓** = «новый». Пишутся по-разному, русскому уху сначала звучат одинаково. Лови хвост слога.",
            ),
            word(2, "Не", "ไม่", "май↘", "Падает. Самая частая ошибка — сказать это как вопрос."),
            word(3, "Хвостик вопроса", "ไหม", "май↗", "Подъём. Это не «не» и не «новый»."),
            word(4, "Новый", "ใหม่", "май↓", "Низкий, спокойный, сидит внизу. Не тяни вверх."),
            phrase(5, "Не приходит", "ไม่มา", "май↘ маа→", "Два знакомых слога. Падение только на май."),
            phrase(6, "Придёшь?", "มาไหม", "маа→ май↗", "Ровный маа, подъём только на хвосте."),
            phrase(7, "Это новое?", "ใหม่ไหม", "май↓ май↗", "Два май подряд: сначала «новый», потом вопрос."),
            phrase(8, "Новый дом", "บ้านใหม่", "баан→ май↓", "ใหม่ не должен звучать как вопрос."),
            phrase(9, "Не хочу", "ไม่อยาก", "май↘ яак↘", "Без падения на май слышится почти «новый хотеть»."),
            tip(
                10,
                "Слушай конец слога",
                "Падение и подъём живут в хвосте. Русское ухо привыкло бить по началу: «МАЙ!». Сначала дослушай гласный до конца — и только потом решай, что это было.",
            ),
        ],
    ),
    stepset(
        3,
        [
            "Близко падает, далеко ровное: глай↘ / глай→.",
            "Курица и яйцо — про согласный, не про тон.",
        ],
        [
            tip(
                1,
                "Близко и далеко — один глай",
                "**глай↘** близко, **глай→** далеко. Русский слышит одно слово и путает сторону. Это не скорость и не громкость — это горка голоса.",
            ),
            word(2, "Далеко", "ไกล", "глай→", "Ровный. Если упадёшь голосом — скажешь «близко»."),
            word(3, "Близко", "ใกล้", "глай↘", "Падает. Пара к «далеко»: одно тело слова, разный тон."),
            phrase(4, "Далеко?", "ไกลไหม", "глай→ май↗", "Слово ровное, вопросный хвост отдельно."),
            phrase(5, "Близко к дому", "ใกล้บ้าน", "глай↘ баан→", "Падение на «близко», дом не трогай."),
            tip(
                6,
                "Курица и яйцо — не про тон",
                "**ไก่** кай↓ и **ไข่** кхай↓ оба низкие. Разница в старте: к vs кх с придыханием. Если «гай» путается в кафе — сначала проверь согласный, потом тон.",
            ),
            word(7, "Белый", "ขาว", "кхаау↗", "Подъём. Длинный гласный."),
            word(8, "Рис", "ข้าว", "кхаау↘", "Падение. Тоже длинный. Не сплющивай в кхау→."),
            phrase(9, "Это белое", "นี่ขาว", "ни→ кхаау↗", "Сравни со следующей карточкой."),
            phrase(10, "Это рис", "นี่ข้าว", "ни→ кхаау↘", "Одна разница — стрелка на кхаау."),
        ],
    ),
    stepset(
        4,
        [
            "Не бей русским ударением по главному слову.",
            "Вопросный подъём — на хвосте, не на всей фразе.",
        ],
        [
            tip(
                1,
                "Не бей по главному слову",
                "По-русски мы выделяем важное ударением: «это СОБАКА». В тайском такое «СО» сжирает тон. Каждый слог сам по себе: **ни↘** своим падением, **маа↗** своим подъёмом.",
            ),
            tip(
                2,
                "Не делай из всего вопрос",
                "Русский вопрос часто взлетает целиком. Тайский чаще поднимается на хвосте **май↗**, а тело фразы остаётся своим. Если поднять всё — «не» и «собака» тоже поедут не туда.",
            ),
            phrase(3, "Это собака", "นี่หมา", "ни→ маа↗", "Без русского удара на «собака»."),
            phrase(4, "Не приходит", "ไม่มา", "май↘ маа→", "Не кричи «НЕ». Падение тихое и точное."),
            phrase(5, "Придёшь?", "มาไหม", "маа→ май↗", "Подъём только на май. маа не спрашивает."),
            phrase(6, "Это новое?", "ใหม่ไหม", "май↓ май↗", "Низкий, потом подъём. Два разных май, не один крик."),
            phrase(7, "Далеко?", "ไกลไหม", "глай→ май↗", "глай ровный, даже в вопросе."),
            phrase(8, "Это рис", "นี่ข้าว", "ни→ кхаау↘", "Не превращай в удивлённое русское «рис?!»."),
            word(9, "Близко", "ใกล้", "глай↘", "Короткое слово. Один слог — одна горка."),
        ],
    ),
    stepset(
        5,
        [
            "Пять этажей на одном каа. Имена тонов не нужны.",
            "Не обрезай гласный: тон живёт на всей длине слога.",
        ],
        [
            tip(
                1,
                "Пять этажей, не пять имён",
                "Ровный, низкий, падающий, высокий, восходящий. Названия из учебника не нужны. Нужно попасть голосом в разные этажи одного слога **каа**.",
            ),
            word(2, "Ворона, ровный", "กา", "каа→", "Живое слово. Остальные каа — этажи для уха."),
            word(3, "Каа низкий", "ก่า", "каа↓", "Голос сел и живёт внизу. Не с горки, а уже внизу."),
            word(4, "Каа падающий", "ก้า", "каа↘", "Стартуй чуть выше и скатись."),
            word(5, "Каа высокий", "ก๊า", "каа↑", "Узко, сверху. Как лошадь маа↑."),
            word(6, "Каа вверх", "ก๋า", "каа↗", "Снизу вверх. Как собака маа↗."),
            phrase(7, "Лифт каа", "กา ก่า ก้า ก๊า ก๋า", "каа→ каа↓ каа↘ каа↑ каа↗", "Медленно, с рукой. Если два этажа слиплись — только эту пару ещё раз."),
            tip(
                8,
                "Не обрезай гласный",
                "Тон живёт на всей длине слога. **маа** и **кхаау** длинные. Если сказать короткое русское «ма!» — этаж не успевает случиться. Сначала длина, потом красота.",
            ),
            phrase(9, "Приходить длинно", "มา", "маа→", "Держи гласный. Не «ма», а маа."),
            phrase(10, "Рис длинно", "ข้าว", "кхаау↘", "Длинный плюс падение. Обрежешь — тон сломается."),
        ],
    ),
    stepset(
        6,
        [
            "Закрой RU и попади в стрелки — пазл сложился.",
            "Если тон слился: три раза медленно, не быстрее.",
        ],
        [
            tip(
                1,
                "Собери пазл вслух",
                "Тон меняет слово. Слушай хвост слога. Рука, потом голос. Не бей русским ударением. Если не услышал разницу — три раза медленно, не быстрее.",
            ),
            phrase(2, "Собака не приходит", "หมาไม่มา", "маа↗ май↘ маа→", "Три этажа в одной фразе. Если слилось — разбери по слогам."),
            phrase(3, "Придёшь?", "มาไหม", "маа→ май↗", "Вопрос. Сравни с «не приходит»."),
            phrase(4, "Это новое?", "ใหม่ไหม", "май↓ май↗", "Низкий плюс подъём."),
            phrase(5, "Близко, далеко", "ใกล้ ไกล", "глай↘ глай→", "Подряд. Должны быть разными."),
            word(6, "Тигр", "เสือ", "сыа↗", "Подъём. Новая пара-якорь."),
            word(7, "Рубашка", "เสื้อ", "сыа↘", "Падение. сыа как глай: одно тело, другой тон."),
            phrase(8, "Новая рубашка", "เสื้อใหม่", "сыа↘ май↓", "Два спокойных низа. Не сделай из ใหม่ вопрос."),
            word(9, "Тётя", "ป้า", "паа↘", "Падает. Так зовут старшую женщину. Не путай со следующим."),
            word(10, "Лес", "ป่า", "паа↓", "Низкий. Рядом с ป้า — проверка: падение не равно уже-внизу."),
        ],
    ),
]


B2_LESSONS = {
    "course_id": "course_b_2",
    "course_title": "Магия интонации",
    "lessons": [
        {
            "lesson_id": "course_b_2_l1",
            "order": 1,
            "title": "Один слог — разные слова",
            "subtitle": "Одна «маа» — приходить, собака, лошадь.",
            "duration_minutes": 4,
            "card_count": 10,
            "is_free": True,
            "tags": [],
            "preview_phrase": "Приходить;маа→",
            "content": [
                {"kind": "intro", "text": "Тон — часть слова. Одна «маа» даёт три смысла. Словарь не зубрим."},
                {"kind": "outline", "text": "มา / หมา / ม้า · стрелки · рука · ворона каа→."},
                {"kind": "apply", "text": "Скажи маа→, маа↗ и маа↑ подряд так, чтобы они не слиплись."},
            ],
            "outcomes": ["Услышать, что один слог с разным тоном — это разные слова."],
            "prerequisites": ["course_b_0_l2"],
            "links": {"steps_ref": "course_b_2_l1_steps", "hometask_ref": "course_b_2_l1_home"},
            "assistant_tips": [],
        },
        {
            "lesson_id": "course_b_2_l2",
            "order": 2,
            "title": "Три май",
            "subtitle": "Не, вопрос и новый — похожи на слух, разные на деле.",
            "duration_minutes": 4,
            "card_count": 10,
            "is_free": True,
            "tags": [],
            "preview_phrase": "Не;май↘",
            "content": [
                {"kind": "intro", "text": "Самая полезная путаница: три май. Здесь учим слух, не грамматику."},
                {"kind": "outline", "text": "ไม่ · ไหม · ใหม่ · не приходит · придёшь? · это новое?"},
                {"kind": "apply", "text": "Скажи май↘ маа→ и маа→ май↗ — падение и подъём должны быть разными."},
            ],
            "outcomes": ["Отличить не, вопросный хвост и «новый» по движению голоса."],
            "prerequisites": ["course_b_2_l1"],
            "links": {"steps_ref": "course_b_2_l2_steps", "hometask_ref": "course_b_2_l2_home"},
            "assistant_tips": [],
        },
        {
            "lesson_id": "course_b_2_l3",
            "order": 3,
            "title": "Гай и гаай",
            "subtitle": "Близко не равно далеко. Рис не равен белому.",
            "duration_minutes": 4,
            "card_count": 10,
            "is_free": False,
            "tags": [],
            "preview_phrase": "Близко;глай↘",
            "content": [
                {"kind": "intro", "text": "Пары, которые русское ухо сливает в одно слово. Разница — только тон."},
                {"kind": "outline", "text": "ใกล้ / ไกล · ขาว / ข้าว · курица и яйцо — не тон."},
                {"kind": "apply", "text": "Скажи глай↘ и глай→ подряд, затем кхаау↗ и кхаау↘."},
            ],
            "outcomes": ["Различить близко/далеко и белый/рис только по тону."],
            "prerequisites": ["course_b_2_l2"],
            "links": {"steps_ref": "course_b_2_l3_steps", "hometask_ref": "course_b_2_l3_home"},
            "assistant_tips": [],
        },
        {
            "lesson_id": "course_b_2_l4",
            "order": 4,
            "title": "Русская ловушка",
            "subtitle": "Не бить ударением и не поднимать всю фразу.",
            "duration_minutes": 3,
            "card_count": 9,
            "is_free": False,
            "tags": [],
            "preview_phrase": "Это собака;ни→ маа↗",
            "content": [
                {"kind": "intro", "text": "Новых слов нет. Ломаем две русские привычки: удар по смыслу и вопрос на всю фразу."},
                {"kind": "outline", "text": "Собака · не приходит · придёшь? · это новое? · далеко? · рис."},
                {"kind": "apply", "text": "Скажи «это собака» без удара на «собака» — каждый слог своим тоном."},
            ],
            "outcomes": ["Не подменять тайский тон русским ударением и вопросительным подъёмом."],
            "prerequisites": ["course_b_2_l3"],
            "links": {"steps_ref": "course_b_2_l4_steps", "hometask_ref": "course_b_2_l4_home"},
            "assistant_tips": [],
        },
        {
            "lesson_id": "course_b_2_l5",
            "order": 5,
            "title": "Пять этажей голоса",
            "subtitle": "Один слог каа — все пять движений.",
            "duration_minutes": 4,
            "card_count": 10,
            "is_free": False,
            "tags": [],
            "preview_phrase": "Ворона, ровный;каа→",
            "content": [
                {"kind": "intro", "text": "Тренажёр мышц. Кроме «вороны» этажи каа запоминать как слова не нужно."},
                {"kind": "outline", "text": "กา пять тонов · длина гласного · маа и кхаау длинные."},
                {"kind": "apply", "text": "Прогони каа по пяти этажам с рукой. Если два слиплись — только эту пару."},
            ],
            "outcomes": ["Попасть голосом в пять этажей одного слога и не обрезать гласный."],
            "prerequisites": ["course_b_2_l4"],
            "links": {"steps_ref": "course_b_2_l5_steps", "hometask_ref": "course_b_2_l5_home"},
            "assistant_tips": [],
        },
        {
            "lesson_id": "course_b_2_l6",
            "order": 6,
            "title": "Собака не приходит",
            "subtitle": "Собираем пары в короткие проверки.",
            "duration_minutes": 4,
            "card_count": 10,
            "is_free": False,
            "tags": [],
            "preview_phrase": "Собака не приходит;маа↗ май↘ маа→",
            "content": [
                {"kind": "intro", "text": "Финал без новой бытовой темы: склейка пар плюс тигр/рубашка и тётя/лес."},
                {"kind": "outline", "text": "หมาไม่มา · มาไหม · ใกล้ ไกล · เสือ / เสื้อ · ป้า / ป่า."},
                {"kind": "apply", "text": "Закрой RU и скажи «собака не приходит» по слогам со стрелками."},
            ],
            "outcomes": ["Собрать тон из отдельных пар в короткую фразу и удержать контраст."],
            "prerequisites": ["course_b_2_l5"],
            "links": {"steps_ref": "course_b_2_l6_steps", "hometask_ref": "course_b_2_l6_home"},
            "assistant_tips": [],
        },
    ],
    "summary": {"total_lessons": 6, "total_duration_minutes": 23},
    "description": "Слуховой курс: похожий слог, другой тон — другое слово. Минимальные пары, не survival-фразы.",
}


def dumps_indented_object(obj: dict, extra_indent: int = 4) -> str:
    raw = json.dumps(obj, ensure_ascii=False, indent=2)
    pad = " " * extra_indent
    return "\n".join(pad + line if line else line for line in raw.splitlines())


def replace_json_array_slice(path: Path, start_id: str, end_next_id: str, new_objects: list[dict]) -> None:
    text = path.read_text(encoding="utf-8")
    idx = -1
    for key in ("id", "course_id"):
        marker = f'    {{\n      "{key}": "{start_id}"'
        idx = text.find(marker)
        if idx >= 0:
            break
    if idx < 0:
        raise SystemExit(f"start object not found for {start_id} in {path}")
    end_idx = -1
    for key in ("id", "course_id"):
        marker = f'    {{\n      "{key}": "{end_next_id}"'
        end_idx = text.find(marker, idx + 1)
        if end_idx >= 0:
            break
    if end_idx < 0:
        raise SystemExit(f"end object not found for {end_next_id} in {path}")
    replacement = ",\n".join(dumps_indented_object(obj) for obj in new_objects) + ",\n"
    path.write_text(text[:idx] + replacement + text[end_idx:], encoding="utf-8")


def replace_catalog_b2() -> None:
    text = CATALOG.read_text(encoding="utf-8")
    old = '''    "id": "course_b_2",
    "title": "Магия интонации",
    "description": "Тон, скорость и вежливые хвостики на знакомых фразах.",
    "category": "База от Тайки",
    "is_pro": false,
    "lesson_count": 6,
    "duration_minutes": 22,
    "icon_name": "tone_magic",
    "is_new": false,
    "learning_outcomes": [
      {
        "type": "Тоны",
        "count": 5
      },
      {
        "type": "Интонация",
        "count": 20
      },
      {
        "type": "Фразы",
        "count": 5
      }
    ],
    "short_description": "Слушай тон, не зубри заново"'''
    new = '''    "id": "course_b_2",
    "title": "Магия интонации",
    "description": "Похожий слог, другой тон — другое слово. Учимся слышать тоны на парах.",
    "category": "База от Тайки",
    "is_pro": false,
    "lesson_count": 6,
    "duration_minutes": 23,
    "icon_name": "tone_magic",
    "is_new": false,
    "learning_outcomes": [
      {
        "type": "Тоны",
        "count": 5
      },
      {
        "type": "Минимальные пары",
        "count": 6
      },
      {
        "type": "Лайфхаки",
        "count": 11
      }
    ],
    "short_description": "Слышать тон, не зубрить фразы"'''
    if old not in text:
        raise SystemExit("catalog B2 block not found")
    CATALOG.write_text(text.replace(old, new, 1), encoding="utf-8")


def validate() -> None:
    steps = json.loads(STEPS.read_text(encoding="utf-8"))
    lessons = json.loads(LESSONS.read_text(encoding="utf-8"))
    b2 = [s for s in steps["stepsets"] if s.get("course_id") == "course_b_2"]
    assert [s["lesson_id"] for s in b2] == [f"course_b_2_l{i}" for i in range(1, 7)], [s["lesson_id"] for s in b2]
    course = next(c for c in lessons["courses"] if c["course_id"] == "course_b_2")
    for ss, lesson in zip(b2, course["lessons"]):
        n = len(ss["items"])
        orders = [it["order"] for it in ss["items"]]
        assert orders == list(range(1, n + 1)), (ss["lesson_id"], orders)
        assert lesson["card_count"] == n, (lesson["lesson_id"], lesson["card_count"], n)
        for it in ss["items"]:
            if it["kind"] == "tip":
                assert it.get("text"), it
            else:
                assert it.get("ru") and it.get("thai") and it.get("phonetic"), it
    print("OK", {s["lesson_id"]: len(s["items"]) for s in b2})
    print("lessons", course["description"])
    print("titles", [l["title"] for l in course["lessons"]])


def main() -> None:
    retone_steps({"stepsets": B2_STEPS}, load_retone())
    replace_json_array_slice(STEPS, "course_b_2_l1_steps", "course_b_4_l1_steps", B2_STEPS)
    replace_json_array_slice(LESSONS, "course_b_2", "course_b_3", [B2_LESSONS])
    replace_catalog_b2()
    validate()


if __name__ == "__main__":
    main()
