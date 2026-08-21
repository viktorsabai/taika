# Taika Xcode yellow diagnostics audit

## Scope

This report classifies the diagnostics supplied in `pasted_content_2.txt`. The attachment contains **92 diagnostic entries**, not 96. The difference should be reconciled against the Xcode Issue Navigator export before treating the list as complete.

## Classification summary

| Category | Count | Release meaning |
|---|---:|---|
| Swift 6 actor-isolation / Sendable diagnostics | 31 | Highest risk. These are warnings under a Swift 5 compatibility mode but are explicitly marked as errors in Swift 6 language mode. They must not be dismissed as cosmetic. |
| Deprecated APIs and syntax | 28 | Not an immediate runtime blocker, but should be migrated before production to avoid future SDK/compiler breakage. |
| Unused, redundant or unreachable code | 29 | Mostly safe cleanup, except where the unused value indicates a removed side effect or incomplete refactor. |
| Other semantic diagnostics | 4 | Small but real cleanup items: invalid `try/catch`, redundant `await`, impossible defaults, and a non-optional `??`. |

## Highest-risk group: Swift 6 concurrency

The 31 concurrency diagnostics cluster in eight files:

| File | Count | Interpretation |
|---|---:|---|
| `Speaker/SpeakerRecorder.swift` | 13 | The recorder is main-actor isolated while satisfying nonisolated protocol requirements and is accessed from Sendable/timer closures. This is the most important cluster because it touches permission, recording, metering and audio URL lifecycle. |
| `Speaker/SpeakerManager.swift` | 7 | Main-actor state is mutated from a Sendable meter closure; the closure must hop explicitly to `MainActor` or the meter must be isolated behind a dedicated actor/state bridge. |
| `Profile/ProfileManager.swift` | 4 | Synchronous nonisolated callbacks call main-actor `refresh()`. These should dispatch through `Task { @MainActor in ... }` or the callback owner should be main-actor isolated. |
| `StepData.swift` | 2 | Nonisolated code reads main-actor static lesson metadata. Constants should be explicitly `nonisolated`/Sendable or accessed from a main-actor context. |
| `LessonsData.swift` | 2 | Same metadata isolation problem for `lessonId` and `lessonTitle`. |
| `Sync/SyncManager.swift` | 1 | NotificationCenter callback calls main-actor `schedulePush()` synchronously. The callback needs an explicit main-actor hop. |
| `PersonalPackManager.swift` | 1 | Nonisolated storage parsing reads main-actor static `courseId`; move the constant to a nonisolated value or isolate the caller. |
| `Favorites/FavoriteManager.swift` | 1 | A non-Sendable `work` closure is passed to a `@Sendable` API. This needs an explicit Sendable-safe capture or a main-actor dispatch boundary. |

### What this means

The concurrency group is the actual build-readiness concern. If the target is switched to strict Swift 6 language mode, these diagnostics become compile errors. Even if the current target still builds under Swift 5 mode, they describe undefined ownership boundaries around audio, timers, notifications and shared managers. The correct fix is **not** to blanket-annotate every file with `@MainActor`; that would hide the ownership problem and can make nonisolated audio callbacks harder to reason about.

The recommended order is: first redesign `SpeakerRecorder` protocol isolation and timer callbacks, then fix `SpeakerManager` meter callbacks, then normalize Profile/Sync notification hops, and finally mark immutable metadata constants as explicitly nonisolated.

## Deprecated APIs and syntax

There are 28 deprecated diagnostics. The largest group is `onChange(of:perform:)` across StepAnimation, StepView, CourseAnimation, CourseDS, FavoriteDS, CardDS and SpeakerDS. These should be migrated to the iOS 17 two-parameter or zero-parameter `onChange` closure. The migration is mechanical but should be done carefully where the old value is used.

The remaining deprecations are concentrated in `SpeakerRecorder.swift`: `requestRecordPermission`, `recordPermission` and `.granted`. These should migrate to `AVAudioApplication.requestRecordPermission` and `AVAudioApplication.recordPermission`. This is more than syntax cleanup because it sits in the permission flow and must be tested on a real device.

`AppDS.swift` also contains five backward trailing-closure diagnostics. Label the `onTap` argument explicitly. These are safe and low-risk.

## Unused/redundant diagnostics

There are 29 cleanup diagnostics, including unused locals such as `round`, `ru`, `ph`, `minR`, `key`, `lifehackCount`, `cid`, `w`, `h`, `completed`, `cappedTotal`, `maxSlots`, `clampedFraction`, `sep`, `isActiveStatic`, `iconInk`, `bubbleReactions`, `isToday`, `tomorrow`, `title` and `recorderWasValid`. There are also redundant `_` ignores, unreachable `default` cases and one redundant `??` on a non-optional `Int`.

