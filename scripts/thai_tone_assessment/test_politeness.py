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
    test_finalize_gloss()
    print("ok")
