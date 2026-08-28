#!/usr/bin/env python3
"""
Minimal FastAPI server for Thai tone assessment (Phase C).
POST /assess: multipart form with "file" (audio) + "text" (Thai target); returns Phase D–compatible JSON.
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
from pydantic import BaseModel

app = FastAPI(title="Thai Tone Assessment", version="0.1.0")

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
                lambda: importlib.import_module("run_phase_c").assess(assess_path, text.strip(), expected_tones),
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


def _normalize_phonetic(phonetic: str) -> str:
    """Убирает IPA, латиницу в фонетике, тайский скрипт; оставляет кириллицу и стрелки →↓↘↑↗."""
    out = _strip_thai_from_phonetic(phonetic)
    for old, new in _IPA_REPLACEMENTS:
        out = out.replace(old, new)
    for bad, good in _PHONETIC_ARROW_FIXUPS:
        out = out.replace(bad, good)
    out = _fix_latin_i_in_phonetic(out)
    out = _latin_to_cyrillic_phonetic(out)
    out = re.sub(r"\s+", " ", out).strip()
    out = _collapse_letter_space_arrow(out)
    out = _normalize_phonetic_word_spaces(out)
    return out


def _strip_arrows(s: str) -> str:
    out = s or ""
    for a in ARROWS + ("↕", "↔", "⇕", "⇅"):
        out = out.replace(a, "")
    return out.strip()


def _normalize_phonetic_token(raw: str) -> str:
    """
    Нормализация ОДНОГО слова: внутри слова пробелов быть не может — только дефисы,
    поэтому `_normalize_phonetic_word_spaces` (режет по стрелкам) здесь не применяется.
    """
    s = _strip_thai_from_phonetic(raw or "")
    # Скобочные пояснения («кхун (you)») — комментарий модели, а не звучание.
    s = re.sub(r"[(\[{][^)\]}]*[)\]}]", " ", s)
    for old, new in _IPA_REPLACEMENTS:
        s = s.replace(old, new)
    for bad, good in _PHONETIC_ARROW_FIXUPS:
        s = s.replace(bad, good)
    s = _fix_latin_i_in_phonetic(s)
    s = _latin_to_cyrillic_phonetic(s)
    s = re.sub(r"\s+", " ", s).strip()
    s = _collapse_letter_space_arrow(s)
    s = re.sub(r"[^а-яёА-ЯЁ→↓↘↑↗\s-]", "", s)
    s = re.sub(r"[\s-]*-[\s-]*", "-", s)
    s = re.sub(r"\s+", "-", s)
    s = re.sub(r"-{2,}", "-", s)
    return s.strip("- ")


def _normalize_phonetic_line(phonetic: str) -> str:
    """
    Санитайз уже согласованной строки С СОХРАНЕНИЕМ границ слов.
    В отличие от `_normalize_phonetic`, не режет «ру↑-сык↘» по стрелке: там дефис —
    это стык слогов внутри одного тайского слова, а не граница слов.
    """
    tokens = [_normalize_phonetic_token(t) for t in (phonetic or "").split()]
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
_SMART_CACHE_PROMPT_VERSION = "v9"


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
    parts_json = json.dumps(parts or [], ensure_ascii=False)
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

OPENAI_API_KEY = (os.getenv("OPENAI_API_KEY") or "").strip()
OPENAI_MODEL = (os.getenv("TAIKA_SMART_MODEL") or "gpt-4o-mini").strip()
OPENAI_CHAT_URL = "https://api.openai.com/v1/chat/completions"


def _openai_chat_json(
    *,
    system: str,
    user: str,
    temperature: float,
    timeout: float,
    schema: dict[str, Any] | None = None,
    tag: str = "smart_speaker",
) -> dict[str, Any] | None:
    """
    Один вход для всех LLM-вызовов. Пробует Structured Outputs (strict json_schema);
    если аккаунт/модель их не принимает — откатывается на json_object, а не падает.
    """
    if not OPENAI_API_KEY:
        return None
    body: dict[str, Any] = {
        "model": OPENAI_MODEL,
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
                    "required": ["th", "ph", "m"],
                    "properties": {
                        "th": {"type": "string", "description": "One Thai word, Thai script only"},
                        "ph": {"type": "string", "description": "Cyrillic pronunciation of that word + tone arrows"},
                        "m": {"type": "string", "description": "Russian meaning of that word in this sentence"},
                    },
                },
            }
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
        if not m:
            problems.append(f"word[{i}] '{th}': 'm' is empty")
        elif _is_weak_gloss(m):
            problems.append(f"word[{i}] '{th}': 'm' is too vague ({m!r})")
        elif multi and _is_whole_phrase_gloss(m, ru):
            problems.append(f"word[{i}] '{th}': 'm' repeats the whole sentence instead of this word")
    if not any(any(a in w.get("ph", "") for a in ARROWS) for w in words):
        problems.append("no tone arrows anywhere in 'ph'")
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
    Рассогласованный разбор не отдаём вообще: пустой список — сигнал клиенту дотянуть его
    отдельным запросом. Пара «слово — чужое значение» учит неправильному и подрывает доверие
    к функции; отсутствие разбора читается всего лишь как свойство фразы.
    """
    if not parts:
        return []
    if _parts_match_phonetic(phonetic, parts):
        return parts
    print(
        f"[smart_speaker] dropping unaligned parts ({where}): {len(parts)} parts vs "
        f"{len(_phonetic_word_groups(phonetic))} phonetic chunks",
        file=sys.stderr,
        flush=True,
    )
    return []


