#!/usr/bin/env python3
"""Replace generic yellow cards in paid courses with lesson-specific phrases."""
from __future__ import annotations

import json
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STEPS = ROOT / "steps.json"
LESSONS = ROOT / "lessons.json"
DIFF = ROOT / "docs/paid_generic_fix_diff.json"
AUDIT = ROOT / "docs/launch_curriculum_traffic_light.json"
LEARNABLE = {"word", "phrase", "casual"}

# (lesson_id, old_thai, kind, ru, thai, phonetic, tip)
REPLACE: list[tuple[str, str, str, str, str, str, str]] = [
    ("course_l_1_l1", "เข้าใจแล้ว", "phrase", "Понял, что не так", "เข้าใจแล้วว่าผิดตรงไหน", "кау→ джай→ лэу→ ваа→ фит↘ тронг→ най↗", "На посту: не голое «понял»."),
    ("course_l_1_l5", "จ่ายบัตรได้ไหม", "phrase", "Штраф картой можно?", "ค่าปรับจ่ายบัตรได้ไหม", "кхаа→ прап→ джай→ бат→ дай→ май↗", "Оплата штрафа, не касса магазина."),
    ("course_l_2_l1", "นี่ที่อยู่", "phrase", "Адрес в приложении", "โชว์ที่อยู่ในแอป", "чоу→ ти→ ю→ най→ эп↘", "Такси: показать пин, не голое «вот адрес»."),
    ("course_l_2_l1", "จ่ายบัตรได้ไหม", "phrase", "Такси картой можно?", "แท็กซี่จ่ายบัตรได้ไหม", "тхэк→ си→ джай→ бат→ дай→ май↗", "Оплата поездки."),
    ("course_l_2_l2", "ตกลง", "phrase", "Цену зафиксировали", "ราคาตกลงแล้ว", "раа→ кхаа→ ток→ лонг→ лэу→", "Торг до посадки."),
    ("course_l_3_l4", "ตกลง", "phrase", "Беру по этой цене", "เอาตามราคานี้", "ау→ там→ раа→ кхаа→ ни→", "Рынок, не общее «договорились»."),
    ("course_l_4_l3", "เข้าใจ", "phrase", "Такой остроты хватит", "ระดับนี้พอ", "ра→ дап→ ни→ пхо→", "Про перец, не «понятно»."),
    ("course_l_4_l6", "เช็คบิล", "phrase", "Счёт на стол", "เช็คบิลโต๊ะนี้", "чек→ бин→ то→ ни→", "Ресторан, не отель и не бар."),
    ("course_l_4_l6", "รวม", "phrase", "Всё на один стол", "รวมโต๊ะนี้", "руам→ то→ ни→", "Одна оплата за компанию."),
    ("course_l_4_l6", "บัตร", "phrase", "Картой за еду", "จ่ายบัตรที่โต๊ะ", "джай→ бат→ ти→ то→", "Оплата за ужин."),
    ("course_l_4_l6", "เงินสด", "phrase", "Наличными за еду", "จ่ายเงินสดที่โต๊ะ", "джай→ нген→ сот↘ ти→ то→", "Наличные в ресторане."),
    ("course_l_5_l2", "เข้าใจ", "phrase", "Давно так?", "เป็นมานานไหม", "пэн→ маа→ наан→ май↗", "Врач уточняет симптом."),
    ("course_l_6_l1", "ชั้น", "phrase", "Номер на каком этаже?", "ห้องชั้นไหน", "хонг→ чан↘ най↗", "Отель, не магазин."),
    ("course_l_6_l2", "ผ้าเช็ดตัว", "phrase", "Не хватает полотенец", "ผ้าเช็ดตัวขาด", "пха→ чхет→ туа→ кхат→", "В номер, не пляж и не зал."),
    ("course_l_6_l5", "เช็คบิล", "phrase", "Счёт за номер", "บิลห้อง", "бин→ хонг→", "Выезд из отеля."),
    ("course_l_6_l5", "บัตร", "phrase", "Картой на ресепшен", "จ่ายบัตรที่ล็อบบี้", "джай→ бат→ ти→ лоп↘ би→", "Оплата проживания."),
    ("course_l_6_l5", "เงินสด", "phrase", "Наличными в лобби", "จ่ายเงินสดที่ล็อบบี้", "джай→ нген→ сот↘ ти→ лоп↘ би→", "Наличные при выезде."),
    ("course_l_7_l2", "ผ้าเช็ดตัว", "phrase", "Есть пляжное полотенце?", "มีผ้าชายหาดไหม", "ми→ пха→ чай→ хат→ май↗", "Шезлонг, не номер."),
    ("course_l_8_l1", "ชั้น", "phrase", "Товар на каком этаже?", "ของอยู่ชั้นไหน", "кхонг→ ю→ чан↘ най↗", "Магазин, не отель."),
    ("course_l_8_l1", "เข้าใจ", "phrase", "Нашёл где лежит", "หาเจอแล้ว", "хаа→ джё→ лэу→", "Ориентация в зале, не «понятно»."),
    ("course_l_8_l3", "บัตร", "phrase", "Картой на кассе", "จ่ายบัตรที่แคชเชียร์", "джай→ бат→ ти→ кэ→ чиа→", "Очередь на кассе."),
    ("course_l_8_l3", "เงินสด", "phrase", "Наличными на кассе", "จ่ายเงินสดที่แคชเชียร์", "джай→ нген→ сот↘ ти→ кэ→ чиа→", "Касса магазина."),
    ("course_l_8_l6", "รวม", "phrase", "Вся корзина вместе", "รวมทั้งตะกร้า", "руам→ тханг→ та→ краа→", "Итог покупки."),
    ("course_l_9_l6", "นี่ที่อยู่", "phrase", "Передайте адрес службе", "ส่งที่อยู่ให้หน่วย", "сонг→ ти→ ю→ хай→ нуай→", "Скорая, не такси."),
    ("course_l_10_l2", "โอเค", "phrase", "Хватит этот подход", "พอเซ็ตนี้", "пхо→ сет↘ ни→", "Зал, не голое «ок»."),
    ("course_l_10_l5", "ผ้าเช็ดตัว", "phrase", "Одолжите полотенце зала", "ขอยืมผ้ายิม", "кхо→ йым→ пха→ йим→", "Душ в зале."),
    ("course_l_12_l5", "รวม", "phrase", "Весь пакет", "รวมแพ็กเกจ", "руам→ пхэк→ кет↘", "Стрижка плюс цвет, не ресторан."),
    ("course_l_12_l5", "โอเค", "phrase", "Длина нормальная", "ความยาวพอดี", "кхвам→ яау→ пхо→ ди→", "Согласие на стрижку."),
    ("course_l_13_l2", "เงินสด", "phrase", "Аренду наличными", "จ่ายค่าเช่าเงินสด", "джай→ кхаа→ чау→ нген→ сот↘", "Съём, не касса."),
    ("course_l_14_l2", "นี่ที่อยู่", "phrase", "Привезите в эту комнату", "ส่งที่ห้องนี้", "сонг→ ти→ хонг→ ни→", "Курьер, не такси."),
    ("course_l_14_l2", "ชั้น", "phrase", "На третий этаж", "ส่งชั้นสาม", "сонг→ чан↘ саам→", "Куда нести заказ."),
    ("course_l_15_l1", "เช็คบิล", "phrase", "Ещё раунд на всех", "อีกรอบเดียวกัน", "ик→ роп→ диау→ кан→", "Бар: общий заказ, не кассовый счёт."),
    ("course_l_15_l2", "โอเค", "phrase", "Это пиво берём", "เบียร์นี้ได้", "биа→ ни→ дай→", "Согласие на цену напитка."),
    ("course_l_15_l5", "ขอบเขต", "phrase", "Не трогай", "อย่าแตะนะ", "йаа→ тэ→ на↗", "Знакомство в баре, не ретрит."),
    ("course_e_2_l1", "เข้าใจแล้ว", "phrase", "Задачу принял", "รับงานแล้ว", "рап→ нгаан→ лэу→", "Рабочий кивок, не сервисное «понял»."),
    ("course_e_2_l2", "ไม่กดดัน", "phrase", "Можно не спеша", "ค่อยๆ ทำได้", "кхой→ глай→ там→ дай→", "Статус без гонки."),
    ("course_e_3_l5", "เข้าใจแล้ว", "phrase", "Понял что делать дальше", "เข้าใจขั้นตอน", "кау→ джай→ кхан→ тон→", "Сервис: следующий шаг."),
    ("course_e_3_l6", "จ่ายบัตรได้ไหม", "phrase", "Ремонт картой можно?", "ค่าซ่อมจ่ายบัตรได้ไหม", "кхаа→ сом→ джай→ бат→ дай→ май↗", "Оплата услуги, не такси."),
    ("course_e_4_l6", "ตกลง", "phrase", "Тема закрыта", "พูดจบแล้ว", "пхуут→ джоп→ лэу→", "После ссоры, не торг."),
    ("course_e_5_l6", "ไม่กดดัน", "phrase", "Не заставляй отвечать", "อย่าบังคับตอบ", "йаа→ банг→ кхап↘ топ→", "Код общения, не дедлайн."),
    ("course_s_4_l6", "ขอบเขต", "phrase", "Здесь зона тишины", "โซนเงียบ", "соон→ нгиап→", "Ретрит, не знакомства."),
    ("course_s_5_l4", "ขอบเขต", "phrase", "Моя черта", "เส้นของฉัน", "сен→ кхонг→ чхан→", "В паре, не бар и не ретрит."),
    ("course_s_5_l4", "ไม่กดดัน", "phrase", "Не надо сразу встречаться", "ไม่ต้องรีบคบ", "май→ тонг→ рип→ кхоп→", "Темп отношений."),
]


