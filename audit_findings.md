# Taika intermediate-final audit findings

## Scope and baseline

Аудитируется branch `agent/p2-course-hub-combined` at `6d60d31`, remote default `origin/2026-01-21-k7hb-d2004` at `b2161c0`. В combined branch входят P2 curriculum и onboarding commits `dc277fe`, `f0c3554`, `6d60d31`. В репозитории 81 Swift files under `taika/`. Xcode/xcodebuild/swiftc отсутствуют в sandbox, поэтому compile/runtime conclusions remain static until Xcode run.

## Curriculum/data checks

`lessons.json` contains 42 courses, 267 lessons; `steps.json` contains 267 stepsets. There are no missing stepsets, orphan stepsets, missing course IDs in steps, or orphan step courses. Life validators pass: 15 life courses, 104 lessons, 928 cards, 0 card-count mismatches, outcomes/prerequisites complete for life lessons/courses.

The general contract checker reports 115 empty `outcomes`, all in non-life extension families: E courses (30 lessons), S courses (36 lessons), and long courses (43 lessons). Base B0–B7 and Life L1–L15 outcomes are complete. This is a content-contract gap for 18 non-life extension courses if those courses are user-visible; it may be intentional if they are not yet shipped, but visibility must be confirmed.

The runtime catalog `taika/Resourses/taika_basa_course.json` and audited `lessons.json` both contain 42 course IDs. However, course-level metadata is split: runtime catalog owns title/category/is_pro/lesson_count/duration, while lessons.json owns lesson-level metadata/outcomes/prerequisites/card_count. This is a duplicated source-of-truth boundary rather than an immediate ID mismatch.

The bundled runtime catalog is loaded by `CourseView` via `_JSONLoader.courses(from: "taika_basa_course")`; lessons and steps are loaded separately through `LessonsData`/`StepData`. The new CourseHub card IDs `course_b_1`, `course_l_2`, `course_l_3`, `course_l_5` exist in the runtime catalog.

Known strict phonetic exception remains exactly one record: B2 `course_b_2_l3`, phrase «Что а?», phonetic `э↗?`. Validators report 394 records, 993 tokens, 992 tokens with arrows. This is the known tech-lead-owned intentional record and was not changed.

Existing base regression scripts are snapshot/scope validators and fail against the current evolved branch because they assert old non-target snapshots; `validate_base_phonetics.py` fails only on the known `э↗?` record. Life validators are current and pass.

## Navigation/state architecture

`NavigationIntent` is the global path stack with routes `lessons(courseId)`, `lesson(courseId, lessonId, presentation)`, `course(courseId)`, `game(courseId, lessonId?, gameType)`, and `favoritesAll(initialFilter)`. `favoritesAll` is a side effect that switches tab/filter and does not enter the path. Tab switching is a separate `requestedTab` signal with indices Main=0, Course=1, Speaker=2, Favorites=3, Profile=4.

`OverlayPresenter` is a second independent navigation layer with search, paywalls, speaker tone aha, game park, filters, first-visit tips, course preview/reset, auth soft wall and other overlays. AppShell renders both path destinations and overlay switch, so overlay precedence and dismissal must be checked for every path.

Course first-entry is triggered from `CourseView.maybePresentCourseProductDemo()` when `TaikaProductDemoFlags.hasSeenCourse == false`, `nav.path` is empty and no overlay exists. AppShell maps `.courseFirstTip` to `CourseHubWelcomeView`. CTA onStart marks course seen, dismisses overlay, then asynchronously pushes `lessons(course_b_0)`; browse/dismiss mark course seen and only dismiss.

Speaker first-entry is triggered from `SpeakerView.maybePresentSpeakerProductDemo()` under equivalent no-overlay/no-pending-context guards. AppShell maps `.speakerFirstTip` to legacy `TaikaTabTipOverlayView(kind: .speaker)`. Speaker context is passed through `SpeakerRequestedCourseId` plus AppShell bindings and consumed on Speaker appear/change.

AppShell has two onboarding persistence flags (`taika.welcome.seen.v1`, `taika.onboarding.v2.done`) plus per-tab `TaikaProductDemoFlags`. `migrateProductDemoFlagsIfNeeded()` marks both course and speaker product demos seen for users with onboardingDone on first migration. This intentionally prevents old users from seeing first-visit tab demos, but can also make demo behavior appear inconsistent during QA unless all flags are reset.

AppShell's `requestedTab` handler saves SpeakerReturnContext when switching to Speaker, consumes SpeakerRequestedCourseId, pops global path, changes tab, and clears the request. Speaker tab back behavior depends on SpeakerReturnContext; fallback is Course tab after clearing path.

## Preliminary risk areas to validate further

The primary architectural risk is two navigation owners: global NavigationIntent path plus OverlayPresenter. Need verify no overlay remains stale after route changes and no requestedTab is lost when several state changes happen in one animation.

The primary data risk is the 115 empty outcomes in E/S/long extension courses, plus split course-level metadata between runtime catalog and lessons.json. Need confirm whether these courses are visible in CourseView and therefore require P2-style educational contracts.

The primary testing risk is coverage: `taikaTests` contains only an empty example test; UI tests only launch the app and take a screenshot. No automated test asserts AppShell navigation, CourseHub first-entry, Speaker context handoff, game continuation, paywall close behavior, or JSON/card contracts.
