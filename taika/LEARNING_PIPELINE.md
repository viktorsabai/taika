


# TAIKA — LEARNING PIPELINE ARCHITECTURE

---

## TABLE OF CONTENTS

1. Product Vision  
2. Global User Flow  
3. Component Responsibilities  
4. Pro Gating Model  
5. Progress Architecture  
6. UX Contract  
7. Navigation Contract  
8. User Stories  
9. Scalability Rules  
10. Core User Stories  
11. Non‑Negotiable Rules  
12. Learning Model  
13. Difficulty System  
14. Feedback Loop Model  
15. Anti‑Patterns & Guardrails  

---

## 1. PRODUCT VISION

Taika is a structured Thai learning ecosystem.

Core principle:
Step is the atomic unit of learning.
Everything else (Lesson, Course, Games, Speaker) is an aggregation or reinforcement layer built around Step.

---

## 2. GLOBAL USER FLOW

Main
 → Course
   → Lessons
     → Step
       → HomeTask (Games)
       → Speaker

Navigation rules:
- Course is top-level entry from Main.
- Lessons is always scoped to a Course.
- Step is always scoped to a Lesson.
- HomeTask and Speaker are scoped to a Step.
- Back navigation never breaks the hierarchy.

---

## 3. COMPONENT RESPONSIBILITIES

### 3.1 Course

Purpose:
- Macro-level learning structure.
- Program overview.
- High-level progress tracking.

Responsibilities:
- List courses.
- Show aggregated progress (based on Lessons).
- Provide entry into Lessons.

Does NOT:
- Handle Step logic.
- Handle game logic.
- Contain audio logic.

---

### 3.2 Lessons

Purpose:
- List of lessons inside a course.
- Mid-level progress aggregation.

Responsibilities:
- Display lesson cards.
- Show lesson completion (based on Steps).
- Provide entry into Step.
- Provide access to game modes for a lesson (via GameModePicker).

Lesson progress:
- Derived from Step completion state.

Does NOT:
- Contain card content.
- Contain game business logic.

---

### 3.3 Step (Atomic Unit)

Purpose:
- Present learning content.
- Manage learning state for a single unit.

Contains:
- Cards (word / phrase / slang / etc.).
- Audio playback.
- Step-level progress state.

Step completion:
- Based on user interaction with cards (defined in StepManager).

Step is the source of truth for:
- What material exists.
- What syllables exist.
- What transcription exists.
- What audio exists.

All games must derive content from Step.

---

### 3.4 HomeTask (Games Layer)

Purpose:
- Reinforcement of Step content.
- Controlled gamification.

Game types:
- Match (free)
- Recall / Builder (PRO)
- Future extensions

Rules:
- Games never introduce new content.
- Games consume StepData only.
- Games do not own educational material.

Game completion:
- Feeds into Step reinforcement metrics.
- May increase lesson-level mastery score.

Free vs Pro:
- Match = Free
- Recall and advanced games = PRO

---

### 3.5 Speaker

Purpose:
- Pronunciation practice.
- Audio-based reinforcement.

Modes:
- Basic feedback (Free)
- Detailed scoring (PRO)

Speaker must:
- Use Step audio content.
- Never bypass Step hierarchy.
- Report progress back to Step context.

---

## 4. PRO GATING MODEL

Free:
- Course browsing
- Lessons browsing
- Step content
- Match game
- Basic Speaker

PRO:
- Recall game
- Advanced Speaker scoring
- Future advanced exercises

PRO gating must:
- Exist at entry points (GameModePicker / Speaker entry).
- Not exist inside core Step content.

---

## 5. PROGRESS ARCHITECTURE

Single Source of Truth:
Step.

Aggregation model:

Step → Lesson → Course

Definitions:

Step Progress:
- Completion state
- Reinforcement score
- Game performance

Lesson Progress:
- Aggregated Step completion
- Percentage of Steps completed

Course Progress:
- Aggregated Lesson completion

Games:
- Modify Step reinforcement
- Do not directly modify Course

Speaker:
- Modify Step pronunciation score

---

## 6. UX CONTRACT

Across entire pipeline:

