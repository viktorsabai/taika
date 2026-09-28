"""Thai script -> Taika phonetic (Cyrillic + tone arrows, space-separated syllables)."""
from __future__ import annotations
import re
import unicodedata
from pythainlp.tokenize import syllable_tokenize
from pythainlp.transliterate import romanize

ARROWS = "→↓↘↑↗"
MID, LOW, FALL, HIGH, RISE = "→", "↓", "↘", "↑", "↗"

MID_C = set("กจดตฎฏบปอ")
HIGH_C = set("ขฃฉฐถผฝศษสห")
# everything else with a consonant is low
CONS = set("กขฃคฅฆงจฉชซฌญฎฏฐฑฒณดตถทธนบปผฝพฟภมยรลวศษสหฬอฮ")
STOP_FINALS = set("กขคฆดตถทธปพภบจชซศษสฎฏฐฑฒฌ")
SONORANT_FINALS = set("งนมยวญณรลฬ")
TONE_EK, TONE_THO, TONE_TRI, TONE_CHAT = "่", "้", "๊", "๋"
SHORT_VOWEL_CHARS = set("ะิึุ็")
LONG_VOWEL_CHARS = set("าีืูเแโใไำๅ")
SILENT = "์"
LEAD_H_SONORANTS = set("งญนมยรลว")

# Royin / RTGS cluster → Taika Cyrillic. Longest first.
LATIN_TO_CYR = [
    ("uea", "ыа"), ("oea", "ыа"), ("iao", "иау"), ("uai", "уай"),
    ("aeo", "эу"), ("oei", "ый"), ("uay", "уай"), ("io", "ио"),
    ("eo", "эу"), ("ao", "ау"), ("ai", "ай"), ("oi", "ой"), ("ui", "уй"),
    ("ia", "иа"), ("ua", "уа"), ("ue", "ы"), ("oe", "ы"), ("eu", "ы"),
    ("ae", "э"), ("ee", "и"), ("ii", "и"), ("oo", "у"), ("uu", "у"),
    ("aa", "а"), ("ng", "нг"), ("kh", "кх"), ("ph", "пх"), ("th", "тх"),
    ("ch", "ч"), ("bh", "пх"), ("dh", "тх"), ("gh", "кх"),
    ("a", "а"), ("b", "б"), ("c", "к"), ("d", "д"), ("e", "е"),
    ("f", "ф"), ("g", "г"), ("h", "х"), ("i", "и"), ("j", "дж"),
    ("k", "к"), ("l", "л"), ("m", "м"), ("n", "н"), ("o", "о"),
    ("p", "п"), ("q", "к"), ("r", "р"), ("s", "с"), ("t", "т"),
    ("u", "у"), ("v", "в"), ("w", "в"), ("x", "кс"), ("y", "й"), ("z", "з"),
]
_LATIN_RE = re.compile("|".join(re.escape(k) for k, _ in LATIN_TO_CYR), re.I)
_LATIN_MAP = {k: v for k, v in LATIN_TO_CYR}

# Common royin bugs / Taika spellings
CYR_FIX = {
    "батн": "бат",
    "кхрап": "кхрап",
    "чот": "джот",  # จอด — in good cards often джот
}


def latin_to_cyr(s: str) -> str:
    s = unicodedata.normalize("NFD", s)
    s = re.sub(r"[\u0300-\u036f]", "", s)
    s = _LATIN_RE.sub(lambda m: _LATIN_MAP[m.group(0).lower()], s)
    s = s.lower()
    return CYR_FIX.get(s, s)


def _initial_class(syl: str) -> str:
    chars = [c for c in syl if c in CONS]
    if not chars:
        return "mid"
    # ห + sonorant cluster → high
    if chars[0] == "ห" and len(chars) >= 2 and chars[1] in LEAD_H_SONORANTS:
        return "high"
    # อ as vowel carrier: if first is อ and there's another consonant, skip อ? อ่าน starts with อ
    first = chars[0]
    if first in MID_C:
        return "mid"
    if first in HIGH_C:
        return "high"
    return "low"


def _tone_mark(syl: str) -> str | None:
    if TONE_EK in syl:
        return "ek"
    if TONE_THO in syl:
        return "tho"
    if TONE_TRI in syl:
        return "tri"
    if TONE_CHAT in syl:
        return "chat"
    return None


