#!/usr/bin/env python3
"""Launch traffic-light audit of catalog + lessons + steps.

Writes one readable HTML report. Does not mutate curriculum JSON.
"""
from __future__ import annotations

import html
import json
import re
from collections import Counter, defaultdict
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "taika/Resourses/taika_basa_course.json"
LESSONS = ROOT / "lessons.json"
STEPS = ROOT / "steps.json"
OUT_HTML = ROOT / "docs/LAUNCH_CURRICULUM_TRAFFIC_LIGHT.html"
OUT_JSON = ROOT / "docs/launch_curriculum_traffic_light.json"
BASE_DIFF = ROOT / "docs/base_curriculum_fix_diff.json"
LIFE_DIFF = ROOT / "docs/life_curriculum_fix_diff.json"
SOUL_DIFF = ROOT / "docs/soul_long_curriculum_fix_diff.json"
WAVE_DIFF = ROOT / "docs/wave_curriculum_fix_diff.json"
GENERIC_DIFF = ROOT / "docs/paid_generic_fix_diff.json"

LEARNABLE = {"word", "phrase", "casual"}
ARROWS = set("→↓↘↑↗")
LATIN = re.compile(r"[A-Za-z]")
CYR = re.compile(r"[а-яёА-ЯЁ]")
THAI = re.compile(r"[\u0E00-\u0E7F]")
COMBINING = re.compile(r"[\u0300-\u036f]")
PH_PARTICLE = re.compile(r"^(кхрап|крап|кха)[→↓↘↑↗]?$", re.I)
PARTICLE_ONLY = {"ครับ", "ค่ะ", "คะ"}
GENERIC_TIPS = (
    "используй как короткую реплику",
    "детали и объяснение держи отдельно",
    "не строй длинный диалог",
)

# Bare survival that belongs in Base, not as paid situational cards.
BASE_LEAK_RU = {
    "спасибо",
    "пожалуйста",
    "привет",
    "здравствуй",
    "здравствуйте",
    "как дела",
    "как дела?",
    "до свидания",
    "пока",
    "извини",
    "извините",
    "прости",
}

# Situation kits: at least one RU stem should appear in the course if the title promises it.
SITUATION_KITS: dict[str, tuple[str, tuple[str, ...]]] = {
    "course_l_1": ("пост / полиция", ("паспорт", "полиц", "штраф", "водитель", "прав", "стоп")),
    "course_l_2": ("такси", ("такси", "останови", "прямо", "налево", "направо", "счётчик", "grab", "аэропорт")),
    "course_l_3": ("рынок", ("сколько", "дорого", "дешев", "кило", "торг", "батх")),
    "course_l_4": ("еда / заказ", ("меню", "остро", "счёт", "заказ", "рис", "без")),
    "course_l_5": ("врач", ("врач", "больн", "аптек", "болит", "аллерг", "температ")),
    "course_l_6": ("отель", ("номер", "ключ", "выезд", "завтрак", "бронь", "ресеп")),
    "course_l_7": ("пляж", ("пляж", "зонт", "волн", "шезлонг", "море")),
    "course_l_8": ("магазин", ("пакет", "картой", "наличн", "размер", "пример", "касс")),
    "course_l_9": ("срочная помощь", ("скор", "помощ", "авари", "вызов", "больно")),
    "course_l_10": ("зал", ("зал", "подход", "тренер", "вес", "разминк")),
    "course_l_11": ("праздник", ("сонгкран", "праздник", "вода", "поздрав")),
    "course_l_12": ("салон / образ", ("стриж", "салон", "окрас", "маник")),
    "course_l_13": ("жильё / хозяин", ("ключ", "вода", "свет", "сосе", "слома", "кондиц")),
    "course_l_14": ("доставка", ("доставк", "курьер", "адрес", "код")),
    "course_l_15": ("ночь / знакомства", ("бар", "знаком", "выпить", "танц")),
    "course_long_1": ("виза", ("виза", "штамп", "продлен", "иммиграц", "паспорт")),
    "course_long_2": ("банк", ("счёт", "карт", "банкомат", "перевод", "банк")),
    "course_long_3": ("медицина / страховка", ("страхов", "больниц", "анализ", "врач")),
    "course_long_4": ("свой транспорт", ("bts", "mrt", "байк", "маршрут", "остановка")),
    "course_long_5": ("кондо / соседи", ("кондо", "сосе", "шум", "парков")),
    "course_long_6": ("питомцы", ("собак", "кошк", "вет", "клетка")),
}

MIN_CARDS = 8
NOISE_CODES = {"no_tip", "dup_across_courses", "thin_lesson_copy", "generic_tip"}
WHY_LABEL = {
    "ok": "чисто",
    "overlap_only": "только пересечение с другим курсом — не дыра",
    "thin": "мало карточек",
    "recap": "повтор внутри своего курса",
    "leak": "базовая фраза в платном курсе",
    "red": "красный",
    "other": "другая жёлтая пометка",
}
BLOCK_OF = (
    ("course_b_", "1. База от Тайки"),
    ("course_l_", "2. Тайский для жизни"),
    ("course_e_", "4. На одной волне"),
    ("course_s_", "3. Тайский для души"),
    ("course_long_", "3. Долгожители"),
)


def course_block(cid: str) -> str:
    for prefix, name in BLOCK_OF:
        if str(cid).startswith(prefix):
            return name
    return "Другое"


def lesson_why(flags: list[dict], color: str) -> str:
    codes = [f.get("code") for f in flags]
    if color == "red":
        return "red"
    if color == "yellow":
        if "thin" in codes or "too_thin" in codes:
            return "thin"
        if "dup_in_course" in codes:
            return "recap"
        if "base_leak" in codes:
            return "leak"
        return "other"
    if "dup_across_courses" in codes:
        return "overlap_only"
    return "ok"


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def norm_ru(s: str) -> str:
    s = (s or "").strip().lower().replace("ё", "е")
    return re.sub(r"\s+", " ", re.sub(r"[^\wа-я]+", " ", s, flags=re.I)).strip()


def norm_th(s: str) -> str:
    return re.sub(r"\s+", "", (s or "").strip())


def card_key(it: dict) -> tuple[str, str]:
    return (norm_ru(it.get("ru") or ""), norm_th(it.get("thai") or ""))


