"""Phonetic syllable chunks must match iOS detailed tone rows (no network, no librosa)."""
from __future__ import annotations

from syllable_contract import (
    expected_tones_for_chunks,
    phonetic_syllable_chunks,
    tone_name_from_chunk,
)


def test_hungry_phrase_keeps_trailing_particle():
    chunks = phonetic_syllable_chunks("чан→ хиу↘ кхрап↘")
    assert chunks == ["чан→", "хиу↘", "кхрап↘"], chunks
    assert expected_tones_for_chunks(chunks) == ["Mid", "Falling", "Falling"]


def test_hyphenated_word_plus_particle():
    chunks = phonetic_syllable_chunks("са-ват-ди↘ кхрап↘")
    assert chunks == ["са", "ват", "ди↘", "кхрап↘"], chunks
    assert expected_tones_for_chunks(chunks)[-1] == "Falling"
    assert len(chunks) == 4


def test_two_arrows_in_one_chunk_still_one_syllable():
    chunks = phonetic_syllable_chunks("кху↘н↘")
    assert chunks == ["кху↘н↘"]
    assert expected_tones_for_chunks(chunks) == ["Falling"]


def test_female_particle():
    chunks = phonetic_syllable_chunks("са-бай→-ди→ кха↘")
    assert chunks[-1] == "кха↘"
    assert tone_name_from_chunk(chunks[-1]) == "Falling"
    assert len(chunks) == 4


def test_empty_phonetic():
    assert phonetic_syllable_chunks("") == []
    assert phonetic_syllable_chunks(None) == []


if __name__ == "__main__":
    test_hungry_phrase_keeps_trailing_particle()
    test_hyphenated_word_plus_particle()
    test_two_arrows_in_one_chunk_still_one_syllable()
    test_female_particle()
    test_empty_phonetic()
    print("ok")
