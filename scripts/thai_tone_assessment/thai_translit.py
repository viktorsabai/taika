"""
Кириллица Taika из тайского — без модели.

1. Произношение слова берём из словаря-модели PyThaiNLP w2p: она переписывает слово
   так, как его читают (โทรศัพท์ → โท-ระ-สับ, ทราบ → ซาบ, ศูนย์ → สูน), со скрытыми
   гласными и нерегулярными чтениями.
2. Каждый переписанный слог разбираем по правилам письма: начальная согласная,
   гласная, конечная.
3. Собираем кириллицу по стандарту курса (большинство написаний в steps.json):
   ข/ค → кх, จ → дж, ฉ → чх, ช → ч, ถ/ธ → тх, ท → т, พ/ผ → пх, долгота не удваивается.

Тон слога сюда не входит — его ставит speaker_quality по написанию.
"""
from __future__ import annotations

import functools
import re
import sys

CONS = "กขฃคฅฆงจฉชซฌญฎฏฐฑฒณดตถทธนบปผฝพฟภมยรลวศษสหฬอฮ"
LEAD = "เแโใไ"
TONE_MARKS = "\u0e48\u0e49\u0e4a\u0e4b"
PHINTHU = "\u0e3a"
THANTHAKHAT = "\u0e4c"

ONSET = {
    "ก": "к", "ข": "кх", "ฃ": "кх", "ค": "кх", "ฅ": "кх", "ฆ": "кх", "ง": "нг",
    "จ": "дж", "ฉ": "чх", "ช": "ч", "ฌ": "ч", "ซ": "с", "ญ": "й", "ฎ": "д", "ฏ": "т",
    "ฐ": "тх", "ฑ": "т", "ฒ": "тх", "ณ": "н", "ด": "д", "ต": "т", "ถ": "тх", "ท": "т",
    "ธ": "тх", "น": "н", "บ": "б", "ป": "п", "ผ": "пх", "ฝ": "ф", "พ": "пх", "ฟ": "ф",
    "ภ": "пх", "ม": "м", "ย": "й", "ร": "р", "ล": "л", "ว": "в", "ศ": "с", "ษ": "с",
    "ส": "с", "ห": "х", "ฬ": "л", "อ": "", "ฮ": "х",
}
CODA = {
    **{c: "к" for c in "กขคฆ"},
    **{c: "т" for c in "จชซฌฎฏฐฑฒดตถทธศษส"},
    **{c: "п" for c in "บปพฟภ"},
    "ง": "нг", "ม": "м", "ย": "й", "ว": "у",
    **{c: "н" for c in "ญณนรลฬ"},
}
CLUSTER_SECOND = {"ร": "р", "ล": "л", "ว": "в"}
ONSET_PAIRS = {
    "กร", "กล", "กว", "ขร", "ขล", "ขว", "คร", "คล", "คว", "ปร", "ปล", "พร", "พล",
    "ผล", "ตร", "บร", "บล", "ดร", "ฟร", "ฟล",
}
SONORANTS = set("งญนมยรลว")
IOTATED = {"а": "я", "у": "ю"}


def _strip_marks(s: str) -> str:
    return "".join(ch for ch in s if ch not in TONE_MARKS)


def _drop_silent(s: str) -> str:
    """Буква под ์ не читается (вместе с гласной над ней): ศูนย์ → ศูน, สัปดาห์ → สัปดา."""
    s = re.sub(r"[ทต]ร" + THANTHAKHAT, "", s)
    return re.sub(r"[" + CONS + r"][ิุ]?" + THANTHAKHAT, "", s)


