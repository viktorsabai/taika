# Taika UI/UX Epic — Scrum decomposition

## Epic goal

Создать единую native UI-систему для всех информационных и action-состояний Taika: технологичный dark continuous canvas, liquid-glass surfaces, мягкий blur, waveform/orb motion, понятные русские объяснения и CTA, которые всегда возвращают пользователя в исходный контекст.

Эпик не должен превращаться в одновременный переписывание всего приложения. Работа идёт от общего visual foundation к вертикальным продуктовым срезам. Каждый slice должен заканчиваться рабочим пользовательским сценарием, а не только новым компонентом.

## Non-goals

В этот эпик не входят изменение образовательного curriculum, новый onboarding, редизайн основных course cards, полная смена брендинга, новая бизнес-модель Taika+ или переписывание Speaker engine. Мы меняем presentation layer, interaction states, routing behavior и copy, сохраняя текущие product capabilities.

## Product backlog

| ID | Backlog item | Тип | Приоритет |
|---|---|---|---|
| FND-01 | Зафиксировать Taika Liquid Glass visual tokens: canvas, glass, tint, stroke, shadow, blur | Enabler | P0 |
| FND-02 | Сделать единый continuous background без header/body split | Enabler | P0 |
| FND-03 | Создать reusable `GlassSurface`, `GlassMessage`, `GlassChoice`, `GlassPaywall`, `GlassWorkbench` | Enabler | P0 |
| FND-04 | Создать motion tokens и state transition rules | Enabler | P0 |
| FND-05 | Добавить accessibility contract: contrast, Dynamic Type, Reduce Motion, VoiceOver labels | Enabler | P0 |
| TAX-01 | Зафиксировать state taxonomy и surface selection rules | Architecture | P0 |
| TAX-02 | Унифицировать close, back, dismissal и return-context behavior | Architecture | P0 |
| TAX-03 | Унифицировать haptics для success, locked tap, error и selection | Interaction | P1 |
| GAME-01 | Пересобрать Game Park empty state | Vertical slice | P1 |
| GAME-02 | Пересобрать Game Park mode picker | Vertical slice | P1 |
| GAME-03 | Добавить contextual locked-game peek | Vertical slice | P1 |
| PAY-01 | Пересобрать attempts/quota state | Vertical slice | P1 |
| PAY-02 | Связать quota → contextual paywall → return to source | Vertical slice | P1 |
| PAY-03 | Обновить Taika+ plan selection surface | Vertical slice | P1 |
| SEARCH-01 | Пересобрать search workbench | Vertical slice | P1 |
| SEARCH-02 | Реализовать empty query, results и no-results states | Vertical slice | P1 |
| SPEAK-01 | Унифицировать Speaker listening/recognizing/result/failure states | Vertical slice | P0 |
| SPEAK-02 | Исправить input sheet keyboard-safe behavior | Vertical slice | P1 |
| SPEAK-03 | Добавить failure recovery without navigation dead-end | Vertical slice | P0 |
| DICT-01 | Завершить My Dictionary empty/list/edit surfaces | Vertical slice | P1 |
| DICT-02 | Добавить lightweight saved/edited confirmation | Vertical slice | P1 |
| QA-01 | Пройти все state transitions на iPhone sizes | QA | P0 |
| QA-02 | Проверить no-jump/no-freeze/no-dead-end navigation | QA | P0 |
| QA-03 | Проверить dark/light system contrast and Reduce Motion | QA | P1 |

## Foundation decomposition

### FND-01 — Visual tokens

Нужен отдельный `TaikaOverlayTokens` layer, а не новые цвета внутри каждого View. Минимальный контракт: `canvas`, `canvasElevated`, `glassFill`, `glassStroke`, `glassHighlight`, `accentFill`, `accentGlow`, `textPrimary`, `textSecondary`, `danger`, `success`, `blurRadius`, `cornerRadius`, `contentPadding`.

Основной принцип: glass должен быть прозрачным настолько, чтобы underlying context сохранялся, но достаточно плотным для контраста текста. Нельзя использовать одинаковый opacity для всех поверхностей: Message, Paywall и Workbench имеют разную плотность.

### FND-02 — Continuous Canvas

Header, body и overlay должны восприниматься как один экран. Для этого background glow и blur принадлежат screen shell, а не отдельной карточке. Overlay не должен создавать новую серую плоскость поверх gray body. В Speaker waveform/orb остаётся главным spatial anchor.

### FND-03 — Reusable surfaces

| Primitive | Назначение | Не должен делать |
|---|---|---|
| `GlassSurface` | общий material shell | не навязывает padding и CTA |
| `GlassMessage` | empty/info/recovery | не содержит plan rows |
| `GlassChoice` | modes/plans | не выглядит как alert |
| `GlassPaywall` | purchase | не используется для обычного лимита |
| `GlassWorkbench` | Speaker/Search/Dictionary | не превращает рабочий flow в modal card |

