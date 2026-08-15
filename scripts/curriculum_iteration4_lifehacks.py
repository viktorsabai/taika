#!/usr/bin/env python3
"""
Iteration 4 — lifehacks (kind:tip) to shareable-only model.

Rules:
- NOT mandatory every lesson (0 is OK)
- b_0: tips-only course — keep storytelling lifehacks
- b_2: keep tone-profile lifehacks
- Elsewhere: only fun fact / linguistic story / common mistake / local custom
- Short (except b_0); max 2 per lesson outside b_0
- Kill boilerplate & editor-meta
"""

from __future__ import annotations

import json
import re
from copy import deepcopy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STEPS_PATH = ROOT / "steps.json"
LESSONS_PATH = ROOT / "lessons.json"
REPORT_PATH = ROOT / "docs" / "curriculum_iteration4_lifehacks_report.md"

LEARNABLE = {"word", "phrase", "casual"}

# Exact boilerplate to drop
DROP_EXACT = {
    "Контекст из Базы не повторяем — углубляем сценарий. Каа.",
    "Это [[сборка]] сцены: порядок реплик важнее новых слов.",
    "Долгожитель: поверх База/Жизнь/Волна/Душа. Кха/кхрап в tip. Каа.",
    "Здесь — мягкость и код общения, не новый словарь выживания.",
    "Ниша поверх базы: говори естественнее, не зубри дубли.",
    "Глагол не спрягается: выучил — собирай с «я/ты» и местом.",
    "Резидентские темы: спокойный тон важнее идеального акцента.",
    "Оценка (вкусно/дорого/красиво) оживляет любую бытовую фразу.",
    "Склейка: глагол + оценка. Пример: кин + а-рой.",
    "Один Thai — одна карточка: транслит не дублируем отдельной карточкой.",
}

DROP_SUBSTRINGS = [
    "контекст из базы не повторяем",
    "ниша поверх",
    "долгожитель:",
    "не дублируем",
    "не повторяй базовое",
    "не повторяем",
    "уже в «",
    "уже в \"",
    "уже в старте",
    "уже в разговорном",
    "уже в курсе",
    "в следующем уроке",
    "здесь только",
    "здесь — кто ты",
    "здесь держись",
    "вернись в",
    "открой «",
    "из базы",
    "из старта",
    "поверх база",
    "кха/кхрап в tip",
    "сборкa / review",
    "сборка / review",
    "порядок реплик важнее",
    "склей уже знакомое",
    "навигацию и цену склей",
    "числа уже знаешь — здесь только",
]

# Keep even if short routing-ish — explicit allow by exact text
KEEP_EXACT = {
    "Вай на уровне груди + улыбка. Часто работает даже без слов.",
    "Кха / кхрап — вежливые хвостики. Мужчины: кхрап, женщины: кха.",
    "Сложное имя — придумай короткий тайский ник. Тайцы любят.",
    "Сабай = комфортно. Май сабай = не очень. Переключатель small talk.",
    "Формула дня: кхо … ной / дай май? — вежливая просьба на всё.",
    "Покажи на карте и скажи ти-ни — часто понятнее слов.",
    "Кхоп-кхун и кхо тхот — говори чаще, чем кажется нужным.",
    "Выбери один «я» и держись его. Тайцам важна стабильность.",
    "Тхё — она в неформальном контексте.",
    "На-рак — милый классный для людей и вещей.",
    "Тайцы любят когда рассказываешь про семью — сближает.",
    "Тайцы часто спрашивают возраст — отвечай спокойно.",
    "Кхонг плюс местоимение — чья вещь.",
    "Чён — приглашать. Маа йиам — прийти в гости, навестить.",
    "Семь = джет↘ (เจ็ด). Не путай с «дет» — цифра уходит в цены и время.",
    "สิบ уже из урока 1–10. Здесь — десятки: 20, 30, 40, 50 и 100.",
    "Монг — час. На-ти — минута. Для такси и встреч.",
    "В такси: тронг пай + палец. Чот тронг ни — останови.",
    "เย็น здесь «вечер». То же слово в «Горячо и холодно» значит «холодно / холодный» — контекст решает.",
    "เย็น = холодно (напиток/погода). В уроке про время то же слово — «вечер».",
    "อยู่ที่ไหน — «где находится?». Позже с глаголом «жить» та же оболочка спросит «где живёшь?» — смысл из контекста.",
    "«Где живёшь?» = อยู่ที่ไหน. Ту же форму в старте учили как «где это?» — слушай контекст.",
    "На посту улыбка и спокойный тон важнее идеального тайского.",
    "Пай + место — из Базы. Здесь конкретные места.",  # borderline - will drop via substring "из базы" 
    "Назови район или ориентир — таксист поймёт быстрее.",
}

