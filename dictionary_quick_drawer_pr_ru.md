# PR: Dictionary Quick Drawer

## Краткое описание

Добавляет отдельный быстрый доступ к личному словарю Taika в native SwiftUI. Словарь больше не является трудно обнаруживаемым фильтром внутри «Избранного» и не открывается маленьким нечитаемым окном из Speaker. Он становится отдельным utility layer, который открывается из header или через правую edge-tab поверх текущего экрана.

## Branch / commit

- Branch: `feature/dictionary-quick-drawer`
- Commit: `a1cb6256e9b90674cfc0db413a1d014b7d0bee98`
- Base: production HEAD `95ffb64`
- Pull request URL: https://github.com/viktorsabai/taika/pull/new/feature/dictionary-quick-drawer

## Product intent

Личный словарь содержит фразы, которые пользователь сам создал через Speaker. Это отдельная ценность Taika и не то же самое, что фразы, сохранённые из курсов. Поэтому Quick Drawer не смешивает user dictionary с Favorites cards, не меняет Speaker flow и не создаёт новый источник данных.

## User flow

1. На Home, Speaker или Favorites пользователь видит отдельную dictionary icon в app header с количеством личных фраз.
2. Пользователь может нажать на icon или потянуть небольшую pink/lilac edge-tab справа.
3. Справа выезжает readable glass drawer поверх текущего экрана. Underlying context сохраняется.
4. Drawer показывает до пяти последних личных фраз из существующего `FavoriteManager.smartSpeakerDictionaryCardsDTO`.
5. Каждую фразу можно открыть в Speaker через speaker action.
6. `Открыть весь словарь` переводит в существующий полноценный Favorites → Словарь route.
7. Drawer закрывается крестиком, tap по scrim или свайпом вправо. Пользователь возвращается ровно на исходный экран.

## Что изменено

| Файл | Изменение |
|---|---|
| `taika/Favorites/DictionaryQuickDrawerView.swift` | Новый right-side drawer, empty state, readable phrase rows и edge-tab gesture |
| `taika/Theme/OverlayPresenter.swift` | Новый overlay case `dictionaryQuickDrawer` |
| `taika/Theme/AppShell.swift` | Centralized drawer presentation, full-dictionary route, Speaker return route и root edge-tab |
| `taika/Theme/AppDS.swift` | Dictionary shortcut добавлен в Favorites header; Home/Speaker сохраняют существующий shortcut |

## Data source

Используется существующий `FavoriteManager` и его производный список `smartSpeakerDictionaryCardsDTO`. Новых моделей, storage buckets, persistence rules или Speaker API не добавлено.

## Speaker isolation

Core Speaker flow намеренно не изменён. `git diff --stat -- taika/Speaker` пуст. Drawer может отображаться поверх Speaker, но после закрытия Speaker остаётся на прежнем состоянии. Кнопка перехода в Speaker из drawer использует существующий navigation context.

## Validation

- `git diff --check` — passed.
- Проверены все references для `dictionaryQuickDrawer`, `DictionaryQuickDrawerView` и `DictionaryEdgeTab`.
- Xcode project использует `PBXFileSystemSynchronizedRootGroup`, поэтому новый Swift file автоматически входит в target.
- Speaker directory diff — empty.
- Linux sandbox не содержит Xcode/Swift compiler, поэтому полноценный iOS build должен пройти на Mac/Xcode.

## Device smoke checklist

На iPhone проверить:

- Home → tap dictionary header icon → drawer opens from the right.
- Home → pull right edge-tab to the left → drawer opens.
- Speaker → open drawer → close drawer → Speaker remains unchanged.
- Favorites → dictionary header icon is visible and opens the same drawer.
- Drawer with 0 phrases shows `Твои фразы появятся здесь` and `Открыть Speaker`.
- Drawer with phrases shows correct count and up to five latest personal phrases.
- Phrase speaker action returns to Speaker without creating a second overlay.
- `Открыть весь словарь` opens Favorites with `Словарь` selected.
- Close by X, scrim tap and right swipe; all three return to the source screen.
- Repeated open/close gestures do not leave a stuck overlay or duplicate navigation route.
- Verify iPhone compact width, larger iPhone width and landscape behavior.

## Out of scope

This PR does not redesign Speaker, change phrase creation, modify FavoriteManager persistence, add search/edit/delete for dictionary entries, or alter curriculum JSON. Those can be separate follow-up tasks after this navigation layer is approved.

## Review focus

Please focus review on drawer presentation geometry, interaction with the existing root navigation stack, edge-tab gesture conflict with system gestures, and whether the full-dictionary route preserves current Favorites behavior.
