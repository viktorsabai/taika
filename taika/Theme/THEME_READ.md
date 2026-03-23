

# THEME COMPONENT — ARCHITECTURE & IDENTITY CONTRACT

## 1. PURPOSE

Theme is the core identity layer of Taika.

It is not just colors.  
It is the **visual contract** of the entire product.

Theme ensures:

- single source of truth for design tokens
- strict separation between UI primitives and feature components
- visual consistency across Course / Lessons / Step / HomeTask / Speaker / Main / Profile / PRO
- no random styling inside Views
- no duplicated visual logic
- no "one-off" UI hacks

If something is visual — it must originate from Theme.

---

## 2. ARCHITECTURE LAYERS

Theme is composed of the following parts:

### 2.1 ThemeManager

Responsibility:
- active theme state (dark / light / colored)
- accent tokens
- gradients
- background tokens
- runtime switching support

Rules:
- no UI logic
- no navigation logic
- no business logic
- pure design tokens and theme state

ThemeManager is the only runtime authority for color decisions.

---

### 2.2 ThemeDesign

Contains:
- color definitions
- gradients
- semantic tokens
- spacing scales
- corner radii
- elevation levels
- shadow styles

Important:
Feature components must never define raw colors.

All visual values must come from semantic tokens.

Example rule:
Never use Color.black directly.  
Use ThemeManager.shared.current.backgroundPrimary.

---

### 2.3 AppDS (Atomic Design System)

AppDS is the atomic visual layer.

Contains:
- typography tokens
- text styles
- icon styles
- button primitives
- chip primitives
- glass cards
- system spacing helpers

AppDS builds reusable atomic UI elements.

Strict rule:
AppDS must not contain feature logic.
No navigation.
No state.
No business rules.

Only pure visual rendering.

---

### 2.4 CardDS

CardDS builds structured cards using AppDS atoms.

Examples:
- LessonCard
- StepCard
- PROCard
- GameCard

CardDS:
- composes AppDS atoms
- applies elevation
- applies accent tokens
- applies border logic

CardDS must not:
- navigate
- fetch data
- mutate state

---

### 2.5 AppShell

AppShell is the global layout container.

Responsibilities:
- global background
- header orchestration
- toolbar orchestration
- safe area handling
- navigation state rendering
- theme background injection

AppShell decides:
- when back header appears
- when bottom toolbar appears
- how overlays stack
- global environment injection

AppShell must never contain feature-specific layout.

---

### 2.6 OverlayPresenter

Single global overlay engine.

Responsibilities:
- paywall overlays
- game result overlays
- completion overlays
- alert overlays
- modal glass sheets

Rules:
- no local overlay hacks inside feature views
- all overlays go through OverlayPresenter
- consistent glass style
- consistent blur logic
- consistent animation contract

---

### 2.7 NavigationIntent

Centralized navigation abstraction.

Purpose:
- decouple UI from navigation decisions
- prevent nested NavigationLinks chaos
- unify navigation from all components

Feature views trigger intents.
AppShell interprets and renders navigation.

---

## 3. DESIGN PRINCIPLES ENFORCED BY THEME

### 3.1 No Hardcoded Values

Forbidden:
- Color.black
- random padding
- arbitrary cornerRadius
- inline font definitions

Allowed:
- Theme tokens only

---

### 3.2 Single Background Source

Background must always come from AppShell.

Feature views must not define their own full-screen background.

Exception:
Temporary experimental components (must be removed before release).

---

### 3.3 Consistent Elevation

Elevation scale:
- Level 0: screen background
- Level 1: section containers
- Level 2: cards
- Level 3: floating overlays
- Level 4: modal glass

No arbitrary shadow stacking.

---

### 3.4 Accent Governance

Accent color must be:
- used for actions
- used for progress
- used for highlights
- never used as background fill

Accent is not decoration.
Accent communicates interactivity.

---

### 3.5 Glass Language

Glass style is defined centrally.

All:
- paywalls
- results
- premium overlays
- modal popups

must use the same glass contract.

No custom blurred rectangles allowed.

---

## 4. WHAT THEME MUST PREVENT

Theme exists to prevent:

- visual drift between modules
- duplicated button styles
- multiple bubble implementations
- inconsistent corner radii
- header misalignment
- layout breaking on different screens
- feature teams inventing their own tokens

Theme is a guardrail system.

---

## 5. FEATURE CONTRACT WITH THEME

Each feature must respect:

Course / Lessons / Step / HomeTask / Speaker / Profile / PRO / Main:

- no local background
- no local shadow experiments
- no local bubble designs
- no random gradients
- no hardcoded fonts
- no dynamic style branching outside ThemeManager

Feature components:
- consume tokens
- compose AppDS
- render data

Nothing more.

---

## 6. FUTURE EXTENSION

Theme must support:

- runtime theme switching
- seasonal accents
- PRO-exclusive accent modes
- experimental accent A/B testing
- brand refresh without touching feature code

This is possible only if Theme remains pure and centralized.

---

## 7. FINAL RULE

If something looks visually inconsistent:

It is not a feature bug.
It is a Theme contract violation.

Fix the contract.
Do not patch locally.

Theme is the backbone of Taika identity.