- Background comes only from AppShell.
- No system toolbars.
- Headers follow AppShell contract.
- Taika identity (bubble, tone, spacing) must be consistent.
- No standalone visual systems inside games.

Games must feel like:
"Step reinforcement inside Taika",
not "external mini-app".

---

## 7. NAVIGATION CONTRACT

AppShell:
- Controls header rendering.
- Controls background.
- Controls tab visibility.

Nested flow:
CourseView
 → LessonsView
   → StepView
     → GameShell / SpeakerView

Rules:
- Only AppShell renders global header.
- Step-level back navigation must respect hierarchy.
- No duplicate headers inside DS.

---

## 8. USER STORIES (CORE)

US-01:
As a new user,
I want to open a course,
so that I can start structured learning.

US-02:
As a learner,
I want to complete steps,
so that I progress through lessons.

US-03:
As a learner,
I want to reinforce knowledge via games,
so that I retain syllables and phrases.

US-04:
As a PRO user,
I want advanced exercises,
so that I can deepen mastery.

US-05:
As a learner,
I want consistent UI behavior,
so that I never feel lost between modules.

---

## 9. SCALABILITY RULES

- All new game types must consume StepData.
- No game may store standalone content.
- No visual duplication of header/background.
- All scoring must map back to Step.

If a feature does not map back to Step,
it does not belong in the learning pipeline.

---

END OF DOCUMENT

# TAIKA — LEARNING PIPELINE ARCHITECTURE (v2.0)

---

## 1. PRODUCT VISION

Taika is a structured Thai learning ecosystem.

Core principle:
Step is the atomic unit of learning.

Everything else (Lesson, Course, Games, Speaker, Progress) is an aggregation, reinforcement, or analytics layer built around Step.

If a feature does not map back to Step — it does not belong in the learning pipeline.

---

## 2. GLOBAL USER FLOW

Main  
 → Course  
   → Lessons  
     → Step  
       → HomeTask (Games)  
       → Speaker  

Hierarchy rules:
- Course is entry from Main.
- Lessons is scoped to a Course.
- Step is scoped to a Lesson.
- HomeTask and Speaker are scoped to a Step.
- Navigation never bypasses hierarchy.
- No module owns global state outside its scope.

AppShell:
- Owns header.
- Owns background.
- Owns tab visibility.
- Nested modules must not duplicate global UI.

---

## 3. DATA OWNERSHIP MODEL

Single source of truth: **Step**

### 3.1 Step owns:
- Card content
- Thai text
- Syllables (including tone marks as syllable boundaries)
- Transcription
- Audio references
- Completion state
- Reinforcement metrics
- Pronunciation score

### 3.2 Managers

StepManager:
- Owns step-level learning state
- Updates completion
- Tracks reinforcementScore
- Tracks pronunciationScore

HomeTaskManager:
- Reinforcement only
- Cannot create new learning data
- Cannot modify lesson or course directly
- Reports results back to StepManager

SpeakerManager:
- Handles recording lifecycle
- Handles scoring
- Reports pronunciation score back to StepManager

ProgressManager:
- Aggregates:
  Step → Lesson → Course
- Does not generate primary state
- Only aggregates

UserSession:
- Persistence layer
- Does not contain learning logic

---

## 4. STATE MACHINES

### 4.1 Step State

idle  
→ interacting  
→ completed  

Completion defined by StepManager.

---

### 4.2 Game (HomeTask) State

idle  
→ selecting  
→ readyForCheck  
→ checking  
→ success | failure  
→ nextRound  

Important:
- No intermediate red states while user is building.
- Validation occurs only:
  - After explicit “Check” action
  OR
  - After full slot count reached.

No publish inside View body.

---

### 4.3 Speaker State

idle  
→ recording  
→ analyzing  
→ feedback  

Rules:
- Recording state must not auto-reset without explicit transition.
- Scoring must update Step pronunciationScore.
- PRO scoring adds detail layer, not separate logic path.

---

## 5. HOME TASK (GAMES) CONTRACT

Purpose:
Reinforce Step content.

