# Финальный ownership map не-базовых курсов Taika

**Статус документа:** content architecture / draft approval map. Этот документ фиксирует, какой курс владеет каким навыком, но не является подтверждением финальных тайских формулировок и не запускает production migration.

**Canonical branch:** `2026-01-21-k7hb-d2004`

## 1. Правило ownership

> Один курс владеет не местом, где происходит разговор, а основным коммуникативным навыком, который пользователь должен унести из курса.

Например, слово «счёт» может встречаться в отеле и ресторане, но самостоятельный checkout-skill не должен быть продан пользователю как новый outcome в каждом курсе. Если phrase имеет одинаковый intent, используется один canonical phrase ID с несколькими контекстными входами. Если intent отличается, создаётся отдельная phrase variant с явным контекстом.

### Типы повторного использования

| Тип | Правило | Пример |
|---|---|---|
| **Canonical shared phrase** | Одна и та же короткая функция используется в нескольких доменах и хранится через один phrase ID. | «не понял», «ещё раз», «медленнее» |
| **Contextual variant** | Перевод похож, но объект или коммуникативная функция отличаются. Нужен отдельный context/intent, не просто копия текста. | «пакет» на рынке и «пакет» на кассе |
| **Owner-only phrase** | Фраза является частью уникального outcome одного курса и не должна появляться в соседних курсах без ссылки. | «сдачи не надо» в taxi/payment flow |
| **Notes / advanced** | Закон, медицина, культурное объяснение, стратегия или меняющийся тренд не входят в обязательный learnable denominator. | визовые правила, insurance eligibility, Buddhist concepts |

## 2. Canonical map: 30 курсов

