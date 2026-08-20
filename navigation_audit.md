# Taika Cross-App Navigation and State Audit

## Scope

Сквозной аудит проверяет root tabs, NavigationIntent routes, overlays, session/state managers, course/lesson/card/game/speaker scope propagation, canonical messages, paywalls и cross-screen action semantics.

## Initial architecture map

| Layer | Current owner | Observed contract |
|---|---|---|
| Root navigation signal | `NavigationIntent` | Owns `path: [Route]` and `requestedTab`; root shell is expected to observe and apply both. |
| Route model | `NavigationIntent.Route` | `lessons(courseId)`, `lesson(courseId, lessonId, presentation)`, `course(courseId)`, `game(courseId, lessonId, gameType)`, `favoritesAll(initialFilter)`, `dictionary`. |
| Lesson presentation | `LessonRoutePresentation` | `canonical`, `directStart`, `favoritesAll(startIndex:hacksOnly:)`, `personalPack(startIndex:)`. Direct start intentionally resets start index and avoids restoring completion overlay. |
| Favorites deep-link | `NavigationIntent.go(.favoritesAll(...))` | Does not push a route; writes `FavoritesFilterState.shared.selectedTab`, requests root tab 3, and returns. |
| Course catalog deep-link | `NavigationIntent.openCourseCatalog(tab:)` | Writes `CourseCatalogTabState`, pops route path, requests root tab 1. |
| Overlay routing | `OverlayPresenter` | Owns one active `Overlay` plus search state; `present(_:)` also intercepts selected paywalls for the Speaker tone aha state. |
| Root tab indices | `NavigationIntent` comments | 0 Main, 1 Course, 2 Speaker, 3 Favorites, 4 Profile. |

## Initial audit risks to verify

1. Route entry and return semantics must be checked against every caller. In particular, routes from cards, completed LessonsView, Speaker and Game Park must preserve course/lesson/card scope rather than rebuilding a generic queue.
2. `favoritesAll` is a special root-tab request rather than a stack route. Its behavior must be compared with the newer `FavoriteScreenTab` model, including legacy FDK values.
3. `LessonRoutePresentation.directStart` is explicitly canonical for opening a lesson from a list. Any caller using `.canonical` or a completion presentation may reopen the wrong StepView state.
4. The app uses both root-tab state and a navigation path. Audit must verify that each transition clears or preserves the path intentionally, especially when returning from Speaker/Game Park.
5. OverlayPresenter is a single-overlay state machine with cross-cutting paywall interception. Its cases and all presentation call sites need a matrix to detect duplicate paywalls, wrong source context, or stale scope.
6. Managers and persistence must be audited against the route scope: `ReinforcementStore`, `FavoriteManager`, `SpeakerManager`, `SpeakerRequestedCourseId`, `DictionarySessionSelection`, `UserSession`, `CourseCatalogTabState`, and `FavoritesFilterState`.

## Current status

- Phase 1–4: architecture, route, manager, overlay, paywall and copy audit completed.
- Phase 5: prioritized fixes applied for the high-impact scope/navigation findings.
- Phase 6: static verification completed; Simulator/Xcode E2E remains the required external validation because this sandbox has no Xcode toolchain.

## Concrete finding F-001 — Favorites bookmark action has a context collision

`AppDS` now renders a contextual bookmark icon for Favorites when `FavoritesFilterState.shared.selectedTab == .cards`. However, `AppShell.ShellHeaderHost` currently passes the global `onTapDictionary` callback for every tab, and that callback presents `.dictionaryQuickDrawer`. Therefore the new Favorites bookmark can still open the quick drawer instead of switching the Favorites page to its Dictionary collection.

**Expected contract:** on Favorites tab, bookmark sets `FavoritesFilterState.shared.selectedTab = .dictionary`; on Main/Speaker tabs, the same global dictionary icon may continue opening the quick drawer. This needs a tab-specific callback at the ShellHeaderHost boundary.

## Concrete finding F-002 — Dictionary Games action uses Favorites game source

`FavoriteView.favoritesPracticeSection()` currently uses `.gameParkFromFavorites` for both `selectedTab == .cards` and `selectedTab == .dictionary`. This means the Dictionary mode's `Игры` row is routed through the Favorites game source instead of the dictionary source. The Dictionary quick drawer already has a separate `DictionarySessionSelection` and direct `.game` path, so the final app needs either a dictionary-specific Game Park source or a direct dictionary game route that preserves selected dictionary card IDs.

