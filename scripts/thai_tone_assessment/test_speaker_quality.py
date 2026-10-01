"""
Контракт Smart Speaker как платной фичи: тоны по написанию, числа не теряются,
частица по полу и типу фразы, непроверенный ответ не закрепляется в кэше.
Модель подменена — тесты гоняют те же ошибки, что прод отдавал на живом корпусе.
"""
from __future__ import annotations

import tempfile
from pathlib import Path

from fastapi.testclient import TestClient

import api
import speaker_quality as q
import spoken_canon


def _endpoint(fake, ru: str, politeness: str = "female", db: str | None = None) -> tuple[dict, int]:
    calls = {"n": 0}

    def counting(**kwargs):
        calls["n"] += 1
        return fake(**kwargs)

    if db is None:
        tmp = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
        tmp.close()
        db = tmp.name
    original = api._openai_chat_json, api.OPENAI_API_KEY, api._cache_db_path
    api._openai_chat_json = counting
    api.OPENAI_API_KEY = "test-key"
    api._cache_db_path = lambda: Path(db)
    try:
        api._init_cache_db()
        body = TestClient(api.app).post(
            "/smart_speaker", json={"text_ru": ru, "politeness": politeness}
        ).json()
        return body, calls["n"]
    finally:
        api._openai_chat_json, api.OPENAI_API_KEY, api._cache_db_path = original


def _prod_like_four_years(**kwargs):
    """Ответы, как у прода на «я живу тут 4 года»: цифра в тайском и неверные стрелки."""
    tag = str(kwargs.get("tag") or "")
    if tag.endswith("translate"):
        return {"thai": "ฉันอยู่ที่นี่ 4 ปีแล้ว"}
    if tag.endswith("judge"):
        return {"ok": True, "missing": []}
    if tag.endswith("meanings"):
        return {"meanings": ["я", "жить", "здесь", "четыре", "год", "уже"]}
    if tag.endswith("phonetic"):
        return {"phonetics": ["чан↗", "йу↘", "ти-ни↗", "си↘", "пи↗", "лэу↗"]}
    if tag.endswith("gloss"):
        return {"fixes": []}
    return None


def test_four_years_keeps_number_and_rule_tones():
    body, _ = _endpoint(_prod_like_four_years, "я живу тут 4 года")
    assert body["thai"] == "ฉันอยู่ที่นี่สี่ปีแล้ว ค่ะ", body
    assert body["phonetic"] == "чхан↗ ю↓ ти↘-ни↘ си↓ пи→ лэу↑ кха↘", body
    assert [p["m"] for p in body["parts"]] == ["я", "жить", "здесь", "четыре", "год", "уже", "вежливость (ж)"]
    assert [p["p"] for p in body["parts"]] == ["чхан", "ю", "ти-ни", "си", "пи", "лэу", "кха"]
    assert body["checks"] == {"numbers": True, "meaning": True, "tones": True, "letters": True, "gloss": True}


def test_model_letters_are_never_shipped():
    """Буквы прода с живого корпуса: «сорон» за สอง, «хай» за ห้า. Слова читает движок."""
    seen = []

    def garbage_letters(**kwargs):
        tag = str(kwargs.get("tag") or "")
        seen.append(tag)
        if tag.endswith("translate"):
            return {"thai": "ขอกาแฟสองแก้ว"}
        if tag.endswith("judge"):
            return {"ok": True, "missing": []}
        if tag.endswith("meanings"):
            return {"meanings": ["просить", "кофе", "два", "стакан"]}
        if tag.endswith("phonetic"):
            return {"phonetics": ["кхо↗", "ка-фэ", "сорон↗", "кэу↘"]}
        if tag.endswith("gloss"):
            return {"fixes": []}
        return None

    body, _ = _endpoint(garbage_letters, "два кофе пожалуйста", politeness="male")
    assert body["phonetic"] == "кхо↗ ка→-фэ→ сонг↗ кэу↘ кхрап↑", body
    assert body["checks"]["letters"] is True
    assert not any(t.endswith("phonetic") for t in seen), "движок прочитал все слова — запрос букв лишний"


