# Taika UI/UX Epic — synchronized system audit

## Executive finding

Scrum decomposition синхронизирована с текущей SwiftUI-архитектурой. В проекте уже есть значительная база для реализации, но она распределена по нескольким ownership layers и частично дублирует material/overlay logic. Поэтому первый sprint должен быть не «перерисовать все карточки», а **собрать shared foundation и определить ownership**, иначе новый blur будет добавлен ещё в несколько локальных мест и снова разойдётся.

Текущий код уже содержит:

- `ThemeDesign.swift` с базовыми Theme colors, strokes и shared design constants;
- `AppDS.swift` с app-level UI pieces и background/overlay helpers;
- `HeaderOverlays.swift` с `OverlayEtalonBackground`, `OverlayEtalonCard`, `OverlayBlackGlassCard`, `UnifiedOverlayChrome`, primary/secondary buttons и несколькими конкретными overlays;
- `OverlayPresenter.swift` как central enum/presenter;
- `AppShell.swift` как routing host, который switch-ит overlay cases и одновременно управляет header, tab, onboarding и environment objects;
- `SpeakerDS.swift`/`ResultDS.swift` с отдельными Speaker/result overlay treatments;
- `TaikaPlusPaywallView.swift` с собственным card/material/plan implementation;
- `MainView.swift` с самостоятельным `SearchOverlayView` и `SearchOverlayState`;
- Favorites/My Dictionary с отдельными dictionary entry points, notifications и manager-backed state sync.

Главный системный gap: **shared visual vocabulary существует, но не существует одного source of truth для surface material, dismissal behavior и state taxonomy**.

## Current architecture map

| Domain | Current source of truth | Current responsibility | Main gap |
|---|---|---|---|
| Theme tokens | `Theme/ThemeDesign.swift`, `Theme/TaikaDynamicColors.swift` | Colors, strokes, theme manager | Нет отдельного overlay material/token layer |
| App chrome | `Theme/AppDS.swift`, `Theme/TaikaScreenChrome.swift`, `Theme/ShellHeaderDriver.swift` | Header, bottom chrome, app-level visual helpers | Header/backdrop ownership пересекается с overlay backgrounds |
| Overlay primitives | `Theme/HeaderOverlays.swift` | Etalon backgrounds/cards/buttons/chrome + concrete overlays | Несколько material systems: Etalon, BlackGlass, local rounded cards |
| Overlay routing | `Theme/OverlayPresenter.swift` | Enum state, `present`, `dismiss`, current overlay | Routing централизован, но source context и return behavior не унифицированы для всех cases |
| Overlay host | `Theme/AppShell.swift` | Switch overlay → concrete View, navigation side effects | AppShell слишком много знает о конкретном UI и navigation outcomes |
| Speaker | `Speaker/SpeakerDS.swift`, `Speaker/SpeakerView.swift`, `Speaker/ResultDS.swift`, `Speaker/SpeakerManager.swift` | Recording, recognition, result, mode and UI state | Visual state machine не отделена от rendering; failure/retry contract нужно формализовать |
| Paywall | `PRO/TaikaPlusPaywallView.swift`, `PRO/TaikaProConfig.swift`, `PRO/ProManager.swift` | Plans, RevenueCat package state, purchase CTA | Paywall material and return-to-source logic are local, not shared with quota/locked states |
| Search | `Main/MainView.swift`, `Main/MainDS.swift`, `Favorites/FavoriteTabContent.swift` | Main search and Favorites search | Search has multiple implementations and is not a reusable workbench |
| Game Park | `Theme/HeaderOverlays.swift`, `Theme/AppShell.swift`, `Favorites/FavoriteView.swift` | Main/Favorites entry points, empty state and modes | `source: .main/.favorites` exists, but locked/empty/mode states need explicit taxonomy |
| Dictionary | `Favorites/FavoriteManager.swift`, `Favorites/FavoriteView.swift`, `Favorites/MyDictionaryView.swift`, `Theme/AppShell.swift` | Manager data, notifications, standalone dictionary and navigation | Existing sync works through notifications, but entry points and edit/update ownership need one pipeline |

## Scrum backlog mapped to current files

