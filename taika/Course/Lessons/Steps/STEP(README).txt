STEP COMPONENT  
PRODUCT + TECHNICAL SPECIFICATION (V1)

====================================================
1. PRODUCT ROLE
====================================================

Step is the atomic learning unit inside:

Course → Lesson → Step → HomeTask

A Step is not a screen.
A Step is a structured educational interaction block.

Each Step must:
- introduce or reinforce one learning concept
- provide interaction
- provide feedback
- report progress

Step is the core pedagogical engine of Taika.


====================================================
2. PRODUCT PURPOSE
====================================================

Step exists to:

1. Present learning material (word, phrase, slang, structure)
2. Attach phonetic transcription
3. Attach audio reference
4. Enable repetition
5. Move user forward in controlled progression

Step must feel:
- minimal
- structured
- intentional
- pedagogically clear


====================================================
3. ARCHITECTURE CONTRACT
====================================================

Strict separation of concerns:

StepData
- pure content model
- no logic
- loaded from JSON

StepManager
- owns state machine
- controls progress
- controls audio triggering
- validates interactions (if any)

StepView
- binds to StepManager
- routes actions
- does not compute business logic

StepDS
- pure rendering
- no logic
- no validation
- no state mutation

StepAudio
- handles audio playback
- does not mutate Step state

StepAnimation
- contains isolated animation helpers
- does not contain business logic


====================================================
4. STEP DATA MODEL
====================================================

Each Step must contain:

- id
- type
- primary text (thai)
- transcription (russian phonetics)
- translation (russian meaning)
- audio reference
- optional metadata

Example conceptual model:

struct StepData {
    let id: String
    let type: StepType
    let thaiText: String
    let transcription: String
    let translation: String
    let audioFile: String?
}

Content constraints (from Content Standard v1.0):

- transcription must use "-" as syllable separator
- tone markers remain part of syllable
- no logic-based parsing inside Step
- syllable parsing is delegated to game layer

StepData is content-atomic.
Games and Speaker derive behavior from it.


====================================================
5. STEP STATE MACHINE
====================================================

enum StepState {
    case idle
    case presenting
    case interacted
    case completed
}

Flow:

idle → presenting (on appear)
presenting → interacted (user action)
interacted → completed (validation success)

StepManager controls transitions.


====================================================
6. PROGRESSION & MASTERY LOGIC
====================================================

Step completion and Step mastery are different concepts.

Completion:
- Boolean state inside Lesson scope
- Means user interacted once successfully
- Unlocks next Step

Mastery:
- Persistent score (0–100)
- Managed by ProgressManager (global)
- Aggregates:
    Exposure
    Reinforcement
    Production

Rules:

- Completion does NOT equal Mastery.
- Step can be completed but still remain in Learning state.
- Mastery state is computed externally and injected via ProgressManager.

Mastery thresholds:

0–39   = Learning  
40–69  = Improving  
70–100 = Stable  

StepManager must:

- Notify ProgressManager on completion
- Expose masteryState for UI rendering
- Never compute mastery score internally

If mastery decays (time-based decay model),
Step must visually reflect it (badge / indicator),
but must NOT block navigation.

Progress remains lesson-scoped.
Mastery is cross-lesson and persistent.


====================================================
7. AUDIO BEHAVIOR
====================================================

StepAudio must:

- allow replay
- not auto-loop
- optionally auto-play on first appearance
- never block UI thread

Audio state must not interfere with StepState.


====================================================
8. VISUAL CONTRACT (StepDS)
====================================================

StepDS must:

- respect ThemeManager tokens
- never use adaptive layout without constraints
- never overflow width
- use consistent spacing (multiples of 4 or 8)

Visual hierarchy:

1. Thai text (primary)
2. Transcription
3. Translation
4. Interaction (if present)
5. Continue CTA


====================================================
9. INTEGRATION WITH HOMETASK
====================================================

HomeTask is triggered after Step completion.

StepManager must expose:

- isLastStep
- isCompleted
- canOpenHomeTask

Step does NOT contain HomeTask logic.
It only signals completion.


====================================================
9.1 INTEGRATION WITH SPEAKER (PRODUCTION LAYER)
====================================================

Speaker is the Production layer of Mastery.

StepManager must expose:

- productionEligible (if StepType supports pronunciation)
- currentMasteryScore
- productionScore (best or rolling average)

Speaker attempts must:

- update Production component of Mastery
- not mutate StepState directly
- not auto-complete Step

Production affects Mastery,
not Completion.


====================================================
10. DESIGN PRINCIPLES
====================================================

- Minimal
- Stable layout
- No dynamic resizing jumps
- No unnecessary animations
- Clarity over decoration

Premium feel = restraint + spacing + structure.

- Mastery state must be visually readable but subtle
- No layout shift when mastery changes
- Stable vertical rhythm across all Step types
- No conditional layout branching inside DS


====================================================
11. EXTENSIBILITY
====================================================

StepType must be extensible:

enum StepType {
    case info
    case pronunciation
    case practice
    case challenge
}

Future Step types must plug into the same StepManager state machine.


====================================================
12. WHAT STEP IS NOT
====================================================

Step is NOT:
- a navigation container
- a game engine
- a layout experiment

It is a controlled educational interaction unit.


====================================================
13. CHANGELOG
====================================================

2026-02-21 (EPIC 1 — Learning Core Stabilization)

StepManager:
- Единственная точка записи learned: setLearned(index:), setLearned(courseId:lessonId:index:isLearned:). Все вызовы ProgressManager/LessonsManager идут только из StepManager.
- Атомарный контракт Step: StepData.isValidForProgress(), invalidProgressIndices(for:); невалидные шаги (нет transcript/audio) исключены из progressEligibleIndices и excludedProgressIndexes.
- notifyProgress() вызывается сразу после notifyProgressStoreStep(), чтобы LessonsManager и игры видели завершённый урок без задержки.

StepView:
- При загрузке урока вызывается StepManager.configure(courseId:lessonId:steps:) для выравнивания контекста и индексов.
- Тап «запомнил»/стрелка: только StepManager.setLearned; anim.learned синхронизируется из StepManager (syncAnimLearnedFromStepManager).
- После отметки «запомнил» или тапа по стрелке: перелистывание карусели на следующую learnable-карточку с withAnimation(.spring); сохранение индекса в StepManager для «Продолжить».
- Удалены дублирующие postStepProgressSnapshot/scheduleProgressSnapshot; прогресс идёт только из StepManager.

HomeTask (Match):
- buildRound (режим курса): прогресс берётся по courseId и при отсутствии по ccid (LessonsManager.shared.progress[courseId] ?? progress[ccid]), чтобы не было «нет пар для матча» из-за разного формата ключей (underscore vs dash).

2026-02-21 (критический фикс — восстановление «выучено»):
- StepManager.reloadFromProgressStore() при загрузке урока читал прогресс по сырому LessonKey(courseId, lessonId), тогда как ProgressManager хранит по каноническому ключу (makeKey: lowercase, "_" → "-"). Из-за этого lookup всегда возвращал [], сохранённый learned не подхватывался — на экране и в играх «выучено» не отображалось. Исправлено: чтение через ProgressManager.learnedSet(courseId:lessonId:), который внутри использует ту же канонизацию, что и при записи.

====================================================
END OF STEP SPEC
====================================================
