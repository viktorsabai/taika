# Completion UX bugfix refine

| Проверка | Статус |
|---|---|
| Проверить текущую sheet geometry и presentation modifiers | Готово |
| Сопоставить production layout с утверждённым mockup | Готово |
| Сделать completion panel адаптивным по высоте и safe-area | Готово |
| Заменить locked-game отдельный overlay на lightweight bottom sheet | Готово |
| Добавить haptic/feedback и вернуть пользователя в completion context | Готово |
| Проверить `Продолжить курс` transition и duplicate tap guard | Готово статически |
| Проверить intermediate/final/free/PRO states | Ожидает device review |
| Создать refine commit в `agent/post-lesson-completion-state` | Ожидает |
| Push branch | Ожидает отдельного запроса |

# На одной волне — curriculum rebuild

| Задача | Статус |
|---|---|
| Зафиксировать production branch/commit и E-course inventory | Готово |
| Утвердить границы и promise каждого из 6 E-курсов | Готово |
| Спроектировать 6×6 уроков: outcome, prerequisite, micro-scene | Готово |
| Переписать карточки E-курсов с платной глубиной | Готово |
| Добавить response branches и register/casual context | Готово в lesson copy/tips |
| Убрать meta-labels и исправить сломанные/неестественные карточки | Готово |
| Нормализовать все E phonetics с tone arrows | Готово: E-specific validator 0 issues |
| Синхронизировать card_count и catalog outcomes | Готово |
| Запустить structural/content/phonetic validators | Готово: E + full-program regressions |
| Подготовить diff, статистику и curriculum commit | Diff готов; commit в работе |

# «На одной волне» — owner-level 10/10 quality gate

| Задача | Статус |
|---|---|
| Зафиксировать критерии 10/10 для русскоязычного жителя Таиланда | Готово: e_quality_gate_ru.md |
| Проверить каждую карточку на usable language и semantic RU↔Thai alignment | Готово: 36 E-уроков |
| Проверить каждый урок на полноценную micro-scene и response branch | Готово: educational gate 0 issues |
| Проверить границы между шестью E-курсами и соседними категориями | Готово: non-E scope 0 issues |
| Проверить cultural/register/safety risks | Готово: universal claims corrected |
| Внести необходимые content replacements/additions без quota | Готово: -5 irrelevant, +1 required branch |
| Повторно прогнать strict phonetic и structural gates | Готово: E gates 0 issues |
| Подготовить owner verdict и только после него решение о push | Готово: GO TO REVIEW, push ждёт approval |

# Next: push E and audit «Тайский для долгожителей»

| Задача | Статус |
|---|---|
| Запушить approved E commit `fcdfd35` в `agent/post-lesson-completion-state` | Готово: remote HEAD `989e91f` после safe merge |
| Зафиксировать production snapshot Long category | Готово: 7 курсов, 43 урока, 357 карточек |
| Проверить все Long course promises, lesson outcomes и prerequisites | Готово |
| Проверить все Long cards: usable language, duplicates, register, safety и Thai↔RU alignment | Готово: targeted quality pass |
| Переработать Long courses без искусственной card quota | Готово |
| Запустить structural/content/strict phonetic gates | Готово: Long gate 0 issues |
| Подготовить Long verdict и локальный commit | Verdict готов; commit в работе |

# Approved Long push

| Задача | Статус |
|---|---|
| Проверить локальный `ae7b839` и remote ancestry | Готово: remote divergence интегрирован без force-push |
| Запушить `ae7b839` в `origin/agent/post-lesson-completion-state` без force-push | Готово |
| Проверить remote SHA и сообщить техлиду | Готово: `95ffb642bf73d15019e1800b2d943c3c5b58cceb` |

# Dictionary Quick Drawer — SwiftUI feature branch

| Задача | Статус |
|---|---|
| Проверить production HEAD и remote branch | Готово: base `95ffb64` |
| Найти текущие Favorites/Dictionary/Speaker/Overlay entry points | Готово |
| Создать feature branch от production HEAD | Готово: `feature/dictionary-quick-drawer` |
| Реализовать header dictionary shortcut с badge | Готово для Home/Speaker/Favorites |
| Реализовать right-side Quick Drawer и edge-tab | Готово |
| Реализовать full «Мой словарь» destination | Подключено через существующий Favorites dictionary route |
| Не менять Speaker flow и проверить isolation | Готово: `git diff --stat -- taika/Speaker` пуст |
| Проверить gestures, dismissal и navigation regressions | Статически проверено; device/Xcode review ожидает |
| Создать локальный commit и подготовить PR branch | В работе |

# Dictionary Quick Drawer — push and PR

| Задача | Статус |
|---|---|
| Проверить branch `feature/dictionary-quick-drawer` и commit `a1cb625` | Готово |
| Проверить remote branch state без force-push | Готово: branch отсутствовала |
| Запушить feature branch в origin | Готово |
| Подтвердить remote SHA | Готово: `a1cb6256e9b90674cfc0db413a1d014b7d0bee98` |
| Сформировать PR description для tech lead | Готово: dictionary_quick_drawer_pr_ru.md |
| Передать PR description и device smoke checklist | Готово |

