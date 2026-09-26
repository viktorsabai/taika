#!/usr/bin/env python3
"""
Minimal FastAPI server for Thai tone assessment (Phase C).
POST /assess: multipart form with "file" (audio) + "text" (Thai target)
+ optional "phonetic" (Cyrillic teaching chunks; syllable count follows this, not Thai tokenizer)
+ optional "expected_tones"; returns Phase D–compatible JSON.
"""
from __future__ import annotations

import asyncio
import difflib
import functools
import importlib
import sqlite3
import subprocess
import sys
import tempfile
import time
from pathlib import Path

import json
import os
import re
from typing import Any

import requests
from fastapi import FastAPI, File, Form, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

app = FastAPI(title="Thai Tone Assessment", version="0.1.0")

# Landing (Story Lab / TestOnFly) may call Railway directly; browser needs CORS.
# Prefer same-origin `/taika-api` proxy on the site — this is a safety net.
_CORS_ORIGINS = [
    o.strip()
    for o in (
        os.environ.get("CORS_ALLOW_ORIGINS")
        or "https://taikaa.online,https://www.taikaa.online,http://localhost:3000,http://localhost:5173,http://127.0.0.1:3000,http://127.0.0.1:5173"
    ).split(",")
    if o.strip()
]
app.add_middleware(
    CORSMiddleware,
    allow_origins=_CORS_ORIGINS,
    allow_credentials=False,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)

# 16 kHz mono WAV for pitch tracker
TARGET_SR = 16000
ASSESS_TIMEOUT_S = 180.0


def _ensure_wav(path: str, suffix: str) -> str | None:
    """
    If path is .m4a or .mp3, convert to .wav with ffmpeg and return path to wav (caller must unlink).
    Avoids librosa.load() hanging on m4a (audioread backend). Returns None if conversion fails.
    """
    if suffix.lower() not in (".m4a", ".mp3"):
        return None
    wav_path = path + ".wav"
    try:
        subprocess.run(
            [
                "ffmpeg", "-y", "-i", path,
                "-acodec", "pcm_s16le", "-ar", str(TARGET_SR), "-ac", "1",
                wav_path,
            ],
            capture_output=True,
            timeout=30,
            check=True,
        )
        return wav_path
    except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired) as e:
        print(f"[tone_assess] ffmpeg convert failed ({e}), will try librosa on original", file=sys.stderr, flush=True)
        return None


@app.post("/assess")
async def post_assess(
    file: UploadFile = File(..., description="Audio file (WAV preferred)"),
    text: str = Form(..., description="Target Thai word or phrase"),
    expected_tones: str | None = Form(None, description="Optional: comma-separated tones, e.g. Mid,Falling"),
    phonetic: str | None = Form(
        None,
        description="Cyrillic teaching phonetic; syllable count follows these chunks, not Thai tokenizer",
    ),
    text_score: int | None = Form(None, description="Optional: 0-100 text similarity from client (ASR); used for hybrid_score"),
):
    """
    Accept an audio file and target text; return total_score and per-syllable tone assessment.
    If text_score (0-100) is provided, adds hybrid_score = 0.4*text + 0.3*phoneme_avg + 0.3*tone_avg
    (phoneme_avg = tone_avg until phoneme_score per syllable is wired).
    """
    if not text or not text.strip():
        raise HTTPException(status_code=400, detail="text is required")

    suffix = Path(file.filename or "audio").suffix or ".wav"
    if suffix.lower() not in (".wav", ".wave", ".mp3", ".m4a", ".ogg", ".webm"):
        suffix = ".wav"

    try:
        body = await file.read()
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to read file: {e!s}")

    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
        tmp.write(body)
        tmp_path = tmp.name

    # Convert m4a/mp3 to WAV so librosa doesn't hang (audioread on m4a can block on macOS)
    assess_path = tmp_path
    wav_path = _ensure_wav(tmp_path, suffix)
    if wav_path:
        assess_path = wav_path

    loop = asyncio.get_event_loop()
    try:
        result = await asyncio.wait_for(
            loop.run_in_executor(
                None,
                # Lazy import: avoid slow librosa/numba import at server startup.
                lambda: importlib.import_module("run_phase_c").assess(
                    assess_path,
                    text.strip(),
                    expected_tones,
                    (phonetic or "").strip() or None,
                ),
            ),
            timeout=ASSESS_TIMEOUT_S,
        )
    except asyncio.TimeoutError:
        raise HTTPException(
            status_code=504,
            detail=f"Tone assessment timed out ({int(ASSESS_TIMEOUT_S)}s). Try a shorter recording.",
        )
    finally:
        Path(assess_path).unlink(missing_ok=True)
        if wav_path and wav_path != tmp_path:
            Path(tmp_path).unlink(missing_ok=True)

    if "error" in result:
        print(f"[assess] error: {result['error']}", file=sys.stderr, flush=True)
        raise HTTPException(status_code=422, detail=result["error"])

    syl_count = len(result.get("syllables") or [])
    print(f"[assess] ok: total_score={result.get('total_score')} syllables={syl_count}", file=sys.stderr, flush=True)

    # Hybrid score: 0.4*text + 0.3*phoneme + 0.3*tone (phoneme_avg = tone_avg for now)
    if text_score is not None and 0 <= text_score <= 100:
        syllables = result.get("syllables") or []
        tone_scores = [s.get("tone_score") for s in syllables if isinstance(s.get("tone_score"), (int, float))]
        tone_avg = sum(tone_scores) / len(tone_scores) if tone_scores else 0
        phoneme_scores = [s.get("phoneme_score") for s in syllables if s.get("phoneme_score") is not None]
        phoneme_avg = sum(phoneme_scores) / len(phoneme_scores) if phoneme_scores else tone_avg
        result["hybrid_score"] = int(round(0.4 * text_score + 0.3 * phoneme_avg + 0.3 * tone_avg))
    else:
        result["hybrid_score"] = result.get("total_score", 0)

    return result


# --- Smart Speaker: RU -> (thai, phonetic) in Taika style ---

ARROWS = ("→", "↓", "↘", "↑", "↗")
# Верхняя граница разбора — предохранитель от разросшегося ответа модели, а не норма.
# Отсечка режет саму фразу, поэтому запас щедрый: клиент ограничивает ввод 12 русскими
# словами, а честное пословное деление тайского даёт заметно больше единиц, чем русский
# оригинал (артикли-классификаторы, разнесённые «ไม่ + เผ็ด», «ร้อน + มาก»).
MAX_WORDS = 32
# Иногда модель выдаёт ↕/↔ вместо одного из пяти тоновых знаков Taika — нормализуем в средний тон.
_PHONETIC_ARROW_FIXUPS = (
    ("↕", "→"),
    ("⇕", "→"),
    ("↔", "→"),
    ("⇅", "→"),
)


def _norm_ru(s: str) -> str:
    """Нормализация для поиска: lowercase, коллапс пробелов, убираем конечные ?!.,"""
    s = (s or "").strip().lower()
    s = re.sub(r"\s+", " ", s)
    s = re.sub(r"[?!.,;:\s]+$", "", s)  # trailing punctuation/spaces
    s = re.sub(r"^[?!.,;:\s]+", "", s)  # leading
    return s.strip()


def _steps_path() -> Path:
    # Allow override from environment; default to repo root steps.json
    env = (os.getenv("TAIKA_STEPS_JSON") or "").strip()
    if env:
        return Path(env).expanduser().resolve()
    # From api.py in scripts/thai_tone_assessment/ -> parent.parent.parent = repo root
    candidates = [
        Path(__file__).resolve().parent.parent.parent / "steps.json",
        Path.cwd() / "steps.json",
        Path.cwd() / ".." / "steps.json",
        Path.cwd() / ".." / ".." / "steps.json",
    ]
    for p in candidates:
        if p.resolve().is_file():
            return p.resolve()
    return candidates[0].resolve()


_CACHE: dict[str, tuple[str, str]] | None = None  # norm_ru -> (thai, phonetic)


def _load_steps_index() -> dict[str, tuple[str, str]]:
    global _CACHE
    if _CACHE is not None:
        return _CACHE
    sp = _steps_path()
    if not sp.is_file():
        print(f"[smart_speaker] steps.json not found at {sp}", file=sys.stderr, flush=True)
        _CACHE = {}
        return _CACHE
    data = json.loads(sp.read_text(encoding="utf-8"))
    idx: dict[str, tuple[str, str]] = {}
    for stepset in data.get("stepsets", []):
        for it in stepset.get("items", []):
            kind = (it.get("kind") or "").strip().lower()
            if kind not in ("word", "phrase", "casual"):
                continue
            ru = (it.get("ru") or "").strip()
            th = (it.get("thai") or "").strip()
            ph = (it.get("phonetic") or "").strip()
            if not ru or not th or not ph:
                continue
            # Only keep entries that are already "Taika style": at least one tone arrow present
            if not any(a in ph for a in ARROWS):
                continue
            idx.setdefault(_norm_ru(ru), (th, ph))
    _CACHE = idx
    return idx


# Trailing gender particle (ครับ/ค่ะ). LLM often adds its own; server owns the single final one.
_THAI_POLITENESS_TRAIL_RE = re.compile(r"\s*(ครับ|ค่ะ|คะ)\s*$")
# Any tone arrow (incl. typos) optional after stem. Longer stems first.
_PHONETIC_POLITENESS_TRAIL_RE = re.compile(
    r"(?i)\s*(?:кхрап|крап|кха)\s*[→↓↘↑↗↕↔⇕⇅]?\s*$"
)


def _strip_trailing_politeness(thai: str, phonetic: str) -> tuple[str, str]:
    """
    Убирает ВСЕ хвостовые ครับ/ค่ะ и кхрап/крап/кха (любая стрелка тона),
    чтобы _apply_politeness дописал ровно одну частицу по politeness.
    """
    th = (thai or "").strip()
    ph = (phonetic or "").strip()
    for _ in range(8):
        th2 = _THAI_POLITENESS_TRAIL_RE.sub("", th).strip()
        ph2 = _PHONETIC_POLITENESS_TRAIL_RE.sub("", ph).strip()
        if th2 == th and ph2 == ph:
            break
        th, ph = th2, ph2
    return th, ph


def _norm_politeness(politeness: str | None) -> str:
    p = (politeness or "female").strip().lower()
    return p if p in ("male", "female", "kathoey") else "female"


def _is_politeness_chunk(p: str) -> bool:
    return _part_key(p) in ("кхрап", "крап", "кха")


def _politeness_gloss_for_chunk(p: str) -> str:
    k = _part_key(p)
    if k in ("кхрап", "крап"):
        return "вежливость (м)"
    if k == "кха":
        return "вежливость (ж)"
    return "вежливость"


# Thai script range: U+0E00–U+0E7F (буквы тайского алфавита)
_THAI_SCRIPT_RE = re.compile(r"[\u0E00-\u0E7F]+")


def _strip_thai_from_phonetic(phonetic: str) -> str:
    """Убирает тайские символы из phonetic — поле должно быть только кириллица."""
    return _THAI_SCRIPT_RE.sub("", phonetic)


def _has_thai_script(s: str) -> bool:
    return bool(_THAI_SCRIPT_RE.search(s))


def _strip_thai_from_explanation(text: str) -> str:
    """
    Тайское письмо в объяснении для пользователя — мусор: он его не читает, всё тайское
    приходит к нему кириллицей. Вырезаем скрипт и подчищаем осиротевшую пунктуацию
    («слово ครับ — вежливость» → «слово — вежливость» → «слово — вежливость»).
    """
    if not _has_thai_script(text or ""):
        return text or ""
    out = _THAI_SCRIPT_RE.sub(" ", text)
    out = re.sub(r"\(\s*\)|\[\s*\]|«\s*»", " ", out)
    out = re.sub(r"\s+([,.;:!?])", r"\1", out)
    out = re.sub(r"([,;:])\s*(?=[,.;:])", "", out)
    out = re.sub(r"\s+", " ", out).strip(" -–—,;:")
    return out


_CONTRAST_SEPARATORS = ("нужно было", "а нужен", "а нужно", "а надо", "а не", "вместо")
_ADVICE_TOKEN_TRIM = ".,;:!?«»\"'()[]"


def _is_degenerate_advice(text: str) -> bool:
    """
    Совет, у которого обе стороны противопоставления совпадают: «используй май↗ вместо май↗».
    Ничему не учит и читается как поломка приложения.

    Возникает там, где два тайских слова различаются только тоном: кириллицей они пишутся
    одинаково, и без названия тона совет схлопывается. Стрелки здесь значимы —
    «май↘ вместо май↗» это нормальный, полезный совет.
    """
    t = (text or "").lower()
    if not t:
        return False
    for phrase in _CONTRAST_SEPARATORS[:-1]:
        t = t.replace(phrase, " вместо ")
    tokens = [w.strip(_ADVICE_TOKEN_TRIM) for w in t.split()]
    tokens = [w for w in tokens if w]
    for i, w in enumerate(tokens):
        if w != "вместо" or i == 0 or i + 1 >= len(tokens):
            continue
        if tokens[i - 1] == tokens[i + 1]:
            return True
    return False


def _first_sentence(text: str) -> str:
    m = re.search(r"^(.+?[.!?])(\s|$)", (text or "").strip())
    return (m.group(1) if m else (text or "")).strip()


def _cyrillic_letters_only(s: str) -> str:
    """Только буквы а-яё подряд (без пробелов), lower."""
    return "".join(re.findall(r"[а-яё]", (s or "").lower()))