def test_verified_answer_is_cached_and_reused():
    tmp = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
    tmp.close()
    first, n1 = _endpoint(_prod_like_four_years, "я живу тут 4 года", db=tmp.name)
    second, n2 = _endpoint(_prod_like_four_years, "Я живу тут 4 года.", db=tmp.name)
    assert n1 > 0 and n2 == 0
    assert first == second


def test_missing_number_is_repaired_or_never_cached():
    state = {"translate": 0}

    def drops_number(**kwargs):
        tag = str(kwargs.get("tag") or "")
        if tag.endswith("translate"):
            state["translate"] += 1
            return {"thai": "ราคาเท่าไหร่บาท"}
        if tag.endswith("judge"):
            return {"ok": True, "missing": []}
        if tag.endswith("meanings"):
            return {"meanings": ["цена", "сколько", "бат"]}
        if tag.endswith("phonetic"):
            return {"phonetics": ["ра-ка", "тхау-рай", "бат"]}
        if tag.endswith("gloss"):
            return {"fixes": []}
        return None

    tmp = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
    tmp.close()
    body, _ = _endpoint(drops_number, "сколько стоит 250 бат", db=tmp.name)
    # Перевод без числа переспрашиваем, а не принимаем молча.
    assert state["translate"] == 3
    assert body["checks"]["numbers"] is False
    again, n = _endpoint(drops_number, "сколько стоит 250 бат", db=tmp.name)
    assert n > 0, "ответ без числа не должен закрепиться в кэше"


def test_female_question_gets_kha_high():
    def toilet(**kwargs):
        tag = str(kwargs.get("tag") or "")
        if tag.endswith("translate"):
            return {"thai": "ห้องน้ำอยู่ที่ไหน"}
        if tag.endswith("judge"):
            return {"ok": True, "missing": []}
        if tag.endswith("meanings"):
            return {"meanings": ["туалет", "находиться", "где"]}
        if tag.endswith("phonetic"):
            return {"phonetics": ["хонг-нам↗", "ю↘", "ти-най↘"]}
        if tag.endswith("gloss"):
            return {"fixes": []}
        return None

    body, _ = _endpoint(toilet, "а где здесь туалет?")
    assert body["thai"].endswith(" คะ"), body
    assert body["phonetic"] == "хонг↘-нам↑ ю↓ ти↘-най↗ кха↑", body
    canon, n = _endpoint(toilet, "где туалет?")
    assert n == 0 and canon["thai"].endswith(" คะ") and canon["phonetic"].endswith("кха↑"), canon


def test_glued_model_syllables_do_not_matter():
    def glued(**kwargs):
        tag = str(kwargs.get("tag") or "")
        if tag.endswith("translate"):
            return {"thai": "ฉันอยู่ที่นี่"}
        if tag.endswith("judge"):
            return {"ok": True, "missing": []}
        if tag.endswith("meanings"):
            return {"meanings": ["я", "жить", "здесь"]}
        if tag.endswith("phonetic"):
            return {"phonetics": ["чан↗", "ю↘", "тини↗"]}
        if tag.endswith("syllables"):
            return {"words": [{"i": 2, "syllables": ["ти", "ни"]}]}
        if tag.endswith("gloss"):
            return {"fixes": []}
        return None

    body, _ = _endpoint(glued, "я живу тут")
    assert body["phonetic"] == "чхан↗ ю↓ ти↘-ни↘ кха↘", body
    assert body["checks"]["tones"] is True


def test_canon_tones_follow_spelling():
    seen = set()
    for key, e in spoken_canon.CANON.items():
        if (e["thai"], e["phonetic"]) in seen:
            continue
        seen.add((e["thai"], e["phonetic"]))
        thai, ph, parts = api._apply_speaker_pronoun(
            e["thai"], api._normalize_phonetic_line(e["phonetic"]), list(e["parts"]), "female"
        )
        thai, ph = api._apply_politeness(thai, ph, "female", key)
        toned, ok = api._final_tones(thai, ph)
        assert ok, (key, thai, ph)
        assert q.rule_arrows(thai, toned) in (None, [c for c in toned if c in q.ARROWS]), (key, toned)