def in_scope_course(cid: str) -> bool:
    return not str(cid or "").startswith("course_b_")


def audit_slice(payload: dict) -> dict:
    courses = []
    for c in payload.get("courses") or []:
        if not in_scope_course(c.get("id") or ""):
            continue
        yellow_cards = []
        for les in c.get("lessons") or []:
            for card in les.get("cards") or []:
                if card.get("color") == "yellow" and (card.get("kind") or "") in LEARNABLE:
                    yellow_cards.append({
                        "lesson": les.get("id"),
                        "ru": card.get("ru"),
                        "thai": card.get("thai"),
                        "notes": card.get("notes") or [],
                    })
        courses.append({
            "id": c["id"],
            "title": c.get("title") or c["id"],
            "color": c.get("color"),
            "yellow_cards": yellow_cards,
        })
    return {
        "totals": payload.get("totals") or {},
        "yellow_cards": sum(len(c["yellow_cards"]) for c in courses),
        "courses": courses,
    }


def snapshot_changed(stepsets, lids: set[str]):
    out = {}
    for ss in stepsets:
        lid = ss.get("lesson_id") or ""
        if lid not in lids:
            continue
        rows = []
        for it in ss.get("items") or []:
            k = (it.get("kind") or "").strip()
            if k in LEARNABLE:
                rows.append({
                    "kind": k,
                    "ru": (it.get("ru") or "").strip(),
                    "thai": (it.get("thai") or "").strip(),
                    "ph": (it.get("phonetic") or "").strip(),
                })
        out[lid] = rows
    return out