Game types:
- Match (Free)
- Recall / Builder (PRO)
- Future games

Rules:
- Games consume StepData only.
- No standalone game content.
- No external visual systems.
- No separate header.

Reinforcement model:

Each Step contains:
- reinforcementScore
- gameAttempts
- gameMastered (Bool)

Game completion:
- success increments reinforcementScore
- repeated success can set gameMastered = true
- failure increments attempts but does not regress completion

Lesson completion does NOT depend on game mastery.

Games are reinforcement, not blockers.

---

## 6. PRO GATING MODEL

Free:
- Course browsing
- Lessons browsing
- Step content
- Match game
- Basic Speaker

PRO:
- Recall game
- Advanced Speaker scoring
- Future advanced exercises

Rules:
- Gating happens at entry (GameModePicker / Speaker entry).
- Gating does NOT exist inside Step.
- Gating must not break navigation stack.
- Free fallback must be deterministic.

---

## 7. PROGRESS ARCHITECTURE

Primary unit: Step

### Step Progress:
- completionState
- reinforcementScore
- pronunciationScore

### Lesson Progress:
- Derived from Step completion percentage

### Course Progress:
- Derived from Lesson completion percentage

Games:
- Modify reinforcementScore only.

Speaker:
- Modifies pronunciationScore only.

No module may directly modify Lesson or Course.

Aggregation only.

---

## 8. UX CONTRACT

Across entire pipeline:

- Background comes from AppShell only.
- No nested toolbars.
- No duplicate headers.
- Taika identity must be consistent:
  - Bubble tone
  - Spacing
  - Accent tokens
- Games must feel like:
  “Step reinforcement inside Taika”
  not external mini-app.

View layer:
- No business logic.
- No state mutation in body.
- No publish during render.

Manager layer:
- Sole mutator of state.
- Explicit transitions only.

DS layer:
- Pure visuals.
- No logic.
- No navigation.
- No state.

---

## 9. SCALABILITY RULES

All future extensions must:

- Consume StepData.
- Map back to Step progress.
- Respect AppShell contract.
- Respect state machine rules.
- Avoid duplicating visual systems.

If a feature:
- Cannot map to Step,
- Cannot report into reinforcement or pronunciation,
- Or breaks hierarchy,

It does not belong in learning pipeline.

---

## 10. CORE USER STORIES

US-01  
As a user, I open a course and understand macro progress.

US-02  
As a learner, I complete Steps and see progress reflected upward.

US-03  
As a learner, I reinforce knowledge via games that feel native to Taika.

US-04  
As a PRO user, I access deeper exercises and detailed scoring.

US-05  
As a user, I never feel lost in navigation or visual inconsistencies.

US-06  
As a learner, I see consistent feedback loops (game → reinforcement → step → lesson → course).

---

## 11. NON-NEGOTIABLE RULES

- Step is atomic.
- No standalone game content.
- No visual duplication of global layout.
- No mutation in View body.
- No implicit state transitions.
- No broken hierarchy navigation.

If something feels like a mini-app inside Taika —
it is architecturally wrong.

---

---

## 12. LEARNING MODEL

Taika is not a content viewer.  
It is a mastery engine built around Step.

### 12.1 Learning Philosophy

- Structured progression
- Reinforcement-driven retention
- Audio-first language acquisition
- Syllable-level cognition (tone marks included as boundaries)

Step is considered “exposed” when:
- User has interacted with content.
- Audio has been played.
- Basic interaction occurred.

Step is considered “completed” when:
- Defined completion criteria in StepManager are met.

Step is considered “mastered” when:
- reinforcementScore ≥ masteryThreshold
AND
- pronunciationScore ≥ pronunciationThreshold (if applicable)

Mastery must be explicitly defined in StepManager.

---

## 13. DIFFICULTY SYSTEM

Difficulty is progressive and contextual.

### 13.1 Step Difficulty

Each Step may contain:
- difficultyLevel (1–5)
- syllableCount
- phraseLength

Difficulty increases by:
- More syllables
- Reduced hints
- Audio-first interaction
- Removal of transcription

---

### 13.2 Game Difficulty Scaling

