# AudioRecall compile fix — round tuple и canonical key strings

| Задача | Статус |
|---|---|
| Добавить `lessonId` во все AudioRecallRound tuple assignments | Не начато |
| Исправить две незакрытые interpolated строки `normalizedCardKey` | Не начато |
| Проверить все AudioRecallRound references и diff | Не начато |

# Game 2 — свободная сборка слогов и корректное завершение раунда

| Задача | Статус |
|---|---|
| Найти причину повторного добавления карточек после завершения слоговой сборки | Не начато |
| Разделить current round, remaining queue и finished state | Не начато |
| Заменить прочерки на нативные индексированные слотовые targets | Не начато |
| Разрешить выбор любого слогового слота и заполнение не по порядку | Не начато |
| Сохранить existing Taika glass/gradient language без нового UI-паттерна | Не начато |
| Проверить wrong pick, reset, completed word и final overlay | Не начато |

# Lesson-level reinforcement aggregation — результат игры по урокам

| Задача | Статус |
|---|---|
| Сохранять source course/lesson для каждой карточки во всех reinforcement games | Не начато |
| Пересчитывать score, attempts и errors отдельно по каждому уроку | Не начато |
| Не показывать course-level 100% как замену lesson-level diagnostics | Не начато |
| Подключить lesson metrics к строкам зачётки и error focus | Не начато |
| Проверить mixed-lesson Audio/Recall flow и legacy metrics | Не начато |

# Games 2–3 — единый каноничный completion overlay

| Задача | Статус |
|---|---|
| Сравнить Match/Recall/AudioRecall completion overlay и фон | Не начато |
| Убрать отдельный AudioRecall final overlay, не использующий каноничный blur | Не начато |
| Свести заголовок, статистику, error CTA, Speaker и next game к единому компоненту | Не начато |
| Проверить Pro/non-Pro и ошибки в играх 2–3 | Не начато |

# Compile fix — GameCompletionActions argument order

| Задача | Статус |
|---|---|
| Переставить `onRepeat` перед `errorCount` в GameCompletionActions call site | Не начато |
| Проверить все вызовы GameCompletionActions после сигнатурного расширения | Не начато |
| Собрать и отправить точечный compile fix | Не начато |

# Diagnostics persistence — ошибки не доходят до grade sheet

| Задача | Статус |
|---|---|
| Проверить, что симулятор запускает актуальный commit и не показывает старый persisted snapshot | Не начато |
| Проследить failed-card запись из Match/Recall/Audio до ReinforcementStore | Не начато |
| Сверить canonical course/lesson/card keys между store и LessonsView | Не начато |
| Проверить notification refresh и cache invalidation после save | Не начато |
| Добавить исправление для race/identity/fallback и проверить fresh-progress сценарий | Не начато |

# Post-game reinforcement — один следующий шаг и единый card scope

| Задача | Статус |
|---|---|
| При ошибках показывать primary action «Повторить ошибки», а не обычный Repeat всего урока | Не начато |
| При успешном закреплении вести в следующее закрепление или следующий урок по контексту | Не начато |
| Передавать failed card scope из completion overlay в Speaker без повторного выбора курса/уроков | Не начато |
| Убрать три равноправные CTA и оставить один primary + тихое закрытие/secondary action | Не начато |
| Проверить Pro gate для следующего режима без потери текущего card scope | Не начато |

# LessonsView in-progress — убрать лишний reinforcement summary

| Задача | Статус |
|---|---|
| Не показывать game/reinforcement summary в основном блоке незавершённого курса | Не начато |
| Оставить в начатом курсе только учебный прогресс, материалы и следующий урок | Не начато |
| Показывать зачётку и targeted practice только после завершения курса | Не начато |

# Runtime delivery audit — почему правки не видны

| Задача | Статус |
|---|---|
| Сверить локальный HEAD и remote branch с коммитом, который должен тестироваться | Не начато |
| Проверить фактический LessonsView/CourseView/Game entry point и target membership | Не начато |
| Найти старые fallback-и, которые продолжают рисовать прежний UI | Не начато |
| Проверить runtime scope: selected lesson IDs, failed card keys и picker callbacks | Не начато |
| Собрать и отправить исправление только после подтверждения реального path | Не начато |

# Card-level error queue — targeted practice

| Задача | Статус |
|---|---|
| Аудировать игровые модели раундов и источники конкретных ошибочных карточек | Не начато |
| Добавить persisted failedCardKeys с canonical course/lesson/card identity | Не начато |
| Передавать error-card scope через GameRequestedCourseScope и picker | Не начато |
| Фильтровать Memory/Recall/Audio/Speaker только по error queue | Не начато |
| Удалять карточку из error queue после успешного повторного закрепления | Не начато |
| Проверить пустой режим, Pro gate и обратную совместимость с обычным закреплением | Не начато |

# Начатый курс — разделить обучение и закрепление

| Задача | Статус |
|---|---|
| Для незавершённого курса убрать формулировку «готов к закреплению» | Не начато |
| Показывать главным CTA следующий незавершённый урок | Не начато |
| Оставить reinforcement вторичным и не выдавать его за статус курса | Не начато |
| Сохранить полноценную зачётку и targeted practice только для завершённого курса | Не начато |

# Ошибки курса — scoped practice и спокойный signal

| Задача | Статус |
|---|---|
| Зафиксировать правило: «Ошибки» означает только диагностированные карточки из всех выбранных уроков курса | Не начато |
| Не сбрасывать weak-card scope при выборе конкретной игры | Не начато |
| Убрать крупный малиновый индикатор и оставить signal только внутри error row | Не начато |
| Развести выбор материала и выбор режима без повторного показа всех карточек урока | Не начато |
| Проверить прямой запуск scoped Memory/Recall/Speaker и Pro gate | Не начато |

# Общий коммит текущего рабочего дерева

| Задача | Статус |
|---|---|
| Проверить состав всех текущих изменений перед общим коммитом | Не начато |
| Собрать все изменения в один commit и push | Не начато |
| Передать точную команду обновления ветки в Xcode | Не начато |

# LessonsView — цельный сценарий ошибок и закрепления

| Задача | Статус |
|---|---|
| Убрать лоскутный малиновый error UI из grade sheet и описать ошибки как часть зачётки курса | Не начато |
| Сформировать один главный next step для пройденного курса: сначала ошибки, затем targeted practice, без конкурирующих CTA | Не начато |
| Перестроить визуальную иерархию: крупный результат курса, предметы зачётки, затем только релевантные уроки с диагностикой | Не начато |
| Сделать error state спокойным и технологичным в айдентике Taika, используя малиновый только как signal внутри строки/метрики | Не начато |
| Проверить состояния: ошибок нет, ошибки есть, выбранные ошибки, Pro и non-Pro | Не начато |
| Проверить, что Train Errors запускает targeted practice напрямую и не открывает лишний picker | Не начато |

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


# LessonsView discovery shuffle and retention state

- [ ] Define a non-repeating deterministic shuffle for lesson/hack section switches.
- [ ] Keep current in-progress lesson and explicit user selection stable across shuffle.
- [ ] Replace overloaded completed back face with a compact progress summary.
- [ ] Use one primary retention CTA and keep secondary utilities visually subordinate.
- [ ] Preserve course scope, favorites, reinforcement and next-lesson navigation.


# Simplified completion card and learned progress treatment

- [x] Replace overloaded completed back face with compact progress summary and primary CTA.
- [x] Add techno/glass completion treatment and explicit learned/completed indicator.
- [x] Keep current in-progress or next lesson focused after return/progress changes.
- [x] Preserve favorites, reinforcement, next lesson, Speaker and course scope.
- [x] Static-check and prepare one clean testable commit.


# LessonsView course action dock

- [ ] Audit current Итоги/Прогресс block and existing Speaker/Game Park actions.
- [ ] Design compact dock with current lesson context and clear primary actions.
- [ ] Preserve course progress metrics and existing access gates.
- [ ] Implement without duplicating dictionary or Speaker UI architecture.
- [ ] Validate navigation and prepare test handoff.


