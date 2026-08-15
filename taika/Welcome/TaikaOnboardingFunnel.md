# Taika onboarding funnel

## Product promise

Taika does not explain itself with a sequence of marketing screens. It lets the user feel the core loop in under a minute: choose a useful phrase, hear it, say it, see how the voice was understood, and choose where to continue.

## State model

`attract` shows the MainView-like typewriter and one microphone action. `choose` introduces a depth carousel of useful phrase cards. `listen` plays the selected phrase while the card remains spatially stable. `speak` turns the same card into a recording state with local signal motion. `analyze` keeps the card in place and replaces only its lower content with a compact analyzing signal. `understand` reveals text and tone feedback in sequence on the same card. `choosePath` presents real Taika course cards in the same carousel primitive. `enterApp` hands off to the existing AppShell course flow.

## Funnel rule

Every state must have one primary gesture. A state may contain secondary affordances, but no second competing CTA. The next state must be a consequence of the user's action, not an arbitrary page swipe.

| State | User action | Product proof | Next motion |
|---|---|---|---|
| Attract | Tap the microphone / primary CTA | Taika is voice-first | Hero contracts into phrase carousel |
| Choose | Swipe or tap a phrase card | Useful content is immediately available | Selected card snaps and neighboring cards settle |
| Listen | Tap speaker | Taika speaks Thai naturally | Card audio affordance pulses locally |
| Speak | Tap microphone and repeat | Taika listens to the user | Card becomes a live signal surface |
| Analyze | Wait briefly | Taika is processing voice, not showing a generic spinner | Signal resolves into the same card |
| Understand | Observe reveal | Text and tone are evaluated separately | Tone rail draws left-to-right, then CTA appears |
| Choose path | Swipe course cards | The result connects to a real learning path | Selected course lifts into the handoff |
| Enter app | Tap one CTA | The user has a clear next session | Native AppShell transition |

## Depth carousel contract

The carousel uses an iOS 17 `ScrollView` with centered target alignment and a bound selected ID. Each card receives its distance from the viewport center through `GeometryReader`. Distance controls `scaleEffect`, `opacity`, `rotation3DEffect` and a maximum horizontal/vertical parallax. The selected card is always fully visible; neighboring cards peek by a fixed amount and never determine the layout height. The carousel viewport has an explicit fixed height and clips only its own content.

## Motion contract

Motion is local and interruptible. Card settling uses a spring. Phrase-to-speak is a content morph inside the same card identity. Recording signal uses repeating bars and rings but never moves the page. Analysis uses a short shimmer/sweep instead of `ProgressView`. Result reveal is staggered: recognized text, word confidence, then tone rail. Haptics mark selection, recording start, successful analysis and course handoff. `accessibilityReduceMotion` disables scale/rotation/repeat loops but keeps state changes and opacity transitions.

## Visual contract

Use `MDCyclingTypewriter`, `MDWarmupPhraseCard`, `FDMiniCourseCard`, `MDMainFilledPillCTA`, `TaikaWordmarkLockup`, `PD/CD.ColorToken`, `ThemeManager` and the existing MainView spacing. Do not introduce large independent glass panels, full-screen score rings, long explanatory paragraphs, or a separate marketing visual language.
