#!/usr/bin/env python3
"""Heal «На одной волне» plus leftover Base intonation capstone recap."""
from __future__ import annotations

import json
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STEPS = ROOT / "steps.json"
LESSONS = ROOT / "lessons.json"
DIFF = ROOT / "docs/wave_curriculum_fix_diff.json"
AUDIT = ROOT / "docs/launch_curriculum_traffic_light.json"
LEARNABLE = {"word", "phrase", "casual"}


def in_scope_lesson(lid: str) -> bool:
    s = str(lid or "")
    return s.startswith("course_e_") or s == "course_b_2_l6"


def in_scope_course(cid: str) -> bool:
    s = str(cid or "")
    return s.startswith("course_e_") or s == "course_b_2"


REPLACE: list[tuple[str, str, str, str, str, str, str]] = [
    ("course_e_1_l5", "ขอบคุณ", "phrase", "Очень выручили", "ช่วยได้มากเลย", "чуай↗ дай→ мак↘ лёй→", "Благодарность за ясность, не кассовое спасибо."),
    ("course_e_1_l5", "ค่ะ", "phrase", "Не затруднит?", "รบกวนนิดนึง", "роп→ куан→ нит→ нынг→", "Мягкий вход без маркера каа на карточке."),
    ("course_e_1_l5", "ครับ", "phrase", "Скажи мягче", "พูดสุภาพหน่อย", "пхуут→ су→ пхаап↘ ной→", "Вежливый хвост — формулировка, не частица."),
    ("course_e_1_l5", "ห้าคำสำคัญ", "phrase", "Смягчи хвост", "ลงท้ายให้นุ่ม", "лонг→ тхаай↗ хай→ нум→", "Как звучать мягче, не список из пяти слов."),
    ("course_e_1_l5", "สวัสดีทุกคน", "phrase", "Извини что вклинился", "ขอโทษที่ขัด", "кхо→ тхот→ ти→ кхат↘", "В разговор, не общее приветствие."),
    ("course_e_2_l2", "ยังไม่เสร็จ", "phrase", "Ещё в работе", "กำลังทำอยู่", "кам→ ланг→ там→ ю→", "Статус задачи, не повтор «ещё не готово»."),
    ("course_e_2_l6", "ขอบคุณที่ช่วย", "phrase", "Продолжим завтра", "ไว้คุยต่อพรุ่งนี้", "вай→ кхуй→ то→ пхрунг→ ни→", "Закрыть рабочий день, не повтор благодарности."),
    ("course_e_2_l6", "ยังไม่เสร็จเหรอ", "phrase", "С задачей всё ок?", "งานนี้โอเคไหม", "нгаан→ ни→ о→ кэ→ май↗", "Итог разговора, не статус из начала курса."),
    ("course_e_2_l6", "และ", "phrase", "Файл уже отправил", "ส่งไฟล์มาแล้ว", "сонг→ фай→ маа→ лэу→", "Рабочий факт, не союз."),
    ("course_e_2_l6", "แต่", "phrase", "Застрял вот здесь", "ติดตรงนี้นิดหน่อย", "тит→ тронг→ ни→ нит→ ной→", "Где стоп, не союз «но»."),
    ("course_e_2_l6", "เพราะ", "phrase", "Жду подтверждения", "รอคอนเฟิร์มก่อน", "ро→ кхон→ фём→ кон→", "Почему ждём, не союз «потому что»."),
    ("course_e_3_l1", "ขอบคุณ", "phrase", "Кто принимает заявку?", "ใครรับเรื่องนี้", "кхрай→ рап→ рыанг→ ни→", "Сервисный вход, не спасибо из Базы."),
    ("course_e_3_l4", "เท่าไหร่", "phrase", "Сколько за услугу?", "ค่าบริการเท่าไหร่", "кхаа→ бо→ ри→ кан→ тао→ рай↗", "Цена сервиса, не рыночное «тао рай»."),
    ("course_e_3_l6", "ขอบคุณ ลาก่อน", "phrase", "Всё забрал", "รับของเรียบร้อย", "рап→ кхонг→ риап→ рой↘", "Закрыть услугу фактом, не прощание из Базы."),
    ("course_e_5_l6", "ใจเย็นนะ", "phrase", "Что он имеет в виду?", "เขาหมายถึงอะไร", "кхау→ маай→ тхынг→ а→ рай↗", "Уточнить код, не повтор «давай спокойно»."),
    ("course_b_2_l6", "สวัสดี", "phrase", "Этот, пожалуйста", "เอาอันนี้", "ау→ ан→ ни→", "Семь-элевен: указать на полке, не повтор приветствия."),
    ("course_b_2_l6", "สบายดีไหม", "phrase", "Жарко тут?", "ร้อนไหม", "рон↘ май↗", "Короткая мелодия вопроса, не повтор «как дела»."),
    ("course_b_2_l6", "เท่าไหร่", "phrase", "Сколько всего?", "รวมกี่บาท", "руам→ ги→ бат→", "Касса, не голое «тао рай»."),
    ("course_b_2_l6", "อร่อยมาก", "phrase", "Слишком сладко", "หวานไป", "ваан→ пай→", "Оценка товара, не повтор «очень вкусно»."),
    ("course_b_2_l6", "ขอบคุณมาก", "phrase", "Всё, беру", "ได้แล้ว", "дай→ лэу→", "Закрыть покупку, не повтор «спасибо большое»."),
    ("course_b_2_l6", "สบายดี", "phrase", "Только это", "เอาแค่นี้", "ау→ кхэ→ ни→", "Лимит корзины, не повтор «хорошо»."),
]