# Course Practice Dock implementation

- [x] Replace the lower Итоги/Прогресс dashboard with a compact practice dock.
- [x] Add context-aware Speaker course and Game Park entry cards.
- [x] Preserve existing navigation, access gates and current lesson context.
- [x] Keep detailed metrics as a secondary compact line.
- [x] Validate dock states and push one testable commit.


# LessonsView product revision: native quick actions

- [ ] Separate completed-card result from quick action navigation.
- [ ] Reuse Dictionary-style native action panel treatment for Speaker and Game Park.
- [ ] Remove next-lesson CTA and motivational/dashboard copy from completed card.
- [ ] Keep only explicit learned status and concise progress signal on the card.
- [ ] Define final UX contract before coding the revision.


# Approved LessonsView role separation implementation

- [x] Make completed-card back face proof-of-learning only, with no next-lesson CTA.
- [x] Replace lower Course Practice Dock dashboard with one Dictionary-style native quick-actions panel.
- [x] Keep Speaker/Game Park callbacks, gates and current lesson context intact.
- [x] Remove duplicate progress/statistics/action copy from the lower area.
- [x] Validate Swift references and ship one consolidated commit.


# Lesson grade summary and single action surface regression

- [ ] Remove the outer-plus-inner double frame from the quick action panel.
- [ ] Restore real lesson mastery statistics without recreating the old dashboard.
- [ ] Surface pronunciation average and reinforcement effectiveness only when real data exists.
- [ ] Add a compact «Зачёт по уроку» summary with clear hierarchy.
- [ ] Keep course progress in hero and quick actions in one native panel.


# Unified course and lesson mastery presentation

- [ ] Audit CourseView course-grade values against real lesson-level speaker and reinforcement data.
- [ ] Define one honest mastery contract for fully completed courses and lessons.
- [ ] Keep missing metrics explicit instead of inventing scores.
- [ ] Add a restrained glossy Taika-techno treatment to completed cards without hurting readability.
- [ ] Reuse the same mastery semantics and visual language in CourseView and LessonsView.


# Consolidated mastery flow implementation

- [ ] Wire real pronunciation and reinforcement metrics for course and lesson grade states.
- [ ] Add honest empty states and next-best actions for missing mastery data.
- [ ] Update CourseView course grade and LessonsView lesson grade consistently.
- [ ] Add premium Taika-techno waveform/halo treatment to completed surfaces.
- [ ] Remove duplicate quick-action chrome and ship one consolidated test commit.


# Instant Translation learning loop

- [ ] Audit instant translation states and existing Speaker navigation/data contracts.
- [ ] Define voice-reactive sphere behavior for listening, processing, result and ready-next.
- [ ] Add parallel Save to Dictionary and Train Now actions.
- [ ] Keep phrase context after save and support continuous next-phrase capture.
- [ ] Validate translation, dictionary persistence and training handoff.


# Instant Translation loop implementation

- [ ] Connect smoothed voice feedback to the recording sphere.
- [ ] Separate listening and processing visual states.
- [ ] Add Train Now beside Save to Dictionary on result state.
- [ ] Keep result visible after save and show saved status.
- [ ] Add next-phrase capture without resetting the Speaker flow.
- [ ] Validate dictionary persistence and training handoff before handoff.


# Home daily warmup retention entry point

- [x] Audit current warmup button time-based fill and motion hooks.
- [x] Keep warmup visually stable regardless of time remaining.
- [x] Add restrained lightning pulse to the warmup icon.
- [x] Add rotating value-oriented copy inside the button.
- [x] Preserve daily availability state, accessibility and reduced-motion behavior.


# Favorites compact practice actions

- [ ] Audit Favorites Speaker/Games actions against DictionarySoftActionLabel.
- [ ] Replace large competing CTA buttons with a compact secondary action rail.
- [ ] Keep saved materials and My Dictionary as the visual priority.
- [ ] Preserve card/list mode, filters, Speaker and Games navigation.
- [ ] Validate accessibility and prepare a focused test commit.


# LessonsView learned cards and selected practice scope

- [ ] Give fully completed lessons a premium learned-state treatment with clear achievement signal.
- [ ] Add a compact expandable chip for selecting completed lessons to practice.
- [ ] Keep unfinished lessons out of the selection list.
- [ ] Route selected completed lessons to Speaker and Game Park using existing contracts.
- [ ] Preserve course scope, favorites, card/list modes and navigation.


# Consolidated CourseView LessonsView Favorites UX pass

- [ ] Audit shared mastery, completion and action contracts across all three screens.
- [ ] Unify real course/lesson mastery semantics and honest empty states.
- [ ] Add premium learned cards and completed-only practice selection in LessonsView.
- [ ] Align CourseView grade card with the same mastery language and visual treatment.
- [ ] Reduce Favorites Speaker/Games controls to compact Dictionary-style actions.
- [ ] Validate cross-screen callbacks, accessibility and argument order before one consolidated commit.


# Warmup single-slot micro-UX correction

- [x] Keep warmup title and explanatory copy in one centered slot, never simultaneously.
- [x] Animate the copy transition from the center with stable button geometry.
- [x] Remove lightning glow/container and retain icon-only motion.
- [x] Check clipping, spacing and reduced-motion behavior.
- [ ] Create and push a corrective commit with one test command.


# Lessons completed selection handoff correction

- [ ] Preserve current focused lesson separately from selected reinforcement lessons.
- [ ] Allow selecting multiple completed lessons without changing the visible lesson card.
- [ ] Route the selected lesson set only after explicit Speaker or Games action.
- [ ] Keep uncompleted lessons out of the selection queue.
- [ ] Remove the remaining divider/line and strengthen learned-card visual treatment.
- [ ] Run static wiring checks and create one corrective commit.


# Speaker voice flow correction

- [ ] Separate instant translation from explicit pronunciation training states.
- [ ] Make the compact voice-reactive sphere the only visual hero during listening and processing.
- [ ] Prevent background translation/training cards from showing through active recording and analysis states.
- [ ] Restore score-first gate before syllable/rhythm breakdown.
- [ ] Replace unbounded training ribbon with a capped phrase-history carousel and deterministic tap-to-resume behavior.
- [ ] Validate state transitions and push one Speaker corrective commit.


# Favorites compiler diagnostic retry

- [ ] Replace FavInsetGroup body with explicit compiler-safe typed surface and overlay helpers.
- [ ] Re-run static checks and push a follow-up fix for FavoriteTabContent.swift:289.


# Favorites compiler diagnostic retry 2

- [ ] Remove ambiguous expression at FavoriteTabContent.swift:294 with explicit non-opaque helper composition.
- [ ] Run static checks and push the final compiler fix.


# LessonsView compiler fixes

- [ ] Fix optional String arguments at LessonsView lines 513 and 707.
- [ ] Restore explicit navigation bar visibility modifier at LessonsView line 800.
- [ ] Run static checks and push LessonsView build-fix commit.


# CourseView learned card visual correction

- [ ] Replace completed course mauve tint with jungle-green glass treatment.
- [ ] Remove or heavily suppress visible residual techno-line strokes on completed course cards.
- [ ] Preserve mastery metrics, card actions and carousel geometry.
- [ ] Run static checks and push corrective CourseView/CardDS commit.


# Speaker phrase chip rail correction

- [ ] Replace large history cards in the main Speaker surface with compact Main-style phrase chips.
- [ ] Keep the sphere as the only central hero during idle, recording and translation states.
- [ ] Preserve capped history and tap-to-resume behavior through the chips.
- [ ] Run static checks and push a Speaker UI corrective commit.


# Favorites mockup proof

- [ ] Create faithful list-mode mockup with unified action rail and adaptive filter logic.
- [ ] Create faithful grid-mode mockup with the same header hierarchy.
- [ ] Deliver both mockup images for approval before coding.