Most can be removed safely, but they should not be bulk-deleted without reading the surrounding code. In particular, an unused local can indicate that a previous refactor removed a side effect or that a metric was intended to be rendered but is now silently dropped. These are appropriate for a separate cleanup commit after the concurrency pass.

## Four semantic diagnostics requiring explicit cleanup

| Location | Risk |
|---|---|
| `ProManager+RevenueCat.swift:57–59` | `try` and `catch` are unreachable because the enclosed operation no longer throws. Remove the dead error path only after confirming the RevenueCat API contract. |
| `ProfileManager.swift:403,421` | `await` is redundant. Remove it after confirming the called function is synchronous and main-actor-safe. |
| `SpeakerManager.swift:1231` and `AppDS.swift:3360` | `default` is unreachable. Remove or replace with an explicit exhaustive case only after confirming the enum cannot gain a runtime unknown case. |
| `SpeakerManager.swift:1352` | Right side of `??` is never used because the left side is non-optional. Remove the fallback; this may reveal an incorrect assumption in the surrounding data mapping. |

## Release recommendation

The list is **not 96 harmless yellow warnings**. It is approximately one-third concurrency architecture risk, one-third mechanical deprecation migration, and one-third cleanup. The current UI/navigation work should not be judged by the yellow count alone.

For an internal single-account test, the app can proceed after a clean build if the current Swift 5 compatibility mode is intentional and the Speaker flow is manually tested. For a multi-account or production build, the 31 Swift 6 diagnostics—especially the SpeakerRecorder/SpeakerManager cluster—must be resolved or explicitly bounded by an audited concurrency design.

### Recommended order of work

1. Fix `SpeakerRecorder` and `SpeakerManager` actor/Sendable boundaries.
2. Fix `SyncManager`, `ProfileManager`, `StepData`, `LessonsData`, `PersonalPackManager` and `FavoriteManager` isolation warnings.
3. Migrate audio permission APIs and all `onChange` calls.
4. Remove unused/redundant locals and unreachable branches in a cleanup-only commit.
5. Run a fresh Xcode build and export the Issue Navigator again. The expected result is zero Swift 6 actor-isolation errors and a materially smaller warning list.

## Verdict

**Current warning health: 61/100.** The quantity is manageable, but the concurrency warnings are structurally meaningful. **Internal test readiness remains conditional; production readiness should not be raised until the Swift 6 group is resolved and the fresh Xcode warning export confirms the result.**


## Implementation wave status

The warning-cleanup epic has now been applied as one behavior-preserving source wave:

| Wave | Status | Notes |
|---|---|---|
| SpeakerRecorder/SpeakerManager actor boundaries | Applied | `SpeakerRecording` is main-actor isolated; timer meter callbacks hop explicitly to `MainActor`. |
| Audio permission APIs | Applied | Migrated record permission checks/request to `AVAudioApplication`; speech permission semantics unchanged. |
| Profile/Sync notification callbacks | Applied | Callbacks use explicit `Task { @MainActor in ... }` hops. |
| Immutable metadata isolation | Applied | Personal pack identifiers/titles are `nonisolated` constants. |
| Favorite mutation boundary | Applied | Removed non-Sendable DispatchQueue crossing from the main-actor manager helper. |
| SwiftUI callback deprecations | Applied | Confirmed one-parameter `onChange` sites migrated to the two-parameter form. |
| AppDS trailing closures | Applied | Preview action closures use explicit `onTap:` labels. |
| Safe unused/redundant cleanup | Applied | Removed confirmed dead locals, redundant animation result ignores, unreachable enum defaults, and fallback key binding. |

### Validation boundary

`git diff --check` passes and `swiftc` is unavailable in the Linux sandbox. The final acceptance gate remains a clean Xcode build with the supplied Issue Navigator export refreshed after this wave. A device test is required for microphone permission, Speaker recording/meter lifecycle, speech authorization, notification-driven profile refresh, and sign-out/session isolation.

### Release interpretation

This source wave addresses the known 92-entry attachment without claiming that an Xcode warning count is zero until Xcode regenerates diagnostics. If strict Swift 6 still reports actor/Sendable warnings after the fresh build, treat those as the next compiler-specific wave rather than suppressing them with blanket annotations.

## Epic implementation commit

Pending final Xcode/device validation: all source changes from the warning-cleanup epic will be delivered in the single commit requested for device testing.