def _is_dead(syl: str) -> bool:
    body = syl.replace(SILENT, "")
    # drop tone marks
    for t in (TONE_EK, TONE_THO, TONE_TRI, TONE_CHAT):
        body = body.replace(t, "")
    cons = [c for c in body if c in CONS]
    # final consonant: last consonant that isn't a leading cluster-only
    # Heuristic: last char if consonant
    chars = list(body)
    # thanthakhat already removed the killed consonant by replace SILENT - but the consonant remains.
    # Remove consonant immediately before ์ — already stripped ์ so the silent cons is still there.
    # Better: remove C์ pairs first
    raw = syl
    raw = re.sub(r".์", "", raw)
    for t in (TONE_EK, TONE_THO, TONE_TRI, TONE_CHAT):
        raw = raw.replace(t, "")
    # Open short syllable (นะ, และ, กระ, ดุ): the consonant before the vowel is an initial.
    if raw.endswith("ะ") or (raw and raw[-1] in "ิึุ"):
        return True
    # Silent final ร after a stop (บัตร, มิตร, จักร).
    if (
        len(raw) >= 3
        and raw[-1] == "ร"
        and raw[-2] in STOP_FINALS
        and sum(c in CONS for c in raw) >= 3
    ):
        return True
    # trailing stop?
    tail = [c for c in raw if c in CONS or c in SHORT_VOWEL_CHARS or c in LONG_VOWEL_CHARS or c in "ะา"]
    # find last pronounced consonant
    last_c = None
    for c in reversed(raw):
        if c in CONS:
            last_c = c
            break
    has_short = any(c in SHORT_VOWEL_CHARS or c == "ะ" for c in raw)
    has_long = any(c in LONG_VOWEL_CHARS or c == "า" for c in raw)
    if last_c and last_c in STOP_FINALS:
        # if it's the only consonant, it may be initial not final
        cons_all = [c for c in raw if c in CONS]
        if len(cons_all) >= 2 or (len(cons_all) == 1 and has_short and not has_long and last_c != cons_all[0]):
            return True
        if len(cons_all) >= 2:
            return True
        # single consonant + short vowel, no live final → dead (กะ, จะ)
        if has_short and not has_long:
            return True
    if last_c and last_c in SONORANT_FINALS:
        return False
    # no final cons: short open syllable is dead, long is live
    if has_short and not has_long:
        return True
    return False


def tone_arrow(syl: str) -> str:
    mark = _tone_mark(syl)
    cls = _initial_class(syl)
    dead = _is_dead(syl)
    if mark == "tri":
        return HIGH
    if mark == "chat":
        return RISE
    if mark == "ek":
        if cls == "low":
            return FALL
        return LOW
    if mark == "tho":
        if cls == "low":
            return HIGH
        return FALL
    # unmarked
    if cls == "mid":
        return LOW if dead else MID
    if cls == "high":
        return LOW if dead else RISE
    # low
    if not dead:
        return MID
    # dead low: short → high, long → falling
    if "็" in syl or "ะ" in syl or "ั" in syl:
        return HIGH
    has_long = any(c in LONG_VOWEL_CHARS or c == "า" for c in syl)
    # อ / ว after the initial are the long vowels «о» / «уа» (รอบ, ชอบ, บวก).
    if "อ" in syl[1:] or "ว" in syl[1:]:
        has_long = True
    return FALL if has_long else HIGH


# Initial pairs that are one sound, not a hidden «а» syllable.
_ONSET_PAIRS = {
    "กร", "กล", "กว", "ขร", "ขล", "ขว", "คร", "คล", "คว", "ปร", "ปล", "พร", "พล",
    "ผล", "ตร", "บร", "บล", "ดร", "ฟร", "ฟล", "ทร", "จร", "ศร", "สร", "ซร",
}


def _split_hidden_a(syl: str) -> list[str] | None:
    """ขนม → ข + นม, สบาย → ส + บาย, อร่อย → อ + ร่อย. None when not applicable."""
    if len(syl) < 3 or syl[0] not in CONS or syl[1] not in CONS:
        return None
    c1, c2, rest = syl[0], syl[1], syl[2:]
    if c1 + c2 in _ONSET_PAIRS:
        return None
    if c1 == "ห" and c2 in LEAD_H_SONORANTS:
        return None
    if c1 == "อ" and c2 == "ย":
        return None
    # ว between consonants is the vowel «уа» (สวย, ขวด), not an initial.
    if c2 == "ว" and rest.lstrip(TONE_EK + TONE_THO + TONE_TRI + TONE_CHAT)[:1] in CONS:
        return None
    # Leading high/mid consonant lends its class to a sonorant (ขนม, ตลาด, อร่อย).
    if c2 in LEAD_H_SONORANTS and (c1 in HIGH_C or c1 in MID_C):
        return [c1 + "ะ", c1 + c2 + rest]
    return [c1 + "ะ", c2 + rest]