# Favorites canvas mockups

- [ ] Initialize a two-page Favorites mockup canvas: List mode and Grid mode.
- [ ] Create both pages with exact current Taika labels and proposed control hierarchy.
- [ ] Present the canvas directly in the UI.


# Consolidated visual fix: Favorites, CourseView, LessonsView

- [ ] Align Favorites header controls, action rail, filters and content to one strict spacing grid.
- [ ] Apply one jungle-green learned surface to completed CourseView and LessonsView cards.
- [ ] Remove mauve dust and decorative line artifacts from both completed-card paths.
- [ ] Preserve mastery metrics, carousel geometry and existing actions.
- [ ] Run static checks and push one consolidated visual commit.


# Speaker canonical Main sphere

- [ ] Reuse the exact Main speaker sphere component and visual scale in Speaker.
- [ ] Map idle, listening and processing states to the canonical sphere states.
- [ ] Keep phrase chips secondary and preserve tap-to-resume behavior.
- [ ] Run static checks and push one canonical-hero commit.


# Speaker reactive sphere

- [ ] Pass the live recording meter into the shared MDVoiceSphere.
- [ ] Keep Main idle sphere visually unchanged while Speaker listening reacts to meter.
- [ ] Animate rings/core/wave intensity from live voice level with reduced-motion fallback.
- [ ] Verify listening, idle and processing states and push one corrective commit.


# Organic learned card treatment

- [ ] Remove solid green completed-card wash that lowers text contrast.
- [ ] Add restrained vine-like organic wave paths and localized glow inside completed cards.
- [ ] Animate the organic treatment slowly, with reduced-motion fallback.
- [ ] Keep mastery metrics, icons, card dimensions and actions unchanged.
- [ ] Push one organic learned visual commit after static validation.


# Speaker idle hero fix

- [ ] Render canonical MDVoiceSphere immediately in idle/empty Speaker state.
- [ ] Keep phrase chips secondary and preserve Instant Translation CTA.
- [ ] Verify idle, listening, processing and result branches.
- [ ] Push one idle Speaker corrective commit.


# Learned-state clarity refinement

- [ ] Tint completed progress rail green without changing in-progress rails.
- [ ] Add explicit completed status/check language and green mastery accent.
- [ ] Strengthen organic wave layers and localized depth while keeping text area clean.
- [ ] Verify completed/in-progress contrast and push one refinement commit.


# Favorites simplified action hierarchy

- [ ] Remove category filter rail from Favorites.
- [ ] Move Speaker and Games below saved materials in one row.
- [ ] Match Dictionary dark action style exactly in list and grid modes.
- [ ] Validate existing filter/data interactions are not broken and push one commit.


# Completed card hierarchy refinement

- [ ] Remove mastery metrics rail from completed card face.
- [ ] Keep pronunciation/reinforcement metrics available on the completed back face.
- [ ] Make completed status dark glossy with explicit green check/accent.
- [ ] Keep green progress signal and soften pink to atmospheric/global-only role.
- [ ] Validate face/back contrast and push one refinement commit.


# Instant Speaker structured training continuation

- [ ] Preserve RU/Thai/transliteration context after translation.
- [ ] Replace generic standalone score overlay with in-card training result state.
- [ ] Restore explicit score-first then tone/syllable breakdown sequence.
- [ ] Keep Repeat, Save, Train/Next actions inside the same Instant Speaker context.
- [ ] Verify classic breakdown data is reused without a second unrelated pipeline.


# Speaker clean-start state

- [ ] Hide phrase chips in initial idle before first translation result.
- [ ] Keep canonical techno-AI sphere as the only central hero.
- [ ] Add concise ready-to-listen copy without a second competing card.
- [ ] Restore chips only after a conversation result exists.
- [ ] Validate idle-to-recording-to-result transitions and push one cleanup commit.

# Course mastery synchronization

- [ ] Audit Game Park completion/result persistence and lesson/course mastery readers.
- [ ] Separate material completion from pronunciation reinforcement in the shared model.
- [ ] Map matched game cards back to source lesson cards without inflating or zeroing unrelated lessons.
- [ ] Show course-level green completion state in the top description card.
- [ ] Show reinforcement count and a useful CTA for weak/unpracticed cards.
- [ ] Keep lesson cards and course summary mutually consistent after returning from Game Park.
- [ ] Validate with static grep/diff and create one branch commit.

# Green mastery / black actions visual pass

- [ ] Use jungle-green for Taika brand chip and completed/mastery status.
- [ ] Remove pink from completed-state semantic labels, progress and flip-back actions.
- [ ] Use black glossy glass buttons for Speaker and Game Park actions.
- [ ] Use the same black glossy treatment for card flip actions.
- [ ] Add native press feedback without introducing new decorative borders or pink glow.
- [ ] Keep pink only where it remains a non-semantic brand accent outside completed/action states.

# Epic: Course–Game Mastery Sync

## Scope

- [x] Define one source-card identity contract: courseId, lessonId, card/step index, game session id, result type and score.
- [x] Audit every Game Park mode that can be launched from a course or lesson.
- [x] Persist matched source cards at game completion; never mark unrelated cards or the entire course by inference.
- [x] Separate material completion from reinforcement/pronunciation mastery.
- [x] Extend unified mastery aggregation for lesson and course summaries.
- [x] Recalculate course and lesson status immediately after returning from Game Park.
- [x] Add course-header green completion status and reinforcement summary.
- [x] Add lesson-level source/status treatment for cards encountered in Game Park.
- [x] Add useful CTA for weak cards that preserves course/lesson context.
- [x] Update completed-card back face with game coverage, average pronunciation and remaining work.
- [x] Keep pink out of completed semantic states and use black glossy action controls.
- [ ] Validate partial game, full game, mixed lesson selection, repeat sessions and empty states.
- [ ] Run static validation, inspect diff, create one consolidated commit and push current branch.

# Corrective compile fix

- [ ] Replace inaccessible CDLearnedCardTokens reference in AppDS.swift with an accessible jungle-green token.
- [ ] Run diff/static validation and push corrective commit to 2026-01-21-k7hb-d2004.

# CardDS corrective compile fix

- [ ] Replace all CardDS references to inaccessible CDLearnedCardTokens with accessible mastery token.
- [ ] Resolve TaikaWordmarkLockup Color versus LinearGradient/AnyShapeStyle mismatch.
- [ ] Reorder glossyBlackSurface argument before onLockedTap at CardDS callsites.
- [ ] Run static validation and push corrective commit to 2026-01-21-k7hb-d2004.

# Simulator build validation

- [ ] Check whether Xcode, xcodebuild, simctl and an iOS project/scheme are available in the current environment.
- [ ] Run the strongest available build/test validation without claiming Simulator success if unavailable.
- [ ] Report exact build/test status and Mac command if external simulator is required.

# Speaker canonical sphere layout

- [ ] Find and remove the oversized idle microphone composition.
- [ ] Keep one reduced onboarding-style MDVoiceSphere centered across idle/recording/processing.
- [ ] Drive sphere motion from recordingMeter without moving the hero vertically.
- [ ] Validate idle-to-recording-to-result layout continuity and push one commit.

# Course/Lessons performance and completion state

- [ ] Find why completed course/lesson cards render flipped on first appearance.
- [ ] Keep completed cards green on the front; show course grade sheet only after explicit flip/tap.
- [ ] Verify all Speaker/Game/favorite/flip hit targets are aligned and tappable.
- [ ] Identify expensive body recomputations, unstable arrays and broad animations in CourseView/LessonsView.
- [ ] Run static validation and push one corrective commit.

# LessonsView course summary integration audit

