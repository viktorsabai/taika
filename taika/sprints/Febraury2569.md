

# Sprint: February 2569
## Taika iOS — MVP Stabilization Sprint

---

# 🎯 Sprint Goal

Stabilize the educational core of Taika.
No new experimental systems.
No phase‑2 mechanics.
Only reliability, consistency, and premium-level UX polish.

This sprint focuses on making the current product solid enough to ship as a real MVP.

---

# 🔥 EPIC 1 — Learning Core Stabilization

## Objective
Ensure Step → Lesson → Course progression works predictably and without hidden state bugs.

## Tasks
- Normalize Step completion logic inside StepManager.
- Ensure LessonManager aggregates Step completion correctly.
- Ensure CourseManager aggregates Lesson completion correctly.
- Remove duplicated progress calculations across managers.
- Validate Step atomic contract:
  - transcript must exist
  - audio must exist
  - content type must be defined
- Ensure no business logic exists inside DS layer.

## Definition of Done
- Completion % is correct across Step, Lesson, Course.
- No progress resets after app restart.
- No UI-driven state mutations.

### Sprint log (EPIC 1)

**2026-02-21**
- **Сделано:** Стабилизация ядра обучения (план EPIC 1): атомарный контракт Step (валидация transcript/audio, исключение невалидных из прогресса), единая точка записи прогресса через StepManager, StepView и MainView переведены на вызов только StepManager; удалено дублирование расчётов и пост-снапшоты из StepView; аудит DS (логика только в менеджерах).
- **Доп. правки (долг):** Исправлено сохранение прогресса — ProgressManager при `setStepLearned` теперь сохраняет сразу (`scheduleSave(immediate: true)`), чтобы прогресс не терялся при быстром выходе или смене экрана. Тап по стрелке на учебных карточках: помечаем карточку как «запомнил» и перелистываем на следующую (как у лайфхаков); переход к следующей learnable-карточке (пропуск лайфхаков); при автопереходе сохраняем индекс в StepManager для «Продолжить».
- **Тесты (по факту запуска на устройстве):** Проверить: заход в новый курс/урок → прохождение урока (отметки «запомнил») → выход из приложения → повторный запуск — прогресс по Step/Lesson/Course и кнопка «Продолжить» должны сохраняться. Проверить: тап по стрелке на учебной карточке перелистывает на следующую и ставит «запомнил». После прохождения урока — тап «пройти игру» (Match): не должно быть «нет пар для матча».
- **Документация:** Правки отражены в ARCHITECTURE_TECH.md (§15 changelog), SESSION_README.md (§12 CHANGELOG), LEARNING_PIPELINE.md (§12 changelog), COURSE(README).txt (§15), LESSONS(README).txt (§16), STEP(README).txt (§13 CHANGELOG).
- **Критический фикс (после тестов):** «Выучено» не восстанавливалось после перезапуска, т.к. StepManager.reloadFromProgressStore() искал данные по сырому LessonKey, а ProgressManager хранит по каноническому ключу. Заменено на ProgressManager.learnedSet(courseId:lessonId:) — теперь загрузка урока подхватывает сохранённый прогресс. См. STEP(README).txt §13.
- **Сброс «сбросить всё»:** После сброса в профиле на карточках курса оставался старый прогресс (рассинхрон: сбрасывались только ProgressManager и FavoriteManager; LessonsManager и UserSession не очищались). В `ProfileView.performFullReset()` добавлены вызовы `UserSession.shared.resetAllProgress()` (очищает LessonsManager + снимок UserSession + избранное) и `StepManager.shared.resetAll()` (очистка in-memory learned), чтобы все хранилища прогресса сбрасывались в одном месте.
- **Почему лайки сохраняются, а «выучено» — нет:** Лайки пишутся в FavoriteManager, который при каждом изменении вызывает `save()` синхронно. Прогресс «выучено» писался в ProgressManager, но `scheduleSave(immediate: true)` выполнял `save()` асинхронно (через `DispatchQueue.global.async`), поэтому при быстром выходе из урока или сворачивании приложения сохранение не успевало. Исправлено: при `immediate: true` ProgressManager теперь вызывает `save()` сразу (синхронно), как FavoriteManager.
- **learned=0 / total=0 (effective=0):** Все шаги урока помечались как invalid, т.к. контракт требовал и transcript (phonetic), и audio. Во многих шагах audio пустой или не заполнен → total=0, прогресс не считался. Ослаблен контракт в `StepData.isValidForProgress`: для учёта в прогрессе достаточно непустого transcript (phonetic); audio обязателен только для Speaker/воспроизведения.
- **Прогресс урока/курса и анимация карусели (EPIC 1):** (1) Знаменатель прогресса урока — из StepData.progressCounts(for: lessonId), чтобы не было 100% при 2 выученных. (2) Set-based путь в LessonsManager (нотификация .stepProgressDidChange) тоже использует StepData.progressCounts, иначе перезаписывал правильный процент. (3) Процент курса = сумма выученных по всем урокам / сумма карточек всех уроков курса (LessonsData + StepData), а не только по урокам с записью в progress. (4) Анимация перелистывания карусели при тапе «запомнил»: в SDStepCarousel (StepDS) убран DispatchQueue.main.async вокруг proxy.scrollTo в onChange(of: activeIndex), оставлен withAnimation(.spring) вокруг scrollTo, чтобы прокрутка к следующей карточке шла с пружинной анимацией. Мини-прогресс внизу синхронизирован с activeIndex и обновляется при jump.