# Curated shareable lifehacks by lesson_id (0–2). Overwrites after cleanup if set.
# Empty list = explicitly no lifehack for this lesson after cleanup.
SCENARIO: dict[str, list[str]] = {
    # b_1 — keep jewels + a few more
    "course_b_1_l1": [
        "Вай на уровне груди + улыбка. Часто работает даже без слов.",
        "Мужчины говорят кхрап↘, женщины — ка↘. Один хвост — и ты уже «свой».",
    ],
    "course_b_1_l2": [
        "Сложное имя? Придумай короткий тайский ник — тайцы такое обожают.",
    ],
    "course_b_1_l3": [
        "Сабай = «мне ок/комфортно». Май сабай — честный ответ без драмы.",
    ],
    "course_b_1_l4": [
        "Формула на всё: кхо + что нужно + ной. Вода, счёт, пакет — один каркас.",
    ],
    "course_b_1_l5": [
        "Покажи на карте и скажи ти-ни — жест часто понятнее идеального тайского.",
    ],
    "course_b_1_l6": [
        "Сначала тао рай↗, потом уже торг. Улыбка — часть цены.",
    ],
    "course_b_1_l7": [
        "Кхоп кхун и кхо тхот говори чаще, чем кажется нужным — так звучишь теплее.",
    ],
    # b_3
    "course_b_3_l1": [
        "Выбери одно «я» (пхом или чхан) и держись его — тайцам важна стабильность.",
    ],
    "course_b_3_l2": [
        "Тхё — мягкое «она» между своими. С незнакомкой безопаснее кхау / кун.",
    ],
    "course_b_3_l3": [
        "Рассказ про семью сближает быстрее small talk про погоду.",
    ],
    "course_b_3_l4": [
        "Спросить возраст в Таиланде — норма, не грубость. Отвечай спокойно.",
    ],
    "course_b_3_l7": [
        "Чён = приглашаю. Маа йиам = приходи в гости. Два слова — весь этикет визита.",
    ],
    # b_4
    "course_b_4_l1": [
        "Семь = джет↘ (เจ็ด). Путают с «дет» — и цены, и время едут.",
    ],
    "course_b_4_l3": [
        "เย็น — и «вечер», и «холодно». Смысл только из контекста — классика тайского.",
    ],
    "course_b_4_l5": [
        "В такси: тронг пай + палец куда ехать. Чот тронг ни — останови.",
    ],
    # b_7 scenes
    "course_b_7_l1": [
        "В 7-Eleven очередь любит короткие хвосты: саватди кхрап → просьба → кхоп кхун.",
    ],
    "course_b_7_l2": [
        "«Без острого» говори до готовки. После — уже поздно и неловко.",
    ],
    "course_b_7_l3": [
        "Назови ориентир (отель, Big C, сои), не только адрес — таксист так ездит в голове.",
    ],
    "course_b_7_l4": [
        "Торг с улыбкой. Резкое «дорого!» без улыбки звучит как конфликт.",
    ],
    "course_b_7_l5": [
        "Соседу достаточно имени + «живу рядом». Допрос «откуда и зачем» — лишний.",
    ],
    # Life
    "course_l_1_l1": [
        "На посту улыбка и спокойный тон важнее идеального произношения.",
    ],
    "course_l_1_l2": [
        "Паспорт показывают, а не пересказывают. Короткий ответ + документ.",
    ],
    "course_l_1_l3": [
        "Куда / откуда / сколько дней — отвечай одной фразой. Лишняя история настораживает.",
    ],
    "course_l_1_l4": [
        "Май пэн рай на посту = «всё ок, без драмы». Не «мне всё равно».",
    ],
    "course_l_2_l1": [
        "Назови район или большой ориентир — таксист поймёт быстрее улицы.",
    ],
    "course_l_2_l2": [
        "Цену лучше спросить до посадки. После старта торговаться уже странно.",
    ],
    "course_l_2_l4": [
        "Чот тронг ни + палец в окно. Так останавливают чаще, чем длинным адресом.",
    ],
    "course_l_2_l7": [
        "Ночью метр и приложение часто спокойнее торга на улице — и для тебя, и для водителя.",
    ],
    "course_l_3_l3": [
        "Пхэнг с улыбкой — начало торга. Пхэнг без улыбки — начало ссоры.",
    ],
    "course_l_3_l5": [
        "Фрукты считают штуками и кило. Уточни ан / кило — иначе цена «поедет».",
    ],
    "course_l_4_l1": [
        "Пад тай и сом там знают все. Названия блюд — твой быстрый пропуск в заказ.",
    ],
    "course_l_4_l3": [
        "Пхет ной на скажи сразу. Переделать уже готовое острое почти нельзя.",
    ],
    "course_l_4_l7": [
        "Аллергия — первое слово заказа, не после «а-рой мак».",
    ],
    "course_l_5_l1": [
        "В аптеке: симптом → «я» → что нужно. Так фармацевт быстрее поймёт.",
    ],
    "course_l_5_l5": [
        "«Май пхэ» (нет аллергии) или название аллергена — лучше перебдеть.",
    ],
    "course_l_6_l3": [
        "Жалоба на кондей звучит мягче с «ми пан ха ной», чем с раздражением.",
    ],
    "course_l_6_l4": [
        "Early check-in просят как вопрос «дай май?», не как требование.",
    ],
    "course_l_14_l3": [
        "Трек-номер — твой главный аргумент. Без него курьер и поддержка глухие.",
    ],
    "course_l_14_l4": [
        "«Где курьер?» лучше с адресом и треком в одном сообщении.",
    ],
    "course_l_7_l1": [
        "ที่ร่ม = в тени. ร่ม = зонт. Одно «ром», разные просьбы — лови контекст.",
    ],
    "course_l_7_l3": [
        "Кокос «ма пхрау» — пляжный пароль. «Нам» тут чаще вода, не сок из пачки.",
    ],
    "course_l_8_l3": [
        "На кассе очередь любит готовность: карта/QR достань заранее.",
    ],
    "course_l_8_l7": [
        "Возврат спокойным тоном + чек. Эмоции кассиру не помогают.",
    ],
    "course_l_9_l1": [
        "Чуай ной — универсальный зов о помощи. Громко и ясно важнее акцента.",
    ],
    "course_l_9_l6": [
        "Адрес и телефон скажи дважды. В стрессе цифры путают все.",
    ],
    "course_l_10_l1": [
        "Абонемент = บัตรสมาชิก. Просто «бат» могут понять как банковскую карту.",
    ],
    "course_l_11_l1": [
        "На Сонгкране мокрый = норма. Сухой хмурый турист — редкий персонаж.",
    ],
    "course_l_11_l2": [
        "Лой Кратонг: кратонг пускают с уважением, не как мусор в воду.",
    ],
    "course_l_12_l1": [
        "Фото стрижки на телефоне спасает лучше десяти прилагательных.",
    ],
    "course_l_12_l4": [
        "หนวด = усы. Борода — เครา. Путают даже в салонах для фарангов.",
    ],
    "course_l_13_l1": [
        "Про протечку пиши сразу с фото. «Потом» в кондо часто значит «никогда».",
    ],
    "course_l_13_l6": [
        "В чат с хозяином — коротко и без капса. Капс читают как крик.",
    ],
    "course_l_15_l2": [
        "Цену за напиток лучше уточнить до «ещё один» — ночные меню хитрят.",
    ],
    "course_l_15_l5": [
        "Знакомство в баре: имя + откуда хватает. Допрос биографии — минус вайб.",
    ],
    # Ethics — cultural shareables
    "course_e_5_l1": [
        "Крэнг-джай — не «мне всё равно», а «стесняюсь тебя обременить».",
    ],
    "course_e_5_l2": [
        "Джай-йен = «сделай сердце холодным»: просьба не кипятиться, не оскорбление.",
    ],
    "course_e_5_l3": [
        "Май пэн рай иногда значит «отстань мягко», а не «всё правда ок».",
    ],
    "course_e_5_l4": [
        "Обходное «позже / посмотрим» часто уже отказ. Читай паузу, не только слова.",
    ],
    "course_e_6_l1": [
        "Ной и на в конце — как смягчитель. Без них просьба звучит приказом.",
    ],
    "course_e_6_l3": [
        "Кхрап/ка можно почти к любой фразе. Одна частица — другой вайб.",
    ],
    "course_e_6_l5": [
        "Фаранг-резкость: прямой «сделай сейчас» без смягчения режет ухо.",
    ],
    "course_e_1_l1": [
        "Коротко и ясно бьёт точнее длинного вежливого тумана.",
    ],
    "course_e_2_l2": [
        "«Как статус?» мягче дедлайна. Давление без крэнг-джай портит работу.",
    ],
    "course_e_2_l4": [
        "Комплимент работе («там ди мак») открывает двери быстрее критики.",
    ],
    "course_e_3_l1": [
        "Перед просьбой к персоналу: роп куан на — «извините что беспокою».",
    ],
    "course_e_4_l1": [
        "Извинение без самоунижения: кхо тхот + коротко что не так.",
    ],
    "course_e_4_l5": [
        "Сохранить лицо обоим важнее «доказать кто прав» — так гасят конфликт.",
    ],
    # Spec / soul
    "course_s_1_l5": [
        "555 в чате = ха-ха-ха. Вслух лучше сказать «кхам», не «пять пять пять».",
    ],
    "course_s_3_l1": [
        "555 и «джин» — маркеры «я свой» в чате. Без них текст суше.",
    ],
    "course_s_3_l3": [
        "Нам-джай = щедрое сердце. Комплимент сильнее пустого «ди мак».",
    ],
    "course_s_4_l1": [
        "На ретрите молчание — уважение, не наказание. Шепот тоже считается шумом.",
    ],
    "course_s_4_l5": [
        "С монахами: ниже головой, тише голосом, без фамильярного «хай».",
    ],
    "course_s_5_l1": [
        "На-рак — мило. Перебор комплиментов незнакомцу читается странно.",
    ],
    "course_s_5_l4": [
        "Май яак = граница. В романтике это уважение, не холодность.",
    ],
    "course_s_6_l2": [
        "Кэнг маак детям — топливо. Тайские родители хвалят часто и вслух.",
    ],
    "course_s_6_l3": [
        "Раванг на — мягкое «осторожно». Окрик без на звучит жёстче, чем нужно.",
    ],
    "course_s_2_l1": [
        "Муай-тай — слово-бренд. Можно не переводить: так и говорят.",
    ],
    # Longstay
    "course_long_1_l1": [
        "90-day report проще сделать до дедлайна. Штраф дороже часа в иммиграции.",
    ],
    "course_long_1_l3": [
        "TM.30 часто «забывают» хозяева. Напомни мягко — спасает от штрафа тебе.",
    ],
    "course_long_2_l2": [
        "PromptPay по телефону — местный суперсила. Карта не всегда нужна.",
    ],
    "course_long_2_l5": [
        "Заморозка карты: сначала банк по телефону, потом отделение. Так быстрее.",
    ],
    "course_long_3_l3": [
        "Аллергию на лекарство скажи до укола/таблетки — потом уже поздно.",
    ],
    "course_long_3_l4": [
        "«Страховка покрывает?» спроси до дорогих анализов, не после.",
    ],
    "course_long_4_l2": [
        "Залог байка и фото царапин до выезда — классика, которая экономит скандал.",
    ],
    "course_long_4_l5": [
        "Сонгтео: стукни монеткой / скажи остановку заранее. Молчание = проедешь мимо.",
    ],
    "course_long_5_l1": [
        "Просьба о тишине с «ной на» работает. Капс в чате кондо — эскалация.",
    ],
    "course_long_5_l2": [
        "Курение на балконе — частый триггер соседей. Правила дома читай до спора.",
    ],
    "course_long_6_l1": [
        "На вакцинацию бери паспорт питомца. Без бумажки клиника глухая.",
    ],
    "course_long_7_l1": [
        "555 в чате смешно, в голосовом — лучше «кхам мак». Иначе звучишь как робот.",
    ],
    "course_long_7_l2": [
        "แซ่บ про еду = вкусно-огонь. Про человека — уже флирт. Контекст решает.",
    ],
}