def _onset(s: str, lead: str = "") -> tuple[str, str, bool]:
    """(кириллица начала, остаток слога, был ли кластер)."""
    # ไหม, เหมือน: ห перед сонорной только задаёт тон. อ немая лишь в อย (อย่า, อยู่):
    # в โอน, เอง она — начальная согласная.
    if lead and len(s) >= 2 and s[0] == "ห" and s[1] in SONORANTS:
        return ONSET[s[1]], s[2:], False
    if not s or s[0] not in CONS:
        return "", s, False
    c1 = s[0]
    rest = s[1:]
    if rest.startswith(PHINTHU) and len(rest) > 1 and rest[1] in CONS:
        c2 = rest[1]
        rest = rest[2:]
        if c1 in "หอ":
            return ONSET[c2], rest, False
        return ONSET[c1] + CLUSTER_SECOND.get(c2, ONSET[c2]), rest, True
    if c1 == "ห" and rest[:1] == "ว" and len(rest) == 2 and rest[1] in CONS:
        # ห้วน, หวง: ว здесь гласная «уа», ห — начальная.
        return ONSET["ห"], rest, False
    if c1 == "ห" and rest[:1] in SONORANTS and len(rest) > 1:
        return ONSET[rest[0]], rest[1:], False
    if c1 == "อ" and rest[:1] == "ย" and len(rest) > 1:
        return ONSET["ย"], rest[1:], False
    if rest[:2] == "รร":
        return ONSET[c1], rest, False
    if rest[:1] == "ร" and len(rest) > 1:
        # ทร читается «с» (ทราย, ทรง), после จ/ศ/ส/ซ ร немая (จริง, สร้าง, ศรี).
        if c1 == "ท":
            return "с", rest[1:], False
        if c1 in "จศสซ":
            return ONSET[c1], rest[1:], False
    if rest[:1] in CLUSTER_SECOND and c1 + rest[0] in ONSET_PAIRS:
        after = rest[1:2]
        if rest[0] == "ว":
            # ขวา, ความ — кластер; กวน, แก้ว — ว это гласная «уа» или конечная «у».
            is_cluster = bool(after) and after not in CONS
        else:
            is_cluster = bool(after) or bool(lead)
        if is_cluster:
            return ONSET[c1] + CLUSTER_SECOND[rest[0]], rest[1:], True
    return ONSET[c1], rest, False


def _coda(tail: str) -> str | None:
    """Конечная согласная или None, если хвост не одна согласная."""
    if tail == "":
        return ""
    if len(tail) == 1 and tail in CODA:
        return CODA[tail]
    # บัตร, สมัคร, เพชร, มิตร: ร после конечной не читается.
    if len(tail) == 2 and tail[1] == "ร" and tail[0] in CODA:
        return CODA[tail[0]]
    return None


def _vowel_and_coda(lead: str, r: str) -> tuple[str, str] | None:
    """r — всё после начальной согласной (без тоновых меток)."""
    def with_tail(v: str, tail: str) -> tuple[str, str] | None:
        c = _coda(tail)
        return None if c is None else (v, c)

    if lead == "เ":
        for pat, v in (
            ("ียะ", "иа"), ("ือะ", "ыа"), ("าะ", "о"), ("อะ", "ё"),
        ):
            if r == pat:
                return v, ""
        if r == "า":
            return "ау", ""
        if r.startswith("ีย"):
            return with_tail("иа", r[2:])
        if r.startswith("ือ"):
            return with_tail("ыа", r[2:])
        if r == "อ":
            return "ё", ""
        if r.startswith("ิ"):
            return with_tail("ё", r[1:])
        if r == "ย":
            return "ёй", ""
        if r.startswith("็"):
            return with_tail("е", r[1:])
        if r == "ะ":
            return "е", ""
        return with_tail("е", r)
    if lead == "แ":
        if r == "ะ":
            return "э", ""
        if r.startswith("็"):
            return with_tail("э", r[1:])
        return with_tail("э", r)
    if lead == "โ":
        if r == "ะ":
            return "о", ""
        return with_tail("о", r)
    if lead in ("ใ", "ไ"):
        if r in ("", "ย"):
            return "ай", ""
        return None

    if r == "ะ":
        return "а", ""
    if r.startswith("รร"):
        # ธรรม = тхам, บรร = бан: รร даёт «а», а без конечной — «ан».
        return ("а", "н") if r == "รร" else with_tail("а", r[2:])
    if r.startswith("ัว"):
        return with_tail("уа", r[2:])
    if r.startswith("ั"):
        return with_tail("а", r[1:])
    if r.startswith("ำ"):
        return "ам", ""
    if r.startswith("า"):
        return with_tail("а", r[1:])
    if r.startswith("ิ") or r.startswith("ี"):
        return with_tail("и", r[1:])
    if r.startswith("ึ"):
        return with_tail("ы", r[1:])
    if r.startswith("ือ"):
        return with_tail("ы", r[2:])
    if r.startswith("ื"):
        return with_tail("ы", r[1:])
    if r.startswith("ุ") or r.startswith("ู"):
        return with_tail("у", r[1:])
    if r.startswith("็อ"):
        return with_tail("о", r[2:])
    if r.startswith("อ"):
        return with_tail("о", r[1:])
    if r.startswith("ว") and len(r) == 2 and r[1] in CONS:
        return with_tail("уа", r[1:])
    if r == "":
        return "о", ""
    if len(r) == 1 and r in CONS:
        return with_tail("о", r)
    return None


