# Полная карта декомпозиции перегруженных карточек

**Scope:** все 30 не-базовых курсов; только аналитика/draft, production JSON не меняется.

**Rule:** одна карточка — одно речевое действие. Автофлаги требуют ручной проверки; короткие списки объектов и варианты не удаляются автоматически.

## Сводка

- Flagged cards: **68**
- Courses covered: **29**
- `compound_action`: **13**
- `long_question`: **1**
- `noun_list`: **15**
- `choice_list`: **2**


## course_e_1 — 4 flagged cards

| Step | Было | Тип | Решение / atomic draft | Notes | QA |
|---|---|---|---|---|---|
| `course_e_1_l2_o5` | Давайте в своём темпе | `review` | «Давайте в своём темпе» — упростить после native QA | Автофлаг недостаточен; проверить у методиста. | draft — Russian intent; Thai/native QA required |
| `course_e_1_l3_o5` | Чтобы не давить | `review` | «Чтобы не давить» — упростить после native QA | Автофлаг недостаточен; проверить у методиста. | draft — Russian intent; Thai/native QA required |
| `course_e_1_l6_o5` | Скажу мягко и понятно | `noun_list` | «Скажу мягко» / «понятно» | Естественный список объектов; split только если нужна отдельная тренировка каждого объекта. | draft — Russian intent; Thai/native QA required |
| `course_e_1_l6_o6` | Давайте обсудим | `review` | «Давайте обсудим» — упростить после native QA | Автофлаг недостаточен; проверить у методиста. | draft — Russian intent; Thai/native QA required |

## course_e_2 — 2 flagged cards

| Step | Было | Тип | Решение / atomic draft | Notes | QA |
|---|---|---|---|---|---|
| `course_e_2_l1_o3` | Когда сможете? | `short_question` | «Когда сможете?» — оставить как одну карточку; при необходимости уточнение сделать отдельным step | Короткий вопрос; не считать перегруженным автоматически, проверить naturalness. | draft — Russian intent; Thai/native QA required |
| `course_e_2_l6_o4` | Если ещё не готово | `review` | «Если ещё не готово» — упростить после native QA | Автофлаг недостаточен; проверить у методиста. | draft — Russian intent; Thai/native QA required |

## course_e_3 — 3 flagged cards

| Step | Было | Тип | Решение / atomic draft | Notes | QA |
|---|---|---|---|---|---|
| `course_e_3_l1_o5` | Можно починить? | `short_question` | «Можно починить?» — оставить как одну карточку; при необходимости уточнение сделать отдельным step | Короткий вопрос; не считать перегруженным автоматически, проверить naturalness. | draft — Russian intent; Thai/native QA required |
| `course_e_3_l3_o2` | Когда будет готово? | `short_question` | «Когда будет готово?» — оставить как одну карточку; при необходимости уточнение сделать отдельным step | Короткий вопрос; не считать перегруженным автоматически, проверить naturalness. | draft — Russian intent; Thai/native QA required |
| `course_e_3_l4_o3` | Когда придёте? | `short_question` | «Когда придёте?» — оставить как одну карточку; при необходимости уточнение сделать отдельным step | Короткий вопрос; не считать перегруженным автоматически, проверить naturalness. | draft — Russian intent; Thai/native QA required |

## course_e_4 — 5 flagged cards

| Step | Было | Тип | Решение / atomic draft | Notes | QA |
|---|---|---|---|---|---|
| `course_e_4_l1_o3` | Давайте без обид | `review` | «Давайте без обид» — упростить после native QA | Автофлаг недостаточен; проверить у методиста. | draft — Russian intent; Thai/native QA required |
| `course_e_4_l2_o3` | Давайте уточним | `review` | «Давайте уточним» — упростить после native QA | Автофлаг недостаточен; проверить у методиста. | draft — Russian intent; Thai/native QA required |
| `course_e_4_l3_o6` | Давайте вместе решим | `review` | «Давайте вместе решим» — упростить после native QA | Автофлаг недостаточен; проверить у методиста. | draft — Russian intent; Thai/native QA required |
| `course_e_4_l4_o5` | Когда мягче | `review` | «Когда мягче» — упростить после native QA | Автофлаг недостаточен; проверить у методиста. | draft — Russian intent; Thai/native QA required |
| `course_e_4_l5_o6` | Давайте оставим это и пойдём дальше | `compound_action` | «Давайте оставим это» / «пойдём дальше» | Каждая карточка должна содержать одно действие; контекст/причину вынести в tip или notes. | draft — Russian intent; Thai/native QA required |

