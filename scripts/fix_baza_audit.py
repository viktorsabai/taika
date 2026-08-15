#!/usr/bin/env python3
"""Apply CLO audit fixes to База courses (P0–P2)."""

from __future__ import annotations

import json
from copy import deepcopy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LESSONS_PATH = ROOT / "lessons.json"
STEPS_PATH = ROOT / "steps.json"
REPORT_PATH = ROOT / "docs" / "baza_courses_report.md"

LEARNABLE = {"word", "phrase", "casual"}


def renumber(items: list) -> list:
    out = []
    for i, it in enumerate(items, 1):
        n = deepcopy(it)
        n["order"] = i
        out.append(n)
    return out


def tip(order: int, text: str) -> dict:
    return {"order": order, "kind": "tip", "text": text}


def learnable_count(items: list) -> int:
    return sum(1 for it in items if it.get("kind") in LEARNABLE)


def find_ss(steps_doc: dict, lesson_id: str) -> dict:
    for s in steps_doc["stepsets"]:
        if s.get("lesson_id") == lesson_id:
            return s
    raise KeyError(lesson_id)


def drop_ru(items: list, *rus: str) -> list:
    want = {r.strip().lower() for r in rus}
    return [it for it in items if (it.get("ru") or "").strip().lower() not in want]


def replace_ru(items: list, old_ru: str, new_item: dict) -> list:
    out = []
    for it in items:
        if (it.get("ru") or "").strip().lower() == old_ru.strip().lower():
            n = deepcopy(new_item)
            n["order"] = it.get("order", 0)
            out.append(n)
        else:
            out.append(it)
    return out


def set_phonetic(items: list, *, thai: str | None = None, ru: str | None = None, phonetic: str) -> None:
    for it in items:
        if thai and it.get("thai") == thai:
            it["phonetic"] = phonetic
        if ru and (it.get("ru") or "").strip().lower() == ru.strip().lower():
            it["phonetic"] = phonetic


def ensure_tip(items: list, text: str, *, at_start: bool = False) -> list:
    texts = [it.get("text") for it in items if it.get("kind") == "tip"]
    if text in texts:
        return items
    t = tip(0, text)
    return [t] + items if at_start else items + [t]


# --- lesson shell texts (intro / outline / apply) ---

