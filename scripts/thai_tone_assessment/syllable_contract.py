"""
Syllable count for /assess must match the iOS breakdown rows.

iOS `translitChunksForSyllables`: split on spaces (words), then `-` / `·` inside a word.
One chunk = one row = one audio segment. Trailing politeness is its own last chunk.
"""
from __future__ import annotations

_ARROW_TONES: tuple[tuple[str, str], ...] = (
    ("↘", "Falling"),
    ("↗", "Rising"),
    ("→", "Mid"),
    ("↓", "Low"),
    ("↑", "High"),
)


def phonetic_syllable_chunks(phonetic: str | None) -> list[str]:
    raw = (phonetic or "").strip()
    if not raw:
        return []
    words = [w.strip() for w in raw.split() if w.strip()]
    chunks: list[str] = []
    for word in words:
        buf: list[str] = []
        parts: list[str] = []
        for ch in word:
            if ch in "-·":
                part = "".join(buf).strip()
                if part:
                    parts.append(part)
                buf = []
            else:
                buf.append(ch)
        part = "".join(buf).strip()
        if part:
            parts.append(part)
        chunks.extend(parts if parts else [word])
    return chunks


def tone_name_from_chunk(chunk: str) -> str:
    for arrow, name in _ARROW_TONES:
        if arrow in chunk:
            return name
    return "Mid"


def expected_tones_for_chunks(chunks: list[str]) -> list[str]:
    return [tone_name_from_chunk(c) for c in chunks]
