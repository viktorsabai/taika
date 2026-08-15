# Taika first-entry storyboard contract

## Decision

The first entry uses the existing `TaikaEntryOnboardingView` and `TaikaProductDemoPager` as the product-storyboard surface. `AppShell` keeps the existing Splash → first-entry → `finishFirstEntry` contract, but no longer presents the old `TaikaLearnOnboardingView` mini-lesson as the first screen.

## Why

`TaikaProductDemoPager` already owns a stable mobile composition: Taika branding, step progress, title, stage, subtitle, CTA, skip path, swipe gesture, spring page transitions, haptics and reduced-motion-safe presentation. Its scenes are rendered by `TaikaProductDemoStageView`, which is the existing product-demo language rather than a new onboarding card system.

## Product narrative

The entry storyboard is four short scenes:

1. **One phrase is the first step.** The learner chooses a live phrase, hears it and says it.
2. **Taika hears more than words.** The learner sees that pronunciation and tone become actionable feedback.
3. **One phrase can be reinforced in several ways.** Match, syllable practice, Audio Recall and Speaker are shown as a learning loop.
4. **Taika is a personal kun kru.** Courses, lessons, words and phrases become the continuation into regular self-learning.

## Technical contract preserved

The existing `finishFirstEntry(with: .baseCourse, landingCourseId: "course_b_1")` path remains unchanged. Skip and completion both land in the existing starter course. No new mock course IDs or independent AppShell state machine are introduced.
