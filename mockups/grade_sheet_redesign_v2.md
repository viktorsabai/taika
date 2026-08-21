# Taika Grade Sheet Redesign v2

## Product direction

The grade sheet should read as an educational control surface, not an admin dashboard. The hierarchy is: one mastery outcome, four reinforcement subjects, then a focused lesson queue.

## Key changes

1. Replace scattered green checkmarks with one consistent outlined selection circle at the leading edge of each lesson row.
2. Replace tiny `Выбрать все / Снять выбор` links with a segmented control: `Все уроки` and `Только ошибки`.
3. Keep lesson metrics on one readable line: learned cards, error count when non-zero, and reinforcement score.
4. Show errors as an inline calm marker such as `Фокус · 2`, using muted pink only as a signal. Do not use red panels, red badges, or Jira-like incident styling.
5. Keep subject rows as a strict list with dividers. Paid modes show a quiet lock and `Taika+`; tapping opens the contextual native bottom sheet.
6. Use the existing Taika Liquid Glass language: graphite plane, ultra-thin material, pink-to-mint mastery gradient only for the key result and selected controls, restrained hairlines, and native Apple-like spacing.

## Screen hierarchy

- `ЗАЧЁТКА КУРСА`: 75% mastery, three supporting metrics.
- `ПРЕДМЕТЫ ЗАЧЁТКИ`: Speaker, Memory, Recall, Audio.
- `ФОКУС НА СЕГОДНЯ`: scope segmented control and lesson queue.
- One bottom CTA: `Начать с фокуса`.

## SwiftUI implementation scope

The implementation should be one coordinated pass across the grade sheet and lesson list components. It should preserve the existing card-level failedCardKeys model and use the same selected lesson set for `Все уроки` and `Только ошибки`. The redesign must not change navigation or card-scope semantics.
