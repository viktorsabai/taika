"""
Детерминированные гарантии Smart Speaker: то, что можно проверить без модели.

Модель переводит и пишет буквы звучания. Всё, что следует из тайского написания
и из цифр пользователя, считает код:
- тон каждого слога — по правилам орфографии (тот же движок, которым выверен курс);
- числа из русского обязаны дойти до тайского словами, цифры в тайском — раскрыты;
- женская частица в вопросе — คะ, а не ค่ะ.
"""
from __future__ import annotations

import re
import sys
from dataclasses import dataclass
from pathlib import Path

_HERE = Path(__file__).resolve().parent
for _folder in (_HERE, _HERE.parent):
    if str(_folder) not in sys.path:
        sys.path.insert(0, str(_folder))

ARROWS = ("→", "↓", "↘", "↑", "↗")
_ARROW_LIKE = "→↓↘↑↗↕↔⇕⇅"


# --- Тоны по написанию -------------------------------------------------------

def _engine():
    try:
        import thai_taika_phonetic as eng  # noqa: PLC0415

        eng.thai_syllables("ปี")
        return eng
    except Exception as e:  # noqa: BLE001
        print(f"[speaker_quality] tone engine unavailable: {e}", file=sys.stderr, flush=True)
        return None


_ENGINE = None
_ENGINE_TRIED = False


def tone_engine():
    global _ENGINE, _ENGINE_TRIED
    if not _ENGINE_TRIED:
        _ENGINE_TRIED = True
        _ENGINE = _engine()
    return _ENGINE


def syllable_variants(th: str) -> list[list[str]]:
    eng = tone_engine()
    if not eng or not th:
        return []
    try:
        return eng.thai_syllable_variants(th)
    except Exception:  # noqa: BLE001
        return []


def syllable_chunks(ph: str) -> list[str]:
    """Слоги фонетики одного слова: дефис или стрелка — граница слога."""
    s = ph or ""
    for a in _ARROW_LIKE:
        s = s.replace(a, a + "-")
    return [c for c in (x.strip(_ARROW_LIKE + " ") for x in s.split("-")) if c]


def _hyphen_chunks(ph: str) -> list[str]:
    """Только дефис — граница: «я↘нг-рай» это «янг» + «рай», стрелка просто сползла внутрь."""
    return [
        c for c in ("".join(ch for ch in x if ch not in _ARROW_LIKE).strip() for x in (ph or "").split("-")) if c
    ]


def retone_word(th: str, ph: str) -> str | None:
    """
    Буквы модели + стрелка каждого слога по тайскому написанию.
    None — слоги не удалось сопоставить 1:1 (стрелкам модели тогда верить нельзя).
    """
    eng = tone_engine()
    if not eng or not th:
        return None
    variants = syllable_variants(th)
    for chunks in (_hyphen_chunks(ph), syllable_chunks(ph)):
        if not chunks:
            continue
        for syls in variants:
            if len(syls) == len(chunks):
                return "-".join(c + eng.tone_arrow(s) for c, s in zip(chunks, syls))
    return None


def retone_line(thai: str, phonetic: str) -> str | None:
    """Целая строка (канон, курс, кэш): стрелки по написанию, если слоги сходятся 1:1."""
    eng = tone_engine()
    if not eng or not thai or not phonetic:
        return None
    try:
        return eng.retone_phonetic(re.sub(r"\s+", "", thai), phonetic)
    except Exception:  # noqa: BLE001
        return None


def rule_arrows(thai: str, phonetic: str) -> list[str] | None:
    """Ожидаемые стрелки по написанию для чанков фонетики; None — не сопоставить."""
    toned = retone_line(thai, phonetic)
    if toned is None:
        return None
    return [ch for ch in toned if ch in ARROWS]


# --- Числа -------------------------------------------------------------------

_TH_DIGIT = ("ศูนย์", "หนึ่ง", "สอง", "สาม", "สี่", "ห้า", "หก", "เจ็ด", "แปด", "เก้า")
_TH_PLACES = ((100000, "แสน"), (10000, "หมื่น"), (1000, "พัน"), (100, "ร้อย"))


def _below_million(n: int) -> str:
    out: list[str] = []
    rest = n
    for value, word in _TH_PLACES:
        d, rest = divmod(rest, value)
        if d:
            out.append(_TH_DIGIT[d] + word)
    tens, ones = divmod(rest, 10)
    if tens == 1:
        out.append("สิบ")
    elif tens == 2:
        out.append("ยี่สิบ")
    elif tens:
        out.append(_TH_DIGIT[tens] + "สิบ")
    if ones == 1 and n > 10:
        out.append("เอ็ด")
    elif ones:
        out.append(_TH_DIGIT[ones])
    return "".join(out)