def thai_syllables(
    thai: str, split_hidden: bool = False, repeat: int = 1
) -> list[str]:
    """Thai syllables; ๆ repeats the last `repeat` syllables; punctuation and spaces dropped."""
    out: list[str] = []
    for syl in syllable_tokenize(thai or "", keep_whitespace=False, engine="han_solo"):
        syl = syl.strip()
        if not syl or not re.search(r"[\u0E00-\u0E7F]", syl):
            continue
        if syl == "ๆ":
            out.extend(out[-repeat:])
            continue
        if split_hidden:
            parts = _split_hidden_a(syl)
            if parts:
                out.extend(parts)
                continue
        out.append(syl)
    return out


def thai_syllable_variants(thai: str) -> list[list[str]]:
    """Plausible syllabifications, most literal first — callers pick the one matching a known count."""
    seen: list[list[str]] = []
    for split in (False, True):
        for rep in (1, 2, 3):
            v = thai_syllables(thai, split_hidden=split, repeat=rep)
            if v not in seen:
                seen.append(v)
            if "ๆ" not in thai:
                break
    return seen


# Same chunking as iOS `translitChunksForSyllables` and /assess syllable_contract.
_CHUNK_SPLIT = re.compile(r"(\s+|[-·])")


def retone_phonetic(thai: str, phonetic: str) -> str | None:
    """Rewrite only the tone arrows of an authored phonetic from Thai spelling.

    Letters and separators stay as written. None when the Thai syllables can't be
    aligned 1:1 with the phonetic chunks (hidden linking vowels, Latin, ครับ/ค่ะ).
    """
    if not thai or not phonetic or "/" in thai or re.search(r"[A-Za-z0-9]", thai):
        return None
    pieces = _CHUNK_SPLIT.split(phonetic)
    slots = [
        i for i, p in enumerate(pieces)
        if p and not _CHUNK_SPLIT.fullmatch(p) and p.strip(ARROWS)
    ]
    syls = next((v for v in thai_syllable_variants(thai) if len(v) == len(slots)), None)
    if syls is None:
        return None
    for i, syl in zip(slots, syls):
        letters = "".join(ch for ch in pieces[i] if ch not in ARROWS)
        pieces[i] = letters + tone_arrow(syl)
    return "".join(pieces)


def thai_to_taika(thai: str) -> str:
    thai = (thai or "").strip()
    if not thai:
        return ""
    # particles are a speaker attribute, not part of the phrase
    thai = re.sub(r"ครับ\s*/\s*ค่ะ|ครับ\s*/\s*คะ|ค่ะ\s*/\s*ครับ", " ", thai)
    if re.sub(r"\s+", "", thai) not in {"ครับ", "ค่ะ", "คะ"}:
        thai = re.sub(r"ครับ|ค่ะ", " ", thai)
    thai = re.sub(r"\s+", " ", thai).strip()
    thai = thai.replace("ผม/ฉัน", "ผม").replace("ฉัน/ผม", "ผม")
    parts = []
    for syl in syllable_tokenize(thai, keep_whitespace=False):
        if not syl.strip() or syl.isspace():
            continue
        if not re.search(r"[\u0E00-\u0E7F]", syl):
            # keep latin loanwords as cyrillic-letter spelling if any
            if re.search(r"[A-Za-z]", syl):
                parts.append(latin_to_cyr(syl) + MID)
            continue
        rom = romanize(syl, engine="royin")
        cyr = latin_to_cyr(rom)
        if not cyr:
            continue
        parts.append(cyr + tone_arrow(syl))
    return " ".join(parts)


def diacritic_line_to_arrows(ph: str) -> str:
    """Cyrillic/latin with Paiboon marks → Taika arrows. Unmarked chunk gets mid."""
    ph = unicodedata.normalize("NFD", ph or "")
    ph = ph.replace("/", " ")
    # map combining
    cmap = {"\u0300": LOW, "\u0301": HIGH, "\u0302": FALL, "\u030c": RISE, "\u0306": MID}
    out_tokens = []
    for raw in re.split(r"[\s\-]+", ph):
        if not raw:
            continue
        arrow = MID
        letters = []
        for ch in raw:
            if ch in cmap:
                arrow = cmap[ch]
            elif ch in ARROWS:
                arrow = ch
            else:
                letters.append(ch)
        token = "".join(letters)
        token = latin_to_cyr(token) if re.search(r"[A-Za-z]", token) else token
        token = re.sub(r"[^а-яёА-ЯЁ]", "", token)
        if not token:
            continue
        out_tokens.append(token.lower() + arrow)
    return " ".join(out_tokens)
