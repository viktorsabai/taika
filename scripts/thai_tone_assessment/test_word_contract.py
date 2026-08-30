"""
Регрессии пословного контракта /smart_speaker (без сети).

Тесты проверяют не «правильный перевод конкретной фразы» (это не проверить в юните),
а ИНВАРИАНТ выдачи: сколько чанков в phonetic — столько же glosses в parts, в том же
порядке. Именно его нарушение давало «РАЗБОР · 1» вместо полного разбора.

Каждый кейс — это вариант кривого ответа модели, который встречался в проде.
"""
from __future__ import annotations

import api
from api import (
    MAX_WORDS,
    _apply_politeness,
    _clean_words,
    _glue_letters_after_arrows,
    _is_degenerate_advice,
    _normalize_parts,
    _normalize_phonetic,
    _normalize_phonetic_line,
    _normalize_phonetic_token,
    _parts_match_phonetic,
    _politeness_part,
    _segmentation_problems,
    _smart_translate_words,
    _strip_thai_from_explanation,
    _thai_word_tokens,
    _usable_coach,
    _validate_words,
    _words_to_outputs,
)


def _fake_llm(*responses):
    """Подменяет LLM: каждый вызов отдаёт следующий заготовленный ответ."""
    queue = list(responses)

    def fake(**kwargs):
        return queue.pop(0) if queue else None

    return fake


def _run(monkeypatch_target, *responses, ru="как ваше настроение", politeness="male"):
    original = api._openai_chat_json
    api._openai_chat_json = _fake_llm(*responses)
    try:
        return _smart_translate_words(ru, politeness)
    finally:
        api._openai_chat_json = original


# --- нормализация одного слова ------------------------------------------------


def test_latin_cluster_becomes_cyrillic():
    # Регрессия: латинская «ng» ломала сравнение чанков → первый gloss молча терялся.
    assert _normalize_phonetic_token("я↘ng-рай↘") == "я↘нг-рай↘"
    assert _normalize_phonetic_token("khrap↘") == "кхрап↘"


def test_space_inside_word_becomes_hyphen():
    # Пробел внутри слова = второй чанк в phonetic = рассинхрон с parts.
    assert _normalize_phonetic_token("ру сык↘") == "ру-сык↘"
    assert _normalize_phonetic_token("ру - сык↘") == "ру-сык↘"
    assert _normalize_phonetic_token("са бай ди↗") == "са-бай-ди↗"


def test_detached_arrow_glues_back():
    assert _normalize_phonetic_token("кхун →") == "кхун→"


def test_junk_is_stripped():
    assert _normalize_phonetic_token("сы\u0300к↘") == "сык↘"  # комбинируемое ударение
    assert _normalize_phonetic_token("кхун→ (you)") == "кхун→"  # пояснение модели
    assert _normalize_phonetic_token("คุณ кхун→") == "кхун→"  # тайский скрипт в phonetic
    assert _normalize_phonetic_token("«кхун→»") == "кхун→"


def test_odd_arrows_normalize_to_mid():
    assert _normalize_phonetic_token("май↕") == "май→"


# --- сборка выдачи ------------------------------------------------------------


def test_outputs_are_consistent_by_construction():
    words = [
        {"th": "คุณ", "ph": "кхун→", "m": "вы"},
        {"th": "รู้สึก", "ph": "ру↑-сык↘", "m": "чувствуете"},
        {"th": "อย่างไร", "ph": "я↘нг-рай→", "m": "как"},
    ]
    thai, phonetic, parts = _words_to_outputs(words)
    assert thai == "คุณรู้สึกอย่างไร"  # тайский пишется без пробелов между словами
    assert phonetic == "кхун→ ру↑-сык↘ я↘нг-рай→"
    assert [p["m"] for p in parts] == ["вы", "чувствуете", "как"]
    assert _parts_match_phonetic(phonetic, parts)