# Dictionary UX simplification pass

| Задача | Статус |
|---|---|
| Проверить текущую feature-ветку и production ancestry | Готово |
| Убрать Main edge-tab и дублирующие affordances | Готово |
| Добавить компактную кнопку «Мой словарь» в существующий Main/action area | Готово: рядом с Разминкой |
| Оставить Favorites только для курсовых карточек и лайфхаков | Готово: visible tabs cards/hacks/courses |
| Сделать отдельный full Dictionary route вместо Favorites filter | Готово: `NavigationIntent.Route.dictionary` |
| Проверить Speaker isolation и data separation | Готово: Speaker files не изменены |
| Создать commit и push текущей branch | Готово: `7c212e0` / remote HEAD `7c212e0` |

# Dictionary video audit — reset before next implementation

| Задача | Статус |
|---|---|
| Покадрово восстановить текущий dictionary flow по ScreenRecording | Не начато |
| Зафиксировать все duplicate entry points и conflicting icons | Не начато |
| Проверить, какие действия доступны внутри Quick Drawer/Full Dictionary | Не начато |
| Сопоставить video behavior с SwiftUI routes/overlays/Favorites state | Не начато |
| Определить отдельные сущности Favorites, course cards/hacks и My Dictionary | Не начато |
| Сформулировать целевой low-friction dictionary user story | Не начато |
| Подготовить P0/P1/P2 fixes и acceptance criteria до нового кода | Не начато |

# My Dictionary — native product model before implementation

| Задача | Статус |
|---|---|
| Зафиксировать ownership и границы My Dictionary | Не начато |
| Определить один canonical user story | Не начато |
| Развести Quick Preview, Full Dictionary, Speaker и Favorites | Не начато |
| Определить действия внутри phrase row | Не начато |
| Спроектировать SwiftUI state/navigation model | Не начато |
| Определить sync/invalidation contract после mutations | Не начато |
| Подготовить solution brief и acceptance criteria | Не начато |

# MyDictionaryView implementation

| Задача | Статус |
|---|---|
| Проверить точные FDCardDTO/FavoriteManager/audio APIs | Готово |
| Проверить NavigationIntent и Speaker training entry | Готово: callback integration point |
| Написать standalone MyDictionaryView | Готово: `taika/Favorites/MyDictionaryView.swift` |
| Написать reusable phrase row с раскрываемыми actions | Готово |
| Подключить audio/copy/train/delete/edit callbacks | Готово |
| Добавить empty state и delete confirmation behavior | Готово |
| Проверить Swift syntax/diff и передать готовый файл | Готово статически; Xcode build на Mac |

# My Dictionary — inline edit sheet

| Задача | Статус |
|---|---|
| Проверить FavoriteManager mutation API и user_dict model | Готово |
| Добавить `updateSmartSpeakerCard` с duplicate guard | Готово |
| Реализовать `DictionaryPhraseEditSheet` с RU/Thai/translit полями | Готово |
| Подключить sheet к inline «Изменить» action | Готово |
| Проверить diff, скобки и whitespace | Готово статически; Xcode build на Mac |

# My Dictionary Edit Sheet — commit preparation

| Задача | Статус |
|---|---|
| Проверить текущую ветку и рабочий diff | Не начато |
| Проверить отсутствие изменений в Speaker | Не начато |
| Проверить Swift diff и `git diff --check` | Не начато |
| Создать отдельный commit для Edit Sheet | Не начато |
| Передать SHA и инструкции tech lead | Не начато |

# Critical situation-first curriculum audit

| Задача | Статус |
|---|---|
| Найти курс и уроки про остановку полицией | Не начато |
| Проверить реальные roadside scenarios: остановка, права, байк, шлем, пассажир, маршрут, документы | Не начато |
| Проверить все сценарные курсы на coverage реального user journey | Не начато |
| Составить gap matrix и severity P0/P1/P2 | Не начато |
| Пересобрать Police Stop как эталонный курс | Не начато |
| Обновить JSON только после owner-level content review | Не начато |
| Запустить structural, educational и phonetic validators | Не начато |
| Подготовить commit plan и отчёт для владельца/tech lead | Не начато |

# Police Stop — full contextual rebuild

| Задача | Статус |
|---|---|
| Зафиксировать JSON contract и baseline 7 уроков | Готово |
| Составить context map: roadside sequence, branches, register и purpose каждого урока | Готово |
| Переписать titles/subtitles/outcomes/prerequisites | Готово |
| Переписать все 7 stepsets и убрать неуместные passport/visa repeats | Готово: 7 stepsets / 56 items |
| Добавить права, документы на байк, шлем, пассажира, route, repair и receipt branches | Готово |
| Проверить Thai↔RU semantic alignment и tone-arrow phonetics | Tone-arrow/field validator готов; native review рекомендуется |
| Проверить лайфхаки, casual cards и отсутствие дублей вне контекста | Готово: 1 contextual tip per lesson, casual only in L3/L7, duplicate gate 0 unexpected |
| Запустить structural/educational/phonetic validators | Готово: custom validator 0 errors; Xcode/native content review next |
| Подготовить статистику и diff для tech lead review | Готово: lessons.json, steps.json, catalog diff |