- [ ] Inspect persisted ReinforcementStore records and verify whether the prior match contains source-card keys.
- [ ] Trace actual LessonsView header card data path and why game score/coverage is absent.
- [ ] Show completed course/game state and matched versus remaining cards in the upper course card.
- [ ] Add a clear personalized work-on-errors action without requiring a blind replay.
- [ ] Preserve a fallback message for legacy matches that cannot be mapped to source cards.

# Compact course actions and perceived performance

- [ ] Replace large square glossy Game/Speaker controls on course cards with compact inline dark-glass icon actions.
- [ ] Preserve green icon semantics and native press feedback without oversized containers.
- [ ] Inspect heavy card overlays/animations and remove unnecessary full-card invalidation.
- [ ] Run static validation and push one corrective commit.

# Speaker host layout corrective fix

- [ ] Locate the parent layout that still renders the microphone at the top in idle.
- [ ] Route idle, recording and processing through one centered live sphere composition.
- [ ] Remove duplicate microphone/hero host rather than only resizing the sphere.
- [ ] Validate no vertical jump and push a corrective commit.

# Course metric typography

- [ ] Audit all large numeric metrics in CourseView and shared course statistic components.
- [ ] Use a restrained technological numeric face with tabular/monospaced digits and controlled tracking.
- [ ] Preserve readability and hierarchy while removing decorative editorial number styling.
- [ ] Run static validation and push one typography commit.

# Lessons header initializer compile fix

- [ ] Move selectedIndex before isCompletedCourse at LessonsView LSLessonHeader callsite.
- [ ] Run diff check and push corrective commit.

# Lessons header onTapSlot argument order

- [ ] Move onTapSlot before isCompletedCourse at the current LSLessonHeader callsite.
- [ ] Run diff check and push corrective commit.

# LessonsDS progress compile fix

- [ ] Make progress slot Group/ViewBuilder concrete around line 419.
- [ ] Make horizontal alignment/context explicit around line 457.
- [ ] Run diff check and push corrective commit.

# LSProgressStrip initializer compatibility

- [ ] Add backward-compatible isCompletedCourse parameter to the active LSProgressStrip initializer.
- [ ] Run diff check and push corrective commit.

# Speaker liveStage compile fix

- [ ] Replace stale liveStage reference in conversationWidgetStateKey after idle host unification.
- [ ] Run diff check and push corrective commit.

# Lessons numeric typography audit

- [ ] Audit large numbers and percentages in LessonsView and LessonsDS.
- [ ] Replace remaining decorative/rounded metric fonts with shared technical metric style.
- [ ] Keep labels and educational copy readable; do not change hierarchy unrelated to metrics.
- [ ] Run static validation and push one typography corrective commit.

# Final completed course card flow

- [ ] Completed front: remove redundant 100% progress copy and keep only clear green completion status.
- [ ] Completed front: keep game/speaker actions green and favorite pink only; avoid oversized visual emphasis.
- [ ] Completed back: remove redundant Taika label and rebuild as a concise course grade sheet.
- [ ] Completed back: use neutral-light metric values, one useful reinforcement CTA, and no duplicate action row.
- [ ] Run static validation and push final CourseView card-flow commit.

# Final LessonsView retention flow

- [ ] Completed course header: replace lesson check slots/description with training status and compact effectiveness summary.
- [ ] Surface real matched/error-practice signals from game/pronunciation data when available.
- [ ] Completed lesson cards: use same green mastery language and show useful next-practice state.
- [ ] Replace large lower action buttons with line-style Speaker/Game actions and one clear retention CTA.
- [ ] Include concise Taika FM guidance without duplicating course card content.
- [ ] Run static validation and push final LessonsView retention commit.

# CourseView completed card usage context

- [ ] Find the canonical application/use-case field in course JSON.
- [ ] Thread application line into CourseView card model with safe fallback.
- [ ] Make completed status explicit as green status-only treatment.
- [ ] Add compact native card navigation affordance without a new button row.
- [ ] Run static validation and push CourseView refinement commit.

# LessonsView — completed course training UX refinement

- [ ] Зафиксировать роли экрана: курс пройден, текущая цель — тренировка и закрепление.
- [ ] Упростить верхний completed summary: зелёный mastery-state, эффективность, ошибки и одна понятная рекомендация.
- [ ] Убрать ощущение одиночного dropdown и сделать multi-select уроков с явными selected states.
- [ ] Разделить действия: «Закрепить в Спикере» и «Повторить в игре» должны работать по выбранному набору материалов.
- [ ] Перестроить нижнюю панель в компактный native action rail с понятным количеством выбранных уроков.
- [ ] Синхронизировать ошибки/метрики из ReinforcementStore с подсветкой уроков.
- [ ] Сохранить completed-карточки зелёными, без розовых completion accents; розовый оставить только для favorite.
- [ ] Проверить, что стартовый фокус и переходы не сбрасываются на первый урок.
- [ ] Выполнить статическую проверку diff и подготовить consolidated commit после согласованной реализации.

# LessonsView — approved implementation scope

- [ ] Перевести полностью пройденный курс в единый completed-training режим с jungle-green visual hierarchy.
- [ ] Перестроить header summary вокруг закрепления, ошибок и следующего действия.
- [ ] Реализовать multi-select по пройденным урокам вместо одиночного выбора через dropdown.
- [ ] Связать выбранный набор одинаково с Speaker и Game Park handoff.
- [ ] Добавить быстрый выбор уроков с ошибками и явный selected count.
- [ ] Перестроить нижнюю action panel в компактный native action rail.
- [ ] Синхронизировать per-lesson covered cards, sessions и scores из ReinforcementStore.
- [ ] Сохранить текущий lesson focus при возврате из тренировки и не стартовать на первой карточке без причины.
- [ ] Проверить все связанные Swift callsites и подготовить один consolidated commit в `2026-01-21-k7hb-d2004`.

# CourseView — completed achievement and retention correction

- [ ] Сделать completed course front-face визуально очевидным достижением, а не только статусным чипом.
- [ ] Развести green affordances по состояниям: незавершённые карточки не должны получать completed green status/arrow treatment.
- [ ] Создать premium jungle-green gradient treatment по аналогии с pink gradient, но без розового completion accent.
- [ ] Пересобрать back face как retention grade sheet: результат, ценность закрепления, конкретная рекомендация и компактные CTA.
- [ ] Проверить, что flip стартует с front face и state-dependent navigation не ломается.
- [ ] Выполнить static validation, commit и push в `2026-01-21-k7hb-d2004`.

# LessonsView compiler validation follow-up

- [ ] Сверить полную фактическую сигнатуру `LSLessonReels` с production callsite.
- [ ] Проверить все `LSLessonReels` вызовы, включая trailing-closure overload и preview callsites.
- [ ] Проверить связанные `CourseLessonCard`/`HomeTaskView` initializer argument orders.
- [ ] Запустить доступный комплексный static parse/diff validation и не push при найденных ошибках.
- [ ] Запушить только после подтверждения полного порядка аргументов.

# Persistent Xcode LSLessonReels error investigation

- [ ] Проверить локальный HEAD, remote HEAD и отсутствие незапушенных изменений.
- [ ] Найти все `LSLessonReels` declarations, extensions, overloads и duplicate source files.
- [ ] Сравнить Xcode-reported line 1314 с актуальным target-visible source и git blob.
- [ ] Исправить первопричину, а не только переставить аргументы в одном callsite.
- [ ] Выполнить комплексную static validation и сообщить точный branch/commit.

# Target-visible LSLessonReels source mismatch

- [ ] Проверить все `LessonsView.swift` в workspace/project и возможные symlink/generated copies.
- [ ] Проверить `taika.xcodeproj/project.pbxproj` и file references для LessonsView/LessonsDS.
- [ ] Сравнить declaration order, callsite order и фактический target source path.
- [ ] Не считать fix завершённым до подтверждения единственного компилируемого source.

# CardDS retention CTA compiler follow-up

