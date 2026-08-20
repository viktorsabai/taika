# Taika Overlay UI — Mockups

## Cover
Taika Overlay System
Liquid Glass / Continuous Canvas
UX/UI mockups for nine information and action scenarios

## Slide 1
### Игровой парк: пустое состояние

**Сценарий**
Пользователь впервые открывает Игровой парк, но ещё не отметил достаточно выученных карточек.

**Композиция мокапа**
Единый тёмный canvas без горизонтального разрыва между header и body. В центре — мягко пульсирующий game-orb, поверх него компактный translucent glass message surface. Внутри: game glyph, короткий заголовок, две numbered steps и один primary CTA.

**Текст**
«Сначала соберём первые пары»
«Отметь несколько фраз как выученные — и игры откроются сами.»

**CTA**
«Открыть курсы»

**Motion**
Orb медленно собирает две световые точки в пару. При tap CTA surface сжимается на 2%, затем мягко растворяется в переходе к Courses.

## Slide 2
### Игровой парк: выбор режима

**Сценарий**
У пользователя уже есть playable cards; он выбирает подходящий режим.

**Композиция мокапа**
GlassChoice surface с тремя компактными rows. Каждая row имеет icon, название, одну строку пользы и отдельный статус: доступно или PRO. Активная row подсвечивается не рамкой, а внутренним pink-lilac tint.

**Режимы**
«Найди пару» — закрепление через поиск пар.
«Быстрое повторение» — PRO, короткая серия для ежедневного refresh.
«Аудио-реплика» — PRO, узнавание фразы на слух.

**CTA**
У доступного режима: «Играть».
Для PRO-row CTA появляется только после tap: «Открыть Taika+».

## Slide 3
### Locked game: короткий native peek

**Сценарий**
Free-пользователь нажимает на PRO-режим.

**Композиция мокапа**
Не новый полноэкранный экран. Снизу поднимается compact glass peek на 35–40% высоты. В фоне остаётся виден Game Park. Внутри — lock glyph, одна benefit sentence, маленькая preview-анимация режима и два действия.

**Текст**
«Этот режим тренирует слух»
«Слушай фразу и находи её пару быстрее — без лишних подсказок.»

**CTA**
Primary: «Открыть Taika+»
Secondary: «Не сейчас»

**Motion**
При tap locked row — короткий haptic и мягкий lock pulse; никакого резкого navigation jump.

## Slide 4
### Лимит попыток Speaker

**Сценарий**
Free-пользователь исчерпал или почти исчерпал дневные попытки.

**Композиция мокапа**
GlassMessage поверх того же Speaker canvas. В центре — единая quota metric и тонкий progress arc, а не две конкурирующие цифры.

**Текст**
«Осталось 2 из 3 попыток»
«Лимит обновится завтра. В Taika+ можно тренироваться без остановки.»

**CTA**
Primary: «Открыть Taika+»
Secondary: «Продолжить позже»

**Motion**
Progress arc мягко дорисовывается к текущему значению; после закрытия пользователь возвращается ровно в исходный Speaker state.

## Slide 5
### Paywall Taika+

**Сценарий**
Пользователь осознанно открывает Taika+ из locked mode или лимита.

**Композиция мокапа**
GlassPaywall на едином blurred canvas. Header не отделён тяжёлой полосой. Сверху — конкретная ценность текущего entry point, ниже — три plan rows, выбранный annual plan и один CTA.

**Текст**
«Открой следующий шаг»
«Речь, тон и практика — без лимитов.»

**Планы**
Год — лучшая ценность.
Месяц — гибкая оплата.
Навсегда — разовая покупка.

**CTA**
«Войти и открыть Taika+»

**Native rules**
После закрытия paywall пользователь остаётся в исходном контексте; закрытие не запускает урок или игру автоматически.

## Slide 6
### Search: empty / results / no results

**Сценарий**
Пользователь ищет курс, урок или фразу.

**Композиция мокапа**
GlassWorkbench: search field остаётся частью continuous canvas, а не отдельной плавающей карточкой. В deck показать три состояния рядом: пустой запрос, результаты, ничего не найдено.

**Состояния**
Empty: placeholder «Введи слово» + быстрые suggestions.
Results: sections «Фразы», «Уроки», «Курсы» с count и понятной tap target.
No results: «Ничего не нашли» + «Попробуй другое слово» + suggestions и «Изменить запрос».

**CTA**
В no-results: «Изменить запрос».

## Slide 7
### Speaker: listening / recognizing / result / failure

**Сценарий**
Пользователь говорит фразу, Taika слушает, распознаёт и показывает перевод.

**Композиция мокапа**
Один continuous Speaker canvas. Waveform-orb — главный spatial anchor. Status chip, orb, waveform и нижние actions меняются синхронно.

**States**
Listening: «Слушаю» + active waveform + stop control.
Recognizing: «Распознаю» + processing orb + stage indicator.
Result: RU phrase, translit, Thai, audio/copy/save/train actions.
Failure: «Не расслышала» + «Попробовать ещё раз» + «Написать по-русски».

**CTA**
Result: «В ленту и словарь».
Failure: «Попробовать ещё раз».

## Slide 8
### Speaker: Russian input

**Сценарий**
Пользователь предпочитает написать фразу вместо записи голоса.

**Композиция мокапа**
Input surface раскрывается внутри Speaker canvas и сохраняет видимый orb glow на фоне. Keyboard-safe layout: field, voice alternative and translation CTA не прыгают при появлении клавиатуры.

**Текст**
«Напиши по-русски»
Placeholder: «Любая фраза…»

**CTA**
Secondary: «Голосом»
Primary: «Перевести»

**Motion**
Field появляется через opacity + y-translation 12pt. После перевода surface morphs в тот же Result state, без нового несвязанного sheet.

## Slide 9
### Dictionary: empty / saved / edit confirmation

**Сценарий**
Пользователь открывает личный словарь, сохраняет фразу или редактирует её.

**Композиция мокапа**
GlassWorkbench с единым dictionary canvas. Empty state и list state используют один и тот же header/material. Редактирование — inline sheet, не переход в Speaker.

**Состояния**
Empty: «Твой словарь пока пуст» + «Добавить фразу».
Saved: row с Thai, translit, Russian meaning и actions audio/copy/train/edit/delete.
Edit: «Изменить фразу» с тремя полями и CTA «Сохранить».
Confirmation: короткий inline toast «Сохранено в словарь», без второго modal.

**CTA**
Empty: «Добавить фразу».
Edit: «Сохранить».

## Slide 10
### Единая система Taika Overlay

**Группы поверхностей**
GlassMessage — короткая информация и recovery.
GlassChoice — режимы и планы.
GlassPaywall — коммерческое решение.
GlassWorkbench — Speaker, Search и Dictionary.

**Visual rules**
Тёмный near-black canvas, controlled blur, graphite-violet glass, pink-lilac active tint, thin inner highlight, no hard header/body split.

**Interaction rules**
Каждый state должен объяснять, что произошло, что делать сейчас и что будет после CTA. Закрытие всегда возвращает в исходный контекст. Motion подтверждает действие, но не заменяет смысл.

**Implementation gate**
Сначала утвердить этот visual/interaction system, затем вынести его в reusable SwiftUI primitives и только после этого обновлять конкретные overlays.