def lid_key(x: str):
    parts = x.split("_")
    try:
        tag = parts[1]
        order = {"l": 1, "e": 2, "s": 3, "long": 4}.get(tag, 9)
        if tag == "long":
            return (order, int(parts[2]), int(parts[3][1:]))
        return (order, int(parts[2]), int(parts[3][1:]))
    except (IndexError, ValueError):
        return (9, 0, x)


def main() -> int:
    before_audit = audit_slice(json.loads(AUDIT.read_text(encoding="utf-8"))) if AUDIT.exists() else {}
    steps = json.loads(STEPS.read_text(encoding="utf-8"))
    lessons = json.loads(LESSONS.read_text(encoding="utf-8"))
    ss_by_lesson = {s["lesson_id"]: s for s in steps["stepsets"]}
    changed: set[str] = set()
    replaced_log: dict[str, list[dict]] = defaultdict(list)
    before = snapshot_changed(steps["stepsets"], {r[0] for r in REPLACE})

    for lid, old_th, kind, ru, thai, ph, tip in REPLACE:
        ss = ss_by_lesson.get(lid)
        if not ss:
            print("missing lesson", lid, file=sys.stderr)
            return 1
        hit = None
        for it in ss.get("items") or []:
            if (it.get("kind") or "") not in LEARNABLE:
                continue
            if (it.get("thai") or "").strip() != old_th:
                continue
            hit = it
            break
        if hit is None:
            print("replace miss", lid, old_th, file=sys.stderr)
            return 1
        replaced_log[lid].append({
            "ru_before": (hit.get("ru") or "").strip(),
            "thai_before": (hit.get("thai") or "").strip(),
            "ph_before": (hit.get("phonetic") or "").strip(),
            "ru_after": ru,
            "thai_after": thai,
            "ph_after": ph,
        })
        hit["kind"] = kind
        hit["ru"] = ru
        hit["thai"] = thai
        hit["phonetic"] = ph
        hit["tip"] = tip
        changed.add(lid)

    after = snapshot_changed(steps["stepsets"], changed)

    titles, courses_of = {}, {}
    for course in lessons.get("courses") or []:
        for les in course.get("lessons") or []:
            titles[les["lesson_id"]] = les.get("title") or les["lesson_id"]
            courses_of[les["lesson_id"]] = course.get("course_title") or course.get("course_id")

    diff_lessons = []
    for lid in sorted(changed, key=lid_key):
        diff_lessons.append({
            "id": lid,
            "title": titles.get(lid, lid),
            "course": courses_of.get(lid, ""),
            "n_before": len(before.get(lid) or []),
            "n_after": len(after.get(lid) or []),
            "added": [],
            "replaced": replaced_log.get(lid) or [],
            "changed": [],
        })

    STEPS.write_text(json.dumps(steps, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("changed lessons", len(diff_lessons), "replaced cards", sum(len(v) for v in replaced_log.values()))
    for row in diff_lessons:
        print(f"  {row['id']} repl={len(row['replaced'])}")
    subprocess.check_call([sys.executable, str(ROOT / "scripts/check_steps_json.py")], cwd=ROOT)
    subprocess.check_call([sys.executable, str(ROOT / "scripts/launch_curriculum_traffic_light.py")], cwd=ROOT)
    after_audit = audit_slice(json.loads(AUDIT.read_text(encoding="utf-8")))
    keep_ids = set()
    for course in lessons.get("courses") or []:
        for les in course.get("lessons") or []:
            if les.get("lesson_id") in changed:
                keep_ids.add(course.get("course_id"))
    def slim(a):
        return {
            "totals": a.get("totals") or {},
            "yellow_cards": a.get("yellow_cards"),
            "courses": [c for c in (a.get("courses") or []) if c.get("id") in keep_ids],
        }
    DIFF.write_text(
        json.dumps(
            {
                "title": "Дифф голых базовых карточек в платных курсах — было → стало",
                "html_id": "generic-diff",
                "foot": "Ок / понятно / картой / счёт / границы — под сцену урока, не общий шаблон.",
                "note": "Только жёлтые дубли внутри платных уроков. Базу не трогали.",
                "before": slim(before_audit),
                "after": slim(after_audit),
                "lessons": diff_lessons,
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    subprocess.check_call([sys.executable, str(ROOT / "scripts/launch_curriculum_traffic_light.py")], cwd=ROOT)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