- [ ] Сверить тип `onBackSelectGameMode` в `CourseLessonCard` и ошибочный вызов на строке 3346.
- [ ] Найти все `onBackSelectGameMode` assignments/calls и проверить их argument shape.
- [ ] Исправить только closure invocation, сохранив retention flow.
- [ ] Выполнить `git diff --check` и push только после проверки всех callsites.

# CourseView readability visual correction

- [ ] Сделать completed status badge светлым, контрастным и achievement-like.
- [ ] Осветлить зелёный mastery treatment, чтобы он не поглощал текст и иконки.
- [ ] Пересобрать back-face metrics с крупными светлыми monospaced values.
- [ ] Сделать retention CTA визуально главным и явно объяснить действие.
- [ ] Проверить contrast, CTA и static diff перед push.

# Completed LessonsView redesign pass

- [ ] Сжать верхний completed course summary до компактного training header.
- [ ] Перевести всю страницу completed mode, включая header controls/status accents, в единый jungle-green system.
- [ ] Убрать лишние зелёные рамки вокруг lesson cards; оставить green только для selected/mastery signals.
- [ ] Сделать единый читаемый status treatment на header, card front и card back.
- [ ] Сделать нижнюю training panel главным героем: selected count, ошибки, Speaker и Game Park.
- [ ] Проверить, что выбор нескольких уроков не выглядит как одиночный dropdown и handoff сохраняет набор.
- [ ] Выполнить static validation и consolidated push.

# Completed LessonsView dashboard redesign

- [ ] В completed mode заменить lesson carousel на главный training dashboard.
- [ ] Окрасить весь LessonsView content region от header до toolbar boundary в единый jungle-green surface.
- [ ] Сделать один канонический achievement chip для front и back card faces.
- [ ] Вынести reinforcement statistics и next-step recommendation в центральный hero block.
- [ ] Перенести уроки вниз в компактный структурированный список с понятными selection states.
- [ ] Сделать быстрые действия Speaker/Game Park частью главного training hero/dock, а не вторичным блоком.
- [ ] Сохранить multi-select и одинаковый selected scope для обоих handoffs.
- [ ] Выполнить static validation и consolidated push после полного dashboard pass.

# Quiet Taika FM-first completed LessonsView refinement

- [ ] Вернуть Taika FM context block в completed mode с новым retention-сообщением.
- [ ] Упростить зелёный canvas: убрать ощущение сплошного bright UI-kit и оставить глубокий jungle surface.
- [ ] Сжать hero: одна главная метрика, короткая рекомендация, вторичные stats без дублирования.
- [ ] Перенести быстрые действия в строгий native action rail с одним зелёным акцентом на active state.
- [ ] Сделать список уроков визуально нейтральным, с green только для selected/error indicators.
- [ ] Синхронизировать global header и body green surface, не окрашивая toolbar.
- [ ] Проверить density, contrast, selection handoff и static compile surface перед push.

# LessonsView to Speaker reinforcement routing fix

- [ ] Найти текущий destination для `SpeakerRequestedCourseId` и причину открытия Instant Translation.
- [ ] Разделить reinforcement flow и Instant Translation route/state.
- [ ] Передавать courseId и выбранные lessonIds в Speaker reinforcement carousel.
- [ ] Проверить возврат из Speaker и сохранение source context.
- [ ] Выполнить static validation и push routing fix.

# Unified completed course training block

- [ ] Объединить course title/header и reinforcement dashboard в одну completed-training surface.
- [ ] Убрать повторяющийся `КУРС ПРОЙДЕН` badge из dashboard; статус выражается зелёным active state и copy закрепления.
- [ ] Оставить один компактный Taika FM context внутри объединённого блока.
- [ ] Перенести stats и Speaker/Game Park CTA в единый понятный reinforcement section.
- [ ] Вернуть global header background к нейтральному liquid-glass фону; зелёными оставить только header controls в completed mode.
- [ ] Проверить вертикальную плотность, hierarchy и static compile surface перед push.

# Final LessonsView retention loop pass

- [ ] Вернуть переключение `Уроки / Лайфхаки` внутри курса для completed и обычного статуса.
- [ ] Показывать лайфхаки курса в существующем carousel/reels представлении без новой архитектуры.
- [ ] Добавить per-lesson error count или понятный no-diagnostics state в strict lesson list.
- [ ] Развести старые курсы без reinforcement history и новые курсы с реальными ошибками.
- [ ] Перевести Speaker/Game Park CTA в знакомый Taika line-style и усилить reinforcement result hierarchy.
- [ ] Проверить disabled state, selected scope, empty state, list mode и lifehacks mode.
- [ ] Выполнить static validation и consolidated push.

# Final course grade-sheet UX pass

- [ ] Убрать зелёную горизонтальную линию между FM/materials и зачёткой курса.
- [ ] Убрать повторы `закрепление`, `тренировка курса`, `закрепление навыка` и оставить одну ясную формулировку результата.
- [ ] Перестроить hero как зачётку: итог, интерпретация результата, evidence и следующий шаг.
- [ ] Сохранить только необходимые метрики и сделать их визуально и методически объяснимыми.
- [ ] Сохранить Speaker/Game Park и лайфхаки, но не давать им конкурировать с результатом.
- [ ] Проверить no-diagnostics, errors, selected scope и compact density.
- [ ] Выполнить static validation и consolidated push.

# Skill grade sheet visual refinement

- [ ] Вынести название курса из completed hero в page subtitle под header.
- [ ] Представить закрепление как ведомость навыков: Speaker pronunciation/tones и игровые режимы с отдельными результатами.
- [ ] Не показывать придуманные цифры: использовать реальные byMode averageScore/sessions, а при отсутствии — понятный pending state.
- [ ] Заменить flat green surface на jungle wave lines, deep green base и soft celestial/mint highlight.
- [ ] Убрать лишние labels и дубли, оставить один главный next step по каждой skill row.
- [ ] Сохранить лайфхаки, ошибки, selected scope и disabled states.
- [ ] Выполнить static validation и consolidated push.

# CourseView status-pill final audit

- [ ] Найти текущий `КУРС ПРОЙДЕН` front badge и back-face status treatment.
- [ ] Сверить geometry/gradient/typography с `Начать` pill.
- [ ] Сделать front status `КУРС ПРОЙДЕН`, back status `ЗАКРЕПЛЕНИЕ` в одном каноническом component style.
- [ ] Проверить state-dependent arrows, play/game/speaker actions и application line.
- [ ] Убедиться, что незавершённые карточки не получают completed green affordances.
- [ ] Выполнить static validation, commit и push.

# LessonsView visual reset

- [ ] Сохранить текущую стрелку назад и выровнять название курса по правой стороне верхней строки.
- [ ] Убрать тяжёлую зелёную заливку hero и оставить neutral card surface с тонкими jungle-wave линиями.
- [ ] Уменьшить opacity/contrast waves, чтобы они не пересекали текст и результаты.
- [ ] Перестроить skill rows в читаемую двухзонную структуру: название/назначение слева, score/status/action справа.
- [ ] Убрать truncation и диагональное визуальное смещение в результатах.
- [ ] Проверить density, action affordances и static compile surface перед push.

# CourseView completed card follow-up

- [ ] Проверить, где CourseView собирает лицевую и оборотную стороны completed course card.
- [ ] Найти существующий Start/status pill primitive и использовать одну и ту же визуальную грамматику для «КУРС ПРОЙДЕН» и «ЗАКРЕПЛЕНИЕ».
- [ ] Убрать из completed face вторичные цифры и перегруз, оставить achievement, title и понятные быстрые действия.
- [ ] Пересобрать back как короткую follow-up карточку: результат, следующая цель, CTA в Speaker/Game Park или LessonsView.
- [ ] Устранить lineLimit/truncation в ключевых status, score и CTA текстах.
- [ ] Проверить CourseView ↔ LessonsView navigation scope и выполнить static validation перед push.

# LessonsView grade-sheet final refinement