def test_politeness_keeps_alignment():
    words = [{"th": "สวัสดี", "ph": "са-ват-ди↘", "m": "здравствуйте"}]
    thai, phonetic, parts = _words_to_outputs(words)
    thai, phonetic = _apply_politeness(thai, phonetic, "male")
    parts = parts + [_politeness_part("male")]
    assert thai.endswith("ครับ") and thai.count("ครับ") == 1
    assert _parts_match_phonetic(phonetic, parts)
    assert parts[-1]["m"] == "вежливость (м)"


def test_model_supplied_politeness_is_dropped():
    # Частицу дописывает сервер; если оставить обе — в phonetic будет два «кхрап».
    words = _clean_words([
        {"th": "สวัสดี", "ph": "са-ват-ди↘", "m": "здравствуйте"},
        {"th": "ครับ", "ph": "кхрап↘", "m": "вежливость"},
    ])
    assert len(words) == 1
    _, phonetic, parts = _words_to_outputs(words)
    _, phonetic = _apply_politeness("สวัสดี", phonetic, "male")
    assert phonetic.count("кхрап") == 1
    assert _parts_match_phonetic(phonetic, parts + [_politeness_part("male")])


def test_real_word_sounding_like_particle_survives():
    """
    ขา («нога») читается «кха» — как женская частица. Опознавать частицу по фонетике
    нельзя: так из фразы «у меня болит нога» пропадало бы последнее слово.
    """
    words = _clean_words([
        {"th": "ปวด", "ph": "пуат↘", "m": "болит"},
        {"th": "ขา", "ph": "кха↗", "m": "нога"},
    ])
    assert len(words) == 2, words
    thai, phonetic, parts = _words_to_outputs(words)
    thai, phonetic = api._append_politeness(thai, phonetic, "female")
    parts = parts + [_politeness_part("female")]
    assert phonetic == "пуат↘ кха↗ кха↘"
    assert [p["m"] for p in parts] == ["болит", "нога", "вежливость (ж)"]
    assert _parts_match_phonetic(phonetic, parts)


def test_word_cap():
    words = _clean_words(
        [{"th": "ดี", "ph": "ди↗", "m": "хорошо"} for _ in range(MAX_WORDS + 5)]
    )
    assert len(words) == MAX_WORDS
    _, phonetic, parts = _words_to_outputs(words)
    assert _parts_match_phonetic(phonetic, parts)


# --- инварианты ---------------------------------------------------------------


def test_validate_rejects_whole_phrase_gloss():
    problems = _validate_words(
        "как ваше настроение",
        [
            {"th": "คุณ", "ph": "кхун→", "m": "как ваше настроение"},
            {"th": "ดี", "ph": "ди↗", "m": "хорошо"},
        ],
    )
    assert any("whole sentence" in p for p in problems)


def test_validate_rejects_missing_pieces():
    assert _validate_words("привет", [])
    assert any("'m' is empty" in p for p in _validate_words(
        "привет", [{"th": "สวัสดี", "ph": "са-ват-ди↘", "m": ""}]
    ))
    assert any("no Cyrillic" in p for p in _validate_words(
        "привет", [{"th": "สวัสดี", "ph": "↘", "m": "привет"}]
    ))
    assert any("no tone arrows" in p for p in _validate_words(
        "привет", [{"th": "สวัสดี", "ph": "са-ват-ди", "m": "привет"}]
    ))


def test_validate_accepts_single_word_phrase():
    # У однословной фразы gloss ЛЕГАЛЬНО совпадает со всей фразой — не считаем это ошибкой.
    assert _validate_words("привет", [{"th": "สวัสดี", "ph": "са-ват-ди↘", "m": "привет"}]) == []


# --- полный проход с подменённой моделью --------------------------------------


def test_screenshot_regression_latin_ng():
    """
    Прод-баг: phonetic «кун-ру-сык-я-ng-рай↘ кхрап↘» схлопывался в один чанк,
    сверка строк не находила его среди parts и разбор усыхал до «кхрап — вежливость».
    """
    built = _run(
        None,
        {"words": [
            {"th": "คุณ", "ph": "кхун→", "m": "вы"},
            {"th": "รู้สึก", "ph": "ру↑-сык↘", "m": "чувствуете"},
            {"th": "อย่างไร", "ph": "я↘ng-рай→", "m": "как"},
        ]},
    )
    assert built is not None
    thai, phonetic, parts = built
    assert len(parts) == 3
    assert "ng" not in phonetic
    assert _parts_match_phonetic(phonetic, parts)


