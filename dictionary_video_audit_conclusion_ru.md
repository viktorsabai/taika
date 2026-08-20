# Taika Dictionary — owner-level video audit

## Verdict

Текущий словарь действительно находится примерно на уровне **3/10**. Проблема не в одном плохом отступе или icon, а в том, что в приложении одновременно существуют несколько presentation layers одной функции: header shortcut, Quick Drawer, Speaker list, Speaker dictionary overlay и Favorites dictionary tab/legacy state. Пользователь не получает единого понятного объекта «Мой словарь».

Главная ошибка — мы пытались сделать dictionary быстрым utility layer, но оставили его реальным владельцем данных и действий внутри Speaker. В результате Quick Drawer показывает preview, Full Dictionary фактически ведёт в Speaker, а управление фразой снова происходит через Speaker menu и отдельный overlay.

## Observed flow from recording

| Время | Действие | Что видит пользователь | Проблема |
|---|---|---|---|
| 00:00 | Тап по верхней иконке с числом 1 | Открывается «Мой словарь» | Иконка похожа на badge/закладку, смысл неочевиден |
| 00:01 | Drawer показывает личную фразу | Preview одной фразы | Быстрый preview сам по себе понятен, но внутри почти нет действий |
| 00:02 | «Открыть весь словарь» | Переход в Speaker | Кнопка обещает Dictionary, а ведёт в другой продуктовый раздел |
| 00:03 | Меню `...` у фразы в Speaker | Training / Open Dictionary / Copy / Delete | Для базовой операции слишком глубокий путь |
| 00:06 | «Открыть словарь» | Отдельный Dictionary overlay | Третий словарьный chrome поверх Speaker |
| 00:12 | Тап по audio | Аудио запускается | Работает, но действие спрятано в промежуточном overlay |
| 00:15 | Удаление | Фраза исчезает из Speaker | Удаление не синхронизирует Quick Drawer |
| 00:19 | Возврат в Favorites и повторный header tap | Drawer снова показывает удалённую фразу | Критический stale-state bug |
| 00:20–00:47 | Favorites → hacks → courses → lesson → like phrase | Course phrase появляется в Favorites | Это отдельный корректный pipeline и его нельзя смешивать с My Dictionary |
| 00:47 | Повторный header tap | Drawer всё ещё показывает старую deleted phrase | State separation и refresh contract сломаны |

## Root causes in implementation

| Root cause | Техническое проявление | Приоритет |
|---|---|---:|
| Не существует одного Dictionary owner screen | Quick Drawer и Speaker dictionary sheet используют `smartSpeakerDictionaryCardsDTO`, но управление остаётся в `SpeakerDS` | P0 |
| Full Dictionary route не является полноценным CRUD screen | Drawer CTA в текущей реализации запускает route, а пользователь всё равно попадает в Speaker/legacy dictionary path | P0 |
| Quick Drawer имеет только `onSpeak` action | `DictionaryDrawerRow` даёт audio/переход в Speaker, но не edit, delete, copy, repeat или context actions внутри dictionary | P0 |
| Delete не имеет единого refresh/invalidation contract | `FavoriteManager.remove` меняет источник, но drawer/header не получают гарантированный immediate refresh после удаления | P0 |
| Дублируются icon meanings | Bookmark используется в старом Speaker dictionary chip, books glyph — в Quick Drawer/Main, heart — в Favorites | P1 |
| Favorites сохраняет legacy `.dictionary` case | В видимых tabs case уже можно скрывать, но код и старые states продолжают существовать | P1 |
| Naming меняется по экранам | «Мой словарь» → «Спикер» → «Словарь» | P1 |
| Phonetic rendering visually collides | Arrows/superscripts visually overlap in Speaker phrase presentation | P1 |
| Drawer is a preview but visually pretends to be full screen | Large panel, huge empty state, large CTA, no inline management actions | P1 |

## What must not be merged

Критически важно не объединять следующие сущности:

| Сущность | Содержание |
|---|---|
| Favorites → Courses | Сохранённые курсы пользователя |
| Favorites → Cards | Сохранённые карточки из курсов |
| Favorites → Hacks | Сохранённые лайфхаки |
| My Dictionary | Только личные фразы, созданные пользователем через Speaker |
| Quick Drawer | Быстрый preview My Dictionary |
| Full Dictionary | Единственный экран управления My Dictionary |

Фраза из урока, которую пользователь лайкнул, не должна автоматически попадать в My Dictionary. И личная Speaker-фраза не должна появляться в Favorites Cards.

## Target product model

```text
Header/Main compact button
        ↓
Quick Drawer: последние 3–5 личных фраз
        ↓
Full Dictionary: все личные фразы + действия
        ├── прослушать
        ├── тренировать
        ├── копировать
        ├── редактировать
        └── удалить
```

Quick Drawer не должен вести в Speaker для обычных dictionary actions. Speaker нужен для создания новой фразы и голосовой тренировки, но не должен быть владельцем списка словаря.

Внутри Full Dictionary каждая карточка должна иметь один компактный `...` или context menu с действиями: `Послушать`, `Тренировать`, `Скопировать`, `Изменить`, `Удалить`. Audio и delete должны работать прямо внутри Dictionary. После любого mutation header count, drawer list и full list должны обновляться через один published store/invalidation signal.

## Target UI decisions

1. На Main оставить один компактный entry point в существующей action zone. Не добавлять edge-tab.
2. В header использовать один glyph для My Dictionary во всех состояниях. Bookmark оставить исключительно для Favorites; если команда решит вернуть bookmark как brand symbol, он должен быть только словарным и не использоваться для Favorites.
3. Quick Drawer сделать preview, а не псевдо-fullscreen: 3–5 строк, быстрый audio, `...`, `Все фразы`.
4. Full Dictionary сделать настоящим самостоятельным screen с единым названием **«Мой словарь»**.
5. Убрать `Открыть весь словарь → Speaker`. CTA должен открывать `DictionaryView` напрямую.
6. Убрать постоянный текст про swipe; оставить standard close/drag affordance.
7. Drawer должен закрывать underlying app header; нельзя показывать два header слоя одновременно.
8. Empty state должен быть компактным и объяснять одно действие: «Создай фразу в Speaker — она появится здесь».

## Acceptance criteria before next implementation

| Критерий | Pass condition |
|---|---|
| Fast entry | С Main до последней личной фразы максимум 1 tap |
| Full route | `Все фразы` открывает самостоятельный DictionaryView, не Favorites и не Speaker |
| Inline management | Audio/copy/train/delete работают из Full Dictionary без перехода в Speaker |
| State sync | Delete/add/edit обновляют badge, drawer и full list в том же UI cycle |
| Separation | Course likes/hacks/courses не попадают в My Dictionary и наоборот |
| Icon consistency | Один dictionary glyph; bookmark/heart не имеют двойного смысла |
| Naming | «Мой словарь» используется в header, drawer и full screen |
| Back behavior | Close/back возвращает в исходный экран без потери scroll/tab context |
| Empty state | Нет большого пустого поля и лишнего CTA stack |
| Phonetics | Стрелки читаются без overlap на реальном iPhone font size |

## Owner decision

Текущую feature branch нельзя считать готовой к production merge. Следующий pass должен быть не косметическим: нужно перенести ownership dictionary actions из Speaker overlay в отдельный Full Dictionary screen, добавить inline actions и единый observable refresh contract. Только после этого имеет смысл повторно оценивать spacing, gradients и motion.