- [ ] Сделать три верхние метрики одной ровной строкой одинаковой ширины, как строка результатов выше.
- [ ] Увеличить score/status справа в skill rows и зарезервировать широкую колонку, чтобы «нет результата» не переносилось по буквам.
- [ ] Для доступной игровой skill row открывать уже определённый game mode напрямую, без повторного picker.
- [ ] Для платной игры показывать crown/PRO affordance и открывать Taika Pro/paywall flow вместо запуска или picker.
- [ ] Проверить, что существующий speaker routing и selected lesson scope не изменились.
- [ ] Выполнить static validation на overflow, call-site types и navigation regressions.

# Exact Start-style completed status

- [ ] Использовать canonical Start capsule как единственный источник геометрии status chip.
- [ ] Убрать отдельный monospaced status style и отдельные размеры/padding у CDCourseStatusPill.
- [ ] Сохранить только заменяемые content-параметры: icon, title и direction arrow.
- [ ] Применить одинаковую capsule на лицевой стороне «КУРС ПРОЙДЕН» и на обороте «ЗАКРЕПЛЕНИЕ».
- [ ] Проверить exact font, padding, fill, shadow и PressDownStyle against Start button.

# Completed course back flow: Speaker + three game modes

- [ ] Передать из CourseView отдельный reinforcement Speaker entry point, а не обычный Speaker/Instant Translation route.
- [ ] Сохранить courseId и selected lesson scope при входе в Speaker reinforcement.
- [ ] Заменить прямой запуск match из course card back на native dock с match, recall и audioRecall.
- [ ] Free match должен запускаться direct; paid modes должны показывать crown и «Открыть Taika Pro».
- [ ] Не показывать повторный общий picker после выбора режима в dock.
- [ ] Проверить закрытие dock, gameType и lesson scope на всех трех режимах.

# BUG: in-progress LessonsView mixes lesson completion with course completion

## Observed state

When a user completes only the first lesson of a seven-lesson course and plays one reinforcement game, LessonsView remains structurally in the in-progress course flow, but the individual lesson card renders the course-level green status chip `КУРС ПРОЙДЕН`. The header also exposes a bare `100%` reinforcement result, which is visually read as course completion. The result is a false state: the course is not completed, only one lesson has been completed and one game session exists.

## Analytics review / root cause

`LessonsView.isCompletedCourse` is correctly intended to derive from `headerProgress.completed >= totalLessonsCount`, and `LessonsManager.headerCounts` is lesson-progress based. However, the lesson carousel passes each completed lesson through the shared `CourseLessonCard`, where the generic `.completed` branch uses the course-level status title and completed-course visual grammar. Separately, `courseGameSummary` exposes `ReinforcementStore.overallScore` as a bare percentage, without labeling it as a game/reinforcement score. Reinforcement metrics therefore leak course-level completion language into an in-progress course state.

## Required fix

Keep three independent state axes: course completion, lesson completion, and reinforcement progress. A completed lesson inside an incomplete course must remain a lesson card with a lesson-specific green completion treatment and must never receive the course badge, course flip/back grade sheet, or course-level CTA. The in-progress header must show lesson progress such as `1/7 уроков`; any reinforcement percentage must be explicitly labeled `результат игры` or `эффективность закрепления` and must not be presented as a course completion percentage.

## Acceptance criteria

- [ ] Scenario: complete lesson 1 of 7, play one game, return to LessonsView. The page remains in the in-progress LessonsView branch.
- [ ] The lesson 1 card remains a lesson entity; it may use green wave completion styling, but its status copy is `УРОК ПРОЙДЕН`, not `КУРС ПРОЙДЕН`.
- [ ] Lessons 2–7 retain normal locked/in-progress lesson-card styling and do not inherit course-card visuals.
- [ ] No course flip/back grade sheet or completed-course reinforcement dashboard appears until all seven lessons are completed.
- [ ] The top summary distinguishes lesson completion (`1/7`) from reinforcement metrics (`1 игра`, covered cards, or reinforcement score).
- [ ] A fully completed course still uses the existing completed-course dashboard and course-level status pill unchanged.
- [ ] Add/verify a regression test or deterministic debug scenario for `1/7 + 1 game` and `7/7 + 1 game` states.

# Implement BUG fix: lesson card vs course card state

- [ ] Передать explicit `isCourseCompleted`/course context в lesson-card renderer.
- [ ] При неполном курсе показывать lesson-specific completed state без `КУРС ПРОЙДЕН`, course flip и course grade sheet.
- [ ] Сохранить completed-course card behavior только для полного курса.
- [ ] Явно подписать reinforcement score в in-progress summary.
- [ ] Проверить сценарии `1/7 + game` и `7/7 + game` статически и через diff.

# Minimal fix: CourseView status chip overflow

- [ ] Сверить статус с canonical Start: system 13 bold, spacing 6, padding 14/8, arrow 11 bold, PressDownStyle.
- [ ] Убрать обрезку `КУРС ПРОЙДЕН` на узкой course card: дать тексту минимальный scale factor/fixed-size behavior без увеличения capsule.
- [ ] Проверить одинаковый compact layout на face `КУРС ПРОЙДЕН` и back `ЗАКРЕПЛЕНИЕ`.

# Exact completed status placement

- [ ] В completed CourseLessonCard убрать TaikaWordmarkLockup из верхней строки.
- [ ] Разместить status capsule в верхней строке на его месте, не увеличивая capsule.
- [ ] Использовать Start metrics: system 13 bold, spacing 6, padding 14/8, arrow 11 bold.
- [ ] Проверить face `КУРС ПРОЙДЕН` и back `ЗАКРЕПЛЕНИЕ` на одинаковую ширину/читабельность.

# Card UI refinement: status, progress, back actions

- [ ] Сделать completed status capsule визуально не выше canonical Start и без лишней ширины от icon/text layout.
- [ ] Для in-progress course/lesson progress использовать currentAccentFill/currentAccentTintColor, не mastery green.
- [ ] Перенести back-face actions вниз, left-align, в outline-only Warmup-style controls.
- [ ] Увеличить action text readability без filled green/black button blocks.
- [ ] Проверить completed face/back и in-progress card states статически.

# Completed LessonsView grade-sheet refinement

- [ ] Снизить насыщенность green/wave background так, чтобы он не конкурировал с результатами.
- [ ] Свести главный score и три achievement metrics в одну ровную композицию с одинаковыми колонками.
- [ ] Добавить restrained appear animation для score/metrics с prefers-reduced-motion guard.
- [ ] Вернуть стрелке в lesson row открытие самого урока.
- [ ] Оставить отдельный явный selection control для сбора уроков в reinforcement.

# Readable completed card back face

- [ ] Убрать monospaced из пользовательских заголовков, пояснений, labels и CTA.
- [ ] Оставить monospaced только для numeric score/metrics, где он помогает сканированию.
- [ ] Увеличить secondary copy до минимум 13 pt и обеспечить lineLimit/lineSpacing без обрезки.
- [ ] Сделать CTA outline-контрастными: зелёный текст/иконка на прозрачной поверхности, без чёрного текста на тёмном фоне.
- [ ] Проверить back face на первом взгляде и push после diff validation.

# Completed lesson selection vs navigation

- [ ] Разделить tap по checkbox/левому содержимому и trailing chevron.
- [ ] Checkbox/left tap только toggles lesson selection.
- [ ] Trailing chevron только открывает canonical lesson.
- [ ] Добавить `Выбрать все` и `Снять все` для completed lesson selection.
- [ ] Сохранить selectedIds и scope для Speaker/Game reinforcement.

# StepView completion screen-fit

- [ ] Сохранить success hero, основной CTA и следующий урок в safe-area пределах.
- [ ] Сжать secondary chips/section spacing на малых экранах.
- [ ] Сделать game recommendation rows компактными и не обрезать locked states.
- [ ] Добавить scroll-safe fallback для completion content, если высоты экрана недостаточно.
- [ ] Проверить визуальный порядок и push после static validation.