def test_repair_pass_recovers_bad_first_answer():
    built = _run(
        None,
        {"words": [{"th": "คุณ", "ph": "кхун→", "m": "как ваше настроение"},
                   {"th": "ดี", "ph": "ди↗", "m": "хорошо"}]},
        {"words": [{"th": "คุณ", "ph": "кхун→", "m": "вы"},
                   {"th": "ดี", "ph": "ди↗", "m": "хорошо"}]},
    )
    assert built is not None
    assert [p["m"] for p in built[2]] == ["вы", "хорошо"]


def test_gives_up_instead_of_returning_broken():
    # Дважды брак → None, вызывающий уходит на legacy-путь. Обрезанный разбор не отдаём.
    bad = {"words": [{"th": "คุณ", "ph": "", "m": ""}]}
    assert _run(None, bad, bad) is None
    assert _run(None, None, None) is None


def test_rejects_russian_spellout():
    # Модель иногда «транскрибирует» сам русский ввод вместо тайского произношения.
    ru = "твоя персона"
    bad = {"words": [
        {"th": "คุณ", "ph": "тво↗-я→", "m": "твоя"},
        {"th": "คน", "ph": "пер↘-со-на→", "m": "персона"},
    ]}
    assert _run(None, bad, bad, ru=ru) is None


def test_full_phonetic_normalizer_also_fixes_latin():
    # Legacy-путь тоже перестал пропускать латиницу наружу.
    assert "ng" not in _normalize_phonetic("я↘ng-рай↘ кхрап↘")


def test_line_normalizer_keeps_word_boundaries():
    """
    Регрессия: `_normalize_phonetic` режет «ру↑-сык↘» по стрелке на два чанка —
    это правило для legacy-строк, где дефисами склеено ВСЁ. Для уже согласованной
    строки оно ломало соответствие с parts (ровно так разбор и терялся на кэше).
    """
    line = "кхун→ ру↑-сык↘ я↘нг-рай→ кхрап↘"
    assert api._normalize_phonetic_line(line) == line
    assert len(api._phonetic_word_groups(api._normalize_phonetic_line(line))) == 4


# --- эндпоинт целиком ---------------------------------------------------------


def _endpoint_case(politeness: str):
    import tempfile

    from fastapi.testclient import TestClient

    db = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
    db.close()
    calls = {"n": 0}

    def fake(**kwargs):
        calls["n"] += 1
        return {"words": [
            {"th": "คุณ", "ph": "кхун→", "m": "вы"},
            {"th": "รู้สึก", "ph": "ру↑-сык↘", "m": "чувствуете"},
            {"th": "อย่างไร", "ph": "я↘ng-рай→", "m": "как"},
        ]}

    original_llm, original_key, original_db = api._openai_chat_json, api.OPENAI_API_KEY, api._cache_db_path
    api._openai_chat_json = fake
    api.OPENAI_API_KEY = "test-key"
    api._cache_db_path = lambda: __import__("pathlib").Path(db.name)
    try:
        api._init_cache_db()
        client = TestClient(api.app)
        fresh = client.post(
            "/smart_speaker", json={"text_ru": "как ваше настроение?", "politeness": politeness}
        ).json()
        cached = client.post(
            "/smart_speaker", json={"text_ru": "Как ваше настроение", "politeness": politeness}
        ).json()
        return fresh, cached, calls["n"]
    finally:
        api._openai_chat_json, api.OPENAI_API_KEY, api._cache_db_path = original_llm, original_key, original_db


