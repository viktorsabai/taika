#!/usr/bin/env python3
"""
Анализ образовательного контента Базы: карточки из steps.json (course_b_*).
- Дубли: одна и та же фраза (ru или thai) в нескольких уроках/курсах.
- Карточки со слэшем: ru или thai содержат "/" (варианты: кхрап/ка, чхан/пхом).
Запуск: python3 scripts/analyze_baza_steps_content.py
"""
import json
import os
import re
from collections import defaultdict

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STEPS_PATH = os.path.join(BASE, "steps.json")
BAZA_PREFIX = "course_b_"


def norm_ru(s):
    """Нормализация для сравнения: нижний регистр, без лишних пробелов."""
    return (s or "").strip().lower()


def norm_thai_key(s):
    """Ключ для тайского: убрать тоновые стрелки и пробелы для сравнения."""
    if not s:
        return ""
    t = re.sub(r"[↗↘→↖↙]", "", s)
    t = t.replace(" ", "").strip().lower()
    return t


def main():
    with open(STEPS_PATH, "r", encoding="utf-8") as f:
        data = json.load(f)

    stepsets = [s for s in data.get("stepsets", []) if (s.get("course_id") or "").startswith(BAZA_PREFIX)]
    by_ru = defaultdict(list)  # norm_ru(ru) -> [(course_id, lesson_id, ru, thai, phonetic)]
    by_thai = defaultdict(list)  # norm_thai_key(phonetic или thai) -> [...]
    slash_cards = []  # (course_id, lesson_id, ru, thai, phonetic)

    for s in stepsets:
        cid = s.get("course_id", "")
        lid = s.get("lesson_id", "")
        for it in s.get("items", []):
            kind = it.get("kind", "")
            if kind not in ("word", "phrase", "casual"):
                continue
            ru = (it.get("ru") or "").strip()
            thai = (it.get("thai") or "").strip()
            phonetic = (it.get("phonetic") or "").strip()
            if not ru and not thai:
                continue
            key_ru = norm_ru(ru)
            key_thai = norm_thai_key(phonetic or thai)
            entry = (cid, lid, ru, thai, phonetic)
            if key_ru:
                by_ru[key_ru].append(entry)
            if key_thai:
                by_thai[key_thai].append(entry)
            if "/" in ru or "/" in thai or "/" in phonetic:
                slash_cards.append(entry)

    # Дубли по русскому
    dupes_ru = {k: v for k, v in by_ru.items() if len(v) > 1}
    # Уникальность по курсам/урокам (одна фраза в нескольких уроках)
    dupes_ru_cross = {k: v for k, v in dupes_ru.items() if len(set((x[0], x[1]) for x in v)) > 1}

    # Дубли по тайскому/фонетике
    dupes_thai = {k: v for k, v in by_thai.items() if len(v) > 1}
    dupes_thai_cross = {k: v for k, v in dupes_thai.items() if len(set((x[0], x[1]) for x in v)) > 1}

    lines = []
    lines.append("# Анализ образовательного контента «База от Тайки» (steps)\n")
    lines.append(f"Stepsets: {len(stepsets)}, карточек (word/phrase/casual): {sum(len([i for i in s.get('items', []) if i.get('kind') in ('word','phrase','casual')]) for s in stepsets)}\n")

    lines.append("## 1. Карточки со слэшем в ru / thai / phonetic\n")
    lines.append("Слэш = варианты (часто муж/жен: кхрап/ка, чхан/пхом). Имеет смысл сделать подпись однозначной или добавить tip.\n")
    for cid, lid, ru, thai, ph in slash_cards:
        lines.append(f"- **{ru}**")
        lines.append(f"  - thai: `{thai}` | phonetic: `{ph}`")
        lines.append(f"  - {cid} / {lid}")
    lines.append("")

    lines.append("## 2. Дубли фраз по русскому (одна и та же фраза в разных уроках)\n")
    for key in sorted(dupes_ru_cross.keys(), key=lambda k: -len(dupes_ru_cross[k]))[:40]:
        occ = dupes_ru_cross[key]
        lessons = set((x[0], x[1]) for x in occ)
        lines.append(f"- **«{key[:50]}»** — в {len(lessons)} уроках ({len(occ)} карточек)")
        for cid, lid, ru, thai, ph in occ[:6]:
            lines.append(f"  - {cid} {lid}")
        if len(occ) > 6:
            lines.append(f"  - ... и ещё {len(occ) - 6}")
        lines.append("")
    lines.append("")

    lines.append("## 3. Дубли по тайскому/фонетике (одно и то же слово в разных уроках)\n")
    for key in sorted(dupes_thai_cross.keys(), key=lambda k: -len(dupes_thai_cross[k]))[:30]:
        occ = dupes_thai_cross[key]
        lessons = set((x[0], x[1]) for x in occ)
        sample = occ[0]
        lines.append(f"- `{sample[4] or sample[3]}` (ru: «{sample[2][:40]}») — в {len(lessons)} уроках")
        for cid, lid, ru, thai, ph in occ[:5]:
            lines.append(f"  - {cid} {lid}")
        lines.append("")
    lines.append("")

    lines.append("## 4. Выводы\n")
    lines.append(f"- Карточек со слэшем: **{len(slash_cards)}** — уточнить подписи или tip (кто кхрап/ка, чхан/пхом).")
    lines.append(f"- Уникальных фраз (ru) с повторами в разных уроках: **{len(dupes_ru_cross)}** — часть дублей осмысленна (повтор в диалогах b_7), часть можно убрать или заменить на вариации.")
    lines.append("- Рекомендация: в b_7 не дублировать те же карточки что в b_1 (привет, счёт, вода), а давать короткие связки и контекст; слэш-карточки подписать явно: «Здравствуйте (кхрап/ка)», «Я (чхан/пхом)».")
    lines.append("")

    report = "\n".join(lines)
    out_path = os.path.join(BASE, "docs", "baza_steps_content_report.md")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(report)
    print(report)
    print(f"\nОтчёт: {out_path}")


if __name__ == "__main__":
    main()
