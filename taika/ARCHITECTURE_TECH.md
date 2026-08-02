

# taika ios — technical architecture

## 1. architectural principles

| principle | description |
|-----------|------------|
| ds is visual-only | design system renders ui. no business logic. |
| view assembles | view composes ds components and binds state. |
| manager owns logic | all state transitions, validation, scoring, progression live in managers. |
| data is pure | data structs contain no logic. |
| single source of truth | user progress and pro state come from session layer. |
| centralized shell | navigation, header, background, overlays controlled by appshell. |

---

## 2. global layer map

```
taikaapp
 └── appshell
      ├── theme (tokens, design system)
      ├── navigationintent
      ├── overlaypresenter
      └── root tab routing
           ├── main
           ├── course
           │    └── lessons
           │         └── step
           │              └── hometask
           ├── speaker
           ├── profile
           └── pro
```

---

## 3. layer responsibilities

### 3.1 theme layer

**files**
- thememanager
- themedesign
- appds
- cardds
- overlaypresenter
- navigationintent
- appshell

**responsibilities**
- global background
- header injection
- toolbar injection
- accent management
- overlay system
- visual token enforcement

appshell is the root visual container. no screen should manually define global background or header.

---

### 3.2 session layer

**files**
- usersession
- progressmanager

**responsibilities**
- active user state
- completed steps
- lesson progress
- game scores
- unlocked content
- daily streak
- persistence

this layer must never depend on ui.

**progress source of truth (EPIC 4)**  
- Learned step indices: ProgressManager only. Written via StepManager → ProgressManager.setStepLearned.  
- Course/lesson percent: ProgressManager.progress(for:) uses learnedSteps + lessonMetaProvider (LessonsData/StepData). LessonsManager aggregates are rebuilt from PM on load so dashboard and course/lessons screens stay in sync.  
- All progress APIs return values in [0, 1]. See SESSION_README §4.

---

### 3.3 course pipeline

```
course
 └── lessons
      └── step
           └── hometask
```

#### course component
- coursemanager handles filtering, availability, unlock logic.
- courseds renders grid/list layout only.
- coursenavigator emits navigationintent.

#### lessons component
- lessonsmanager resolves lessons for selected course.
- game mode selection resolved here.
- lessonsds renders layout only.

#### step component
- stepmanager controls:
  - current card
  - audio playback
  - animation state
  - progression to next card
- stepds renders learning card ui.
- stepaudio and stepanimation isolated utilities.

#### hometask component
- hometaskmanager:
  - game mode routing
  - validation logic
  - score calculation
  - syllable parsing
  - round generation
- hometaskds:
  - layout shell
  - bubble system
  - progress indicator
- recallgameds:
  - slot rendering
  - syllable grid rendering
  - check button
  - state visualization only

---

## 4. speaker component

**files**
- speakermanager
- speakerview
- speakerapi
- speakerrecorder
- speakerds
- resultds

**architecture**

```
recording → analyzing → scoring → feedback → result overlay
```

- speakermanager is state machine.
- speakerapi handles recognition and scoring.
- speakerrecorder handles audio capture.
- resultds renders score visualization.
- no scoring logic inside ds.

pro gating lives in promanager, not in speakerview.

---

## 5. pro architecture

**files**
- promanager
- proview

**rules**
- promanager owns entitlement state.
- gating must occur at manager or navigation layer.
- ui only reflects entitlement state.

no business logic inside proview.

---

## 6. main component

main is dashboard orchestrator.

**files**
- mainmanager
- mainds
- mainview
- toolbar

responsibilities:
- daily progress snapshot
- shortcut navigation
- entry to course and speaker
- does not own learning logic

---

## 7. navigation system

navigationintent enum defines screen transitions.

appshell:
- injects global header
- injects toolbar
- manages overlay presenter
- applies global background token

no view should push navigation directly using ad-hoc navigation.

---

## 8. overlay system