| Backlog item | Primary files | Secondary files | Implementation note |
|---|---|---|---|
| FND-01 tokens | `Theme/ThemeDesign.swift`, `Theme/TaikaDynamicColors.swift` | `Theme/ThemeManager.swift` | Add overlay-specific tokens here, not inside individual overlay Views |
| FND-02 continuous canvas | `Theme/AppShell.swift`, `Theme/AppDS.swift`, `Theme/TaikaScreenChrome.swift` | `Speaker/SpeakerDS.swift`, `HeaderOverlays.swift` | Shell owns canvas/backdrop; feature Views own content only |
| FND-03 reusable surfaces | `Theme/HeaderOverlays.swift` | `PRO/TaikaPlusPaywallView.swift`, `Main/MainView.swift`, `Speaker/ResultDS.swift` | Consolidate Etalon/BlackGlass/local card patterns into shared primitives |
| FND-04 motion tokens | `Theme/VisualEffectsDS.swift`, `Theme/ThemeDesign.swift` | `Speaker/SpeakerDS.swift`, `HeaderOverlays.swift` | Separate state motion from decorative motion; support Reduce Motion |
| FND-05 accessibility | all new shared primitives | Speaker/Search/Dictionary/Paywall | Do before migrating concrete screens, otherwise every screen repeats fixes |
| TAX-01 state taxonomy | `Theme/OverlayPresenter.swift` | `AppShell.swift`, feature managers | Add semantic classes/metadata, not only case names |
| TAX-02 return context | `OverlayPresenter.swift`, `NavigationIntent.swift` | `AppShell.swift`, `SpeakerReturnContext` | Dismissal must return to source; paywall/game/search need explicit source context |
| GAME-01/02/03 | `HeaderOverlays.swift` | `AppShell.swift`, `FavoriteView.swift` | Keep `source` handling, change surface/state composition |
| PAY-01/02/03 | `HeaderOverlays.swift` attempts, `TaikaPlusPaywallView.swift`, `AppShell.swift` | `SpeakerData.swift`, `ProManager.swift` | Quota and purchase should share source-context contract |
| SEARCH-01/02 | `MainView.swift`, `MainDS.swift`, `FavoriteTabContent.swift` | `OverlayPresenter.swift` | Consolidate Main/Favorites search workbench or explicitly share component |
| SPEAK-01/03 | `SpeakerDS.swift`, `ResultDS.swift`, `SpeakerManager.swift` | `SpeakerView.swift`, `AppShell.swift` | Formalize `idle/listening/recognizing/result/failure/retry` before visual migration |
| SPEAK-02 | `SpeakerDS.swift`, `SpeakerView.swift` | `MainDS.swift` input patterns | Keyboard-safe input surface must be part of Speaker workbench |
| DICT-01/02 | `Favorites/MyDictionaryView.swift`, `FavoriteManager.swift` | `FavoriteView.swift`, `AppShell.swift` | Keep standalone dictionary; use notification/observable sync consistently |

## Confirmed system gaps

### 1. Material ownership is fragmented

`HeaderOverlays.swift` already contains `OverlayEtalonBackground`, `OverlayEtalonCard`, `OverlayBlackGlassCard` and `UnifiedOverlayChrome`, but Paywall, Search, Speaker result and other overlays still have local treatments. A new blur implementation must not be added directly to every screen. Sprint 0 should define one material recipe and a migration rule: new overlays use shared primitives; old local shells are migrated only when their vertical slice is active.

### 2. AppShell is both router and feature coordinator

`AppShell.swift` switches over concrete overlay cases and also performs navigation side effects such as dismissing, popping to root and requesting tabs. This is workable for the current number of cases but creates risk during visual refactor: a View change can accidentally change routing. The first implementation should preserve the enum cases and move only presentation/material logic; return-context extraction should be introduced incrementally.

### 3. Overlay cases do not all express semantic state

The current presenter knows concrete cases such as `gamePark`, `gameParkFromFavorites`, `favoritesSearch` and other feature screens, but the taxonomy is implicit. It does not consistently distinguish empty, locked, quota, paywall, workbench, failure and confirmation. Add metadata or typed state next to the existing cases instead of replacing the routing system in Sprint 1.

### 4. Search is duplicated

Main Search (`MainView.swift`) and Favorites Search (`FavoriteTabContent.swift`) are separate implementations. Their UI may look related but they have different ownership and result sources. Before applying Liquid Glass, extract shared `SearchWorkbenchSurface` and keep source-specific result providers. Do not merge result semantics casually.

### 5. Speaker has the strongest visual identity but needs a state contract

`SpeakerDS.swift` and `ResultDS.swift` already contain waveform/orb and result overlays. This is the correct first vertical slice. The gap is not missing animation; it is that processing, result and failure are spread across rendering and manager behavior. Define a state contract first, then keep the existing orb/waveform as the visual anchor.

### 6. Paywall and quota are not one source-aware flow

Attempts are surfaced in `HeaderOverlays.swift`, while purchase UI lives in `TaikaPlusPaywallView.swift`. The visual refactor must preserve RevenueCat/package logic and make source context explicit: Speaker limit, locked game, or another entry point. Closing the paywall must never infer a new destination.

### 7. Dictionary state sync exists, but entry points are still distributed

`FavoriteManager` publishes `smartSpeakerDictionaryCardsDTO` and emits `.FavoritesDidChange`; `AppShell` also posts `.taikaOpenSmartSpeakerDictionary`. `MyDictionaryView` can be kept independent, but the product should select one source of truth for count updates and route the compact drawer/entry point to the standalone screen. Do not mix Dictionary with Favorites filter again.

### 8. Accessibility and keyboard safety are cross-cutting