CONTENT: dict[str, tuple[str, str, str]] = {
    # b_0
    "course_b_0_l1": (
        "Снимаем страх перед тайским: язык проще, чем кажется, если мыслить короткими смыслами.",
        "Почему тайский не «как русский» · глагол без спряжений · фразы вместо перевода · короткие просьбы.",
        "Сегодня: скажи одну готовую фразу вместо перевода с русского — например «можно воды?».",
    ),
    "course_b_0_l2": (
        "Тоны — не теория для экзамена, а мелодия слова. Стрелки помогают слышать, а не зубрить названия.",
        "Почему тон меняет смысл · слушай → повтори · стрелки вверх/вниз/ровно · ошибки нормальны.",
        "Послушай 3 слова со стрелками и повтори вслух, не глядя на экран.",
    ),
    "course_b_0_l3": (
        "Как думают тайцы в разговоре: коротко, мягко, с улыбкой и вежливым хвостиком.",
        "Короткие фразы · местоимения по ситуации · кхрап/ка · мягкий отказ · объяснить вместо слова.",
        "В следующий раз в кафе добавь кхрап или ка к любой просьбе — и улыбнись.",
    ),
    # b_1
    "course_b_1_l1": (
        "Базовые приветствия: саватди, вежливый хвост и casual «ватди».",
        "สวัสดี · สวัสดีครับ · หวัดดี · прощание · вай и улыбка.",
        "Поздоровайся в 7-Eleven или кафе: саватди + кхрап/ка.",
    ),
    "course_b_1_l2": (
        "Имя и «откуда» — минимум для знакомства без допроса.",
        "Как зовут · меня зовут · откуда · я из России · очень приятно.",
        "Представься одному человеку: имя + «я из России».",
    ),
    "course_b_1_l3": (
        "Small talk: «как дела?» и короткие ответы по-тайски.",
        "สบายดีไหม · ответы от chill до «так себе» · окей.",
        "Спроси «сабай ди май?» у продавца или соседа и ответь коротко.",
    ),
    "course_b_1_l4": (
        "Формулы просьб на кассе и в кафе: вода, счёт, без острого, пакет.",
        "ได้ไหม · ขอน้ำหน่อย · без острого · чек-бин · пакет · ещё один.",
        "В кафе попроси воду или скажи «без острого» одной фразой.",
    ),
    "course_b_1_l5": (
        "Где тут: туалет, здесь, останови — без полной навигации.",
        "อยู่ที่ไหน · туалет · здесь · останови · вайфай · я заблудился.",
        "Спроси, где туалет, или скажи таксисту «останови здесь».",
    ),
    "course_b_1_l6": (
        "Цена и оплата: сколько, дорого, скидка, карта, QR.",
        "เท่าไหร่ · дорого · скидка · карта · наличные · QR · ок беру.",
        "На рынке или в магазине спроси «тао рай?» и при необходимости «лот дай май?».",
    ),
    "course_b_1_l7": (
        "Вежливый минимум: спасибо и извини — без них не обойтись.",
        "ขอบคุณ · ขอบคุณมาก · ขอโทษ · ничего страшного · сорри мягко.",
        "Сегодня скажи «кхоп кхун» после любой покупки или помощи.",
    ),
    # b_2
    "course_b_2_l1": (
        "Одна мелодия «маа» — три смысла. Здесь учим тон, не новый словарь.",
        "มา / หมา / ม้า · вода нам · фразы с приходом и собакой.",
        "Произнеси маа→, маа↘ и маа↗ подряд и почувствуй разницу.",
    ),
    "course_b_2_l2": (
        "май↘ «не» и май↗ «новый» — одна запись в ушах, разный тон.",
        "ใหม่ · ไม่ · «не хочу» · «это новое?» · новый дом / друг.",
        "Скажи «май↘ яак» и «баан май↗» — проверь, что тоны разные.",
    ),
    "course_b_2_l3": (
        "Эмоции тоном: боль вниз, удивление вверх, восторг.",
        "โอ้ย · เอ๊ะ · ว้าว · джанг · жарко · вкусно · дорого · жалко.",
        "В кафе скажи «а-рой джанг» или «пхэнг мак» с нужной эмоцией.",
    ),
    "course_b_2_l4": (
        "Как тайцы глотают слоги: медленная vs нативная скорость знакомых фраз.",
        "สบายดีไหม медленно и быстро · цена · куда · вкусно · спасибо.",
        "Возьми «сабай ди май» и произнеси сначала полностью, потом сжато.",
    ),
    "course_b_2_l5": (
        "Хвостики ной и на смягчают просьбу — звучишь менее приказно.",
        "หน่อย · หน่อยนะ · спасибо на · да кхрап · ок ной на.",
        "Добавь «ной» или «ной на» к любой просьбе сегодня.",
    ),
    "course_b_2_l6": (
        "Те же фразы из старта, но с коротким кхрап/ка — как в 7-Eleven.",
        "Вежливые версии: привет · как дела · цена · вода · счёт · пакет · спасибо.",
        "Собери мини-сцену: саватди кхрап → просьба → кхоп кхун мак кхрап.",
    ),
    # b_3
    "course_b_3_l1": (
        "Кто говорит: пхом / чхан / кун / рао — выбери своё «я».",
        "ผม · ฉัน · คุณ · เรา · это мой друг · это ты?",
        "Представься с выбранным «я»: пхом или чхан + имя.",
    ),
    "course_b_3_l2": (
        "Говорим о других: он/она, они, короткие факты.",
        "เขา · เธอ · พวกเขา · зовут · таец · подруга · работает здесь.",
        "Расскажи об одном человеке: «кхау чыу…» или «тхё там нгаан…».",
    ),
    "course_b_3_l3": (
        "Семья с теплом: мама, папа, братья и сёстры.",
        "แม่ · พ่อ · พี่น้อง · есть мама · семья в России · сколько братьев.",
        "Скажи одну фразу о своей семье: «чхан ми мэ» или про брата/сестру.",
    ),
    "course_b_3_l4": (
        "Возраст и профессия — типичные вопросы после знакомства.",
        "อายุ · сколько лет · работаю · чем занимаешься · учитель · фриланс.",
        "Ответь на «кун там арай?» одной короткой фразой.",
    ),
    "course_b_3_l5": (
        "Чей: мой, твой, его — сумка, телефон, дом, семья.",
        "ของฉัน · ของคุณ · сумка · телефон · наш дом · его машина.",
        "Укажи на вещь и скажи «ни … кхонг чхан».",
    ),
    "course_b_3_l6": (
        "Сборка знакомства: привет + имя + откуда + семья.",
        "Мини-диалог целиком · имя Анна · Пхукет · семья · рад познакомиться.",
        "Проговори диалог вслух от начала до «рад познакомиться».",
    ),
    "course_b_3_l7": (
        "Друзья и гости: позвать, прийти, зайти.",
        "เพื่อน · แขก · в гости · пригласить · на кофе · заходи.",
        "Пригласи кого-то «маа йиам на» или «чён ду кафэ».",
    ),
    # b_4
    "course_b_4_l1": (
        "Числа 1–10 — база для цен, времени и счёта людей.",
        "หนึ่ง…สิบ · слушай тон на 4, 5, 9 · семь = джет.",
        "Посчитай вслух от 1 до 10 и обратно.",
    ),
    "course_b_4_l2": (
        "Десятки и сотни для рынка и счёта.",
        "20–50 · 100 · กี่ · штуки · 21 · цены в батах.",
        "Скажи цену: «ха сип бат» или «рой бат».",
    ),
    "course_b_4_l3": (
        "Который час и куски дня: утро, полдень, вечер.",
        "กี่โมง · часы · เช้า · เย็น · сейчас · через 10 минут.",
        "Спроси или скажи время: «сип монг чау» или «ик сип нати».",
    ),
    "course_b_4_l4": (
        "Дни недели + сегодня / завтра / вчера.",
        "วันจันทร์…วันอาทิตย์ · сегодня · завтра · вчера.",
        "Скажи, какой сегодня день: «ван ни …».",
    ),
    "course_b_4_l5": (
        "Навигация в такси: прямо, налево, направо, метры.",
        "ตรงไป · เลี้ยวซ้าย/ขวา · 100 метров · далеко/близко.",
        "В такси или вслух: «тронг пай» + «лиао сай» или «лиао кхва».",
    ),
    "course_b_4_l6": (
        "Счёт людей и раз: сколько человек, сколько раз.",
        "คน · กี่คน · ครั้ง · каждый день · раз в неделю.",
        "Скажи «сон кон» или «кхраанг нынг» в подходящей ситуации.",
    ),
    # b_5
    "course_b_5_l1": (
        "Движение: идти и приходить + куда.",
        "ไป · มา · куда идёшь · домой · магазин · вчера пришёл.",
        "Ответь на «пай най?» — «пай баан» или «пай ран».",
    ),
    "course_b_5_l2": (
        "Хотеть, любить, нужно — ядро желаний и планов.",
        "อยาก · ชอบ · ต้อง · хочу есть · не хочу · люблю острое.",
        "Скажи «яак кин» или «май↘ яак» с правильным тоном на май.",
    ),
    "course_b_5_l3": (
        "Говорить и понимать — спасательные фразы для разговора.",
        "พูด · เข้าใจ · не понимаю · медленнее · повторите · слушай.",
        "Если не понял — скажи «май кхао джай» или «пхуут ик тхи».",
    ),
    "course_b_5_l4": (
        "Есть, пить, покупать, готовить, заказать.",
        "กิน · ดื่ม · ซื้อ · рис · вода · заказать кофе · уже ел.",
        "Закажи или скажи «кин кхао» / «дум нам» в кафе.",
    ),
    "course_b_5_l5": (
        "Делать и работать: что делаешь, где работаешь, помоги.",
        "ทำ · ทำงาน · отдыхать · что делаешь · помоги пожалуйста.",
        "Ответь «чхан там нгаан» или попроси «чуай ной».",
    ),
    "course_b_5_l6": (
        "Быт: спать, сидеть, давать, брать.",
        "นอน · นั่ง · ให้ · เอา · сиди здесь · дай воды · не бери.",
        "Попроси «хай нам» или скажи «нонг ти ни».",
    ),
    "course_b_5_l7": (
        "Знать, видеть, жить — факты о себе и месте.",
        "รู้ · เห็น · อยู่ · живу здесь · где живёшь · не знаю.",
        "Скажи «ю ти ни» или «май руу» в реальном разговоре.",
    ),
    # b_6
    "course_b_6_l1": (
        "Еда: вкусно, остро, сладко — и просьбы про уровень остроты.",
        "อร่อย · เผ็ด · หวาน · очень вкусно · пхет ной · не сладко.",
        "В кафе скажи «а-рой мак» или «пхет ной на».",
    ),
    "course_b_6_l2": (
        "Красиво и про цену: дёшево / дорого для вещей и отеля.",
        "สวย · ราคา · ถูก · แพง · слишком дорого для меня.",
        "Оцени вещь: «суай мак» или «пхэнг пай сам рап чхан».",
    ),
    "course_b_6_l3": (
        "Горячо и холодно — погода и напитки. เย็น = и вечер, и холод.",
        "ร้อน · เย็น · อุ่น · лёд · холодная вода · сегодня жарко.",
        "Закажи «нам ен» или скажи «ван ни рон».",
    ),
    "course_b_6_l4": (
        "Размер: большой / маленький — дом, номер и порция в кафе.",
        "ใหญ่ · เล็ก · большой или маленький · дайте большую/маленькую.",
        "В кафе выбери размер: «ау яй» или «ау лек».",
    ),
    "course_b_6_l5": (
        "Оценка: хороший / плохой, удобно, обычно.",
        "ดี · ไม่ดี · удобный · всё хорошо · плохая погода · неудобно.",
        "Скажи «ди мак» или «май са дуак» по ситуации.",
    ),
    "course_b_6_l6": (
        "Новый, старый, быстрый, простой, сложный.",
        "ใหม่ · เก่า · เร็ว · ช้า · ง่าย · ยาก · тайский сложный?",
        "Скажи «пхуут ча» или ответь на «паса тай як май?».",
    ),
    # b_7
    "course_b_7_l1": (
        "Капстоун 7-Eleven: склей привет + просьбу + спасибо из старта.",
        "Вода · вот пожалуйста · пакет · готово · порядок очереди из tip.",
        "Собери сцену вслух: саватди → кхо нам ной → кхоп кхун.",
    ),
    "course_b_7_l2": (
        "Кафе: заказ и добор — без острого и счёт уже в старте.",
        "สั่ง · ещё кофе · ещё воды · с собой · вставь «без острого» и чек-бин.",
        "Собери заказ: санг + напиток + «май пхет» + чек-бин.",
    ),
    "course_b_7_l3": (
        "Такси: куда едем + повороты + останови.",
        "Аэропорт · отель · налево/направо · останови здесь · до свидания.",
        "Проговори маршрут: «пай санам бин» → «лиао…» → «чот тронг ни».",
    ),
    "course_b_7_l4": (
        "Рынок: торг из старта + количество, упаковка, сдача.",
        "Две штуки · упакуйте · сдача · слишком дорого · цена/скидка из старта.",
        "Собери торг: тао рай → пхэнг → лот дай май → хо хай ной.",
    ),
    "course_b_7_l5": (
        "Сосед: люди рядом после знакомства из старта и семьи из b_3.",
        "Семья · живу рядом · сосед · давно здесь? · имя/откуда не дублируем.",
        "Скажи «чхан ю тхэу ни» или спроси «ю ти ни нан ры янг?».",
    ),
    "course_b_7_l6": (
        "Финал Базы: время + куда + поехали + до встречи.",
        "Который час · куда идёшь · поехали · хороший день · до встречи.",
        "Собери день целиком вслух; если спотыкаешься — вернись в b_1 или b_4.",
    ),
}