def syllable_to_cyrillic(syl: str) -> str | None:
    """Один слог в правильной (переписанной w2p) орфографии → кириллица без тона."""
    s = _strip_marks(_drop_silent(syl or ""))
    if not s:
        return None
    lead = ""
    if s[0] in LEAD:
        lead, s = s[0], s[1:]
    onset, rest, _cluster = _onset(s, lead)
    if not s or s[0] not in CONS:
        return None
    vc = _vowel_and_coda(lead, rest)
    if vc is None:
        return None
    vowel, coda = vc
    if onset == "й" and vowel[:1] in IOTATED:
        out = IOTATED[vowel[0]] + vowel[1:]
    else:
        out = onset + vowel
    return out + coda


@functools.lru_cache(maxsize=1)
def _w2p():
    try:
        from pythainlp.transliterate import pronunciate  # noqa: PLC0415

        pronunciate("ปี", engine="w2p")
        return pronunciate
    except Exception as e:  # noqa: BLE001
        print(f"[thai_translit] w2p unavailable: {e}", file=sys.stderr, flush=True)
        return None


@functools.lru_cache(maxsize=8192)
def spoken_syllables(word: str) -> tuple[str, ...]:
    """Слоги слова так, как их читают (переписанные правильной орфографией)."""
    w = re.sub(r"\s+", "", word or "")
    if not w:
        return ()
    fn = _w2p()
    if fn is None:
        return ()
    try:
        out = fn(w, engine="w2p")
    except Exception:  # noqa: BLE001
        return ()
    return tuple(p for p in re.split(r"[-\s]+", out or "") if p)


def _letters(syls) -> list[str] | None:
    out: list[str] = []
    for s in syls:
        c = syllable_to_cyrillic(s)
        if not c:
            return None
        out.append(c)
    return out or None


def _cluster_of(syl: str) -> tuple[str, str] | None:
    """(первая согласная, вторая) если слог по написанию начинается с кластера."""
    s = _strip_marks(_drop_silent(syl or ""))
    lead = ""
    if s and s[0] in LEAD:
        lead, s = s[0], s[1:]
    if len(s) < 2:
        return None
    _, _, cluster = _onset(s, lead)
    if cluster and s[1] != PHINTHU:
        return s[0], s[1]
    if cluster:
        return s[0], s[2]
    return None


def _restore_clusters(spoken: list[str], ortho: list[str], letters: list[str]) -> list[str]:
    """
    w2p иногда роняет второй звук кластера (กระเป๋า → กะ-เป๋า, ประจำ → ปะ-จำ).
    Если слоги совпали по счёту, а в написании кластер есть — возвращаем его.
    """
    if len(spoken) != len(ortho):
        return letters
    out = list(letters)
    for i, (sp, orth) in enumerate(zip(spoken, ortho)):
        want = _cluster_of(orth)
        if not want or _cluster_of(sp):
            continue
        c1, c2 = want
        head = ONSET[c1]
        if out[i].startswith(head) and CLUSTER_SECOND.get(c2):
            out[i] = head + CLUSTER_SECOND[c2] + out[i][len(head):]
    return out