# Regular splash branded ritual

- [ ] Найти текущий regular splash implementation и animation state.
- [ ] Убрать розовое пятно и собрать графитовую branded composition.
- [ ] Добавить restrained voice-wave motion и reduced-motion fallback.
- [ ] Сохранить быстрый launch flow и проверить safe-area/contrast.
- [ ] Закоммитить и запушить splash redesign.

# Completed course card wave flip

- [ ] Найти общий rotating surface и текущий wave background ownership.
- [ ] Перенести wave layer внутрь той же clipped face/back surface.
- [ ] Сохранить face/back readability и не допустить bleed за границы карточки.
- [ ] Проверить 3D flip visually/static и запушить fix.

# StepView completion header polish

- [ ] Добавить безопасный top inset под app header.
- [ ] Уменьшить success icon/title vertical footprint.
- [ ] Сделать lesson/status chips компактными, одинаковыми и центрированными.
- [ ] Проверить, что CTA/game rows не потеряли доступную высоту.
- [ ] Закоммитить и запушить polish.

# Splash final polish

- [ ] Поднять центральную splash composition.
- [ ] Сделать главную wave белой, оставить тонкий accent highlight.
- [ ] Сократить подпись до короткого branded cue.
- [ ] Проверить обычную и reduced-motion анимацию.
- [ ] Закоммитить и запушить polish.

# LessonsView mastery gradient final

- [ ] Найти текущие mastery green gradient/color usages.
- [ ] Добавить exact gradient #36F5B0 → #19CFA0.
- [ ] Подключить его только к completed/mastery accents.
- [ ] Проверить, что in-progress и PRO colors не изменились.
- [ ] Закоммитить и запушить color fix.

# Grade sheet and selection action bar layout

- [ ] Выровнять единый horizontal inset внутри completed hero.
- [ ] Зафиксировать skill row result column и chevron у правого края.
- [ ] Собрать Выбрать все/Снять все в отдельную ровную action bar.
- [ ] Добавить bottom spacing, чтобы controls не попадали под home indicator.
- [ ] Проверить small-screen clipping и запушить layout fix.

# Final two-day integration audit

- [x] Сверить историю последних двух дней и фактический diff относительно origin/2026-01-21-k7hb-d2004.
- [x] Проверить CourseView completed face/back, exact status capsule и reinforcement routes.
- [x] Проверить LessonsView completed/in-progress state axes, grade sheet, waves, selection/navigation и bulk actions.
- [x] Проверить StepView completion screen-fit, safe area и centered metadata chips.
- [x] Проверить Speaker reinforcement entry и Game Park mode/PRO routing.
- [x] Проверить regular SplashView visual polish и AppShell handoff.
- [x] Найти и исправить regressions/contradictory states.
- [x] Выполнить static validation и собрать один consolidated production push.

# Speaker coherent state flow

- [x] Проверить стартовый idle/ready state без ложного live listening.
- [x] Развести explicit CTA tap и active recording/listening state.
- [x] Зафиксировать одну геометрию сферы/микрофона между idle, listening и processing.
- [x] Проверить CTA transitions, processing и result handoff.
- [x] Выполнить static validation и запушить Speaker flow fix.

# Speaker build and background fixes

- [x] Исправить foregroundStyle LinearGradient/Color mismatch в SpeakerDS.swift:1061 через AnyShapeStyle.
- [x] Вернуть Speaker глобальный graphite background token как на Main.
- [x] Выполнить static validation (git diff --check и source audit).
- [ ] Выполнить device/Xcode build gate check на macOS simulator.

# Course and lesson progress gradient consistency

- [ ] Найти все progress fill/track paths в CourseView и LessonsView.
- [ ] Сверить их с утверждённым основным gradient token.
- [ ] Синхронизировать прогресс CourseView и карточек уроков LessonsView.
- [ ] Выполнить static validation и подготовить commit/push.

# Completed green treatment audit

- [x] Аудировать все старые green Color usages в CourseView, LessonsView и CardDS.
- [x] Сверить фон, progress, status chip и completed accent с #36F5B0 → #19CFA0.
- [x] Исправить оставшиеся старые treatments, сохранив новый status chip.
- [x] Выполнить static validation и подготовить commit/push.

# Completed LessonsView background regression

- [x] Найти root background/overlay, который заливает весь completed LessonsView зелёным.
- [x] Вернуть graphite base background и оставить зелёный только локальным accent treatment.
- [x] Проверить header, FM block, grade sheet и нижнюю навигацию на отсутствие зелёной заливки.
- [x] Выполнить static validation и подготовить commit/push.

# In-progress LessonsView treatment regression

- [x] Найти state gate, который преждевременно включает completed green treatment.
- [x] Оставить зелёный только на реально завершённых карточках уроков.
- [x] Привести выбор уроков in-progress курса к списочному UX completed-сценария.
- [x] Выполнить static validation и подготовить commit/push.

# LessonsView back navigation UX

- [x] Найти текущий back action и его visual/touch target.
- [x] Сделать back affordance нативной с удобной областью нажатия.
- [x] Проверить, что back не конфликтует с carousel/scroll gestures.
- [x] Выполнить static validation и подготовить commit/push.

# Reinforcement diagnostics and grade-sheet clarity

- [x] Проверить сохранение результатов игры по courseId/lessonId и mapping ошибок.
- [x] Сделать weak lessons и отсутствие диагностики различимыми в списке.
- [x] Убрать лишние иконки у предметов «Вспоминание» и «На слух», сохранив строгую зачётку.
- [x] Определить, нужен ли reset прогресса, выполнить static validation и подготовить commit/push.

# Speaker E2E flow cleanup

- [x] Найти idle/listening/recognition/result states и все дублирующие CTA.
- [x] Зафиксировать единый главный сценарий и иерархию экранных сообщений.
- [x] Убрать дубли статуса, mode chips и нижних кнопок без layout jumps.
- [x] Выполнить static validation и подготовить commit/push.

# Course quality pass: One Wave and Thai for Soul

- [x] Составить карту каталога, уроков, steps, целей и повторений для обоих курсов.
- [x] Проверить end-to-end сценарии: первый вход, урок, step, игра, Speaker, возврат и продолжение.
- [x] Проверить стрелки, back navigation, selection, быстрые действия и отсутствие дублирующих CTA.
- [x] Проверить методическую последовательность, связность русского/тайского материала и покрытие практикой.
- [x] Сверить completed/in-progress/locked states, диагностику ошибок и синхронизацию прогресса.
- [x] Исправить подтверждённые проблемы, провести static validation и подготовить один финальный push.

# Game Park navigation and paywall consistency

- [x] Аудировать входы в Game Park из header, CourseView, LessonsView и lesson cards.
- [x] Зафиксировать один canonical game mode picker и единый route state.
- [x] Убрать промежуточный непонятный экран и повторный Pro paywall.
- [x] Проверить возврат из игр, locked modes и выбранный lesson/course scope.
- [x] Выполнить static validation и подготовить один финальный push.

# LessonsView grade sheet redesign

- [x] Аудировать смысл каждого блока зачётки и diagnostics copy.
- [x] Убрать лишний Speaker icon и разделить предметы строгими rows/dividers.
- [x] Сделать системные metric numbers с единым reveal motion без layout jumps.
- [x] Перепроектировать нижний diagnostics/lesson selection block с одним ясным CTA.
- [x] Выполнить static validation и подготовить один финальный push.

# Natural mastery gradient family

- [x] Аудировать текущие pink/mastery tokens и все completed usages.
- [x] Зафиксировать природную pink-core/lime/jungle gradient family по референсу.
- [x] Синхронизировать chips, progress, grade sheet, lines и completed rows.
- [x] Проверить контраст, локальность акцентов и отсутствие full-screen green overlay.
- [x] Выполнить static validation и подготовить один финальный push.

# Mastery gradient correction pass

