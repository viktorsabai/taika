# Overlay Style Consistency — As-Is vs To-Be

## Verdict

Текущее расхождение стилистики информационных блоков **не было задумано эпиком**. В постановке были предусмотрены разные роли primitives — `GlassMessage`, `GlassChoice`, `GlassPeek`, `GlassQuota`, `GlassPaywall` и `GlassWorkbench`, — но общий material language должен был оставаться единым. Сейчас роли частично смешались с разными локальными композициями, поэтому визуальная система выглядит не как одна семья, а как несколько похожих, но независимых экранов.

Главное правило To-Be: **один material system, разные content roles; не один layout на всё**.

## What the epic actually specified

| Primitive | Роль | Допустимая геометрия |
|---|---|---|
| `GlassMessage` | Короткое информационное сообщение или failure/recovery | Compact, content-sized, без большого пустого тела |
| `GlassChoice` | Выбор одного режима или recovery action | Compact card с повторяемыми choice rows |
| `GlassPeek` | Контекстный locked preview | Низкий bottom sheet/peek, не полноценный экран |
| `GlassQuota` | Лимит/использование | Compact quota card, крупное число и короткое объяснение |
| `GlassPaywall` | Подписка и покупка | Самая ёмкая card с pricing и primary CTA |
| `GlassWorkbench` | Ввод/поиск | Input-like surface, не informational card |

Следовательно, **разный размер контента — это нормально**. Ненормально, когда у каждого state свои blur, border, radius, opacity, inset и vertical placement.

## Screenshot-based As-Is

### Quota: «Попытки сегодня»

Состояние функционально понятно и наиболее близко к `GlassQuota`, однако visual weight слишком большой: много вертикального воздуха, quota card визуально приближается к paywall. Крупное число и CTA полезны, но quota должна быть короче и плотнее, с одной ясной причиной лимита и одним action.

### Game Park

Game Park по смыслу является `GlassChoice`, и его rows уже соответствуют этой роли лучше всего. Проблема была не в самом выборе, а в реализации container: card растягивалась вертикально, просвечивал underlying screen, а при попытке унифицировать с paywall она превратилась в слишком большую panel. Правильная форма — content-sized compact card, как в утверждённом mockup: title, subtitle, section label и три choice rows.

### Paywall

Paywall визуально самый цельный, но он не должен становиться универсальным шаблоном для всех сообщений. Его расширенная геометрия оправдана pricing content, legal copy и purchase CTA. Он задаёт canonical material and CTA treatment, но не должен задавать высоту Game Park или quota.

### Search / Workbench

Search mockup подтверждает ещё одну важную границу: input surface должен быть компактным workbench внутри собственной card. Он не должен выглядеть как quota, choice или paywall, хотя использует тот же glass material.

## Shared rules that should be unified

| Rule | Current risk | To-Be contract |
|---|---|---|
| Material | У разных cards разная плотность и просвечивание | Использовать `GlassSurface`/`blackGlass` и shared opacity tokens |
| Radius | Визуально близкие, но не всегда одинаковые corners | `cardRadius` для outer surface, `compactRadius` для rows |
| Border | Иногда border заметнее, чем material | Один subtle stroke; selected/locked — только semantic emphasis |
| Backdrop | В некоторых states underlying screen слишком читаем | Единственный shared `GlassBackdrop`; контекст сохраняется, но не конкурирует с card |
| Header | Close/title по-разному сидят в cards | Единый title/close row primitive внутри outer surface |
| Insets | Разные horizontal/vertical paddings | Shared card/content insets; role-specific только content spacing |
| CTA | Paywall CTA сильнее всех, что нормально | Shared primary button treatment; action count зависит от role |
| Motion | Разные overlays ощущаются как разные системы | Единые 180–240 ms presentation/interaction timings |

## Recommended To-Be contract

Вынести не один универсальный overlay layout, а **один reusable shell с role-specific body**:

```text
UnifiedGlassOverlayFrame
├── shared backdrop
├── shared title + close row
├── role-specific content
│   ├── Message body
│   ├── Choice rows
│   ├── Quota body
│   ├── Paywall pricing
│   └── Workbench input
└── optional role-specific action zone
```

`GlassChoice` и `GlassQuota` должны быть compact/content-sized. `GlassPeek` должен оставаться снизу. `GlassPaywall` может быть большим. Это не нарушение унификации, а правильное разделение ролей.

## Priority order

**P0.** Убрать локальные full-height/flexible containers из `GlassMessage`, `GlassChoice` и `GlassQuota`; вернуть content-sized sizing. Устранить двойной backdrop/header composition.

**P1.** Применить shared title/close row, shared outer insets и shared border/material tokens ко всем informational overlays. Game Park должен использовать `GlassChoice` rows, quota — `GlassQuota`, failure — `GlassMessage`.

**P2.** После device validation выровнять motion timing, haptic feedback, locked peek transition и accessibility labels. Paywall не расширять на остальные roles.

## Final answer

Текущая стилистическая разница — **не осознанная часть постановки**, а результат того, что primitives были созданы, но часть существующих overlays продолжила использовать собственную композицию. Исправлять нужно не одинаковой высотой всех сообщений, а единым `UnifiedGlassOverlayFrame` с разными компактными role bodies.
