#!/usr/bin/env python3
"""Fill thin Base lessons (b_1–b_7) to 8–12 learnable cards. Does not change ids."""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STEPS = ROOT / "steps.json"
LESSONS = ROOT / "lessons.json"
DIFF = ROOT / "docs/base_curriculum_fix_diff.json"
AUDIT = ROOT / "docs/launch_curriculum_traffic_light.json"
LEARNABLE = {"word", "phrase", "casual"}

ADD: dict[str, list[dict]] = {
    "course_b_1_l1": [
        {"kind": "phrase", "ru": "Доброе утро", "thai": "สวัสดีตอนเช้า", "phonetic": "са→ ват→ ди→ тон→ чау↗", "tip": "Утро до полудня. Тон чау — «утро»."},
        {"kind": "phrase", "ru": "Добрый день", "thai": "สวัสดีตอนบ่าย", "phonetic": "са→ ват→ ди→ тон→ бай↘", "tip": "День после полудня. Бай — «после обеда»."},
        {"kind": "phrase", "ru": "Добро пожаловать", "thai": "ยินดีต้อนรับ", "phonetic": "йин→ ди→ тон↗ рап↘", "tip": "Когда встречаешь гостя или заходишь в место."},
        {"kind": "phrase", "ru": "Давно не виделись", "thai": "นานไม่ได้เจอ", "phonetic": "наан→ май→ дай↗ джё→", "tip": "Для знакомого, не для первого вай."},
        {"kind": "word", "ru": "Вай", "thai": "ไหว้", "phonetic": "вай↘", "tip": "Жест руками. Часто работает даже без слов."},
    ],
    "course_b_1_l2": [
        {"kind": "phrase", "ru": "Я турист", "thai": "ฉันเป็นนักท่องเที่ยว", "phonetic": "чхан→ пэн→ нак→ тхонг→ тхиау↗", "tip": "Коротко объяснить, кто ты."},
        {"kind": "phrase", "ru": "Я первый раз в Таиланде", "thai": "ฉันมาไทยครั้งแรก", "phonetic": "чхан→ маа→ тай→ кхраанг↘ рэк↘", "tip": "Снимает ожидание идеального тайского."},
    ],
    "course_b_1_l5": [
        {"kind": "phrase", "ru": "Где банкомат?", "thai": "ตู้เอทีเอ็มอยู่ไหน", "phonetic": "туу↗ э→ ти→ эм→ ю→ най↗", "tip": "Покажи на телефон — жест помогает."},
        {"kind": "phrase", "ru": "Где аптека?", "thai": "ร้านขายยาอยู่ไหน", "phonetic": "раан→ кхаай↘ яа→ ю→ най↗", "tip": "Аптека, не больница."},
    ],
    "course_b_2_l4": [
        {"kind": "phrase", "ru": "Ещё раз коротко", "thai": "อีกที", "phonetic": "ик→ ти→", "tip": "Короткая просьба повторить — мелодия та же."},
        {"kind": "phrase", "ru": "Понял", "thai": "รู้แล้ว", "phonetic": "руу↘ лэу↗", "tip": "Короткий ответ, когда уже схватил смысл."},
    ],
    "course_b_2_l5": [
        {"kind": "phrase", "ru": "Подожди немного", "thai": "รอหน่อย", "phonetic": "ро→ ной→", "tip": "Ной смягчает. Хвост вежливости ставит Спикер."},
        {"kind": "phrase", "ru": "Ещё чуть-чуть", "thai": "อีกนิด", "phonetic": "ик→ нит→", "tip": "Нит = капелька."},
    ],
    "course_b_3_l1": [
        {"kind": "phrase", "ru": "Это я", "thai": "นี่ฉัน", "phonetic": "ни→ чхан→", "tip": "Показать на себя."},
        {"kind": "phrase", "ru": "Кто это?", "thai": "นี่ใคร", "phonetic": "ни→ кхрай→", "tip": "Кхрай — вопрос о человеке."},
        {"kind": "phrase", "ru": "Я тоже", "thai": "ฉันด้วย", "phonetic": "чхан→ дуай→", "tip": "Дуай = «тоже / вместе»."},
    ],
    "course_b_6_l2": [
        {"kind": "phrase", "ru": "Красивый вид", "thai": "วิวสวย", "phonetic": "виу→ суай→", "tip": "Про место, не про человека."},
        {"kind": "phrase", "ru": "Выглядит дорого", "thai": "ดูแพง", "phonetic": "дуу→ пхэнг→", "tip": "Оценка на вид, ещё не торг."},
    ],
    "course_b_7_l1": [
        {"kind": "word", "ru": "Голодный", "thai": "หิว", "phonetic": "хиу↗", "tip": "Хиу — «голоден». Отдельно от «уже ел?»."},
        {"kind": "phrase", "ru": "Ещё голодный", "thai": "ยังหิว", "phonetic": "янг→ хиу↗", "tip": "Янг хиу = ещё не сыт."},
        {"kind": "phrase", "ru": "Что поесть?", "thai": "กินอะไรดี", "phonetic": "кин→ а→ рай↗ ди→", "tip": "Предложить еду, не спрашивать «как дела»."},
    ],
    "course_b_7_l2": [
        {"kind": "phrase", "ru": "За покупками", "thai": "ไปซื้อของ", "phonetic": "пай→ сы→ кхонг→", "tip": "Ответ жизнью: в магазин / за вещами, не GPS-точка."},
        {"kind": "phrase", "ru": "К другу", "thai": "ไปหาเพื่อน", "phonetic": "пай→ хаа↗ пхыан↗", "tip": "Хаа = навестить."},
        {"kind": "phrase", "ru": "Недалеко", "thai": "ใกล้ๆ", "phonetic": "глай↘ глай↘", "tip": "Когда не хочешь объяснять маршрут."},
    ],
    "course_b_7_l3": [
        {"kind": "phrase", "ru": "Возьми зонт", "thai": "เอาร่ม", "phonetic": "ау→ ром↘", "tip": "Ром — зонт."},
        {"kind": "phrase", "ru": "Сильный дождь", "thai": "ฝนตกหนัก", "phonetic": "фон→ ток↘ нак↘", "tip": "Нак = сильный."},
        {"kind": "phrase", "ru": "Облачно", "thai": "ฟ้าครึ้ม", "phonetic": "фаа↗ кхрым→", "tip": "Небо тяжёлое, ещё не ливень."},
    ],
    "course_b_7_l4": [
        {"kind": "phrase", "ru": "Люди добрые", "thai": "คนไทยใจดี", "phonetic": "кон→ тай→ джай→ ди→", "tip": "Комплимент людям, не только стране."},
        {"kind": "phrase", "ru": "Море красивое", "thai": "ทะเลสวย", "phonetic": "тха→ ле→ суай→", "tip": "Если ты на острове — живой ответ."},
        {"kind": "phrase", "ru": "Еда острая", "thai": "อาหารเผ็ด", "phonetic": "а→ хаан→ пхет→", "tip": "Факт про еду, не повтор «люблю Таиланд»."},
    ],
    "course_b_7_l5": [
        {"kind": "phrase", "ru": "Занят работой", "thai": "ยุ่งงาน", "phonetic": "ынг↘ нгаан→", "tip": "Мягкий отказ без «нет»."},
        {"kind": "phrase", "ru": "Свободен вечером", "thai": "ว่างเย็น", "phonetic": "ваан↘ йен→", "tip": "Днём занят, вечером можно."},
        {"kind": "phrase", "ru": "Пойдём за кофе?", "thai": "ไปกินกาแฟไหม", "phonetic": "пай→ кин→ ка→ фэ→ май↗", "tip": "Конкретное «вместе»."},
    ],
    "course_b_7_l6": [
        {"kind": "phrase", "ru": "Мне пора", "thai": "ฉันต้องไป", "phonetic": "чхан→ тонг→ пай→", "tip": "Прямое «пора»."},
        {"kind": "phrase", "ru": "Хорошего дня", "thai": "ขอให้วันนี้ดี", "phonetic": "кхо→ хай↗ ван→ ни→ ди→", "tip": "Закрыть разговор теплом."},
        {"kind": "phrase", "ru": "Напиши потом", "thai": "ทักมาทีหลัง", "phonetic": "тхак→ маа→ ти→ ланг↘", "tip": "Тхак маа = напиши / стукнись."},
    ],
}

