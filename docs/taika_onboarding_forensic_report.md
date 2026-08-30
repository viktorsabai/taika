# Taika onboarding forensic report

## Root cause of previous PR failures

The previous PRs introduced parallel onboarding views (`TaikaNativeOnboardingView`, `TaikaFunnelOnboardingView`) and switched `AppShell` to them. Those views recreated phrase cards, course cards, score states and feature claims instead of using the working first-entry implementation as the source of truth. This caused layout drift, compile risk, duplicated CTA ownership and visual behavior that did not match MainView.

The repository already has a better baseline in `TaikaLearnOnboardingView.swift`. It owns a coherent `Step` state machine (`door`, `phrase`, `breakdown`, `catalog`, `reinforce`, `plus`), existing `LearnCoverflow`, `LearnPhraseCard`, `LearnBreakdownDemo`, `LearnInfiniteCourseReel`, `ReinforceCard`, `CourseData`, Speech authorization/recording and the existing `onFinished` contract. The correct direction is to improve and orchestrate this baseline, not replace it with another independent screen tree.

## Working product surfaces

`MainView` and `MainDS` provide the canonical prompt/typewriter, phrase card and course carousel language. `CourseView` and `LessonsData` provide the real course/lesson path. `SpeakerManager`, `SpeakerDSRoot` and `ResultDS` provide the real phases `idle`, `recording`, `analyzing`, `hint` and `feedback`, including word/tone/syllable feedback. `HomeTaskData`, `HomeTaskView` and `RecallGameDS` provide Match, recall/syllable assembly, Audio Recall and related practice modes. `FavoriteManager` provides the personal shelf and smart speaker dictionary. `TaikaValueDeck` provides contextual value/paywall reasons for games, speaker breakdown, daily picks, courses and dictionary.

## Rebuild rule

Keep `TaikaLearnOnboardingView` and its AppShell contract. Replace only the presentation choreography and stage content where needed. Reuse the real cards and data models. Do not create a second AppShell entry, do not invent course IDs/metrics unless a state is explicitly marked as a demo, and do not put multiple primary actions in one stage.

## Product story

The first entry should demonstrate the loop `choose → hear → speak → understand → reinforce → continue`. The breadth preview should be an interactive continuation rail after the proof moment: Match, syllable assembly, Audio Recall, Speaker tone feedback, real course/lesson cards and the personal shelf. The positioning is: **Taika не переводит за тебя. Она помогает научиться говорить самому.**