def _merge_w2p_splits(spoken: list[str], ortho: list[str]) -> list[str]:
    """
    Склейки, которые w2p иногда рвёт:
    กรุงเทพ → กะ-รุง (в написании кластер กร), เหมาะ → เห-มาะ (ห лишь задаёт тон).
    """
    pairs = {c for o in ortho if (c := _cluster_of(o))}
    written = "".join(ortho)
    # กลับ → กะ-หฺลับ: ะ w2p вставил сам, а в написании пара กล подряд.
    pairs |= {
        (a, b) for a, b in zip(written, written[1:])
        if a + b in ONSET_PAIRS and b != "ว" and a + "ะ" not in written
    }
    out: list[str] = []
    i = 0
    while i < len(spoken):
        cur = _strip_marks(spoken[i])
        nxt = spoken[i + 1] if i + 1 < len(spoken) else ""
        if nxt and len(cur) == 2 and cur[1] == "ะ" and (cur[0], nxt[0]) in pairs:
            out.append(cur[0] + PHINTHU + nxt)
            i += 2
            continue
        bare = nxt.replace(PHINTHU, "")
        if (nxt and len(cur) == 2 and cur[1] == "ะ" and len(bare) > 1 and bare[0] == "ห"
                and (cur[0], bare[1]) in pairs):
            out.append(cur[0] + PHINTHU + bare[1:])
            i += 2
            continue
        if nxt and cur in ("เห", "แห", "โห") and nxt[0] in SONORANTS:
            out.append(cur[0] + "ห" + nxt.lstrip(LEAD) if nxt[0] not in LEAD else nxt)
            i += 2
            continue
        out.append(spoken[i])
        i += 1
    return out


# Звуковой класс начальной согласной: w2p может заменить букву на созвучную
# (ศูนย์ → สูน), но не на другой звук (อย่าง → หฺว่าง — ошибка модели).
_SOUND = {}
for _cls, _letters_ in (
    ("k", "กขฃคฅฆ"), ("ng", "ง"), ("j", "จ"), ("ch", "ฉชฌ"), ("s", "ซศษส"), ("y", "ญย"),
    ("d", "ฎด"), ("t", "ฏตฐฑฒถทธ"), ("n", "ณน"), ("b", "บ"), ("p", "ปผพภ"), ("f", "ฝฟ"),
    ("m", "ม"), ("r", "ร"), ("l", "ลฬ"), ("w", "ว"), ("h", "หฮ"), ("q", "อ"),
):
    for _c in _letters_:
        _SOUND[_c] = _cls


def _initial_sound(syl: str) -> str | None:
    s = _strip_marks(syl or "").lstrip(LEAD)
    if len(s) >= 2 and s[0] in "หอ" and (s[1] == PHINTHU or s[1] in SONORANTS):
        s = s[2:] if s[1] == PHINTHU else s[1:]
    return _SOUND.get(s[:1])


def _w2p_agrees(spoken_syl: str, ortho_syl: str) -> bool:
    want = _initial_sound(spoken_syl)
    if want is None:
        return False
    have = {_SOUND.get(c) for c in ortho_syl if c in _SOUND}
    if "ทร" in ortho_syl:
        have.add("s")
    return want in have


# Готовые (кириллица, слоги-источник тона). Курс и слух, а не общее правило:
# ชื่อ — «чыу», хотя ือ обычно «ы»; รัสเซีย держит «с», не тайскую конечную «т»;
# เงิน — «нген», как в карточках, а не «нгён».
_HOUSE_READING: dict[str, tuple[tuple[str, ...], tuple[str, ...]]] = {
    "ชื่อ": (("чыу",), ("ชื่อ",)),
    "รัสเซีย": (("рас", "сиа"), ("รัส", "เซีย")),
    "เงิน": (("нген",), ("เงิน",)),
    "อยาก": (("яак",), ("อยาก",)),
    "เซเว่น": (("се", "вен"), ("เซ", "เว่น")),
    "อีเลฟเว่น": (("и", "леф", "вен"), ("อี", "เลฟ", "เว่น")),
    "เซเว่นอีเลฟเว่น": (("се", "вен", "и", "леф", "вен"), ("เซ", "เว่น", "อี", "เลฟ", "เว่น")),
    "เปอร์เซ็นต์": (("пё", "сент"), ("เปอ", "เซ็น",)),
}