overlaypresenter:
- single global modal system
- used for:
  - result screens
  - pro paywall
  - game completion
  - error alerts

no view should use random .sheet or .alert without routing through overlaypresenter.

---

## 9. data flow diagram

```
json → data struct → manager logic → published state → view → ds
```

no reverse dependency allowed.

---

## 10. state ownership matrix

| layer | owns state | mutates state | renders ui |
|-------|-----------|--------------|-----------|
| ds | no | no | yes |
| view | no | no | composes |
| manager | yes | yes | no |
| session | yes | yes | no |
| appshell | navigation state | yes | yes |

---

## 11. non-negotiable rules

1. no background defined outside appshell.
2. no header duplication.
3. no business logic inside ds.
4. no scoring inside view.
5. no navigation hardcoding inside feature views.
6. no pro checks inside ds.

---

## 12. future scalability

this architecture allows:
- adding new game modes without touching step.
- replacing recognition engine in speakerapi without touching ui.
- adding themes via thememanager only.
- injecting analytics at manager layer only.
- enabling feature flags centrally.

---

## 13. technical risk control

| risk | mitigation |
|------|-----------|
| duplicated header | appshell single injection |
| black background regression | theme token enforcement |
| infinite re-render | avoid publishing inside view updates |
| ds logic creep | architecture contract |

---

## 14. architectural goal

taika is not a set of screens.

it is:

```
design system
+ session engine
+ structured learning pipeline
+ modular game engine
+ pronunciation engine
```

all connected through a controlled shell.

this document defines the technical contract.

---

## 15. changelog

**2026-03-31 (March Epic — UX/Architecture Consolidation)**  
- Header/navigation contract tightened: `AppHeaderStyle.lessons` now supports optional actions; theory-only flows do not render speaker/game affordances.  
- Carousel return-state persistence added for course and lessons reels (`CarouselScrollPersistence`), restoring previous visible position on back navigation.  
- Card system unified across Course/Lesson/Favorites; lesson cards now support dedicated back-face reminders (`lessonReminders`) distinct from course grade-sheet semantics.  
- Bonus theory course contract formalized (`course_b_0`): no contradictory practice affordances (speaker/console/game/progress expectations) in Course/Lessons UI.  
- Profile metrics contract aligned to canonical pipeline: Profile layer reads `ProgressManager.publishedState` to avoid formula drift.  

**2026-02-21 (EPIC 4 — Progress Consistency Layer)**  
- ProgressManager.lessonMetaProvider wired at init from LessonsData/StepData; course progress is computed from learnedSteps (single formula).  
- LessonsManager.rebuildAggregatesFromProgressManager() runs on load so persisted LM state matches ProgressManager after relaunch.  
- Progress APIs explicitly clamp to [0, 1]; doc in ARCHITECTURE_TECH §3.2 and SESSION_README §4.

**2026-02-21 (EPIC 1 — Learning Core Stabilization)**  
- Single writer for progress: only StepManager writes learned state to ProgressManager/UserSession; StepView and MainView call StepManager.setLearned only.  
- ProgressManager.save() on setStepLearned is now immediate (scheduleSave(immediate: true)) so progress persists before app background/exit.  
- UserSession.save() on setStepLearned is now direct save (no debounce) for same reason.  
- LessonsManager receives progress update immediately in StepManager.notifyProgressStoreStep (notifyProgress() called right after persist) so games see completed lessons without delay.  
- Course/Lessons/Step docs and LEARNING_PIPELINE/SESSION updated; see component changelogs.

**2026-02-21 (EPIC 5 — Main carousel & search overlay)**  
- Main «Продолжить» uses CDLessonCarousel (CourseDS); first card anchor .leading; section slot height includes depth overflow so cards are not clipped.  
- Search overlay is rendered at AppShell level (SearchOverlayView, SearchOverlayState.shared); tapping search in Course tab shows overlay on top of current tab.  
- «План на неделю» replaced by «Подборка для тебя» (Kun Kru overlay).