---

# 🔥 EPIC 2 — Recall Game Discovery Redesign

## Objective
Make Recall Builder a stable, premium-feeling PRO feature with correct syllable/tone model.

## Tasks
- **Discovery:** PhoneticSegment model — syllable (clean) + toneAfter; tones in mask, not in pool.
- **Manager:** parsePhonetic → segments; BuilderRound with segments, clean syllables; validation on assembled == correctPieces.
- **RecallGameDS:** Assembly mask with slots + tone markers; CD tokens; structured layout.
- **HomeTaskView:** Pass segments and syllableItems to RecallGameView.
- Exclude Steps with >6 syllables from Recall.
- Validation only on explicit "Check" tap.

## Definition of Done
- Pool shows clean syllables only; tones shown in assembly mask.
- Game does not overflow screen width.
- CD/PD tokens throughout; no hardcoded colors.
- State machine stable: Idle → Interacting → Ready → Validation.

### Sprint log (EPIC 2)

**2026-02-22 (Regression fix)**
- Откат пула слогов: снова сетка (4 колонки), все слоги видны сразу. Горизонтальная карусель слогов скрывала остальные — создавалось впечатление «всего три слога» при 7 слотах. Логика данных не менялась (round.syllables по-прежнему 8); исправлен только способ отображения.

**2026-02-22 (Redesign v2)**
- ThemeManager для accent; интонации в маске акцентно; wrong-slots UX (тап по ошибочному слоту → очистка оттуда); Taika FM: «слушай → собирай. таika рядом.»; кнопки с подписями.

**2026-02-22 (Discovery Redesign)**
- **Сделано:** EPIC 2 Recall Discovery Redesign. (1) PhoneticSegment: syllable + toneAfter; parsePhonetic извлекает чистые слоги, тоны (↘→↗) в маску. (2) BuilderRound: segments, syllables (pool), correctPieces; валидация по чистым слогам. (3) RecallGameDS: маска [slot] tone [slot] …; CD токены; структурированный layout. (4) HomeTaskView: передача segments. (5) Документация: HomeTask.txt §3, §6; Febraury2569.md.

**2026-02-22 (initial)**
- **Сделано:** Recall Game MVP Clean. (1) Manager: transcript_ru (ph) — единственный источник; split по `-`; исключены >6 слогов. (2) attemptCount, reinforcementScore; валидация по «Проверить». (3) RecallGameDS: isSelectable в View; 🔊; layout; PD tokens.

---

# 🔥 EPIC 3 — Speaker MVP Reliable

## Objective
Make pronunciation flow stable and production-ready.

## Tasks
- Stabilize Speaker state machine:
  - idle
  - recording
  - analyzing
  - result
- Persist lastPronunciationScore.
- Prevent multiple concurrent recording sessions.
- Handle API latency gracefully.
- Remove fake detailed analytics (no syllable breakdown until real support exists).
- Ensure PRO gating consistent across Speaker.

## Definition of Done
- No stuck states.
- No duplicate recordings.
- Score persists after restart.
- Clean result screen.

### Sprint log (EPIC 3)

