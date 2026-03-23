

# MAIN COMPONENT — TAiKA

## 1. BUSINESS ROLE

Main — это не "главная страница".
Это продуктовый хаб и эмоциональная точка входа в Taika.

Main отвечает за:
- вход в учебный пайплайн (Course → Lessons → Step → HomeTask)
- вход в Speaker
- вход в Favorites
- прогресс пользователя
- контекст дня (мотивация / активность / next step)

Main не обучает.
Main направляет.

---

## 2. POSITION IN PRODUCT PIPELINE

Learning Pipeline:

Main  
  ↓  
Course  
  ↓  
Lessons  
  ↓  
Step  
  ↓  
HomeTask (games)

Main — это orchestrator верхнего уровня.
Он не хранит учебную логику.
Он не управляет шагами.
Он не знает про syllables и scoring.

Он знает:
- какой курс активен
- какой lesson последний
- какой step следующий
- есть ли PRO
- есть ли активная сессия

---

## 3. USER STORIES

### 3.1 First Open

- пользователь открывает приложение
- видит текущий прогресс
- видит CTA продолжить обучение
- видит доступ к другим разделам (Speaker / Favorites)

### 3.2 Continue Learning

- пользователь нажимает "Продолжить"
- происходит навигация в Course → Lesson → Step
- Main не решает куда идти — он вызывает CourseNavigator

### 3.3 Explore

- пользователь выбирает курс
- Main переводит его в CourseView

### 3.4 PRO Awareness

- если пользователь не PRO:
  - Main может показывать soft-entry в PRO
- Main не блокирует
- ProManager управляет доступом

---

## 4. ARCHITECTURE CONTRACT

### MainData
- статическая модель UI
- layout-секции
- не содержит бизнес логики

### MainManager
- источник правды для Main
- получает данные из:
  - CourseManager
  - ProgressManager
  - ProManager
- не знает о верстке

### MainDS
- только визуал
- никаких side-effects
- никаких navigation calls

### MainView
- собирает DS
- подписан на MainManager
- вызывает NavigationIntent

### ToolBar
- глобальная навигация
- не дублирует header
- не содержит бизнес логики

---

## 5. WHAT MAIN MUST NOT DO

Main НЕ должен:

- управлять логикой уроков
- вычислять прогресс
- управлять играми
- знать структуру StepData
- управлять PRO доступом напрямую
- создавать overlay сам

Main — чистый orchestration layer.

---

## 6. VISUAL ROLE

Main — самый эмоциональный экран.

Он должен:
- быть чистым
- быть легким
- иметь breathing space
- не быть перегруженным

Это место:
- где пользователь возвращается
- где он чувствует прогресс
- где он видит систему

---

## 7. SCALABILITY

Main должен выдерживать:

- добавление новых игровых режимов
- добавление новых блоков (Daily, Stats, Streak)
- A/B тесты
- будущие AI-модули

Расширение делается через:
- новые секции в MainData
- новые источники данных в MainManager
- новые карточки в MainDS

Без изменения контракта.

---

## 8. SUMMARY

Main = Control Center Taika.

Он не обучает.
Он направляет.
Он агрегирует.
Он держит эмоциональный тон.

Если Main начинает знать слишком много —
архитектура сломана.

---

## 9. CHANGELOG

**2026-02-21 (EPIC 5 — UI, карусель и поиск)**

- **Секция «Продолжить»:** Карусель унифицирована с CourseDS: используется `CDLessonCarousel` (один компонент на всё приложение). Первая карточка привязана по ведущему краю (anchor .leading), чтобы не обрезалась. Высота секции задаётся с запасом под depth-эффект (scale + yOffset): `slotHeight = continueCardH + 2*depthOverflow`, карточки не клипаются.
- **«План на неделю» заменён на «Подборка для тебя»:** Один тап открывает оверлей «Кун Кру» — Taika подбирает курсы по прогрессу, без выбора дня вручную.
- **Поиск:** Оверлей поиска показывается на уровне AppShell (не только в MainView). При тапе на поиск во вкладке «Курсы» поиск открывается поверх текущего экрана. Общий state: `SearchOverlayState.shared` (индекс и кэши курсов/уроков), UI: `SearchOverlayView`; paywall (speakerPaywall, proCoursePaywall) по-прежнему в AppShell.
