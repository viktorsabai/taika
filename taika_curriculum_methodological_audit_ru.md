# Методологический аудит учебной программы Taika

**Роль:** Chief Learning Methodologist  
**Дата:** 16 августа 2026 года  
**Объект:** 42 курса, 267 уроков, 2 268 content records  
**Persona:** русскоязычные пользователи, живущие в Таиланде

> **Главный вывод:** у Taika уже есть сильная библиотека живых бытовых фраз и правильное продуктовое ядро — пользователь слушает, говорит и получает feedback по произношению. Сейчас не хватает не объёма, а педагогической «магистрали»: системе нужно явно объяснять, что изучать сначала, какой навык формируется на каждом шаге, почему фраза возвращается и куда пользователь идёт дальше.

## Executive summary

Каталог технически целостен: все 42 course IDs связаны с lesson data, пропусков в порядковых номерах уроков и дублирующихся lesson orders не найдено. Средний урок содержит около 8,5 records. Это хороший фундамент для дальнейшей методической работы.

При этом программа пока больше похожа на **богатую библиотеку разговорных карточек**, чем на полностью формализованную траекторию обучения. Крупная логика «База → Тайский для жизни → На одной волне → Тайский для души → Тайский для долгожителей» удачна как навигационная карта, но недостаточно доказана как curriculum: в данных не зафиксированы prerequisites, Can-Do outcomes, mastery gates и правила распределённого повторения.

Рекомендованный старт для нового пользователя: короткая ориентация `course_b_0 / lesson 1` («Тайский без паники»), затем `course_b_1 / lesson 1` («Разговорный старт»). В onboarding preview финальный CTA исправлен: он больше не возвращает пользователя в welcome-loop, а показывает этот маршрут.

| Область | Оценка | Диагноз |
|---|---|---|
| Каталог и структурные связи | **Зелёная** | 42/42 course IDs согласованы; order duplicates и gaps отсутствуют |
| Широта программы | **Зелёная** | Есть база, бытовые ситуации, сервис, social и long-term domains |
| Педагогическая progression | **Жёлто-красная** | Нет формальных outcomes, prerequisites и mastery gates |
| Relevance для русскоязычных резидентов | **Жёлтая** | Основные домены есть, но не все jobs-to-be-done оформлены как маршруты |
| Duplicate hygiene | **Красная** | 125 полных duplicate groups, 307 затронутых records |
| Data contract | **Жёлтая** | 147 `tip` records без ru/thai/phonetic ожидаемы, но семантика полей должна быть формализована |

## 1. Методика аудита

Я разделял четыре вопроса, которые нельзя сводить к одной метрике. **Структурный аудит** проверял связи каталога, lessons и steps. **Педагогический аудит** оценивал порядок навыков, переходы и потенциальные difficulty spikes. **Persona audit** проверял, помогает ли программа решать реальные задачи русскоязычного человека в Таиланде. **Duplicate audit** отличал методически нужное возвращение фразы от копирования идентичной карточки.

В качестве внешней рамки использованы action-oriented approach CEFR — обучение через реалистичные сценарии и задачи [1] — и ACTFL Can-Do, где коммуникация рассматривается как interpretive, interpersonal и presentational [2]. Для повторения применён принцип spacing/retrieval: единица должна возвращаться через интервалы и в новых задачах, а не просто дублироваться в соседних уроках [3].

## 2. Что фактически есть в каталоге

Из 2 268 records: 1 525 — phrases, 563 — words, 147 — tips и 33 — casual. Это соответственно 67,2%, 24,8%, 6,5% и 1,5%. Преобладание фраз соответствует обещанию Taika помогать говорить в реальной жизни. Но phrase density сама по себе не гарантирует обучение: каждая фраза должна иметь ситуацию, pronunciation focus, retrieval event и перенос в новый контекст.

| Блок | Курсы | Роль | Ключевые темы |
|---|---:|---|---|
| База от Тайки | `course_b_0`–`course_b_7` | Foundation | orientation, разговорный старт, tones, people, numbers, verbs, food, dialogue |
| Тайский для жизни | `course_l_1`–`course_l_15` | Survival/life routes | police, taxi, market, food, doctor, beach, shop, emergency, condo, delivery, nightlife |
| На одной волне | `course_e_1`–`course_e_6` | Social/work competence | understandable Thai, work, service, conflict, cultural codes, softening |
| Тайский для души | `course_s_1`–`course_s_6` | Personal expansion | blogging, hobbies, social talk, retreat, romance, children |
| Для долгожителей | `course_long_1`–`course_long_7` | Residency life | visa, banks, medicine/insurance, transport, condo, pets, humour/pop culture |

Крупные labels хорошо организуют библиотеку, но ещё не сообщают measurable outcome. Пользователь должен видеть не только «курс про кондо», но и «после этого курса я могу сообщить о поломке, ответить на уточнение и попросить срок ремонта».

