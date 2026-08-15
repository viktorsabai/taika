# Taika first-entry product audit

## Executive diagnosis

Taika is broader than a pronunciation checker. The repository contains a connected learning system: short courses and lessons, words and phrases, a Speaker surface with local speech recognition and pronunciation/tone feedback, multiple reinforcement modes, favorites/personal dictionary, daily selections, course progression, and Taika+ expansion points. The current first-entry concept over-indexes on one Speaker demo and under-explains the loop that makes the product worth returning to.

The onboarding should therefore demonstrate one complete loop and preview the breadth of the ecosystem. It should not attempt to show every feature as a separate page. The product story is: **learn one useful unit → hear it → say it → understand the tone/word feedback → reinforce it in a mode that fits you → continue through a course or personal shelf**.

## Capability map

| Product surface | Evidence in repository | User job | First-entry proof moment |
|---|---|---|---|
| MainView daily practice | `MainView.swift`, `MainDS.swift`, daily picks, warmup cards and course carousel | “Give me one useful thing to do now” | A real phrase card appears with a clear next action |
| Courses and lessons | `CourseData.swift`, `CourseView.swift`, `LessonsData`, course progress models | “Give me a path, not random content” | A course card expands into a lesson/step promise |
| Words and phrases | `StepData.swift`, `MainData.swift`, phrase/word cards, Favorites | “Let me collect and reuse what matters” | A phrase can be saved to a personal shelf |
| Speaker | `SpeakerDS.swift`, `SpeakerManager.swift`, `ResultDS.swift`, `SpeakerAPI.swift` | “Show me what my voice is doing” | The same phrase receives text and tone feedback |
| Tone analysis | `SpeakerIssue` tone cases, tone score/feedback surfaces and syllable feedback | “Explain the specific pronunciation issue” | One syllable/tone is highlighted with a next attempt |
| Reinforcement games | `HomeTaskData.swift`, `HomeTaskView.swift`, `RecallGameDS.swift`, `AppDS.swift` | “Help me remember in different ways” | A small interactive preview shows match, syllable assembly and audio recall |
| Personal shelf | `FavoriteManager.swift`, `FavoriteView.swift`, smart speaker dictionary | “Keep what I want to practice” | Saving a phrase turns it into a reusable practice item |
| Taika+ | `TaikaValueDeck.swift`, `ProGateReason` and paywall/value surfaces | “Understand what expands if I go deeper” | Show limits and expansion contextually after product value is proven |

## Product funnel

The first entry should use a short, controlled funnel rather than a linear slide deck. The learner chooses one context or phrase, then sees the product work. The breadth preview comes after the proof, as a horizontal “what happens next” rail with real mini-cards, not a list of claims.

| Sequence | Screen behavior | Primary CTA | Why it exists |
|---|---|---|---|
| 1. Attract | MainView-like typewriter and one quiet hero action | “Попробовать” | Establishes voice-first identity without explaining the whole app |
| 2. Choose a real use case | Depth carousel of phrase cards: travel, food, everyday speech | “Выбрать фразу” | Gives the user agency and immediately exposes real content |
| 3. Hear it | Selected phrase card stays in place; audio state animates locally | “Послушать” | Demonstrates natural Thai audio and the card interaction language |
| 4. Say it | Same card morphs into mic/listening state with signal bars | “Сказать самому” | Turns the promise into an action |
| 5. Understand | Same card reveals recognized text, word confidence and tone rail sequentially | “Улучшить одну деталь” | Makes the core value concrete rather than showing a generic score |
| 6. Reinforce | Compact carousel of three real modes: match, syllable assembly, audio recall | “Попробовать режим” | Shows that Taika teaches retention, not only pronunciation |
| 7. Continue | Course mini-card carousel plus personal shelf cue | “Выбрать путь” | Connects the proof moment to courses, lessons and saved material |
| 8. Optional expansion | Contextual Taika+ expansion after the free loop is understood | “Продолжить бесплатно” / “Открыть больше” | Keeps sales native and non-blocking |

## Motion principles

Motion should communicate causality. A card should not disappear and be replaced by an unrelated page; the selected phrase should retain its identity as it moves from listening to recording to analysis. The user’s tap creates the next state. Audio pulses around the speaker affordance, recording animates only the local signal, analysis uses a scanning sweep, and feedback reveals in a short sequence. The course carousel then inherits the same center/peek/depth behavior.

The carousel must be a real interaction primitive, not a clipped horizontal stack. It needs a dedicated viewport, center-distance calculation, `scrollTargetBehavior(.viewAligned)`, selected identity, scale/opacity/rotation/parallax based on distance, and an accessible reduced-motion fallback. The screen layout must remain stable while the carousel moves.

## Product risks to avoid

The onboarding should not open with a feature inventory, a large paywall, a full score ring, or a generic marketing card. It should not use content that cannot be reached in the app after onboarding. It should not show a “course” card that is visually unrelated to the real MainView course cards. Finally, it should not promise “AI” as an abstract capability; it should show what the user sees and does after speaking.

## Recommended next implementation

Use a new native onboarding orchestrator with independent stateful feature modules: `AttractStep`, `PhraseChoiceStep`, `SpeakerDemoStep`, `ReinforcementStep`, and `PathChoiceStep`. Reuse existing MainView/DS cards wherever possible, but do not force the entire product into one giant view. Each module owns its local motion while the orchestrator owns the funnel, completion, persistence and AppShell handoff.