ADD: dict[str, list[dict]] = {
    "course_e_1_l3": [
        {"kind": "phrase", "ru": "Спросить чуть-чуть", "thai": "ขอถามนิดนึง", "phonetic": "кхо→ тхам→ нит→ нынг→", "tip": "Мягкий вход в вопрос."},
        {"kind": "phrase", "ru": "Не тороплю", "thai": "ไม่รีบนะ", "phonetic": "май→ рип→ на↗", "tip": "Снять давление с собеседника."},
    ],
    "course_e_2_l3": [
        {"kind": "phrase", "ru": "В какой день отдадите?", "thai": "ส่งให้วันไหน", "phonetic": "сонг→ хай→ ван→ най↗", "tip": "Срок без укора."},
        {"kind": "phrase", "ru": "Можно сдвинуть срок?", "thai": "เลื่อนได้ไหม", "phonetic": "лыан→ дай→ май↗", "tip": "Напоминание как просьба, не приказ."},
    ],
    "course_e_3_l1": [
        {"kind": "phrase", "ru": "Кондей не холодит", "thai": "แอร์ไม่เย็น", "phonetic": "э→ май→ ен→", "tip": "Конкретная поломка, не голое «проблема»."},
        {"kind": "phrase", "ru": "Здесь грязно", "thai": "สกปรกตรงนี้", "phonetic": "сок→ ка→ прок→ тронг→ ни→", "tip": "Покажи место, не обвиняй человека."},
        {"kind": "phrase", "ru": "Странный запах", "thai": "กลิ่นไม่ดี", "phonetic": "клин→ май→ ди→", "tip": "Коротко назвать, что не так."},
    ],
    "course_e_3_l2": [
        {"kind": "phrase", "ru": "Позовите мастера", "thai": "เรียกช่างให้หน่อย", "phonetic": "риак↗ чаанг→ хай→ ной→", "tip": "Кто чинит, не общее «помогите»."},
        {"kind": "phrase", "ru": "Долго ждать очередь?", "thai": "รอคิวนานไหม", "phonetic": "ро→ кхиу→ наан→ май↗", "tip": "Очередь в сервисе."},
        {"kind": "phrase", "ru": "Можно сделать здесь?", "thai": "ทำที่นี่ได้ไหม", "phonetic": "там→ ти→ ни→ дай→ май↗", "tip": "На месте или уносить."},
    ],
    "course_e_3_l3": [
        {"kind": "phrase", "ru": "Во сколько будет готово?", "thai": "กี่โมงเสร็จ", "phonetic": "ги→ монг→ сет↘", "tip": "Час, не день."},
        {"kind": "phrase", "ru": "Напишите когда готово", "thai": "แจ้งเมื่อเสร็จ", "phonetic": "джэнг→ мыа→ сет↘", "tip": "Не стоять и ждать у стойки."},
        {"kind": "phrase", "ru": "Долго займёт?", "thai": "ใช้เวลานานไหม", "phonetic": "чай↗ ве→ лаа→ наан→ май↗", "tip": "Ожидание до факта «готово»."},
    ],
    "course_e_3_l4": [
        {"kind": "phrase", "ru": "Запчасти входят?", "thai": "รวมอะไหล่ไหม", "phonetic": "руам→ а→ лай→ май↗", "tip": "Цена услуги vs детали."},
        {"kind": "phrase", "ru": "Когда платить?", "thai": "จ่ายตอนไหน", "phonetic": "джай→ тон→ най↗", "tip": "До или после работы."},
        {"kind": "phrase", "ru": "Есть гарантия?", "thai": "มีประกันไหม", "phonetic": "ми→ пра→ кан→ май↗", "tip": "После ремонта."},
    ],
    "course_e_3_l5": [
        {"kind": "phrase", "ru": "Это вот это?", "thai": "หมายถึงอันนี้ไหม", "phonetic": "маай→ тхынг→ ан→ ни→ май↗", "tip": "Указать пальцем, не кивать."},
        {"kind": "phrase", "ru": "Покажите пальцем", "thai": "ชี้ให้ดูหน่อย", "phonetic": "чи→ хай→ ду→ ной→", "tip": "Когда слова не хватает."},
        {"kind": "phrase", "ru": "Это слово ещё раз", "thai": "พูดคำนี้ใหม่", "phonetic": "пхуут→ кхам→ ни→ май→", "tip": "Одно слово, не весь монолог."},
    ],
    "course_e_3_l6": [
        {"kind": "phrase", "ru": "Чек, пожалуйста", "thai": "ใบเสร็จด้วย", "phonetic": "бай→ сет↘ дуай→", "tip": "Бумага на руках."},
        {"kind": "phrase", "ru": "Сдача будет?", "thai": "เหลือทอนไหม", "phonetic": "лыа→ тхон→ май↗", "tip": "Наличные на кассе сервиса."},
        {"kind": "phrase", "ru": "До следующего раза", "thai": "ไว้คราวหน้า", "phonetic": "вай→ кхрау→ наа↗", "tip": "Выход без формулы «ла кон»."},
    ],
    "course_e_4_l6": [
        {"kind": "phrase", "ru": "Можно начать заново?", "thai": "เริ่มใหม่ได้ไหม", "phonetic": "рём→ май→ дай→ май↗", "tip": "Сброс ссоры, не повтор извинения."},
        {"kind": "phrase", "ru": "Не держу зла", "thai": "ไม่ถือสา", "phonetic": "май→ тхы→ саа→", "tip": "Закрыть тему лицом."},
    ],
    "course_e_5_l2": [
        {"kind": "phrase", "ru": "Говори спокойно", "thai": "ค่อยๆ พูด", "phonetic": "кхой→ глай→ пхуут→", "tip": "Темп, не повтор «джай йен»."},
        {"kind": "phrase", "ru": "Не злись сразу", "thai": "อย่าเพิ่งโกรธ", "phonetic": "йаа→ пхенг→ кроот→", "tip": "До того как вспыхнет."},
    ],
}