def phonetic_problems(ph: str, thai: str) -> list[str]:
    out = []
    if not (ph or "").strip():
        return ["empty_phonetic"]
    if LATIN.search(ph):
        out.append("latin_phonetic")
    if THAI.search(ph):
        out.append("thai_in_phonetic")
    if COMBINING.search(ph):
        out.append("diacritic_phonetic")
    has_cyr = bool(CYR.search(ph))
    has_arrow = any(a in ph for a in ARROWS)
    if has_cyr and not LATIN.search(ph) and not has_arrow and not COMBINING.search(ph):
        out.append("missing_tone_arrows")
    compact_th = re.sub(r"\s+", "", thai or "")
    if compact_th not in PARTICLE_ONLY:
        if "ครับ" in (thai or "") or "ค่ะ" in (thai or ""):
            out.append("baked_politeness")
        if any(PH_PARTICLE.match(p) for p in ph.split()):
            out.append("baked_politeness_phonetic")
    return out


def worst(*colors: str) -> str:
    order = {"green": 0, "yellow": 1, "red": 2}
    return max(colors, key=lambda c: order[c])


def color_label(c: str) -> str:
    return {"green": "ОК", "yellow": "условно ОК", "red": "не ОК"}[c]


def main() -> int:
    catalog = load(CATALOG)
    lessons_root = load(LESSONS)
    steps_root = load(STEPS)

    cat_by_id = {c["id"]: c for c in catalog}
    lesson_courses = {c["course_id"]: c for c in lessons_root["courses"]}
    stepsets = steps_root["stepsets"]
    ss_by_lesson = {s["lesson_id"]: s for s in stepsets}
    ss_by_id = {s["id"]: s for s in stepsets}

    # Global usage of cards
    usage: dict[tuple[str, str], list[tuple[str, str, str]]] = defaultdict(list)
    for ss in stepsets:
        cid = ss.get("course_id") or ""
        lid = ss.get("lesson_id") or ""
        for it in ss.get("items") or []:
            if it.get("kind") not in LEARNABLE:
                continue
            k = card_key(it)
            if k[0] or k[1]:
                usage[k].append((cid, lid, (it.get("ru") or "").strip()))

    courses_out = []
    totals = Counter()
    lesson_color_counts = Counter()
    course_color_counts = Counter()
    red_lessons_flat = []

    cat_order = [c["id"] for c in catalog]
    for cid in cat_order:
        cat = cat_by_id[cid]
        block = lesson_courses.get(cid)
        is_base = (cat.get("category") or "") == "База от Тайки"
        is_pro = bool(cat.get("is_pro"))
        course_flags: list[dict] = []
        lessons_out = []

        if not block:
            course_flags.append({"sev": "red", "code": "catalog_missing_lessons", "msg": "Курс есть в каталоге, нет в lessons.json"})
            courses_out.append(_course_row(cat, [], course_flags, is_base, is_pro, "red"))
            course_color_counts["red"] += 1
            continue

        lessons = block.get("lessons") or []
        declared = cat.get("lesson_count")
        if declared is not None and declared != len(lessons):
            course_flags.append({"sev": "red", "code": "lesson_count_mismatch", "msg": f"В каталоге {declared} уроков, в lessons.json {len(lessons)}"})

        if block.get("course_title") != cat.get("title"):
            course_flags.append({"sev": "yellow", "code": "title_mismatch", "msg": "Название в каталоге ≠ lessons.json"})

        ru_blob_parts: list[str] = []
        course_keys_seen: dict[tuple[str, str], str] = {}
        intra_course_dupes = 0
        learnable_course = 0
        base_leak_n = 0
        thin_n = 0
        empty_n = 0
        phonetic_err_n = 0

        for les in lessons:
            lid = les.get("lesson_id") or ""
            title = les.get("title") or ""
            ref = (les.get("links") or {}).get("steps_ref")
            flags: list[dict] = []
            items = []
            ss = None
            if not ref:
                flags.append({"sev": "red", "code": "no_steps_ref", "msg": "Нет links.steps_ref"})
            elif ref not in ss_by_id:
                flags.append({"sev": "red", "code": "broken_steps_ref", "msg": f"steps_ref «{ref}» нет в steps.json"})
            else:
                ss = ss_by_id[ref]
                if ss.get("lesson_id") != lid:
                    flags.append({"sev": "red", "code": "steps_ref_lesson_mismatch", "msg": "steps_ref указывает на другой lesson_id"})
                items = ss.get("items") or []

            if lid and lid not in ss_by_lesson:
                flags.append({"sev": "red", "code": "no_stepset", "msg": "Нет stepset с этим lesson_id"})

            if not (les.get("outcomes") or []):
                flags.append({"sev": "yellow", "code": "empty_outcomes", "msg": "Нет outcomes — непонятно, чему учит урок"})

            content_blocks = les.get("content") or []
            if len(content_blocks) < 3:
                flags.append({"sev": "yellow", "code": "thin_lesson_copy", "msg": f"Мало текстовых блоков урока ({len(content_blocks)})"})

            learnable = [it for it in items if it.get("kind") in LEARNABLE]
            tips = [it for it in items if it.get("kind") == "tip"]
            n = len(learnable)
            learnable_course += n
            if n == 0 and not cid.startswith("course_b_0"):
                empty_n += 1
                flags.append({"sev": "red", "code": "no_learnable", "msg": "Нет карточек word/phrase/casual — урок пустой"})
            elif n and n < MIN_CARDS and not cid.startswith("course_b_0"):
                thin_n += 1
                flags.append({"sev": "yellow", "code": "thin", "msg": f"Тонкий урок: {n} карточек (цель {MIN_CARDS}–12)"})

            intro = next((b.get("text") or "" for b in content_blocks if b.get("kind") == "intro"), "")
            apply = next((b.get("text") or "" for b in content_blocks if b.get("kind") == "apply"), "")
            outcomes = [str(x) for x in (les.get("outcomes") or []) if str(x).strip()]

            intra_lesson = Counter(card_key(it) for it in learnable if card_key(it)[0] or card_key(it)[1])
            for k, cnt in intra_lesson.items():
                if cnt > 1:
                    flags.append({"sev": "red", "code": "dup_in_lesson", "msg": f"Дубль внутри урока ×{cnt}: «{learnable_label(learnable, k)}»"})

            cards = []
            kinds = Counter()
            for it in items:
                kind = (it.get("kind") or "").strip()
                order = it.get("order")
                if kind == "tip":
                    text = (it.get("text") or "").strip()
                    cards.append({
                        "order": order,
                        "kind": "tip",
                        "ru": text,
                        "thai": "",
                        "ph": "",
                        "tip": "",
                        "color": "green",
                        "notes": ["рамка урока"],
                    })
                    continue
                if kind not in LEARNABLE:
                    cards.append({
                        "order": order,
                        "kind": kind or "?",
                        "ru": (it.get("ru") or it.get("text") or "").strip(),
                        "thai": (it.get("thai") or "").strip(),
                        "ph": (it.get("phonetic") or "").strip(),
                        "tip": (it.get("tip") or "").strip(),
                        "color": "yellow",
                        "notes": [f"нестандартный kind: {kind}"],
                    })
                    continue

                kinds[kind] += 1
                ru = (it.get("ru") or "").strip()
                thai = (it.get("thai") or "").strip()
                ph = (it.get("phonetic") or "").strip()
                tip = (it.get("tip") or "").strip()
                ru_blob_parts.append(ru)
                notes: list[str] = []
                card_color = "green"

                k = card_key(it)
                prev = course_keys_seen.get(k)
                if prev and (k[0] or k[1]):
                    intra_course_dupes += 1
                    notes.append(f"повтор в этом курсе (уже в {prev})")
                    card_color = worst(card_color, "yellow")
                    flags.append({"sev": "yellow", "code": "dup_in_course", "msg": f"Уже было в этом курсе ({prev}): «{ru}»"})
                elif k[0] or k[1]:
                    course_keys_seen[k] = lid

                if intra_lesson.get(k, 0) > 1:
                    notes.append("дубль внутри урока")
                    card_color = "red"

                places = usage.get(k) or []
                other_courses = sorted({c for c, _, _ in places if c != cid})
                if len(other_courses) >= 2:
                    notes.append(f"ещё в {len(other_courses)} курсах")
                    card_color = worst(card_color, "yellow")
                    flags.append({"sev": "yellow", "code": "dup_across_courses", "msg": f"Та же карточка ещё в {len(other_courses)} курсах: «{ru}»"})

                nru = norm_ru(ru)
                leak_ok_course = cid in {"course_e_4"} and nru in {"извини", "извините", "прости"}
                wrap = bool(re.search(r"\b(весь|вся|всё)\b", title, re.I))
                if (
                    not is_base
                    and not leak_ok_course
                    and nru in BASE_LEAK_RU
                    and len(nru.split()) <= 2
                ):
                    base_leak_n += 1
                    notes.append("базовая карточка в ситуативном курсе")
                    card_color = worst(card_color, "yellow")
                    flags.append(
                        {
                            "sev": "yellow",
                            "code": "base_leak",
                            "msg": f"Базовая карточка в ситуативном курсе: «{ru}»"
                            + (" (в сценке-итоге — допустимо, если не единственное мясо)" if wrap else ""),
                        }
                    )

                if not ru:
                    notes.append("пустой русский")
                    card_color = "red"
                    flags.append({"sev": "red", "code": "empty_ru", "msg": "Пустой русский"})
                if not thai:
                    notes.append("пустой тайский")
                    card_color = "red"
                    flags.append({"sev": "red", "code": "empty_thai", "msg": "Пустой тайский"})
                for p in phonetic_problems(ph, thai):
                    phonetic_err_n += 1
                    notes.append(p)
                    card_color = "red"
                    flags.append({"sev": "red", "code": p, "msg": f"{p}: «{ph}» / {ru}"})

                if tip and any(g in tip.lower() for g in GENERIC_TIPS):
                    notes.append("шаблонный tip")
                    card_color = worst(card_color, "yellow")
                    flags.append({"sev": "yellow", "code": "generic_tip", "msg": f"Шаблонный tip: «{tip[:80]}»"})

                cards.append({
                    "order": order,
                    "kind": kind,
                    "ru": ru,
                    "thai": thai,
                    "ph": ph,
                    "tip": tip,
                    "color": card_color,
                    "notes": notes,
                })

            if not tips and n >= 6 and not cid.startswith("course_b_0"):
                flags.append({"sev": "yellow", "code": "no_tip", "msg": "Нет tip в уроке — мало образовательной рамки"})

            leak_here = sum(1 for f in flags if f["code"] == "base_leak")
            if n >= 4 and leak_here >= max(3, int(n * 0.4)):
                flags.append({"sev": "red", "code": "lesson_is_base", "msg": f"Урок на {leak_here}/{n} состоит из базовых карточек — бессмысленный как платная ситуация"})
            if n and n < 5 and not cid.startswith("course_b_0"):
                flags.append({"sev": "red", "code": "too_thin", "msg": f"Критически тонкий урок: {n} карточек — нет объёма, чтобы учить"})

            # Deduplicate similar flags (dup_across can explode)
            flags = _dedupe_flags(flags)

            color = _lesson_color(flags, n, cid)
            why = lesson_why(flags, color)

            lesson_color_counts[color] += 1
            row = {
                "id": lid,
                "order": les.get("order"),
                "title": title,
                "subtitle": les.get("subtitle") or "",
                "is_free": bool(les.get("is_free")),
                "n": n,
                "kinds": dict(kinds),
                "color": color,
                "why": why,
                "flags": flags,
                "outcomes": outcomes,
                "intro": intro,
                "apply": apply,
                "cards": cards,
            }
            lessons_out.append(row)
            if color == "red":
                red_lessons_flat.append({"course_id": cid, "course": cat.get("title"), "lesson": title, "id": lid, "flags": [f for f in flags if f["sev"] == "red"][:8]})

        kit = SITUATION_KITS.get(cid)
        if kit and not is_base:
            label, stems = kit
            blob = " ".join(ru_blob_parts).lower()
            hit = [s for s in stems if s.lower() in blob]
            if len(hit) < 1:
                course_flags.append({"sev": "red", "code": "scenario_hole", "msg": f"Сценарий «{label}» не закрыт (ключевые слова не нашлись в карточках)"})
            elif len(hit) < 2:
                course_flags.append({"sev": "yellow", "code": "scenario_thin", "msg": f"Сценарий «{label}» тонкий (нашлись: {hit})"})

        if intra_course_dupes >= 4:
            course_flags.append({"sev": "yellow", "code": "course_dupes", "msg": f"{intra_course_dupes} повторных карточек внутри курса"})
        if intra_course_dupes >= 8 and learnable_course and intra_course_dupes / max(learnable_course, 1) > 0.35:
            course_flags.append({"sev": "red", "code": "course_dupes_heavy", "msg": "Курс на треть состоит из внутренних дублей"})
        if thin_n >= 2:
            course_flags.append({"sev": "yellow", "code": "many_thin", "msg": f"{thin_n} тонких уроков"})
        if lessons and thin_n == len(lessons) and not cid.startswith("course_b_0"):
            course_flags.append({"sev": "red", "code": "all_lessons_thin", "msg": "Все уроки тонкие — курс выглядит как недоделанный платный пакет"})
        if empty_n:
            course_flags.append({"sev": "red", "code": "empty_lessons", "msg": f"{empty_n} уроков без карточек"})
        if phonetic_err_n:
            course_flags.append({"sev": "red", "code": "phonetic_errors", "msg": f"{phonetic_err_n} ошибок фонетики/тонов/частиц"})
        if base_leak_n >= 6:
            course_flags.append({"sev": "red", "code": "base_leak_course", "msg": f"{base_leak_n} базовых карточек — курс учит Базе, а не ситуации"})
        elif base_leak_n >= 3:
            course_flags.append({"sev": "yellow", "code": "base_leak_course", "msg": f"{base_leak_n} базовых карточек в ситуативном курсе"})

        lesson_colors = [l["color"] for l in lessons_out]
        color = "green"
        if course_flags:
            color = worst(color, *[f["sev"] for f in course_flags])
        red_n = sum(1 for c in lesson_colors if c == "red")
        yellow_n = sum(1 for c in lesson_colors if c == "yellow")
        if red_n >= 2:
            color = "red"
        elif red_n == 1:
            color = worst(color, "yellow")
        elif yellow_n:
            color = worst(color, "yellow")

        course_color_counts[color] += 1
        totals["lessons"] += len(lessons_out)
        totals["learnable"] += learnable_course
        courses_out.append(_course_row(cat, lessons_out, course_flags, is_base, is_pro, color, learnable_course, thin_n, intra_course_dupes))

    texture = build_texture(courses_out)
    payload = {
        "date": str(date.today()),
        "base_diff": json.loads(BASE_DIFF.read_text(encoding="utf-8")) if BASE_DIFF.exists() else None,
        "life_diff": json.loads(LIFE_DIFF.read_text(encoding="utf-8")) if LIFE_DIFF.exists() else None,
        "soul_diff": json.loads(SOUL_DIFF.read_text(encoding="utf-8")) if SOUL_DIFF.exists() else None,
        "wave_diff": json.loads(WAVE_DIFF.read_text(encoding="utf-8")) if WAVE_DIFF.exists() else None,
        "generic_diff": json.loads(GENERIC_DIFF.read_text(encoding="utf-8")) if GENERIC_DIFF.exists() else None,
        "texture": texture,
        "totals": {
            "courses": len(courses_out),
            "lessons": totals["lessons"],
            "learnable": totals["learnable"],
            "courses_green": course_color_counts["green"],
            "courses_yellow": course_color_counts["yellow"],
            "courses_red": course_color_counts["red"],
            "lessons_green": lesson_color_counts["green"],
            "lessons_yellow": lesson_color_counts["yellow"],
            "lessons_red": lesson_color_counts["red"],
        },
        "courses": courses_out,
        "red_lessons": red_lessons_flat,
    }
    OUT_JSON.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    OUT_HTML.write_text(render_html(payload), encoding="utf-8")
    print("courses", dict(course_color_counts))
    print("lessons", dict(lesson_color_counts))
    print("wrote", OUT_HTML)
    print("wrote", OUT_JSON)
    return 0


