# Full card-by-card review — Thai for Life L1–L15

## Scope

После полного review проверены 15 курсов, 104 урока и 851 phrase records с обязательными tone arrows. Уже полностью пересобранный Police Stop L1 и ранее проверенные housing L13 и delivery L14 сохранены в общем working tree. Остальные курсы прошли targeted card-by-card review: исправлялись только подтверждённые semantic mismatches, meta-cards и missing scenario branches.

## Последние batches

| Batch | Курсы | Ключевые изменения |
|---|---|---|
| 1 | L7 Beach, L8 Shop, L9 Emergency, L10 Gym | Добавлены beach safety tips про флаги/течение/спасателя; удалены store meta-cards; удалена emergency RU↔Thai ошибка `Человек плохо`; уточнён `Приятно устал`. |
| 2 | L11 Festivals, L12 Salon, L2 Taxi, L3 Market | `Фонарики` → `Кратонг`; `Новолуние` → `Полнолуние`; `Веселья` → `Весело`; удалены market/salon meta-cards; `Давай по-честному` → `Реальная цена`; уточнено `Когда вам удобно?`. |
| 3 | L4 Food, L5 Pharmacy, L6 Hotel, L15 Nightlife | Удалена fixed-duration medical card `Таблетки на неделю`; добавлен safety tip про дозировку и обращение к врачу; исправлено `Спасибо почините` → `Спасибо, что починили`; удалены hotel/nightlife journey meta-cards; добавлен safe-exit tip для nightlife. |

## Already rebuilt courses

| Курс | Состояние |
|---|---|
| L1 Police Stop | Полный 7-lesson roadside rebuild: права, документы на байк, шлем, пассажир, маршрут, repair, штраф/квитанция, passport branch. |
| L13 Housing | Card-by-card pass: протечка, оплата, кондиционер, мастер, доступ, follow-up, соседи. |
| L14 Delivery | Card-by-card pass: адрес с этажом/входом/телефоном, трек, курьер, получение, проверка, delay/damage/support. |

## Финальная validation

| Check | Result |
|---|---:|
| L courses | 15 |
| L lessons | 104 |
| Items according to audit | 976 |
| Phrase records with phonetics | 851 |
| Category validator errors | 0 |
| Card-count mismatches | 0 |
| Strict tone-arrow errors | 0 / 851 |
| Police Stop regression errors | 0 |
| Contextual tips | 104 / 104 |
| `git diff --check` | Passed |

Universal phrases such as `спасибо`, `счёт`, `дорого`, `сколько стоит?` and `до свидания` remain as documented duplicate notes. They are not automatically deleted because some repetition is pedagogically natural across independent scenarios; the report marks them for final editorial decision rather than silently removing useful Thai.

All production JSON changes remain local until the single category commit is created. The report and scripts are not part of production curriculum files.
