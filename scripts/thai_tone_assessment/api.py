#!/usr/bin/env python3
"""
Minimal FastAPI server for Thai tone assessment (Phase C).
POST /assess: multipart form with "file" (audio) + "text" (Thai target); returns Phase D–compatible JSON.
"""
from __future__ import annotations

import asyncio
import difflib
import importlib
import sqlite3
import subprocess
import sys
import tempfile
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


def _strip_trailing_politeness(thai: str, phonetic: str) -> tuple[str, str]:
    """Убирает ครับ/ค่ะ и кхрап/кха с конца, чтобы не дублировать при _apply_politeness."""
    for _ in range(2):  # макс 2 итерации (на случай двойного кхрап)
        thai = re.sub(r"\s*(ครับ|ค่ะ)\s*$", "", thai).strip()
        phonetic = re.sub(r"\s*(кхрап↘|кхрап\s*↘|кха↘|кха\s*↘)\s*$", "", phonetic).strip()
    return thai, phonetic


# Thai script range: U+0E00–U+0E7F (буквы тайского алфавита)
_THAI_SCRIPT_RE = re.compile(r"[\u0E00-\u0E7F]+")


def _strip_thai_from_phonetic(phonetic: str) -> str:
    """Убирает тайские символы из phonetic — поле должно быть только кириллица."""
    return _THAI_SCRIPT_RE.sub("", phonetic)


def _has_thai_script(s: str) -> bool:
    return bool(_THAI_SCRIPT_RE.search(s))


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


def _normalize_phonetic(phonetic: str) -> str:
    """Убирает IPA, латиницу в фонетике, тайский скрипт; оставляет кириллицу и стрелки →↓↘↑↗."""
    replacements = [
        ("ū", "у"), ("ē", "е"), ("ā", "а"), ("ī", "и"), ("ō", "о"),
        ("í", "и"), ("ú", "у"), ("é", "е"), ("ó", "о"), ("á", "а"),
        ("ɛ", "е"), ("ɪ", "и"), ("ɔ", "о"), ("ʌ", "а"), ("ə", "э"),
        ("ʃ", "ш"), ("ʒ", "ж"), ("ŋ", "нг"), ("ɲ", "нь"),
        ("dʒ", "дж"), ("tʃ", "ч"),
        ("ʰ", ""), ("ʹ", ""), ("ʿ", ""), ("ʻ", ""), ("ˈ", ""), ("ˌ", ""),
    ]
    out = _strip_thai_from_phonetic(phonetic)
    for old, new in replacements:
        out = out.replace(old, new)
    for bad, good in _PHONETIC_ARROW_FIXUPS:
        out = out.replace(bad, good)
    out = _fix_latin_i_in_phonetic(out)
    out = re.sub(r"\s+", " ", out).strip()
    out = _collapse_letter_space_arrow(out)
    return out


def _apply_politeness(thai: str, phonetic: str, politeness: str) -> tuple[str, str]:
    thai, phonetic = _strip_trailing_politeness(thai, phonetic)
    p = (politeness or "female").strip().lower()
    ph = phonetic.strip()
    if p == "male":
        th2 = (thai + " ครับ").strip()
        ph2 = (ph + " кхрап↘").strip() if ph else ""
        return th2, ph2
    if p in ("female", "kathoey"):
        th2 = (thai + " ค่ะ").strip()
        ph2 = (ph + " кха↘").strip() if ph else ""
        return th2, ph2
    return thai, phonetic


class SmartSpeakerReq(BaseModel):
    text_ru: str
    politeness: str | None = "female"


class ThaiPhoneticReq(BaseModel):
    """Тайский текст (например с ASR) → кириллическая фонетика в стиле taikA (как в /smart_speaker)."""

    text_th: str