# Слова, которые и правила, и w2p читают неверно. Значение — переписанное чтение.
_EXCEPTIONS: dict[str, tuple[str, ...]] = {
    "โทร": ("โท",),
    "ก็": ("ก้อ",),
    "เทรน": ("เทฺรน",),
    "เทรนด์": ("เทฺรน",),
    "เทรนเนอร์": ("เทฺรน", "เน่อ"),
    "พาสปอร์ต": ("พาส", "สะ", "ป็อด"),
    "อพยพ": ("อบ", "พะ", "ยบ"),
    "ไอศกรีม": ("ไอ", "สะ", "กฺรีม"),
    "อัลตราซาวนด์": ("อัน", "ตฺรา", "ซาว"),
    "ประวัติศาสตร์": ("ปฺระ", "หฺวัด", "ติ", "สาด"),
    "สรรพสินค้า": ("สับ", "พะ", "สิน", "ค้า"),
    "กระดาษชำระ": ("กฺระ", "ดาด", "ชำ", "ระ"),
    "โทรศัพท์": ("โท", "ระ", "สับ"),
    "โทรทัศน์": ("โท", "ระ", "ทัด"),
    "สุขสันต์": ("สุก", "สัน"),
    "จักรยาน": ("จัก", "กฺระ", "ยาน"),
    "สัตวแพทย์": ("สัด", "ตะ", "วะ", "แพด"),
    "เอ็กซเรย์": ("เอ็ก", "ซะ", "เร"),
}
def _newmm(text: str) -> list[str]:
    try:
        from pythainlp.tokenize import word_tokenize  # noqa: PLC0415

        return [t for t in word_tokenize(text, engine="newmm", keep_whitespace=False) if t.strip()]
    except Exception:  # noqa: BLE001
        return [text]


# Грубые классы: в конце слога ส/จ/ช/ด/ท звучат одинаково (т), w2p их взаимно переписывает.
_LOOSE = {}
for _cls, _letters_ in (
    ("k", "กขฃคฅฆ"), ("ng", "ง"), ("t", "จฉชฌซศษสฎดฏตฐฑฒถทธ"), ("y", "ญย"),
    ("n", "ณน"), ("p", "บปผพภฝฟ"), ("m", "ม"), ("r", "ร"), ("l", "ลฬ"),
    ("w", "ว"), ("h", "หฮ"),
):
    for _c in _letters_:
        _LOOSE[_c] = _cls


def _no_foreign(syllables, spoken) -> bool:
    """В чтении нет звуков, которых нет в написании (กลัว → กอน-วัว выдумало น)."""
    word = "".join(syllables)
    have = {_LOOSE[c] for c in word if c in _LOOSE} | {"h", "w", "y"}
    if any(len(s) > 1 and s[-1] in "รลฬญณ" for s in syllables):
        have.add("n")
    if "ำ" in word:
        have.add("m")
    if "ฤ" in word:
        have.add("r")
    return all(_LOOSE[c] in have for syl in spoken for c in syl if c in _LOOSE)


def _trust_w2p(syllables, spoken, min_syllables: int | None = None) -> bool:
    """
    Чтение w2p правдоподобно: не потеряло звуков, не выдумало новых и не добавило
    слогов сверх вставных «Cะ» скрытых гласных (กลัว → กล-หฺวัว отбрасываем).
    """
    if not spoken:
        return False
    if min_syllables is not None:
        if len(spoken) - sum(_is_filler(s) for s in spoken) > min_syllables:
            return False
        # สวน → สะ-วะ-นะ: вставных слогов не бывает больше, чем настоящих.
        if len(spoken) > 2 * min_syllables:
            return False
    return _covers(syllables, spoken) and _no_foreign(syllables, spoken)


def _skeleton(syllables) -> list[str]:
    """Звучащие согласные подряд (грубые классы), без ห/อ и немых; ำ даёт «м»."""
    out: list[str] = []
    for syl in syllables:
        for c in _strip_marks(_drop_silent(syl or "")):
            if c == "ำ":
                out.append("m")
            elif c in _LOOSE and c != "ห":
                out.append(_LOOSE[c])
    return out


_EXPLICIT_VOWEL = set("ะัาำิีึืุูเแโใไๅอ็ฤ")


def _has_explicit_vowel(syl: str) -> bool:
    return any(c in _EXPLICIT_VOWEL for c in syl or "")


