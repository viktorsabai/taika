

LESSONS COMPONENT — BUSINESS & ARCHITECTURE SPECIFICATION

1. ROLE IN PRODUCT HIERARCHY

Global hierarchy:

Course → Lessons → Steps → (HomeTask / Speaker / Games)

Lessons is:
- navigation hub inside a Course
- progression controller between Steps
- access point to Game Modes
- PRO gating checkpoint (secondary level)

Lessons is NOT:
- business logic executor of steps
- UI-heavy playground
- game logic owner

It orchestrates. It does not compute learning mechanics.


2. BUSINESS RESPONSIBILITY

Lessons answers 5 core questions:

1) What lessons exist inside this course?
2) What is unlocked?
3) What is completed?
4) What mode is selected? (Learn / Practice / Game)
5) Is user allowed to access this mode? (Free vs PRO)

Lessons is a PROXY LAYER between Course-level navigation and Step-level learning.


3. FILE RESPONSIBILITIES

LessonsData.swift
- Pure static / JSON-driven structure.
- Defines:
  - lesson metadata
  - step references
  - order index
  - pro flags
  - lesson type (basic / practice / mixed)
- No logic.
- No state mutation.

LessonsManager.swift
- Business logic owner.
- Computes:
  - unlock rules
  - lesson progress
  - aggregated step completion
  - mode availability
- Owns:
  - current selected lesson
  - current selected game mode
  - isLocked
  - isProRequired
- Must not contain UI logic.
- Must not know about DS layout.

LessonsView.swift
- Assembly only.
- Binds to LessonsManager.
- Handles navigation to:
  - StepView
  - HomeTaskView
  - Speaker
- No heavy computation.
- No state mutation logic except view triggers.

LessonsDS.swift
- Pure visuals.
- Lesson card templates.
- Progress bar styling.
- Locked state rendering.
- PRO badge rendering.
- Uses AppDS tokens only.
- No business branching.

GameModePickerDS.swift
- Visual selector for:
  - Learn
  - Practice
  - Game
- Accepts current selection.
- Emits selection via callback.
- No business logic.


4. NAVIGATION CONTRACT

LessonsView → StepView
Pass:
- courseId
- lessonId
- selectedMode

Lessons must not:
- infer step logic
- mutate step progress directly

StepManager owns step-level progression.


5. PRO GATING RULES

Level 1: Lesson level
- Some lessons may be fully PRO.

Level 2: Mode level
- Some modes (e.g., Game 2, Speaker) are PRO.

LessonsManager must expose:

- func canAccess(lesson: Lesson)
- func canAccess(mode: GameModeType)

UI must never decide gating.
Only Manager decides.


6. PROGRESSION LOGIC

Unlock rule:
Lesson N is unlocked when:
- Lesson N-1 completion >= threshold
or
- Explicit free override flag

Completion of lesson:
- Based on Steps completion aggregation.
- LessonsManager computes aggregated progress.

Lessons never reads StepData directly.
It asks StepManager.


12. MASTERY INTEGRATION (NEW)

Lessons must integrate with MasteryModel and ProgressManager.

LessonsManager must NOT compute mastery itself.
It must read aggregated state from ProgressManager.

For each Lesson, manager must compute:

- lessonCompletionPercent
  (based on Step completion state)

- lessonMasteryPercent
  (average of Step masteryScore values)

- lessonStabilityState:
    • Learning
    • Reinforcing
    • Stable
    • Decaying

Rules:

- Lesson is considered “Completed” when:
    lessonCompletionPercent == 100%

- Lesson is considered “Stable” when:
    lessonMasteryPercent >= 60%

- If any Step inside Lesson enters Decay,
  lessonStabilityState must reflect Decaying.

IMPORTANT:
LessonsManager must not store mastery.
It only derives from Step-level state.


7. GAME MODE STRATEGY

GameModePickerDS is visual.
LessonsManager stores currentMode.

Flow:
User taps mode →
View calls manager.setMode(mode) →
Manager validates →
View reacts.

If PRO required:
Manager emits state:
- requiresProOverlay = true

View presents global overlay.


13. RETENTION & SOFT LOCK STRATEGY

Lessons must NOT hard-block next lesson based on Mastery.

However:

If previous lessonMasteryPercent < 40%,
LessonsManager should expose:

- requiresReinforcementHint = true

UI behavior:
- Show subtle reinforcement badge on next lesson card.
- Show “Review Recommended” state.
- Do NOT block navigation.

This prevents user frustration while maintaining retention loop.


8. DESIGN CONTRACT (CRITICAL)

Lessons must:
- Use CardDS templates for lesson cards.
- Use same accent system as Course.
- Use same PRO chip token.
- No custom gradients.
- No hardcoded colors.

Spacing:
- 16 outer padding
- 12 internal stack spacing
- maxWidth 420 in centered layouts

Progress bars:
- Always inside card
- Never floating outside layout


9. ERROR ZONES TO AVOID

- View calculating unlock state.
- DS containing conditional business logic.
- Manager pushing navigation.
- Lessons modifying Step progress directly.
- GameModePicker deciding PRO access.


10. FUTURE EXTENSIONS

Lessons must support:

- Daily lesson recommendation.
- Adaptive ordering.
- Difficulty level per lesson.
- AI suggested path.
- Partial lesson replay.

Therefore:
Do not hardcode linear index assumptions.
Use explicit ordering fields.


14. DECAY AWARE BEHAVIOR

Lessons must react to mastery decay events.

If ProgressManager flags Step as Decayed:

LessonsManager must:

- mark parent lesson as ReinforcementRequired
- update lessonStabilityState
- optionally expose decayCount

Future extension:
Daily “Reinforce Lesson” surface on LessonsView.


11. SUMMARY

Lessons is:
- orchestration layer
- progression gate
- mode selector
- visual lesson navigator

It must remain:
- deterministic
- state-driven
- PRO-aware
- visually consistent with CourseDS
- logically independent from Step internal mechanics


15. TECHNICAL CONTRACT FOR CURSOR IMPLEMENTATION

LessonsManager MUST expose:

- var lessonCompletionPercent: Double
- var lessonMasteryPercent: Double
- var lessonStabilityState: LessonStabilityState
- var requiresReinforcementHint: Bool
- var reinforcementRequiredCount: Int

LessonsView MUST:

- Render stability badge.
- Render reinforcement hint.
- Never compute percentages.

All mastery math lives in ProgressManager.
Lessons only aggregates and presents.

This file now reflects:
- MasteryModel integration
- Decay support
- Retention loop alignment
- PRO gating consistency
- Clean architectural separation


16. CHANGELOG

2026-02-21 (EPIC 1 — Learning Core Stabilization)
- LessonsManager получает обновление прогресса сразу при каждом toggle шага: StepManager вызывает notifyProgress() сразу после notifyProgressStoreStep (без задержки), чтобы статус урока .completed был виден играм и курсу без задержки.
- Источник данных для прогресса урока — только StepManager (нотификация .stepProgressDidChange и updateLessonProgress). Запись learned — только через StepManager.

END OF SPECIFICATION