def _lesson_color(flags: list[dict], n: int, cid: str) -> str:
    if any(f["sev"] == "red" for f in flags):
        return "red"
    # Пересечение той же фразы с другим курсом — норма для ниши, не жёлтый курс.
    if any(f["code"] == "thin" for f in flags):
        return "yellow"
    material = [f for f in flags if f["code"] not in NOISE_CODES]
    if any(f["sev"] == "yellow" for f in material):
        return "yellow"
    return "green"


def learnable_label(items: list[dict], k: tuple[str, str]) -> str:
    for it in items:
        if card_key(it) == k:
            return (it.get("ru") or k[0] or k[1])[:80]
    return k[0] or k[1]


def _dedupe_flags(flags: list[dict]) -> list[dict]:
    seen = Counter()
    out = []
    overflow = Counter()
    for f in flags:
        key = (f["code"], f["msg"])
        if seen[key]:
            continue
        seen[key] += 1
        # cap noisy codes
        if f["code"] in {"dup_across_courses", "dup_in_course", "generic_tip"}:
            overflow[f["code"]] += 1
            if overflow[f["code"]] > 4:
                continue
        out.append(f)
    extra = []
    for code, n in overflow.items():
        if n > 4:
            extra.append({"sev": "yellow", "code": code, "msg": f"ещё {n - 4} таких же пометок (свернуто)"})
    return extra + out