- [x] Аудировать роли lime/pink/jungle и solid fallback по скриншотным состояниям.
- [x] Пересобрать controlled pink-to-jungle gradient без жёлтого доминирования.
- [x] Синхронизировать chips, wordmark accents, waves, crowns и grade sheet.
- [x] Убрать смешение legacy solid/gradient treatments.
- [x] Выполнить static validation и подготовить один финальный push.

# Completed card and achievement visual sync

- [x] Аудировать старые mint treatments на face/back карточек и в LessonsView.
- [x] Зафиксировать единый natural gradient для всех completed action/status elements.
- [x] Добавить pink-gradient halo для completed favorite card только при active favorite.
- [x] Выделить одно главное achievement number в grade sheet и проверить motion/contrast.
- [x] Выполнить static validation и подготовить один финальный push.

# Smart Speaker E2E state-machine cleanup

- [x] Аудировать idle, recording, processing, no-input, error и result states.
- [x] Зафиксировать единый graphite surface и стабильную hero composition.
- [x] Убрать scene-level background changes и повторяющиеся status/CTA layers.
- [x] Сделать no-input/error states с одним понятным next action.
- [x] Проверить result/retry/keyboard fallback flow и отсутствие layout jumps.
- [x] Выполнить static validation и подготовить один финальный push.

# Grade sheet diagnostics regression

- [ ] Аудировать старый selection chip, score contrast/motion и плотность skill rows.
- [ ] Перевести `уроки выбраны` и completed selection controls на natural mastery gradient.
- [ ] Выровнять result block вправо и выделить одну крупную achievement metric.
- [ ] Разделить предметы зачётки и упростить arrows/Pro states.
- [ ] Показывать error-training lesson только при реальном lesson-level diagnostics.
- [ ] Выполнить static validation и подготовить один финальный push.

# LessonsView — in-progress course polish

- [ ] Audit lesson card front/back rendering for completed lessons inside an unfinished course.
- [ ] Remove Taika label from completed lesson card and use the canonical pink-to-green completion status treatment.
- [ ] Restore pink favorite wave lines when a lesson card has favorites, while preserving graphite surface.
- [ ] Remove duplicate status and fix typography/spacing on the lesson-card back.
- [ ] Replace lower selection controls' old pink solid styling with the canonical gradient treatment.
- [ ] Validate in-progress, completed-lesson, empty-diagnostics, and favorite/non-favorite states statically.
- [ ] Commit and push the complete fix to branch 2026-01-21-k7hb-d2004.

# Course View — weekly metrics and completed filter

- [ ] Audit current weekly metrics and identify the exact source for lessons, minutes, and words.
- [ ] Verify whether minutes come from lesson timer estimates, completed progress, games, or a mixed aggregate.
- [ ] Define a bounded weekly time metric that does not inflate from course estimates or repeated sessions.
- [ ] Reduce bottom metrics scale and hierarchy without losing the useful signal.
- [ ] Add a visible «Пройденные» filter only when completed courses exist.
- [ ] Remove completed courses from «Продолжить» and preserve in-progress/unstarted semantics.
- [ ] Validate filter transitions, empty states, metric labels, and commit/push the fix.

# Swift compiler fix — LessonsDS argument order

- [ ] Fix `LessonsDS.swift:1479` so `isFavoriteActive` precedes `isConsoleEnabled` according to `CourseLessonCard` initializer order.
- [ ] Scan all `CourseLessonCard` call sites for the same named-argument ordering issue.
- [ ] Run static validation and commit/push the build-ready fix.


# Final Lessons grade-sheet and navigation pass

- [ ] Audit current grade-sheet metric rows, approved numeric font tokens, materials picker, game callback, and Lessons header Speaker callback.
- [ ] Remove the unreadable efficiency label and duplicate selected-lessons count from the grade sheet.
- [ ] Recompose grade-sheet subjects into one readable result/errors/chevron row and restore the approved numeric font.
- [ ] Replace the old mint Lessons/Lifehacks picker styling with canonical gradient treatment.
- [ ] Open the tapped game mode directly instead of reopening Game Park mode selection.
- [ ] Route Lessons header Speaker to scoped course reinforcement for the whole course.
- [ ] Run static validation and push one commit for all fixes.

# Completed lesson card — final path bugfix

- [ ] Audit why completed lesson back face still renders the wrong numeric/typeface treatment.
- [ ] Trace console tap from completed lesson card and route it to the Game Mode Picker, not step completion/final message.
- [ ] Trace Speaker tap from completed lesson card and route it to scoped course reinforcement, not Instant Speaker.
- [ ] Trace post-game lesson-level diagnostic persistence and expose real weak lesson IDs/scores in LessonsView.
- [ ] Run static path validation and push one unified bugfix commit.

# LessonsView regression — final numeric and diagnostics correction

- [ ] Restore the exact numeric font used by Course View bottom metrics, not MV-SKIFER.
- [ ] Remove the hero sublabel under the main reinforcement score entirely.
- [ ] Trace why saved game scores still do not become visible weak lesson diagnostics.
- [ ] Ensure error-training CTA/list appears only from real lesson-level scores below threshold.
- [ ] Replace the actual Lessons materials picker accent with the canonical approved gradient.
- [ ] Run targeted validation and push one regression-fix commit.


# Course favorites — pink organic wave treatment

- [ ] Audit CourseCard favorite state and current organic wave renderer.
- [ ] Ensure favorite courses receive pink background waves immediately after tap.
- [ ] Keep completed-course green treatment dominant when both completed and favorite are true.
- [ ] Validate live favorite refresh and push one focused commit.


# CourseCard back-face accent regression

- [ ] Locate the actual back-face action button and its old mint accent source.
- [ ] Apply canonical gradient with completed/favorite state precedence.
- [ ] Run static validation and push focused fix.


# Diagnostic error UX polish

- [ ] Audit current error count/indicator rendering and `Тренировать ошибки` callback.
- [ ] Design a compact malinовый diagnostic chip/indicator distinct from selection controls.
- [ ] Remove gradient from the error-training CTA and use a separate outline/action treatment.
- [ ] Make the error-training action launch the scoped reinforcement flow.
- [ ] Validate zero-error, one-error, and multiple-error states, then push one commit.


# Post-game reinforcement completion flow

- [ ] Audit current game completion overlay, context flags, and callbacks.
- [ ] Define next-step matrix for course reinforcement, lesson game, errors, and Speaker.
- [ ] Replace generic equal-weight popup actions with one contextual primary action and calm secondary close.
- [ ] Align completion overlay with Taika FM / Step final-message visual language.
- [ ] Keep real game metrics and error feedback visible without duplicating selection controls.
- [ ] Validate all game origins and push one post-game flow commit.


# Locked game subjects — Taika+ access flow

- [ ] Audit locked subject row renderer and tap callback.
- [ ] Remove `Taika Pro` text and gradient from locked subjects; keep only neutral lock/crown signal.
- [ ] Route locked game tap to the existing Taika+ access sheet, never Game Park picker.
- [ ] Validate locked and unlocked rows, then push one commit.


# Consolidated Taika UI/UX commit

- [ ] Audit branch HEAD, upstream, recent commits, and working tree.
- [ ] Verify all recent Course/Lessons/CardDS, diagnostics, post-game, and locked-game changes are present.
- [ ] Identify any local or missing changes before consolidation.
- [ ] Create one consolidated commit without losing work and push it.
- [ ] Report exact final HEAD and update command.


# Post-game context and session diagnostics follow-up

- [ ] Verify why a lesson-origin game still renders Step-like follow-up buttons.
- [ ] Define course reinforcement CTA matrix for Pro and non-Pro users.
- [ ] Trace game mistake count from runtime result to ReinforcementStore/session restore by lesson ID.
- [ ] Ensure errors survive closing/reopening LessonsView and are scoped to the correct lesson.
- [ ] Push one focused fix after static validation.