**2026-02-23**
- **Сделано:** (1) Избранное в спикере: резолв по case-insensitive lessonId (StepData.lessonIdForCaseInsensitiveLookup), т.к. FavoriteManager хранит нормализованные id, а steps.json — ключи как в JSON. (2) Фильтр «выученные»: отдельная очередь только из learnedSteps, без daily picks; при пустоте — «пока нет выученных фраз». (3) Убран фейковый syllable breakdown: в Manager syllableFeedback = [], в DS удалён блок «по слогам»; экран результата — скор + hint. (4) SpeakerAPI оставлен точкой расширения под Azure; в проде не вызывается; комментарии в SpeakerAPI и SpeakerManager. (5) State machine: централизованный setPhase() с DEBUG-логированием переходов; явный переход в .hint при ошибках записи/распознавания. (6) Документация: SPEAKER_README §12 (источники очередей, baseQueue, разбор — мок до Azure), sprint log EPIC 3.

**2026-02-21 (дотюнивание EPIC 3)**
- **Убраны заглушки daily picks:** в `rebuildQueue()` при отсутствии выученных шагов baseQueue остаётся пустым (без подстановки «са ват ди» и т.п.).
- **Пустые состояния для всех фильтров:** при пустой baseQueue для фильтров «случайные» и default — тот же сценарий, что у «избранное»/«выученные»: очистка состояния, queue = [], phase = .hint, taikaHints с текстом «пройдите урок — здесь появятся фразы» / «пройдите урок — здесь появятся фразы для тренировки».
- **«Получить разбор» и PRO:** кнопка разбора в SpeakerDS синхронизирована с ProManager и OverlayPresenter. PRO — открывается оверлей разбора (ты сказал / нужно было + подсказка); не PRO — Overlay.speakerPaywall → PROView(initialPage для спикера), сквозной процесс завлечения на покупку PRO.
- **EPIC 3 завершён:** стабильная очередь без заглушек, единый формат пустых состояний, гейт разбора через PRO.

**2026-02-21 (фикс paywall со вкладки Спикер)**
- **Проблема:** при тапе «получить разбор» (не PRO) ничего не происходило: оверлей `speakerPaywall` рендерился только в MainView, а на вкладке Спикер отображается SpeakerView, MainView не в дереве.
- **Исправление:** отображение paywall (speakerPaywall и proCoursePaywall) перенесено на уровень AppShell — оверлей показывается поверх любой активной вкладки. В MainView для этих кейсов оставлен EmptyView().

**2026-02-21 (Step–Speaker flow, UX)**
- **Пояснение фильтров:** «текущий урок» = все шаги последнего открытого урока с контентом спикера; после одного урока он может совпадать с «выученные»/«случайные» по составу (две карточки = два шага урока) — это ожидаемо, не баг. Документация: SPEAKER_README §12 и §12.1.
- **CTA «Потренировать произношение»:** в summary overlay после завершения урока добавлена кнопка — переключает на вкладку Спикер (фильтр «текущий урок»). Реализация: NavigationIntent.requestTab(_:), AppShell реагирует и делает popToRoot + selectedTab = 2; в StepView кнопка с иконкой mic и текстом «Потренировать произношение».

**2026-02-21 (навигация и фильтрация в Спикере при росте числа уроков)**
- **План (EPIC 3):** SPEAKER_README §12.2 — при 10–20 уроках нужна ясность: какой урок, откуда карточка. (1) Фильтр «последний урок» вместо «текущий» + в пилле показывать название урока. (2) Чип на каждой карточке с названием урока (как в Избранном). (3) Второй уровень фильтра для «выученные»: выбор по уроку (чипы «Все» | «Урок 1» | …) — в бэклоге. Реализовано: переименование «текущий урок» → «последний урок», чип урока на карточке SpeakerTopCard.

**2026-02-21 (второй уровень «выученные» + унификация)**
- **Второй уровень для «выученные»:** при выборе фильтра «выученные» под основной полоской показывается вторая: «Все» | «Урок 1» | «Урок 2» | … (уроки, в которых есть выученные шаги). SpeakerManager: learnedLessonIds, learnedLessonFilter, setLearnedLessonFilter(lessonId); очередь выученных фильтруется по выбранному уроку. Отступы полосок — PD.Spacing.screen (как в Step/остальном приложении).
- **Унификация Step–Speaker:** общий компонент полоски и фильтр по типу карточек в Step оставлены в бэклоге; при редизайне можно вынести TaikaFilterStrip в Theme и использовать в обоих экранах.