## course_e_5 — 3 flagged cards

| Step | Было | Тип | Решение / atomic draft | Notes | QA |
|---|---|---|---|---|---|
| `course_e_5_l3_o4` | Когда что сказать | `review` | «Когда что сказать» — упростить после native QA | Автофлаг недостаточен; проверить у методиста. | draft — Russian intent; Thai/native QA required |
| `course_e_5_l5_o6` | Улыбка сама по себе не означает «да» | `compound_action` | «Улыбка сама по себе не означает «да»» — упростить после native QA | Каждая карточка должна содержать одно действие; контекст/причину вынести в tip или notes. | draft — Russian intent; Thai/native QA required |
| `course_e_5_l6_o6` | Ответить мягко и ясно | `noun_list` | «Ответить мягко» / «ясно» | Естественный список объектов; split только если нужна отдельная тренировка каждого объекта. | draft — Russian intent; Thai/native QA required |

## course_e_6 — 2 flagged cards

| Step | Было | Тип | Решение / atomic draft | Notes | QA |
|---|---|---|---|---|---|
| `course_e_6_l1_o5` | Чтобы смягчить | `review` | «Чтобы смягчить» — упростить после native QA | Автофлаг недостаточен; проверить у методиста. | draft — Russian intent; Thai/native QA required |
| `course_e_6_l3_o6` | Когда добавить | `review` | «Когда добавить» — упростить после native QA | Автофлаг недостаточен; проверить у методиста. | draft — Russian intent; Thai/native QA required |

## course_l_10 — 2 flagged cards

| Step | Было | Тип | Решение / atomic draft | Notes | QA |
|---|---|---|---|---|---|
| `course_l_10_l2_o4` | Когда занятия? | `short_question` | «Когда занятия?» — оставить как одну карточку; при необходимости уточнение сделать отдельным step | Короткий вопрос; не считать перегруженным автоматически, проверить naturalness. | draft — Russian intent; Thai/native QA required |
| `course_l_10_l7_o11` | Можно перенести на завтра? | `long_question` | «Можно перенести на завтра?» — оставить как одну карточку; при необходимости уточнение сделать отдельным step | Оставить один вопрос и один объект; дополнительные уточнения вынести в следующую карточку. | draft — Russian intent; Thai/native QA required |

## course_l_11 — 1 flagged cards

| Step | Было | Тип | Решение / atomic draft | Notes | QA |
|---|---|---|---|---|---|
| `course_l_11_l3_o9` | Когда фестиваль? | `short_question` | «Когда фестиваль?» — оставить как одну карточку; при необходимости уточнение сделать отдельным step | Короткий вопрос; не считать перегруженным автоматически, проверить naturalness. | draft — Russian intent; Thai/native QA required |

## course_l_12 — 3 flagged cards

| Step | Было | Тип | Решение / atomic draft | Notes | QA |
|---|---|---|---|---|---|
| `course_l_12_l6_o6` | Когда вам удобно? | `short_question` | «Когда вам удобно?» — оставить как одну карточку; при необходимости уточнение сделать отдельным step | Короткий вопрос; не считать перегруженным автоматически, проверить naturalness. | draft — Russian intent; Thai/native QA required |
| `course_l_12_l6_o10` | Можно оплатить картой? | `short_question` | «Можно оплатить картой?» — оставить как одну карточку; при необходимости уточнение сделать отдельным step | Короткий вопрос; не считать перегруженным автоматически, проверить naturalness. | draft — Russian intent; Thai/native QA required |
| `course_l_12_l6_o11` | Я не так имел в виду | `compound_action` | «Я не так имел в виду» — упростить после native QA | Каждая карточка должна содержать одно действие; контекст/причину вынести в tip или notes. | draft — Russian intent; Thai/native QA required |

## course_l_13 — 5 flagged cards

| Step | Было | Тип | Решение / atomic draft | Notes | QA |
|---|---|---|---|---|---|
| `course_l_13_l1_o8` | Когда почините? | `short_question` | «Когда почините?» — оставить как одну карточку; при необходимости уточнение сделать отдельным step | Короткий вопрос; не считать перегруженным автоматически, проверить naturalness. | draft — Russian intent; Thai/native QA required |
| `course_l_13_l3_o8` | Когда почините? | `short_question` | «Когда почините?» — оставить как одну карточку; при необходимости уточнение сделать отдельным step | Короткий вопрос; не считать перегруженным автоматически, проверить naturalness. | draft — Russian intent; Thai/native QA required |
| `course_l_13_l4_o6` | Сообщите, когда приедете | `compound_action` | «Сообщите» / «когда приедете» | Каждая карточка должна содержать одно действие; контекст/причину вынести в tip или notes. | draft — Russian intent; Thai/native QA required |
| `course_l_13_l6_o5` | Напишите когда будете | `review` | «Напишите» / «будете» | Автофлаг недостаточен; проверить у методиста. | draft — Russian intent; Thai/native QA required |
| `course_l_13_l7_o4` | Когда закончите ремонт? | `short_question` | «Когда закончите ремонт?» — оставить как одну карточку; при необходимости уточнение сделать отдельным step | Короткий вопрос; не считать перегруженным автоматически, проверить naturalness. | draft — Russian intent; Thai/native QA required |

