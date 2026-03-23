# -*- coding: utf-8 -*-
"""
Данные для функционального минимума (survival minimum): слова/фразы из гайда аналитика
и CONTENT_AUDIT, которых не хватает в steps.json. Каждая запись пойдёт в указанный lesson
курса База (course_b_1). phonetic — кириллица, каждый слог с тоном (→↗↘↑↓).
"""
# (ru, thai, phonetic, kind, tip optional)
# target_lesson: course_b_1_l2 = Знакомство, l3 = Как дела, l4 = Хочу и могу, l5 = Где/здесь, l6 = Цены/числа

SURVIVAL_ITEMS = [
    # Логические связки (в урок «Как дела» или «Знакомство»)
    {"ru": "И", "thai": "และ", "phonetic": "лэ→", "kind": "word", "target_lesson": "course_b_1_l3", "tip": "Союз «и». Лэ — связка между словами."},
    {"ru": "Но", "thai": "แต่", "phonetic": "тэ↘", "kind": "word", "target_lesson": "course_b_1_l3", "tip": "Но, однако. Тэ — противопоставление."},
    {"ru": "Потому что", "thai": "เพราะ", "phonetic": "пхро↘", "kind": "word", "target_lesson": "course_b_1_l3", "tip": "Потому что. Пхро — причина."},
    {"ru": "Если", "thai": "ถ้า", "phonetic": "тха↗", "kind": "word", "target_lesson": "course_b_1_l3", "tip": "Если. Тха — условие."},
    {"ru": "Поэтому", "thai": "เลย", "phonetic": "лёй→", "kind": "word", "target_lesson": "course_b_1_l3", "tip": "Поэтому, вот почему. Лёй — следствие."},
    # Модальность (Хочу и могу — l4)
    {"ru": "Хочу", "thai": "อยาก", "phonetic": "яак↘", "kind": "word", "target_lesson": "course_b_1_l4", "tip": "Хотеть. Яак — основа просьб."},
    {"ru": "Могу", "thai": "ได้", "phonetic": "дай↗", "kind": "word", "target_lesson": "course_b_1_l4", "tip": "Мочь, можно. Дай — возможность."},
    {"ru": "Надо", "thai": "ต้อง", "phonetic": "тонг↗", "kind": "word", "target_lesson": "course_b_1_l4", "tip": "Нужно, надо. Тонг — необходимость."},
    {"ru": "Попробовать", "thai": "ลอง", "phonetic": "лонг→", "kind": "word", "target_lesson": "course_b_1_l4", "tip": "Попробовать. Лонг — попытка."},
    {"ru": "Взять", "thai": "เอา", "phonetic": "ау→", "kind": "word", "target_lesson": "course_b_1_l4", "tip": "Взять, брать. Ау — «дай мне»."},
    {"ru": "Дать", "thai": "ให้", "phonetic": "хай↗", "kind": "word", "target_lesson": "course_b_1_l4", "tip": "Дать. Хай — передать."},
    {"ru": "Это", "thai": "อันนี้", "phonetic": "ан→-ни↘", "kind": "word", "target_lesson": "course_b_1_l4", "tip": "Это (вот это). Покажи пальцем."},
    {"ru": "Вот", "thai": "นี่", "phonetic": "ни↗", "kind": "word", "target_lesson": "course_b_1_l4", "tip": "Вот, это здесь. Ни — указание."},
    # Пространство и навигация (Где, здесь — l5)
    {"ru": "Далеко", "thai": "ไกล", "phonetic": "клай→", "kind": "word", "target_lesson": "course_b_1_l5", "tip": "Далеко. Клай — расстояние."},
    {"ru": "Близко", "thai": "ใกล้", "phonetic": "клай↗", "kind": "word", "target_lesson": "course_b_1_l5", "tip": "Близко. Клай (восходящий) — рядом."},
    {"ru": "Назад", "thai": "กลับ", "phonetic": "клап↘", "kind": "word", "target_lesson": "course_b_1_l5", "tip": "Назад, возвращаться. Клап — обратно."},
    {"ru": "Налево", "thai": "ซ้าย", "phonetic": "саай↗", "kind": "word", "target_lesson": "course_b_1_l5", "tip": "Налево. Саай — левая сторона."},
    {"ru": "Направо", "thai": "ขวา", "phonetic": "кхваа→", "kind": "word", "target_lesson": "course_b_1_l5", "tip": "Направо. Кхваа — правая сторона."},
    # Время (в l6 или рядом с ценами/действиями)
    {"ru": "Потом", "thai": "ทีหลัง", "phonetic": "ти→-ланг↘", "kind": "word", "target_lesson": "course_b_1_l6", "tip": "Потом, позже. Ти ланг — после."},
    {"ru": "Ещё не", "thai": "ยัง", "phonetic": "янг→", "kind": "phrase", "target_lesson": "course_b_1_l6", "tip": "Ещё не, пока нет. Янг — отрицание времени."},
    {"ru": "Сейчас", "thai": "ตอนนี้", "phonetic": "тон→-ни↘", "kind": "word", "target_lesson": "course_b_1_l6", "tip": "Сейчас. Тон ни — в данный момент."},
    {"ru": "Сегодня", "thai": "วันนี้", "phonetic": "ван→-ни↘", "kind": "word", "target_lesson": "course_b_1_l6", "tip": "Сегодня. Ван ни — этот день."},
    {"ru": "Завтра", "thai": "พรุ่งนี้", "phonetic": "пхрунг→-ни↘", "kind": "word", "target_lesson": "course_b_1_l6", "tip": "Завтра. Пхрунг ни — следующий день."},
    {"ru": "Уже", "thai": "แล้ว", "phonetic": "лэу↗", "kind": "word", "target_lesson": "course_b_1_l6", "tip": "Уже. Лэу — завершённость."},
    # Вопросительные слова (Где — l5, дополняем остальные)
    {"ru": "Кто", "thai": "ใคร", "phonetic": "кхрай→", "kind": "word", "target_lesson": "course_b_1_l5", "tip": "Кто? Кхрай — вопрос о человеке."},
    {"ru": "Что", "thai": "อะไร", "phonetic": "а→-рай↗", "kind": "word", "target_lesson": "course_b_1_l5", "tip": "Что? А-рай — вопрос о предмете."},
    {"ru": "Когда", "thai": "เมื่อไหร่", "phonetic": "мыа→-рай↘", "kind": "word", "target_lesson": "course_b_1_l5", "tip": "Когда? Мыа рай — вопрос о времени."},
    {"ru": "Почему", "thai": "ทำไม", "phonetic": "тхам→-май↗", "kind": "word", "target_lesson": "course_b_1_l5", "tip": "Почему? Тхам май — причина."},
    {"ru": "Как", "thai": "ยังไง", "phonetic": "янг→-нгай→", "kind": "word", "target_lesson": "course_b_1_l5", "tip": "Как? Янг нгай — способ, каким образом."},
]
