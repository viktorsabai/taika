# My Dictionary — нативная product-модель Taika

## Короткий ответ владельцу

Да, словарь можно сделать нативно. Но нужно перестать строить его как цепочку окон вокруг Speaker. **Speaker создаёт и тренирует личные фразы. My Dictionary хранит и управляет ими. Favorites хранит контент Taika.** Это три разных ownership-а.

Сейчас существующий `FavoriteManager` уже содержит правильную базовую границу: личные фразы определяются как `courseId == "user_dict"` и `lessonId == "smart_speaker"`; производный список — `smartSpeakerDictionaryCardsDTO`. Проблема не в отсутствии данных, а в том, что UI отправляет пользователя обратно в Speaker и показывает несколько разных presentation layers.

## Canonical user story

```text
Пользователь видит Main
    ↓ один компактный вход «Мой словарь»
Открывается My Dictionary screen
    ↓
Список личных фраз
    ├── ▶ Послушать
    ├── ⋯ Действия
    ├── свайп row → удалить
    └── tap row → раскрыть детали
         ├── тренировать в Speaker
         ├── скопировать
         ├── изменить
         └── удалить
```

Quick Drawer не нужен как обязательный промежуточный слой. Если мы оставляем его для быстрого доступа из Home/Speaker, он должен быть только **preview**, а не отдельной версией словаря:

```text
Header icon → Quick Preview (3 recent phrases) → «Все фразы» → My Dictionary
```

Важное правило: **«Все фразы» никогда не ведёт в Speaker и никогда не ведёт в Favorites filter.**

## Ownership model

| Объект | Источник | Где показывается | Что можно сделать |
|---|---|---|---|
| Course | `CourseData` / catalog | Courses/Main | Открыть курс, продолжить |
| Course card | `FavoriteManager.items`, обычный card item | Favorites → Карточки | Послушать, тренировать, убрать из избранного |
| Course hack | `FavoriteManager.items`, hack item | Favorites → Лайфхаки | Открыть lesson, убрать из избранного |
| Personal phrase | `FavoriteManager.items` с `user_dict/smart_speaker` | My Dictionary | Audio, train, copy, edit, delete |
| Quick Preview | derived prefix из personal phrases | быстрый drawer/preview | Audio, открыть phrase actions, перейти в Full Dictionary |

Personal phrase не должна попадать в Favorites → Карточки. Course card не должна попадать в My Dictionary только потому, что пользователь нажал heart.

## Рекомендуемый экранный уровень

### Main

На Main не добавляем боковую закладку и не строим новую крупную секцию. В существующей utility/action zone остаётся одна компактная кнопка:

```text
[ Разминка · 9ч 55м ]   [ ▤ Мой словарь 3 ]
```

В header можно сохранить тот же dictionary shortcut как глобальный быстрый вход, но glyph и label должны быть одинаковыми. Не использовать bookmark для словаря, если bookmark уже означает Favorites.

### My Dictionary

Это должен быть **полноценный root-like screen**, а не sheet поверх Favorites и не экран Speaker.

```text
‹ Назад       Мой словарь                 ▤
              Твои фразы для жизни в Таиланде

[ Все ] [ Последние ] [ На повторение ]

┌──────────────────────────────────────┐
│ Как ваши дела                    🔊 ⋯ │
│ са-бай ди-май кхрап                 │
│ сабайдиครับ                         │
│                                     │
│ [ Тренировать ]                     │
└──────────────────────────────────────┘
```

Основной экран не должен показывать одновременно Favorites header, drawer header и Speaker header. У него один title, один back affordance и один dictionary glyph.

### Phrase row actions

Пользователь должен иметь возможность управлять фразой **без перехода в Speaker**.

| Действие | Поведение |
|---|---|
| Tap audio | Проигрывает Thai audio прямо в row |
| Tap row | Раскрывает вторую строку действий или открывает compact detail sheet |
| `⋯` | Показывает `Тренировать`, `Скопировать`, `Изменить`, `Удалить` |
| Swipe left | Delete с native confirmation/undo toast |
| Тренировать | Переводит в Speaker training mode, но только как осознанный action |
| Изменить | Открывает edit sheet, не Speaker list |
| Удалить | Мгновенно меняет store и UI, показывает Undo |