# Тайский для жизни — category-wide contextual rebuild

| Задача | Статус |
|---|---|
| Зафиксировать scope L1–L15 и общий validation contract | Готово: 15 курсов / 104 урока |
| Пересобрать high-stakes L5/L6/L7/L9/L13/L14 | Готово: scenario contracts + contextual material pass |
| Пересобрать transactional L2/L3/L4/L8/L10/L12 | Готово: scenario contracts + contextual material pass |
| Пересобрать social/seasonal L11/L15 | Готово: social/safety contracts + casual cleanup |
| Сохранить Police Stop L1 в общий category diff | Готово: full 7-lesson rebuild |
| Запустить category-wide structural/content/duplicate/phonetic validators | Готово: structural 0, content 0, phonetic 0; duplicate notes documented |
| Создать один общий commit всех правок категории | Готово: `ea3b284` |
| Подготовить статистику и handoff tech lead | Готово: final_life_category_audit.txt |

# Housing rental course — card-by-card rebuild

| Задача | Статус |
|---|---|
| Зафиксировать baseline `course_l_13` и все 7 stepsets | Готово |
| Сопоставить урок → реальная housing situation → нужные branches | Готово |
| Проверить каждую card на Thai↔RU смысл и контекст | Готово: 63 cards reviewed, 4 targeted changes |
| Проверить phonetic tone arrows и casual/register | Готово: strict L validator 0 errors |
| Составить было→стало и заменить неуместные cards | Готово: housing_course_card_audit_ru.md |
| Запустить counts/duplicate/phonetic validators | Готово: counts 0, category 0, phonetic 0, Police regression 0 |
| Создать отдельный housing-course commit | Ожидает owner review |

# Delivery course — card-by-card rebuild

| Задача | Статус |
|---|---|
| Зафиксировать baseline `course_l_14` и все 7 stepsets | Готово |
| Проверить order → address → courier → payment → receipt → failure flow | Готово |
| Проверить каждую card на Thai↔RU смысл и delivery context | Готово: 63 baseline items reviewed |
| Проверить phonetic tone arrows и casual/register | Готово: strict L validator 0 errors |
| Переписать неуместные cards и добавить delay/damage/return branches | Готово: 9 targeted changes |
| Запустить counts/duplicate/phonetic validators | Готово: counts 0, category 0, phonetic 0, Police regression 0 |
| Оставить L14 uncommitted для общего category commit | Готово: остаётся в working tree |

# Full Thai for Life category review — remaining courses

| Задача | Статус |
|---|---|
| Зафиксировать порядок L7/L8/L9/L10/L11/L12/L2/L3/L4/L5/L6/L15 | Готово |
| Провести card-by-card review и rebuild L7/L8/L9/L10 | Готово: batch 1 |
| Провести card-by-card review и rebuild L11/L12/L2/L3 | Готово: batch 2 |
| Провести card-by-card review и rebuild L4/L5/L6/L15 | Готово: batch 3 |
| Сохранить уже проверенные L1/L13/L14 в общем working tree | Готово |
| Запустить category-wide semantic/structural/duplicate/phonetic validation | Готово: 0 errors; duplicate notes documented |
| Создать один общий commit всей категории | Готово: `feb0c8d` |
| Подготовить полный owner/tech-lead handoff | Готово: full_life_category_card_review_ru.md |

# Thai for Life — full native-aware methodology pass

| Задача | Статус |
|---|---|
| Зафиксировать honest baseline всех 15 курсов и общий scenario contract | Готово |
| Проверить L1 Police Stop card-by-card against native scenario | Готово / сохранён regression pass |
| Проверить L2 Taxi, L3 Market, L4 Food, L5 Pharmacy | Готово |
| Проверить L6 Hotel, L7 Beach, L8 Shop, L9 Emergency, L10 Gym | Готово |
| Проверить L11 Festivals, L12 Salon, L13 Housing, L14 Delivery, L15 Nightlife | Готово |
| Добавить недостающие Thai phrase cards, ответы, repair/safety/exit branches | Готово: L7 safety + L12 correction + existing branches |
| Проверить register, Russian gloss, casual, tips и Thai tone arrows | Готово: 854 phonetic records, 0 issues |
| Провести semantic completeness audit, а не только structural validator | Готово: 15/15 missing terms empty; 0 confirmed meta cards |
| Создать новый финальный category commit только после полного pass | Готово: `424d8b6` |

# Final current-state curriculum audit