### FND-04 — Motion

Motion должен объяснять изменение состояния. Entrance — короткий spring. State change — opacity/scale/tint/orb transition. Locked tap — короткий haptic и pulse. Error — мягкий recovery shake только один раз. Никаких бесконечных bounce-анимаций, которые маскируют отсутствие ответа.

### FND-05 — Accessibility

Каждый interactive element имеет VoiceOver label и hint. Text проверяется на контраст поверх реального material. Dynamic Type не должен обрезать CTA. `Reduce Motion` отключает orbital traces и оставляет только fade. Keyboard-safe surfaces не должны перекрывать input.

## Message taxonomy

| Class | Когда использовать | Главная структура | CTA |
|---|---|---|---|
| `GlassMessage` | empty, explanation, recovery | eyebrow → title → short copy → optional steps | один primary action |
| `GlassChoice` | mode picker, plan picker | title → selectable rows → selected state | row action или primary CTA |
| `GlassPeek` | locked tap, contextual hint | icon → one benefit → CTA + dismiss | contextual CTA |
| `GlassQuota` | daily attempts, free limits | single metric → reset rule → upgrade/continue | upgrade или postpone |
| `GlassPaywall` | deliberate purchase intent | source context → value → plans → legal | purchase CTA |
| `GlassWorkbench` | Speaker/Search/Dictionary | persistent canvas → task/result → inline actions | task-specific action |
| `GlassToast` | saved/edited/copied confirmation | short confirmation only | no CTA |
| `GlassFailure` | recognition/no-result/network failure | what happened → retry path → alternative | retry/alternative |

## Classification rules

Если пользователь должен выбрать между несколькими режимами, используется `GlassChoice`. Если нужно объяснить, почему действие сейчас недоступно, используется `GlassPeek`, а не новый full-screen sheet. Если есть деньги или subscription, используется `GlassPaywall`. Если пользователь находится внутри ongoing task, например Speaker или Search, нельзя заменять его workbench на generic alert.

Каждое сообщение обязано ответить на три вопроса: **что произошло; что пользователь может сделать сейчас; куда он попадёт после CTA**. Закрытие всегда возвращает в исходный контекст.

## Vertical Scrum slices

### Slice A — Speaker foundation, Sprint 1

**User story:** Как пользователь, я хочу понимать, слушает ли Speaker, распознаёт ли речь, получил ли результат или не расслышал меня, не теряя контекст.

**Scope:** FND-01–05, SPEAK-01, SPEAK-03, TAX-02.

**States:** idle → listening → recognizing → result → failure → retry.

**Acceptance criteria:** Header/body выглядят как один canvas; orb/waveform/status меняются синхронно; failure даёт `Попробовать ещё раз` и `Написать по-русски`; никакого зависания без visible state; close/retry возвращают в Speaker.

### Slice B — Game Park, Sprint 2

**User story:** Как пользователь, я хочу понять, почему игры закрыты, выбрать доступный режим и увидеть понятное предложение PRO без лишней навигации.

**Scope:** GAME-01–03, GlassMessage, GlassChoice, GlassPeek.

**Acceptance criteria:** Empty state ведёт в Courses; mode rows объясняют механику; locked tap открывает contextual peek; `Не сейчас` возвращает в Game Park; после появления playable cards state обновляется без перезапуска.

### Slice C — Quota and Paywall, Sprint 3

**User story:** Как free-пользователь, я хочу видеть один понятный лимит и понимать, что даст Taika+.

**Scope:** PAY-01–03, GlassQuota, GlassPaywall.

**Acceptance criteria:** одна quota metric без противоречивых чисел; paywall знает source context; close не запускает урок или игру; selected plan визуально очевиден; legal copy остаётся читаемым.

### Slice D — Search, Sprint 4

**User story:** Как пользователь, я хочу найти фразу, урок или курс и получить recovery path, если ничего не найдено.

**Scope:** SEARCH-01–02, GlassWorkbench, GlassFailure.

**Acceptance criteria:** keyboard-safe; empty query отличается от no-results; results сгруппированы; no-results предлагает изменить запрос; search close возвращает на тот экран, откуда он был открыт.

### Slice E — My Dictionary, Sprint 5

**User story:** Как пользователь, я хочу быстро открыть личный словарь, увидеть свои фразы и управлять ими без перехода в Speaker.

**Scope:** DICT-01–02, GlassWorkbench, GlassToast.