def apply_steps(steps_doc: dict) -> list[str]:
    log: list[str] = []

    # --- P0 correctness ---
    b4l1 = find_ss(steps_doc, "course_b_4_l1")
    set_phonetic(b4l1["items"], thai="เจ็ด", phonetic="джет↘")
    log.append("P0: เจ็ด phonetic → джет↘")

    b5l2 = find_ss(steps_doc, "course_b_5_l2")
    set_phonetic(b5l2["items"], thai="ไม่อยาก", phonetic="май↘ яак↘")
    log.append("P0: ไม่อยาก tone aligned to май↘ (как в b_2)")

    b7l3 = find_ss(steps_doc, "course_b_7_l3")
    set_phonetic(b7l3["items"], thai="เลี้ยวซ้าย", phonetic="лиао→ сай↘")
    set_phonetic(b7l3["items"], thai="เลี้ยวขวา", phonetic="лиао→ кхва↗")
    log.append("P0: b_7 taxi เลี้ยว phonetics → лиао / кхва")

    b7l6 = find_ss(steps_doc, "course_b_7_l6")
    set_phonetic(b7l6["items"], thai="กี่โมง", phonetic="ги→ монг↗")
    log.append("P0: b_7 กี่โมง → ги→ монг↗")

    # --- P1 dedupe / theme ---
    b1l1 = find_ss(steps_doc, "course_b_1_l1")
    before = len(b1l1["items"])
    b1l1["items"] = renumber(drop_ru(b1l1["items"], "Приятно познакомиться"))
    b1l1["items"] = ensure_tip(
        b1l1["items"],
        "«Очень приятно» (ยินดีที่ได้รู้จัก) — в следующем уроке «Знакомство».",
    )
    b1l1["items"] = renumber(b1l1["items"])
    log.append(f"P1: b_1_l1 drop «Приятно познакомиться» ({before}→{len(b1l1['items'])} items)")

    b2l5 = find_ss(steps_doc, "course_b_2_l5")
    b2l5["items"] = renumber(drop_ru(b2l5["items"], "Счёт пожалуйста вежливо"))
    b2l5["items"] = ensure_tip(
        b2l5["items"],
        "Вежливый «чек-бин кхрап» соберёшь в следующем уроке «В 7-Eleven».",
    )
    b2l5["items"] = renumber(b2l5["items"])
    log.append("P1: b_2_l5 drop duplicate чек-бин кхрап")

    b2l3 = find_ss(steps_doc, "course_b_2_l3")
    b2l3["items"] = replace_ru(
        b2l3["items"],
        "Спасибо",
        {
            "kind": "phrase",
            "ru": "Жалко!",
            "thai": "น่าเสียดาย",
            "phonetic": "на→ сиа→ дай↘",
            "tip": "Эмоция сожаления: тон вниз, как у оой.",
        },
    )
    b2l3["items"] = renumber(b2l3["items"])
    log.append("P1: b_2_l3 «Спасибо» → «Жалко!» (эмоция тоном)")

    b3l1 = find_ss(steps_doc, "course_b_3_l1")
    b3l1["items"] = renumber(drop_ru(b3l1["items"], "Он она"))
    b3l1["items"] = ensure_tip(
        b3l1["items"],
        "เขา «он/она» — в следующем уроке. Здесь держись я / ты / мы.",
    )
    b3l1["items"] = renumber(b3l1["items"])
    log.append("P1: b_3_l1 drop early เขา")

    b4l2 = find_ss(steps_doc, "course_b_4_l2")
    b4l2["items"] = replace_ru(
        b4l2["items"],
        "Десять",
        {"kind": "word", "ru": "Сорок", "thai": "สี่สิบ", "phonetic": "си→ сип→"},
    )
    b4l2["items"] = ensure_tip(
        b4l2["items"],
        "สิบ уже из урока 1–10. Здесь — десятки: 20, 30, 40, 50 и 100.",
        at_start=True,
    )
    b4l2["items"] = renumber(b4l2["items"])
    log.append("P1: b_4_l2 «Десять» → «Сорок» + tip")

    b4l1["items"] = ensure_tip(
        b4l1["items"],
        "Семь = джет↘ (เจ็ด). Не путай с «дет» — цифра уходит в цены и время.",
        at_start=True,
    )
    b4l1["items"] = renumber(b4l1["items"])
    log.append("P1: b_4_l1 tip про джет")

    b5l1 = find_ss(steps_doc, "course_b_5_l1")
    b5l1["items"] = renumber(drop_ru(b5l1["items"], "Сидеть", "Сиди здесь"))
    b5l1["items"] = ensure_tip(
        b5l1["items"],
        "«Сидеть / сиди здесь» — в уроке «Спать, сидеть, давать». Здесь только движение.",
    )
    b5l1["items"] = renumber(b5l1["items"])
    log.append("P1: b_5_l1 drop сидеть (тема L6)")

    b5l3 = find_ss(steps_doc, "course_b_5_l3")
    b5l3["items"] = renumber(drop_ru(b5l3["items"], "Понимаю"))
    b5l3["items"] = ensure_tip(
        b5l3["items"],
        "เข้าใจ одно и то же: «понимать» / «понимаю» — без спряжения. Держи одну карточку.",
        at_start=True,
    )
    b5l3["items"] = renumber(b5l3["items"])
    log.append("P1: b_5_l3 drop duplicate «Понимаю»")

    b6l4 = find_ss(steps_doc, "course_b_6_l4")
    b6l4["items"] = renumber(drop_ru(b6l4["items"], "Большая порция", "Маленькая порция"))
    b6l4["items"] = ensure_tip(
        b6l4["items"],
        "В кафе ใหญ่/เล็ก = размер порции. Те же слова, что «большой/маленький» — не учи дважды.",
        at_start=True,
    )
    b6l4["items"] = renumber(b6l4["items"])
    log.append("P1: b_6_l4 drop порция-дубли + tip")

    b6l6 = find_ss(steps_doc, "course_b_6_l6")
    b6l6["items"] = renumber(drop_ru(b6l6["items"], "Быстро"))
    b6l6["items"] = ensure_tip(
        b6l6["items"],
        "เร็ว — и «быстрый», и «быстро». Одна форма; «пхуут ча» уже даёт наречие.",
    )
    b6l6["items"] = renumber(b6l6["items"])
    log.append("P1: b_6_l6 drop «Быстро» duplicate")

    # --- P2 tips + b_7 strengthen ---
    b4l3 = find_ss(steps_doc, "course_b_4_l3")
    b4l3["items"] = ensure_tip(
        b4l3["items"],
        "เย็น здесь «вечер». То же слово в «Горячо и холодно» значит «холодно / холодный» — контекст решает.",
    )
    b4l3["items"] = renumber(b4l3["items"])

    b6l3 = find_ss(steps_doc, "course_b_6_l3")
    b6l3["items"] = ensure_tip(
        b6l3["items"],
        "เย็น = холодно (напиток/погода). В уроке про время то же слово — «вечер».",
        at_start=True,
    )
    b6l3["items"] = renumber(b6l3["items"])
    log.append("P2: tips เย็น вечер↔холодно")

    b1l5 = find_ss(steps_doc, "course_b_1_l5")
    b1l5["items"] = ensure_tip(
        b1l5["items"],
        "อยู่ที่ไหน — «где находится?». Позже с глаголом «жить» та же оболочка спросит «где живёшь?» — смысл из контекста.",
    )
    b1l5["items"] = renumber(b1l5["items"])

    b5l7 = find_ss(steps_doc, "course_b_5_l7")
    b5l7["items"] = ensure_tip(
        b5l7["items"],
        "«Где живёшь?» = อยู่ที่ไหน. Ту же форму в старте учили как «где это?» — слушай контекст.",
        at_start=True,
    )
    b5l7["items"] = renumber(b5l7["items"])
    log.append("P2: tips อยู่ที่ไหน контекст")

    # b_7 cafe: replace third «Очень вкусно»
    b7l2 = find_ss(steps_doc, "course_b_7_l2")
    b7l2["items"] = replace_ru(
        b7l2["items"],
        "Очень вкусно",
        {
            "kind": "phrase",
            "ru": "С собой",
            "thai": "เอาไป",
            "phonetic": "ау→ пай→",
            "tip": "В кафе: с собой vs здесь. «Очень вкусно» уже в b_6.",
        },
    )
    b7l2["items"] = renumber(b7l2["items"])
    log.append("P2: b_7 cafe «Очень вкусно» → «С собой»")

    # b_7 taxi: add stop
    has_stop = any((it.get("ru") or "") == "Останови здесь" for it in b7l3["items"])
    if not has_stop:
        # insert before «До свидания»
        items = []
        inserted = False
        for it in b7l3["items"]:
            if not inserted and (it.get("ru") or "") == "До свидания":
                items.append(
                    {
                        "kind": "phrase",
                        "ru": "Останови здесь",
                        "thai": "จอดตรงนี้",
                        "phonetic": "чот→ тронг→ ни↘",
                        "tip": "Из старта — здесь клеим к маршруту такси.",
                    }
                )
                inserted = True
            items.append(it)
        if not inserted:
            items.append(
                {
                    "kind": "phrase",
                    "ru": "Останови здесь",
                    "thai": "จอดตรงนี้",
                    "phonetic": "чот→ тронг→ ни↘",
                }
            )
        b7l3["items"] = renumber(items)
        log.append("P2: b_7 taxi + «Останови здесь»")

    # b_7 market: add too expensive
    b7l4 = find_ss(steps_doc, "course_b_7_l4")
    if not any((it.get("ru") or "") == "Слишком дорого" for it in b7l4["items"]):
        items = list(b7l4["items"])
        # before last tip if possible
        insert_at = len(items)
        for i, it in enumerate(items):
            if it.get("kind") == "tip" and i > 0:
                insert_at = i
        items.insert(
            insert_at,
            {
                "kind": "phrase",
                "ru": "Слишком дорого",
                "thai": "แพงไป",
                "phonetic": "пхэнг→ пай→",
                "tip": "Короткий торг после «пхэнг» из старта.",
            },
        )
        b7l4["items"] = renumber(items)
        log.append("P2: b_7 market + «Слишком дорого»")

    # b_2 hint on role
    b2l1 = find_ss(steps_doc, "course_b_2_l1")
    hints = list(b2l1.get("hints") or [])
    note = "Фразы могут быть знакомы из старта — здесь работаем тоном и скоростью, не словарём."
    if note not in hints:
        b2l1["hints"] = [note] + hints
        log.append("P2: b_2_l1 course-role hint")

    b7l1 = find_ss(steps_doc, "course_b_7_l1")
    hints = list(b7l1.get("hints") or [])
    note7 = "Капстоун Базы: склейка знакомых реплик в сцены. Новых слов мало — это нормально."
    if note7 not in hints:
        b7l1["hints"] = [note7] + hints
        log.append("P2: b_7_l1 capstone hint")

    return log