---

# 🔥 EPIC 4 — Progress Consistency Layer

## Objective
Ensure ProgressManager and UserSession produce consistent and reliable state.

## Tasks
- Remove phantom values.
- Ensure dashboard reflects actual stored values.
- Guarantee persistence across relaunch.
- Normalize progress calculation sources.
- Prevent negative or >100% values.

## Definition of Done
- Dashboard values match real progress.
- No resets after restart.
- No inconsistent aggregation.

### Sprint log (EPIC 4)

**2026-02-21**
- **Единый источник процента курса:** ProgressManager.lessonMetaProvider подключён при init() из LessonsData + StepData (id урока, totalSteps, tipIndexes, excludedIndexes). progress(for: courseId, lessonId: nil) считается по learnedSteps и meta; fallback на LessonsManager оставлен только при пустом meta.
- **Синхронизация после загрузки:** В LessonsManager.load() после чтения персиста вызывается rebuildAggregatesFromProgressManager(): агрегаты пересобираются из ProgressManager.learnedEffectiveCount + StepData.progressCounts по всем курсам/урокам; один save() в конце. Персист LM не перебивает актуальное состояние PM после рестарта.
- **Аудит клампов [0, 1]:** Проверены ProgressManager, LessonsManager, MainView, MainManager, ProfileManager; везде прогресс ограничен [0, 1]. В ProgressManager.progress() добавлен явный min(1.0, max(0.0, …)) для курса и урока.
- **Документация:** SESSION_README §4 — источник истины для learned и агрегатов, кто откуда читает, диапазон [0, 1]. ARCHITECTURE_TECH §3.2 — progress source of truth и changelog EPIC 4.

---

# 🔥 EPIC 5 — UI Consistency Audit

## Objective
Unify UI across components to premium Taika standard.

## Tasks
- Migrate HomeTask screens fully to GameShellDS.
- Audit AppShell usage across screens.
- Remove hardcoded frame(width:) or fixed layout hacks.
- Standardize buttons to AppDS tokens.
- Remove inconsistent color usage.
- Fix horizontal overflow in RecallGameDS.

## Definition of Done
- No layout breaking on device.
- No inconsistent paddings.
- All screens respect DS layer rules.

### Sprint log (EPIC 5)

**2026-02-21 (Identity redesign — без обводок, как счётчик лайков)**
- **Запрос:** Полный редизайн кнопок на карточках: никакой геометрической обводки; референс — счётчик лайков в карточке уроков (без обводок), Ed Tech, акцент на визуале.
- **Решение:** Все кнопки-иконки — только заливка + мягкий глянец (gradient overlay), без stroke/strokeBorder. Хэдер: `roundIcon` — Circle, fill + gloss, без обводки. Карточки: `AppCardIconButton` (сердце, геймпад, play, info), `AppConsoleIconButton`, `StepIconCircleButton` (динамик, сердце, галочка в Step) — Circle, только fill + gloss. `AppFavCounterButton` — капсула без обводки. HUD pill в хэдере — без обводки. Одна визуальная семья: мягкие «блины» цвета, без линий по контуру.
- **Сборка:** BUILD SUCCEEDED.

**2026-02-21 (Активное состояние = только перекрашенная иконка, хэдер как Loora)**
- **Запрос:** Активное состояние — не «кругляшки закрашенные», а просто перекрашенная иконка (акцент). Как счётчик лайков в Lessons: нет обводки, акцентно подсвечиваем иконку. Хэдер — манящий, без круглого розового; вдохновение EdTech (Loora).
- **Решение:** Убраны все фоны (круги/таблетки) у одиночных иконок. **Хэдер:** `headerIcon` — только иконка (rainbow, sun/moon, crown): активная = акцентный цвет, idle = вторичный; без кругов. **Карточки:** `AppCardIconButton` — только иконка: active = accent, idle = secondary. **Step:** `StepIconCircleButton` — только иконка (динамик, сердце, галочка): active = accent, idle = secondary. **Консоль:** `AppConsoleIconButton` — только иконка. Счётчик лайков (`AppFavCounterButton`) без изменений — капсула без обводки, референс. Единая айдентика по всему приложению: состояние только через цвет иконки.
- **Сборка:** BUILD SUCCEEDED.