def thai_number_words(n: int) -> str:
    """4 → สี่, 21 → ยี่สิบเอ็ด, 250 → สองร้อยห้าสิบ, 1500000 → หนึ่งล้านห้าแสน."""
    if n == 0:
        return _TH_DIGIT[0]
    if n < 0:
        return "ลบ" + thai_number_words(-n)
    millions, rest = divmod(n, 1_000_000)
    out = ""
    if millions:
        out = thai_number_words(millions) + "ล้าน"
    if rest:
        out += _below_million(rest)
    return out


def thai_digit_sequence(digits: str) -> str:
    """Телефон, код, номер: каждая цифра отдельно, как диктуют тайцы."""
    return "".join(_TH_DIGIT[int(d)] for d in digits if d.isdigit())


_TH_NUMERAL_DIGITS = str.maketrans("๐๑๒๓๔๕๖๗๘๙", "0123456789")
_GROUPED_INT_RE = re.compile(r"\d{1,3}(?:[ ,\u00a0]\d{3})+(?!\d)")
_CLOCK_RE = re.compile(r"(?<!\d)([01]?\d|2[0-3])[:.]([0-5]\d)(?!\d)")
_DECIMAL_RE = re.compile(r"(\d+)[.,](\d+)")
_INT_RE = re.compile(r"\d+")


def _is_sequence_digits(raw: str) -> bool:
    return len(raw) >= 5 or (len(raw) >= 2 and raw.startswith("0"))


def spell_thai_digits(thai: str, sequence_hint: bool = False) -> str:
    """
    Цифры в тайском ответе модели → тайские слова. Раньше они молча вырезались
    фильтром тайского алфавита, и «4 года» превращалось в «года» без числа.
    """
    s = (thai or "").translate(_TH_NUMERAL_DIGITS)
    if not re.search(r"\d", s):
        return s
    s = _GROUPED_INT_RE.sub(lambda m: re.sub(r"\D", "", m.group(0)), s)
    s = _CLOCK_RE.sub(
        lambda m: thai_number_words(int(m.group(1))) + "นาฬิกา"
        + (thai_number_words(int(m.group(2))) + "นาที" if int(m.group(2)) else ""),
        s,
    )
    s = _DECIMAL_RE.sub(
        lambda m: thai_number_words(int(m.group(1))) + "จุด" + thai_digit_sequence(m.group(2)), s
    )

    def _int(m: re.Match[str]) -> str:
        raw = m.group(0)
        if sequence_hint or _is_sequence_digits(raw):
            return thai_digit_sequence(raw)
        return thai_number_words(int(raw))

    return _INT_RE.sub(_int, s)


_RU_NUM_WORDS: dict[str, int] = {}


def _ru_forms(value: int, *forms: str) -> None:
    for f in forms:
        _RU_NUM_WORDS[f] = value


_ru_forms(0, "ноль", "нуль", "ноля", "нуля")
_ru_forms(2, "два", "две", "двух", "двум", "двумя")
_ru_forms(3, "три", "трёх", "трех", "трём", "трем", "тремя")
_ru_forms(4, "четыре", "четырёх", "четырех", "четырём", "четырем", "четырьмя")
for _v, _base in (
    (5, "пять"), (6, "шесть"), (7, "семь"), (8, "восемь"), (9, "девять"), (10, "десять"),
    (11, "одиннадцать"), (12, "двенадцать"), (13, "тринадцать"), (14, "четырнадцать"),
    (15, "пятнадцать"), (16, "шестнадцать"), (17, "семнадцать"), (18, "восемнадцать"),
    (19, "девятнадцать"), (20, "двадцать"), (30, "тридцать"),
):
    _ru_forms(_v, _base, _base[:-1] + "и", _base + "ю")
_ru_forms(8, "восьми", "восьмью")
_ru_forms(40, "сорок", "сорока")
_ru_forms(50, "пятьдесят", "пятидесяти")
_ru_forms(60, "шестьдесят", "шестидесяти")
_ru_forms(70, "семьдесят", "семидесяти")
_ru_forms(80, "восемьдесят", "восьмидесяти")
_ru_forms(90, "девяносто", "девяноста")
_ru_forms(100, "сто", "ста")
_ru_forms(200, "двести", "двухсот")
_ru_forms(300, "триста", "трёхсот", "трехсот")
_ru_forms(400, "четыреста", "четырёхсот", "четырехсот")
_ru_forms(500, "пятьсот", "пятисот")
_ru_forms(600, "шестьсот", "шестисот")
_ru_forms(700, "семьсот", "семисот")
_ru_forms(800, "восемьсот", "восьмисот")
_ru_forms(900, "девятьсот", "девятисот")
_RU_MULT = {
    **{f: 1000 for f in ("тысяча", "тысячи", "тысяч", "тысячу", "тысячей", "тыщ", "тыщи", "тыща")},
    **{f: 1_000_000 for f in ("миллион", "миллиона", "миллионов", "миллионом", "лям", "ляма", "лямов")},
}
# «один/одна» почти всегда значит «один из», «сам», «одинокий» — по-тайски это
# เดียว/คนเดียว, а не число. Требовать หนึ่ง в переводе было бы ложной тревогой.
_RU_ONE = frozenset({"один", "одна", "одно", "одного", "одной", "одну", "одним", "одном", "одни"})