Recall / Builder game may scale by:
- Removing hint states
- Increasing distractor syllables
- Limiting retries
- Hiding transliteration

Match game scaling:
- Larger pool
- Reduced visual assistance

Games must never introduce new content.
Only alter presentation difficulty.

---

### 13.3 Speaker Strictness

Free:
- Basic correctness
- Binary feedback

PRO:
- Scoring gradient
- Tone detection
- Detailed syllable feedback

Speaker strictness may scale per Step difficulty.

---

## 14. FEEDBACK LOOP MODEL

Learning is cyclical.

Step → Game → Reinforcement → Step  
Step → Speaker → Pronunciation → Step  

### 14.1 Reinforcement Logic

HomeTask success:
- increments reinforcementScore
- may increase masteryIndex

Failure:
- increments attemptCount
- does NOT regress completion

ReinforcementScore must be:
- bounded
- normalized
- predictable

---

### 14.2 Pronunciation Logic

Speaker feedback updates:
- pronunciationScore
- pronunciationConfidence

Pronunciation must NOT block progression.
It enhances mastery depth.

---

### 14.3 Mastery Index

Optional unified metric:

masteryIndex = f(
    completionState,
    reinforcementScore,
    pronunciationScore
)

Lesson and Course may display:
- completion %
- mastery indicator (separate from completion)

Completion ≠ Mastery.

---

## 15. ANTI‑PATTERNS & GUARDRAILS

We must never:

- Add standalone game content not derived from StepData.
- Duplicate global UI inside games.
- Introduce state mutation inside View body.
- Allow navigation that breaks hierarchy.
- Add PRO features that do not deepen learning.
- Create mini‑apps inside Taika.

If a feature:
- Cannot map to Step,
- Cannot report into reinforcement or pronunciation,
- Or breaks architectural layering,

It does not belong in Taika.

---

END OF DOCUMENT (v3.0)

# TAIKA — LEARNING PIPELINE (CLEAN ARCHITECTURE)

---

## 1. PURPOSE OF THIS DOCUMENT

This document defines:

- Learning hierarchy
- Data ownership
- State machines
- Progress aggregation
- Reinforcement model
- Architectural guardrails

It does NOT define:
- Business strategy
- Pricing
- Market positioning
- Competitive analysis
- Unit economics

Those belong to PI_TAIKAAPP.md.

---

## 2. CORE PRINCIPLE

Step is the atomic unit of learning.

All other modules (Lesson, Course, Games, Speaker, Progress)
aggregate, reinforce, or analyze Step.

If a feature cannot map back to Step,
it does not belong in the learning pipeline.

---

## 3. LEARNING HIERARCHY

Main  
→ Course  
→ Lessons  
→ Step  
→ (HomeTask / Speaker)

Rules:
- Course is entry level.
- Lessons belong to a Course.
- Step belongs to a Lesson.
- Games and Speaker belong to a Step.
- Navigation never bypasses hierarchy.

---

## 4. DATA OWNERSHIP

Single source of truth: Step.

### 4.1 Step owns:

- Thai text
- Syllables (tone marks included as boundaries)
- Transcription
- Audio references
- Completion state
- Reinforcement score
- Pronunciation score

No other module owns learning material.

---

## 5. MANAGER RESPONSIBILITIES

### StepManager
- Controls Step completion
- Updates reinforcementScore
- Updates pronunciationScore
- Defines mastery logic

### HomeTaskManager
- Reinforcement only
- Cannot create content
- Cannot modify Lesson or Course directly
- Reports results back to StepManager

### SpeakerManager
- Handles recording lifecycle
- Handles pronunciation scoring
- Reports pronunciationScore to StepManager

### ProgressManager
- Aggregates Step → Lesson → Course
- Does not mutate primary learning state

### UserSession
- Persistence only
- No learning logic

---

## 6. STATE MACHINES

### 6.1 Step State

idle  
→ interacting  
→ completed  

Completion defined by StepManager.

---

### 6.2 Game State

idle  
→ selecting  
→ readyForCheck  
→ checking  
→ success | failure  
→ nextRound  