def _words_system_prompt(politeness: str, problems: list[str] | None) -> str:
    p = _norm_politeness(politeness)
    particle = "ครับ / кхрап" if p == "male" else "ค่ะ / кха"
    base = (
        "You are a Thai teacher for Russian speakers.\n"
        "Translate the Russian sentence into natural Thai and return it SPLIT INTO WORDS as JSON.\n\n"
        "For every Thai word return three fields:\n"
        "  \"th\" — that single word in Thai script (Thai letters only, no spaces).\n"
        "  \"ph\" — how THAT word sounds, in Russian Cyrillic + tone arrows.\n"
        "  \"m\"  — what THAT word means IN THIS sentence (Russian, 1-4 words).\n\n"
        "\"ph\" rules (STRICT):\n"
        "- Cyrillic а-я/ё ONLY. Never Latin letters: write «нг», not «ng»; «кх», not «kh».\n"
        "- No Thai script, no IPA, no accents.\n"
        "- Tone arrows: only → ↓ ↘ ↑ ↗ , each glued right after its syllable.\n"
        "- A multi-syllable word joins its syllables with hyphens INSIDE \"ph\": «ру↑-сык↘».\n"
        "- No accent marks or combining diacritics — plain Cyrillic letters only.\n"
        "- NEVER put a space inside \"ph\" — one word = one \"ph\".\n\n"
        "Splitting rules (STRICT):\n"
        "- One entry = ONE Thai dictionary word. A noun and the word describing it are\n"
        "  SEPARATE entries: «смешное ухо» is หู (ухо) + ตลก (смешной), never one «หูตลก».\n"
        "- Same for verb + object, adjective + intensifier: ร้อน (горячо) + มาก (очень).\n"
        "- But a real compound that lives in the dictionary stays ONE entry:\n"
        "  สบายดี, อย่างไร, น้ำแข็ง, โรงพยาบาล, ขอบคุณ.\n"
        "- The learner reads only these entries, so a hidden word is a word never learned.\n\n"
        "\"m\" rules:\n"
        "- The role of THAT word here, not a dictionary dump of all senses.\n"
        "- NEVER put the translation of the whole sentence into one \"m\".\n"
        "- Russian only. No Thai script inside \"m\" — the learner cannot read it.\n\n"
        "Translation rules:\n"
        "- Keep the exact meaning: same subject (я/ты/вы/он), same tense, a question stays a question.\n"
        "- If the Russian names a language (русский/английский/тайский), keep that EXACT language.\n"
        "- Do NOT translate into a more \"typical\" app phrase than what was asked.\n"
        f"- Do NOT output {particle} anywhere — the server appends exactly one politeness particle.\n\n"
        "Example — Russian «Как ваше настроение»:\n"
        "{\"words\":[{\"th\":\"คุณ\",\"ph\":\"кхун→\",\"m\":\"вы\"},"
        "{\"th\":\"รู้สึก\",\"ph\":\"ру↑-сык↘\",\"m\":\"чувствуете\"},"
        "{\"th\":\"อย่างไร\",\"ph\":\"я↘нг-рай→\",\"m\":\"как\"}]}\n"
        "Note: รู้สึก and อย่างไร are single words, so their syllables are joined by a hyphen.\n\n"
        "Example — Russian «Очень смешное ухо» (three separate words, never glued):\n"
        "{\"words\":[{\"th\":\"หู\",\"ph\":\"ху↑\",\"m\":\"ухо\"},"
        "{\"th\":\"ตลก\",\"ph\":\"та↓-лок↓\",\"m\":\"смешной\"},"
        "{\"th\":\"มาก\",\"ph\":\"мак↘\",\"m\":\"очень\"}]}\n"
        "Note: «หูตลก» as one entry would be WRONG — it hides the word หู from the learner.\n\n"
        "Return JSON: {\"words\":[{\"th\":\"...\",\"ph\":\"...\",\"m\":\"...\"}]}"
    )
    if problems:
        base += (
            "\n\nYour previous answer was REJECTED. Fix exactly these problems and return the whole array again:\n"
            + "\n".join(f"- {p}" for p in problems[:8])
        )
    return base