def _spelled_sounds(syllables) -> list[str]:
    """
    Согласные, которые обязаны прозвучать: без немых (์, ร в ทร/จร/ศร/สร и после
    конечной, ห перед сонорной). Конечные ร/ล/ญ/ณ звучат как «н».
    """
    out: list[str] = []
    for syl in syllables:
        s = _strip_marks(_drop_silent(syl or ""))
        cons_idx = [i for i, c in enumerate(s) if c in CONS]
        last = len(s) - 1 if len(cons_idx) > 1 and s[-1] in CONS else -1
        for i, c in enumerate(s):
            if c not in _LOOSE or c in "วย":
                continue
            prev = s[i - 1] if i else ""
            nxt = s[i + 1] if i + 1 < len(s) else ""
            if c == "ร" and ((prev and prev in "ทจศสซ") or nxt == "ร" or prev == "ร"):
                continue
            if c == "ร" and i == last and prev in CODA and i - 1 in cons_idx and i - 1 != cons_idx[0]:
                continue
            if c == "ห" and nxt in SONORANTS:
                continue
            if i == last and c in "รลฬญณ":
                out.append("n")
                continue
            out.append(_LOOSE[c])
    return out


def _covers(syllables, spoken: list[str]) -> bool:
    """Чтение w2p не потеряло ни одной звучащей согласной слова (หรือยัง → หฺย-อง потеряло ร)."""
    have: dict[str, int] = {}
    for syl in spoken:
        for c in syl:
            snd = "m" if c == "ำ" else _LOOSE.get(c)
            if snd:
                have[snd] = have.get(snd, 0) + 1
    for snd in _spelled_sounds(syllables):
        if have.get(snd, 0) <= 0:
            return False
        have[snd] -= 1
    return True


def _is_filler(syl: str) -> bool:
    """Вставной слог скрытой гласной: ระ в โท-ระ-สับ, ชะ в ราด-ชะ-กาน, ขะ в ขะ-หฺนม."""
    s = _strip_marks(syl or "").replace(PHINTHU, "")
    if s.startswith("ห") and len(s) == 3:
        s = s[1:]
    if len(s) == 3 and s[0] in CONS and s[1] in CLUSTER_SECOND and s[2] == "ะ":
        return True
    return len(s) == 2 and s[0] in CONS and s[1] in "ะอ"


def _piecewise(syllables: list[str]) -> tuple[list[str], list[str]] | None:
    """w2p по каждому слогу написания отдельно — для составных токенов, где w2p путается."""
    letters: list[str] = []
    sources: list[str] = []
    for orth in syllables:
        pieces = [p for p in spoken_syllables(orth)] if orth not in _EXCEPTIONS else list(_EXCEPTIONS[orth])
        pieces = _merge_w2p_splits(pieces, [orth])
        piece_letters = _letters(pieces)
        if orth not in _EXCEPTIONS and _has_explicit_vowel(orth) and len(pieces) == 1:
            piece_letters = None
        floor = 1 if syllable_to_cyrillic(orth) else None
        if piece_letters and _trust_w2p([orth], pieces, floor) and _w2p_agrees(pieces[0], orth):
            letters.extend(_restore_clusters(pieces, [orth] * len(pieces), piece_letters)
                           if len(pieces) == 1 else piece_letters)
            sources.extend(pieces)
            continue
        own = syllable_to_cyrillic(orth)
        if not own:
            return None
        letters.append(own)
        sources.append(orth)
    return letters, sources


@functools.lru_cache(maxsize=8192)
def word_reading(word: str) -> tuple[tuple[str, ...], tuple[str, ...]] | None:
    """Чтение слова; ๆ повторяет слово перед ним (ค่อยๆ = ค่อย ค่อย)."""
    w = (word or "").strip()
    if "ๆ" in w:
        out_l: list[str] = []
        out_s: list[str] = []
        last: tuple[tuple[str, ...], tuple[str, ...]] = ((), ())
        for part in [p for p in re.split(r"\s*ๆ\s*", w)]:
            if part:
                r = _word_reading(part)
                if not r:
                    return None
                out_l.extend(r[0])
                out_s.extend(r[1])
                # พูดตรงๆ = พูด ตรง ตรง: ๆ повторяет последнее слово, а не весь токен.
                tail = _newmm(part)[-1]
                last = (_word_reading(tail) if tail != part else None) or r
            elif out_l:
                out_l.extend(last[0])
                out_s.extend(last[1])
        return (tuple(out_l), tuple(out_s)) if out_l else None
    return _word_reading(w)


_SPLIT_KEYS = tuple(
    sorted(set(_EXCEPTIONS) | set(_HOUSE_READING), key=len, reverse=True)
)