Rules:
- No validation during partial input.
- Validation only after explicit Check
  OR full slot completion.
- No state mutation inside View body.

---

### 6.3 Speaker State

idle  
→ recording  
→ analyzing  
→ feedback  

Rules:
- No implicit resets.
- Feedback updates Step pronunciationScore.
- PRO adds depth, not separate logic branch.

---

## 7. PROGRESS MODEL

Primary unit: Step.

### Step Progress:
- completionState
- reinforcementScore
- pronunciationScore

### Lesson Progress:
- Aggregated Step completion percentage

### Course Progress:
- Aggregated Lesson completion percentage

Games:
- Modify reinforcementScore only.

Speaker:
- Modifies pronunciationScore only.

No module directly modifies Lesson or Course.

---

## 8. REINFORCEMENT RULES

Games are reinforcement, not blockers.

Each Step may contain:

- reinforcementScore
- attemptCount
- gameMastered (Bool)

Success:
- increments reinforcementScore

Failure:
- increments attemptCount
- does NOT regress completion

Lesson completion must not depend on game mastery.

---

## 9. PRO GATING RULES

Free:
- Course browsing
- Lessons browsing
- Step content
- Match game
- Basic Speaker

PRO:
- Recall / Builder game
- Advanced Speaker scoring

Rules:
- Gating happens at entry points only.
- Gating never breaks navigation.
- Gating never blocks Step content.

---

## 10. UX CONTRACT

- Background from AppShell only.
- No nested toolbars.
- No duplicate headers.
- DS layer contains no business logic.
- View layer contains no state mutation.
- Manager layer is sole state mutator.

Games must feel like:
“Step reinforcement inside Taika”,
not standalone mini-apps.

---

## 11. SCALABILITY RULES

All new learning features must:

- Consume StepData
- Report results back to StepManager
- Respect hierarchy
- Respect state machines
- Respect AppShell layout contract

If a feature:
- Cannot map to Step
- Cannot update reinforcement or pronunciation
- Or breaks hierarchy

It does not belong in Taika learning pipeline.

---

END OF DOCUMENT

# taika — learning pipeline (clean)

## содержание
1. цель документа  
2. принцип: step = атом  
3. иерархия обучения  
4. ownership данных  
5. менеджеры: ответственность  
6. state machines  
7. прогресс и метрики  
8. reinforcement model (игры)  
9. pro gating  
10. ux / ui контракт  
11. анти‑паттерны и правила масштабирования  

---

## 1. цель документа

этот файл фиксирует архитектуру обучения: иерархию, ownership данных, state‑машины, модель прогресса и контракт ux/ui.

не здесь:
- рынок / конкуренты / позиционирование / moat
- тарифы / цены / unit economics
- go‑to‑market

это всё живёт в **pi_taikaapp.md**.

---

## 2. принцип: step = атом

**step** — единственная атомарная единица обучения.

всё остальное (lesson/course/games/speaker/progress) только:
- агрегирует step
- усиливает step (reinforcement)
- измеряет step (analytics)

если фича не мапится на step — её нет в пайплайне.

---

## 3. иерархия обучения

main  
→ course  
→ lessons  
→ step  
→ (hometask / speaker)

правила:
- lessons всегда внутри course
- step всегда внутри lesson
- games и speaker всегда внутри step
- навигация не перепрыгивает уровни

---

## 4. ownership данных

single source of truth: **step**.

### step хранит:
- thai text / phrase
- слоги (включая tone marks как границы слога)
- транскрипцию
- аудио‑ссылки / аудио‑метаданные
- completion state
- reinforcement metrics
- pronunciation score

ни один другой модуль не “владеет” учебным материалом.

---

## 5. менеджеры: ответственность

### stepmanager
- определяет критерии completion
- ведёт step state
- хранит/обновляет: completion, reinforcementScore, pronunciationScore

### hometaskmanager
- reinforcement only
- потребляет stepdata
- не создаёт контент
- не модифицирует lesson/course напрямую
- репортит результат в stepmanager

### speakermanager
- lifecycle: idle → recording → analyzing → feedback
- скоринг произношения
- репортит pronunciationScore в stepmanager