def test_endpoint_alignment_survives_cache_roundtrip():
    for politeness, particle, gloss in (("male", "ครับ", "вежливость (м)"), ("female", "ค่ะ", "вежливость (ж)")):
        fresh, cached, calls = _endpoint_case(politeness)
        assert fresh == cached, f"{politeness}: кэш изменил ответ\n{fresh}\n{cached}"
        assert calls == 1, f"{politeness}: второй запрос не попал в кэш"
        assert fresh["thai"] == f"คุณรู้สึกอย่างไร {particle}", fresh["thai"]
        assert fresh["thai"].count(particle) == 1
        groups = api._phonetic_word_groups(fresh["phonetic"])
        assert groups == [p["p"] for p in fresh["parts"]], (groups, fresh["parts"])
        assert len(groups) == 4, groups
        assert fresh["parts"][-1]["m"] == gloss
        assert "ng" not in fresh["phonetic"]


# --- рассогласованный разбор не покидает сервер -------------------------------


def test_unaligned_parts_are_dropped_not_shipped():
    # Кривая пара «слово — чужое значение» учит неправильному, поэтому вместо неё
    # клиент должен получить пустой разбор и дотянуть его отдельным запросом.
    phonetic = "кхун→ са-баи→-ди→ май↑ кхрап↘"
    broken = [
        {"p": "кхун", "m": "вы"},
        {"p": "май", "m": "хорошо"},
        {"p": "кхрап", "m": "вежливость (м)"},
    ]
    assert api._aligned_parts_only(phonetic, broken, "test") == []


def test_aligned_parts_pass_through_untouched():
    phonetic = "кхун→ са-баи→-ди→ май↑"
    good = [
        {"p": "кхун", "m": "вы"},
        {"p": "са-баи-ди", "m": "хорошо"},
        {"p": "май", "m": "ли"},
    ]
    assert api._aligned_parts_only(phonetic, good, "test") == good


def test_endpoint_ships_phrase_without_broken_gloss():
    """Легаси-путь: перевод и фонетика доезжают, разбор — нет, если он не сошёлся."""
    import tempfile

    from fastapi.testclient import TestClient

    db = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
    db.close()

    originals = (
        api._openai_chat_json,
        api.OPENAI_API_KEY,
        api._cache_db_path,
        api._smart_translate_words,
        api._llm_translate_ru_to_th,
        api._llm_phrase_parts,
    )
    api.OPENAI_API_KEY = "test-key"
    api._cache_db_path = lambda: __import__("pathlib").Path(db.name)
    # Пословный путь «отказал» → уходим в легаси, который отдаёт разбор не по словам.
    api._smart_translate_words = lambda ru, politeness: None
    api._llm_translate_ru_to_th = lambda ru, politeness: (
        "คุณสบายดีไหม",
        "кхун→ са-баи→-ди→ май↑",
        [{"p": "кхун", "m": "вы"}, {"p": "май", "m": "хорошо"}],
    )
    api._llm_phrase_parts = lambda ru, thai, phonetic: []
    try:
        api._init_cache_db()
        client = TestClient(api.app)
        out = client.post(
            "/smart_speaker", json={"text_ru": "как у вас дела", "politeness": "male"}
        ).json()
        assert out["thai"], "перевод обязан доехать даже без разбора"
        assert out["phonetic"], "фонетика обязана доехать даже без разбора"
        assert out["parts"] == [], out["parts"]
    finally:
        (
            api._openai_chat_json,
            api.OPENAI_API_KEY,
            api._cache_db_path,
            api._smart_translate_words,
            api._llm_translate_ru_to_th,
            api._llm_phrase_parts,
        ) = originals


def test_phrase_parts_keeps_word_boundaries_from_client():
    """Клиент шлёт готовую строку: слоговые дефисы в ней смысловые, рвать их нельзя."""
    from fastapi.testclient import TestClient

    original = api._llm_phrase_parts
    api._llm_phrase_parts = lambda ru, thai, phonetic: [
        {"p": "кхун", "m": "вы"},
        {"p": "са-баи-ди", "m": "хорошо"},
        {"p": "май", "m": "ли"},
    ]
    try:
        client = TestClient(api.app)
        out = client.post(
            "/phrase_parts",
            json={
                "text_ru": "как у вас дела",
                "text_th": "คุณสบายดีไหม",
                "phonetic": "кхун→ са-баи→-ди→ май↑",
            },
        ).json()
        assert [p["p"] for p in out["parts"]] == ["кхун", "са-баи-ди", "май"], out["parts"]
    finally:
        api._llm_phrase_parts = original


