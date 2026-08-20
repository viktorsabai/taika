# Owner-level verdict: «Тайский для долгожителей»

## Verdict

Категория Long после этой migration получила полноценный educational contract и сценарную рамку для платной линейки. Контент не расширялся искусственно по квоте: сохранены все usable cards, удаление или замена допустимы только там, где материал был нерелевантным, небезопасным или семантически слабым.

## As-is → To-be

| Слой | Было | Стало |
|---|---|---|
| Course promises | У части курсов description отсутствовало в lessons source, а public promise не был связан с outcomes | Для всех 7 курсов синхронизированы title, description и scenario outcomes |
| Lesson contracts | 43 урока с пустыми outcomes | У каждого урока есть один короткий наблюдаемый outcome от лица действия пользователя |
| Card counts | Часть counts не совпадала с фактическими items | Все 43 Long card counts синхронизированы |
| Immigration | Полезные слова, но мало следующего шага и официального контекста | Добавлены спокойная навигация, отказ/документы, штраф и reminder сверять актуальные требования с официальным офисом |
| Banking/crypto | Словарь операции и перевода, но слабая security branch | Добавлена явная защита OTP/SMS-кодов и проверка официального приложения/реквизитов |
| Medicine/insurance | Сильный словарь, но недостаточно safety framing | Добавлены симптомы/аллергии/страховка/ассистанс с disclaimer, что диагноз и лечение подтверждает специалист |
| Transport | Есть аренда и шлем, но часть copy романтизирует «как местный» | Сохранены usable transport cards, а lifestyle copy переписан вокруг прав, шлема, страховки и решения не ехать при риске |
| Condo | Словарь дома и жалоб, но generic labels в финале | Outcomes ведут от просьбы и правила к нейтральному сообщению, office escalation и meeting participation |
| Pets | Словарь ветклиники, прививок и отеля | Добавлены observable outcomes для визита, symptom description, grooming и pet travel; диагноз не подменяется карточкой |
| Humor/pop culture | Есть тренды, 555, TikTok и дорамы, но много meta-labels | Добавлены register/context rules, актуальность тренда, проверка реакции и safety boundaries для шуток |

## Quality gate

| Проверка | Результат |
|---|---:|
| Long courses | 7 |
| Long lessons | 43 |
| Long cards | 357 |
| Non-empty outcomes | 43/43 |
| Card-count alignment | 43/43 |
| Invalid prerequisites | 0 |
| Long educational/structural gate | 0 issues |
| Long scope against pushed HEAD | 0 non-Long changes |
| JSON integrity | Passed |

## Remaining program-level backlog

Full-program metrics после Long показывают 42 курса, 267 уроков и 2325 карточек. Вне Long остаются 36 empty outcomes и 10 stale card counts в «Тайском для души», а также 2 inconsistent duplicate Thai phonetic forms и уже известные global phonetic findings. Эти проблемы относятся к следующей категории или отдельному final-program pass и не являются скрытыми Long regressions.

## Owner decision

**Long готов к review, но не к push без отдельного approval.** Категория теперь выдерживает owner-level content gate: каждая карточка и каждый урок имеют место в сценарии, а high-stakes sections получили safety framing.