def audit_slice(payload: dict) -> dict:
    courses = []
    for c in payload.get("courses") or []:
        if not in_scope_course(c.get("id") or ""):
            continue
        courses.append({
            "id": c["id"],
            "title": c.get("title") or c["id"],
            "color": c.get("color"),
            "learnable": c.get("learnable"),
            "thin": c.get("thin"),
            "dups": c.get("dups"),
            "flags": c.get("flags") or [],
            "lessons": [
                {
                    "id": les["id"],
                    "title": les.get("title") or les["id"],
                    "n": les.get("n"),
                    "color": les.get("color"),
                    "flags": [
                        {"sev": f.get("sev"), "code": f.get("code"), "msg": f.get("msg")}
                        for f in (les.get("flags") or [])
                        if f.get("code") not in {"no_tip", "dup_across_courses", "thin_lesson_copy"}
                    ],
                }
                for les in (c.get("lessons") or [])
            ],
        })
    return {"totals": payload.get("totals") or {}, "courses": courses}


def learnable(items):
    return [it for it in items if (it.get("kind") or "") in LEARNABLE]


def snapshot(stepsets):
    out = {}
    for ss in stepsets:
        lid = ss.get("lesson_id") or ""
        if not in_scope_lesson(lid):
            continue
        rows = []
        for it in ss.get("items") or []:
            k = (it.get("kind") or "").strip()
            if k == "tip":
                rows.append({"kind": "tip", "ru": (it.get("text") or "").strip(), "thai": "", "ph": ""})
            elif k in LEARNABLE:
                rows.append({
                    "kind": k,
                    "ru": (it.get("ru") or "").strip(),
                    "thai": (it.get("thai") or "").strip(),
                    "ph": (it.get("phonetic") or "").strip(),
                })
        out[lid] = rows
    return out