def _llm_words_ru_to_th(
    ru: str,
    politeness: str | None,
    problems: list[str] | None = None,
    timeout: float = 12.0,
) -> list[dict[str, str]] | None:
    p = _norm_politeness(politeness)
    is_question = (ru.rstrip()).endswith("?")
    user = (
        f"Russian sentence: {ru!r}{' (this is a question)' if is_question else ''}\n"
        f"Speaker politeness: {p} (do not write the particle yourself).\n"
        "Return the Thai translation split into words."
    )
    data = _openai_chat_json(
        system=_words_system_prompt(p, problems),
        user=user,
        temperature=0.2 if problems else 0.35,
        timeout=timeout,
        schema=_WORDS_SCHEMA,
        tag="smart_speaker.words",
    )
    if not data:
        return None
    return _clean_words(data.get("words"))


# Клиент ждёт ответ 25 с. Проход по словам (до двух попыток) обязан оставить время
# на legacy-запас, иначе пользователь получит таймаут вместо перевода.
_WORDS_TIME_BUDGET_S = 13.0


def _smart_translate_words(ru: str, politeness: str) -> tuple[str, str, list[dict[str, str]]] | None:
    """
    Основной путь /smart_speaker. Возвращает согласованные (thai, phonetic, parts)
    либо None — тогда вызывающий откатывается на legacy-путь. Брак наружу не отдаём.
    """
    started = time.monotonic()
    attempt_problems: list[str] | None = None
    # Слишком крупный, но корректный разбор: придерживаем на случай, если ремонтный
    # проход не справится. Показать «ху-талок — смешное ухо» хуже, чем два слова,
    # но заметно лучше, чем не показать разбор вовсе.
    coarse: tuple[str, str, list[dict[str, str]]] | None = None
    for attempt in range(2):
        left = _WORDS_TIME_BUDGET_S - (time.monotonic() - started)
        if attempt and left < 4.0:
            print("[smart_speaker.words] out of time budget, skipping repair pass", file=sys.stderr, flush=True)
            return coarse
        words = _llm_words_ru_to_th(ru, politeness, problems=attempt_problems, timeout=max(4.0, left))
        if not words:
            attempt_problems = ["response had no usable words"]
            continue
        problems = _validate_words(ru, words)
        if not problems:
            thai, phonetic, parts = _words_to_outputs(words)
            if _phonetic_is_spelled_russian_source(ru, phonetic):
                problems = ["\"ph\" spells the Russian sentence instead of Thai pronunciation"]
            elif not _parts_match_phonetic(phonetic, parts):
                problems = ["internal: parts did not line up with phonetic"]
            else:
                merges = _segmentation_problems(words)
                if not merges:
                    if attempt:
                        print("[smart_speaker.words] recovered on repair pass", file=sys.stderr, flush=True)
                    return thai, phonetic, parts
                coarse = (thai, phonetic, parts)
                problems = merges
        print(
            f"[smart_speaker.words] rejected (attempt {attempt + 1}): {'; '.join(problems[:4])}",
            file=sys.stderr,
            flush=True,
        )
        attempt_problems = problems
    return coarse