def apply_lessons(lessons_doc: dict, steps_doc: dict) -> list[str]:
    log: list[str] = []
    by_lesson = {s["lesson_id"]: s for s in steps_doc["stepsets"]}

    for c in lessons_doc["courses"]:
        if not str(c.get("course_id", "")).startswith("course_b_"):
            continue
        for les in c["lessons"]:
            lid = les["lesson_id"]

            # preview Monday
            if lid == "course_b_4_l4":
                if les.get("preview_phrase") != "понедельник;ван-джан→":
                    les["preview_phrase"] = "понедельник;ван-джан→"
                    log.append("P0: preview понедельник → ван-джан→")

            # which hour preview align
            if lid == "course_b_4_l3" and "монг ге" in (les.get("preview_phrase") or ""):
                les["preview_phrase"] = "который час?;ги монг↗"
                log.append("P0: preview который час → ги монг↗")

            # content shell
            if lid in CONTENT:
                intro, outline, apply_ = CONTENT[lid]
                les["content"] = [
                    {"kind": "intro", "text": intro},
                    {"kind": "outline", "text": outline},
                    {"kind": "apply", "text": apply_},
                ]

            # sync card_count
            ss = by_lesson.get(lid)
            if ss:
                les["card_count"] = learnable_count(ss["items"])

        mins = sum(int(les.get("duration_minutes") or 0) for les in c["lessons"])
        c["summary"] = {
            "total_lessons": len(c["lessons"]),
            "total_duration_minutes": mins,
        }

    # course blurbs
    blurbs = {
        "course_b_0": "Теория без паники: логика языка, тоны и как думают тайцы.",
        "course_b_1": "Survival-ядро: привет, просьбы, где, цена, спасибо.",
        "course_b_2": "Тон, скорость и вежливые хвостики на знакомых фразах.",
        "course_b_3": "Я/ты/он, семья, профессия и мини-диалог знакомства.",
        "course_b_4": "Числа, время, дни недели и навигация.",
        "course_b_5": "Главные глаголы для быта и разговора.",
        "course_b_6": "Оценки и описания: еда, цена, погода, размер.",
        "course_b_7": "Капстоун: склейка Базы в сцены 7-Eleven, кафе, такси, рынок.",
    }
    for c in lessons_doc["courses"]:
        cid = c.get("course_id")
        if cid in blurbs and not (c.get("description") or "").strip():
            c["description"] = blurbs[cid]
            log.append(f"P3: description {cid}")

    log.append("P2: filled intro/outline/apply for all База lessons")
    log.append("P3: synced card_count + summaries")
    return log