**2026-02-21 (UI приколы для кнопок — отклик и размер)**
- **Запрос:** Стало чище, но «не хватает каких-то UI приколов» — помочь юзеру в управлении, может подсвечивать анимационно, размер крупнее.
- **Сделано:** (1) **Размер:** иконки на карточках 18pt (Theme.IconButton.iconSizeCard), зона нажатия 48pt (tapMinCard) — крупнее и легче попасть. (2) **Нажатие:** PressDownStyle с более выраженным отскоком (scale 0.92, fade 0.94, useBouncySpring: true, dampingFraction 0.72) — не плоский отклик. (3) **Смена состояния:** у сердца (favorite) при isActive лёгкое увеличение 1.06 + spring-анимация — «включил лайк» заметно. AppCardIconButton и StepIconCircleButton переведены на новые токены и стиль.
- **Варианты для дальнейшего шторма (EPIC 5):**
  - **Хаптик:** при тапе по карточной иконке вызывать UIImpactFeedbackGenerator(style: .light) в onTap на уровне View — уже есть в ряде мест, можно унифицировать.
  - **Мгновенная подсветка при тапе:** 0.15–0.2 с полупрозрачный accent под иконкой (overlay) — «вспышка» подтверждения.
  - **Первичная кнопка на карточке:** одну иконку (например play или сердце) сделать чуть крупнее (20pt) или с лёгким акцентным glow в idle, чтобы был явный CTA.
  - **Появление ряда иконок:** при появлении карточки stagger (задержка 0.02–0.05 с между иконками) + fade-in.
  - **Long-press подсказка:** при удержании показывать accessibilityLabel как tooltip (нативный или кастом).
  - **Прогресс / следующий шаг:** мягко пульсировать или подсветить иконку «далее» (play / checkmark), когда шаг готов к переходу.

**2026-02-21 (Main: карусель «Продолжить» и поиск)**
- **Карусель «Продолжить»:** Унифицирована с CourseDS — используется `CDLessonCarousel`; первая карточка с anchor .leading (не обрезается); высота секции с запасом под depth (slotHeight = cardH + 2*depthOverflow).
- **Поиск:** Оверлей поиска перенесён на уровень AppShell (`SearchOverlayView`, `SearchOverlayState.shared`). Тап по поиску во вкладке «Курсы» открывает поиск поверх текущего экрана, а не «в MainView».
- **«Подборка для тебя»:** Заменён блок «План на неделю» — один тап открывает оверлей Кун Кру с подборкой курсов по прогрессу.

---

# 🔥 EPIC 6 — Content Sanity Layer

## Objective
Prevent invalid content from breaking games or speaker.

## Tasks
- Validate transcript formatting.
- Ensure hyphen-based syllable separation.
- Validate audio presence.
- Log invalid Steps.
- Exclude invalid Steps from Recall automatically.

## Definition of Done
- Broken content does not crash app.
- Recall only runs on valid Steps.
- Speaker only runs on valid Steps.

---

# 🚫 Explicitly Out of Scope (Phase 2)

- Mastery decay engine
- Server sync
- Multi-device sync
- AI quota system
- Advanced analytics
- Experiment flags

---

# 📌 Sprint Success Criteria

- Recall stable and premium.
- Speaker reliable.
- Progress consistent.
- No visual layout breaks.
- No hidden state corruption.

This sprint ends when the product feels stable enough to test with real users.

---

# 📋 Что осталось на февраль (на следующий спринт)

- **EPIC 5 (UI):** Хаптик при тапе по иконкам; мгновенная подсветка/вспышка при тапе; stagger появления иконок на карточке; long-press подсказки; пульсация иконки «далее» при готовности шага. Аудит горизонтального overflow в остальных секциях (FM, прогресс-круги), если есть жалобы.
- **EPIC 6 (Content Sanity):** Валидация transcript, исключение невалидных Step из Recall/Speaker, логирование битых шагов.
- **Общее:** Финальный прогон тестов (прогресс после рестарта, «Продолжить», Speaker, Recall, сброс в профиле). Критерий успеха спринта — стабильно для теста с реальными пользователями.