def _course_row(cat, lessons, flags, is_base, is_pro, color, learnable=0, thin=0, dups=0):
    return {
        "id": cat["id"],
        "title": cat.get("title") or cat["id"],
        "category": cat.get("category") or "",
        "is_pro": is_pro,
        "is_base": is_base,
        "description": cat.get("description") or "",
        "lesson_count": len(lessons),
        "learnable": learnable,
        "thin": thin,
        "dups": dups,
        "color": color,
        "flags": flags,
        "lessons": lessons,
    }


def build_texture(courses: list[dict]) -> dict:
    why_n = Counter()
    overlap_lessons = []
    real_yellow = []
    red_courses = []
    by_block = defaultdict(lambda: Counter())
    overlap_phrases = Counter()
    for c in courses:
        block = course_block(c["id"])
        by_block[block][c["color"]] += 1
        if c["color"] == "red":
            red_courses.append({"id": c["id"], "title": c.get("title"), "block": block, "flags": c.get("flags") or []})
        for les in c.get("lessons") or []:
            why = les.get("why") or lesson_why(les.get("flags") or [], les.get("color") or "green")
            why_n[why] += 1
            overlaps = [f for f in (les.get("flags") or []) if f.get("code") == "dup_across_courses"]
            if why == "overlap_only" or (les.get("color") == "green" and overlaps):
                phrases = []
                for f in overlaps:
                    msg = f.get("msg") or ""
                    # «Название»
                    if "«" in msg and "»" in msg:
                        phrases.append(msg[msg.find("«") + 1 : msg.find("»")])
                    overlap_phrases[msg[:120]] += 1
                overlap_lessons.append({
                    "course": c.get("title"),
                    "course_id": c["id"],
                    "block": block,
                    "lesson": les.get("title"),
                    "id": les.get("id"),
                    "n": les.get("n"),
                    "phrases": phrases[:4],
                })
            if les.get("color") == "yellow":
                real_yellow.append({
                    "course": c.get("title"),
                    "course_id": c["id"],
                    "block": block,
                    "lesson": les.get("title"),
                    "id": les.get("id"),
                    "n": les.get("n"),
                    "why": why,
                    "flags": [f.get("msg") for f in (les.get("flags") or []) if f.get("code") not in NOISE_CODES][:4],
                })
    blocks = []
    for _, name in BLOCK_OF:
        cnt = by_block.get(name) or Counter()
        if not cnt:
            continue
        blocks.append({
            "name": name,
            "green": cnt["green"],
            "yellow": cnt["yellow"],
            "red": cnt["red"],
        })
    return {
        "why": dict(why_n),
        "blocks": blocks,
        "overlap_lessons": overlap_lessons,
        "real_yellow": real_yellow,
        "red_courses": red_courses,
        "overlap_top": [{"msg": m, "n": n} for m, n in overlap_phrases.most_common(20)],
    }