def renumber(items: list) -> list:
    out = []
    for i, it in enumerate(items, 1):
        n = deepcopy(it)
        n["order"] = i
        out.append(n)
    return out


def is_drop(text: str) -> bool:
    t = (text or "").strip()
    if not t:
        return True
    if t in DROP_EXACT:
        return True
    if t in KEEP_EXACT:
        return False
    low = t.lower()
    return any(s in low for s in DROP_SUBSTRINGS)


def max_tips_for(course_id: str) -> int:
    if course_id == "course_b_0":
        return 99
    if course_id == "course_b_2":
        return 3
    return 2


def rebuild_lesson_tips(ss: dict, lesson_id: str, course_id: str) -> tuple[int, int, int]:
    """Returns (kept_old, dropped, added_curated)."""
    items = ss.get("items") or []
    non_tips = [it for it in items if it.get("kind") != "tip"]
    old_tips = [it for it in items if it.get("kind") == "tip"]

    kept = []
    dropped = 0

    if course_id == "course_b_0":
        # keep all non-empty
        for it in old_tips:
            t = (it.get("text") or "").strip()
            if t:
                kept.append(it)
            else:
                dropped += 1
    elif course_id == "course_b_2":
        for it in old_tips:
            t = (it.get("text") or "").strip()
            if is_drop(t):
                dropped += 1
            elif t:
                kept.append(it)
            else:
                dropped += 1
    else:
        for it in old_tips:
            t = (it.get("text") or "").strip()
            if is_drop(t):
                dropped += 1
            elif t in KEEP_EXACT or (t and not is_drop(t) and len(t) >= 24 and "курс" not in t.lower()):
                # keep shareable-looking unique tips
                # still drop curriculum pointers with «курс»
                if re.search(r"в курсе|следующ|уже в", t, re.I):
                    dropped += 1
                else:
                    kept.append(it)
            else:
                dropped += 1

    kept_old = len(kept)

    # Curated overlay: if lesson in SCENARIO, use that as authoritative set
    # (unless b_0 — never replace)
    added = 0
    if course_id != "course_b_0" and lesson_id in SCENARIO:
        curated = SCENARIO[lesson_id]
        # replace tips with curated
        kept = []
        for text in curated:
            kept.append({"kind": "tip", "text": text, "order": 0})
            added += 1
        # count previous kept as dropped if replaced
        dropped += kept_old
        kept_old = 0
    elif course_id != "course_b_0" and lesson_id not in SCENARIO:
        # no curated: keep only filtered; cap
        pass

    # Cap
    cap = max_tips_for(course_id)
    if len(kept) > cap:
        dropped += len(kept) - cap
        kept = kept[:cap]

    # Put tips first (common pattern), then cards — preserve relative card order
    new_items = kept + non_tips
    ss["items"] = renumber(new_items)
    return kept_old, dropped, added