| Задача | Статус |
|---|---|
| Определить актуальный commit range и production diff | Готово: cumulative diff от `95ffb64` |
| Проверить JSON loader contract и все 15 course records | Готово: 15/15 |
| Проверить 104 lessons, card counts и prerequisites | Готово: 0 mismatches / 0 missing prerequisites |
| Проверить semantic context, Thai↔RU glosses, casual и tips | Готово: scenario completeness 15/15; duplicate notes documented |
| Проверить strict tone arrows и duplicate/regression risks | Готово: 854/854 phonetics, Police regression 0 |
| Сформировать go/no-go заключение для tech lead | Готово: GO with native review caveat; squashed SHA `3f4e8a0` |

# Final handoff correction

| Задача | Статус |
|---|---|
| Подтвердить актуальное состояние: 15 курсов / 104 урока / 979 items | Готово |
| Подтвердить loader/count/prerequisite/phonetic/scenario checks | Готово: 0 structural errors, 0 phonetic issues, 0 missing scenario terms |
| Сформировать один squashed production curriculum commit из актуального baseline | Не начато |
| Передать tech lead точный SHA и честное go/no-go заключение | Не начато |

# Owner review table — Thai for Life materials

| Задача | Статус |
|---|---|
| Извлечь baseline/current lesson and card structure | Готово: baseline `95ffb64` vs current squashed |
| Составить was→now по всем 15 курсам | Готово |
| Указать ключевые added/removed/rewritten branches | Готово |
| Отдельно отметить места, где сохранились existing cards | Готово в пояснении к таблице |
| Сохранить компактную таблицу для owner review | Готово: `thai_for_life_was_now_owner.md` |

# Push Thai for Life final curriculum

| Задача | Статус |
|---|---|
| Проверить branch и HEAD `3f4e8a0` | Готово |
| Проверить рабочее дерево production files | Готово: production files clean |
| Push `agent/thai-life-final-curriculum` в origin | Готово |
| Проверить remote SHA и ссылку на branch | Готово: `3f4e8a025e81e213ffed82a9519c2c512cca8f37` |
| Передать tech lead handoff | Готово |

# Overlay UX/UI audit and liquid-glass redesign

| Задача | Статус |
|---|---|
| Инвентаризировать все информационные overlays, sheets, paywalls, limits, search и game states | Готово: 10 classes |
| Найти их routing/presenter и SwiftUI implementation points | Готово: OverlayPresenter, AppShell, HeaderOverlays, Speaker, Paywall, Search |
| Классифицировать состояния по UX-задаче и severity | Готово |
| Сформировать оставить/изменить/добавить matrix | Готово |
| Определить liquid-glass material, blur, hierarchy, motion и accessibility rules | Готово в audit report |
| Подготовить mockup scenario list до кодирования | Готово: 9 scenario groups |

# Overlay UI mockup slide deck

| Задача | Статус |
|---|---|
| Зафиксировать cover и design direction | Готово |
| Подготовить 9 scenario mockup groups | Готово |
| Сформировать CTA/copy/state rules для каждого group | Готово |
| Собрать visual references в liquid-glass/onboarding direction | Готово |
| Написать slide content outline | Готово |
| Сгенерировать slide deck и передать owner review | Готово: `manus-slides://HqFpM6vWBb9bzV6TFOEZXV` |

# Real Taika canvas mockups — before/after

| Задача | Статус |
|---|---|
| Зафиксировать реальные base screens из предоставленных screenshots и SwiftUI architecture | Готово |
| Подготовить before→after frame для Game Park empty/modes/locked | Готово |
| Подготовить before→after frame для attempts/paywall/search | Готово |
| Подготовить before→after frame для Speaker states/input | Готово |
| Подготовить before→after frame для Dictionary states/edit | Готово |
| Собрать Canvas-ready board с реальными mobile UI frames | Готово: `manus-slides://nYcnHxvERS6uFN6VwoWn2l` |

# Taika UI/UX epic — Scrum decomposition

| Задача | Статус |
|---|---|
| Зафиксировать epic goal, scope и non-goals | Готово |
| Разложить Liquid Glass / Continuous Canvas foundation | Готово |
| Определить reusable SwiftUI primitives и routing constraints | Готово |
| Классифицировать message surfaces и state taxonomy | Готово |
| Сформировать vertical slices: Game Park, Paywall, Search, Speaker, Dictionary | Готово |
| Определить priority, dependencies и sprint order | Готово |
| Написать acceptance criteria и Definition of Done | Готово |
| Подготовить первый sprint backlog | Готово |

# Synchronized UI/UX epic architecture audit

| Задача | Статус |
|---|---|
| Инвентаризировать актуальные Theme/AppDS/ThemeDesign files | Готово |
| Инвентаризировать OverlayPresenter/AppShell/HeaderOverlays routing | Готово |
| Инвентаризировать Speaker/Paywall/Search/Dictionary responsibilities | Готово |
| Сопоставить backlog items с конкретными symbols и files | Готово |
| Найти visual foundation duplication и ownership conflicts | Готово |
| Найти routing/state sync/accessibility gaps | Готово |
| Сформировать synchronized epic map и Sprint 0 backlog | Готово: `taika_ui_epic_synchronized_system_audit_ru.md` |

