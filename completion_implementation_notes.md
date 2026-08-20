# Completion implementation notes

## Branch

Working branch: `agent/post-lesson-completion-state`, created from remote production `2026-01-21-k7hb-d2004` after fetch. Working tree contains many pre-existing untracked audit/curriculum files; implementation commit must stage only intended Swift files.

## Current component

`taika/Theme/AppDS.swift` contains public `LessonSummaryOverlay` with existing public initializer contract:
- title, subtitle, primaryTitle, secondaryTitle
- onPrimary, onSecondary, onClose
- ctaStyle, kind (`LessonSummaryKind`: lesson/course/catalogEnd), eyebrow, hacksAccessory
- optional `onSpeakerPractice`, speakerPracticeTitle, speakerPracticeSystemImage
- optional selectedGameMode and onSelectGameMode
- showGameReinforce, lessonDurationText, overallProgressText

Current body uses an old visual stack with title/subtitle, FM accent, optional hacks, and footerBlock. For `kind == .course || .catalogEnd`, `courseCompleteCTA()` currently shows primary button, Speaker button, and a course completion text. For lesson states, `buttonsBrandChips()` shows primary CTA, game selector if selectedGameMode/onSelectGameMode are present, and a duplicate game action button. Game labels currently are English/Russian mixed: match => «матч», recall => «слоги», audioRecall => «аудио».

Current helper `metaProgressLine()` only renders lessonDurationText and overallProgressText. `progressAndSubtitleBlock()` exists inside body and parses subtitle progress with `parseProgress`. Need preserve callers and derive compact result ribbon from current strings where possible.

## Existing navigation contracts

`AppShell` `.game` route maps to private `GameView`; `openSpeakerPractice()` in AppShell GameView marks active lesson, rebuilds Speaker queue, sets `SpeakerRequestedCourseId`, dismisses, requests Speaker tab. `continueLearning()` calls `CourseNavigator.shared.advance(from:courseId, lessonId:lid)` and handles `.nextLesson`, `.nextCourse`, `.end`; `.end` only dismisses.

Game modes in `GameModeType`: `.match`, `.recall`, `.audioRecall`, plus other modes normalized in AppShell. `AppShell.isProGateActive` filters `GameModeType.modesLessonAndPark` by `requiresProSubscription && !pro.isPro`. For free users locked game opens a placeholder/paywall path. Existing `GameModeType` UI labels need local Russian transliteration proposal: «Чап-кху» / «найди пару», «Там-кхам» / «собери слово», «Фанг-лыак» / «послушай и выбери»; verify with product before final copy.

## Required implementation states

1. Intermediate lesson: primary «Продолжить курс», next lesson caption, Speaker recommendation, one active free game and locked PRO games.
2. Intermediate lesson PRO: same, all games active.
3. Last lesson course free: title «Курс завершён», primary «Посмотреть курсы», Speaker, one active game and locked PRO games.
4. Last lesson course PRO: title «Курс завершён», primary «Выбрать следующий курс», actual next course caption if available, Speaker, all games active.
5. Last course/track/no next destination: primary catalog/other courses, never fake next lesson.
6. Locked game: show inline locked state/paywall; close must return to same completion context.
7. Repeat lesson: no celebratory first-entry animation assumptions; route should return to course/lesson context.
8. Double-tap CTA must be idempotent; no duplicate nav pushes.

## Constraints

Use existing Taika tokens and current SwiftUI architecture. Do not create a parallel completion flow. Keep public initializer/call sites compatible unless adding optional parameters with defaults. Xcode/xcodebuild unavailable in sandbox; static checks only. Do not stage audit scripts or unrelated untracked files.