_SEQUENCE_CONTEXT_RE = re.compile(
    r"номер|телефон|позвон|звони|набер|наберите|код|пин|счёт\s+номер|whatsapp|ватсап|вотсап|line|лайн",
    re.IGNORECASE,
)
_CLOCK_CONTEXT_RE = re.compile(r"^(утра|вечера|ночи|дня|часов\s+(утра|вечера|ночи|дня))")


@dataclass(frozen=True)
class NumberMention:
    value: int
    raw: str
    # cardinal — в тайском обязано быть это число; sequence — цифры по одной;
    # soft — время суток / год / «один»: тайский выражает иначе, проверяет судья.
    kind: str


def ru_number_mentions(ru: str) -> list[NumberMention]:
    text = (ru or "").replace("\u00a0", " ")
    low = text.lower()
    seq_ctx = bool(_SEQUENCE_CONTEXT_RE.search(low))
    out: list[NumberMention] = []
    cleaned = _GROUPED_INT_RE.sub(lambda m: re.sub(r"\D", "", m.group(0)), text)
    for m in re.finditer(r"\d+(?:[.,:]\d+)?", cleaned):
        raw = m.group(0)
        after = cleaned[m.end():].lstrip().lower()
        if re.search(r"[.,:]", raw):
            out.append(NumberMention(0, raw, "soft"))
            continue
        val = int(raw)
        # 7-Eleven, 4G, iPhone 15 — часть названия, по-тайски это бренд (เซเว่น), не число.
        before = cleaned[max(0, m.start() - 1):m.start()]
        if re.match(r"-?\s?[A-Za-z]", cleaned[m.end():]) or re.match(r"[A-Za-z]", before):
            out.append(NumberMention(val, raw, "soft"))
            continue
        if seq_ctx or _is_sequence_digits(raw):
            out.append(NumberMention(val, raw, "sequence"))
        elif _CLOCK_CONTEXT_RE.match(after) or (1900 <= val <= 2100 and after.startswith("год")):
            out.append(NumberMention(val, raw, "soft"))
        else:
            out.append(NumberMention(val, raw, "cardinal"))
    tokens = re.findall(r"[а-яё]+", low)
    i = 0
    while i < len(tokens):
        tok = tokens[i]
        if tok not in _RU_NUM_WORDS and tok not in _RU_MULT:
            if tok in _RU_ONE:
                out.append(NumberMention(1, tok, "soft"))
            i += 1
            continue
        total, current, words = 0, 0, []
        while i < len(tokens) and (tokens[i] in _RU_NUM_WORDS or tokens[i] in _RU_MULT or (
            words and tokens[i] in _RU_ONE
        )):
            t = tokens[i]
            words.append(t)
            if t in _RU_MULT:
                total += (current or 1) * _RU_MULT[t]
                current = 0
            else:
                current += _RU_NUM_WORDS.get(t, 1)
            i += 1
        value = total + current
        after = " ".join(tokens[i:i + 2])
        kind = "soft" if _CLOCK_CONTEXT_RE.match(after) else "cardinal"
        out.append(NumberMention(value, " ".join(words), kind))
    return out


_TH_NUM_MORPHEMES = (
    ("ศูนย์", "d", 0), ("หนึ่ง", "d", 1), ("เอ็ด", "d", 1), ("สอง", "d", 2), ("ยี่", "d", 2),
    ("สาม", "d", 3), ("สี่", "d", 4), ("ห้า", "d", 5), ("หก", "d", 6), ("เจ็ด", "d", 7),
    ("แปด", "d", 8), ("เก้า", "d", 9), ("สิบ", "m", 10), ("ร้อย", "m", 100),
    ("พัน", "m", 1000), ("หมื่น", "m", 10000), ("แสน", "m", 100000), ("ล้าน", "M", 1_000_000),
)
_TH_NUM_RE = re.compile("|".join(m for m, _, _ in sorted(_TH_NUM_MORPHEMES, key=lambda x: -len(x[0]))))
_TH_NUM_INFO = {m: (k, v) for m, k, v in _TH_NUM_MORPHEMES}