**Expected contract:** Favorites → Games uses favorite card scope; Dictionary → Games uses dictionary card scope. Neither path may fall back to the other collection or rebuild a generic course queue.

## Finding F-003 — GameRequestedCourseScope lifecycle is covered

The initial grep appeared to show no `clear` call site, but `AppShell.GameView` clears `GameRequestedCourseScope.shared` in `.onAppear` after the route has already received `lessonIds` and `cardKeys` as initializer arguments. This is the correct one-shot order: the route captures scope first, then the shared request is cleared. No fix is required for this item.

## Finding F-004 — GrandDialogue card-level persistence is fixed

`GrandDialogueGameView` now tracks failed turn ids, derives source card keys from each expected reply, and records coverage/failed keys grouped by their actual source course and lesson. Pseudo-sources such as Favorites, Dictionary and Learned Park are excluded from course reinforcement writes.



## Finding F-005 — Dictionary selection cleanup is now shared across game modes

`DictionarySessionSelection.shared.clear()` now runs from the dictionary-aware `onDisappear` paths in Match/Recall, AudioRecall and GrandDialogue. Root-level “all dictionary” training continues to explicitly activate `nil`, and a new selection replaces the previous selection.



## Finding F-006 — GrandDialogue attribution is now source-grouped

GrandDialogue may still stitch base-course material for its conversational fallback, but completion now groups `sourceCardKeys` and `lessonIds` by each reply's actual source course. A turn from a stitched course is no longer written under the input course id.



## Preliminary audit matrix

| ID | Area | Severity | Impact | Candidate fix |
|---|---|---:|---|---|
| F-001 | Favorites toolbar navigation | High | Bookmark can open quick drawer instead of Dictionary collection | Tab-specific callback at AppShell; applied locally during audit |
| F-002 | Dictionary → Games | Resolved | Dictionary action now uses a dedicated Game Park source and course id | Verify Simulator flow |
| F-003 | Game scope lifecycle | Resolved | GameView captures arguments then clears shared request onAppear | No change required |
| F-004 | GrandDialogue persistence | Resolved | GrandDialogue records source and failed card keys | Verify error queue/grade sheet |
| F-005 | Dictionary session selection | Resolved | AudioRecall and GrandDialogue now clear dictionary selection on exit | Verify all game modes |
| F-006 | GrandDialogue attribution | Resolved | Completion groups by actual reply source course/lesson | Verify mixed stitched session |
| F-007 | Dictionary Game Park chrome | Resolved | AppShell excludes Dictionary Game Park from global header backdrop | Verify overlay presentation |

## Manager/state ownership findings

| State | Source of truth | Boundary | Audit result |
|---|---|---|---|
| Learned lesson/card progress | `ProgressManager` | `LessonsManager` rebuilds aggregates from it on load | Consistent; do not derive learned state from reinforcement sessions alone |
| Course/lesson reinforcement metrics | `ReinforcementStore` | Read by LessonsView/grade sheet and written by game completion paths | Requires every game mode to send concrete card scope; GrandDialogue fixed in this batch |
| Card favorites | `FavoriteManager` | Used by Course, Lessons and Favorites | Separate from Dictionary storage; do not delete dictionary cards when toggling favorite |
| Speaker queue/context | `SpeakerManager` + `SpeakerRequestedCourseId` | Speaker entry and return context | One-shot return payload is consumed and cleared; training scope must be set before root-tab switch |
| Dictionary multi-selection | `DictionarySessionSelection` | Dictionary drawer → Speaker/Game | Must be cleared at every dictionary game mode exit; AudioRecall and GrandDialogue fixed in this batch |
| Root navigation | `NavigationIntent` | AppShell applies `requestedTab` and `path` | Route/pseudo-source normalization is centralized for Favorites; no new duplicate router introduced |

The main architectural risk is not persistence corruption but **scope translation**: a route can be correct while its downstream game still uses a pseudo-course or stale selection. The applied fixes therefore preserve explicit source identities instead of adding another manager.

## Concrete finding F-007 — New Dictionary Game Park missed global overlay chrome exclusion

When `gameParkFromDictionary` was added, AppShell's global `TaikaLiquidGlassHeaderBackdrop` exclusion list still contained only `gamePark` and `gameParkFromFavorites`. This would leave the app header transition layer visible above the Dictionary Game Park overlay, unlike the other Game Park entry points.

**Fix applied:** `gameParkFromDictionary` now uses the same AppShell chrome exclusion contract.