| ID | Курс | Основной owner / outcome | Не является owner | Shared / cross-reference rule |
|---|---|---|---|---|
| `course_l_7` | Пляж как состояние | Пляжная навигация, безопасность у воды, короткие просьбы на месте | Туризм, еда, транспорт, аренда в глубину | «подождите», «всё хорошо», «я пойду» — shared; boat/transit — отдельные owners |
| `course_l_6` | Белый лотос на максималках | Hotel stay: номер, housekeeping, checkout и базовый запрос помощи | Общий repair/service, landlord, condo rules | «счёт, пожалуйста» — только при hotel checkout context; canonical phrase candidate |
| `course_l_11` | Сезон Сонгкрана и не только | Участие в фестивале, вода, фото, границы и безопасный exit | Общая культура Таиланда, пляж, humour trends | «осторожно», «можно фото?» — context-specific; cultural explanation — notes |
| `course_l_13` | Хозяин дома — почти сосед | Коммуникация с landlord: проблема, визит, доступ, результат ремонта | Отель, condo management, generic service | «во сколько?» — shared time phrase; «счёт» не делать отдельным outcome без подтверждения owner |
| `course_l_15` | После заката всё интереснее | Вечерний контакт: заказ, small talk, границы, завершение вечера | Полный romance course, food course, bar culture | «не хочу», «я пойду» — shared boundary/exit IDs; romance depth — `course_s_5` |
| `course_l_3` | Король рынка | Market purchase: цена, количество, торг, взвешивание, упаковка | Retail checkout, food ordering, replacement dialogues | «пакет» — contextual variant candidate with shop; bargaining phrases owner-only |
| `course_l_12` | Новый тайский образ | Beauty service: стрижка, массаж, борода, запись, боль/комфорт, оплата | Generic service, medicine, hotel | «больно», «остановитесь» — shared safety phrase IDs; service object stays beauty-specific |
| `course_l_8` | Магазинные приключения | Retail flow: найти товар, цена, касса, скидка, пакет, обмен | Market bargaining, food restaurant, replacement survival course | «пакет» — contextual variant candidate; «обмен можно?» owner-only |
| `course_e_5` | Коды Таиланда | Cultural pragmatics: понять культурный код и безопасно уточнить смысл | Grammar, slang, full cultural encyclopedia | «можно уточнить?», «не понял» — shared repair IDs; explanations move to notes |
| `course_long_4` | Транспорт для своих | Mobility system: rental, helmet, public transport, insurance/safety basics | Taxi trip, police stop, delivery | «подождите» shared; «шлем есть?» and rental safety owner-only |
| `course_l_14` | Таиланд доставляет | Delivery: order status, address, courier, delay, receiving issue | Retail checkout, landlord repair, taxi transport | «где заказ?» delivery-specific; generic «ещё не приехал» can be shared only as status variant |
| `course_l_5` | Доктор Тайка дежурит | Basic medical navigation: symptom, pharmacy/clinic, next question | Insurance policy, emergency response, diagnosis | Medical phrases require native/medical QA; explanations and dosage warnings — notes |
| `course_e_2` | Работа с тайцами | Workplace micro-actions: request, status, deadline, reminder, confirmation | Conflict de-escalation strategy, finance, visa/work law | «когда будет?», «готово?» can be shared functional IDs; workplace context remains owner |
| `course_long_2` | Банки, деньги, крипта | Everyday finance navigation: account, transfer, fee, ATM/basic transaction | Investment advice, legal eligibility, tax, crypto strategy | Financial/legal details — notes; all action wording requires domain QA |
| `course_l_2` | Таксист, вези меня домой | Taxi trip: destination, route, price, stop, payment, exit | General transport system, rental, police, delivery | «остановите здесь» taxi owner; «сдачи не надо» payment context only |
| `course_long_3` | Полная медицина и страховка | Medical system depth: clinic/insurance interaction and next-step questions | Basic symptom survival, emergency commands | Insurance eligibility, claim rules and coverage — advanced notes; medical QA mandatory |
| `course_s_5` | Романтика по-тайски | Interest, invitation, status, consent/boundaries and respectful exit | Evening bar flow, hobby invitation, sexual/relationship advice | «не хочу», «просто поговорим» shared boundary IDs; register/consent QA mandatory |
| `course_long_1` | Виза, продление, иммиграция | Administrative navigation: documents, appointment, fees, status and deadline questions | Legal advice, eligibility decisions, work law | Current rules and document requirements — notes with update policy |
| `course_l_4` | Вселенная тайской еды | Food ordering: dish, spice, restrictions, quantity, additions, bill | Market price/bargaining, retail checkout, generic service | «счёт, пожалуйста» food/hospitality canonical candidate; allergy wording requires QA |
| `course_s_2` | Хобби и движ по-тайски | Light social hobby: ask, invite, schedule, join/decline | Romance depth, event logistics, generic small talk | «во сколько?», «до встречи» shared; activity noun stays contextual |
| `course_s_3` | О чём говорят на самом деле | Pragmatic slang: reaction, clarification, implied meaning and safe exit | Full cultural code course, current meme/trend course | «это шутка?», «не понял» shared; slang register requires native QA |
| `course_long_5` | Соседи, кондо, правила дома | Condo communication: noise, rules, management, meeting, non-conflict request | Landlord repair, generic conflict strategy | «можно тише?» condo/noise owner; repair routes to `course_l_13` |
| `course_e_4` | Разговоры без конфликта | De-escalation phrases: apology, pause, clarification, solution, exit | Abuse/safety response, workplace negotiation depth | «извините», «давай спокойно», «что делать?» shared/functional; strategy in tips |
| `course_s_6` | Тай кидс | Child-facing safety, praise, play, boundaries and parent contact | Food ordering, beach safety, medical child care | «осторожно», «стоп», «держись за руку» contextual child-safety variants |
| `course_s_1` | Тайский для блогинга | Social content: caption, reaction, comment, direct reply and posting etiquette | General Thai grammar, influencer business strategy | «спасибо», «отвечу позже» shared; platform-specific workflow — notes |
| `course_long_6` | Питомцы в Таиланде | Pet care navigation: vet, symptoms, grooming, pet-friendly places, travel questions | Human medicine, generic service, immigration | Travel documents and airline policy — notes; safety wording requires QA |
| `course_e_1` | Понятный тайский | Repair communication: repeat, slow down, clarify, confirm, soften | Cultural code explanation, conflict strategy, grammar lecture | Canonical owner for repair toolkit; other courses reference shared IDs |
| `course_l_9` | Срочная помощь | Emergency commands and essential facts: help, urgency, police/ambulance, address | Full police procedure, medical diagnosis, legal explanation | Safety-critical wording and current numbers require dedicated QA |
| `course_long_7` | Тайский юмор, мемы, поп-культура | Safe reactions, joke clarification, tone, exit from awkward humor | Slang encyclopedia, current trend catalog | Trends are optional notes; «шучу», «не обижайся» need register QA |
| `course_s_4` | Ретрит и внутренний сабай | Retreat navigation, respectful questions, schedule, participation and exit | Buddhist doctrine, spiritual counseling, cultural encyclopedia | Concepts move to cultural notes; practical navigation remains learnable |