def sync_card_counts(lessons_doc: dict, steps_doc: dict) -> None:
    by = {s["lesson_id"]: s for s in steps_doc["stepsets"]}
    for c in lessons_doc["courses"]:
        for les in c.get("lessons") or []:
            ss = by.get(les["lesson_id"])
            if not ss:
                continue
            if c["course_id"] == "course_b_0":
                # theory: tips count as cards
                les["card_count"] = sum(1 for it in ss["items"] if it.get("kind") == "tip")
            else:
                les["card_count"] = sum(1 for it in ss["items"] if it.get("kind") in LEARNABLE)


def metrics(steps_doc: dict, lessons_doc: dict) -> dict:
    by = {s["lesson_id"]: s for s in steps_doc["stepsets"]}
    lessons_n = 0
    with_tips = 0
    zero = 0
    total_tips = 0
    boilerplate = 0
    for c in lessons_doc["courses"]:
        for les in c.get("lessons") or []:
            lessons_n += 1
            ss = by[les["lesson_id"]]
            tips = [(it.get("text") or "").strip() for it in ss["items"] if it.get("kind") == "tip"]
            total_tips += len(tips)
            if tips:
                with_tips += 1
            else:
                zero += 1
            for t in tips:
                if t in DROP_EXACT or any(s in t.lower() for s in DROP_SUBSTRINGS[:5]):
                    boilerplate += 1
    return {
        "lessons": lessons_n,
        "with_tips": with_tips,
        "zero_tips": zero,
        "total_tips": total_tips,
        "boilerplate_left": boilerplate,
        "avg_when_present": round(total_tips / with_tips, 2) if with_tips else 0,
    }