def _split_on_exception(word: str) -> tuple[str, str, str] | None:
    """Исключение внутри составного токена (สุขสันต์วันเกิด), но не внутри слога (เก็บ ⊃ ก็)."""
    for key in _SPLIT_KEYS:
        i = word.find(key)
        if i < 0 or word == key:
            continue
        head, tail = word[:i], word[i + len(key):]
        if head and head[-1] in LEAD:
            continue
        if tail and (len(tail) < 2 or tail[0] not in CONS + LEAD):
            continue
        return head, key, tail
    return None


def _word_reading(word: str) -> tuple[tuple[str, ...], tuple[str, ...]] | None:
    """
    (кириллица по слогам, слоги-источник в правильной орфографии) для одного слова.

    w2p знает скрытые гласные и нерегулярные чтения (โทรศัพท์ = โท-ระ-สับ, ทราบ = ซาบ),
    но это модель, и она ошибается даже на частых словах (อย่าง → หฺว่าง). Написание
    читается правилами надёжно, но не показывает скрытых гласных и иногда неверно
    делится на слоги. Поэтому по каждому слогу: если вариант написания с тем же
    числом слогов есть и w2p с ним согласен по начальному звуку — берём w2p;
    не согласен — слог по написанию.
    """
    house = _HOUSE_READING.get(word)
    if house:
        return house
    if word in _EXCEPTIONS:
        spoken_ex = list(_EXCEPTIONS[word])
        letters_ex = _letters(spoken_ex)
        return (tuple(letters_ex), tuple(spoken_ex)) if letters_ex else None
    split = _split_on_exception(word)
    if split:
        out_l: list[str] = []
        out_s: list[str] = []
        for part in split:
            if not part:
                continue
            r = _word_reading(part)
            if not r:
                return None
            out_l.extend(r[0])
            out_s.extend(r[1])
        return tuple(out_l), tuple(out_s)
    variants = []
    try:
        import speaker_quality  # noqa: PLC0415

        variants = speaker_quality.syllable_variants(word)
    except Exception:  # noqa: BLE001
        pass
    first = variants[0] if variants else []
    spoken = _merge_w2p_splits(list(spoken_syllables(word)), first)
    parsed = [len(v) for v in variants if _letters(v)]
    floor = min(parsed) if parsed else None
    if first and not _trust_w2p(first, spoken, floor):
        pw = _piecewise(first)
        if pw:
            return tuple(pw[0]), tuple(pw[1])
        return None
    ortho = next((v for v in variants if spoken and len(v) == len(spoken)), None)
    if ortho:
        # Скелет согласных совпал по слову, а по слогу нет — w2p лишь сдвинул границу
        # (กิ-โลก-รัม → กิ-โล-กฺรำ), ему верим. Не совпал и по слову — w2p выдумал звук
        # (อย่าง → หฺว่าง, เปล → เปน), верим написанию.
        true_split = "".join(ortho) == word
        same_word = _skeleton(spoken) == _skeleton(ortho)
        letters: list[str] = []
        sources: list[str] = []
        for sp, orth in zip(spoken, ortho):
            sp_c = syllable_to_cyrillic(sp)
            or_c = syllable_to_cyrillic(orth)
            if sp_c and _cluster_of(orth) and not _cluster_of(sp):
                sp_c = _restore_clusters([sp], [orth], [sp_c])[0]
            same_syl = _skeleton([sp]) == _skeleton([orth])
            if or_c and true_split and _has_explicit_vowel(orth) and (same_syl or not same_word):
                letters.append(or_c)
                sources.append(orth)
            elif sp_c and (_w2p_agrees(sp, orth) or not or_c or (same_word and not same_syl)):
                letters.append(sp_c)
                sources.append(sp)
            elif or_c:
                letters.append(or_c)
                sources.append(orth)
            else:
                letters = []
                break
        if letters:
            return tuple(letters), tuple(sources)
    spoken_letters = _letters(spoken)
    if spoken_letters:
        return tuple(_restore_clusters(spoken, first, spoken_letters)), tuple(spoken)
    first_letters = _letters(first)
    if first_letters:
        return tuple(first_letters), tuple(first)
    return None


def word_letters(word: str) -> list[str] | None:
    """Кириллица по слогам для одного тайского слова; None — не разобрать без модели."""
    r = word_reading(word)
    return list(r[0]) if r else None