Material opacity, text contrast, Dynamic Type, Reduce Motion and keyboard avoidance are not currently represented as a shared acceptance layer. They must be Sprint 0 enablers, otherwise each vertical slice will regress on long copy and smaller devices.

## Synchronized sprint plan

### Sprint 0 — Foundation and contracts

**Files:** `Theme/ThemeDesign.swift`, `Theme/TaikaDynamicColors.swift`, `Theme/VisualEffectsDS.swift`, `Theme/HeaderOverlays.swift`, `Theme/OverlayPresenter.swift`.

**Tasks:** add overlay tokens; define shared surface primitives; write surface taxonomy; define dismissal/return-context contract; add Reduce Motion and accessibility hooks; create preview fixtures for Message/Choice/Peek/Workbench.

**Do not touch:** RevenueCat logic, curriculum, Speaker recognition engine, FavoriteManager persistence.

### Sprint 1 — Speaker vertical slice

**Files:** `Speaker/SpeakerDS.swift`, `Speaker/SpeakerView.swift`, `Speaker/ResultDS.swift`, `Speaker/SpeakerManager.swift` and minimal `AppShell.swift` integration.

**Tasks:** migrate Speaker canvas and result/failure surfaces; formalize state enum mapping; preserve waveform/orb; add retry and Russian-input recovery; verify no indefinite spinner.

### Sprint 2 — Game Park vertical slice

**Files:** `Theme/HeaderOverlays.swift`, `Theme/AppShell.swift`, `Favorites/FavoriteView.swift`.

**Tasks:** migrate empty state, mode picker and locked peek; preserve `source: .main/.favorites`; add haptic/return context; ensure playable-card badge updates.

### Sprint 3 — Quota and Paywall

**Files:** `Theme/HeaderOverlays.swift`, `PRO/TaikaPlusPaywallView.swift`, `PRO/TaikaProConfig.swift`, `PRO/ProManager.swift`, `AppShell.swift`.

**Tasks:** one quota metric; contextual source label; shared paywall surface; correct dismissal; preserve package fetching and purchase semantics.

### Sprint 4 — Search workbench

**Files:** `Main/MainView.swift`, `Main/MainDS.swift`, `Favorites/FavoriteTabContent.swift`, optionally `Theme/OverlayPresenter.swift`.

**Tasks:** extract shared workbench; preserve separate result sources; implement empty/results/no-results; keyboard-safe transitions.

### Sprint 5 — Dictionary

**Files:** `Favorites/MyDictionaryView.swift`, `Favorites/FavoriteManager.swift`, `Favorites/FavoriteView.swift`, `Theme/AppShell.swift`.

**Tasks:** migrate empty/list/edit/confirmation surfaces; keep inline actions; ensure `.FavoritesDidChange` and badge update immediately; keep Dictionary independent from Favorites filtering.

### Sprint 6 — Integration QA

**Scope:** all migrated surfaces and routing.

**Checks:** iPhone small/large, Dynamic Type, Reduce Motion, VoiceOver labels, keyboard, dismissal, source return, no-freeze, no-jump, no duplicate overlay, state synchronization.

## Risk register

| Risk | Severity | Mitigation |
|---|---:|---|
| Adding new blur separately to each overlay | P0 | Shared primitives first; no local material in new work |
| Paywall close routes to wrong screen | P0 | Source-context object and explicit return contract |
| AppShell switch grows more complex | P1 | Keep current cases; isolate view rendering from navigation gradually |
| Search implementations diverge further | P1 | Shared workbench shell, separate data providers |
| Speaker visual refactor changes recognition behavior | P0 | No engine changes in UI sprint; state contract + regression testing |
| Dictionary count stale after edit/delete | P0 | One observable source + `.FavoritesDidChange` regression test |
| Glass reduces contrast | P0 | Contrast tests with actual underlying backgrounds and Dynamic Type |
| Keyboard crops input surface | P1 | Keyboard-safe container and device matrix |
| Motion looks decorative or causes hangs | P1 | Explicit state-driven animation and Reduce Motion path |

## Sprint 0 Definition of Done

Sprint 0 is complete when `TaikaOverlayTokens` and shared surface primitives exist; at least four preview fixtures render against real Taika backgrounds; every new surface declares its semantic class; close/dismissal behavior has a source-context contract; no concrete feature screen has added a new one-off material; Reduce Motion and accessibility labels are covered in the primitives; and the first Speaker slice can begin without modifying routing or persistence architecture.

## Recommendation

Начинать реализацию нужно с **Sprint 0 + Speaker contract**, но не с массовой правки `AppDS.swift` и не с перерисовки каждого overlay вручную. `HeaderOverlays.swift` — текущая ближайшая точка shared overlay primitives; `ThemeDesign.swift` — естественное место для tokens; `OverlayPresenter.swift`/`AppShell.swift` — routing boundary; `SpeakerDS.swift`/`ResultDS.swift` — первый product slice. Это минимизирует риск разъезда UI и сохраняет рабочую логику приложения.