def test_phrase_parts_returns_nothing_when_unaligned():
    from fastapi.testclient import TestClient

    original = api._llm_phrase_parts
    api._llm_phrase_parts = lambda ru, thai, phonetic: [{"p": "кхун", "m": "вы"}]
    try:
        client = TestClient(api.app)
        out = client.post(
            "/phrase_parts",
            json={
                "text_ru": "как у вас дела",
                "text_th": "คุณสบายดีไหม",
                "phonetic": "кхун→ са-баи→-ди→ май↑",
            },
        ).json()
        assert out["parts"] == [], out["parts"]
    finally:
        api._llm_phrase_parts = original


# --- Тайская графика не доходит до пользователя -----------------------------
# Наш пользователь тайское письмо не читает: всё тайское приходит к нему кириллицей.
# Любой квадратик в объяснении читается как «приложение сломалось».


def test_thai_script_never_leaks_into_gloss_meaning():
    parts = _normalize_parts([
        {"p": "кхрап", "m": "вежливая частица ครับ"},
        {"p": "кхун", "m": "вы (คุณ)"},
    ])
    assert parts == [
        {"p": "кхрап", "m": "вежливая частица"},
        {"p": "кхун", "m": "вы"},
    ], parts


def test_gloss_without_thai_is_untouched():
    """Скрубер не должен трогать нормальные значения — включая скобки и знаки."""
    for m in ["вежливость (м)", "как, каким образом", "быть — есть", "1-й"]:
        assert _strip_thai_from_explanation(m) == m, m


def test_gloss_that_is_only_thai_is_dropped():
    """Если после вычистки не осталось смысла — часть выкидываем, а не показываем пустую."""
    assert _normalize_parts([{"p": "кхун", "m": "คุณ"}]) == []


def test_coach_explanation_is_cleaned_of_thai():
    assert _strip_thai_from_explanation("Ты сказала ขา вместо ค่ะ — нужен низкий тон.") == (
        "Ты сказала вместо — нужен низкий тон."
    )


def test_words_path_cleans_thai_from_gloss():
    """
    Пословный путь собирает parts напрямую, минуя `_normalize_parts`. Регрессия: тайская
    графика в значении доезжала до пользователя именно по основному, а не запасному пути.
    """
    words = _clean_words([
        {"th": "คุณ", "ph": "кхун→", "m": "вы (คุณ)"},
        {"th": "ดี", "ph": "ди↗", "m": "хорошо"},
    ])
    assert [w["m"] for w in words] == ["вы", "хорошо"], words


def test_gloss_that_is_only_thai_triggers_repair():
    """Значение осталось пустым после чистки — ответ обязан уйти в ремонтный проход."""
    words = _clean_words([{"th": "คุณ", "ph": "кхун→", "m": "คุณ"}])
    assert _validate_words("вы", words), "пустое значение должно попасть в problems"


# --- Подсказка коуча ---------------------------------------------------------
# «используй май↗ вместо май↗» и «ЧТО ПОПРАВИТЬ» без сути читаются как поломка,
# а не как совет. Наружу такое уходить не должно ни при каком ответе модели.


def test_degenerate_advice_is_detected():
    assert _is_degenerate_advice("Используй май↗ вместо май↗")
    assert _is_degenerate_advice("Ты сказала май↘, нужно было май↘.")
    assert _is_degenerate_advice("скажи кхрап, а не кхрап")


def test_real_contrast_advice_survives():
    """Стрелки значимы: разный тон — это как раз полезный совет, его резать нельзя."""
    assert not _is_degenerate_advice("Используй май↘ вместо май↗")
    assert not _is_degenerate_advice("Ты сказала кха↗, нужно было кхрап↘.")
    assert not _is_degenerate_advice("В слове май нужен нисходящий тон, а прозвучал восходящий.")
    assert not _is_degenerate_advice("")


def test_degenerate_coach_is_not_shipped():
    assert _usable_coach("Используй май↗ вместо май↗", "") is None