# Sprint 0 visual proof mockups

| Задача | Статус |
|---|---|
| Подготовить Speaker continuous-canvas foundation mockup | Готово |
| Подготовить Game Park shared GlassMessage mockup | Готово |
| Показать, что именно входит и не входит в Sprint 0 | Готово в deck |
| Передать Canvas-ready mockup board | Готово: `manus-slides://g2zHmbJtGpkDvdeDM0sUpS` |

# Figma-like UI component workspace

| Задача | Статус |
|---|---|
| Зафиксировать Sprint 0 component primitives и non-goals | Готово |
| Показать current→new material anatomy | Готово |
| Показать GlassMessage/Choice/Peek/Quota/Workbench/Paywall states | Готово |
| Показать usage examples на реальных Taika surfaces | Готово |
| Передать единый Canvas workspace без презентационного narrative | Готово: `/manus-storage/taika-real-canvas-workspace_a1e4a4ee.png` |

# Sprint 0 implementation — approved workspace spec

| Задача | Статус |
|---|---|
| Зафиксировать approved workspace spec и non-goals | Не начато |
| Реализовать overlay tokens в существующем Theme layer | Не начато |
| Переиспользовать текущие HeaderOverlays primitives без новой архитектуры | Не начато |
| Мигрировать material/stroke/blur на выбранные existing overlays | Не начато |
| Проверить отсутствие product-flow/routing/persistence changes | Не начато |
| Провести static validation и подготовить device review notes | Не начато |
| Создать локальный Sprint 0 commit без push | Не начато |
| Сформировать Sprint 1 scope после фактического diff | Не начато |

# Sprint 0 — Liquid Glass overlay foundation

| Задача | Статус |
|---|---|
| Зафиксировать approved workspace spec и non-goals | Готово |
| Реализовать overlay tokens в существующем Theme layer | Готово |
| Переиспользовать текущие HeaderOverlays primitives без новой архитектуры | Готово |
| Мигрировать material/stroke/blur на выбранные existing overlays | Готово: shared backdrop/card/CTA chrome |
| Проверить отсутствие product-flow/routing/persistence changes | Готово статически |
| Провести static validation и подготовить device review notes | Готово статически; Xcode build на Mac |
| Создать локальный Sprint 0 commit без push | В работе |
| Сформировать Sprint 1 scope после фактического diff | В работе |

# Sprint 1 — Speaker mockup workspace

| Задача | Статус |
|---|---|
| Зафиксировать реальные Speaker states и non-goals | Не начато |
| Собрать idle/listening/result/retry/error mockups | Не начато |
| Показать continuous-canvas anatomy и shared Sprint 0 primitives | Не начато |
| Сохранить continuity с `taika-component-workspace.png` | Не начато |
| Передать единый workspace image в Canvas без презентационного deck | Не начато |

# Sprint 1 — corrected Speaker translation flow

| Задача | Статус |
|---|---|
| Развести voice translation и pronunciation training как разные user stories | Не начато |
| Зафиксировать русский input → тайский output + русский транслит | Не начато |
| Не показывать pronunciation score в instant translation result | Не начато |
| Показать optional CTA для отдельной тренировки фразы | Не начато |
| Использовать существующую Taika card anatomy без тайского письма | Не начато |
| Перенести compact AI voice-agent motif из onboarding вместо большого waveform circle | Не начато |
| Пересобрать mockup и запросить approval до SwiftUI implementation | Не начато |

# Sprint 0 + Sprint 1 — user-visible delta mockup

| Задача | Статус |
|---|---|
| Сформулировать, что меняет только Sprint 0 | Не начато |
| Сформулировать, что добавляет только Sprint 1 | Не начато |
| Показать current → after на одном реальном Speaker screen flow | Не начато |
| Не использовать explanatory board, feature chips и mini-phone collage | Не начато |
| Передать mockup только после проверки понятности delta | Не начато |

# Sprint 1.1 — Speaker without persistent feed

| Задача | Статус |
|---|---|
| Проверить смысл текущей Speaker-ленты после появления My Dictionary | Не начато |
| Зафиксировать Speaker initial state как voice-agent ready state | Не начато |
| Убрать автоматическое хранение всех переводов в Speaker feed | Не начато |
| Оставить explicit save-to-dictionary action на result | Не начато |
| Развести Speaker history/temporary result и canonical My Dictionary ownership | Не начато |
| Сформулировать revised Sprint 1.1 scope и acceptance criteria | Не начато |

# Sprint 1.1 — Speaker Fast Translation implementation

| Задача | Статус |
|---|---|
| Найти текущую result-card и action «В ленту и словарь» | Не начато |
| Найти persistent feed/history ownership и Speaker save callback | Не начато |
| Убрать автоматическое сохранение, не ломая current result | Не начато |
| Перевести CTA на explicit save to My Dictionary | Не начато |
| Сохранить approved card anatomy и audio/copy/train actions | Не начато |
| Создать локальный commit без push | Не начато |
| Зафиксировать Sprint 2 scope | Не начато |