def renumber(items):
    out = []
    for i, it in enumerate(items, start=1):
        n = dict(it)
        n["order"] = i
        out.append(n)
    return out


def lid_key(x: str):
    parts = x.split("_")
    try:
        if parts[1] == "b":
            return (0, int(parts[2]), int(parts[3][1:]))
        return (1, int(parts[2]), int(parts[3][1:]))
    except (IndexError, ValueError):
        return (9, 0, x)


def main() -> int:
    before_audit = audit_slice(json.loads(AUDIT.read_text(encoding="utf-8"))) if AUDIT.exists() else {}
    steps = json.loads(STEPS.read_text(encoding="utf-8"))
    lessons = json.loads(LESSONS.read_text(encoding="utf-8"))
    before = snapshot(steps["stepsets"])
    ss_by_lesson = {s["lesson_id"]: s for s in steps["stepsets"]}
    changed: set[str] = set()
    replaced_log: dict[str, list[dict]] = defaultdict(list)

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

    for lid, extras in ADD.items():
        ss = ss_by_lesson.get(lid)
        if not ss:
            print("missing lesson", lid, file=sys.stderr)
            return 1
        have_th = {(it.get("thai") or "").strip() for it in learnable(ss["items"])}
        have_ru = {(it.get("ru") or "").strip().lower() for it in learnable(ss["items"])}
        for card in extras:
            if card["thai"] in have_th or card["ru"].strip().lower() in have_ru:
                print("skip dup add", lid, card["ru"])
                continue
            ss["items"].append(dict(card))
            have_th.add(card["thai"])
            have_ru.add(card["ru"].strip().lower())
            changed.add(lid)
        ss["items"] = renumber(ss["items"])

    for lid in changed:
        ss_by_lesson[lid]["items"] = renumber(ss_by_lesson[lid]["items"])

    after = snapshot(steps["stepsets"])

    for course in lessons.get("courses") or []:
        if not in_scope_course(course.get("course_id") or ""):
            continue
        for les in course.get("lessons") or []:
            ss = ss_by_lesson.get(les.get("lesson_id"))
            if ss:
                les["card_count"] = len(ss.get("items") or [])

    titles, courses_of = {}, {}
    for course in lessons.get("courses") or []:
        for les in course.get("lessons") or []:
            titles[les["lesson_id"]] = les.get("title") or les["lesson_id"]
            courses_of[les["lesson_id"]] = course.get("course_title") or course.get("course_id")

    diff_lessons = []
    for lid in sorted(changed, key=lid_key):
        b_learn = [x for x in (before.get(lid) or []) if x["kind"] in LEARNABLE]
        a_learn = [x for x in (after.get(lid) or []) if x["kind"] in LEARNABLE]
        b_keys = {(x["kind"], x["ru"], x["thai"]) for x in b_learn}
        added = [x for x in a_learn if (x["kind"], x["ru"], x["thai"]) not in b_keys]
        added = [x for x in added if not any(r["ru_after"] == x["ru"] and r["thai_after"] == x["thai"] for r in replaced_log.get(lid) or [])]
        diff_lessons.append({
            "id": lid,
            "title": titles.get(lid, lid),
            "course": courses_of.get(lid, ""),
            "n_before": len(b_learn),
            "n_after": len(a_learn),
            "added": added,
            "replaced": replaced_log.get(lid) or [],
            "changed": [],
        })

    STEPS.write_text(json.dumps(steps, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    LESSONS.write_text(json.dumps(lessons, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("changed lessons", len(diff_lessons))
    for row in diff_lessons:
        print(f"  {row['id']} {row['n_before']}→{row['n_after']} +{len(row['added'])} repl={len(row['replaced'])}")
    subprocess.check_call([sys.executable, str(ROOT / "scripts/check_steps_json.py")], cwd=ROOT)
    subprocess.check_call([sys.executable, str(ROOT / "scripts/launch_curriculum_traffic_light.py")], cwd=ROOT)
    after_audit = audit_slice(json.loads(AUDIT.read_text(encoding="utf-8")))
    DIFF.write_text(
        json.dumps(
            {
                "title": "Дифф «На одной волне» — было → стало",
                "html_id": "wave-diff",
                "foot": "Плюс капстон Базы course_b_2_l6: внутренние повторы → фразы 7-Eleven.",
                "note": "Блок 4. Частицы ครับ/ค่ะ с карточек сняты. Красный course_e_3 добитый до 8.",
                "before": before_audit,
                "after": after_audit,
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