## course_l_14 — 1 flagged cards

| Step | Было | Тип | Решение / atomic draft | Notes | QA |
|---|---|---|---|---|---|
| `course_l_14_l1_o8` | Когда привезёт? | `short_question` | «Когда привезёт?» — оставить как одну карточку; при необходимости уточнение сделать отдельным step | Короткий вопрос; не считать перегруженным автоматически, проверить naturalness. | draft — Russian intent; Thai/native QA required |

## course_l_15 — 1 flagged cards

| Step | Было | Тип | Решение / atomic draft | Notes | QA |
|---|---|---|---|---|---|
| `course_l_15_l6_o9` | Спасибо, но я откажусь | `compound_action` | «Спасибо» / «но я откажусь» | Каждая карточка должна содержать одно действие; контекст/причину вынести в tip или notes. | draft — Russian intent; Thai/native QA required |

## course_l_3 — 3 flagged cards

| Step | Было | Тип | Решение / atomic draft | Notes | QA |
|---|---|---|---|---|---|
| `course_l_3_l3_o9` | Цена не та, что на табличке | `compound_action` | «Цена не та» / «что на табличке» | Каждая карточка должна содержать одно действие; контекст/причину вынести в tip или notes. | draft — Russian intent; Thai/native QA required |
| `course_l_3_l6_o9` | Давайте пересчитаем | `review` | «Давайте пересчитаем» — упростить после native QA | Автофлаг недостаточен; проверить у методиста. | draft — Russian intent; Thai/native QA required |
| `course_l_3_l6_o10` | Вот столько, правильно? | `compound_action` | «Вот столько» / «правильно?» | Каждая карточка должна содержать одно действие; контекст/причину вынести в tip или notes. | draft — Russian intent; Thai/native QA required |

## course_l_4 — 1 flagged cards

| Step | Было | Тип | Решение / atomic draft | Notes | QA |
|---|---|---|---|---|---|
| `course_l_4_l2_o4` | Супы и рис | `noun_list` | «Супы» / «рис» | Естественный список объектов; split только если нужна отдельная тренировка каждого объекта. | draft — Russian intent; Thai/native QA required |

## course_l_6 — 5 flagged cards

| Step | Было | Тип | Решение / atomic draft | Notes | QA |
|---|---|---|---|---|---|
| `course_l_6_l3_o8` | Когда починят? | `short_question` | «Когда починят?» — оставить как одну карточку; при необходимости уточнение сделать отдельным step | Короткий вопрос; не считать перегруженным автоматически, проверить naturalness. | draft — Russian intent; Thai/native QA required |
| `course_l_6_l3_o11` | Можно починить сегодня? | `short_question` | «Можно починить сегодня?» — оставить как одну карточку; при необходимости уточнение сделать отдельным step | Короткий вопрос; не считать перегруженным автоматически, проверить naturalness. | draft — Russian intent; Thai/native QA required |
| `course_l_6_l4_o9` | Позвоните когда готово | `review` | «Позвоните» / «готово» | Автофлаг недостаточен; проверить у методиста. | draft — Russian intent; Thai/native QA required |
| `course_l_6_l7_o6` | Когда починят? | `short_question` | «Когда починят?» — оставить как одну карточку; при необходимости уточнение сделать отдельным step | Короткий вопрос; не считать перегруженным автоматически, проверить naturalness. | draft — Russian intent; Thai/native QA required |
| `course_l_6_l7_o11` | Позвоните, когда будет готово | `compound_action` | «Позвоните» / «когда будет готово» | Каждая карточка должна содержать одно действие; контекст/причину вынести в tip или notes. | draft — Russian intent; Thai/native QA required |

## course_l_7 — 4 flagged cards

