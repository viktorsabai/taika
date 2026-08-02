# SESSION COMPONENT — TAiKA

## 1. BUSINESS ROLE

Session — это системный слой состояния пользователя.

Это не экран.
Это не UI.
Это не обучение.

Session отвечает за:
- текущего пользователя
- авторизацию
- локальное состояние сессии
- восстановление состояния после перезапуска
- связь между ProManager и ProgressManager
- единый источник identity

Если Profile — это отображение пользователя,
то Session — это его реальное существование в системе.

---

## 2. POSITION IN ARCHITECTURE

Global Layers:

UserSession
    ↓
ProManager
    ↓
ProgressManager
    ↓
Learning Pipeline

Session — самый нижний слой пользовательского состояния.

Он не знает о UI.
Он не знает о конкретных View.
Он предоставляет:
- userId
- auth state
- isLoggedIn
- persisted flags

---

## 3. USER SESSION CONTRACT

### UserSession responsibilities

UserSession — Single Source of Truth для:

- текущего userId
- login state
- first launch flag
- onboarding state
- persisted user preferences

Он должен:
- сохраняться локально
- восстанавливаться при запуске
- быть доступным через EnvironmentObject

Он НЕ должен:
- управлять прогрессом обучения
- управлять подпиской напрямую
- выполнять network-запросы обучения

---

## 4. PROGRESS MANAGER RELATIONSHIP

ProgressManager зависит от UserSession.

Правило:

Если userId меняется →
ProgressManager должен пересинхронизироваться.

Session управляет тем:
- какой пользователь активен
- какой прогресс загружать

ProgressManager:
- считает прогресс
- не решает кто пользователь

### Progress source of truth (EPIC 4)

- **«Выучено» (learned step indices):** единственный источник истины — ProgressManager.learnedSteps (персист в UserDefaults). Запись только через StepManager → ProgressManager.setStepLearned; UserSession.snapshot.learnedSteps обновляется из ProgressManager.
- **Агрегаты урока/курса (проценты):** курс-процент для дашборда считается в ProgressManager.progress(for: courseId, lessonId: nil) по learnedSteps + lessonMetaProvider (LessonsData/StepData). LessonsManager хранит агрегаты для экранов Course/Lessons; при старте они пересобираются из ProgressManager (rebuildAggregatesFromProgressManager), чтобы персист LM не расходился с PM.
- **Кто откуда читает:** MainView/MainManager — ProgressManager.progress(for:); CourseView/LessonsView — LessonsManager.coursePercent/lessonProgress; ProfileManager — ProgressManager.progress; Speaker — UserSession.snapshot.learnedSteps.
- **Диапазон:** все публичные API прогресса возвращают значение в [0, 1].
- **Персист и миграции:** схема шагов «выучено» живёт в `ProgressManager` (внутренний `PMStore` в `ProgressManager.swift`). `LessonsManager` дополнительно кодирует агрегаты в UserDefaults (`LessonsManager.progress.v1`, `LessonsManager.started.v1`); при каждом `load()` после декода вызывается `rebuildAggregatesFromProgressManager()`, чтобы выровнять проценты с PM. Менять ключ LM без явной миграции — только осознанно: первый кадр может кратко показать старый снимок до пересчёта.

---

## 5. PRO MANAGER RELATIONSHIP

ProManager использует:
- userId
- entitlement state

Session хранит:
- tier
- purchase flags (если локально)

ProManager валидирует.
Session хранит.

---

## 6. STATE RESTORATION (MVP)

Session supports:

- restoring userId
- restoring isLoggedIn
- restoring basic local flags (onboarding / first launch)

Session does NOT restore:
- mastery calculations
- learning state
- decay state
- AI quota

Those belong to ProgressManager or future versions.

---

## 7. AUTH MODES (CURRENT + FUTURE)

Текущий режим:
- локальный пользователь
- без серверной авторизации

Будущий режим:
- email login
- OAuth
- Apple ID
- cloud sync

Архитектура Session должна быть готова к этому.

---

## 8. ANTI-PATTERNS

Session НЕ должен:

- знать о StepData
- знать о Lesson структуре
- вызывать GameManager
- хранить визуальные состояния
- триггерить навигацию напрямую

Session — это state container.

---

## 9. SCALABILITY

Session должен поддерживать:

- multi-device sync
- server profile
- offline mode
- feature flags
- experiment flags
- AI usage tracking

Расширение происходит через:
- добавление новых persisted свойств
- без изменения UI компонентов

---

## 10. SUMMARY

Session = фундамент пользователя.

Он:
- определяет, кто пользователь
- определяет, есть ли сессия
- хранит состояние
- связывает монетизацию и прогресс

Если Session начинает управлять обучением —
архитектура нарушена.

Если обучение начинает хранить identity —
архитектура нарушена.

Session = identity & state container layer.

---

## 11. CURRENT IMPLEMENTATION (AS-IS)

Текущее состояние Session в коде:

- реализован `UserSession` как EnvironmentObject
- хранится `userId`
- хранится `isLoggedIn`
- сохраняются базовые флаги (onboarding / first launch)
- есть связь с `ProgressManager`
- есть связь с `ProManager`
- поддерживается восстановление базового состояния при запуске

---

## MVP SCOPE (LOCKED)

Session in MVP is:

- identity holder
- local persistence container
- environment object
- bridge between ProManager and ProgressManager

Nothing more.

Advanced features (cloud sync, quota tracking, mastery snapshot, decay integration)
are FUTURE scope and intentionally excluded from MVP.

---

## 12. CHANGELOG

**2026-03-31 (March Epic — Profile Metrics Contract)**  
- Profile dashboard contract aligned to canonical pipeline: `ProfileManager` now reads canonical metrics from `ProgressManager.publishedState` (after refresh), reducing parallel-formula drift risk.  
- Session/Progress responsibility boundary remains unchanged: identity/session in UserSession, metric computation in ProgressManager, presentation in Profile layer.

**2026-02-21 (EPIC 4 — Progress Consistency)**  
- ProgressManager.lessonMetaProvider подключён из LessonsData/StepData при инициализации; курс-процент считается из learnedSteps по одной формуле, без fallback на LM для дашборда.  
- LessonsManager при load() пересобирает агрегаты из ProgressManager (rebuildAggregatesFromProgressManager), чтобы персист LM совпадал с PM после рестарта.  
- Источник истины и читатели прогресса задокументированы в §4 (Progress source of truth).

**2026-02-21 (EPIC 1)**  
- UserSession.setStepLearned: сохранение переведено с saveDebounced() на прямой save(), чтобы состояние «выучено» не терялось при быстром выходе.  
- ProgressManager по-прежнему вызывает UserSession.setStepLearned при каждом setStepLearned; запись в ProgressManager теперь тоже immediate (см. ARCHITECTURE_TECH.md).
