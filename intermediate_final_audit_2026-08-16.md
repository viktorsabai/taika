# Taika — промежуточно-финальный аудит приложения

**Дата аудита:** 16 августа 2026 года.  
**Аудируемый production HEAD:** `c021ee5` — `Rewrite Course Hub welcome as a live product demo.`  
**Feature branch для сравнения:** `agent/p2-course-hub-combined` at `6d60d31`.  
**Объём:** navigation, AppShell, onboarding, Course View, lessons, games, Speaker, Favorites, paywall, state persistence, curriculum/data contracts, test coverage и handoff между remote-ветками.

> Аудит выполнен статически по Swift-коду, JSON и Git history. В sandbox отсутствуют `xcodebuild`, `swiftc` и iOS Simulator, поэтому фактическая компиляция, runtime gestures, Voice/ASR и визуальная проверка на устройстве требуют отдельного прогона в Xcode.

## Executive summary

Архитектура приложения в целом связная: есть единый `NavigationIntent.path` для push-навигации, отдельный `requestedTab` для переключения корневых вкладок, а curriculum data в текущем состоянии содержит 42 курса, 267 уроков и 267 stepsets без orphan/missing связей. P0/P1/P2 life-контент согласован: 15 курсов, 104 урока, 928 карточек, zero `card_count` mismatches.

Главные риски находятся не в отсутствии route cases, а в **двухслойной навигации**, persistent first-entry flags, отсутствии реальных navigation/UI tests и разделении curriculum между двумя JSON sources. Эти места могут давать именно те симптомы, которые уже появлялись в тестировании: старый onboarding вместо нового, потерянный context при переходе в Speaker, повторный показ/непоказ demo, stale overlay и расхождение между локальной feature branch и production.

Отдельно подтверждён важный Git/handoff факт: production уже находится на `c021ee5`, который добавляет новый rewrite Course Hub поверх `6d60d31`; remote feature branch `agent/p2-course-hub-combined` всё ещё указывает на `6d60d31`. То есть текущий production и review branch больше не идентичны и ревьюить их нужно как два разных состояния.

## Severity matrix

| Severity | Finding | Status | Рекомендация |
|---|---|---|---|
| **P0** | Нет автоматических тестов navigation/onboarding/paywall/data contracts | Подтверждено | Добавить минимальный XCTest/XCUITest smoke suite до следующего крупного merge |
| **P0** | Два независимых navigation слоя: `NavigationIntent` + `OverlayPresenter` | Подтверждено архитектурно | Зафиксировать precedence contract и закрывать/отменять overlay перед route/tab transition |
| **P1** | Один `requestedTab: Int?` — single-slot signal может быть перезаписан быстрыми последовательными запросами | Риск по коду | Заменить на typed command/event или гарантировать queue/ack semantics |
| **P1** | First-entry state размазан между `welcomeSeen`, `onboardingDone`, `TaikaProductDemoFlags` и migration flag | Подтверждено | Ввести единый onboarding state model и debug reset, проверяемый из UI tests |
| **P1** | 115 пустых `outcomes` в E/S/long extension courses | Подтверждено | Если эти 18 курсов видимы пользователю — заполнить educational contracts до release; если hidden — явно фильтровать/пометить |
| **P1** | Course catalog и lesson curriculum используют разные course-level sources | Подтверждено | Описать source-of-truth и добавить consistency validator в CI |
| **P1** | Keyboard observers в `CourseView` добавляются на каждом `onAppear`, токены не сохраняются/не удаляются | Подтверждено по коду | Хранить observer tokens и remove в `onDisappear` или использовать Combine publishers |
| **P2** | `.course` route имеет destination, но production producer не найден | Статический orphan route | Удалить или добавить явный producer; не оставлять скрытый route contract |
| **P2** | `.favoritesAll` реализован как special side effect, а не настоящий path destination | Осознанно, но хрупко | Упростить contract: либо route-only, либо tab command-only |
| **P2** | Base regression scripts проверяют старые snapshots и падают на evolved data | Подтверждено | Обновить validators, чтобы они проверяли invariants, а не старые snapshots |
| **P2** | Strict phonetic validator падает на одной осознанной записи `э↗?` | Известное исключение техлида | Не менять запись; добавить explicit allowlist/exception в validator |
| **P2** | CourseHub production demo action callbacks демонстрируют действия, но не открывают реальные games/Speaker | По текущему дизайну intentional | Ясно обозначить это как controlled demo и проверить UX copy, чтобы не обещать реальный переход |

## 1. Git и delivery baseline

На момент аудита remote содержит следующие релевантные состояния:

| Ref | HEAD | Смысл |
|---|---|---|
| `2026-01-21-k7hb-d2004` | `c021ee5` | Текущий production branch, rewrite Course Hub |
| `agent/p2-course-hub-combined` | `6d60d31` | Combined P2 + предыдущий CourseHub card-system refine |
| `agent/p2-life-rebuild` | `b2161c0` | P2 curriculum rebuild |
| `feature/course-hub-welcome` | `0c62006` | Earlier onboarding branch |

`c021ee5` изменяет `taika/Course/CourseHubWelcomeView.swift` относительно `6d60d31`; остальные combined changes остаются его ancestor history. Поэтому screenshot на устройстве нужно сопоставлять с production `c021ee5`, а не с feature branch `6d60d31`.

## 2. Navigation model

### 2.1 Global path

`NavigationIntent.Route` содержит пять route families:

| Route | Destination | Producers found |
|---|---|---:|
| `.lessons(courseId)` | `LessonsView` | Да, несколько |
| `.lesson(courseId, lessonId, presentation)` | `StepView` | Да, через summary/favorites/next lesson |
| `.course(courseId)` | `CourseView` | Destination есть, явный production producer не найден |
| `.game(courseId, lessonId?, gameType)` | `GameView` | Да, 19 static references |
| `.favoritesAll(initialFilter)` | Side effect → Favorites tab | Только special handling в `NavigationIntent.go` и AppShell |

AppShell correctly owns `NavigationStack(path: $nav.path)` and maps `.lessons`, `.lesson`, `.game` to actual views. `.favoritesAll` intentionally does not append to path: `NavigationIntent.go` changes filter and requests tab 3. This works as a command, but it makes the enum semantically mixed: some cases are routes, others are commands.

### 2.2 Tab switching

`requestedTab` is an optional integer consumed by AppShell. Known values are Main=0, Course=1, Speaker=2, Favorites=3, Profile=4. Producers request Speaker frequently from Course, Lessons, Favorites and Main; Speaker requests Course for return-to-learning; AppShell requests Course/Favorites from overlays.

The main risk is that `requestedTab` stores only one pending value. If two transitions happen before AppShell's `.onChange` consumes and clears it, the second request overwrites the first. This is especially relevant when a game/lesson dismisses, posts progress notifications, schedules an auth soft wall and requests Speaker in the same short interval.

### 2.3 Path and overlay precedence

AppShell renders `NavigationStack` content and, independently, the current `OverlayPresenter.overlay`. The overlay switch includes paywalls, tone aha, first-entry demos, filters, game park, course preview/reset and auth soft wall. There is no central transition coordinator that atomically performs:

1. dismiss current overlay;
2. save/clear return context;
3. mutate `nav.path`;
4. request tab;
5. wait for destination lifecycle.

Instead, individual handlers perform subsets of these actions. This is flexible but makes race conditions possible. A transition contract should be documented and tested for every cross-tab handoff.

## 3. First-entry and onboarding state

There are at least four relevant persistence layers:

| State | Storage | Meaning |
|---|---|---|
| `welcomeSeen` | `taika.welcome.seen.v1` | Core welcome was seen |
| `onboardingDone` | `taika.onboarding.v2.done` | Core loop/quick start completed |
| `hasSeenCourse` | `TaikaProductDemoFlags` | Course first-entry demo seen |
| `hasSeenSpeaker` | `TaikaProductDemoFlags` | Speaker first-entry demo seen |

`AppShell.migrateOnboardingFlagIfNeeded()` can infer `onboardingDone` from the old `welcomeSeen` flag. `migrateProductDemoFlagsIfNeeded()` then marks course and speaker demos as seen for existing users. This is logically defensible for backwards compatibility, but it explains why QA can install a build and not see the expected first-entry screen unless all related flags are reset.

Course first-entry is triggered from `CourseView` only when `nav.path` is empty, no overlay is present and `hasSeenCourse == false`. AppShell then presents production `CourseHubWelcomeView` through `.courseFirstTip`. The start CTA marks the flag, dismisses the overlay and schedules `nav.go(.lessons(course_b_0))` after 180 ms. Browse and dismiss mark the flag and dismiss without a route change.

The 180 ms delayed navigation after an animated dismiss is a race-sensitive seam. A double tap or an interrupted animation could schedule more than one push. The CTA should be guarded by a local `isCompleting` state or routed through one idempotent AppShell action.

Speaker first-entry still uses legacy `TaikaTabTipOverlayView(kind: .speaker)`, while Course first-entry uses `CourseHubWelcomeView`. This is not necessarily incorrect, but it means the two product-demo entry points do not share the same visual/motion system or state contract.

## 4. Course Hub production implementation

Production `c021ee5` uses the real `CourseLessonCard` component and passes the existing inline controls: play, favorite, console and Speaker. This is the correct architectural direction and is materially better than custom action blocks.