# --- Smart Speaker: SQLite cache для переводов (экономия API-запросов) ---

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
                created_at INTEGER DEFAULT (strftime('%s', 'now')),
                PRIMARY KEY (text_ru_norm, politeness)
            )
        """)
        conn.commit()


def _cache_get(text_ru_norm: str, politeness: str) -> tuple[str, str] | None:
    p = (politeness or "female").strip().lower()
    if p not in ("male", "female", "kathoey"):
        p = "female"
    try:
        with sqlite3.connect(_cache_db_path()) as conn:
            row = conn.execute(
                "SELECT thai, phonetic FROM translations WHERE text_ru_norm = ? AND politeness = ?",
                (text_ru_norm, p),
            ).fetchone()
            if row:
                return (row[0], row[1])
    except Exception as e:
        print(f"[smart_speaker] cache get error: {e}", file=sys.stderr, flush=True)
    return None


def _cache_set(text_ru_norm: str, politeness: str, thai: str, phonetic: str) -> None:
    p = (politeness or "female").strip().lower()
    if p not in ("male", "female", "kathoey"):
        p = "female"
    try:
        with sqlite3.connect(_cache_db_path()) as conn:
            conn.execute(
                "INSERT OR REPLACE INTO translations (text_ru_norm, politeness, thai, phonetic) VALUES (?, ?, ?, ?)",
                (text_ru_norm, p, thai, phonetic),
            )
            conn.commit()
    except Exception as e:
        print(f"[smart_speaker] cache set error: {e}", file=sys.stderr, flush=True)


# Инициализация при импорте
_init_cache_db()

OPENAI_API_KEY = (os.getenv("OPENAI_API_KEY") or "").strip()
OPENAI_MODEL = (os.getenv("TAIKA_SMART_MODEL") or "gpt-4o-mini").strip()


def _llm_translate_ru_to_th(ru: str, politeness: str | None) -> tuple[str, str] | None:
    """
    Fallback when нет точного совпадения в steps.json.
    Использует OpenAI Chat API, если задан OPENAI_API_KEY.
    Возвращает (thai, phonetic) или None при ошибке.
    """
    if not OPENAI_API_KEY:
        return None

    p = (politeness or "female").strip().lower()
    if p not in ("male", "female", "kathoey"):
        p = "female"

    system = (
        "You are a Thai teacher for Russian speakers. You output JSON with two DIFFERENT things:\n\n"
        "1) \"thai\" — the answer in Thai script (what a Thai person would say).\n"
        "2) \"phonetic\" — ONLY the pronunciation of THAT Thai sentence written in Russian Cyrillic letters + tone arrows. "
        "This is **Thai-to-Cyrillic**: each **Thai syllable** (by Thai spelling) becomes one Cyrillic chunk + one arrow (→↓↘↑↗). "
        "It must sound like Thai, NOT like Russian. It must NOT repeat, spell, or syllabify the original Russian prompt.\n\n"
        "Phonetic format (STRICT):\n"
        "- Cyrillic а-я/ё only, plus hyphens inside a syllable, spaces between words. NO Thai letters in phonetic. NO Latin. NO IPA.\n"
        "- For the vowel sound [i] use ONLY Cyrillic «и»/«И», never Latin I or i.\n"
        "- One tone arrow glued to the end of each syllable chunk (no space before the arrow). "
        "Use ONLY these five: → ↓ ↘ ↑ ↗ (mid/low/falling/rising/high). Never ↕ ↔ or other arrows.\n"
        "- Good example: Russian «Как дела?» → thai might be «สบายดีไหม» → phonetic like «са-бай↘ ди↗-май↗» (sounds of Thai words).\n"
        "- BAD: any phonetic whose letters read as the Russian question (e.g. «как→ де→ла») — forbidden.\n"
        "- Do NOT add ครับ/ค่ะ or кхрап/кха in output — we append politeness on the server.\n\n"
        "Workflow: first choose correct \"thai\", then write \"phonetic\" by reading **left-to-right through \"thai\"** "
        "(Thai syllable boundaries), transcribing each syllable’s Thai pronunciation into Cyrillic.\n"
        "If the Russian input is a question (?), \"thai\" should be a natural Thai question; \"phonetic\" still reflects only that Thai.\n\n"
        "Return JSON: {\"thai\": \"...\", \"phonetic\": \"...\"}."
    )

    is_question = (ru.rstrip()).endswith("?")
    hint = " (question)" if is_question else ""
    user = (
        f"Russian phrase: {ru!r}{hint}.\n"
        "Return thai + phonetic. Remember: phonetic = how to pronounce the **Thai** words you put in \"thai\", "
        "syllable by syllable in Cyrillic — not a transliteration of this Russian sentence."
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
                    return thai, p2n
            retried2 = _llm_translate_ru_to_th_retry(thai)
            if retried2:
                _, p3 = retried2
                p3n = _normalize_phonetic(p3)
                if p3n and not _phonetic_is_spelled_russian_source(ru, p3n):
                    return thai, p3n
            return thai, ""
        return thai, phon
    except Exception as e:  # pragma: no cover - defensive
        print(f"[smart_speaker] parse error: {e}", file=sys.stderr, flush=True)
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
        "- Omit final ครับ/ค่ะ from your mental syllable count if you transcribe them as separate particles — "
        "server may strip them; you may still write кхрап/кха if those appear in the Thai string.\n"
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
    politeness = req.politeness or "female"
    print(f"[smart_speaker] ru={ru!r} ru_norm={ru_norm!r} politeness={politeness}", file=sys.stderr, flush=True)

    # 1. Cache lookup — если уже переводили, возвращаем из кэша (нормализуем на всякий случай)
    cached = _cache_get(ru_norm, politeness)
    if cached:
        thai, phonetic = cached
        phonetic = _normalize_phonetic(phonetic)
        phonetic = _sanitize_phonetic_not_russian_spellout(ru, thai, phonetic)
        thai, phonetic = _strip_trailing_politeness(thai, phonetic)
        thai, phonetic = _apply_politeness(thai, phonetic, politeness)
        return {"thai": thai, "phonetic": phonetic}

    # 2. Steps.json — точное совпадение
    idx = _load_steps_index()
    hit = idx.get(ru_norm)
    if hit:
        thai, phonetic = hit
    else:
        # 3. LLM — генерация (если настроен OPENAI_API_KEY)
        if not OPENAI_API_KEY:
            print("[smart_speaker] OPENAI_API_KEY not set, cannot translate", file=sys.stderr, flush=True)
            raise HTTPException(status_code=404, detail="no match and OPENAI_API_KEY not set in Railway Variables")
        llm = _llm_translate_ru_to_th(ru, politeness)
        if not llm:
            raise HTTPException(
                status_code=404,
                detail="LLM translation failed. Check Railway logs for OpenAI errors. Model=" + OPENAI_MODEL,
            )
        thai, phonetic = llm

    phonetic = _normalize_phonetic(phonetic)
    phonetic = _sanitize_phonetic_not_russian_spellout(ru, thai, phonetic)
    thai, phonetic = _apply_politeness(thai, phonetic, politeness)

    # 4. Сохраняем в кэш (с учётом politeness — результат уже с кхрап/кха)
    _cache_set(ru_norm, politeness, thai, phonetic)

    return {"thai": thai, "phonetic": phonetic}


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


@app.get("/health")
async def health():
    steps_ok = _steps_path().is_file()
    return {
        "status": "ok",
        "steps_json": steps_ok,
        "openai_configured": bool(OPENAI_API_KEY),
        "model": OPENAI_MODEL,
    }