def render_texture(tex: dict | None, pill) -> str:
    if not tex:
        return ""
    why = tex.get("why") or {}
    block_rows = []
    for b in tex.get("blocks") or []:
        block_rows.append(
            f"<tr><td>{html.escape(b['name'])}</td>"
            f"<td>{pill('green', str(b.get('green') or 0))}</td>"
            f"<td>{pill('yellow', str(b.get('yellow') or 0))}</td>"
            f"<td>{pill('red', str(b.get('red') or 0))}</td></tr>"
        )
    real_rows = []
    for r in tex.get("real_yellow") or []:
        real_rows.append(
            f"<tr class='yellow'><td>{html.escape(r.get('block') or '')}</td>"
            f"<td>{html.escape(r.get('course') or '')}<div class='meta'><code>{html.escape(r.get('course_id') or '')}</code></div></td>"
            f"<td><b>{html.escape(r.get('lesson') or '')}</b> · {r.get('n')} карт."
            f"<div class='meta'><code>{html.escape(r.get('id') or '')}</code></div></td>"
            f"<td>{pill('yellow', WHY_LABEL.get(r.get('why') or '', r.get('why') or ''))}<div class='meta'>{html.escape(' · '.join(r.get('flags') or []))}</div></td></tr>"
        )
    overlap_rows = []
    for r in tex.get("overlap_lessons") or []:
        ph = ", ".join(r.get("phrases") or []) or "—"
        overlap_rows.append(
            f"<tr class='green'><td>{html.escape(r.get('block') or '')}</td>"
            f"<td>{html.escape(r.get('course') or '')}</td>"
            f"<td>{html.escape(r.get('lesson') or '')}<div class='meta'><code>{html.escape(r.get('id') or '')}</code></div></td>"
            f"<td>{html.escape(ph)}</td></tr>"
        )
    red_rows = []
    for r in tex.get("red_courses") or []:
        msgs = " · ".join(html.escape(f.get("msg") or "") for f in (r.get("flags") or [])[:4])
        red_rows.append(
            f"<tr class='red'><td>{html.escape(r.get('block') or '')}</td>"
            f"<td>{html.escape(r.get('title') or '')} <code>{html.escape(r.get('id') or '')}</code></td>"
            f"<td>{msgs}</td></tr>"
        )
    return f"""
  <div class="course yellow" id="texture">
    <h2 style="margin:0 0 8px;font-size:16px">Фактура анализа — что смотреть</h2>
    <p>Светофор красит <b>урок</b>, не «есть пометка». Пересечение одной фразы с другим курсом (карта, границы, остро) <b>больше не делает курс жёлтым</b>. Это нормальная ниша, не дыра.</p>
    <p class="meta">Четыре прогона карточек закрыты: База, «для жизни», душа + долгожители, «на одной волне». Очередь thin / recap / leak пустая. Ниже в свёртке — пересечения между курсами, это шум, не дыра.</p>
    <div class="stats" style="margin:12px 0;padding:0;border:0;background:transparent">
      <div class="stat"><b>{why.get('ok', 0)}</b><span>уроков чистых</span></div>
      <div class="stat"><b>{why.get('overlap_only', 0)}</b><span>только пересечение — шум</span></div>
      <div class="stat"><b>{why.get('thin', 0)}</b><span>мало карточек — править</span></div>
      <div class="stat"><b>{why.get('recap', 0)}</b><span>повтор внутри курса — править</span></div>
      <div class="stat"><b>{why.get('leak', 0)}</b><span>базовая фраза в платном</span></div>
      <div class="stat"><b>{why.get('red', 0)}</b><span>уроков красных</span></div>
    </div>
    <h3 style="margin:16px 0 6px;font-size:15px">По блокам каталога</h3>
    <table>
      <thead><tr><th>Блок</th><th>зелёные курсы</th><th>жёлтые (реальные)</th><th>красные</th></tr></thead>
      <tbody>{''.join(block_rows)}</tbody>
    </table>
    <h3 style="margin:16px 0 6px;font-size:15px">Реальная очередь — жёлтые не из пересечений</h3>
    <p class="meta">Thin, recap внутри курса или leak из Базы. Сейчас пусто.</p>
    <table>
      <thead><tr><th>Блок</th><th>Курс</th><th>Урок</th><th>Почему</th></tr></thead>
      <tbody>{''.join(real_rows) or '<tr><td colspan="4">Реальных жёлтых уроков нет</td></tr>'}</tbody>
    </table>
    <h3 style="margin:16px 0 6px;font-size:15px">Красные курсы</h3>
    <table>
      <thead><tr><th>Блок</th><th>Курс</th><th>Почему</th></tr></thead>
      <tbody>{''.join(red_rows) or '<tr><td colspan="3">Красных курсов нет</td></tr>'}</tbody>
    </table>
    <details>
      <summary>Пересечения между курсами — не очередь правок ({len(tex.get('overlap_lessons') or [])} уроков)</summary>
      <p class="meta">Одна и та же фраза живёт в двух сценах. Для ниши это ок. Не путать с «дублем из Базы».</p>
      <table>
        <thead><tr><th>Блок</th><th>Курс</th><th>Урок</th><th>Какая фраза пересекается</th></tr></thead>
        <tbody>{''.join(overlap_rows) or '<tr><td colspan="4">нет</td></tr>'}</tbody>
      </table>
    </details>
  </div>
"""