def test_empty_headline_is_filled_from_detail():
    """Пустой заголовок при живом пояснении — не повод терять совет целиком."""
    out = _usable_coach("", "Тон в первом слоге ушёл вниз. Держи его ровным.")
    assert out is not None
    assert out.headline == "Тон в первом слоге ушёл вниз."
    assert out.detail == "Держи его ровным."


def test_thai_only_headline_falls_back_to_detail():
    out = _usable_coach("ครับ", "Частица вежливости прозвучала слишком коротко.")
    assert out is not None
    assert out.headline == "Частица вежливости прозвучала слишком коротко."
    assert out.detail is None


def test_coach_with_nothing_usable_is_dropped():
    assert _usable_coach("", "") is None
    assert _usable_coach("ครับ", "คุณ") is None


def test_semantic_coach_endpoint_never_ships_broken_hint():
    """
    Сквозная проверка платной подсказки: что бы ни ответила модель, наружу уходит либо
    годный совет с заголовком, либо честный отказ — но не пустой заголовок и не «X вместо X».
    """
    from fastapi.testclient import TestClient

    originals = (api.OPENAI_API_KEY, api._openai_post_coach_raw)
    api.OPENAI_API_KEY = "test-key"
    client = TestClient(api.app)
    body = {"expected_thai": "ไม่", "expected_phonetic": "май↘", "heard_phonetic": "май↗"}

    cases = [
        # (ответ модели, ожидаемый заголовок или None если 503)
        (("Используй май↗ вместо май↗", ""), None),
        (("ครับ", ""), None),
        (("", "Тон ушёл вверх. Держи спад."), "Тон ушёл вверх."),
        (("Нужен нисходящий тон", "Сейчас прозвучал восходящий."), "Нужен нисходящий тон"),
        (("Скажи май↘ вместо май↗", ""), "Скажи май↘ вместо май↗"),
    ]
    try:
        for (headline, detail), expected in cases:
            api._openai_post_coach_raw = lambda req, h=headline, d=detail: {"headline": h, "detail": d}
            resp = client.post("/semantic_coach", json=body)
            if expected is None:
                assert resp.status_code == 503, (headline, detail, resp.status_code, resp.text)
            else:
                assert resp.status_code == 200, (headline, detail, resp.text)
                got = resp.json()
                assert got["headline"] == expected, got
                assert got["headline"].strip(), got
    finally:
        api.OPENAI_API_KEY, api._openai_post_coach_raw = originals


# --- Одна строка разбора = одно слово ---------------------------------------
# Склейка проходит все прочие инварианты (чанк один, gloss один, всё согласовано),
# но прячет слово: «หูตลก — смешное ухо» вместо «หู — ухо» + «ตลก — смешной».


def _tokenizer_ready() -> bool:
    """Без словаря проверка склейки молчит — тогда эти тесты нечего проверять."""
    return _thai_word_tokens("หูตลก") == ("หู", "ตลก")


def test_glued_words_are_reported_as_separate():
    if not _tokenizer_ready():
        raise ImportError("PyThaiNLP dictionary unavailable")
    problems = _segmentation_problems([
        {"th": "หูตลก", "ph": "ху↑-та↓лок↓", "m": "смешное ухо"},
        {"th": "มาก", "ph": "мак↘", "m": "очень"},
    ])
    assert len(problems) == 1, problems
    assert "หูตลก" in problems[0] and "หู" in problems[0] and "ตลก" in problems[0]


def test_real_compound_words_stay_one_entry():
    """Обратный край: настоящее сращение дробить нельзя, иначе разбор врёт по смыслу."""
    if not _tokenizer_ready():
        raise ImportError("PyThaiNLP dictionary unavailable")
    for th in ["ตลก", "รู้สึก", "อย่างไร", "สบายดี", "น้ำแข็ง", "โรงพยาบาล", "ขอบคุณ", "ห้องน้ำ"]:
        assert _segmentation_problems([{"th": th, "ph": "х→", "m": "значение"}]) == [], th


def test_free_combinations_are_split():
    if not _tokenizer_ready():
        raise ImportError("PyThaiNLP dictionary unavailable")
    for th in ["ผู้หญิงสวย", "ร้อนมาก", "อาหารอร่อย"]:
        assert _segmentation_problems([{"th": th, "ph": "х→", "m": "значение"}]) != [], th


