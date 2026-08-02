# Sprint: April 2569
## Taika iOS — Stabilization, Conversion, and Final Polish

---

# 🎯 Sprint Goal

Закрыть хвосты после мартовского UX/Architecture эпика:
- добить регрессионную надёжность,
- дотюнить conversion-сценарий Smart Speaker demo,
- провести массовый QA-проход карточек и профиля.

---

# 🔥 EPIC A-1 — Regression Hardening (P0)

## Objective
Поймать и закрыть все критические расхождения поведения между входными путями и после back-навигации.

## Scope
- Entry path parity: Main / Course / Lessons / Favorites / Speaker.
- Header/back parity: без дублей, без неожиданных системных элементов.
- Carousel persistence: verify + edge cases при смене контента/фильтров.
- Free/PRO gating sanity: speaker, smart speaker demo, course game affordances.

## Definition of Done
- Regression checklist пройден на устройстве.
- Нет P0/P1 багов в навигации и возвратах.

---

# 🔥 EPIC A-2 — Smart Speaker Conversion Loop (P0)

## Objective
Сделать free demo понятным и конверсионным, без «глючного» ощущения.

## Scope
- Онбординг-копирайт и ритуал «что сделать → что получил → что дальше».
- Ясный free quota UX (не путать с обычным speaker).
- Полировка dictionary / politeness UI в реальных сценариях.
- Критические тайминги и микроанимации фаз (recording/analyzing/hint/feedback).

## Definition of Done
- Free user понимает демо за один проход.
- Нет сценариев «нажал — непонятно что случилось».
- Конверсионный путь на PRO очевиден и не агрессивен.

---

# 🔥 EPIC A-3 — Card QA Sweep (P1)

## Objective
Финальный сквозной аудит карточек после унификации.

## Scope
- Course/Lesson/Favorites readability (long text, chips, subtitle wrapping).
- Lesson flip back-face quality (коротко, полезно, без шума).
- Theory-only (`course_b_0`) визуально и логически согласован на всех экранах.

## Definition of Done
- Нет «нечитабельных» карточек в целевых категориях.
- Flip у lesson карт выглядит нативно и мотивирует закрепление.

---

# 🔥 EPIC A-4 — Profile Final Polish (P1)

## Objective
Довести профиль до финального визуала без изменения каноники метрик.

## Scope
- Типографика/spacing/иерархия блоков.
- Точечная полировка контента карточек статистики.
- Проверка соответствия labels ↔ formulas (через canonical `ProgressManager`).

## Definition of Done
- Профиль в айдентике Taika и без метрик-дрейфа.
- Нет дублирующих формул в активном рендер-пути.

---

# ✅ EPIC A-5 — Step «картотека» / зачётка урока (закрыт в коде)

Связка карусели Step, Taika FM, переход «следующий урок / курс», оверлей завершения и лайфхак-карточка.

## Сделано
- **Taika FM:** цепочка подсказок (tip → hints → текст карточки → taikafm.json); нет вечной фазы «печатает» на пустом контенте (`TaikaFMBubbleTyping.effectiveMessages`).
- **Следующий урок:** старт с нормализованного начала урока без подтягивания чужого `lastStepIndex`; сброс индекса в сессии при переходе.
- **Следующий курс (modal):** `StepNextCourseFullScreenHost` — тот же `AppHeader` `.back`, что у урока в `NavigationStack`, плюс `startIndex: 0`.
- **Две карусели (лайфхаки / карточки):** `applyCarouselIndex` + синхронизация сегментов; `onActiveIndexChange` в `SDStepCarousel`; прогресс-бар и смена чипа в хедере обновляют глобальный индекс для FM.
- **SDStepCarousel:** короче окно `isProgrammaticScroll` после программного скролла; порог `norm < 0.48` для привязки к центру — меньше дёрганья индекса.
- **Оверлей «урок закрыт»:** визуальная связка с flipped lesson card — `taikA` + `AppStatusChip(.completed)` с названием урока, заголовок в духе зачётки, `CourseInlineProgressView`, обводка карточки акцентом.
- **Лайфхак:** опциональный RU-заголовок + тело с `Theme.StepCardText.lifehackBodyFontSize` / lineLimit / scale; разворот на весь экран в том же шрифте.
- **Микро-отклик:** короткий spring scale на `StepIconCircleButton` и на избранное / прослушать в `AppCardIconButton`.

## Definition of Done
- Сценарии: один сегмент; два сегмента; следующий урок; следующий курс из саммари; карточка без tip в JSON — FM не залипает на точках.

---

# 🚫 Out of Scope (April)

- Новый крупный функционал вне текущих эпиков.
- Переписывание content pipeline или новая контентная матрица.
- Серверная синхронизация мульти-девайс.

---

# 📋 Execution Order

1. EPIC A-1
2. EPIC A-2
3. EPIC A-3
4. EPIC A-4
5. EPIC A-5 (Step / зачётка — по готовности кода выше)

---

# ⚠️ Risks & Mitigation

- **Risk:** regressions при мелких UI-правках.  
  **Mitigation:** единый regression checklist + device run после каждого блока.

- **Risk:** free-demo снова воспринимается как «глюк».  
  **Mitigation:** сценарное тестирование с фиксированным ритуалом и UX-copy review.

- **Risk:** метрики профиля снова расходятся.  
  **Mitigation:** запрет параллельных формул в view-слое; читать только canonical state.