def _llm_translate_ru_to_th(ru: str, politeness: str | None) -> tuple[str, str, list[dict[str, str]]] | None:
    """
    Fallback when нет точного совпадения в steps.json.
    Использует OpenAI Chat API, если задан OPENAI_API_KEY.
    Возвращает (thai, phonetic, parts) или None при ошибке.
    """
    if not OPENAI_API_KEY:
        return None

    p = _norm_politeness(politeness)
    if p == "male":
        politeness_rule = (
            "Speaker politeness (FIXED attribute from the app): male.\n"
            "Do NOT write ครับ / ค่ะ / кхрап / крап / кха anywhere in thai, phonetic, or parts. "
            "The server appends exactly one final ครับ / кхрап↘ after your output."
        )
        particle_example = "ฉันพูดภาษารัสเซีย"
    else:
        label = "female" if p == "female" else "kathoey (use female particle)"
        politeness_rule = (
            f"Speaker politeness (FIXED attribute from the app): {label}.\n"
            "Do NOT write ครับ / ค่ะ / кхрап / крап / кха anywhere in thai, phonetic, or parts. "
            "The server appends exactly one final ค่ะ / кха↘ after your output."
        )
        particle_example = "ฉันพูดภาษารัสเซีย"

    system = (
        "You are a Thai teacher for Russian speakers. You output JSON with THREE things:\n\n"
        "1) \"thai\" — the answer in Thai script (what a Thai person would say).\n"
        "2) \"phonetic\" — ONLY the pronunciation of THAT Thai sentence written in Russian Cyrillic letters + tone arrows. "
        "This is **Thai-to-Cyrillic**: each **Thai syllable** (by Thai spelling) becomes one Cyrillic chunk + one arrow (→↓↘↑↗). "
        "It must sound like Thai, NOT like Russian. It must NOT repeat, spell, or syllabify the original Russian prompt.\n"
        "3) \"parts\" — teaching gloss locked to \"phonetic\" (UNIVERSAL CONTRACT):\n"
        "   - After each tone arrow, start a NEW space-separated chunk (do not chain with hyphens across tones).\n"
        "   - Split \"phonetic\" by spaces (ignore tone arrows). That list IS \"parts\".\n"
        "   - Same count, same order. Hyphens only INSIDE a chunk (са-бай), never instead of spaces between words.\n"
        "   - Do NOT add items that are not a phonetic space-chunk. Do NOT split one chunk into two parts.\n"
        "   - m = that chunk's role in the sentence (1–5 Russian words). NEVER put the full Russian prompt into one m.\n"
        "   - Same COUNT, same ORDER. Each \"p\" = that chunk WITHOUT tone arrows (hyphens stay).\n"
        "   - Do NOT add items that are not a phonetic space-chunk. Do NOT split one chunk into two parts.\n"
        "   - \"m\" = what that chunk means IN THIS SENTENCE (Russian, 1–5 words). "
        "Not a dictionary dump of all senses (e.g. do not gloss ที่ as «в / у» when it is part of ที่จะ «чтобы»).\n"
        "   - Softener นะ / «на» is NOT the gender particle — gloss it as «смягчение» or «мягко», never as «вежливость».\n"
        "   - Do NOT include gender politeness particles in parts (server adds them).\n"
        "   Example: phonetic «са-бай↘ ди↗-май↗» → parts "
        "[{\"p\":\"са-бай\",\"m\":\"в порядке\"},{\"p\":\"ди-май\",\"m\":\"хорошо? (вопрос)\"}] "
        "OR if phonetic has three chunks «са-бай↘ ди↗ май↗» → three parts.\n\n"
        f"{politeness_rule}\n\n"
        "CRITICAL — translate the EXACT meaning, do not substitute a more \"familiar\" app-domain sentence:\n"
        "- Translate ONLY the literal meaning of the given Russian sentence: same subject (я/ты/вы/он...), "
        "same verb tense/mood (statement vs question), same object/language named.\n"
        "- If the Russian sentence names a language (русский/тайский/английский...), keep that EXACT language in \"thai\" — "
        "never swap it for another language just because this app is about learning Thai.\n"
        f"- Example: «Я говорю по-русски» (statement, language=Russian) → thai «{particle_example}» "
        "(without ครับ/ค่ะ — server adds it). This is NOT «คุณพูดภาษาไทยได้ไหม» (\"Do you speak Thai?\") — "
        "do not default to that stock phrase just because it's common in Thai-learning apps.\n"
        "- Example: «Ты говоришь по-русски?» (question, 2nd person, language=Russian) → thai should ask "
        "whether the listener speaks Russian, not Thai.\n\n"
        "Phonetic format (STRICT):\n"
        "- Cyrillic а-я/ё only, plus hyphens inside a syllable, spaces between words. NO Thai letters in phonetic. NO Latin. NO IPA.\n"
        "- For the vowel sound [i] use ONLY Cyrillic «и»/«И», never Latin I or i.\n"
        "- One tone arrow glued to the end of each syllable chunk (no space before the arrow). "
        "Use ONLY these five: → ↓ ↘ ↑ ↗ (mid/low/falling/rising/high). Never ↕ ↔ or other arrows.\n"
        "- Good example: Russian «Как дела?» → thai might be «สบายดีไหม» → phonetic like «са-бай↘ ди↗-май↗» (sounds of Thai words).\n"
        "- BAD: any phonetic whose letters read as the Russian question (e.g. «как→ де→ла») — forbidden.\n"
        "- NEVER add ครับ/ค่ะ or кхрап/крап/кха — even once. Server appends the single particle for this speaker.\n\n"
        "Workflow: first re-read the Russian sentence carefully (who is the subject, is it a question, which language/topic "
        "is named), then choose the correct \"thai\" with the SAME meaning, then write \"phonetic\" by reading "
        "**left-to-right through \"thai\"**, then write \"parts\" as a 1:1 gloss of those phonetic space-chunks.\n"
        "If the Russian input is a question (?), \"thai\" should be a natural Thai question; \"phonetic\" still reflects only that Thai.\n\n"
        "Return JSON: {\"thai\": \"...\", \"phonetic\": \"...\", \"parts\": [{\"p\":\"...\",\"m\":\"...\"}, ...]}."
    )

    is_question = (ru.rstrip()).endswith("?")
    hint = " (question)" if is_question else ""
    user = (
        f"Russian phrase: {ru!r}{hint}.\n"
        f"Speaker politeness: {p}.\n"
        "Return thai + phonetic + parts WITHOUT any ครับ/ค่ะ/кхрап/крап/кха. "
        "phonetic = how to pronounce the **Thai** words (Cyrillic + tone arrows), not a spelling of the Russian. "
        "parts = 1:1 with phonetic space-chunks (same count/order; no extra tokens)."
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
                "temperature": 0.4,
                "response_format": {"type": "json_object"},
            },
            timeout=20,
        )
    except Exception as e:  # pragma: no cover - network errors
        print(f"[smart_speaker] openai request failed: {e}", file=sys.stderr, flush=True)
        return None

    if resp.status_code >= 300:
        print(f"[smart_speaker] openai http {resp.status_code}: {resp.text[:200]}", file=sys.stderr, flush=True)
        return None

    try:
        payload: dict[str, Any] = resp.json()
        content = payload["choices"][0]["message"]["content"]
        data = json.loads(content)
        thai = str(data.get("thai", "")).strip()
        phon = str(data.get("phonetic", "")).strip()
        parts = _normalize_parts(data.get("parts") if isinstance(data.get("parts"), list) else [])
        if not thai or not phon:
            return None
        # Retry once if LLM put Thai script in phonetic (must be Cyrillic only)
        if _has_thai_script(phon):
            print("[smart_speaker] phonetic had Thai script, retrying with corrective prompt", file=sys.stderr, flush=True)
            retried = _llm_translate_ru_to_th_retry(thai)
            if retried:
                thai, phon = retried
            else:
                phon = _normalize_phonetic(phon)
        phon = _normalize_phonetic(phon)
        if not phon:
            return None
        if _phonetic_is_spelled_russian_source(ru, phon):
            print("[smart_speaker] phonetic mirrored Russian; Thai-only phonetic pass", file=sys.stderr, flush=True)
            p2 = _llm_phonetic_from_thai_script(thai)
            if p2:
                p2n = _normalize_phonetic(p2)
                if p2n and not _phonetic_is_spelled_russian_source(ru, p2n):
                    if not parts:
                        parts = _llm_phrase_parts(ru, thai, p2n) or []
                    return thai, p2n, _finalize_parts(ru, thai, p2n, parts)
            retried2 = _llm_translate_ru_to_th_retry(thai)
            if retried2:
                _, p3 = retried2
                p3n = _normalize_phonetic(p3)
                if p3n and not _phonetic_is_spelled_russian_source(ru, p3n):
                    if not parts:
                        parts = _llm_phrase_parts(ru, thai, p3n) or []
                    return thai, p3n, _finalize_parts(ru, thai, p3n, parts)
            return thai, "", parts
        if not parts:
            parts = _llm_phrase_parts(ru, thai, phon) or []
        return thai, phon, _finalize_parts(ru, thai, phon, parts)
    except Exception as e:  # pragma: no cover - defensive
        print(f"[smart_speaker] parse error: {e}", file=sys.stderr, flush=True)
        return None


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
        "m = meaning of THAT chunk IN THIS SENTENCE (Russian, 1–5 words).\n"
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

    # 2. Steps.json — точное совпадение (фонетика авторская, её не переписываем)
    idx = _load_steps_index()
    hit = idx.get(ru_norm)
    if hit:
        thai, phonetic = hit
        thai, phonetic = _apply_politeness(thai, _normalize_phonetic(phonetic), politeness)
        parts = _finalize_parts(ru, thai, phonetic, _llm_phrase_parts(ru, thai, phonetic) or [])
        if _parts_match_phonetic(phonetic, parts):
            _cache_set(ru_norm, politeness, thai, phonetic, parts)
        parts = _aligned_parts_only(phonetic, parts, "steps")
        return {"thai": thai, "phonetic": phonetic, "parts": parts}

    if not OPENAI_API_KEY:
        print("[smart_speaker] OPENAI_API_KEY not set, cannot translate", file=sys.stderr, flush=True)
        raise HTTPException(status_code=404, detail="no match and OPENAI_API_KEY not set in Railway Variables")

    # 3. Основной путь: пословный контракт — thai/phonetic/parts из одного массива слов.
    built = _smart_translate_words(ru, politeness)
    if built:
        thai, phonetic, parts = built
        thai, phonetic = _append_politeness(thai, phonetic, politeness)
        parts = parts + [_politeness_part(politeness)]
        if _parts_match_phonetic(phonetic, parts):
            _cache_set(ru_norm, politeness, thai, phonetic, parts)
            print(f"[smart_speaker] words path ok: {len(parts)} parts", file=sys.stderr, flush=True)
            return {"thai": thai, "phonetic": phonetic, "parts": parts}
        print("[smart_speaker] words path lost alignment after politeness", file=sys.stderr, flush=True)

    # 4. Legacy-путь: отдельные phonetic + parts со сверкой строк. Держим как страховку,
    #    чтобы отказ структурированного ответа не оставлял пользователя без перевода.
    llm = _llm_translate_ru_to_th(ru, politeness)
    if not llm:
        raise HTTPException(
            status_code=404,
            detail="LLM translation failed. Check Railway logs for OpenAI errors. Model=" + OPENAI_MODEL,
        )
    thai, phonetic, parts = llm

    phonetic = _normalize_phonetic(phonetic)
    phonetic = _sanitize_phonetic_not_russian_spellout(ru, thai, phonetic)
    thai, phonetic = _apply_politeness(thai, phonetic, politeness)

    if not parts:
        parts = _llm_phrase_parts(ru, thai, phonetic) or []
    parts = _finalize_parts(ru, thai, phonetic, parts)

    # Кэшируем только согласованный результат: битый разбор не должен «залипать» навсегда.
    if _parts_match_phonetic(phonetic, parts):
        _cache_set(ru_norm, politeness, thai, phonetic, parts)

    # Перевод и произношение отдаём всегда — это главное. Разбор только если он сошёлся.
    parts = _aligned_parts_only(phonetic, parts, "legacy")
    return {"thai": thai, "phonetic": phonetic, "parts": parts}


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
    # Тот же инвариант, что и в /smart_speaker: сюда клиент приходит именно за чистым
    # разбором, поэтому отдать полурассыпавшийся — хуже, чем не отдать ничего.
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
    return {
        "status": "ok",
        "steps_json": steps_ok,
        "openai_configured": bool(OPENAI_API_KEY),
        "model": OPENAI_MODEL,
    }
