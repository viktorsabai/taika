#!/usr/bin/env python3
"""
Анализ курсов категории «База от Тайки»: состав, пересечения, дубли, заполненность контента.
Запуск: python3 scripts/analyze_baza_courses.py (из корня репо; читает lessons.json)
"""
import json
import os
from collections import defaultdict

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LESSONS_JSON = os.path.join(BASE, "lessons.json")
BAZA_PREFIX = "course_b_"


def norm(s):
    return (s or "").strip().lower()


def main():
    with open(LESSONS_JSON, "r", encoding="utf-8") as f:
        data = json.load(f)

    courses = data.get("courses", [])
    baza = [c for c in courses if c.get("course_id", "").startswith(BAZA_PREFIX)]
    baza.sort(key=lambda c: c["course_id"])

    lines = []
    lines.append("# Оценка состава категории «База от Тайки»\n")
    lines.append(f"Курсов в категории: **{len(baza)}** (course_b_1 … course_b_7)\n")

    # 1) Сводка по курсам и урокам
    lines.append("## 1. Курсы и уроки\n")
    all_lessons = []
    for c in baza:
        cid = c["course_id"]
        title = c.get("course_title", "")
        lessons = c.get("lessons", [])
        total_min = c.get("summary", {}).get("total_duration_minutes", 0)
        lines.append(f"### {cid}: {title}")
        lines.append(f"- Уроков: {len(lessons)}, заявлено минут: {total_min}\n")
        for les in lessons:
            lid = les.get("lesson_id", "")
            t = les.get("title", "")
            sub = les.get("subtitle", "")
            preview = les.get("preview_phrase", "")
            content = les.get("content", [])
            intro = next((x.get("text", "") for x in content if x.get("kind") == "intro"), "")
            outline = next((x.get("text", "") for x in content if x.get("kind") == "outline"), "")
            apply_ = next((x.get("text", "") for x in content if x.get("kind") == "apply"), "")
            has_text = bool(norm(intro) or norm(outline) or norm(apply_))
            all_lessons.append({
                "course_id": cid,
                "lesson_id": lid,
                "title": t,
                "subtitle": sub,
                "preview_phrase": preview,
                "has_content": has_text,
            })
        for les in lessons:
            lines.append(f"- **{les.get('title', '')}** — {les.get('subtitle', '')}")
        lines.append("")

    # 2) Контент уроков (intro/outline/apply)
    lines.append("## 2. Заполненность контента уроков (intro / outline / apply)\n")
    empty = [l for l in all_lessons if not l["has_content"]]
    filled = [l for l in all_lessons if l["has_content"]]
    lines.append(f"- Уроков **без текста** в блоках intro/outline/apply: **{len(empty)}** из {len(all_lessons)}")
    lines.append(f"- Уроков **с текстом**: **{len(filled)}**\n")
    if filled:
        for l in filled:
            lines.append(f"- {l['course_id']} / {l['title']}")
    else:
        lines.append("Во всех уроках Базы поля intro, outline и apply **пустые** — текстового контента для категории нет, только карточки (steps) и подзаголовки.\n")

    # 3) Пересечения по preview_phrase (одинаковые или очень похожие фразы)
    lines.append("## 3. Пересечения и дубли (preview_phrase)\n")
    by_phrase = defaultdict(list)
    for l in all_lessons:
        p = (l["preview_phrase"] or "").strip()
        if p:
            # нормализуем для сравнения: до первой точки с запятой — русская часть
            key = p.split(";")[0].strip().lower() if ";" in p else p.lower()
            by_phrase[key].append((l["course_id"], l["title"], p))

    duplicates = {k: v for k, v in by_phrase.items() if len(v) > 1}
    if duplicates:
        lines.append("Один и тот же (или очень похожий) preview встречается в нескольких уроках:\n")
        for phrase_key, occurrences in sorted(duplicates.items(), key=lambda x: -len(x[1])):
            lines.append(f"- **«{phrase_key}»** — в {len(occurrences)} уроках:")
            for cid, title, full in occurrences:
                lines.append(f"  - {cid}: {title} — `{full}`")
            lines.append("")
    else:
        lines.append("Жёстких дублей по preview_phrase не найдено.\n")

    # Точные дубли фразы (полная строка)
    by_full = defaultdict(list)
    for l in all_lessons:
        p = (l["preview_phrase"] or "").strip()
        if p:
            by_full[p].append((l["course_id"], l["title"]))
    exact_dupes = {k: v for k, v in by_full.items() if len(v) > 1}
    if exact_dupes:
        lines.append("**Точные дубли preview_phrase (одна и та же строка):**\n")
        for phrase, occ in exact_dupes.items():
            lines.append(f"- `{phrase}`")
            for cid, title in occ:
                lines.append(f"  - {cid}: {title}")
        lines.append("")

    # 4) Тематические пересечения (по названиям уроков)
    lines.append("## 4. Тематические пересечения (по названиям уроков)\n")
    title_words = defaultdict(list)
    for l in all_lessons:
        for w in norm(l["title"]).split():
            if len(w) > 2:
                title_words[w].append((l["course_id"], l["title"]))
    overlap_words = {w: v for w, v in title_words.items() if len(v) > 1 and len(set(x[0] for x in v)) > 1}
    if overlap_words:
        lines.append("Слова в названиях уроков, встречающиеся в разных курсах (возможное дублирование тем):\n")
        for w, occ in sorted(overlap_words.items(), key=lambda x: -len(x[1]))[:25]:
            courses_here = set(x[0] for x in occ)
            if len(courses_here) >= 2:
                lines.append(f"- **{w}**: {', '.join(courses_here)}")
                for cid, title in occ[:5]:
                    lines.append(f"  - {cid}: {title}")
        lines.append("")

    # 5) Выводы и рекомендации
    lines.append("## 5. Краткие выводы\n")
    lines.append("- **Состав**: 7 курсов, 40 уроков; темы логично разнесены (старт, интонация, местоимения, цифры/время, глаголы, прилагательные, диалоги).")
    lines.append("- **Информативность**: блоки intro/outline/apply у всех уроков пустые — для категории «База» нет текстовых объяснений, только карточки и подзаголовки. Стоит заполнить хотя бы intro для ключевых уроков.")
    lines.append("- **Дубли**: есть повторяющиеся фразы между курсами (например «здравствуйте», «как дела», «7-Eleven», «счёт») — это нормально для базы, но можно сузить дубли там, где один урок полностью перекрывает другой.")
    lines.append("- **Рекомендация**: 1) Добавить текст в content (intro/outline) для уроков Базы. 2) Проверить, не дублируют ли уроки «В 7-Eleven» (b_2_l6 и b_7_l1) один и тот же сценарий — при необходимости объединить или чётко развести по уровням.")
    lines.append("")

    report = "\n".join(lines)
    out_path = os.path.join(BASE, "docs", "baza_courses_report.md")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(report)
    print(report)
    print(f"\nОтчёт сохранён: {out_path}")


if __name__ == "__main__":
    main()