def write_report(lessons_doc: dict, steps_doc: dict, fix_log: list[str]) -> None:
    by_lesson = {s["lesson_id"]: s for s in steps_doc["stepsets"]}
    lines = [
        "# Оценка состава категории «База от Тайки»",
        "",
        "Обновлено после CLO-аудита (fix_baza_audit.py).",
        "",
        "Курсов в категории: **8** (`course_b_0` … `course_b_7`).",
        "",
        "## 1. Курсы и уроки",
        "",
    ]
    for c in lessons_doc["courses"]:
        if not str(c.get("course_id", "")).startswith("course_b_"):
            continue
        mins = (c.get("summary") or {}).get("total_duration_minutes")
        lines.append(f"### {c['course_id']}: {c.get('course_title')}")
        if c.get("description"):
            lines.append(f"- _{c['description']}_")
        lines.append(f"- Уроков: {len(c['lessons'])}, заявлено минут: {mins}")
        lines.append("")
        for les in sorted(c["lessons"], key=lambda x: x.get("order", 0)):
            ss = by_lesson.get(les["lesson_id"])
            n = learnable_count(ss["items"]) if ss else les.get("card_count")
            lines.append(
                f"- **{les.get('title')}** — {les.get('subtitle')} · cards={n} · preview=`{les.get('preview_phrase')}`"
            )
        lines.append("")

    empty = 0
    filled = 0
    for c in lessons_doc["courses"]:
        if not str(c.get("course_id", "")).startswith("course_b_"):
            continue
        for les in c["lessons"]:
            texts = [(b.get("text") or "").strip() for b in les.get("content") or []]
            if any(texts):
                filled += 1
            else:
                empty += 1

    lines += [
        "## 2. Заполненность intro / outline / apply",
        "",
        f"- Уроков **с текстом**: **{filled}**",
        f"- Уроков **без текста**: **{empty}**",
        "",
        "## 3. Применённые правки аудита",
        "",
    ]
    for item in fix_log:
        lines.append(f"- {item}")
    lines += [
        "",
        "## 4. Методическая рамка",
        "",
        "- **b_0** — mindset/теория; **b_1** — словарь выживания; **b_2** — тон/скорость/вежливость на знакомом;",
        "- **b_3–b_6** — расширение системы; **b_7** — капстоун-склейка (мало новых слов — норма).",
        "- Повторы между b_1↔b_2↔b_7 считаем спиралью, не браком, если tip/hint это объясняет.",
        "",
    ]
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    lessons_doc = json.loads(LESSONS_PATH.read_text(encoding="utf-8"))
    steps_doc = json.loads(STEPS_PATH.read_text(encoding="utf-8"))

    log = []
    log += apply_steps(steps_doc)
    log += apply_lessons(lessons_doc, steps_doc)

    LESSONS_PATH.write_text(
        json.dumps(lessons_doc, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    STEPS_PATH.write_text(
        json.dumps(steps_doc, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    write_report(lessons_doc, steps_doc, log)

    print("OK — applied fixes:")
    for line in log:
        print(" ", line)


if __name__ == "__main__":
    main()