## 3. Рекомендуемая progression

| Фаза | Маршрут | Выходной навык |
|---|---|---|
| 0. Orientation | `course_b_0`, 3 урока | Понять связь звук → тон → смысл и пережить первый micro-win |
| 1. Survival speech | `course_b_1` «Разговорный старт» | Поздороваться, представиться, попрощаться, начать короткий обмен |
| 2. Pronunciation foundation | `course_b_2` «Магия интонации» | Слышать и воспроизводить базовые tone contrasts на частых фразах |
| 3. Reference base | `course_b_3`–`course_b_4` | Говорить о себе, людях, времени, числах и месте |
| 4. Action control | `course_b_5`–`course_b_7` | Просить, хотеть, идти, остановить, выбрать, закончить mini-dialogue |
| 5. Immediate life | Приоритетно `course_l_2`, `l_3`, `l_4`, `l_5`, `l_8`, `l_9`, `l_13`, `l_14` | Taxi, market, food, doctor, shop, emergency, condo, delivery |
| 6. Social competence | `course_e_1`–`e_6` | Смягчать просьбы, работать с сервисом и конфликтом, понимать implicit meaning |
| 7. Long-term admin | `course_long_1`–`long_5` | Immigration, bank, medicine/insurance, transport, condo |
| 8. Personal expansion | `course_s_*`, `course_long_6`–`long_7` | Расширять социальную и культурную жизнь после survival mastery |

`course_b_0` содержит 3 урока и 20 records, все типа `tip`. Это хороший orientation module, но не лучший первый speaking lesson. Он должен быть явно обозначен как «короткая настройка перед первым уроком».

`course_b_1` выглядит наиболее подходящим первым speaking course: 7 уроков, 24 steps и 59 records. `course_b_2` логично ставить после первого successful voice attempt: тогда тональная теория объясняет личный результат пользователя, а не появляется как абстрактная лекция.

Главный возможный difficulty spike возникает при переходе от базовых карточек к police, immigration, medicine и condo. Эти сценарии требуют не только словаря, но и sequence management: сообщить контекст, ответить на уточнение, попросить повторить, подтвердить понимание и завершить разговор. Урок «Таксист, вези меня домой» должен проверять полный цикл «приветствие → destination → уточнение → цена/оплата → остановка → благодарность», а не только знание слова «домой».

### Curriculum passport, которого сейчас не хватает

Каждому course и lesson нужен machine-readable паспорт.

| Поле | Пример | Функция |
|---|---|---|
| `entry_level` | survival A1 | Не направлять новичка в сложный сценарий |
| `prerequisites` | `b_1`, `b_4`, polite particles | Сделать progression проверяемой |
| `can_do_outcome` | «Могу сообщить хозяину о проблеме и попросить исправить её» | Объяснить ценность курса |
| `interaction_mode` | interpersonal | Отличить listening от speaking и writing |
| `scenario_steps` | report → clarify → request → confirm | Превратить карточки в задачу |
| `pronunciation_focus` | tone pair, rhythm, final particles | Связать voice feature с навыком |
| `mastery_gate` | recognition + 2 spontaneous attempts | Не считать просмотр прохождением |
| `recycling_plan` | D+1, D+3, D+7, new context | Отличить retrieval от дубля |

## 4. Relevance для русскоязычных жителей Таиланда

Содержательно Taika уже хорошо привязана к жизни в Таиланде: в каталоге есть police, taxi, market, food, doctor, urgent help, shop, delivery, condo, immigration, banks, insurance, pets и social culture. Это сильнее универсального beginner textbook и должно быть частью positioning: не «выучить тайский вообще», а «решать ежедневные задачи и постепенно звучать увереннее».

Приоритет следует задавать не количеством тем, а частотой и последствиями ситуаций. В home/onboarding лучше показывать не 42 курса, а jobs-to-be-done: «решить вопрос с кондо», «заказать еду», «объясниться с врачом», «пройти immigration», «говорить на рынке», «не растеряться в такси».

| Job пользователя | Текущее покрытие | Рекомендация |
|---|---|---|
| Visa и immigration | `course_long_1` | Сделать guided route с документами, уточнениями и просьбой повторить |
| Condo, landlord, repairs | `course_l_13`, `course_long_5` | Развести бытовую поломку и правила дома/соседей |
| Market и bargaining | `course_l_3` | Проверять полный negotiation dialogue, не только prices |
| Food, spice, payment | `course_l_4` | Добавить dine-in, takeaway, delivery, allergy branches |
| Taxi и transport | `course_l_2`, `course_long_4` | Развести первый ride и transport-for-locals |
| Doctor, pharmacy, insurance | `course_l_5`, `course_long_3` | Добавить symptoms, allergy, medication и insurance handoff |
| Police/emergency | `course_l_1`, `course_l_9` | Guided rehearsal: «повторите медленнее», «позвоните переводчику» |
| Delivery, parcels, address | `course_l_14` | Добавить room number, landmark, missed call, cashless payment |
| SIM, internet, utilities | Не виден отдельный course-level route | Проверить coverage; при отсутствии добавить в long-term admin |
| Work/service communication | `course_e_2`–`e_4` | Усилить softening, indirect refusal и escalation ladder |

