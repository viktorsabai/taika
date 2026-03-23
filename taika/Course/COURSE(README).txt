COURSE COMPONENT — BUSINESS & ARCHITECTURE SPECIFICATION  
product: taika  
layer: course (top-level learning container)

------------------------------------------------------------
1. BUSINESS ROLE
------------------------------------------------------------

course = стратегический уровень обучения.

это не просто список уроков.  
это:

- логическая рамка прогресса
- единица ценности для пользователя
- единица монетизации (future: course-level pro gating)
- основной объект для аналитики retention

иерархия:

course  
→ lessons  
→ steps  
→ home task / games  
→ speaker

курс — это “большая цель”,  
уроки — это этапы,  
степ — атом знания.

------------------------------------------------------------
2. RESPONSIBILITY BY FILE
------------------------------------------------------------

CourseData.swift
----------------
роль: чистая модель данных

содержит:
- структуру Course
- метаданные (id, title, description, level, cover)
- список lesson ids
- pro flag (если есть)

НЕ содержит:
- логики прогресса
- навигации
- бизнес-вычислений


CourseManager.swift
-------------------
роль: бизнес-логика курса

отвечает за:
- загрузку курса
- расчет прогресса по курсу
- состояние unlocked / locked
- агрегирование прогресса из LessonsManager
- future: course-level completion logic

ВАЖНО:
manager не рисует UI  
manager не знает про DS  
manager не делает навигацию


CourseView.swift
----------------
роль: сборка экрана

отвечает за:
- подключение manager
- передачу данных в CourseDS
- вызов CourseNavigator
- триггеры перехода к Lessons

НЕ содержит:
- бизнес-логики
- расчета прогресса
- прямых обращений к данным lessons


CourseDS.swift
--------------
роль: визуальный слой

DS рисует:
- header
- cover
- прогресс-блок
- список lessons
- pro индикаторы
- состояние locked

DS не знает:
- как считать прогресс
- как работает навигация
- откуда данные

DS получает:
- plain data
- callbacks


CourseNavigator.swift
----------------------
роль: изоляция навигации

делает:
- переход к LessonsView
- future: deep links
- future: открытие step напрямую

navigator не знает про бизнес.


CourseSearch.swift
-------------------
роль: вспомогательная логика поиска

пока вторичный слой.
может быть расширен до:
- фильтра по level
- фильтра по completed
- фильтра по pro


CourseAnimation.swift
----------------------
роль: изолированные анимации

анимации не должны жить в View.
не должны быть inline.
должны быть централизованы.

------------------------------------------------------------
3. DATA FLOW
------------------------------------------------------------

CourseData
    ↓
CourseManager
    ↓
CourseView
    ↓
CourseDS

progress flow:

LessonsManager
    ↓
CourseManager aggregates
    ↓
CourseView
    ↓
CourseDS

никакой прямой связи DS → Manager.

------------------------------------------------------------
4. NAVIGATION CONTRACT
------------------------------------------------------------

CourseView
    uses CourseNavigator

при тапе на lesson:

CourseView
    → navigator.openLesson(courseId, lessonId)

никаких NavigationLink внутри DS.

------------------------------------------------------------
5. PRO LOGIC
------------------------------------------------------------

возможные варианты:

1) course-level pro
2) lesson-level pro
3) mixed model

CourseManager должен:

- уметь отдавать isCourseLocked
- уметь отдавать isLessonLocked
- не содержать UI реакции

UI реакция:
CourseView / DS

------------------------------------------------------------
6. DESIGN CONTRACT
------------------------------------------------------------

курс обязан соответствовать айдентике taika:

- фон через AppShell
- header через глобальный header
- прогресс — единый стиль с step
- карточки lesson — reuse LessonCardV
- никаких кастомных “разовых” форм

если в курсе появляется новая визуальная форма —
она должна быть вынесена в DS,
а не создана локально в View.