| Step | Было | Тип | Решение / atomic draft | Notes | QA |
|---|---|---|---|---|---|
| `course_l_7_l4_o8` | Когда едем? | `short_question` | «Когда едем?» — оставить как одну карточку; при необходимости уточнение сделать отдельным step | Короткий вопрос; не считать перегруженным автоматически, проверить naturalness. | draft — Russian intent; Thai/native QA required |
| `course_l_7_l6_o4` | Лежак и кокос | `noun_list` | «Лежак» / «кокос» | Естественный список объектов; split только если нужна отдельная тренировка каждого объекта. | draft — Russian intent; Thai/native QA required |
| `course_l_7_l7_o6` | Когда отплытие? | `short_question` | «Когда отплытие?» — оставить как одну карточку; при необходимости уточнение сделать отдельным step | Короткий вопрос; не считать перегруженным автоматически, проверить naturalness. | draft — Russian intent; Thai/native QA required |
| `course_l_7_l7_o7` | Маска и ласты | `noun_list` | «Маска» / «ласты» | Естественный список объектов; split только если нужна отдельная тренировка каждого объекта. | draft — Russian intent; Thai/native QA required |

## course_long_1 — 2 flagged cards

| Step | Было | Тип | Решение / atomic draft | Notes | QA |
|---|---|---|---|---|---|
| `course_long_1_l4_o5` | Донести и вернуться | `compound_action` | «Донести» / «вернуться» | Каждая карточка должна содержать одно действие; контекст/причину вынести в tip или notes. | draft — Russian intent; Thai/native QA required |
| `course_long_1_l5_o5` | Наличные или карта | `choice_list` | Короткий выбор: «Наличные или карта» — оставить одной карточкой; при необходимости разделить на названия вариантов. | Короткий выбор; не считать сложносочинённой автоматически. | draft — Russian intent; Thai/native QA required |

## course_long_2 — 3 flagged cards

| Step | Было | Тип | Решение / atomic draft | Notes | QA |
|---|---|---|---|---|---|
| `course_long_2_l1_o6` | Виза и документы | `noun_list` | «Виза» / «документы» | Естественный список объектов; split только если нужна отдельная тренировка каждого объекта. | draft — Russian intent; Thai/native QA required |
| `course_long_2_l1_o7` | Рабочая виза или пенсионная | `choice_list` | Короткий выбор: «Рабочая виза или пенсионная» — оставить одной карточкой; при необходимости разделить на названия вариантов. | Короткий выбор; не считать сложносочинённой автоматически. | draft — Russian intent; Thai/native QA required |
| `course_long_2_l4_o3` | Когда зачислится? | `short_question` | «Когда зачислится?» — оставить как одну карточку; при необходимости уточнение сделать отдельным step | Короткий вопрос; не считать перегруженным автоматически, проверить naturalness. | draft — Russian intent; Thai/native QA required |

## course_long_3 — 1 flagged cards

| Step | Было | Тип | Решение / atomic draft | Notes | QA |
|---|---|---|---|---|---|
| `course_long_3_l2_o5` | Результаты когда? | `short_question` | «Результаты когда?» — оставить как одну карточку; при необходимости уточнение сделать отдельным step | Короткий вопрос; не считать перегруженным автоматически, проверить naturalness. | draft — Russian intent; Thai/native QA required |

## course_long_4 — 2 flagged cards

| Step | Было | Тип | Решение / atomic draft | Notes | QA |
|---|---|---|---|---|---|
| `course_long_4_l4_o3` | Угон и ДТП | `noun_list` | «Угон» / «ДТП» | Естественный список объектов; split только если нужна отдельная тренировка каждого объекта. | draft — Russian intent; Thai/native QA required |
| `course_long_4_l6_o7` | Ключи и документы на байк | `compound_action` | «Ключи» / «документы на байк» | Каждая карточка должна содержать одно действие; контекст/причину вынести в tip или notes. | draft — Russian intent; Thai/native QA required |

## course_long_5 — 1 flagged cards

| Step | Было | Тип | Решение / atomic draft | Notes | QA |
|---|---|---|---|---|---|
| `course_long_5_l5_o4` | Когда собрание? | `short_question` | «Когда собрание?» — оставить как одну карточку; при необходимости уточнение сделать отдельным step | Короткий вопрос; не считать перегруженным автоматически, проверить naturalness. | draft — Russian intent; Thai/native QA required |

## course_long_6 — 1 flagged cards

| Step | Было | Тип | Решение / atomic draft | Notes | QA |
|---|---|---|---|---|---|
| `course_long_6_l2_o4` | Следующая прививка когда? | `short_question` | «Следующая прививка когда?» — оставить как одну карточку; при необходимости уточнение сделать отдельным step | Короткий вопрос; не считать перегруженным автоматически, проверить naturalness. | draft — Russian intent; Thai/native QA required |