Для police, immigration и doctor Taika должна учить языковую коммуникацию, но не создавать впечатление юридической или медицинской диагностики. Voice score — это feedback по произношению, а не оценка безопасности ситуации.

## 5. Duplicate audit

После Unicode-safe NFC normalization выявлено 125 полных duplicate groups, затрагивающих 307 records. По отдельным ключам повторов больше: 161 повтор по русскому gloss, 200 по Thai form и 206 по phonetic form. Это не означает, что 307 records нужно удалить: одинаковая фраза может быть методически правильной в разных временных и сценарных контекстах.

| Пример | Частота по audit | Решение |
|---|---:|---|
| «спасибо» / `ขอบคุณ` / `кхоп кхун` | 16 по русскому ключу | Один canonical item, отдельные contexts для shop, doctor, condo, social |
| «до свидания» | 9 | Оставить introduction, delayed retrieval и dialogue closure; остальное сократить |
| «сколько стоит» | 7 | Сохранить только при различии market, shop, delivery и service function |
| «счёт пожалуйста» | 6 | Оставить в food/payment как полезное retrieval |
| «дорого» | 6 | Развести market negotiation и polite disagreement |
| «вода» | 5 | Оставить food/health/ordering; лишние повторы заменить compounds |
| «налево/направо» | 3 | Сохранить: это нормальное distributed retrieval в navigation/taxi |

Повтор является **полезным reinforcement**, если он возвращается через интервал, находится в новой задаче и меняет retrieval parameter: audio, speaker intent, distractor, tone contrast, speed или response type. Это **redundant clutter**, если ru + thai + phonetic полностью совпадают, повтор стоит рядом или в несвязанной теме и не добавляет нового tip, prompt или interaction.

### Cleanup plan

Сначала нужно freeze-нуть добавление новых exact duplicates. Затем разобрать top-30 групп, начиная со «спасибо», «до свидания», «сколько стоит», «счёт пожалуйста», «дорого», «вода», «о кэ» и «чек бин». Копии не следует механически удалять: их лучше преобразовывать в cloze, audio discrimination, contrastive task или dialogue response. Удалять можно только запись без нового learning purpose.

На уровне data model рекомендую ввести `canonical_content_id` и `exposure_id`. Все вхождения «спасибо» будут ссылаться на один canonical item, но иметь разные exposure types: `introduce`, `guided_retrieval`, `scenario_transfer`, `mastery_check`. CI должен отклонять exact triple duplicate без `repetition_reason`, `canonical_content_id` и `target_skill`.

## 6. Data contract

Структурные проверки положительные: отсутствующих course IDs нет, courses без lessons нет, duplicate orders нет, gaps нет. Поэтому основной риск находится не в повреждённом каталоге, а в semantics и pedagogy.

У всех 2 268 records заполнены `kind` и `order`. У 2 121 record есть ru/thai/phonetic; 147 — это standalone `tip` records без языковой карточки, что логично. 123 records не имеют `tip`; это допустимо, но для продукта с pronunciation promise полезно различать standalone `tip` и optional `micro_explanation` у phrase/word.

Canonical assets уже существуют: 48 phonetic entries, 5 gloss entries, 1 allow-multi exception list и 190 card tips. Их следует связать с runtime records через IDs. Для Thai duplicate checker должен использовать NFC-safe normalization и сохранять combining marks; иначе автоматический audit будет порождать ложные варианты.

## 7. Рекомендуемый lesson loop

Один урок должен быть коротким повторяемым циклом, а не контейнером из 8–13 карточек.

| Segment | Действие пользователя | Что измеряем |
|---|---|---|
| Hook | Слышит mini-scenario и выбирает намерение | Attention/comprehension |
| Notice | Видит смысл, Thai original и русскую транслитерацию | Form–meaning mapping |
| Listen | Слушает slow и natural version | Auditory discrimination |
| Speak | Записывает попытку | Production |
| Feedback | Получает 1–2 actionable cues | Corrective feedback |
| Retrieval | Вспоминает фразу без полного prompt | Retrieval strength |
| Transfer | Использует фразу в новом mini-dialogue | Functional transfer |
| Exit | Выполняет Can-Do task и видит следующий route | Mastery/next action |