## 3. Canonical shared phrase families

Эти фразы могут встречаться в нескольких курсах, но не должны создавать отдельный уникальный outcome в каждом из них. Их нужно хранить как shared phrase IDs с контекстным использованием.

| Семейство | Примеры | Canonical owner / policy |
|---|---|---|
| Repair | «не понял», «ещё раз», «медленнее», «можно уточнить?» | `course_e_1`; остальные курсы ссылаются на shared IDs |
| Confirmation | «правильно?», «понял», «всё хорошо» | Shared utility; контекст добавляется через lesson/scene |
| Pause | «подождите», «сейчас», «потом» | Shared utility; не считать уникальным skill каждого курса |
| Exit | «я пойду», «до встречи», «до свидания», «спасибо» | Shared exit family; course-specific reason остаётся в scene |
| Boundary | «не надо», «не хочу», «осторожно», «стоп» | Shared IDs только при одинаковой функции; child/safety/romance получают contextual variants |
| Time | «когда?», «во сколько?», «сегодня?», «завтра?» | Shared time family; object и owner должны быть явны |
| Cost | «сколько?», «дорого», «скидка есть?» | Не единый owner для всех: market/retail/food/taxi/beauty различаются intent-ом |

## 4. Реальные overlap-кандидаты на ручной QA

### Высокий приоритет

| Кандидат | Курсы | Решение |
|---|---|---|
| «счёт, пожалуйста» | `course_l_4`, `course_l_6`, `course_l_13`, `course_l_15` | Food/hospitality canonical phrase candidate. В жилье и evening оставить только при подтверждённом отличающемся intent; иначе cross-reference. |
| «пакет» | `course_l_3`, `course_l_8` | Сначала проверить Thai и action: упаковка товара на рынке vs пакет на кассе. Один ID при одинаковом intent, contextual variants при различии. |
| Repair toolkit | `course_e_1`, `course_e_4`, `course_e_5`, `course_s_1`, `course_s_3`, `course_long_7` | Canonical owner `course_e_1`; остальные не дублируют урок, а используют shared IDs. |
| Time/status questions | `course_e_2`, `course_l_6`, `course_l_7`, `course_l_13`, `course_s_2` | Shared phrase family; объект и действие должны быть частью context, не новым переводом. |
| Boundaries / exit | `course_l_15`, `course_s_5`, `course_e_4`, `course_s_6`, `course_s_4` | Смысл различается по safety/register; не копировать слепо, провести native QA. |

### Средний приоритет

| Кандидат | Курсы | Проверка |
|---|---|---|
| «готово?», «когда будет?» | work, service, delivery, hotel | Разделить status request и completion confirmation. |
| «дорого», «сколько?» | market, shop, food, taxi, evening | Не считать одинаковым outcome; объект оплаты должен быть явен. |
| «помогите», «что делать?» | medical, emergency, service, conflict, pets | Safety/medical/emergency contexts требуют отдельного register и QA. |
| «можно?», «участвовать можно?» | retreat, condo, hobby, culture, pet-friendly | Проверить permission object; phrase without object is not a complete target. |

## 5. Что это означает для будущей миграции

До миграции нужно не просто удалить одинаковые русские строки. Нужно ввести или подтвердить в content model четыре понятия:

1. `canonical_phrase_id` — единый reusable phrase;
2. `intent` — коммуникативная функция;
3. `context_owner` — курс, который объясняет и проверяет применение;
4. `variant_of` — контекстная версия базовой фразы.

Только после этого можно безопасно обновлять `steps.json`. Иначе мы либо получим реальные дубли, либо удалим полезные сквозные survival-фразы, которые должны быть доступны в нескольких сценариях.

## 6. Финальный статус

| Этап | Статус |
|---|---|
| Per-course drafts по 30 курсам | Готово |
| Exact overlap inventory | Готово |
| Shared phrase families | Сформированы |
| Canonical ownership map | Сформирован как draft architecture |
| Native/medical/legal QA | Не проведён |
| Production migration | Не начата массово |

**Главный вывод:** после этого map потенциальные дубли не должны мигрировать буквально. Сначала canonical phrase IDs и контекстные варианты; затем — один пилотный кластер и contract QA.
