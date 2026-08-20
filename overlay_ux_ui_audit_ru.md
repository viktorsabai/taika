# Taika overlays — UX/UI audit

## Executive conclusion

Сейчас у Taika нет одного общего языка информационных состояний. Есть общий тёмный фон, розовый accent и rounded container, но разные overlays используют разные уровни визуальной плотности, разные сценарные CTA и разные модели поведения. Поэтому они выглядят «плюс-минус из одной системы», но не как единая native product surface.

Главная проблема не в том, что карточки недостаточно красивые. Проблема в том, что в одном визуальном контейнере смешаны **информационный empty state**, **ограничение free-функции**, **paywall**, **search task**, **AI processing state**, **result state** и **game mode selection**. У каждого из них должна быть своя информационная иерархия, хотя material и motion могут быть общими.

## Classification matrix

| Класс | User story | Текущий экран | Решение | Почему |
|---|---|---|---|---|
| Empty state with next action | Game Park без выученных cards | «Игровой парк / Сначала выучи пару фраз» | **Оставить сценарий, изменить presentation** | Логика понятная, но экран выглядит как отдельная тяжёлая карточка, а CTA слишком общий. |
| Entitlement/paywall | Free user открывает PRO games | Game Park с locked rows или отдельный paywall | **Разделить** | Locked mode должен объяснять ценность конкретной функции; paywall не должен маскироваться под обычный informational overlay. |
| Purchase surface | Открыть Taika+ | Paywall с планами | **Оставить как отдельный modal class, переработать material** | Структура планов и CTA работает, но paywall визуально слишком похож на обычные sheets и недостаточно связан с конкретной причиной открытия. |
| Usage limit | Free attempts exhausted | «Попытки сегодня» | **Оставить модель, изменить hierarchy** | Хорошо показывает usage, но сейчас это сухое уведомление с paywall CTA; нужен progress/remaining state и ясное действие после закрытия. |
| Search task | Найти курс/урок/фразу | Search overlay with keyboard | **Оставить, изменить shell** | Это не message card, а task surface. Ему нужен continuous search surface, а не floating card над пустым фоном. |
| AI processing | Speaker listens/recognizes | «Слушаю», «Распознаю», loading orb | **Оставить motion concept, изменить states** | Orb/waveform — сильный brand asset. Нужно унифицировать processing states и убрать ощущение зависания. |
| AI result | Speaker gives translated phrase | Result card with RU, translit, Thai, actions | **Оставить information architecture, усилить glass/material** | Это основной product value moment. Он должен ощущаться частью Speaker canvas, не вставленным alert. |
| User input | «Напиши по-русски» | Text input sheet + keyboard | **Оставить flow, изменить keyboard-safe layout** | Функционально понятно, но sheet слишком отделён от Speaker и теряет continuous context. |
| Mode picker | Game Park mode selection | «Выбери режим» with free/PRO rows | **Пересобрать** | Сейчас выглядит как список заглушек: неясно, чем режимы отличаются и что пользователь получит. |
| Failure/unknown state | Ничего не распознано / поиск не дал результата | Various text states | **Добавить unified class** | Сейчас нет единого recovery pattern: что произошло, что можно сделать дальше, повторить или изменить. |

## Что оставить

Нужно сохранить тёмную Taika identity, розово-лиловый accent, крупные скругления, короткие Russian headlines, один primary CTA и мягкую background glow. В Speaker обязательно оставить waveform/orb, live status labels и переходы «речь → текст → перевод»: это наиболее узнаваемый технологичный product moment.

Нужно сохранить отдельный paywall как коммерческий surface, а не превращать все ограничения в toast. Также правильно, что закрытие доступно через `xmark`, а game rows показывают PRO/lock distinction.

## Что изменить

### 1. Убрать «пыльный» backdrop

Сейчас многие screens используют практически однотонный тёмный фон, а content card лежит поверх него как отдельный прямоугольник. Предлагаю единый **continuous liquid-glass canvas**:

- базовый фон: near-black Taika surface;
- один слабый radial accent glow за активным объектом;
- header и body находятся на одной spatial plane;
- overlay получает translucent material, а не плотный gray fill;
- background сохраняет читаемый контекст underlying screen через controlled blur;
- граница — тонкая и полупрозрачная, не яркая рамка;
- shadow минимальная, depth создаётся blur + tint + inner highlight.

Важно: liquid glass — это не просто `.ultraThinMaterial` с opacity. Нужен слой из material, tinted fill, top highlight, low-contrast stroke и controlled dimming. Иначе получится серый «пыльный» прямоугольник.