**Acceptance criteria:** empty/list/edit states используют один canvas; audio/copy/train/edit/delete доступны inline; save/delete мгновенно обновляют badge и список; confirmation не открывает второй modal; dictionary icon унифицирован как `books.vertical`.

## Sprint order and dependencies

| Sprint | Focus | Depends on | Deliverable |
|---|---|---|---|
| Sprint 0 | Audit + tokens + taxonomy | current code review | approved component contract |
| Sprint 1 | Speaker | Sprint 0 | working continuous Speaker states |
| Sprint 2 | Game Park | Sprint 0 | empty/modes/locked flow |
| Sprint 3 | Quota + Paywall | Sprint 0, Sprint 1 | source-aware paywall flow |
| Sprint 4 | Search | Sprint 0 | workbench search states |
| Sprint 5 | Dictionary | Sprint 0, existing MyDictionaryView/Edit Sheet | complete dictionary pipeline |
| Sprint 6 | Integration QA | Sprints 1–5 | device-tested unified overlay system |

Порядок начинается со Speaker, потому что он задаёт главный технологичный visual language и самый частый processing state. Game Park можно делать следующим как независимый vertical slice. Paywall зависит от корректного source-context return. Dictionary использует уже созданный самостоятельный экран и Edit Sheet, поэтому не должен быть смешан с Favorites redesign.

## Definition of Done

Эпик считается завершённым, когда все пять vertical slices используют общие surface primitives и tokens; все states имеют явные вход, success, failure и dismissal transitions; CTA объясняют результат; close возвращает в исходный context; нет navigation dead-ends, layout jumps или indefinite loading states; screen readers и Reduce Motion поддержаны; каждый slice проверен на реальном устройстве минимум на маленьком и большом iPhone; создан отдельный UI branch с commit history по sprint slices.

## Первый sprint backlog

| Story | Task | Acceptance |
|---|---|---|
| S0-01 | Создать `TaikaOverlayTokens` | Все новые surfaces используют tokens, без локальных random colors |
| S0-02 | Создать `GlassSurface` и `GlassWorkbench` | Material прозрачен, контрастен и не создаёт gray slab |
| S0-03 | Перенести Speaker background в continuous canvas | Header/body split исчезает без потери читаемости |
| S0-04 | Зафиксировать Speaker state enum/UI contract | idle/listening/recognizing/result/failure/retry покрыты |
| S0-05 | Добавить failure recovery | Повтор и Russian input работают без dead-end |
| S0-06 | Device QA pass | iPhone sizes, Dynamic Type, Reduce Motion, keyboard-safe |

## Owner decisions needed

До начала реализации нужно утвердить три вещи: что `liquid glass` является общей material direction для всех surface classes; что Speaker становится первым implementation slice; и что Game Park locked tap открывает contextual peek, а не отдельный полноэкранный paywall. Остальные решения можно принимать внутри sprint acceptance criteria без дополнительного product reset.


## Уточнение epic boundary после Dictionary audit (2026-08-17)

### Dictionary вынесен из текущего overlay epic

Проверка git history показала, что Dictionary work присутствует в текущей агентской цепочке (`a1cb625` — quick drawer, `7c212e0` — routing simplification, `a300568` — standalone `MyDictionaryView` и edit sheet, `4404473` — explicit save flow в Speaker), но эти commits не достижимы из `origin/HEAD` текущего продового ref `ddc567b`.

Поэтому в текущий общий overlay epic Dictionary не включаем и не переписываем вслепую. Фактическая реализация на устройстве должна быть принята за source of truth после отдельного device/repo sync. Dictionary фиксируется как **tech debt / отдельный follow-up epic**:

- сверить production implementation с standalone `MyDictionaryView` и `DictionaryPhraseEditSheet`;
- подтвердить единственный canonical entry point и отсутствие дублирования с Smart Speaker drawer;
- проверить listen/copy/train/edit/delete и atomic `FavoriteManager` update;
- после этого отдельно подготовить mockup и commit, не смешивая его с текущими overlay foundation/Game Park/Paywall задачами.

### Consolidated test deployment boundary

В текущий test deployment входят только согласованные overlay commits Sprint 0–3:

1. Sprint 0 — shared Liquid Glass foundation;
2. Sprint 1.1 — Speaker current result + explicit dictionary save behavior;
3. Sprint 2 — Game Park contextual locked peek;
4. Sprint 3 — source-aware Quota/Paywall hierarchy.

Dictionary-specific commits не считаются частью consolidated overlay deployment, пока production state не будет подтверждён отдельно. Push не выполняется автоматически; перед тестом tech lead должен собрать нужную ветку/цепочку commits в один deployment candidate.

### Next epic slice

После Sprint 3 следующим остаётся Search overlay. Dictionary не является Sprint 4 текущего epic и планируется отдельным follow-up после production audit.