def main() -> None:
    steps_doc = json.loads(STEPS_PATH.read_text(encoding="utf-8"))
    lessons_doc = json.loads(LESSONS_PATH.read_text(encoding="utf-8"))
    before = metrics(steps_doc, lessons_doc)

    tot_kept = tot_drop = tot_add = 0
    for ss in steps_doc["stepsets"]:
        lid = ss.get("lesson_id") or ""
        cid = ss.get("course_id") or ""
        k, d, a = rebuild_lesson_tips(ss, lid, cid)
        tot_kept += k
        tot_drop += d
        tot_add += a

    sync_card_counts(lessons_doc, steps_doc)
    after = metrics(steps_doc, lessons_doc)

    STEPS_PATH.write_text(json.dumps(steps_doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    LESSONS_PATH.write_text(json.dumps(lessons_doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    lines = [
        "# Curriculum iteration 4 — lifehacks (shareable-only)",
        "",
        "## Model",
        "",
        "- Lifehack is optional (0 per lesson is OK)",
        "- b_0: tips-only storytelling kept",
        "- b_2: tone-profile lifehacks kept (≤3)",
        "- Elsewhere: curated shareable facts / mistakes / local customs (≤2)",
        "- Boilerplate & editor-meta removed",
        "",
        "## Metrics",
        "",
        "| | Before | After |",
        "|---|---:|---:|",
        f"| Total lifehack items | {before['total_tips']} | {after['total_tips']} |",
        f"| Lessons with ≥1 lifehack | {before['with_tips']} | {after['with_tips']} |",
        f"| Lessons with 0 lifehacks | {before['zero_tips']} | {after['zero_tips']} |",
        f"| Avg tips when present | {before['avg_when_present']} | {after['avg_when_present']} |",
        f"| Boilerplate left | {before['boilerplate_left']} | {after['boilerplate_left']} |",
        "",
        f"Kept old shareable≈{tot_kept}, dropped≈{tot_drop}, curated added≈{tot_add}",
        "",
        "## Note",
        "",
        "Card `tip` fields (Taika FM micro-hints) are unchanged — separate layer.",
        "",
    ]
    REPORT_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("BEFORE", before)
    print("AFTER ", after)
    print(f"kept_old={tot_kept} dropped={tot_drop} curated_added={tot_add}")


if __name__ == "__main__":
    main()