def test_missing_tokenizer_does_not_block_translation():
    """
    Без PyThaiNLP словарь недоступен и деление проверить нечем. Это не повод отказывать
    пользователю в переводе: проверка молчит, а не заваливает ответ.
    """
    original = api._thai_word_tokens
    api._thai_word_tokens = lambda th: (th,)  # деградация из-except в _thai_word_tokens
    try:
        assert _segmentation_problems([
            {"th": "หูตลก", "ph": "ху↑-та↓-лок↓", "m": "смешное ухо"},
        ]) == []
    finally:
        api._thai_word_tokens = original


def test_repair_pass_splits_glued_words():
    """Первый ответ склеил слова — ремонтный проход обязан вернуть их по отдельности."""
    if not _tokenizer_ready():
        raise ImportError("PyThaiNLP dictionary unavailable")
    glued = {"words": [
        {"th": "หูตลก", "ph": "ху↑-та↓-лок↓", "m": "смешное ухо"},
        {"th": "มาก", "ph": "мак↘", "m": "очень"},
    ]}
    split = {"words": [
        {"th": "หู", "ph": "ху↑", "m": "ухо"},
        {"th": "ตลก", "ph": "та↓-лок↓", "m": "смешной"},
        {"th": "มาก", "ph": "мак↘", "m": "очень"},
    ]}
    out = _run(None, glued, split, ru="очень смешное ухо")
    assert out is not None
    _, phonetic, parts = out
    assert [p["m"] for p in parts] == ["ухо", "смешной", "очень"], parts
    assert _parts_match_phonetic(phonetic, parts)


def test_glued_result_still_shipped_when_repair_fails():
    """
    Ремонт не помог — отдаём крупный, но верный разбор. Показать «ху-талок — смешное
    ухо» хуже, чем два слова, но лучше, чем оставить пользователя без разбора вовсе.
    """
    if not _tokenizer_ready():
        raise ImportError("PyThaiNLP dictionary unavailable")
    glued = {"words": [
        {"th": "หูตลก", "ph": "ху↑-та↓-лок↓", "m": "смешное ухо"},
        {"th": "มาก", "ph": "мак↘", "m": "очень"},
    ]}
    out = _run(None, glued, glued, ru="очень смешное ухо")
    assert out is not None, "разбор не должен пропадать из-за грубости деления"
    _, phonetic, parts = out
    assert _parts_match_phonetic(phonetic, parts)


def test_orphan_letter_after_arrow_glues_into_syllable():
    """
    Скрин «Я хочу есть»: หิว писали как «хи↘-в», нормализатор резал по стрелке,
    появлялось слово «в», разбор не сходился и выкидывался целиком.
    После склейки конечная ว пишется «у», как в курсе (хиу лэу), не «в».
    """
    for src in ("хи↘в", "хи↘-в", "хи↘ в"):
        assert _glue_letters_after_arrows(src) == "хив↘", src
        assert _normalize_phonetic_token(src) == "хиу↘", src
    assert _glue_letters_after_arrows("хи↘ кхрап↘") == "хи↘ кхрап↘"
    assert _normalize_phonetic_token("хью↗") == "хиу↗"
    assert _normalize_phonetic_token("хио↗") == "хиу↗"
    # Начальная ว не трогаем.
    assert _normalize_phonetic_token("ва↘") == "ва↘"


def test_hungry_screenshot_line_has_no_orphan_letter():
    for src in (
        "чан-хи↘-в кхрап↘",
        "чан-хи↘ в кхрап↘",
        "чан-хи↘в кхрап↘",
        "чан→ хи↘-в кхрап↘",
    ):
        line = _normalize_phonetic_line(src)
        groups = api._phonetic_word_groups(line)
        assert "в" not in groups, (src, line, groups)
        assert any("хиу" in g for g in groups), (src, line, groups)