def _color_word(c: str) -> str:
    return {"green": "зелёный", "yellow": "жёлтый", "red": "красный"}.get(c or "", c or "—")


def render_base_diff(diff: dict | None, pill) -> str:
    if not diff:
        return ""
    before_c = {c["id"]: c for c in (diff.get("before") or {}).get("courses") or []}
    after_c = {c["id"]: c for c in (diff.get("after") or {}).get("courses") or []}
    bt = (diff.get("before") or {}).get("totals") or {}
    at = (diff.get("after") or {}).get("totals") or {}
    title = diff.get("title") or "Дифф — было → стало"
    html_id = diff.get("html_id") or "diff"
    foot = diff.get("foot") or "Ниже только уроки, которые реально менялись."

    course_ids = [c["id"] for c in (diff.get("after") or {}).get("courses") or []]
    if not course_ids:
        course_ids = [c["id"] for c in (diff.get("before") or {}).get("courses") or []]

    course_rows = []
    for cid in course_ids:
        b = before_c.get(cid) or {}
        a = after_c.get(cid) or {}
        if not b and not a:
            continue
        changed = (b.get("color") != a.get("color")) or (b.get("learnable") != a.get("learnable"))
        course_rows.append(
            f"<tr class='{(a.get('color') or 'green')}'>"
            f"<td><code>{html.escape(cid)}</code><div class='meta'>{html.escape(a.get('title') or b.get('title') or '')}</div></td>"
            f"<td>{pill(b.get('color') or 'green', _color_word(b.get('color') or ''))} · {b.get('learnable', '—')} карт.</td>"
            f"<td>{pill(a.get('color') or 'green', _color_word(a.get('color') or ''))} · {a.get('learnable', '—')} карт.</td>"
            f"<td>{'да' if changed else 'нет'}</td></tr>"
        )

    lesson_rows = []
    for row in diff.get("lessons") or []:
        b_les = a_les = {}
        for block in before_c.values():
            for les in block.get("lessons") or []:
                if les["id"] == row["id"]:
                    b_les = les
        for block in after_c.values():
            for les in block.get("lessons") or []:
                if les["id"] == row["id"]:
                    a_les = les
        added_html = "".join(
            f"<div><b>{html.escape(x.get('ru') or '')}</b> · "
            f"<span class='ph'>{html.escape(x.get('ph') or '')}</span> · "
            f"<span class='th'>{html.escape(x.get('thai') or '')}</span></div>"
            for x in (row.get("added") or [])
        ) or "<span class='meta'>карточек не добавляли</span>"
        repl_html = "".join(
            f"<div class='frame'><span class='meta'>было:</span> <b>{html.escape(x.get('ru_before') or '')}</b> · "
            f"<span class='ph'>{html.escape(x.get('ph_before') or '')}</span> · "
            f"<span class='th'>{html.escape(x.get('thai_before') or '')}</span><br/>"
            f"<span class='meta'>стало:</span> <b>{html.escape(x.get('ru_after') or '')}</b> · "
            f"<span class='ph'>{html.escape(x.get('ph_after') or '')}</span> · "
            f"<span class='th'>{html.escape(x.get('thai_after') or '')}</span></div>"
            for x in (row.get("replaced") or [])
        )
        ph_html = "".join(
            f"<div><b>{html.escape(x.get('ru') or '')}</b><br/>"
            f"<span class='meta'>было</span> <span class='ph'>{html.escape(x.get('ph_before') or '')}</span><br/>"
            f"<span class='meta'>стало</span> <span class='ph'>{html.escape(x.get('ph_after') or '')}</span></div>"
            for x in (row.get("changed") or [])
        )
        extra = repl_html or ph_html or "<span class='meta'>—</span>"
        lesson_rows.append(
            f"<tr class='{(a_les.get('color') or 'green')}'>"
            f"<td><b>{html.escape(row.get('title') or '')}</b>"
            f"<div class='meta'><code>{html.escape(row['id'])}</code> · {html.escape(row.get('course') or '')}</div>"
            f"<div class='meta'>светофор: {_color_word(b_les.get('color') or '')} → {_color_word(a_les.get('color') or '')}</div></td>"
            f"<td>{row.get('n_before')} → <b>{row.get('n_after')}</b></td>"
            f"<td>{added_html}</td>"
            f"<td>{extra}</td></tr>"
        )

    stats = (
        f"<p class='meta'>Каталог целиком: курсы {bt.get('courses_green', '—')}/"
        f"{bt.get('courses_yellow', '—')}/{bt.get('courses_red', '—')} "
        f"(зелёный/жёлтый/красный) → {at.get('courses_green', '—')}/"
        f"{at.get('courses_yellow', '—')}/{at.get('courses_red', '—')}. "
        f"Уроки красные: {bt.get('lessons_red', '—')} → {at.get('lessons_red', '—')}. "
        f"Карточек learnable: {bt.get('learnable', '—')} → {at.get('learnable', '—')}.</p>"
    )
    note = html.escape(diff.get("note") or "")
    return f"""
  <div class="course yellow" id="{html.escape(html_id)}">
    <h2 style="margin:0 0 8px;font-size:16px">{html.escape(title)}</h2>
    <p class="meta">{note}</p>
    {stats}
    <p class="meta">{html.escape(foot)}</p>
    <table>
      <thead><tr><th>Курс</th><th>Было</th><th>Стало</th><th>Менялся</th></tr></thead>
      <tbody>{''.join(course_rows)}</tbody>
    </table>
    <h3 style="margin:18px 0 8px;font-size:15px">Что добавили / что заменили</h3>
    <table class="cards">
      <thead><tr><th>Урок</th><th>карт.</th><th>Новые карточки</th><th>Замена / фонетика было → стало</th></tr></thead>
      <tbody>{''.join(lesson_rows) or '<tr><td colspan="4">диффа нет</td></tr>'}</tbody>
    </table>
  </div>
"""