------------------------------------------------------------
7. SCALABILITY
------------------------------------------------------------

будущие расширения:

- ai recommendations
- adaptive difficulty
- streak logic
- course completion reward
- certificate system
- multi-language switch

CourseManager должен быть расширяемым,
без зависимости от UI.

------------------------------------------------------------
8. WHAT IS NOT ALLOWED
------------------------------------------------------------

- бизнес-логика внутри DS
- навигация внутри DS
- progress calculations inside View
- прямой доступ CourseView к LessonsData
- inline анимации в View
- дубли токенов цвета/шрифтов

------------------------------------------------------------
9. CURRENT WEAK SPOTS (UPDATED AFTER MASTERY MODEL v1.0)
------------------------------------------------------------

после внедрения mastery_model.md появились новые требования к курсу.

текущие риски:

- course completion не учитывает mastery_score
- нет связи с decay логикой
- нет soft-warning если lesson completed, но mastery низкий
- нет course-level mastery aggregation
- progress может ≠ реальному усвоению

------------------------------------------------------------
10. COURSE ↔ MASTERY INTEGRATION
------------------------------------------------------------

курс теперь обязан учитывать не только completion,
но и mastery.

добавляется логика:

CourseManager должен агрегировать:

- completion_rate (из LessonsManager)
- average_mastery_score
- stable_steps_ratio
- learning_steps_ratio

новые computed поля:

isCourseCompleted:
    completion_rate == 100%

isCourseMastered:
    stable_steps_ratio >= 0.6

isCourseAtRisk:
    decay_detected == true

------------------------------------------------------------
11. LESSON ACCESS LOGIC (UPDATED)
------------------------------------------------------------

переход к следующему lesson НЕ блокируется,
даже если mastery низкий.

но:

если lesson completed,
но stable_steps_ratio < 0.3

CourseManager должен отдавать:
    lessonNeedsReinforcement = true

UI обязан:

- показать warning badge
- подсветить lesson
- предложить вернуться в HomeTask

никаких hard locks.

------------------------------------------------------------
12. DECAY SUPPORT
------------------------------------------------------------

если ProgressManager сигнализирует:

step перешел из stable → learning

CourseManager должен:

- пересчитать stable_steps_ratio
- обновить course mastery state
- передать сигнал в Main (для notification bubble)

курс становится участником retention loop.

------------------------------------------------------------
13. UPDATED SCALABILITY
------------------------------------------------------------

будущие расширения:

- adaptive lesson ordering
- mastery-based recommendation
- AI next best lesson
- skill graph visualization
- spaced repetition scheduler

CourseManager не должен зависеть от конкретной реализации Mastery.
он работает через интерфейс ProgressProvider.

------------------------------------------------------------
14. UPDATED STRATEGIC ROLE
------------------------------------------------------------

курс больше не просто narrative.

курс теперь:

- контейнер прогресса
- контейнер mastery
- источник retention сигналов
- узел decay логики
- основа premium ощущения

если курс показывает:
completion 100% + mastery 20%
→ пользователь понимает, что “прокликал”.

если курс показывает:
completion 80% + mastery 65%
→ пользователь видит реальный прогресс.

курс = прозрачность обучения.

------------------------------------------------------------
15. CHANGELOG
------------------------------------------------------------

2026-02-21 (EPIC 1 — Learning Core Stabilization)
- CourseManager без изменений: по-прежнему агрегирует только из LessonsManager.progress и lessonIds(for:).
- Игры (Match) на уровне курса берут карточки из LessonsManager.progress; исправление ключа (courseId vs ccid) сделано в HomeTaskView, см. STEP/HomeTask.

2026-02-21 (EPIC 5 — поиск)
- Поиск в шапке CourseView открывает оверлей поиска на уровне AppShell (SearchOverlayView), а не в MainView; оверлей показывается поверх любой вкладки (в т.ч. Курсы).

END OF SPEC