def _phonetic_is_spelled_russian_source(ru: str, phonetic: str) -> bool:
    """
    LLM кладёт в phonetic русский исходник: по буквам (п→р→и) или по слогам (тво→я→пер→со→…).
    Тогда склейка букв совпадает с RU — это не тайская транскрипция.
    """
    ru_l = _cyrillic_letters_only(_norm_ru(ru))
    ph_l = _cyrillic_letters_only(phonetic)
    ph_l = re.sub(r"(кхрап|кха)+$", "", ph_l)
    if len(ru_l) < 4 or not ph_l:
        return False
    # Точное совпадение буквенного ряда (после удаления стрелок/пробелов)
    if ph_l == ru_l:
        return True
    # Очень похожие строки (слоги с дефисами/стрелками дают ту же склейку ± мелочь)
    if len(ph_l) >= len(ru_l) * 0.92:
        r = difflib.SequenceMatcher(None, ru_l, ph_l).ratio()
        if r >= 0.82:
            return True
    if len(ph_l) < len(ru_l) * 0.75:
        return False
    # ru — подпоследовательность ph; хвост после совпадения — не длиннее порога
    i = 0
    for c in ru_l:
        while i < len(ph_l) and ph_l[i] != c:
            i += 1
        if i >= len(ph_l):
            return False
        i += 1
    tail = len(ph_l) - i
    max_tail = max(12, len(ru_l) // 3)
    return tail <= max_tail


def _sanitize_phonetic_not_russian_spellout(ru: str, thai: str, phonetic: str) -> str:
    """Если phonetic — русский спеллаут, перегенерировать: сначала только по тайскому тексту."""
    ph = (phonetic or "").strip()
    if not ph or not _phonetic_is_spelled_russian_source(ru, ph):
        return ph
    print("[smart_speaker] phonetic mirrors Russian source; regenerating from Thai", file=sys.stderr, flush=True)
    if OPENAI_API_KEY:
        p1 = _llm_phonetic_from_thai_script(thai)
        if p1:
            p1n = _normalize_phonetic(p1)
            if p1n and not _phonetic_is_spelled_russian_source(ru, p1n):
                return p1n
        retried = _llm_translate_ru_to_th_retry(thai)
        if retried:
            _, p2 = retried
            p2n = _normalize_phonetic(p2)
            if p2n and not _phonetic_is_spelled_russian_source(ru, p2n):
                return p2n
    return ""


def _fix_latin_i_in_phonetic(phonetic: str) -> str:
    """Модель иногда пишет латинскую I/i вместо кириллической И/и; не трогаем i внутри лат. кластеров (mai и т.п.)."""
    out = phonetic.replace("I", "И")
    out = re.sub(r"(?<![A-Za-z])i(?![A-Za-z])", "и", out)
    return out


def _collapse_letter_space_arrow(phonetic: str) -> str:
    """LLM часто пишет «э ↗ п ↘» — схлопываем в «э↗ п↘» (как в Taika: буква сразу перед стрелкой)."""
    prev = None
    while prev != phonetic:
        prev = phonetic
        phonetic = re.sub(
            r"([а-яёА-ЯЁ·'\-])\s+([→↓↘↑↗])",
            r"\1\2",
            phonetic,
        )
    return phonetic


_IPA_REPLACEMENTS = (
    ("dʒ", "дж"), ("tʃ", "ч"),
    ("ū", "у"), ("ē", "е"), ("ā", "а"), ("ī", "и"), ("ō", "о"),
    ("í", "и"), ("ú", "у"), ("é", "е"), ("ó", "о"), ("á", "а"),
    ("ɛ", "е"), ("ɪ", "и"), ("ɔ", "о"), ("ʌ", "а"), ("ə", "э"),
    ("ʃ", "ш"), ("ʒ", "ж"), ("ŋ", "нг"), ("ɲ", "нь"),
    ("ʰ", ""), ("ʹ", ""), ("ʿ", ""), ("ʻ", ""), ("ˈ", ""), ("ˌ", ""),
)

# RTGS-подобная латиница иногда протекает в phonetic («ng», «khrap»). Раньше она проходила
# насквозь и ломала сравнение чанков (латинская g ≠ кириллическая г) — теперь транслитерируем.
_LATIN_TO_CYR = {
    "ng": "нг", "kh": "кх", "ph": "пх", "th": "тх", "ch": "ч", "dj": "дж",
    "aa": "а", "ee": "и", "ii": "и", "oo": "у", "uu": "у", "ae": "э", "oe": "ы",
    "ue": "ы", "eu": "ы", "ai": "ай", "ao": "ау", "aw": "о", "iu": "иу", "ua": "уа",
    "a": "а", "b": "б", "c": "к", "d": "д", "e": "е", "f": "ф", "g": "г", "h": "х",
    "i": "и", "j": "дж", "k": "к", "l": "л", "m": "м", "n": "н", "o": "о", "p": "п",
    "q": "к", "r": "р", "s": "с", "t": "т", "u": "у", "v": "в", "w": "в", "x": "кс",
    "y": "й", "z": "з",
}
_LATIN_RE = re.compile(
    "|".join(sorted((re.escape(k) for k in _LATIN_TO_CYR), key=len, reverse=True)),
    re.IGNORECASE,
)


def _latin_to_cyrillic_phonetic(s: str) -> str:
    """«ng» → «нг», «khrap» → «кхрап». Кириллица — единственный алфавит phonetic."""
    if not s or not re.search(r"[A-Za-z]", s):
        return s
    return _LATIN_RE.sub(lambda m: _LATIN_TO_CYR[m.group(0).lower()], s)


# Spoken digits in house phonetic. 3+ digit strings (1669, 555) are read one by one;
# 1–99 use Thai tens. Tones follow the course cards (нынг→, сип→, ий-сип→).
_TAIKA_DIGIT = (
    "сун→", "нынг→", "сонг→", "сам→", "си→",
    "ха→", "хок→", "чет→", "пэт→", "кау→",
)
_TAIKA_ONES_PLACE = (
    "сун→", "эт→", "сонг→", "сам→", "си→",
    "ха→", "хок→", "чет→", "пэт→", "кау→",
)
_TAIKA_TENS = {
    2: "ий-сип→",
    3: "сам→-сип→",
    4: "си→-сип→",
    5: "ха→-сип→",
    6: "хок→-сип→",
    7: "чет→-сип→",
    8: "пэт→-сип→",
    9: "кау→-сип→",
}
_ARROW_CLASS = "→↓↘↑↗"
_GLUE_AFTER_ARROW_RE = re.compile(
    # Хвост без собственной стрелки до конца слога. Lookahead обязан смотреть
    # дальше одной буквы: иначе «ру↑-сык↘» откатится к «ру↑-сы» + «к↘» → «русы↑к↘».
    rf"([а-яёА-ЯЁ-]+)([{_ARROW_CLASS}])(?:[\s-]*)([а-яёА-ЯЁ]+)(?![а-яёА-ЯЁ-]*[{_ARROW_CLASS}])"
)


def _int_to_taika(n: int) -> str:
    if n < 0:
        n = 0
    if n < 10:
        return _TAIKA_DIGIT[n]
    if n == 10:
        return "сип→"
    if n < 20:
        return "сип→-" + _TAIKA_ONES_PLACE[n - 10]
    if n < 100:
        tens, ones = divmod(n, 10)
        head = _TAIKA_TENS[tens]
        if ones == 0:
            return head
        return head + "-" + _TAIKA_ONES_PLACE[ones]
    return "-".join(_TAIKA_DIGIT[int(d)] for d in str(n))


def _expand_phonetic_digits(s: str) -> str:
    """
    Цифры в phonetic — дыра в контракте: ученик читает «90→», а не «кау→-сип→».
    «4x6» / «4кс6» (латинский x уже стал «кс») — размер фото, не слово «икс».
    """
    if not s or not re.search(r"\d", s):
        return s

    def times(m: re.Match[str]) -> str:
        return f"{_int_to_taika(int(m.group(1)))}-кху→-{_int_to_taika(int(m.group(2)))}"

    out = re.sub(r"(\d+)\s*[xх×]\s*(\d+)", times, s, flags=re.IGNORECASE)
    out = re.sub(r"(\d+)\s*кс\s*(\d+)", times, out)

    def num(m: re.Match[str]) -> str:
        raw = m.group(1)
        spoken = (
            "-".join(_TAIKA_DIGIT[int(d)] for d in raw)
            if len(raw) >= 3
            else _int_to_taika(int(raw))
        )
        return spoken

    # Стрелку, которую модель приклеила к числу («90→»), съедаем: у spoken свои.
    out = re.sub(rf"(\d+)[{_ARROW_CLASS}]?", num, out)
    return out


def _glue_letters_after_arrows(s: str) -> str:
    """
    หิว — один слог. Модель пишет «хи↘в» / «хи↘-в» / «хи↘ в», и тогда
    `_normalize_phonetic_word_spaces` делает из хвоста отдельное слово «в».
    Три чанка phonetic не сходятся с тайскими словами — разбор выкидывается.

    Не склеиваем, если у следующих букв уже есть своя стрелка: «хи↘ кхрап↘».
    Букву в конце слога после склейки поправляет `_house_w_coda`.
    """
    prev = None
    out = s or ""
    while prev != out:
        prev = out
        out = _GLUE_AFTER_ARROW_RE.sub(r"\1\3\2", out)
    return out


_HOUSE_W_CODA_RE = re.compile(
    rf"([аеёиоуыэюя])в(?=[{_ARROW_CLASS}\s-]|$)"
)
_HOUSE_IO_CODA_RE = re.compile(rf"ио(?=[{_ARROW_CLASS}\s-]|$)")
_HOUSE_YU_CODA_RE = re.compile(rf"ью(?=[{_ARROW_CLASS}\s-]|$)")


def _house_w_coda(s: str) -> str:
    """
    Конечная ว — гласный скольжения, в курсе это «у»: хиу, лэу, кхиу.
    Латиница w→в и royin «hio» дают хив / хио; «хью» — та же ошибка другим алфавитом.
    Начальная ว не трогаем: ว่า → ва.
    """
    out = _HOUSE_W_CODA_RE.sub(r"\1у", s or "")
    out = _HOUSE_IO_CODA_RE.sub("иу", out)
    out = _HOUSE_YU_CODA_RE.sub("иу", out)
    return out


def _shape_phonetic(s: str) -> str:
    """Общая зачистка: IPA, латиница, цифры, обрубки после стрелки. Границы слов не трогает."""
    out = _strip_thai_from_phonetic(s or "")
    for old, new in _IPA_REPLACEMENTS:
        out = out.replace(old, new)
    for bad, good in _PHONETIC_ARROW_FIXUPS:
        out = out.replace(bad, good)
    out = _fix_latin_i_in_phonetic(out)
    out = _latin_to_cyrillic_phonetic(out)
    out = re.sub(r"\s+", " ", out).strip()
    out = _expand_phonetic_digits(out)
    out = _glue_letters_after_arrows(out)
    out = _house_w_coda(out)
    out = _collapse_letter_space_arrow(out)
    return out


def _normalize_phonetic(phonetic: str) -> str:
    """Убирает IPA, латиницу в фонетике, тайский скрипт; оставляет кириллицу и стрелки →↓↘↑↗."""
    out = _shape_phonetic(phonetic)
    out = _normalize_phonetic_word_spaces(out)
    # word_spaces мог снова оторвать «↘-в» → «↘ в»; склеиваем повторно.
    out = _glue_letters_after_arrows(out)
    return _house_w_coda(out)


def _strip_arrows(s: str) -> str:
    out = s or ""
    for a in ARROWS + ("↕", "↔", "⇕", "⇅"):
        out = out.replace(a, "")
    return out.strip()


def _normalize_phonetic_token(raw: str) -> str:
    """
    Нормализация ОДНОГО слова: внутри слова пробелов быть не может — только дефисы,
    поэтому `_normalize_phonetic_word_spaces` (режет по стрелкам) здесь не применяется.
    Цифры раскрываем ДО вычистки non-Cyrillic, иначе «90→» превращалось в голую стрелку.
    """
    s = _strip_thai_from_phonetic(raw or "")
    # Скобочные пояснения («кхун (you)») — комментарий модели, а не звучание.
    s = re.sub(r"[(\[{][^)\]}]*[)\]}]", " ", s)
    s = _shape_phonetic(s)
    s = re.sub(r"[^а-яёА-ЯЁ→↓↘↑↗\s-]", "", s)
    s = re.sub(r"[\s-]*-[\s-]*", "-", s)
    s = re.sub(r"\s+", "-", s)
    s = re.sub(r"-{2,}", "-", s)
    s = s.strip("- ")
    return _house_w_coda(_glue_letters_after_arrows(s))


def _normalize_phonetic_line(phonetic: str) -> str:
    """
    Санитайз уже согласованной строки С СОХРАНЕНИЕМ границ слов.
    В отличие от `_normalize_phonetic`, не режет «ру↑-сык↘» по стрелке: там дефис —
    это стык слогов внутри одного тайского слова, а не граница слов.

    Сначала склеиваем обрубок после стрелки на всей строке: иначе «хи↘ в» — два токена
    и glue внутри токена его уже не достаёт.
    """
    shaped = _shape_phonetic(phonetic or "")
    tokens = [_normalize_phonetic_token(t) for t in shaped.split()]
    return " ".join(t for t in tokens if t)


def _normalize_phonetic_word_spaces(phonetic: str) -> str:
    """
    LLM often hyphenates EVERY syllable: «кун-ю↘-тхи↗-ни↘ кхрап↘».
    Teaching contract splits on spaces → that becomes ONE mega-chunk + politeness.
    After a tone arrow, a hyphen is a word boundary → turn into a space.
    Keeps in-word hyphens like «кун-ю» (no arrow between).
    """
    s = phonetic or ""
    for a in ARROWS + ("↕", "↔", "⇕"):
        s = s.replace(f"{a}-", f"{a} ")
        s = s.replace(f"{a} -", f"{a} ")
    return re.sub(r"\s+", " ", s).strip()


def _apply_politeness(thai: str, phonetic: str, politeness: str) -> tuple[str, str]:
    thai, phonetic = _strip_trailing_politeness(thai, phonetic)
    p = _norm_politeness(politeness)
    ph = phonetic.strip()
    if p == "male":
        th2 = (thai + " ครับ").strip()
        ph2 = (ph + " кхрап↘").strip() if ph else ""
        return th2, ph2
    # female + kathoey → ค่ะ
    th2 = (thai + " ค่ะ").strip()
    ph2 = (ph + " кха↘").strip() if ph else ""
    return th2, ph2


# Первое лицо. Сервер владеет местоимением так же, как частицей ครับ/ค่ะ:
# модель может написать любое, скрипт ставит ผม или ฉัน по politeness.
_I_THAI_MALE = "ผม"
_I_THAI_FEMALE = "ฉัน"
_I_PH_MALE = "пхом"
_I_PH_FEMALE = "чхан"
_I_PH_MALE_KEYS = frozenset({"пхом", "пхон"})
_I_PH_FEMALE_KEYS = frozenset({"чхан", "чан"})


def _speaker_i_thai(politeness: str | None) -> str:
    return _I_THAI_MALE if _norm_politeness(politeness) == "male" else _I_THAI_FEMALE


def _speaker_i_ph(politeness: str | None) -> str:
    return _I_PH_MALE if _norm_politeness(politeness) == "male" else _I_PH_FEMALE


def _last_tone_arrow(token: str) -> str:
    found = ""
    for ch in token or "":
        if ch in ARROWS or ch in "↕↔⇕⇅":
            found = ch if ch in ARROWS else "→"
    return found or "→"


def _force_i_ph_token(token: str, want_stem: str) -> str:
    return want_stem + _last_tone_arrow(token) if token else want_stem + "→"
    return want_stem + _last_tone_arrow(token) if token else want_stem + "→"


def _pronoun_slot_indexes(thai: str, pronoun: str) -> list[int]:
    """Индексы ฉัน/ผม в нарезке. Пусто — словарь недоступен или слово одно слипшееся."""
    bare, _ = _strip_trailing_politeness(_thai_bare(thai), "")
    if not bare or pronoun not in bare:
        return []
    tokens = ["".join(_THAI_SCRIPT_RE.findall(t)) for t in _thai_word_tokens(bare)]
    tokens = [t for t in tokens if t]
    if len(tokens) <= 1:
        return []
    return [i for i, t in enumerate(tokens) if t == pronoun]


def _apply_speaker_pronoun(
    thai: str,
    phonetic: str,
    parts: list[dict[str, str]] | None,
    politeness: str | None,
) -> tuple[str, str, list[dict[str, str]]]:
    """
    ฉัน ↔ ผม по полу спикера. Не трогает остальные слова.
    Фонетика и разбор переписываются вместе с тайским, иначе разъедутся.
    """
    want_th = _speaker_i_thai(politeness)
    want_ph = _speaker_i_ph(politeness)
    drop_th = _I_THAI_FEMALE if want_th == _I_THAI_MALE else _I_THAI_MALE
    from_keys = _I_PH_FEMALE_KEYS if want_th == _I_THAI_MALE else _I_PH_MALE_KEYS
    th_in = thai or ""
    out_parts = [dict(p) for p in (parts or []) if isinstance(p, dict)]
    if drop_th not in th_in:
        return th_in, phonetic or "", out_parts
    th = th_in.replace(drop_th, want_th)
    ph_tokens = (phonetic or "").split(" ") if phonetic else []
    idxs = _pronoun_slot_indexes(th_in, drop_th)
    if not idxs:
        for i, tok in enumerate(ph_tokens):
            if tok and _part_key(tok) in from_keys:
                idxs = [i]
                break
        if not idxs:
            for i, part in enumerate(out_parts):
                if _part_key(str(part.get("p") or "")) in from_keys:
                    idxs = [i]
                    break
    for i in idxs:
        if i < len(ph_tokens) and ph_tokens[i]:
            ph_tokens[i] = _force_i_ph_token(ph_tokens[i], want_ph)
        if i < len(out_parts):
            gloss = str(out_parts[i].get("m") or "я") or "я"
            out_parts[i] = {"p": want_ph, "m": gloss}
    ph = re.sub(r"\s+", " ", " ".join(ph_tokens)).strip()
    return th, ph, out_parts


class SmartSpeakerReq(BaseModel):
    text_ru: str
    politeness: str | None = "female"


class ThaiPhoneticReq(BaseModel):
    """Тайский текст (например с ASR) → кириллическая фонетика в стиле taikA (как в /smart_speaker)."""

    text_th: str


class SemanticCoachReq(BaseModel):
    expected_thai: str
    expected_ru: str = ""
    expected_phonetic: str = ""
    heard_thai: str = ""
    heard_phonetic: str = ""
    text_score: int = 0
    tone_score: int | None = None
    weak_syllables: list[dict[str, Any]] | None = None


class SemanticCoachResp(BaseModel):
    headline: str
    detail: str | None = None


# --- Smart Speaker: SQLite cache для переводов (экономия API-запросов) ---

# Bump this whenever the LLM system prompt changes meaning-affecting behavior:
# it namespaces cache keys so old (possibly wrong) cached translations become
# unreachable instead of being served forever via INSERT OR REPLACE.
# v8: пословный контракт (thai/phonetic/parts собираются из одного массива слов) —
# все записи v7 и раньше могли содержать обрезанный разбор, поэтому становятся недостижимыми.
# v9: одна строка разбора = одно словарное слово. Записи v8 могли склеивать
# самостоятельные слова («หูตลก — смешное ухо»), пряча слово от пользователя.
# v10: цифры в phonetic раскрываются в кириллицу; «хи↘ в» склеивается обратно в слог.
# Записи v9 с «90→» и пустым разбором из-за обрубка «в» становятся недостижимыми.
# v11: смысл, не только форма. «Будет дождь» → จะมี с มี=«дождь» больше не кэшируется.
# v12: перевод отделён от урока. Живой тайский (translate model) → нарезка/фонетика
# (mini) → судья смысла. Канон выживания бьёт модель. Старые one-prompt записи неверны.
# v13: границы слов задаёт словарь, не модель. Разбор больше не выкидывается целиком
# из-за рассинхрона чанков. Старые v12 с пустым parts или «чужим» gloss не годятся.
# v14: модель отдаёт одно поле за вызов (тайский / смысл / звучание).
# Местоимение я = ผม/ฉัน по politeness, как частица ครับ/ค่ะ. Старые v13 с чужим ฉัน у male не годятся.
_SMART_CACHE_PROMPT_VERSION = "v14"


def _cache_db_path() -> Path:
    env = (os.getenv("TAIKA_SMART_CACHE_DB") or "").strip()
    if env:
        return Path(env).expanduser().resolve()
    return (Path(__file__).resolve().parent / "smart_speaker_cache.db").resolve()


def _init_cache_db() -> None:
    path = _cache_db_path()
    with sqlite3.connect(path) as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS translations (
                text_ru_norm TEXT NOT NULL,
                politeness TEXT NOT NULL,
                thai TEXT NOT NULL,
                phonetic TEXT NOT NULL,
                parts_json TEXT NOT NULL DEFAULT '[]',
                created_at INTEGER DEFAULT (strftime('%s', 'now')),
                PRIMARY KEY (text_ru_norm, politeness)
            )
        """)
        cols = {r[1] for r in conn.execute("PRAGMA table_info(translations)").fetchall()}
        if "parts_json" not in cols:
            conn.execute("ALTER TABLE translations ADD COLUMN parts_json TEXT NOT NULL DEFAULT '[]'")
        conn.commit()


def _spoken_canon_hit(ru_norm: str) -> tuple[str, str, list[dict[str, str]]] | None:
    try:
        from spoken_canon import lookup as canon_lookup
    except Exception as e:  # noqa: BLE001
        print(f"[smart_speaker] canon import failed: {e}", file=sys.stderr, flush=True)
        return None
    hit = canon_lookup(ru_norm)
    if not hit:
        return None
    thai = str(hit.get("thai") or "").strip()
    phonetic = str(hit.get("phonetic") or "").strip()
    parts_raw = hit.get("parts") if isinstance(hit.get("parts"), list) else []
    parts = _normalize_parts(parts_raw)
    if not thai or not phonetic:
        return None
    return thai, phonetic, parts


def _cache_key(text_ru_norm: str) -> str:
    """Namespaces the cache key with the prompt version — see _SMART_CACHE_PROMPT_VERSION."""
    return f"{_SMART_CACHE_PROMPT_VERSION}:{text_ru_norm}"


def _cache_get(text_ru_norm: str, politeness: str) -> tuple[str, str, list[dict[str, str]]] | None:
    p = _norm_politeness(politeness)
    try:
        with sqlite3.connect(_cache_db_path()) as conn:
            row = conn.execute(
                "SELECT thai, phonetic, parts_json FROM translations WHERE text_ru_norm = ? AND politeness = ?",
                (_cache_key(text_ru_norm), p),
            ).fetchone()
            if row:
                return (row[0], row[1], _parse_parts_json(row[2] if len(row) > 2 else "[]"))
    except Exception as e:
        print(f"[smart_speaker] cache get error: {e}", file=sys.stderr, flush=True)
    return None


def _cache_set(
    text_ru_norm: str,
    politeness: str,
    thai: str,
    phonetic: str,
    parts: list[dict[str, str]] | None = None,
) -> None:
    p = _norm_politeness(politeness)
    ready = [x for x in (parts or []) if x.get("p") and x.get("m")]
    if not thai or not phonetic or not ready or not _parts_match_phonetic(phonetic, ready):
        return
    parts_json = json.dumps(ready, ensure_ascii=False)
    try:
        with sqlite3.connect(_cache_db_path()) as conn:
            conn.execute(
                "INSERT OR REPLACE INTO translations "
                "(text_ru_norm, politeness, thai, phonetic, parts_json) VALUES (?, ?, ?, ?, ?)",
                (_cache_key(text_ru_norm), p, thai, phonetic, parts_json),
            )
            conn.commit()
    except Exception as e:
        print(f"[smart_speaker] cache set error: {e}", file=sys.stderr, flush=True)


def _parse_parts_json(raw: Any) -> list[dict[str, str]]:
    if isinstance(raw, list):
        return _normalize_parts(raw)
    if not isinstance(raw, str) or not raw.strip():
        return []
    try:
        data = json.loads(raw)
    except Exception:
        return []
    return _normalize_parts(data if isinstance(data, list) else [])


def _normalize_parts(raw: list[Any]) -> list[dict[str, str]]:
    """Teaching chunks: [{p, m}] — Cyrillic chunk + short Russian gloss."""
    out: list[dict[str, str]] = []
    for item in raw:
        if not isinstance(item, dict):
            continue
        p = str(item.get("p") or item.get("phonetic") or "").strip()
        m = str(item.get("m") or item.get("meaning") or item.get("ru") or "").strip()
        if not p or not m:
            continue
        # Drop tone arrows from teaching chunk (tones live in full phonetic line).
        for a in ARROWS:
            p = p.replace(a, "")
        p = re.sub(r"\s+", " ", p).strip(" -–—")
        # Значение читает пользователь, который тайскую графику не знает: «ครับ — вежливость»
        # для него начинается с непонятного квадратика. Оставляем только русский текст.
        m = _strip_thai_from_explanation(m)
        m = re.sub(r"\s+", " ", m).strip()
        if not p or not m:
            continue
        if _has_thai_script(p):
            continue
        out.append({"p": p, "m": m})
        if len(out) >= MAX_WORDS:
            break
    return out


def _phonetic_word_groups(phonetic: str) -> list[str]:
    """Same chunks the app shows in «КАК СКАЗАТЬ»: arrows off, split on spaces."""
    s = (phonetic or "").strip().lower()
    s = s.replace("ɨ", "и").replace("і", "и")
    for a in ARROWS + ("↕", "↔", "⇕"):
        s = s.replace(a, "")
    s = s.replace("—", "-").replace("–", "-")
    s = re.sub(r"\s+", " ", s).strip()
    return [g for g in s.split(" ") if g]


def _part_key(p: str) -> str:
    s = (p or "").strip().lower()
    s = s.replace("ɨ", "и").replace("і", "и")
    for a in ARROWS + ("↕", "↔", "⇕"):
        s = s.replace(a, "")
    return re.sub(r"[-\s]", "", s)


def _is_weak_gloss(m: str) -> bool:
    t = re.sub(r"\s+", " ", (m or "").strip())
    if not t or t in ("…", "часть слова", "слово"):
        return True
    letters = re.sub(r"[^а-яёa-z]+", "", t.lower(), flags=re.IGNORECASE)
    if len(letters) <= 1:
        # «я» / «и» / «а» — нормальные значения слов, не обрубок. Иначе
        # «Я хочу есть» срывалось с пословного пути (ฉัน → «я») на legacy,
        # где หิว резалось на «хи↘ в» и разбор пропадал.
        if letters in {"я", "и", "а"}:
            return False
        return True
    if re.fullmatch(r"[вукс]\s*/\s*[вукс]", t.lower()):
        return True
    return False


def _gloss_key(s: str) -> str:
    t = re.sub(r"\s+", " ", (s or "").strip().lower())
    t = re.sub(r"[?!.,;:«»\"']+", "", t)
    return t.strip()


def _is_whole_phrase_gloss(m: str, ru: str) -> bool:
    """True when m dumps the full Russian sentence onto one chunk (useless for teaching)."""
    mk = _gloss_key(m)
    rk = _gloss_key(ru)
    if not mk or not rk or len(rk) < 3:
        return False
    if mk == rk:
        return True
    # «Ты здесь.» / «ты здесь» / contains full RU as the whole gloss
    if rk in mk and len(mk) <= len(rk) + 4:
        return True
    return False


# Служебные тайские слова: грамматика, не носители русских существительных.
# ไป/มา/ได้ нарочно не здесь — это полноценные глаголы.
_THAI_FUNCTION_WORDS = frozenset({
    "จะ", "มี", "เป็น", "ไม่", "และ", "หรือ", "แต่", "ก็",
    "ที่", "ของ", "ใน", "กับ", "นะ", "ไหม", "มั้ย",
    "เลย", "ว่า", "ยัง", "ด้วย", "แล้ว",
    "ครับ", "ค่ะ", "คะ",
})

# Допустимый gloss служебного слова. Существительное («дождь», «кофе») сюда не входит.
_FUNCTION_GLOSS_OK = frozenset({
    "будет", "буду", "будем", "будешь", "будут", "чтобы", "собираюсь", "будущее",
    "есть", "имеется", "иметь", "наличие",
    "являться", "является", "быть", "это",
    "не", "нет",
    "уже", "еще", "тогда",
    "и", "или", "но", "а",
    "вопрос", "ли", "разве",
    "который", "которая", "которые", "что",
    "в", "на", "у", "с", "из", "для", "к", "по",
    "этот", "эта", "то", "там", "тут",
    "тоже", "связка", "частица",
    "вежливость", "смягчение", "мягко",
})

_RU_FUNCTION_WORDS = frozenset({
    "я", "ты", "вы", "он", "она", "оно", "мы", "они",
    "меня", "мне", "тебе", "вам", "его", "ее", "их", "нас",
    "мой", "твой", "ваш", "наш", "моя", "твоя", "ваши",
    "это", "этот", "эта", "эти", "тот", "та", "те",
    "будет", "буду", "будем", "будешь", "будут", "было", "была", "были", "быть", "есть",
    "не", "ни", "нет", "да", "и", "а", "но", "или", "что", "чтобы", "если",
    "в", "на", "с", "со", "у", "к", "ко", "по", "из", "за", "для", "от", "до", "о", "об", "про", "при",
    "же", "ли", "бы", "вот", "вон", "ну", "уже", "еще", "очень", "просто", "там", "тут", "здесь",
    "как", "так", "то", "все", "можно", "надо", "нужно",
    "пожалуйста",
})
_RU_TOKEN_RE = re.compile(r"[а-яё]+", re.IGNORECASE)


def _gloss_is_function_ok(m: str) -> bool:
    key = _gloss_key(m).replace("ё", "е")
    if not key:
        return False
    if key in _FUNCTION_GLOSS_OK:
        return True
    core = re.sub(r"\([^)]*\)", "", key).strip()
    if core in _FUNCTION_GLOSS_OK:
        return True
    chunks = [c.strip() for c in re.split(r"[/,;]+", key) if c.strip()]
    if chunks and all(c in _FUNCTION_GLOSS_OK or c in {"м", "ж"} for c in chunks):
        return True
    return False


def _ru_content_tokens(ru: str) -> list[str]:
    out: list[str] = []
    for tok in _RU_TOKEN_RE.findall((ru or "").lower().replace("ё", "е")):
        if len(tok) < 3:
            continue
        if tok in _RU_FUNCTION_WORDS:
            continue
        out.append(tok)
    return out


def _thai_bare(thai: str) -> str:
    th, _ = _strip_trailing_politeness(thai or "", "")
    return th


def _split_function_run(th: str) -> list[str] | None:
    """Если строка — склейка служебных слов (จะมี), вернуть эти слова. Иначе None."""
    s = (th or "").strip()
    if not s:
        return None
    if s in _THAI_FUNCTION_WORDS:
        return [s]
    funcs = sorted(_THAI_FUNCTION_WORDS, key=len, reverse=True)
    out: list[str] = []
    rest = s
    while rest:
        hit = next((f for f in funcs if rest.startswith(f)), None)
        if not hit:
            return None
        out.append(hit)
        rest = rest[len(hit):]
    return out or None


def _thai_is_function_only(th: str) -> bool:
    s = (th or "").strip()
    if not s:
        return False
    if s in _THAI_FUNCTION_WORDS:
        return True
    tokens = _thai_word_tokens(s)
    if tokens and all(t in _THAI_FUNCTION_WORDS for t in tokens):
        return True
    return _split_function_run(s) is not None


def _thai_content_tokens(thai: str) -> list[str]:
    bare = _thai_bare(thai)
    tokens = [t for t in _thai_word_tokens(bare) if t]
    if not tokens or (len(tokens) == 1 and tokens[0] == bare and _split_function_run(bare)):
        return []
    return [t for t in tokens if t not in _THAI_FUNCTION_WORDS]


def _meaning_problems(ru: str, words: list[dict[str, str]]) -> list[str]:
    """
    Смысловой инвариант пословного пути.
    Служебное слово не носит русское существительное (มี ≠ «дождь»).
    Если в русском есть знаменательные слова, в тайском должно быть хотя бы одно неслужебное.
    """
    problems: list[str] = []
    for i, w in enumerate(words):
        th = (w.get("th") or "").strip()
        m = (w.get("m") or "").strip()
        if not th or _THAI_POLITENESS_TRAIL_RE.fullmatch(th):
            continue
        if _thai_is_function_only(th) and m and not _gloss_is_function_ok(m):
            problems.append(
                f"word[{i}] '{th}' is a grammar word; \"m\" {m!r} is content. "
                "Gloss it as будет/есть/не and add a separate Thai word for that noun "
                "(ฝน for дождь, กาแฟ for кофе, ห้องน้ำ for туалет, บิล for счёт)."
            )
    joined = "".join((w.get("th") or "").strip() for w in words)
    missing = _ru_content_tokens(ru)
    if missing and joined and not _thai_content_tokens(joined):
        problems.append(
            "Thai is only grammar words (จะ/มี/เป็น/ไม่). Russian content is missing from Thai: "
            + ", ".join(missing[:6])
            + ". Add the real content word."
        )
    return problems


def _dropped_content_problems(ru: str, thai: str) -> list[str]:
    """Финальная сетка перед кэшем/ответом — в том числе для legacy-пути."""
    if not _ru_content_tokens(ru):
        return []
    if _thai_content_tokens(thai):
        return []
    missing = ", ".join(_ru_content_tokens(ru)[:6])
    return [
        "Thai is only grammar words; Russian content dropped: " + missing
    ]


def _align_parts_to_phonetic(parts: list[dict[str, str]], phonetic: str) -> list[dict[str, str]]:
    """Universal contract: one gloss per phonetic space-chunk. Drop leftovers."""
    groups = _phonetic_word_groups(phonetic)
    if not groups:
        return parts
    unused = [p for p in parts if p.get("p") and p.get("m")]
    out: list[dict[str, str]] = []
    for g in groups:
        gk = _part_key(g)
        if not gk:
            continue
        idx = next((i for i, it in enumerate(unused) if _part_key(it.get("p", "")) == gk), None)
        if idx is not None:
            m = str(unused.pop(idx).get("m") or "").strip()
            if m and not _is_weak_gloss(m):
                out.append({"p": g, "m": m})
            continue
        acc = ""
        take: list[int] = []
        for i, it in enumerate(unused):
            k = _part_key(it.get("p", ""))
            if not k:
                continue
            nxt = acc + k
            if gk.startswith(nxt):
                acc = nxt
                take.append(i)
                if acc == gk:
                    break
            elif not acc:
                continue
            else:
                break
        if acc == gk and take:
            meanings = [str(unused[i].get("m") or "").strip() for i in take]
            m = next((x for x in meanings if x and not _is_weak_gloss(x)), "")
            for i in reversed(take):
                unused.pop(i)
            if m:
                out.append({"p": g, "m": m})
    return out


def _finalize_parts(
    ru: str,
    thai: str,
    phonetic: str,
    parts: list[dict[str, str]],
    preserve_word_boundaries: bool = False,
) -> list[dict[str, str]]:
    """
    `preserve_word_boundaries=True` — строка уже канонична (пришла от клиента или из
    пословного контракта), и дефис в ней это стык слогов внутри слова. Резать её по
    «стрелка-дефис» нельзя: «са-баи→-ди→» развалится на два слова и разбор разъедется.
    """
    ph = phonetic.strip() if preserve_word_boundaries else _normalize_phonetic_word_spaces(phonetic)
    groups = _phonetic_word_groups(ph)
    aligned = _align_parts_to_phonetic(parts, ph)

    if groups and len(groups) > 1:
        aligned = [p for p in aligned if not _is_whole_phrase_gloss(str(p.get("m") or ""), ru)]

    if groups and len(aligned) < len(groups):
        filled = _llm_phrase_parts(ru, thai, ph) or []
        realigned = _align_parts_to_phonetic(filled + aligned, ph)
        if len(groups) > 1:
            realigned = [p for p in realigned if not _is_whole_phrase_gloss(str(p.get("m") or ""), ru)]
        if len(realigned) >= len(aligned):
            aligned = realigned

    # Canonical gloss for the single trailing gender particle (server-owned).
    if aligned and _is_politeness_chunk(str(aligned[-1].get("p") or "")):
        aligned[-1] = {
            "p": aligned[-1]["p"],
            "m": _politeness_gloss_for_chunk(aligned[-1]["p"]),
        }

    return aligned


# Инициализация при импорте
_init_cache_db()
try:
    from gift import init_gift_db

    init_gift_db()
except Exception as e:  # noqa: BLE001
    print(f"[gift] db init skipped: {e}", file=sys.stderr, flush=True)

OPENAI_API_KEY = (os.getenv("OPENAI_API_KEY") or "").strip()
OPENAI_MODEL = (os.getenv("TAIKA_SMART_MODEL") or "gpt-4o-mini").strip()
OPENAI_TRANSLATE_MODEL = (os.getenv("TAIKA_TRANSLATE_MODEL") or "gpt-4o").strip()
OPENAI_CHAT_URL = "https://api.openai.com/v1/chat/completions"


def _openai_chat_json(
    *,
    system: str,
    user: str,
    temperature: float,
    timeout: float,
    schema: dict[str, Any] | None = None,
    tag: str = "smart_speaker",
    model: str | None = None,
) -> dict[str, Any] | None:
    """
    Один вход для всех LLM-вызовов. Пробует Structured Outputs (strict json_schema);
    если аккаунт/модель их не принимает — откатывается на json_object, а не падает.
    """
    if not OPENAI_API_KEY:
        return None
    body: dict[str, Any] = {
        "model": (model or OPENAI_MODEL),
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        "temperature": temperature,
    }
    formats: list[dict[str, Any]] = []
    if schema:
        formats.append({"type": "json_schema", "json_schema": schema})
    formats.append({"type": "json_object"})

    for fmt in formats:
        body["response_format"] = fmt
        try:
            resp = requests.post(
                OPENAI_CHAT_URL,
                headers={
                    "Authorization": f"Bearer {OPENAI_API_KEY}",
                    "Content-Type": "application/json",
                },
                json=body,
                timeout=timeout,
            )
        except Exception as e:  # pragma: no cover - network errors
            print(f"[{tag}] openai request failed: {e}", file=sys.stderr, flush=True)
            return None
        if resp.status_code == 400 and fmt.get("type") == "json_schema":
            print(f"[{tag}] json_schema rejected, falling back to json_object", file=sys.stderr, flush=True)
            continue
        if resp.status_code >= 300:
            print(f"[{tag}] openai http {resp.status_code}: {resp.text[:200]}", file=sys.stderr, flush=True)
            return None
        try:
            content = resp.json()["choices"][0]["message"]["content"]
            data = json.loads(content)
            return data if isinstance(data, dict) else None
        except Exception as e:  # pragma: no cover - defensive
            print(f"[{tag}] parse error: {e}", file=sys.stderr, flush=True)
            return None
    return None


# --- Word-level contract -------------------------------------------------
#
# Раньше модель писала `phonetic` строкой, а `parts` — отдельным списком, и сервер сверял
# их сравнением строк. Любое расхождение (лишний дефис, латинская буква) молча убивало разбор.
# Теперь модель отдаёт СЛОВА, а `thai` / `phonetic` / `parts` собираются из одного массива —
# рассинхрон невозможен by construction.

_WORDS_SCHEMA: dict[str, Any] = {
    "name": "thai_words",
    "strict": True,
    "schema": {
        "type": "object",
        "additionalProperties": False,
        "required": ["words"],
        "properties": {
            "words": {
                "type": "array",
                "items": {
                    "type": "object",
                    "additionalProperties": False,
                    "required": ["th"],
                    "properties": {
                        "th": {"type": "string", "description": "One Thai word, Thai script only"},
                    },
                },
            }
        },
    },
}

_MEANINGS_SCHEMA: dict[str, Any] = {
    "name": "thai_slot_meanings",
    "strict": True,
    "schema": {
        "type": "object",
        "additionalProperties": False,
        "required": ["meanings"],
        "properties": {
            "meanings": {
                "type": "array",
                "items": {"type": "string", "description": "Russian meaning of that numbered Thai word"},
            }
        },
    },
}

_PHONETICS_SCHEMA: dict[str, Any] = {
    "name": "thai_slot_phonetics",
    "strict": True,
    "schema": {
        "type": "object",
        "additionalProperties": False,
        "required": ["phonetics"],
        "properties": {
            "phonetics": {
                "type": "array",
                "items": {"type": "string", "description": "Cyrillic pronunciation of that numbered Thai word + tone arrows"},
            }
        },
    },
}

_GLOSS_FIX_SCHEMA: dict[str, Any] = {
    "name": "gloss_fix",
    "strict": True,
    "schema": {
        "type": "object",
        "additionalProperties": False,
        "required": ["fixes"],
        "properties": {
            "fixes": {
                "type": "array",
                "items": {
                    "type": "object",
                    "additionalProperties": False,
                    "required": ["i", "m"],
                    "properties": {
                        "i": {"type": "integer"},
                        "m": {"type": "string"},
                    },
                },
            }
        },
    },
}

_THAI_ONLY_SCHEMA: dict[str, Any] = {
    "name": "spoken_thai",
    "strict": True,
    "schema": {
        "type": "object",
        "additionalProperties": False,
        "required": ["thai"],
        "properties": {
            "thai": {"type": "string", "description": "One spoken Thai sentence, Thai script only"},
        },
    },
}

_JUDGE_SCHEMA: dict[str, Any] = {
    "name": "meaning_judge",
    "strict": True,
    "schema": {
        "type": "object",
        "additionalProperties": False,
        "required": ["ok", "missing"],
        "properties": {
            "ok": {"type": "boolean"},
            "missing": {
                "type": "array",
                "items": {"type": "string"},
            },
        },
    },
}


def _clean_words(raw: Any) -> list[dict[str, str]]:
    """Санитайз массива слов: тайский скрипт в th, кириллица+стрелки в ph, чистый gloss в m."""
    if not isinstance(raw, list):
        return []
    out: list[dict[str, str]] = []
    for item in raw:
        if not isinstance(item, dict):
            continue
        th = "".join(_THAI_SCRIPT_RE.findall(str(item.get("th") or "")))
        ph = _normalize_phonetic_token(str(item.get("ph") or ""))
        # Значение читает пользователь, тайскую графику он не знает. Пословный путь
        # собирает parts напрямую, минуя `_normalize_parts`, поэтому чистим здесь.
        # Если после чистки не осталось смысла — `_validate_words` увидит пустое «m»
        # и отправит ответ в ремонтный проход.
        m = _strip_thai_from_explanation(str(item.get("m") or ""))
        m = re.sub(r"\s+", " ", m).strip()
        if not th and not ph:
            continue
        # Частицу вежливости добавляет сервер. Опознаём её по тайскому написанию, а не по
        # звучанию: ขา («нога») тоже читается «кха», и по фонетике его срезало бы зря.
        if th:
            if _THAI_POLITENESS_TRAIL_RE.fullmatch(th):
                continue
        elif _is_politeness_chunk(ph):
            continue
        out.append({"th": th, "ph": ph, "m": m})
        if len(out) >= MAX_WORDS:
            # Обрезка укорачивает и саму фразу, не только разбор — это не рядовое
            # событие, а сигнал, что предохранитель сработал по живому вводу.
            if len(raw) > MAX_WORDS:
                print(
                    f"[smart_speaker.words] hit MAX_WORDS={MAX_WORDS}, dropped {len(raw) - MAX_WORDS} words",
                    file=sys.stderr,
                    flush=True,
                )
            break
    return out


@functools.lru_cache(maxsize=4096)
def _thai_word_tokens(th: str) -> tuple[str, ...]:
    """
    Границы слов по словарю newmm. Ошибка или отсутствие PyThaiNLP — не повод ронять
    перевод: возвращаем строку одним токеном, и проверка склейки просто молчит.
    """
    s = (th or "").strip()
    if not s:
        return ()
    try:
        from pythainlp.tokenize import word_tokenize

        tokens = [t for t in word_tokenize(s, engine="newmm", keep_whitespace=False) if t.strip()]
    except Exception as e:  # noqa: BLE001 — словарь опционален, деградируем молча
        print(f"[smart_speaker.words] thai tokenizer unavailable: {e}", file=sys.stderr, flush=True)
        return (s,)
    return tuple(tokens) or (s,)


def _tokenizer_is_live() -> bool:
    probe = _thai_word_tokens("ฝนจะตก")
    return probe != ("ฝนจะตก",)


def _thai_lesson_slots(thai: str) -> list[str]:
    """
    Слова урока задаёт словарь, не модель. Модель потом только пишет звучание
    и русское значение в эти слоты. Поэтому разбор не может «не сойтись» с фонетикой:
    обе строки собираются из того же списка.
    """
    bare, _ = _strip_trailing_politeness(_thai_bare(thai), "")
    if not bare:
        return []
    out: list[str] = []
    for t in _thai_word_tokens(bare):
        piece = "".join(_THAI_SCRIPT_RE.findall(t))
        if not piece or _THAI_POLITENESS_TRAIL_RE.fullmatch(piece):
            continue
        out.append(piece)
        if len(out) >= MAX_WORDS:
            break
    return out


def _apply_slots(slots: list[str], filled: list[Any]) -> list[dict[str, str]]:
    """th всегда из словаря. ph/m — из ответа модели по индексу."""
    out: list[dict[str, str]] = []
    for i, th in enumerate(slots):
        item = filled[i] if i < len(filled) and isinstance(filled[i], dict) else {}
        ph = _normalize_phonetic_token(str(item.get("ph") or ""))
        m = _strip_thai_from_explanation(str(item.get("m") or ""))
        m = re.sub(r"\s+", " ", m).strip()
        out.append({"th": th, "ph": ph, "m": m})
    return out


def _segmentation_problems(words: list[dict[str, str]]) -> list[str]:
    """
    Ловит склейку самостоятельных слов в одну строку разбора: «หูตลก — смешное ухо»
    вместо «หู — ухо» + «ตลก — смешной». Формально такой ответ согласован и проходит
    все остальные инварианты, но слово прячется от пользователя — в следующей фразе
    он «ху» уже не узнает, а ради узнавания слов он приложением и пользуется.

    Границу слова определяет словарь, а не длина строки: настоящие сращения
    (สบายดี, อย่างไร, น้ำแข็ง, โรงพยาบาล) словарь держит одним токеном, а свободные
    сочетания (หู+ตลก, ผู้หญิง+สวย, ร้อน+มาก) разбирает на части.
    """
    problems: list[str] = []
    for i, w in enumerate(words):
        th = (w.get("th") or "").strip()
        if not th:
            continue
        tokens = _thai_word_tokens(th)
        if len(tokens) > 1:
            problems.append(
                f"word[{i}] '{th}' is {len(tokens)} separate Thai words ({' + '.join(tokens)}): "
                "split it into one entry per word, each with its own \"ph\" and \"m\""
            )
    return problems


def _validate_words(ru: str, words: list[dict[str, str]]) -> list[str]:
    """Инварианты ответа. Пустой список = ответ пригоден к показу."""
    if not words:
        return ["empty words array"]
    problems: list[str] = []
    multi = len(words) > 1
    for i, w in enumerate(words):
        th, ph, m = w.get("th", ""), w.get("ph", ""), w.get("m", "")
        if not th:
            problems.append(f"word[{i}]: 'th' is empty or not Thai script")
        if not ph:
            problems.append(f"word[{i}]: 'ph' is empty")
        elif not re.search(r"[а-яё]", ph, re.IGNORECASE):
            problems.append(f"word[{i}] '{th}': 'ph' has no Cyrillic letters")
        elif re.search(r"\d", ph):
            problems.append(f"word[{i}] '{th}': 'ph' still has digits — write the spoken form")
        elif not any(a in ph for a in ARROWS):
            problems.append(f"word[{i}] '{th}': 'ph' has no tone arrow (a leftover letter is not a word)")
        if not m:
            problems.append(f"word[{i}] '{th}': 'm' is empty")
        elif _is_weak_gloss(m):
            problems.append(f"word[{i}] '{th}': 'm' is too vague ({m!r})")
        elif multi and _is_whole_phrase_gloss(m, ru):
            problems.append(f"word[{i}] '{th}': 'm' repeats the whole sentence instead of this word")
    if not any(any(a in w.get("ph", "") for a in ARROWS) for w in words):
        problems.append("no tone arrows anywhere in 'ph'")
    problems.extend(_meaning_problems(ru, words))
    return problems


def _words_to_outputs(words: list[dict[str, str]]) -> tuple[str, str, list[dict[str, str]]]:
    """Единственное место, где рождаются thai / phonetic / parts — из одного массива."""
    usable = [w for w in words if w.get("th") and w.get("ph") and w.get("m")]
    thai = "".join(w["th"] for w in usable)
    phonetic = " ".join(w["ph"] for w in usable)
    parts = [{"p": _strip_arrows(w["ph"]), "m": w["m"]} for w in usable]
    return thai, phonetic, parts


def _politeness_part(politeness: str) -> dict[str, str]:
    if _norm_politeness(politeness) == "male":
        return {"p": "кхрап", "m": "вежливость (м)"}
    return {"p": "кха", "m": "вежливость (ж)"}


def _append_politeness(thai: str, phonetic: str, politeness: str) -> tuple[str, str]:
    """
    Версия `_apply_politeness` без предварительной зачистки хвоста: на пословном пути
    частицы в ответе модели уже отсеяны по тайскому написанию, а слепое срезание
    «кха» из фонетики съело бы обычное слово вроде ขา.
    """
    if _norm_politeness(politeness) == "male":
        return (thai + " ครับ").strip(), (phonetic + " кхрап↘").strip()
    return (thai + " ค่ะ").strip(), (phonetic + " кха↘").strip()


def _parts_match_phonetic(phonetic: str, parts: list[dict[str, str]]) -> bool:
    """Главный инвариант выдачи: один gloss на каждое слово фонетики, в том же порядке."""
    groups = _phonetic_word_groups(phonetic)
    if len(groups) != len(parts):
        return False
    return all(_part_key(g) == _part_key(p.get("p", "")) for g, p in zip(groups, parts))


def _aligned_parts_only(phonetic: str, parts: list[dict[str, str]], where: str) -> list[dict[str, str]]:
    """
    Рассогласованный разбор не выкидываем целиком: оставляем строки, которые
    сели на чанки фонетики. Пустой список — только если садиться нечему.
    """
    if not parts:
        return []
    if _parts_match_phonetic(phonetic, parts):
        return parts
    aligned = _align_parts_to_phonetic(parts, phonetic)
    if _parts_match_phonetic(phonetic, aligned):
        return aligned
    print(
        f"[smart_speaker] partial parts ({where}): {len(aligned)} aligned / "
        f"{len(_phonetic_word_groups(phonetic))} phonetic chunks "
        f"(from {len(parts)} raw)",
        file=sys.stderr,
        flush=True,
    )
    return aligned


def _compact_thai(s: str) -> str:
    return re.sub(r"\s+", "", _thai_bare(s or ""))


def _words_follow_locked_thai(words: list[dict[str, str]], locked: str) -> list[str]:
    got = _compact_thai("".join((w.get("th") or "") for w in words))
    want = _compact_thai(locked)
    if not want:
        return ["locked Thai is empty"]
    if got != want:
        return [
            f"split must keep the given Thai {want!r}; do not retranslate to {got!r}"
        ]
    return []


def _words_system_prompt(politeness: str, problems: list[str] | None) -> str:
    p = _norm_politeness(politeness)
    particle = "ครับ / кхрап" if p == "male" else "ค่ะ / кха"
    base = (
        "The Thai sentence is FIXED. Do not translate it. Do not add or drop words.\n"
        "Split THAT Thai into dictionary words. Return JSON {\"words\":[{\"th\":\"...\"},...]}.\n"
        "Concatenating every th MUST equal the given Thai.\n"
        "One entry = one Thai dictionary word. Keep real compounds as one: "
        "สบายดี, อย่างไร, น้ำแข็ง, โรงพยาบาล, ขอบคุณ, ห้องน้ำ.\n"
        f"Do not output {particle} — the server appends it.\n"
        "Example: ฝนจะตก → {\"words\":[{\"th\":\"ฝน\"},{\"th\":\"จะ\"},{\"th\":\"ตก\"}]}"
    )
    if problems:
        base += (
            "\n\nPrevious split was REJECTED. Fix these and return the whole array:\n"
            + "\n".join(f"- {p}" for p in problems[:8])
        )
    return base


def _llm_split_thai_to_words(
    ru: str,
    thai: str,
    politeness: str | None,
    problems: list[str] | None = None,
    timeout: float = 8.0,
) -> list[dict[str, str]] | None:
    p = _norm_politeness(politeness)
    user = (
        f"Fixed Thai (do not change): {thai!r}\n"
        "Split the Fixed Thai into words. Thai script only."
    )
    data = _openai_chat_json(
        system=_words_system_prompt(p, problems),
        user=user,
        temperature=0.15 if problems else 0.25,
        timeout=max(3.0, min(6.0, timeout)),
        schema=_WORDS_SCHEMA,
        tag="smart_speaker.words",
    )
    if not data:
        return None
    words = _clean_words(data.get("words"))
    if not words:
        return None
    if all(w.get("th") and w.get("ph") and w.get("m") for w in words):
        return words
    slots = [w["th"] for w in words if w.get("th")]
    if not slots:
        return None
    filled = _llm_fill_slots(ru, slots, p, problems=problems, timeout=timeout)
    return _apply_slots(slots, filled or [])


def _slot_strings(data: Any, n: int, array_key: str, word_key: str) -> list[str] | None:
    """Достаёт список строк из {meanings|phonetics} или из legacy {words:[{m|ph}]}."""
    if not isinstance(data, dict) or n <= 0:
        return None
    raw = data.get(array_key)
    if isinstance(raw, list):
        return [str(x or "") for x in raw[:n]]
    words = data.get("words")
    if isinstance(words, list):
        out: list[str] = []
        for w in words[:n]:
            if isinstance(w, dict):
                out.append(str(w.get(word_key) or ""))
            else:
                out.append(str(w or ""))
        return out
    return None


def _meanings_system_prompt(n: int, problems: list[str] | None) -> str:
    base = (
        f"There are exactly {n} Thai words, numbered and FIXED.\n"
        "For each word return its Russian meaning in this sentence (1-4 words).\n"
        "Meaning of THAT Thai word, not of the whole sentence.\n"
        "Do not copy a Russian word onto a Thai word that does not mean it.\n"
        "Function words จะ/มี/เป็น/ไม่/ที่ → будет/есть/являться/не — never a noun.\n"
        f"Return JSON {{\"meanings\":[\"...\", ...]}} with exactly {n} strings."
    )
    if problems:
        base += "\n\nPrevious meanings were REJECTED. Fix these:\n" + "\n".join(
            f"- {p}" for p in problems[:8]
        )
    return base


def _phonetics_system_prompt(n: int, problems: list[str] | None) -> str:
    base = (
        f"There are exactly {n} Thai words, numbered and FIXED.\n"
        "For each word return how it SOUNDS: Russian Cyrillic + one tone arrow per syllable.\n"
        "Cyrillic а-я/ё only. Write «нг» not «ng», «кх» not «kh». No Latin, no Thai script.\n"
        "Tone arrows → ↓ ↘ ↑ ↗ glued to the syllable.\n"
        "Several syllables of ONE word: join with hyphens, never spaces.\n"
        "Every item has at least one tone arrow. Final ว is a vowel: หิว → хиу↗.\n"
        f"Return JSON {{\"phonetics\":[\"...\", ...]}} with exactly {n} strings."
    )
    if problems:
        base += "\n\nPrevious phonetics were REJECTED. Fix these:\n" + "\n".join(
            f"- {p}" for p in problems[:8]
        )
    return base


def _llm_fill_slots(
    ru: str,
    slots: list[str],
    politeness: str,
    problems: list[str] | None = None,
    timeout: float = 8.0,
) -> list[dict[str, str]] | None:
    if not slots:
        return None
    n = len(slots)
    numbered = "\n".join(f"{i + 1}. {th}" for i, th in enumerate(slots))
    user = (
        f"Russian sentence (context only): {ru!r}\n"
        f"Locked Thai words ({n}):\n{numbered}"
    )
    t_meanings = max(2.5, min(5.0, timeout * 0.5))
    data = _openai_chat_json(
        system=_meanings_system_prompt(n, problems),
        user=user + "\nReturn the Russian meaning of each numbered word.",
        temperature=0.15 if problems else 0.2,
        timeout=t_meanings,
        schema=_MEANINGS_SCHEMA,
        tag="smart_speaker.slots.meanings",
    )
    meanings = _slot_strings(data, n, "meanings", "m") or []
    phonetics = _slot_strings(data, n, "phonetics", "ph") or []
    if len(phonetics) < n or not all(p.strip() for p in phonetics):
        t_ph = max(2.5, min(5.0, timeout - t_meanings if timeout > t_meanings else timeout * 0.5))
        data_ph = _openai_chat_json(
            system=_phonetics_system_prompt(n, problems),
            user=user + "\nReturn how each numbered word sounds.",
            temperature=0.15 if problems else 0.2,
            timeout=t_ph,
            schema=_PHONETICS_SCHEMA,
            tag="smart_speaker.slots.phonetic",
        )
        phonetics = _slot_strings(data_ph, n, "phonetics", "ph") or []
    while len(meanings) < n:
        meanings.append("")
    while len(phonetics) < n:
        phonetics.append("")
    return [{"ph": phonetics[i], "m": meanings[i]} for i in range(n)]


def _repair_gloss_senses(
    ru: str,
    words: list[dict[str, str]],
    timeout: float,
) -> list[dict[str, str]]:
    """
    Второй проход только по значениям: подпись должна быть значением тайского слова,
    а не русским словом, посаженным на чужой слот. Если судья молчит — оставляем как есть.
    """
    if timeout < 2.0 or len(words) < 2 or not OPENAI_API_KEY:
        return words
    listed = "\n".join(
        f"{i}. th={w.get('th')!r} m={w.get('m')!r}" for i, w in enumerate(words)
    )
    data = _openai_chat_json(
        system=(
            "You check word glosses for a Thai lesson.\n"
            "For each item, m must be the meaning of th.\n"
            "If m is a Russian word from the user sentence that this Thai word does not mean, it is wrong.\n"
            "Return JSON {\"fixes\":[{\"i\":0,\"m\":\"correct meaning\"},...]} "
            "only for wrong items. If all are correct, fixes=[]."
        ),
        user=f"Russian sentence: {ru!r}\nItems:\n{listed}",
        temperature=0.0,
        timeout=timeout,
        schema=_GLOSS_FIX_SCHEMA,
        tag="smart_speaker.gloss",
    )
    if not data:
        return words
    fixes = data.get("fixes")
    if not isinstance(fixes, list):
        return words
    out = [dict(w) for w in words]
    for item in fixes:
        if not isinstance(item, dict):
            continue
        try:
            i = int(item.get("i"))
        except (TypeError, ValueError):
            continue
        if i < 0 or i >= len(out):
            continue
        m = _strip_thai_from_explanation(str(item.get("m") or ""))
        m = re.sub(r"\s+", " ", m).strip()
        if m and not _is_weak_gloss(m) and not _is_whole_phrase_gloss(m, ru):
            out[i]["m"] = m
    return out


def _llm_spoken_thai(ru: str, politeness: str, problems: list[str] | None, timeout: float) -> str | None:
    p = _norm_politeness(politeness)
    particle = "ครับ" if p == "male" else "ค่ะ"
    i_th = _speaker_i_thai(p)
    other_i = _I_THAI_FEMALE if i_th == _I_THAI_MALE else _I_THAI_MALE
    extra = ""
    if problems:
        extra = "\nPrevious Thai was REJECTED:\n" + "\n".join(f"- {x}" for x in problems[:6])
    system = (
        "You translate Russian into spoken Thai for a tourist talking to a Thai person.\n"
        "Return JSON {\"thai\":\"...\"} only. Thai script, one short spoken sentence.\n"
        f"Speaker: {p}. First person я/меня/мне/мой → {i_th}. Never write {other_i}.\n"
        f"Do NOT write {particle} or ค่ะ/ครับ — the server appends the gender particle.\n"
        "Do NOT write phonetic, Russian, or Latin.\n"
        "Keep the exact meaning. If Russian names a thing (дождь, кофе, туалет, счёт), "
        "that thing MUST appear as its own Thai word (ฝน, กาแฟ, ห้องน้ำ, บิล).\n"
        "จะมี without the noun is wrong for «будет дождь». Natural is ฝนจะตก.\n"
        "Do not swap in a stock language-app phrase."
    )
    user = f"Russian: {ru!r}{extra}\nSpoken Thai only."
    data = _openai_chat_json(
        system=system,
        user=user,
        temperature=0.2 if problems else 0.3,
        timeout=timeout,
        schema=_THAI_ONLY_SCHEMA,
        tag="smart_speaker.translate",
        model=OPENAI_TRANSLATE_MODEL,
    )
    if not data:
        return None
    thai = "".join(_THAI_SCRIPT_RE.findall(str(data.get("thai") or "")))
    thai, _ = _strip_trailing_politeness(thai, "")
    return thai or None


def _llm_meaning_judge(ru: str, thai: str, timeout: float) -> list[str]:
    """Пустой список = смысл ок. Не блокируем, если судья молчит — локальный гейт уже есть."""
    local = _dropped_content_problems(ru, thai)
    if local:
        return local
    data = _openai_chat_json(
        system=(
            "You check whether a Thai sentence means what the Russian speaker said.\n"
            "Return JSON {\"ok\": true/false, \"missing\": [\"...\"]}.\n"
            "missing = Russian content words whose meaning is absent from the Thai.\n"
            "Idioms can be ok: «я хочу есть» / ฉันหิว or ผมหิว → ok true, missing [].\n"
            "«Будет дождь» / จะมี → ok false, missing [\"дождь\"] because ฝน is absent.\n"
            "Do not demand word-for-word calque."
        ),
        user=f"Russian: {ru!r}\nThai: {thai!r}",
        temperature=0.0,
        timeout=timeout,
        schema=_JUDGE_SCHEMA,
        tag="smart_speaker.judge",
    )
    if not data:
        return []
    missing = [str(x).strip() for x in (data.get("missing") or []) if str(x).strip()]
    ok = bool(data.get("ok"))
    if ok and not missing:
        return []
    if missing:
        return [
            "Thai is missing Russian content: "
            + ", ".join(missing[:6])
            + ". Add the real Thai word."
        ]
    if not ok:
        return ["Thai does not mean the Russian sentence. Translate again, keep every content word."]
    return []


_TEACH_TIME_BUDGET_S = 14.0
_LIVE_TIME_BUDGET_S = 28.0


def _outputs_from_words(
    ru: str,
    words: list[dict[str, str]],
) -> tuple[str, str, list[dict[str, str]]] | None:
    ready = [w for w in words if w.get("th") and w.get("ph") and w.get("m")]
    if len(ready) != len(words) or not ready:
        return None
    out_th, phonetic, parts = _words_to_outputs(ready)
    if not out_th or not phonetic or not parts:
        return None
    if _phonetic_is_spelled_russian_source(ru, phonetic):
        return None
    if not _parts_match_phonetic(phonetic, parts):
        return None
    return out_th, phonetic, parts


def _teach_slots(
    ru: str,
    slots: list[str],
    politeness: str,
    t0: float,
) -> tuple[str, str, list[dict[str, str]]] | None:
    attempt_problems: list[str] | None = None
    last_words: list[dict[str, str]] | None = None
    for attempt in range(2):
        left = _TEACH_TIME_BUDGET_S - (time.monotonic() - t0)
        if left < 3.0:
            break
        filled = _llm_fill_slots(
            ru, slots, politeness, problems=attempt_problems, timeout=max(3.5, min(8.0, left))
        )
        words = _apply_slots(slots, filled or [])
        last_words = words
        problems = _validate_words(ru, words)
        if problems:
            print(
                f"[smart_speaker.slots] rejected (attempt {attempt + 1}): {'; '.join(problems[:4])}",
                file=sys.stderr,
                flush=True,
            )
            attempt_problems = problems
            continue
        left = _TEACH_TIME_BUDGET_S - (time.monotonic() - t0)
        words = _repair_gloss_senses(ru, words, timeout=min(4.0, max(0.0, left)))
        built = _outputs_from_words(ru, words)
        if built:
            if attempt:
                print("[smart_speaker.slots] recovered on repair pass", file=sys.stderr, flush=True)
            return built
        attempt_problems = ["could not assemble phonetic and gloss from slots"]
    if last_words:
        return _outputs_from_words(ru, last_words)
    return None


def _teach_from_thai(
    ru: str,
    thai: str,
    politeness: str,
    started: float | None = None,
) -> tuple[str, str, list[dict[str, str]]] | None:
    """
    Урок по уже готовому тайскому.
    Слова берёт словарь. Модель заполняет звучание и значение. Фонетика и разбор
    собираются из одного списка — поэтому они не могут разъехаться.
    """
    locked, _ = _strip_trailing_politeness(_thai_bare(thai), "")
    if not locked:
        return None
    t0 = started if started is not None else time.monotonic()
    if _tokenizer_is_live():
        slots = _thai_lesson_slots(locked)
        if slots:
            taught = _teach_slots(ru, slots, politeness, t0)
            if taught:
                return taught
            print("[smart_speaker.slots] falling back to model split", file=sys.stderr, flush=True)

    attempt_problems: list[str] | None = None
    coarse: tuple[str, str, list[dict[str, str]]] | None = None
    for attempt in range(2):
        left = _TEACH_TIME_BUDGET_S - (time.monotonic() - t0)
        if left < 3.5:
            print("[smart_speaker.words] out of time budget, skipping repair pass", file=sys.stderr, flush=True)
            return coarse
        words = _llm_split_thai_to_words(
            ru, locked, politeness, problems=attempt_problems, timeout=max(3.5, left)
        )
        if not words:
            attempt_problems = ["response had no usable words"]
            continue
        problems = _words_follow_locked_thai(words, locked)
        problems.extend(_validate_words(ru, words))
        if not problems:
            built = _outputs_from_words(ru, words)
            if built:
                merges = _segmentation_problems(words)
                if not merges:
                    if attempt:
                        print("[smart_speaker.words] recovered on repair pass", file=sys.stderr, flush=True)
                    return built
                coarse = built
                problems = merges
            else:
                problems = ["could not assemble phonetic and gloss"]
        print(
            f"[smart_speaker.words] rejected (attempt {attempt + 1}): {'; '.join(problems[:4])}",
            file=sys.stderr,
            flush=True,
        )
        attempt_problems = problems
    return coarse


def _smart_translate_words(ru: str, politeness: str) -> tuple[str, str, list[dict[str, str]]] | None:
    """Совместимое имя: живой конвейер (перевод → урок). Нарезка тестов идёт через `_teach_from_thai`."""
    return _smart_speaker_live(ru, politeness)


def _smart_speaker_live(ru: str, politeness: str) -> tuple[str, str, list[dict[str, str]]] | None:
    """
    Живой ввод: перевод → опциональный ремонт смысла → урок.
    Судья не имеет права спрятать уже полученный Thai: None только если модели нечего отдать.
    """
    started = time.monotonic()
    problems: list[str] | None = None
    best_thai = None
    for attempt in range(2):
        left = _LIVE_TIME_BUDGET_S - (time.monotonic() - started)
        if left < 5.0:
            break
        thai = _llm_spoken_thai(ru, politeness, problems, timeout=min(8.0, left - 4.0))
        if not thai:
            problems = ["no spoken Thai"]
            continue
        best_thai = thai
        problems = _llm_meaning_judge(ru, thai, timeout=min(4.0, max(2.0, left - 8.0)))
        if not problems:
            break
        print(
            f"[smart_speaker.translate] repair (attempt {attempt + 1}) thai={thai!r}: "
            f"{'; '.join(problems[:3])}",
            file=sys.stderr,
            flush=True,
        )
    thai = best_thai
    if not thai:
        return None
    taught = _teach_from_thai(ru, thai, politeness, started=started)
    if taught:
        return _apply_speaker_pronoun(*taught, politeness)
    print("[smart_speaker] teaching failed, shipping Thai without gloss", file=sys.stderr, flush=True)
    left = _LIVE_TIME_BUDGET_S - (time.monotonic() - started)
    if left < 3.0:
        return _apply_speaker_pronoun(thai, "", [], politeness)
    phon = _llm_phonetic_from_thai_script(thai)
    phon_n = _normalize_phonetic_line(phon or "")
    if phon_n and not _phonetic_is_spelled_russian_source(ru, phon_n):
        return _apply_speaker_pronoun(thai, phon_n, [], politeness)
    return _apply_speaker_pronoun(thai, "", [], politeness)


def _llm_translate_ru_to_th(ru: str, politeness: str | None) -> tuple[str, str, list[dict[str, str]]] | None:
    """Legacy name: живой конвейер (перевод → урок). Формат собирают скрипты."""
    return _smart_speaker_live(ru, politeness or "female")


def _llm_phrase_parts(ru: str, thai: str, phonetic: str) -> list[dict[str, str]] | None:
    """Word-level gloss when translate path had no parts (steps.json / cache backfill)."""
    if not OPENAI_API_KEY:
        return None
    t = (thai or "").strip()
    ph = (phonetic or "").strip()
    if not t:
        return None
    system = (
        "You teach Thai to Russian speakers. Return JSON only: "
        "{\"parts\":[{\"p\":\"...\",\"m\":\"...\"},...]}.\n"
        "UNIVERSAL CONTRACT: parts are a 1:1 gloss of the phonetic space-chunks "
        "(strip tone arrows; keep hyphens inside a chunk). Same count, same order. No extra items.\n"
        "p = exact phonetic chunk without arrows. "
        "m = meaning of THAT Thai word (Russian, 1–5 words). Not a word copied from the Russian sentence unless the Thai word actually means it.\n"
        "CRITICAL: Never copy the full Russian sentence into any single m when there are 2+ chunks.\n"
        "Bad: p«кун-ю» m«Ты здесь». Good: p«кун-ю» m«ты находишься»; p«тхи» m«в»; p«ни» m«здесь».\n"
        "Gender particle кхрап/кха → m «вежливость (м)» / «вежливость (ж)». "
        "Softener «на» (นะ) → «смягчение», NEVER «вежливость»."
    )
    chunks = _phonetic_word_groups(ph)
    chunk_hint = (
        f"Required parts.p in this exact order ({len(chunks)} items): {chunks!r}\n"
        if chunks
        else ""
    )
    user = (
        f"Russian meaning: {ru!r}\n"
        f"Thai: {t!r}\n"
        f"Phonetic: {ph!r}\n"
        f"{chunk_hint}"
        "Return parts only — one gloss per required p."
    )
    try:
        resp = requests.post(
            "https://api.openai.com/v1/chat/completions",
            headers={
                "Authorization": f"Bearer {OPENAI_API_KEY}",
                "Content-Type": "application/json",
            },
            json={
                "model": OPENAI_MODEL,
                "messages": [
                    {"role": "system", "content": system},
                    {"role": "user", "content": user},
                ],
                "temperature": 0.3,
                "response_format": {"type": "json_object"},
            },
            timeout=15,
        )
    except Exception as e:
        print(f"[smart_speaker] parts request failed: {e}", file=sys.stderr, flush=True)
        return None
    if resp.status_code >= 300:
        return None
    try:
        content = resp.json()["choices"][0]["message"]["content"]
        data = json.loads(content)
        return _align_parts_to_phonetic(
            _normalize_parts(data.get("parts") if isinstance(data.get("parts"), list) else []),
            ph,
        )
    except Exception as e:
        print(f"[smart_speaker] parts parse error: {e}", file=sys.stderr, flush=True)
        return None


def _llm_phonetic_from_thai_script(thai: str) -> str | None:
    """
    Только фонетика по тайскому предложению: кириллица + стрелки тонов, по тайским слогам.
    Без русского промпта — модель не путает с исходной русской фразой.
    """
    if not OPENAI_API_KEY:
        return None
    t = (thai or "").strip()
    if not t:
        return None
    system = (
        "Return JSON {\"phonetic\": \"...\"} only.\n"
        "The user message is ONE sentence in Thai script.\n"
        "You write how that Thai sentence is pronounced, using Russian Cyrillic letters and tone arrows (→ ↓ ↘ ↑ ↗ only; never ↕ or ↔).\n"
        "Rules:\n"
        "- Follow Thai syllable boundaries (read the Thai left to right; each Thai syllable → one Cyrillic chunk + one arrow).\n"
        "- Spaces between Thai words → spaces between corresponding Cyrillic word groups.\n"
        "- Hyphens inside a chunk for multi-letter syllable parts. NO Thai characters in phonetic. NO Latin. NO IPA.\n"
        "- Vowel [i] = Cyrillic и/И only, never Latin I or i.\n"
        "- Do NOT transcribe any language other than what is written in Thai in the user message.\n"
        "- Omit final ครับ/ค่ะ from phonetic when present — server owns the single gender particle "
        "(do not write кхрап/кха unless the rest of the sentence requires another sense).\n"
        "Example: Thai 'สวัสดี' → 'са-ват-ди↘' or similar (Thai sounds, not English/Russian words)."
    )
    user = f"Thai sentence:\n{t}"
    try:
        resp = requests.post(
            "https://api.openai.com/v1/chat/completions",
            headers={
                "Authorization": f"Bearer {OPENAI_API_KEY}",
                "Content-Type": "application/json",
            },
            json={
                "model": OPENAI_MODEL,
                "messages": [
                    {"role": "system", "content": system},
                    {"role": "user", "content": user},
                ],
                "temperature": 0.25,
                "response_format": {"type": "json_object"},
            },
            timeout=18,
        )
    except Exception as e:
        print(f"[smart_speaker] phonetic-from-thai request failed: {e}", file=sys.stderr, flush=True)
        return None
    if resp.status_code >= 300:
        return None
    try:
        content = resp.json()["choices"][0]["message"]["content"]
        data = json.loads(content)
        phon = str(data.get("phonetic", "")).strip()
        if phon and not _has_thai_script(phon):
            return phon
    except Exception:
        return None
    return None


def _llm_translate_ru_to_th_retry(original_thai: str) -> tuple[str, str] | None:
    """Повторный запрос: только кириллическая фонетика произношения тайской фразы."""
    if not OPENAI_API_KEY:
        return None
    system = (
        "Return JSON {\"phonetic\": \"...\"} only. "
        "The user gives a sentence in Thai script. "
        "Phonetic = Russian Cyrillic + tone arrows: pronunciation of THAT Thai, syllable-by-syllable as in Thai. "
        "NOT Russian from any other source. NOT English. Use и/И for [i], never Latin I or i. "
        "Example Thai 'เหนื่อยมาก' → 'ныа↘ яй↘ ма↗к↘'."
    )
    user = (
        f"Thai: {original_thai!r}\n"
        "Write Cyrillic phonetic for these Thai words only. One Thai syllable → one chunk + arrow."
    )
    try:
        resp = requests.post(
            "https://api.openai.com/v1/chat/completions",
            headers={
                "Authorization": f"Bearer {OPENAI_API_KEY}",
                "Content-Type": "application/json",
            },
            json={
                "model": OPENAI_MODEL,
                "messages": [
                    {"role": "system", "content": system},
                    {"role": "user", "content": user},
                ],
                "temperature": 0.2,
                "response_format": {"type": "json_object"},
            },
            timeout=15,
        )
    except Exception as e:
        print(f"[smart_speaker] retry failed: {e}", file=sys.stderr, flush=True)
        return None
    if resp.status_code >= 300:
        return None
    try:
        content = resp.json()["choices"][0]["message"]["content"]
        data = json.loads(content)
        phon = str(data.get("phonetic", "")).strip()
        if phon and not _has_thai_script(phon):
            return original_thai, phon
        # Fallback: strip Thai from original and hope something remains
        return None
    except Exception:
        return None


@app.post("/smart_speaker")
async def smart_speaker(req: SmartSpeakerReq):
    ru = (req.text_ru or "").strip()
    if not ru:
        raise HTTPException(status_code=400, detail="text_ru is required")
    if len(ru) > 120:
        raise HTTPException(status_code=413, detail="text_ru too long")

    ru_norm = _norm_ru(ru)
    politeness = _norm_politeness(req.politeness)
    print(f"[smart_speaker] ru={ru!r} ru_norm={ru_norm!r} politeness={politeness}", file=sys.stderr, flush=True)

    parts: list[dict[str, str]] = []

    # 1. Cache lookup — если уже переводили, возвращаем из кэша (нормализуем на всякий случай)
    cached = _cache_get(ru_norm, politeness)
    if cached:
        thai, phonetic, parts = cached
        canonical = _normalize_phonetic_line(phonetic)
        if _parts_match_phonetic(canonical, parts):
            # Запись v8 уже согласована — не гоняем её через выравнивание заново.
            return {"thai": thai, "phonetic": canonical, "parts": parts}
        phonetic = _normalize_phonetic(phonetic)
        phonetic = _sanitize_phonetic_not_russian_spellout(ru, thai, phonetic)
        thai, phonetic = _strip_trailing_politeness(thai, phonetic)
        thai, phonetic = _apply_politeness(thai, phonetic, politeness)
        parts = _finalize_parts(ru, thai, phonetic, parts)
        if _parts_match_phonetic(phonetic, parts):
            _cache_set(ru_norm, politeness, thai, phonetic, parts)
        parts = _aligned_parts_only(phonetic, parts, "cache")
        return {"thai": thai, "phonetic": phonetic, "parts": parts}

    # 2. Живой канон выживания — авторский тайский, без модели.
    canon = _spoken_canon_hit(ru_norm)
    if canon:
        thai, phonetic, parts = canon
        phonetic = _normalize_phonetic_line(phonetic)
        thai, phonetic, parts = _apply_speaker_pronoun(thai, phonetic, parts, politeness)
        thai, phonetic = _apply_politeness(thai, phonetic, politeness)
        parts = list(parts) + [_politeness_part(politeness)]
        if _parts_match_phonetic(phonetic, parts):
            _cache_set(ru_norm, politeness, thai, phonetic, parts)
        print(f"[smart_speaker] canon hit ru={ru_norm!r}", file=sys.stderr, flush=True)
        return {"thai": thai, "phonetic": phonetic, "parts": parts}

    # 3. Steps.json — точное совпадение (фонетика авторская, её не переписываем)
    idx = _load_steps_index()
    hit = idx.get(ru_norm)
    if hit:
        thai, phonetic = hit
        phonetic = _normalize_phonetic(phonetic)
        thai, phonetic, _ = _apply_speaker_pronoun(thai, phonetic, [], politeness)
        thai, phonetic = _apply_politeness(thai, phonetic, politeness)
        parts = _finalize_parts(ru, thai, phonetic, _llm_phrase_parts(ru, thai, phonetic) or [])
        thai, phonetic, parts = _apply_speaker_pronoun(thai, phonetic, parts, politeness)
        if _parts_match_phonetic(phonetic, parts):
            _cache_set(ru_norm, politeness, thai, phonetic, parts)
        parts = _aligned_parts_only(phonetic, parts, "steps")
        return {"thai": thai, "phonetic": phonetic, "parts": parts}

    if not OPENAI_API_KEY:
        print("[smart_speaker] OPENAI_API_KEY not set, cannot translate", file=sys.stderr, flush=True)
        raise HTTPException(status_code=404, detail="no match and OPENAI_API_KEY not set in Railway Variables")

    # 4. Живой ввод: перевод → (ремонт смысла) → нарезка урока.
    built = _smart_speaker_live(ru, politeness)
    if not built:
        raise HTTPException(
            status_code=404,
            detail="LLM translation failed. Check Railway logs for OpenAI errors. Model="
            + OPENAI_TRANSLATE_MODEL,
        )
    thai, phonetic, parts = built
    dropped = _dropped_content_problems(ru, thai)
    if dropped:
        print(f"[smart_speaker] live warning, shipping anyway: {dropped[0]}", file=sys.stderr, flush=True)
    thai, phonetic, parts = _apply_speaker_pronoun(thai, phonetic, parts, politeness)
    thai, phonetic = _append_politeness(thai, phonetic, politeness)
    if parts:
        parts = parts + [_politeness_part(politeness)]
        if _parts_match_phonetic(phonetic, parts):
            _cache_set(ru_norm, politeness, thai, phonetic, parts)
            print(f"[smart_speaker] live ok: {len(parts)} parts", file=sys.stderr, flush=True)
            return {"thai": thai, "phonetic": phonetic, "parts": parts}
        parts = _aligned_parts_only(phonetic, parts, "live")
    if thai or phonetic:
        print(f"[smart_speaker] live shipped without full gloss ru={ru_norm!r}", file=sys.stderr, flush=True)
        return {"thai": thai, "phonetic": phonetic, "parts": parts}
    raise HTTPException(
        status_code=404,
        detail="LLM translation failed. Check Railway logs for OpenAI errors. Model="
        + OPENAI_TRANSLATE_MODEL,
    )


class PhrasePartsReq(BaseModel):
    text_ru: str | None = None
    text_th: str | None = None
    phonetic: str | None = None


@app.post("/phrase_parts")
async def phrase_parts(req: PhrasePartsReq):
    """Word-level gloss for an already-translated Smart Speaker phrase."""
    ru = (req.text_ru or "").strip()
    thai = (req.text_th or "").strip()
    # Клиент присылает уже готовую строку — границы слов в ней смысловые. Агрессивный
    # `_normalize_phonetic` разорвал бы «са-баи→-ди→» на слоги, и разбор снова разъехался бы.
    phonetic = _normalize_phonetic_line((req.phonetic or "").strip())
    if not thai and not phonetic:
        raise HTTPException(status_code=400, detail="text_th or phonetic required")
    parts = _finalize_parts(
        ru,
        thai,
        phonetic,
        _llm_phrase_parts(ru, thai, phonetic) or [],
        preserve_word_boundaries=True,
    )
    # Неполный разбор всё равно отдаём: клиент дотянет хвост, пустой экран хуже.
    return {"parts": _aligned_parts_only(phonetic, parts, "phrase_parts")}


@app.post("/thai_phonetic")
async def thai_phonetic(req: ThaiPhoneticReq):
    """
    Кириллическая фонетика произношения тайской строки (для колонки «ты сказал» после ASR в умном спикере).
    Тот же LLM-проход, что и при санитизации phonetic в /smart_speaker.
    """
    t = (req.text_th or "").strip()
    if not t:
        raise HTTPException(status_code=400, detail="text_th is required")
    if len(t) > 200:
        raise HTTPException(status_code=413, detail="text_th too long")
    raw = _llm_phonetic_from_thai_script(t)
    if not raw:
        raise HTTPException(
            status_code=503,
            detail="phonetic generation failed (OPENAI_API_KEY / network / model)",
        )
    phonetic = _normalize_phonetic(raw)
    if not phonetic.strip() or _has_thai_script(phonetic):
        raise HTTPException(status_code=503, detail="phonetic invalid after normalize")
    return {"phonetic": phonetic}


class TtsReq(BaseModel):
    """Thai (or any) text → MP3 via OpenAI TTS for Story Lab lesson videos."""

    text_th: str
    voice: str | None = "nova"


_TTS_VOICES = frozenset(
    {"alloy", "ash", "ballad", "coral", "echo", "fable", "nova", "onyx", "sage", "shimmer"}
)
_TTS_CACHE_DIR = Path(tempfile.gettempdir()) / "taika_tts_cache"


@app.post("/tts")
async def tts_thai(req: TtsReq):
    """
    Story Lab / lesson Reels: Thai script → MP3 pronunciation.
    Cached on disk by (voice, text) hash. Requires OPENAI_API_KEY.
    """
    from fastapi.responses import Response

    t = (req.text_th or "").strip()
    if not t:
        raise HTTPException(status_code=400, detail="text_th is required")
    if len(t) > 400:
        raise HTTPException(status_code=413, detail="text_th too long")
    if not OPENAI_API_KEY:
        raise HTTPException(status_code=503, detail="OPENAI_API_KEY not set")

    voice = (req.voice or "nova").strip().lower()
    if voice not in _TTS_VOICES:
        voice = "nova"

    import hashlib

    key = hashlib.sha256(f"{voice}\n{t}".encode("utf-8")).hexdigest()
    _TTS_CACHE_DIR.mkdir(parents=True, exist_ok=True)
    cache_path = _TTS_CACHE_DIR / f"{key}.mp3"
    if cache_path.is_file() and cache_path.stat().st_size > 0:
        return Response(
            content=cache_path.read_bytes(),
            media_type="audio/mpeg",
            headers={"X-TTS-Cache": "hit"},
        )

    try:
        resp = requests.post(
            "https://api.openai.com/v1/audio/speech",
            headers={
                "Authorization": f"Bearer {OPENAI_API_KEY}",
                "Content-Type": "application/json",
            },
            json={
                "model": os.getenv("OPENAI_TTS_MODEL", "tts-1").strip() or "tts-1",
                "input": t,
                "voice": voice,
                "response_format": "mp3",
            },
            timeout=60,
        )
    except requests.RequestException as e:
        print(f"[tts] request failed: {e}", file=sys.stderr, flush=True)
        raise HTTPException(status_code=503, detail="tts request failed") from e

    if resp.status_code != 200:
        print(f"[tts] http {resp.status_code}: {resp.text[:200]}", file=sys.stderr, flush=True)
        raise HTTPException(status_code=503, detail="tts generation failed")

    audio = resp.content
    if not audio:
        raise HTTPException(status_code=503, detail="tts empty body")
    try:
        cache_path.write_bytes(audio)
    except OSError as e:
        print(f"[tts] cache write failed: {e}", file=sys.stderr, flush=True)

    return Response(
        content=audio,
        media_type="audio/mpeg",
        headers={"X-TTS-Cache": "miss"},
    )


def _usable_coach(raw_headline: str, raw_detail: str) -> SemanticCoachResp | None:
    """
    Единственное место, где решается, годна ли подсказка к показу. Правила в промпте —
    не гарантия, поэтому фильтруем на выходе: тайская графика, вырожденное
    противопоставление и пустой заголовок одинаково подрывают доверие к разбору.

    Пустой заголовок при живом пояснении не выбрасываем целиком — поднимаем первую фразу
    пояснения наверх: совет остаётся, а блок не выглядит обрубленным.
    """
    headline = _strip_thai_from_explanation(raw_headline).strip()
    detail = _strip_thai_from_explanation(raw_detail).strip()

    if headline and _is_degenerate_advice(headline):
        print(f"[semantic_coach] dropping degenerate headline: {headline!r}", file=sys.stderr, flush=True)
        headline = ""
    if detail and _is_degenerate_advice(detail):
        print(f"[semantic_coach] dropping degenerate detail: {detail!r}", file=sys.stderr, flush=True)
        detail = ""

    if not headline:
        if not detail:
            return None
        headline = _first_sentence(detail)
        detail = detail[len(headline):].strip()

    return SemanticCoachResp(headline=headline, detail=detail or None)


def _openai_post_coach_raw(req: SemanticCoachReq) -> dict[str, Any] | None:
    """Сырой ответ модели. Вынесено отдельно, чтобы фильтр `_usable_coach` тестировался сквозь эндпоинт."""
    weak = req.weak_syllables or []
    weak_txt = json.dumps(weak[:6], ensure_ascii=False) if weak else "[]"
    system = (
        "You are a Thai pronunciation coach for Russian-speaking learners. "
        "Return JSON {\"headline\": \"...\", \"detail\": \"...\"} in Russian.\n"
        "headline: one short line (max 8 words) — the ONE main fix. REQUIRED, never empty.\n"
        "detail: 1-2 sentences — concrete: wrong word vs wrong tone vs wrong syllable. "
        "If heard_thai differs from expected_thai, explain the semantic difference when expected_ru is given. "
        "Never invent Thai words not in the input. No markdown.\n"
        "NEVER write Thai script: the learner cannot read it. To name a Thai word, use its "
        "Russian Cyrillic pronunciation from expected_phonetic / heard_phonetic instead.\n"
        "Two Thai words can share the same Cyrillic spelling and differ ONLY by tone. In that case "
        "naming the words is useless — «используй май вместо май» teaches nothing. Name the TONE in "
        "Russian words instead: «в слове май нужен нисходящий тон, а прозвучал восходящий». "
        "Tone names: ровный, низкий, нисходящий, высокий, восходящий.\n"
        "NEVER return advice where both sides of «вместо» / «а не» / «нужно было» are the same text."
    )
    user = (
        f"expected_ru: {req.expected_ru!r}\n"
        f"expected_thai: {req.expected_thai!r}\n"
        f"expected_phonetic: {req.expected_phonetic!r}\n"
        f"heard_thai (ASR): {req.heard_thai!r}\n"
        f"heard_phonetic: {req.heard_phonetic!r}\n"
        f"text_score: {req.text_score}\n"
        f"tone_score: {req.tone_score}\n"
        f"weak_syllables: {weak_txt}\n"
        "Explain what the user should fix for self-study."
    )
    try:
        resp = requests.post(
            "https://api.openai.com/v1/chat/completions",
            headers={
                "Authorization": f"Bearer {OPENAI_API_KEY}",
                "Content-Type": "application/json",
            },
            json={
                "model": OPENAI_MODEL,
                "messages": [
                    {"role": "system", "content": system},
                    {"role": "user", "content": user},
                ],
                "temperature": 0.35,
                "response_format": {"type": "json_object"},
            },
            timeout=16,
        )
    except Exception as e:
        print(f"[semantic_coach] openai request failed: {e}", file=sys.stderr, flush=True)
        return None
    if resp.status_code >= 300:
        return None
    try:
        data = json.loads(resp.json()["choices"][0]["message"]["content"])
        return data if isinstance(data, dict) else None
    except Exception:
        return None


def _llm_semantic_coach(req: SemanticCoachReq) -> SemanticCoachResp | None:
    if not OPENAI_API_KEY:
        return None
    data = _openai_post_coach_raw(req)
    if not data:
        return None
    return _usable_coach(str(data.get("headline", "")), str(data.get("detail", "")))


@app.post("/semantic_coach")
async def semantic_coach(req: SemanticCoachReq):
    """Russian coaching hint: semantic diff + tone focus for Speaker self-study."""
    if not OPENAI_API_KEY:
        raise HTTPException(status_code=404, detail="OPENAI_API_KEY not set")
    out = _llm_semantic_coach(req)
    if not out:
        raise HTTPException(status_code=503, detail="semantic coach generation failed")
    return out.model_dump()


@app.get("/health")
async def health():
    steps_ok = _steps_path().is_file()
    try:
        from gift import gift_health

        gift = gift_health()
    except Exception as e:  # noqa: BLE001
        gift = {"error": str(e)}
    return {
        "status": "ok",
        "steps_json": steps_ok,
        "openai_configured": bool(OPENAI_API_KEY),
        "model": OPENAI_MODEL,
        "translate_model": OPENAI_TRANSLATE_MODEL,
        "gift": gift,
    }


class GiftIssueReq(BaseModel):
    buyer_rc_id: str | None = None
    transaction_id: str | None = None
    demo: bool = False


class GiftRedeemReq(BaseModel):
    code: str
    app_user_id: str


@app.post("/gift/issue")
async def gift_issue(req: GiftIssueReq):
    """После оплаты gift-SKU (или demo при GIFT_DEMO=1) — выдать одноразовый код."""
    try:
        from gift import init_gift_db, issue_gift_code

        init_gift_db()
        out = issue_gift_code(
            buyer_rc_id=req.buyer_rc_id,
            transaction_id=req.transaction_id,
            demo=bool(req.demo),
        )
    except Exception as e:  # noqa: BLE001
        print(f"[gift] issue error: {e}", file=sys.stderr, flush=True)
        raise HTTPException(status_code=500, detail="gift issue failed") from e
    if not out.get("ok"):
        err = str(out.get("error") or "issue_failed")
        code = 403 if err in ("demo_disabled",) else 400
        raise HTTPException(status_code=code, detail=err)
    return out


@app.post("/gift/redeem")
async def gift_redeem(req: GiftRedeemReq):
    """Получатель активирует код → promotional entitlement `pro`."""
    try:
        from gift import init_gift_db, redeem_gift_code

        init_gift_db()
        out = redeem_gift_code(code_raw=req.code or "", app_user_id=req.app_user_id or "")
    except Exception as e:  # noqa: BLE001
        print(f"[gift] redeem error: {e}", file=sys.stderr, flush=True)
        raise HTTPException(status_code=500, detail="gift redeem failed") from e
    if not out.get("ok"):
        err = str(out.get("error") or "redeem_failed")
        status = 404 if err == "not_found" else 409 if err == "already_redeemed" else 400
        raise HTTPException(status_code=status, detail=err)
    return out