# Sprint 2 — Game Park mockup workspace

| Задача | Статус |
|---|---|
| Зафиксировать empty, mode picker, accessible и locked states | Не начато |
| Показать contextual peek вместо автоматического full-screen paywall | Не начато |
| Показать возврат в Game Park после close/Не сейчас | Не начато |
| Использовать реальные existing Game Park cards/modes без новой архитектуры | Не начато |
| Передать Canvas mockups без презентационного narrative | Не начато |

# Sprint 2 — Game Park implementation

| Задача | Статус |
|---|---|
| Найти текущий Game Park root/view и existing mode callbacks | Не начато |
| Найти существующие locked/PRO states и paywall entry points | Не начато |
| Реализовать empty state и course CTA поверх current view | Не начато |
| Реализовать mode picker с existing game modes | Не начато |
| Реализовать contextual locked peek без auto full-screen paywall | Не начато |
| Провести static validation и проверить return context | Не начато |
| Создать локальный Sprint 2 commit без push | Не начато |
| Зафиксировать Sprint 3 Quota + Paywall scope | Не начато |

# Sprint 3 — Quota + Paywall mockup workspace

| Задача | Статус |
|---|---|
| Показать вход в paywall из Game Park locked peek | Не начато |
| Показать единый quota state без противоречивых чисел | Не начато |
| Показать source-aware Paywall и selected plan | Не начато |
| Показать close/Не сейчас с возвратом в Game Park | Не начато |
| Отделить purchase intent от обычного locked tap | Не начато |
| Передать Canvas mockup без презентационного narrative | Не начато |

# Sprint 3 — Quota + Paywall implementation

| Задача | Статус |
|---|---|
| Найти existing paywall/plan/quota views и source context | Не начато |
| Проверить dismissal/return behavior для Game Park и Speaker | Не начато |
| Применить shared GlassQuota/GlassPaywall без новой RevenueCat architecture | Не начато |
| Сохранить existing prices/trial/legal/subscription callbacks | Не начато |
| Добавить recovery для purchase/restore errors без dead-end | Не начато |
| Провести static validation и создать локальный commit без push | Не начато |
| Зафиксировать Sprint 4 Search и remaining message groups | Не начато |

# Dictionary epic-boundary audit

| Задача | Статус |
|---|---|
| Проверить текущие Dictionary views/data/actions | Не начато |
| Проверить git history и наличие Dictionary commit в текущей ветке/remote refs | Не начато |
| Сопоставить фактическую реализацию с утверждённой standalone Dictionary UX | Не начато |
| Решить: оставить Dictionary в Sprint 4 или вынести в tech debt | Не начато |
| Зафиксировать consolidated epic commit/deployment strategy без push | Не начато |

# Overlay epic release-baseline migration

| Задача | Статус |
|---|---|
| Сопоставить local Sprint 0–3 commits с `origin/2026-01-21-k7hb-d2004` | Не начато |
| Не переносить local standalone Dictionary commits | Не начато |
| Перенести только overlay changes поверх release baseline | Не начато |
| Сверить Speaker save callback с production Dictionary API | Не начато |
| Собрать единый test candidate в этой же release branch без push | Не начато |

# Consolidated overlay epic test candidate

| Задача | Статус |
|---|---|
| Проверить baseline и epic diff | Не начато |
| Исключить production Dictionary replacement | Не начато |
| Squash overlay commits в один clean commit | Не начато |
| Проверить curriculum/P2 commits уже присутствуют в baseline/candidate | Не начато |
| Провести static validation и diff review | Не начато |
| Подготовить test branch и PR description | Не начато |
| Не выполнять production deploy | Не начато |

# Overlay compiler fix

| Задача | Статус |
|---|---|
| Проверить строку 144 `TaikaOverlayTokens.swift` и окружающий modifier | Не начато |
| Разбить сложное SwiftUI expression на локальные sub-expressions | Не начато |
| Проверить, что public API и visual output не изменились | Не начато |
| Создать fix commit в PR branch и push обновление | Не начато |
| Передать Xcode recheck instructions | Не начато |

# Follow-up compiler fix after merged overlay PR

| Задача | Статус |
|---|---|
| Проверить merged baseline и PR #9 merge result | Не начато |
| Создать отдельную fix branch от актуального baseline | Не начато |
| Перенести только GlassChoice type-check refactor | Не начато |
| Создать follow-up commit и PR | Не начато |
| Передать Xcode recheck instructions | Не начато |

# Post-epic visual reality audit

| Задача | Статус |
|---|---|
| Сверить merged PR diff с фактическим AppShell/header/body composition | Не начато |
| Проверить Speaker visual integration отдельно от Speaker behavior | Не начато |
| Проверить Game Park contextual peek и Paywall material на реальных surfaces | Не начато |
| Разделить implemented / partial / missing по каждому Sprint | Не начато |
| Определить visual integration follow-up без новой архитектуры | Не начато |

# Speaker Visual Integration Pass