## course_long_7 — 1 flagged cards

| Step | Было | Тип | Решение / atomic draft | Notes | QA |
|---|---|---|---|---|---|
| `course_long_7_l3_o4` | Дорамы и сериалы | `noun_list` | «Дорамы» / «сериалы» | Естественный список объектов; split только если нужна отдельная тренировка каждого объекта. | draft — Russian intent; Thai/native QA required |

## course_s_1 — 1 flagged cards

| Step | Было | Тип | Решение / atomic draft | Notes | QA |
|---|---|---|---|---|---|
| `course_s_1_l6_o7` | Пост и комменты | `noun_list` | «Пост» / «комменты» | Естественный список объектов; split только если нужна отдельная тренировка каждого объекта. | draft — Russian intent; Thai/native QA required |

## course_s_2 — 1 flagged cards

| Step | Было | Тип | Решение / atomic draft | Notes | QA |
|---|---|---|---|---|---|
| `course_s_2_l6_o4` | Записаться и обсудить | `compound_action` | «Записаться» / «обсудить» | Каждая карточка должна содержать одно действие; контекст/причину вынести в tip или notes. | draft — Russian intent; Thai/native QA required |

## course_s_3 — 3 flagged cards

| Step | Было | Тип | Решение / atomic draft | Notes | QA |
|---|---|---|---|---|---|
| `course_s_3_l1_o4` | Серьёзно? Реально? | `short_question` | «Серьёзно? Реально?» — оставить как одну карточку; при необходимости уточнение сделать отдельным step | Короткий вопрос; не считать перегруженным автоматически, проверить naturalness. | draft — Russian intent; Thai/native QA required |
| `course_s_3_l3_o7` | Джай-рай и чувства | `noun_list` | «Джай-рай» / «чувства» | Естественный список объектов; split только если нужна отдельная тренировка каждого объекта. | draft — Russian intent; Thai/native QA required |
| `course_s_3_l5_o6` | Идиомы и сленг | `noun_list` | «Идиомы» / «сленг» | Естественный список объектов; split только если нужна отдельная тренировка каждого объекта. | draft — Russian intent; Thai/native QA required |

## course_s_4 — 1 flagged cards

| Step | Было | Тип | Решение / atomic draft | Notes | QA |
|---|---|---|---|---|---|
| `course_s_4_l2_o4` | Когда медитация | `review` | «Когда медитация» — упростить после native QA | Автофлаг недостаточен; проверить у методиста. | draft — Russian intent; Thai/native QA required |

## course_s_5 — 4 flagged cards

| Step | Было | Тип | Решение / atomic draft | Notes | QA |
|---|---|---|---|---|---|
| `course_s_5_l1_o6` | Мило и флирт | `noun_list` | «Мило» / «флирт» | Естественный список объектов; split только если нужна отдельная тренировка каждого объекта. | draft — Russian intent; Thai/native QA required |
| `course_s_5_l2_o3` | Забота и интерес | `noun_list` | «Забота» / «интерес» | Естественный список объектов; split только если нужна отдельная тренировка каждого объекта. | draft — Russian intent; Thai/native QA required |
| `course_s_5_l3_o5` | Намёки и интерес | `noun_list` | «Намёки» / «интерес» | Естественный список объектов; split только если нужна отдельная тренировка каждого объекта. | draft — Russian intent; Thai/native QA required |
| `course_s_5_l6_o6` | Забота и границы | `noun_list` | «Забота» / «границы» | Естественный список объектов; split только если нужна отдельная тренировка каждого объекта. | draft — Russian intent; Thai/native QA required |

## course_s_6 — 2 flagged cards

| Step | Было | Тип | Решение / atomic draft | Notes | QA |
|---|---|---|---|---|---|
| `course_s_6_l5_o4` | Игры и еда с детьми | `compound_action` | «Игры» / «еда с детьми» | Каждая карточка должна содержать одно действие; контекст/причину вынести в tip или notes. | draft — Russian intent; Thai/native QA required |
| `course_s_6_l5_o6` | На пляже и в кафе | `compound_action` | «На пляже» / «в кафе» | Каждая карточка должна содержать одно действие; контекст/причину вынести в tip или notes. | draft — Russian intent; Thai/native QA required |

## Правило миграции

Эта карта не является готовым JSON. Перед миграцией нужно подтвердить Thai naturalness, назначить canonical phrase IDs, обновить card_count только после решения keep/split, сохранить исходные IDs/refs и проверить progress/Speaker/reinforcement.