def thai_numbers(thai: str) -> set[int]:
    """Все числа, записанные тайскими словами (สี่ปี → {4}, สองร้อยห้าสิบบาท → {250})."""
    s = re.sub(r"\s+", "", thai or "")
    found: set[int] = set()
    pos = 0
    while True:
        m = _TH_NUM_RE.search(s, pos)
        if not m:
            break
        total, current, pending = 0, 0, None
        j = m.start()
        while True:
            mm = _TH_NUM_RE.match(s, j)
            if not mm:
                break
            kind, val = _TH_NUM_INFO[mm.group(0)]
            if kind == "d":
                if pending is not None:
                    found.add(total + current + pending)
                    total, current = 0, 0
                pending = val
            elif kind == "m":
                current += (pending if pending is not None else 1) * val
                pending = None
            else:
                total = (total + current + (pending or 0) or 1) * val
                current, pending = 0, None
            j = mm.end()
        found.add(total + current + (pending or 0))
        pos = j
    return found


def number_problems(ru: str, thai: str) -> list[str]:
    """Числа пользователя, которых нет в тайском. Пусто — все на месте."""
    compact = re.sub(r"\s+", "", thai or "")
    have = thai_numbers(compact)
    problems: list[str] = []
    for n in ru_number_mentions(ru):
        if n.kind == "soft":
            continue
        if n.kind == "sequence":
            want = thai_digit_sequence(n.raw)
            if want and want not in compact and n.value not in have:
                problems.append(
                    f"number {n.raw} is missing: dictate it digit by digit in Thai words ({want})"
                )
            continue
        if n.value in have or (n.value == 1 and "เดียว" in compact):
            continue
        # Номер комнаты / рейса тайцы читают по цифрам: ห้องสามศูนย์ห้า — тоже 305.
        if n.raw.isdigit() and len(n.raw) >= 2 and thai_digit_sequence(n.raw) in compact:
            continue
        problems.append(
            f"number {n.raw} is missing: write it in Thai words ({thai_number_words(n.value)}) "
            "next to the counted noun with its classifier"
        )
    return problems


def numbers_hint(ru: str) -> str:
    """Подсказка переводчику: точные тайские слова для чисел пользователя."""
    lines = []
    for n in ru_number_mentions(ru):
        if n.kind == "cardinal":
            lines.append(f"{n.raw} = {thai_number_words(n.value)}")
        elif n.kind == "sequence":
            lines.append(f"{n.raw} = {thai_digit_sequence(n.raw)} (digit by digit)")
    return "; ".join(lines)


def has_sequence_number(ru: str) -> bool:
    return any(n.kind == "sequence" for n in ru_number_mentions(ru))


# --- Вопрос и женская частица ---------------------------------------------------

_RU_QUESTION_START_RE = re.compile(
    r"^(где|куда|откуда|когда|сколько|почему|зачем|кто|кого|кому|чей|чья|чьё|какой|какая|какое|какие|"
    r"как|можно|могу|можете|могли|есть\s+ли|ли)\b",
    re.IGNORECASE,
)
_TH_QUESTION_TAIL_RE = re.compile(
    r"(ไหม|มั้ย|มั๊ย|หรือ|หรอ|เหรอ|หรือเปล่า|หรือยัง|เปล่า|ไหน|อะไร|ใคร|เมื่อไหร่|เมื่อไร|ทำไม|ยังไง|"
    r"อย่างไร|เท่าไหร่|เท่าไร|กี่\S*|รึเปล่า|ป่าว)$"
)
_TH_QUESTION_WORD_RE = re.compile(r"ที่ไหน|อะไร|ใคร|เมื่อไหร่|เมื่อไร|ทำไม|ยังไง|อย่างไร|เท่าไหร่|เท่าไร|กี่")


def is_question(ru_raw: str, thai: str) -> bool:
    ru = (ru_raw or "").strip()
    th = re.sub(r"\s+", "", thai or "")
    th = re.sub(r"(ครับ|ค่ะ|คะ|นะ)+$", "", th)
    if ru.endswith("?") or "?" in ru:
        return True
    if th and _TH_QUESTION_TAIL_RE.search(th):
        return True
    if _RU_QUESTION_START_RE.match(ru) and _TH_QUESTION_WORD_RE.search(th):
        return True
    return False


def politeness_particle(politeness: str, question: bool) -> tuple[str, str]:
    """(тайский, фонетика). Тоны — по написанию: ครับ↑, ค่ะ↘, คะ↑ (как в курсе)."""
    if politeness == "male":
        return "ครับ", "кхрап↑"
    if question:
        return "คะ", "кха↑"
    return "ค่ะ", "кха↘"