| Задача | Статус |
|---|---|
| Найти Speaker root ZStack/background composition | Не начато |
| Найти header/body boundary modifiers и safe-area backgrounds | Не начато |
| Найти recording ready/listening/failed states | Не начато |
| Перевести root на continuous canvas без state-machine changes | Не начато |
| Применить compact onboarding-style voice-agent treatment | Не начато |
| Проверить result-card и existing actions remain intact | Не начато |
| Создать follow-up commit в epic test branch | Не начато |

# Branch handoff clarification

| Задача | Статус |
|---|---|
| Сверить `2026-01-21-k7hb-d2004` local/remote SHA | Не начато |
| Сверить `agent/overlay-epic-consolidated-test` local/remote SHA | Не начато |
| Проверить, где находится Visual Integration commit `159237d` | Не начато |
| Дать Xcode точную ветку для теста без создания лишней архитектурной ветки | Не начато |

# Existing release branch visual pass handoff

| Задача | Статус |
|---|---|
| Проверить отсутствие незакоммиченных tracked changes в release branch | Не начато |
| Перенести `159237d` в `2026-01-21-k7hb-d2004` | Не начато |
| Push только в существующую release/test branch | Не начато |
| Подтвердить конечный SHA для Xcode | Не начато |
| Не выполнять production deploy | Не начато |

# Visual integration root-cause audit

| Задача | Статус |
|---|---|
| Определить owning view для Game Park mode picker из скриншота | Не начато |
| Определить реальный dimmer/presentation layer overlay | Не начато |
| Сверить Speaker listening screen с actual branch/code path | Не начато |
| Найти источник header/body seam в runtime composition | Не начато |
| Не вносить новый visual patch до подтверждения owning views | Не начато |

# Corrective Game Park overlay path

| Задача | Статус |
|---|---|
| Проверить `OverlayEtalonBackground` implementation | В работе |
| Проверить `OverlayEtalonCard` implementation | В работе |
| Применить translucent context treatment к реальному Game Park path | Не начато |
| Не считать `GlassBackdrop`-only patch достаточным | Готово: path mismatch найден |
| Commit/push corrective patch в `2026-01-21-k7hb-d2004` | Не начато |

# Full overlay epic reality audit

| Задача | Статус |
|---|---|
| Сопоставить Speaker ready/listening/input overlay с owning views | Не начато |
| Сопоставить Game Park mode picker и его background/card layers | Не начато |
| Сопоставить Paywall runtime surface и detents | Не начато |
| Составить implemented/partial/missing matrix по Sprint 0–3 | Не начато |
| Зафиксировать, что не было сделано визуально | Не начато |
| Определить один корректный visual integration slice вместо микропатчей | Не начато |

# Full overlay epic — Visual Integration + Stability pass

| Задача | Статус |
|---|---|
| Зафиксировать Speaker/Game Park/Paywall runtime state inventory | Не начато |
| Убрать header/body seams на actual screen roots | Не начато |
| Устранить dusty/opaque background layers и duplicate dimmers | Не начато |
| Пересобрать actual Speaker input/listening/result composition | Не начато |
| Пересобрать Game Park sheet positioning and contextual recovery | Не начато |
| Проверить Paywall source/return/detent behavior | Не начато |
| Провести static validation и device QA matrix | Не начато |
| Создать consolidated follow-up commit в `2026-01-21-k7hb-d2004` | Не начато |

# Base material correction — dark continuous canvas

| Задача | Статус |
|---|---|
| Проверить AppHeader internal fill/background | Не начато |
| Проверить root canvas tint/glow и источник dusty gray field | Не начато |
| Проверить Speaker topChrome/content compositing | Не начато |
| Сделать header/body material visually continuous без opaque strip | Не начато |
| Убрать пыльный purple/gray veil, оставив controlled dark gloss | Не начато |
| Провести device-oriented visual acceptance и commit в той же ветке | Не начато |

# Speaker runtime owning-layer audit after bde2426

| Задача | Статус |
|---|---|
| Определить фактический root background, который даёт серый field | Не начато |
| Определить фактический header/body container, который даёт seam | Не начато |
| Проверить, не перекрывает ли runtime другой Speaker/AppShell view | Не начато |
| Сверить listening screenshot с конкретными modifiers и branch conditions | Не начато |
| Не коммитить новый token-only patch до подтверждения owning layer | Не начато |

# Category audit — На одной волне

| Задача | Статус |
|---|---|
| Инвентаризировать все E-courses/уроки/карточки категории | Не начато |
| Проверить scenario relevance для русскоязычных жителей Таиланда | Не начато |
| Проверить полноту ситуаций: вход, нормальный flow, failure branch, closure | Не начато |
| Проверить phrase/word/casual/slang usefulness и register | Не начато |
| Проверить transliteration и tone-arrow compliance | Не начато |
| Проверить progression и дубли между курсами | Не начато |
| Подготовить course-by-course verdict без commit | Не начато |


# Current UI fix — continuous glass seam + onboarding wave