The controlled demo currently changes `beat`, toggles local favorite state, and advances scenarios. The games and Speaker controls show interaction feedback but do not navigate to the actual game/Speaker screens. That is acceptable for a first-entry product demo only if the copy clearly frames the action as a demonstration. If the user expects a real course context to open, the behavior will feel like a dead button.

The production wave is rendered as a `TaikaTechWaveform` background with a 220-point frame and vertical offset. It is visually outside the card system and therefore remains a layout risk on compact devices. It must remain behind content, hit-test disabled, and excluded from the vertical sizing of the main content stack.

## 5. Course/curriculum data contracts

The data graph itself is complete:

| Check | Result |
|---|---:|
| Courses | 42 |
| Lessons | 267 |
| Stepsets | 267 |
| Missing stepsets | 0 |
| Orphan stepsets | 0 |
| Missing course IDs in steps | 0 |
| Life courses | 15 |
| Life lessons | 104 |
| Life cards | 928 |
| Life card-count mismatches | 0 |

The architectural issue is source separation. `CourseView` loads course cards from `taika/Resourses/taika_basa_course.json`, while lesson outcomes, prerequisites and card counts are in `lessons.json`, and detailed learning items are in `steps.json`. The three sources share IDs but course-level title/category/isPro/duration metadata does not live in the same file as the lesson educational contract. A future editor can update a lesson JSON title/outcome while the UI still renders a stale title or category from the bundled catalog.

The general contract checker finds **115 empty outcomes** in E/S/long extension families: 6 E courses, 6 S courses and 7 long courses, totaling 18 courses. All B0–B7 and L1–L15 outcomes are complete. This is not a current P0/P1/P2 life failure, but it becomes a release blocker if those extension courses are visible in production.

## 6. Curriculum validator status

Current life validators pass. Existing base validators are not all green because they encode historical snapshots and because the team intentionally preserved one tech-lead phonetic record:

> B2, `course_b_2_l3`, «Что а?», phonetic `э↗?`

The phonetic audit reports 394 records and 993 tokens; 992 tokens end in arrows, with only this one known exception. The correct engineering fix is not to mutate the record but to add a documented validator allowlist for this exact record, otherwise every future regression run will look red despite intentional content.

## 7. Concrete code risks

### P1 — Keyboard observer accumulation

`CourseView.installKeyboardObservers()` registers keyboard notifications in `onAppear` but does not retain observer tokens or remove them in `onDisappear`. Re-entering Course View can register another pair of callbacks, causing duplicated state updates and animation work. This is a concrete lifecycle bug candidate.

### P1 — Delayed first-course push

`CourseHubWelcomeView` start is dismissed and then schedules `nav.go(.lessons(course_b_0))` after 180 ms. The action should be idempotent and protected against repeated taps or a second callback firing during transition.

### P1 — Single-slot tab command

`NavigationIntent.requestedTab` is an optional integer, not a queue. Multiple near-simultaneous requests can overwrite one another. This is especially risky in Speaker/game/lesson return flows.

### P2 — Mixed route/command enum

`favoritesAll` is named like a route but is consumed as a tab/filter command. This is understandable legacy design, but it increases mental overhead and makes route coverage tests less precise.

### P2 — Dead `.course` destination

A destination for `.course(courseId)` exists in AppShell, but static producer search did not find an explicit `nav.go(.course(...))`. It should either be removed or given a clear producer and test.

### P2 — Legacy and demo seams

The codebase contains multiple legacy wrappers and fallback IDs (`course_demo`, `course_test`, `course_b_1_l1`), plus older demo/pager components. Most are previews/fallbacks, but they increase the risk that an Xcode target accidentally presents a legacy flow.

## 8. Automated test coverage

Current tests are scaffolds only. `taikaTests` contains an empty example test. `taikaUITests` launches the app and has a performance test; launch tests capture a screenshot. There are no assertions for:

- onboarding completion and persistence;
- Course Hub first-entry presentation and one-time dismissal;
- CTA navigation to `course_b_0`;
- course → lesson → game → next game;
- lesson → Speaker context queue;
- Speaker → return-to-learning path restoration;
- Favorites → lesson/course/game/Speaker handoffs;
- PRO gate → tone aha → paywall → close behavior;
- JSON card count/outcome/prerequisite invariants.

This is the highest-confidence process gap in the audit. A small smoke suite would catch most regressions that previously appeared only on a device.

## Recommended next order

First, add a navigation smoke harness around `NavigationIntent` and a small AppShell UI test with resettable onboarding flags. Second, fix keyboard observer lifecycle and make first-entry CTA transition idempotent. Third, formalize the overlay/path transition contract and the requested-tab command semantics. Fourth, decide whether E/S/long courses are production-visible; if yes, complete their outcomes/prerequisites before exposing them. Fifth, merge the validator updates for the intentional phonetic exception and replace historical snapshot assertions with invariant checks.

No production files were modified during this audit. Only audit scripts and report files were created locally.