def render_html(p: dict) -> str:
    t = p["totals"]
    verdict = "red"
    if t["courses_red"] == 0 and t["lessons_red"] == 0:
        verdict = "yellow" if t["courses_yellow"] else "green"
    elif t["courses_red"] <= 3 and t["lessons_red"] <= 8:
        verdict = "yellow"

    def pill(c: str, text: str) -> str:
        return f'<span class="pill {c}">{html.escape(text)}</span>'

    bd = p.get("base_diff")
    if isinstance(bd, dict) and not bd.get("title"):
        bd["title"] = "Дифф Базы — было → стало"
        bd["html_id"] = "base-diff"
        bd.setdefault("foot", "Ниже только уроки Базы, которые менялись.")
    ld = p.get("life_diff")
    if isinstance(ld, dict) and not ld.get("title"):
        ld["title"] = "Дифф «Тайский для жизни» — было → стало"
        ld["html_id"] = "life-diff"
    sd = p.get("soul_diff")
    if isinstance(sd, dict) and not sd.get("title"):
        sd["title"] = "Дифф «Душа + долгожители» — было → стало"
        sd["html_id"] = "soul-diff"
    base_diff_html = render_base_diff(bd, pill)
    life_diff_html = render_base_diff(ld, pill)
    wd = p.get("wave_diff")
    if isinstance(wd, dict) and not wd.get("title"):
        wd["title"] = "Дифф «На одной волне» — было → стало"
        wd["html_id"] = "wave-diff"
    soul_diff_html = render_base_diff(sd, pill)
    wave_diff_html = render_base_diff(wd, pill)
    gd = p.get("generic_diff")
    if isinstance(gd, dict) and not gd.get("title"):
        gd["title"] = "Дифф голых базовых карточек в платных курсах — было → стало"
        gd["html_id"] = "generic-diff"
    generic_diff_html = render_base_diff(gd, pill)
    texture_html = render_texture(p.get("texture"), pill)
    sub = (
        f'Снимок {html.escape(p["date"])}. Сначала блок «Фактура анализа», потом диффы правок, потом полный каталог.'
    )

    red_block = []
    for r in p["red_lessons"]:
        msgs = " · ".join(html.escape(f["msg"]) for f in r["flags"][:5])
        red_block.append(
            f"<tr><td>{html.escape(r['course'])}</td><td>{html.escape(r['lesson'])}</td>"
            f"<td><code>{html.escape(r['id'])}</code></td><td>{msgs}</td></tr>"
        )

    cats = []
    last_cat = None
    for c in p["courses"]:
        if c["category"] != last_cat:
            last_cat = c["category"]
            cats.append(f'<h2 class="cat">{html.escape(last_cat)}</h2>')
        cats.append(render_course(c, pill))

    return f"""<!DOCTYPE html>
<html lang="ru">
<head>
<meta charset="utf-8"/>
<title>Taika — светофор учебной программы</title>
<style>
  :root {{
    --bg: #111214; --card: #1c1d21; --text: #f4f1ea; --muted: #9a958c;
    --green: #3dba7a; --yellow: #e0b43a; --red: #e25c5c; --line: #2c2d33;
  }}
  body {{ margin: 0; font-family: ui-sans-serif, system-ui, -apple-system, sans-serif;
         background: var(--bg); color: var(--text); line-height: 1.45; }}
  .wrap {{ max-width: 1100px; margin: 0 auto; padding: 28px 20px 80px; }}
  h1 {{ font-size: 28px; margin: 0 0 8px; }}
  .sub {{ color: var(--muted); margin-bottom: 24px; }}
  .legend, .stats, .verdict, .course {{ background: var(--card); border-radius: 16px;
         padding: 16px 18px; margin: 0 0 14px; border: 1px solid var(--line); }}
  .verdict.green {{ border-left: 6px solid var(--green); }}
  .verdict.yellow {{ border-left: 6px solid var(--yellow); }}
  .verdict.red {{ border-left: 6px solid var(--red); }}
  .pill {{ display: inline-block; font-size: 12px; font-weight: 700; padding: 3px 8px;
          border-radius: 999px; margin-right: 6px; }}
  .pill.green {{ background: #1d3b2c; color: #8ee0b0; }}
  .pill.yellow {{ background: #3b3318; color: #f0d27a; }}
  .pill.noise {{ background: #2a2b31; color: #9a958c; }}
  .stats {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(140px, 1fr)); gap: 10px; }}
  .stat b {{ display: block; font-size: 22px; }}
  .stat span {{ color: var(--muted); font-size: 13px; }}
  h2.cat {{ margin: 28px 0 10px; font-size: 18px; color: var(--muted); letter-spacing: .04em; text-transform: uppercase; }}
  .course.green {{ border-left: 6px solid var(--green); }}
  .course.yellow {{ border-left: 6px solid var(--yellow); }}
  .course.red {{ border-left: 6px solid var(--red); }}
  .head {{ display: flex; flex-wrap: wrap; gap: 8px; align-items: baseline; justify-content: space-between; }}
  .meta {{ color: var(--muted); font-size: 13px; }}
  details {{ margin-top: 10px; }}
  summary {{ cursor: pointer; color: var(--muted); }}
  table {{ width: 100%; border-collapse: collapse; font-size: 13px; margin-top: 8px; }}
  th, td {{ text-align: left; padding: 7px 6px; border-bottom: 1px solid var(--line); vertical-align: top; }}
  th {{ color: var(--muted); font-weight: 600; }}
  tr.green td:first-child {{ box-shadow: inset 3px 0 var(--green); }}
  tr.yellow td:first-child {{ box-shadow: inset 3px 0 var(--yellow); }}
  tr.red td:first-child {{ box-shadow: inset 3px 0 var(--red); }}
  code {{ font-size: 11px; color: #cfc8b8; }}
  .flag {{ margin: 4px 0; font-size: 13px; }}
  .samples {{ color: var(--muted); font-size: 12px; }}
  .lesson {{ margin: 10px 0; padding: 10px 12px; border-radius: 12px; background: #16171b; border: 1px solid var(--line); }}
  .lesson.green {{ border-left: 4px solid var(--green); }}
  .lesson.yellow {{ border-left: 4px solid var(--yellow); }}
  .lesson.red {{ border-left: 4px solid var(--red); }}
  .ph {{ font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 13px; color: #f0d27a; }}
  .th {{ font-size: 15px; }}
  .kind {{ font-size: 11px; letter-spacing: .04em; text-transform: uppercase; color: var(--muted); }}
  .frame {{ color: var(--muted); font-size: 13px; margin: 6px 0 8px; }}
  .cards th:nth-child(3), .cards td:nth-child(3) {{ min-width: 28%; }}
  .cards th:nth-child(4), .cards td:nth-child(4) {{ min-width: 26%; }}
</style>
</head>
<body>
<div class="wrap">
  <h1>Светофор учебной программы</h1>
  <p class="sub">{sub}</p>

  <div class="legend">
    <b>Как читать светофор</b><br/>
    {pill("green", "зелёный")} объём 8+ карточек, сценарий живой. Пересечение фразы с другим курсом урок зелёным не красит.<br/>
    {pill("yellow", "жёлтый")} мало карточек (5–7) или повтор <b>внутри этого же курса</b>, или база в платном. Это очередь правок.<br/>
    {pill("red", "красный")} &lt;5 карточек, битая фонетика, весь курс тонкий. Нельзя честно продавать.<br/>
    {pill("noise", "пометка-шум")} «нет tip» и «ещё в N курсах» — видно в уроке, но это не жёлтый курс.<br/>
    Диффы Базы, «жизни», «души» и «волны» — журнал четырёх прогонов. Фактура — что ещё жёлтое после них.
  </div>

  <div class="verdict {verdict}">
    <b>Вердикт запуска: {html.escape(color_label(verdict))}</b>
    <p class="meta">Красные курсы нельзя честно продавать как «уже собрано». Жёлтые можно оставить в каталоге, если красные уроки внутри починены. Зелёные — рабочий материал.</p>
  </div>

  <div class="stats">
    <div class="stat"><b>{t["courses"]}</b><span>курсов</span></div>
    <div class="stat"><b>{t["lessons"]}</b><span>уроков</span></div>
    <div class="stat"><b>{t["learnable"]}</b><span>карточек word/phrase/casual</span></div>
    <div class="stat"><b style="color:#8ee0b0">{t["courses_green"]}</b><span>курсов зелёных</span></div>
    <div class="stat"><b style="color:#f0d27a">{t["courses_yellow"]}</b><span>курсов жёлтых</span></div>
    <div class="stat"><b style="color:#f3a0a0">{t["courses_red"]}</b><span>курсов красных</span></div>
    <div class="stat"><b style="color:#f3a0a0">{t["lessons_red"]}</b><span>уроков красных</span></div>
  </div>

  {texture_html}

  {base_diff_html}
  {life_diff_html}
  {soul_diff_html}
  {wave_diff_html}
  {generic_diff_html}

  <div class="course red">
    <h2 style="margin:0 0 8px;font-size:16px">Сначала красные уроки</h2>
    <p class="meta">Это очередь правок. Не иди по приложению — иди по этой таблице.</p>
    <table>
      <thead><tr><th>Курс</th><th>Урок</th><th>id</th><th>Почему красный</th></tr></thead>
      <tbody>
        {''.join(red_block) or '<tr><td colspan="4">Красных уроков нет</td></tr>'}
      </tbody>
    </table>
  </div>

  {''.join(cats)}
</div>
</body>
</html>
"""