| Задача | Статус |
|---|---|
| Найти реализацию header/body seam в AppShell и затронутых Speaker/overlay surfaces | Готово: AppHeader + TaikaLiquidGlassHeaderBackdrop |
| Найти неуместные diagram/chart elements и их rendering paths | Готово: Speaker tone graph/PRO placeholder |
| Убрать жёсткую линию через единый translucent blur/material transition | Готово в AppHeader |
| Заменить неуместные диаграммы на технологичную onboarding wave | Готово в Speaker breakdown и locked placeholder |
| Проверить Swift diff, доступные static/build checks и scope regressions | Static: git diff --check; swiftc недоступен в sandbox |
| Подготовить текущую release branch для device test без создания новой ветки | Готово: pushed `5961a7c` в `origin/2026-01-21-k7hb-d2004` |


# Follow-up diagnosis — commit 5961a7c visually unchanged

| Задача | Статус |
|---|---|
| Сопоставить экран на скриншоте с фактическими Speaker/AppShell render paths | Готово: screenshot = ShellHeaderHost + conversationLiveStage |
| Найти реальный источник горизонтального header seam | Готово: backdrop был ограничен AppHeader height |
| Найти реальный центральный waveform/diagram component | Готово: ConversationVoiceOrb + ConversationLiveWaveRibbon |
| Проверить, почему изменения 5961a7c не затронули наблюдаемый экран | Готово: был изменён breakdown overlay, а не live conversation screen |
| Исправить фактические слои в той же release branch | В работе: ShellHeaderHost + ConversationVoiceOrb |
| Проверить новый diff и передать device-test commit | Не начато |


# Follow-up — header content contrast regression

| Задача | Статус |
|---|---|
| Проверить, почему расширенный backdrop перекрывает заголовок и controls | Готово: backdrop был modifier-level и перекрывал content ordering |
| Сохранить blur ниже header без отдельной opaque полосы | В работе: explicit ZStack transition layer |
| Вернуть читаемую content zone для title/status/header controls | В работе: ShellHeaderHost zIndex(1) |
| Проверить новый diff и device-test handoff в той же ветке | Не начато |


# Completed-lessons-only Speaker selection regression

- [ ] Reproduce the StepView → Speaker lesson-selection path from commit 50ae26b.
- [ ] Confirm the current-course scope and completed lesson status source.
- [ ] Show only completed lessons in the selection UI.
- [ ] Prevent unavailable/uncompleted selection from falling back to the initial Speaker state.
- [ ] Validate navigation and push the fix to the test branch.


# Xcode CodeSign failure diagnosis

- [ ] Capture the full red CodeSign error from Xcode Report navigator.
- [ ] Separate signing/provisioning failure from Swift compile diagnostics.
- [ ] Inspect current valuesProgress code and latest branch diff for compiler issues.
- [ ] Provide exact remediation and rebuild steps.


# Xcode missing Swift Package products

- [ ] Inspect Package.swift/project.pbxproj package references and target product dependencies.
- [ ] Confirm RevenueCat and Firebase package resolution state.
- [ ] Restore package resolution and target linking without changing app architecture.
- [ ] Rebuild and verify CodeSign is only evaluated after dependencies resolve.


# LessonsView course hero picker refinement

- [x] Move the Lessons/Lifehacks picker into the existing course hero card.
- [x] Keep the picker as the only control that swaps the main course content carousel.
- [x] Replace the new hack card presentation with the existing StepView-style lifehack card treatment.
- [x] Preserve course scope, favorites, play action and lesson return navigation.
- [x] Remove duplicate standalone material/hacks section chrome.


# Post-lesson completion and smart resume pipeline

- [ ] Audit completed lesson card flip and existing post-lesson navigation actions.
- [ ] Define a concise reinforcement summary with next-action priority.
- [ ] Focus LessonsView on current in-progress lesson, otherwise next unstarted lesson.
- [ ] Update completed lesson card UI without changing lesson data architecture.
- [ ] Preserve favorites, games, speaker and course pinning actions.


# Unified post-lesson pipeline implementation

- [x] Implement smart resume focus for current in-progress or next lesson.
- [x] Preserve explicit deep-link and lesson context when returning from StepView.
- [x] Add completed-card flip summary with clear next-action hierarchy.
- [x] Reuse existing games, Speaker, favorites and lesson navigation actions.
- [x] Static-check and package all pipeline changes in one commit for branch testing.


# CourseLessonCard argument-order compile fix

- [x] Inspect initializer declaration and every call site for named-argument order.
- [x] Correct the completed-card call and scan for the same ordering issue elsewhere.
- [x] Run strict static checks and verify no unresolved new labels remain.
- [x] Create and push a corrective commit before sending a new test command.


# Lifehacks carousel visual parity

- [x] Match LessonsView lifehack card interior to the current StepView lifehack design.
- [x] Keep lesson-carousel card dimensions and depth treatment.
- [x] Remove oversized empty area while preserving readable hack text and actions.
- [x] Preserve play, favorite, course scope and existing navigation callbacks.