Не нужно делать пять постоянных кнопок в каждой карточке. В спокойном состоянии row содержит только phrase content, audio и `⋯`; остальные действия раскрываются по требованию.

## State model для SwiftUI

Нужен один observable store или единый published mutation contract поверх существующего `FavoriteManager`:

```swift
enum DictionaryPresentation {
    case closed
    case quickPreview
    case full
    case edit(FDCardDTO)
    case actions(FDCardDTO)
}

@MainActor
final class DictionaryStore: ObservableObject {
    @Published private(set) var phrases: [FDCardDTO] = []
    @Published var presentation: DictionaryPresentation = .closed
    @Published var playingPhraseID: String?
    @Published var pendingDeletion: FDCardDTO?

    func reloadFromFavorites()
    func play(_ phrase: FDCardDTO)
    func copy(_ phrase: FDCardDTO)
    func beginEdit(_ phrase: FDCardDTO)
    func delete(_ phrase: FDCardDTO)
    func undoDelete()
    func train(_ phrase: FDCardDTO)
}
```

На первом этапе можно не создавать второй persistent database: `FavoriteManager` уже владеет items. Но UI должен подписываться на `FavoritesDidChange` и вызывать `reloadFromFavorites()` синхронно после add/delete/edit. `smartSpeakerDictionaryCardsDTO` остаётся derived source, а не кэшом, который живёт отдельно.

## Navigation model

```swift
NavigationIntent.Route.dictionary
```

Этот route открывает `DictionaryView`, а не меняет `FavoritesFilterState`. Quick Preview использует `onOpenFullDictionary { nav.set(.dictionary) }`. Speaker navigation вызывается только из явной кнопки `Тренировать` или `Открыть Speaker`, а не как скрытая реализация `Все фразы`.

Legacy `FavoriteScreenTab.dictionary` можно временно оставить для data compatibility, но он не должен входить в visible `mvpTabs` и не должен быть destination для нового user flow.

## Empty state

Пустой словарь должен быть спокойным и коротким:

```text
▤
Мой словарь пока пуст
Скажи первую фразу в Speaker и сохрани её сюда.
[ Открыть Speaker ]
```

Без огромной пустой панели, без двойного CTA и без текста-инструкции про свайп.

## Что исправляет текущие реальные проблемы

| Проблема из screen recording | Решение |
|---|---|
| Deleted phrase остаётся в Quick Drawer | Unified store reload после `FavoriteManager.remove` и observer на `FavoritesDidChange` |
| Верхняя цифра не объясняет себя | Один dictionary glyph + label/accessibility + компактный «Мой словарь» entry |
| `Открыть весь словарь` ведёт в Speaker | Direct `NavigationIntent.Route.dictionary` |
| Внутри словаря ничего нельзя сделать | Actions живут в phrase row/full dictionary |
| Speaker, Dictionary и Favorites визуально смешаны | Один ownership screen и отдельные routes |
| Different icons | Один books/dictionary glyph; heart/bookmark не используются для личного словаря |
| Пять переходов для удаления | Row `⋯` или swipe → delete/undo прямо в Dictionary |
| Фонетика плохо читается | Отдельная phonetic text style, line height и baseline-safe arrow rendering |

## Owner acceptance criteria

Новая версия считается нативной и эффективной, если пользователь может:

1. Открыть My Dictionary с Main максимум одним очевидным tap.
2. Понять по title, что это личные фразы, а не Favorites и не Speaker.
3. Прослушать, скопировать, потренировать и удалить phrase без обходного меню Speaker.
4. Открыть Speaker только как намеренный training/create action.
5. После delete сразу увидеть новый count и исчезновение phrase во всех dictionary presentations.
6. Вернуться назад ровно в исходный экран без потери tab/scroll context.
7. Не встретить больше одного визуального смысла для одного glyph.
8. Не видеть в Favorites личные Speaker-фразы и не видеть в Dictionary course likes/hacks.

## Финальное решение

Я бы остановил текущую drawer-heavy реализацию и строил следующий pass вокруг **Full Dictionary как главного продукта**, а Quick Preview оставил бы только как необязательный shortcut. Сначала делаем правильный самостоятельный screen и действия внутри него; затем подключаем preview. Не наоборот.
