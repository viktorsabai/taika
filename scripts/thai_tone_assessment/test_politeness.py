"""Unit checks for smart-speaker politeness strip/apply (no network)."""
from __future__ import annotations

from api import (
    _apply_politeness,
    _finalize_parts,
    _phonetic_word_groups,
    _strip_trailing_politeness,
)


def test_strip_rising_then_apply_male_single():
    thai = "กรุณาตอบฉันด้วยนะ ครับ"
    # LLM left rising particle; server used to append another falling → duplicate.
    phonetic = "ка-ру-на↗ та-об↘ чан↗ дуй-ый↗ на↗ кхрап↗"
    th, ph = _strip_trailing_politeness(thai, phonetic)
    assert not th.endswith("ครับ")
    assert "кхрап" not in ph.lower()
    th2, ph2 = _apply_politeness(th, ph, "male")
    assert th2.count("ครับ") == 1
    assert th2.endswith("ครับ")
    groups = _phonetic_word_groups(ph2)
    assert groups[-1] == "кхрап"
    assert sum(1 for g in groups if g.replace("-", "") in ("кхрап", "крап", "кха")) == 1


def test_strip_double_khrap():
    th, ph = _strip_trailing_politeness(
        "สวัสดี ครับ ครับ",
        "са-ват-ди↘ кхрап↗ кхрап↘",
    )
    assert th == "สวัสดี"
    assert ph == "са-ват-ди↘"
    _, ph2 = _apply_politeness(th, ph, "male")
    assert ph2.endswith("кхрап↘")
    assert ph2.count("кхрап") == 1


def test_female_particle():
    th, ph = _apply_politeness("สวัสดี", "са-ват-ди↘", "female")
    assert th.endswith("ค่ะ")
    assert ph.endswith("кха↘")


def test_speaker_pronoun_male_swaps_chan():
    from api import _apply_speaker_pronoun, _parts_match_phonetic

    thai, ph, parts = _apply_speaker_pronoun(
        "ฉันหิว",
        "чхан→ хиу↗",
        [{"p": "чхан", "m": "я"}, {"p": "хиу", "m": "голоден"}],
        "male",
    )
    assert thai == "ผมหิว"
    assert "пхом" in ph.lower()
    assert parts[0] == {"p": "пхом", "m": "я"}
    assert parts[1]["m"] == "голоден"
    assert _parts_match_phonetic(ph, parts)


def test_speaker_pronoun_female_swaps_phom():
    from api import _apply_speaker_pronoun, _parts_match_phonetic

    thai, ph, parts = _apply_speaker_pronoun(
        "ผมหิว",
        "пхом→ хиу↗",
        [{"p": "пхом", "m": "я"}, {"p": "хиу", "m": "голоден"}],
        "female",
    )
    assert thai == "ฉันหิว"
    assert ph.startswith("чхан")
    assert parts[0]["p"] == "чхан"
    assert _parts_match_phonetic(ph, parts)


def test_speaker_pronoun_short_chan_variant():
    from api import _apply_speaker_pronoun, _parts_match_phonetic

    thai, ph, parts = _apply_speaker_pronoun(
        "ฉันหิว",
        "чан→ хиу↗",
        [{"p": "чан", "m": "я"}, {"p": "хиу", "m": "голоден"}],
        "male",
    )
    assert "ผม" in thai and "ฉัน" not in thai
    assert parts[0]["p"] == "пхом"
    assert _parts_match_phonetic(ph, parts)


def test_speaker_pronoun_leaves_other_words():
    from api import _apply_speaker_pronoun

    thai, ph, parts = _apply_speaker_pronoun(
        "ฝนจะตก",
        "фон↗ ча↘ ток↘",
        [{"p": "фон", "m": "дождь"}, {"p": "ча", "m": "будет"}, {"p": "ток", "m": "идти"}],
        "male",
    )
    assert thai == "ฝนจะตก"
    assert ph == "фон↗ ча↘ ток↘"
    assert [p["p"] for p in parts] == ["фон", "ча", "ток"]


def test_finalize_gloss():
    parts = _finalize_parts(
        "привет",
        "สวัสดี ครับ",
        "са-ват-ди↘ кхрап↘",
        [{"p": "са-ват-ди", "m": "привет"}, {"p": "кхрап", "m": "вежливость"}],
    )
    assert parts[-1]["m"] == "вежливость (м)"


if __name__ == "__main__":
    test_strip_rising_then_apply_male_single()
    test_strip_double_khrap()
    test_female_particle()
    test_speaker_pronoun_male_swaps_chan()
    test_speaker_pronoun_female_swaps_phom()
    test_speaker_pronoun_short_chan_variant()
    test_speaker_pronoun_leaves_other_words()
    test_finalize_gloss()
    print("ok")