def test_thai_number_words():
    assert q.thai_number_words(4) == "สี่"
    assert q.thai_number_words(21) == "ยี่สิบเอ็ด"
    assert q.thai_number_words(250) == "สองร้อยห้าสิบ"
    assert q.thai_number_words(1500) == "หนึ่งพันห้าร้อย"
    assert q.thai_number_words(1_500_000) == "หนึ่งล้านห้าแสน"
    for n in (4, 11, 21, 99, 101, 250, 1669, 10000, 150000, 2_300_000):
        assert n in q.thai_numbers(q.thai_number_words(n)), n


def test_digits_in_model_thai_become_words():
    assert q.spell_thai_digits("อยู่ที่นี่ 4 ปี") == "อยู่ที่นี่ สี่ ปี"
    assert q.spell_thai_digits("ราคา 1,500 บาท") == "ราคา หนึ่งพันห้าร้อย บาท"
    assert q.spell_thai_digits("โทร 0812345678") == "โทร ศูนย์แปดหนึ่งสองสามสี่ห้าหกเจ็ดแปด"
    assert q.spell_thai_digits("๔ ปี") == "สี่ ปี"


def test_russian_numbers_are_required():
    assert q.number_problems("я живу тут 4 года", "ฉันอยู่ที่นี่สี่ปีแล้ว") == []
    assert q.number_problems("я живу тут четыре года", "ฉันอยู่ที่นี่สี่ปีแล้ว") == []
    assert q.number_problems("я живу тут 4 года", "ฉันอยู่ที่นี่ปีแล้ว")
    assert q.number_problems("две тысячи двадцать пять", "สองพันยี่สิบห้า") == []
    assert q.number_problems("комната 305", "ห้องสามศูนย์ห้า") == []
    assert q.number_problems("позвони 0812345678", "โทรหาศูนย์แปดหนึ่งสองสามสี่ห้าหกเจ็ดแปด") == []
    # Время суток, годы, бренды и «один» тайский выражает иначе — их проверяет судья смысла.
    assert q.number_problems("встретимся в 8 вечера", "เจอกันสองทุ่ม") == []
    assert q.number_problems("где ближайший 7-Eleven", "เซเว่นอยู่ที่ไหน") == []
    assert q.number_problems("я один", "ฉันอยู่คนเดียว") == []


def test_question_detection():
    assert q.is_question("ты здесь?", "คุณอยู่ที่นี่ไหม")
    assert q.is_question("где туалет", "ห้องน้ำอยู่ที่ไหน")
    assert q.is_question("как тебя зовут", "คุณชื่ออะไร")
    assert not q.is_question("я живу тут", "ฉันอยู่ที่นี่")
    assert not q.is_question("я не понимаю", "ฉันไม่เข้าใจ")


def test_retone_word_tolerates_arrow_inside_syllable():
    assert q.retone_word("อย่างไร", "я↘нг-рай→") == "янг↓-рай→"
    assert q.retone_word("ที่นี่", "ти↗ни↗") == "ти↘-ни↘"
    assert q.retone_word("ที่นี่", "тини↗") is None


def test_final_reading_rewrites_model_spaces_from_slots():
    """Прод резал อะไร пробелом — слотов меньше, чем чанков. Движок всё равно читает слово."""
    ph, parts, tones_ok, letters_ok = api._final_reading(
        "คุณชื่ออะไร คะ",
        "кхун→ чыу↘ а↓ рай→ кха↑",
        [{"p": "кхун", "m": "ты"}, {"p": "чыу", "m": "имя"}, {"p": "а", "m": "что"},
         {"p": "рай", "m": "что"}, {"p": "кха", "m": "вежливость (ж)"}],
    )
    assert letters_ok and tones_ok
    assert ph == "кхун→ чыу↘ а↓-рай→ кха↑", ph
    assert [p["p"] for p in parts] == ["кхун", "чыу", "а-рай", "кха"]
    assert q.engine_phonetic("รัสเซีย") == "рас↑-сиа→"
    assert q.engine_phonetic("เงิน") == "нген→"
    assert q.engine_phonetic("อยาก") == "яак↓"
    assert q.engine_phonetic("เซเว่นอีเลฟเว่น") == "се→-вен↘-и→-леф→-вен↘"
