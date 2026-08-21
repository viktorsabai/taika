# Speaker unified-flow audit findings

## Current composition

- `SpeakerView.swift` owns routing and passes `SpeakerManager` state into `SpeakerDSRoot`.
- The main training card is `SpeakerTopCard` in `SpeakerDS.swift`.
- `SpeakerTopCard` uses a fixed card frame (`CardDS.Metrics.speakerPhraseCardWidth/Height`) and currently renders the stable phrase content: translit, Russian title, Thai secondary line, and lesson chip.
- The visible sphere/state aura helpers are `hiTechRecordingFrame`, `hiTechAnalyzingFrame`, and `hiTechResultFrame`; they are defined in `SpeakerTopCard` but current source search did not find an active usage in the body, so the actual visible jump may come from another live conversation orb component.
- `ConversationVoiceOrb`, `ConversationAmbientRings`, `ConversationLiveAmbientGlow`, and `SpeakerLiveStateHalo` are additional state-reactive visuals later in `SpeakerDS.swift` and must be checked before modifying geometry.

## Result screen

- The primary result/breakdown renderer is `SpeakerDSRoot.makeBreakdownView` around lines 4270–4560 in `SpeakerDS.swift`.
- The sheet branch currently contains: focus title/body copy, phrase label, phonetic line, graph section, syllable rows, conclusion copy, loading/error copy, and PRO tease. The non-sheet branch contains a dense legacy card with dual score row, “нужно было/ты сказал”, graph, syllable rows, and conclusion.
- Result visuals currently include several nested surfaces and separate graph/rows sections. The intended redesign is one static reinforcement-style composition: Russian phrase, Thai/phonetic reference, user attempt, one large score using the app’s number styling, and compact chips only.
- Existing `breakdownPhraseGraphSection`, `breakdownSyllableRowsHumanSection`, `breakdownSyllableRowsSection`, and `breakdownSummaryNote*` are reusable data/visual primitives but should be composed without extra explanatory paragraphs or nested card shells.

## State requirements

- `SpeakerManager.Phase` states include idle, recording, analyzing, analyzingTranslation, hint, and feedback.
- Sphere/ambient effects should remain in a fixed geometry container and vary only opacity/intensity/animation by state; no state-specific frame/offset/scale should change layout.
- Recording should show active waveform/recording effect; analyzing should show a restrained processing effect; feedback should show a calm result accent; idle should keep the same sphere footprint and no animated glow.

## Constraints

- Preserve existing manager callbacks, course/lesson scope, card-level errors, PRO gating, and result actions.
- Remove duplicated explanatory copy and nested frames rather than introducing another result card.
- Keep typography and metrics aligned with the course reinforcement/grade-sheet system.