PHONETIC_FIXES = [
    ("course_b_1_l2", "ฉันชื่อ …", "чхан→ чыу→", "было «как меня зовут», стало «меня зовут»"),
    ("course_b_3_l2", "เขาชื่อ …", "кхау→ чыу→", "шаблон «его зовут», без хвоста «как зовут»"),
    ("course_b_1_l4", "พูดช้าๆหน่อย", "пхуут→ ча↗ ча↗ ной→", "ча-ча = медленно, не глай"),
    ("course_b_1_l6", "สแกน QR ได้ไหม", "са→ кэн↗ кю→ ар→ дай→ май↗", "убрали обрубок кр→"),
    ("course_b_6_l5", "ปกติหมด", "пок→ га→ ти→ мот↘", "опечатка пока→ ти→"),
]


def learnable(items):
    return [it for it in items if (it.get("kind") or "") in LEARNABLE]


def audit_base_slice(payload: dict) -> dict:
    courses = []
    for c in payload.get("courses") or []:
        if not str(c.get("id") or "").startswith("course_b_"):
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


def snapshot(stepsets):
    out = {}
    for ss in stepsets:
        lid = ss.get("lesson_id") or ""
        if not str(lid).startswith("course_b_"):
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


def main() -> int:
    before_audit = audit_base_slice(json.loads(AUDIT.read_text(encoding="utf-8"))) if AUDIT.exists() else {}
    steps = json.loads(STEPS.read_text(encoding="utf-8"))
    lessons = json.loads(LESSONS.read_text(encoding="utf-8"))
    before = snapshot(steps["stepsets"])
    ss_by_lesson = {s["lesson_id"]: s for s in steps["stepsets"]}
    changed = set()

    for lid, thai, ph, _note in PHONETIC_FIXES:
        ss = ss_by_lesson.get(lid)
        if not ss:
            print("missing", lid, file=sys.stderr)
            return 1
        hit = False
        for it in ss.get("items") or []:
            if (it.get("thai") or "").strip() == thai:
                it["phonetic"] = ph
                hit = True
                changed.add(lid)
        if not hit:
            print("phonetic fix miss", lid, thai, file=sys.stderr)
            return 1

    for lid, extras in ADD.items():
        ss = ss_by_lesson.get(lid)
        if not ss:
            print("missing lesson", lid, file=sys.stderr)
            return 1
        have_th = {(it.get("thai") or "").strip() for it in learnable(ss["items"])}
        have_ru = {(it.get("ru") or "").strip().lower() for it in learnable(ss["items"])}
        for card in extras:
            if card["thai"] in have_th or card["ru"].strip().lower() in have_ru:
                print("skip dup", lid, card["ru"])
                continue
            ss["items"].append(dict(card))
            have_th.add(card["thai"])
            have_ru.add(card["ru"].strip().lower())
            changed.add(lid)
        ss["items"] = renumber(ss["items"])

    after = snapshot(steps["stepsets"])

    for course in lessons.get("courses") or []:
        if not str(course.get("course_id") or "").startswith("course_b_"):
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
    for lid in sorted(changed):
        if lid.startswith("course_b_0"):
            continue
        b_learn = [x for x in (before.get(lid) or []) if x["kind"] in LEARNABLE]
        a_learn = [x for x in (after.get(lid) or []) if x["kind"] in LEARNABLE]
        b_keys = {(x["kind"], x["ru"], x["thai"]) for x in b_learn}
        a_keys = {(x["kind"], x["ru"], x["thai"]) for x in a_learn}
        added = [x for x in a_learn if (x["kind"], x["ru"], x["thai"]) not in b_keys]
        removed = [x for x in b_learn if (x["kind"], x["ru"], x["thai"]) not in a_keys]
        changed_ph = []
        by_th_b = {x["thai"]: x for x in b_learn if x["thai"]}
        by_th_a = {x["thai"]: x for x in a_learn if x["thai"]}
        for th, old in by_th_b.items():
            new = by_th_a.get(th)
            if new and new["ph"] != old["ph"]:
                changed_ph.append({"ru": new["ru"], "thai": th, "ph_before": old["ph"], "ph_after": new["ph"]})
        diff_lessons.append({
            "id": lid,
            "title": titles.get(lid, lid),
            "course": courses_of.get(lid, ""),
            "n_before": len(b_learn),
            "n_after": len(a_learn),
            "added": added,
            "removed": removed,
            "changed": changed_ph,
        })

    STEPS.write_text(json.dumps(steps, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    LESSONS.write_text(json.dumps(lessons, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("changed lessons", len(diff_lessons))
    for row in diff_lessons:
        print(f"  {row['id']} {row['n_before']}→{row['n_after']} +{len(row['added'])} phonfix={len(row['changed'])}")
    subprocess.check_call([sys.executable, str(ROOT / "scripts/check_steps_json.py")], cwd=ROOT)
    subprocess.check_call([sys.executable, str(ROOT / "scripts/launch_curriculum_traffic_light.py")], cwd=ROOT)
    after_audit = audit_base_slice(json.loads(AUDIT.read_text(encoding="utf-8")))
    DIFF.write_text(
        json.dumps(
            {
                "note": "Правки только Базы (course_b_1…b_7). course_b_0 не трогали. Платные красные l_1 / e_3 не в этом проходе.",
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