def test_hungry_words_path_glues_broken_hiv():
    built = _run(
        None,
        {"words": [
            {"th": "ฉัน", "ph": "чан→", "m": "я"},
            {"th": "หิว", "ph": "хи↘в", "m": "голоден"},
        ]},
        ru="Я хочу есть",
        politeness="male",
    )
    assert built is not None
    thai, phonetic, parts = built
    assert "ฉัน" in thai and "หิว" in thai
    groups = api._phonetic_word_groups(phonetic)
    assert groups == ["чан", "хиу"], (phonetic, groups)
    assert [p["m"] for p in parts] == ["я", "голоден"]
    assert _parts_match_phonetic(phonetic, parts)


def test_hungry_words_path_keeps_alignment_after_politeness():
    words = _clean_words([
        {"th": "ฉัน", "ph": "чан→", "m": "я"},
        {"th": "หิว", "ph": "хи↘-в", "m": "голоден"},
    ])
    thai, phonetic, parts = _words_to_outputs(words)
    thai, phonetic = api._append_politeness(thai, phonetic, "male")
    parts = parts + [_politeness_part("male")]
    assert phonetic == "чан→ хиу↘ кхрап↘", phonetic
    assert _parts_match_phonetic(phonetic, parts)
    assert [p["m"] for p in parts] == ["я", "голоден", "вежливость (м)"]


def test_digits_become_spoken_cyrillic():
    def no_digit(s: str) -> None:
        assert not any(ch.isdigit() for ch in s), s

    no_digit(_normalize_phonetic_token("90→"))
    assert "кау" in _normalize_phonetic_token("90→")
    assert "сип" in _normalize_phonetic_token("90→")

    no_digit(_normalize_phonetic("позвони 1669→"))
    spoken = _normalize_phonetic_token("1669")
    assert spoken == "нынг→-хок→-хок→-кау→", spoken

    no_digit(_normalize_phonetic_token("555"))
    assert _normalize_phonetic_token("555") == "ха→-ха→-ха→"

    for raw in ("4x6", "4×6", "4кс6"):
        got = _normalize_phonetic_token(raw)
        no_digit(got)
        assert "кху" in got and "си" in got and "хок" in got, (raw, got)

    # На согласованной строке число остаётся ОДНИМ словом разбора, не тремя чанками.
    line = _normalize_phonetic_line("то→ 90→ кхрап↘")
    no_digit(line)
    groups = api._phonetic_word_groups(line)
    assert len(groups) == 3, (line, groups)
    assert groups[1].replace("-", "").startswith("кау"), groups


def test_words_path_expands_digits_in_ph():
    built = _run(
        None,
        {"words": [
            {"th": "โทร", "ph": "то→", "m": "звони"},
            {"th": "เบอร์", "ph": "1669→", "m": "скорая"},
        ]},
        ru="позвони 1669",
        politeness="female",
    )
    assert built is not None
    _, phonetic, parts = built
    assert not any(ch.isdigit() for ch in phonetic), phonetic
    assert _parts_match_phonetic(phonetic, parts)


def test_validate_rejects_arrowless_leftover_letter():
    problems = _validate_words(
        "я хочу есть",
        [
            {"th": "ฉัน", "ph": "чан→", "m": "я"},
            {"th": "หิว", "ph": "в", "m": "голоден"},
        ],
    )
    assert any("no tone arrow" in p for p in problems), problems


def test_pronoun_gloss_ya_is_not_weak():
    """Иначе ฉัน → «я» браковало весь пословный ответ «Я хочу есть»."""
    assert _validate_words(
        "я хочу есть",
        [
            {"th": "ฉัน", "ph": "чан→", "m": "я"},
            {"th": "หิว", "ph": "хиу↗", "m": "голоден"},
        ],
    ) == []


if __name__ == "__main__":
    import sys

    failures = 0
    for name, fn in sorted(globals().items()):
        if not name.startswith("test_") or not callable(fn):
            continue
        try:
            fn()
            print(f"ok   {name}")
        except ImportError as e:
            print(f"skip {name}: {e}")
        except AssertionError as e:
            failures += 1
            print(f"FAIL {name}: {e}")
    print("all ok" if not failures else f"{failures} failed")
    sys.exit(1 if failures else 0)