### 2. Разделить container classes

Один и тот же card shell нельзя применять к Game Park empty state, paywall, search и AI result. Нужны четыре базовых surfaces:

| Surface | Для чего | Характер |
|---|---|---|
| `GlassMessage` | empty, info, recovery | короткий текст + 1 action |
| `GlassChoice` | mode picker, plan picker | selectable rows, explicit states |
| `GlassPaywall` | Taika+ purchase | value proposition + plans + purchase/legal |
| `GlassWorkbench` | Speaker/search/input/result | continuous canvas, less card-like |

### 3. Исправить Game Park

Текущий empty state объясняет, почему игр нет, но «К курсам» слишком резко отправляет пользователя в другой раздел. Лучше CTA `Открыть курсы`, secondary action `Понятно`, а после прогресса — dynamic preview: «Готово для игры: 12 фраз».

Mode picker необходимо заменить на три clearly differentiated rows:

1. **Найди пару** — доступно, 1 sentence about mechanic.
2. **Быстрое повторение** — PRO, show what changes: speed/queue/repetition.
3. **Аудио-реплика** — PRO, show the learning outcome: listen and identify.

При tap на locked row не открывать новый тяжёлый экран без контекста. Давать short bottom confirmation/peek with haptic and CTA `Открыть Taika+`.

### 4. Исправить free-limit message

«Попытки сегодня» должна быть classified as a quota state, not generic information. Recommended hierarchy:

> `2 из 3` remaining/used state → progress indicator → one sentence about reset → `Продолжить с PRO`.

Нужно устранить двусмысленность между «2 из 3» и «Сегодня использовано: 1». Оставить только одну primary metric, например: `Осталось 2 из 3 попыток`.

### 5. Исправить Search

Search — это рабочее состояние, а не message card. Header and body should visually merge. Search field must remain visually attached to the result area; keyboard appearance should move content predictably. Empty search and no-result search need different states:

- empty query: suggestions and recent searches;
- no results: explanation + edit query + course/category suggestions;
- result: grouped sections with count and clear close path.

### 6. Исправить Speaker states

Speaker is currently the closest to the desired identity, but its gray upper body and dark lower body create a visible horizontal split. The background should be one continuous animated field. Status chip, orb, waveform and result card should share the same spatial coordinate system.

State model:

`idle → listening → recognizing → result → saved/trained`.

For each state the status label, orb treatment, waveform and CTA must change together. A spinner alone should never communicate progress. On failure use `Не расслышала` + `Попробить ещё раз` + optional `Написать по-русски`.

## Что добавить

Нужны следующие missing states:

| State | Required copy/action |
|---|---|
| Unknown/failed recognition | Что не получилось + «Попробовать ещё раз» |
| Empty dictionary | Почему пусто + «Сказать фразу» / «Написать по-русски» |
| Game has insufficient learned cards | Сколько нужно и как быстро открыть первую игру |
| Locked game tap | Short explanation of feature value + Taika+ CTA |
| Search no result | Change query, suggestions and clear close |
| Paywall dismissed | Return to original context, never silently enter lesson/game |
| Result saved | Lightweight confirmation, not a second full modal |
| Result edited | Inline confirmation and immediate card update |

## Motion rules

Motion should communicate state changes, not decorate a static card. Every overlay gets one entrance transition and one state transition. Use a short spring for sheet entrance, a subtle material refraction/tint shift when state changes, and haptic only for action confirmation or locked-feature tap. Avoid repeated bounce, delayed content and independent animations that make the card look disconnected from the underlying screen.

For Speaker, waveform/orb motion is the primary animation. For Game Park, use one gentle card lift/press and a small lock response. For paywall, plan selection should use a horizontal tint/scale confirmation without relayout jumps.

## Proposed design direction

**Taika Liquid Glass / Continuous Canvas**: dark near-black base, translucent graphite-violet glass, soft pink-to-lilac accent used only for active/primary actions, a restrained radial glow behind the active state, and no hard header/body division. Overlays should feel like a layer of the same app surface, not a foreign dialog placed on top.

The next deliverable should be a mockup set for:

1. Game Park empty state;
2. Game Park mode picker with free and PRO modes;
3. Locked game tap bottom peek;
4. Daily attempts limit;
5. Taika+ paywall;
6. Search empty, results and no-results;
7. Speaker listening, recognizing, result and failed recognition;
8. Russian input sheet;
9. Dictionary empty/success/edit confirmation.

Only after approval of these states should the SwiftUI surface components be refactored and committed in a dedicated UI branch.