### progressmanager
- агрегирует step → lesson → course
- не мутирует primary learning state

### usersession
- персистенс/кэш/restore
- без обучающей логики

---

## 6. state machines

### 6.1 step state
idle → interacting → completed  
completion определяет stepmanager.

### 6.2 game state (hometask)
idle → selecting → readyForCheck → checking → success|failure → nextRound

правила:
- **нет** валидации на неполном вводе
- валидация только:
  - по явному действию “check”
  - или когда заполнены все слоты (если выбран такой режим)
- **нельзя** publish из view body (никаких мутаций во время рендера)

### 6.3 speaker state
idle → recording → analyzing → feedback

правила:
- никаких “самосбросов” без явного перехода
- pro добавляет глубину фидбека, но не отдельную ветку логики обучения

---

## 7. прогресс и метрики

базовая единица прогресса: step.

### step progress:
- completionState
- reinforcementScore
- pronunciationScore

### lesson progress:
- агрегированный % completion по steps

### course progress:
- агрегированный % completion по lessons

игры:
- меняют **только** reinforcementScore

speaker:
- меняет **только** pronunciationScore

ни один модуль не должен напрямую “править” lesson/course (только агрегация).

---

## 8. reinforcement model (игры)

игры = reinforcement, не блокеры.

для каждого step:
- reinforcementScore (bounded/нормализован)
- attemptCount
- gameMastered (optional)

успех:
- +reinforcementScore
- опционально приводит к gameMastered=true

ошибка:
- +attemptCount
- **не** откатывает completion

lesson completion не зависит от game mastery.

---

## 9. pro gating

free:
- course / lessons / step контент
- match game
- basic speaker

pro:
- recall/builder game
- advanced speaker scoring

правила:
- gating только на entry points (game mode picker / вход в speaker)
- gating не ломает navigation stack
- gating не блокирует step контент
- для non‑pro должен быть детерминированный fallback (либо экран pro, либо free‑альтернатива)

---

## 10. ux / ui контракт

глобально:
- background задаёт **только appshell**
- header рисует **только appds через appshell**
- никаких nested navigationstack
- никаких дублирующих header/toolbars
- ds = чистый ui (без бизнес‑логики)
- view = сборка/wiring (без мутаций в body)
- manager = единственный мутатор состояния

игры должны ощущаться как:
“reinforcement внутри taika”, а не отдельное мини‑приложение.

---

## 11. анти‑паттерны и правила масштабирования

запрещено:
- standalone game content (не из stepdata)
- дублировать header/background внутри экранов
- мутации state из view body
- обход иерархии навигации
- “мини‑приложения” внутри taika

скейл правило:
любой новый модуль обучения должен:
- потреблять stepdata
- репортить результат в stepmanager
- соблюдать state‑машины
- соблюдать appshell контракт

---

## 12. changelog (pipeline)

**2026-02-21 (EPIC 1 — Learning Core Stabilization)**  
- Step — единственная точка записи learned: StepView/MainView вызывают только StepManager.setLearned; ProgressManager и LessonsManager обновляются только из StepManager.  
- Сохранение прогресса: ProgressManager и UserSession сохраняют сразу при setStepLearned (без debounce), чтобы прогресс не терялся при выходе.  
- LessonsManager получает notifyProgress() сразу после каждого toggle шага — игры и курс видят .completed без задержки.  
- Атомарный контракт Step: невалидные шаги (нет transcript/audio) исключены из прогресса (StepData.isValidForProgress, invalidProgressIndices).  
- Перелистывание карусели при «запомнил»/стрелке с анимацией; сохранение индекса для «Продолжить».  
- Match (HomeTask): ключ прогресса courseId/ccid исправлен, см. STEP(README).txt.

**2026-02-21 (EPIC 5 — Main)**  
- Main «Продолжить»: CDLessonCarousel, anchor .leading, slot height под depth. Поиск: оверлей в AppShell (SearchOverlayView), поиск из вкладки Курсы открывается поверх текущего экрана. «Подборка для тебя» (Кун Кру) вместо «План на неделю».

---

end of document
