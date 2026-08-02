# DS split — инвентаризация (CardDS / SpeakerDS)

Цель: нарезать монолиты без смены публичного API. Ниже — опорный список **публичных** типов для grep по call-sites перед переносом.

## CardDS.swift (`Theme/CardDS.swift`)

Публичные `struct` (View / модели), по состоянию репозитория:

- `TaikaWordmarkLockup`
- `StepProGateCard`
- `StepWordCardVisual`
- `StepLifehackCardVisual`
- `StepLifehackCardLegacy`
- `CardChrome`
- `CardFooterRail`
- `CardBase`
- `StepCardActionBar`
- `StepCardBase`
- `CardNoteBase`
- `NoteTextCard`
- `NoteStepCard`
- `TaikaFMBubble`
- `TaikaSearchBubble`
- `TaikaFMBubbleTyping`
- `CourseLessonCard`
- `WeeklyResumeItem`
- `CardDS_DaySummary`
- `WeeklyDayBadge`
- `WeeklyResumeCell`
- `WeeklyResumeStrip`
- `StepWordCard`

Рекомендуемые фазы нарезки:

1. Weekly resume блок (`WeeklyResume*` + `CardDS_DaySummary`).
2. FM / поиск (`TaikaFM*`).
3. Step-карточки (`Step*`, `CardBase`, `CardChrome`).
4. Курс (`CourseLessonCard`).

## SpeakerDS.swift

- Единственный крупный публичный контейнер: `SpeakerDSRoot`. Остальное — вложенные `private` типы; выносить смысл только вместе с корнем или через `fileprivate` модули в той же папке.

## Выполнено в рамках эпика

- Удалён неиспользуемый `SpeakerActiveCardAnchorKey` (PreferenceKey не имел ссылок в `SpeakerDS`).