Score должен быть вторичным. Сначала пользователь должен понять, что получилось и какой один элемент улучшить, затем получить retry и transfer. Иначе возникает ощущение игры с рейтингом, а не развития навыка.

## 8. Product funnel и onboarding handoff

Onboarding должен показывать core value одним loop: **Taika объясняет → пользователь слушает → пользователь говорит → Taika показывает feedback → пользователь понимает следующий шаг**. Рекомендуемая последовательность: один dark brand splash; выбор текущего уровня; optional multi-select pain points; phrase demo; listen → speak → feedback; три value cards; отдельный paywall; goals; route confirmation.

Paywall должен быть настоящим отдельным route. Закрытие paywall обязано оставить пользователя на offer или вернуть на предыдущий экран; оно не должно молча переводить его в первый lesson. В текущем preview это отражено как отдельный путь до route summary.

Финальный handoff:

1. `course_b_0 / lesson 1` — «Тайский без паники», короткая ориентация и mental model.
2. После orientation — `course_b_1 / lesson 1` — «Разговорный старт», первый полноценный speaking lesson.
3. После нескольких успешных attempts — `course_b_2`, где tone explanation привязывается к личному voice feedback.

В preview это зафиксировано в `START_ROUTE`: `orientationCourse = course_b_0`, `orientationLesson = 1`, `coreCourse = course_b_1`, `coreLesson = 1`. Для production SwiftUI это нужно заменить на реальный navigation/deep-link contract AppShell.

## 9. Приоритетный план

| Приоритет | Работа | Критерий готовности |
|---|---|---|
| P0 | Canonical IDs и duplicate policy | Top-30 triage завершён; duplicate lint добавлен |
| P0 | Course/lesson Can-Do passport | У каждого course есть entry, outcome, prerequisites, mastery gate |
| P0 | Production onboarding handoff | Close paywall не меняет lesson state; CTA ведёт в `b_0/l1` |
| P1 | Rebuild spine `b_0 → b_1 → b_2` | В каждом уроке есть listen, speak, feedback, retrieval, transfer |
| P1 | Persona task entry points | Taxi, market, food, doctor, condo, immigration доступны как jobs |
| P1 | Safety-critical branches | Doctor/police/immigration имеют clarify/repeat/help branches |
| P2 | SIM/internet/utilities audit | Coverage подтверждена или добавлены новые routes |
| P2 | Learning analytics | Измеряются retry, D+1/D+7 recall и transfer, а не только opens |

## 10. Метрики после релиза

Completion rate недостаточен. Для первого пути нужно измерять first voice attempt rate, время до первой записи, feedback retry rate, delayed recall через 24 часа и 7 дней, transfer success в новом scenario, paywall-close continuation и переход `b_0/l1 → b_1/l1`.

| Metric | Что проверяет |
|---|---|
| First voice attempt rate | Понятна ли core value без объяснения support |
| Feedback retry rate | Хочет ли пользователь применить feedback |
| D+1/D+7 retrieval | Сформировалась ли retention, а не только recognition |
| Scenario transfer | Работает ли фраза вне исходной карточки |
| Paywall close continuation | Честно ли ведёт себя funnel |
| Start route completion | Сработал ли handoff в первый курс |

## Финальный вывод

Taika не нужно превращать в ещё один textbook и не нужно срочно переписывать все 42 курса. Нужно сохранить широту библиотеки и построить поверх неё узкую доказательную spine-траекторию: `b_0 → b_1 → b_2 → b_3/b_4 → task-based life routes`. Остальные курсы должны открываться через persona jobs, а не через плоский список.

Ближайшая работа — не добавлять ещё слова, а сделать существующие единицы методически различимыми: где introduction, где retrieval, где transfer, где mastery check и почему конкретная фраза возвращается. Вместе с canonical IDs, Can-Do outcomes и корректным onboarding handoff это превратит Taika из набора красивых карточек в персональную кун кру, которая действительно помогает русскоязычному пользователю жить и говорить в Таиланде.

## References

[1]: https://www.coe.int/en/web/common-european-framework-reference-languages/the-action-oriented-approach "Council of Europe — The action-oriented approach"

[2]: https://www.actfl.org/educator-resources/ncssfl-actfl-can-do-statements "ACTFL — NCSSFL-ACTFL Can-Do Statements"

[3]: https://www.edresearch.edu.au/guides-resources/practice-guides/spacing-and-retrieval-practice-guide-full-publication "Australian Education Research Organisation — Spacing and retrieval practice guide"

## Internal audit artifacts

`audit_inputs/lessons.json` · `audit_inputs/steps.json` · `audit_inputs/taikafm.json` · `audit_inputs/curriculum_lemma_canon.json` · `content_quality_analysis.json` · `audit_findings_extract_v2.txt` · `cross_source_summary.txt` · `course_metrics_table.md`