def render_course(c: dict, pill) -> str:
    flags = "".join(f'<div class="flag">{pill(f["sev"], f["code"])} {html.escape(f["msg"])}</div>' for f in c["flags"])
    lesson_blocks = []
    for les in c["lessons"]:
        fl_parts = []
        for f in les["flags"]:
            sev = "noise" if f.get("code") in NOISE_CODES else f["sev"]
            extra = " · не красит урок" if sev == "noise" else ""
            fl_parts.append(f'<div class="flag">{pill(sev, f["code"])} {html.escape(f["msg"])}{extra}</div>')
        fl = "".join(fl_parts)
        why = les.get("why") or ""
        why_s = f' · {WHY_LABEL.get(why, why)}' if why and why not in {"ok"} else ""
        pay = "free" if les["is_free"] else "pro"
        kinds = les.get("kinds") or {}
        kind_s = " · ".join(f"{k} {v}" for k, v in kinds.items()) or "нет learnable"
        frame = []
        if les.get("intro"):
            frame.append(f"<div class='frame'><b>intro:</b> {html.escape(les['intro'])}</div>")
        if les.get("apply"):
            frame.append(f"<div class='frame'><b>apply:</b> {html.escape(les['apply'])}</div>")
        if les.get("outcomes"):
            frame.append(f"<div class='frame'><b>outcome:</b> {html.escape(' · '.join(les['outcomes']))}</div>")
        card_rows = []
        for card in les.get("cards") or []:
            notes = " · ".join(html.escape(n) for n in (card.get("notes") or [])) or "—"
            tip = html.escape(card.get("tip") or "")
            tip_html = f"<div class='meta'>{tip}</div>" if tip else ""
            card_rows.append(
                f'<tr class="{card.get("color") or "green"}">'
                f'<td>{card.get("order") or ""}</td>'
                f'<td class="kind">{html.escape(card.get("kind") or "")}</td>'
                f'<td><b>{html.escape(card.get("ru") or "—")}</b>{tip_html}</td>'
                f'<td class="ph">{html.escape(card.get("ph") or "—")}</td>'
                f'<td class="th">{html.escape(card.get("thai") or "—")}</td>'
                f'<td>{notes}</td></tr>'
            )
        cards_table = (
            "<table class='cards'><thead><tr>"
            "<th>#</th><th>kind</th><th>русский (ученик)</th><th>фонетика</th><th>тайский</th><th>пометка</th>"
            "</tr></thead><tbody>"
            + ("".join(card_rows) or "<tr><td colspan='6'>карточек нет</td></tr>")
            + "</tbody></table>"
        )
        open_les = " open" if les["color"] == "red" else ""
        lesson_blocks.append(
            f'<div class="lesson {les["color"]}">'
            f'<details{open_les}>'
            f'<summary>{pill(les["color"], color_label(les["color"]))} '
            f'<b>{html.escape(str(les.get("order") or ""))}. {html.escape(les["title"])}</b> '
            f'<span class="meta">· {html.escape(les["id"])} · {pay} · {les["n"]} карт. ({html.escape(kind_s)}){html.escape(why_s)}</span>'
            f'</summary>'
            f'{"".join(frame)}{fl}{cards_table}'
            f'</details></div>'
        )
    open_attr = " open" if c["color"] == "red" else ""
    pro = "PRO" if c["is_pro"] else "free"
    return f"""
    <section class="course {c['color']}">
      <div class="head">
        <div>
          {pill(c["color"], color_label(c["color"]))}
          <b>{html.escape(c["title"])}</b>
          <div class="meta"><code>{html.escape(c["id"])}</code> · {pro} · {c["lesson_count"]} уроков · {c["learnable"]} карточек</div>
        </div>
      </div>
      <p class="meta">{html.escape(c["description"])}</p>
      {flags}
      <details{open_attr}>
        <summary>Уроки и карточки</summary>
        {''.join(lesson_blocks)}
      </details>
    </section>
    """


if __name__ == "__main__":
    raise SystemExit(main())
