# PRO / paywall — сквозной аудит (код)

Единая точка правды по подписке: `ProManager.shared` (`isPro`, `can(ProFeature)`).

## 0. Покупки и entitlement (RevenueCat)

| Элемент | Где |
|--------|-----|
| Публичный SDK-ключ | `Info.plist` → `REVENUECAT_PUBLIC_API_KEY` (пустой/пробел = SDK не инициализируется) |
| Инициализация | `RevenueCatBootstrap.configureIfNeeded()` из `taikaApp.init()` |
| Entitlement в коде | `TaikaProConfig.entitlementIdentifier` (должен совпадать с RevenueCat, по умолчанию `pro`) |
| Пакеты в текущем Offering | `TaikaProConfig.PackageIdentifier`: `$rc_annual`, `$rc_monthly`, `$rc_lifetime` |
| Обновление PRO | `PurchasesDelegate` → `ProManager.applyRevenueCatCustomerInfo`; при старте — `syncCustomerInfoFromRevenueCat()` из `AppShell` |
| Логика `isPro` | После debug override: **PRO**, если `UserSession.isProFromServer == true` **или** активное entitlement в RevenueCat |
| Экран paywall | `TaikaPlusPaywallView` (обёртка `PROView` для оверлеев) |
| Юридические ссылки | `TaikaProConfig.Legal.privacyPolicy`, `termsOfUse` |

## 1. Курсы из каталога

| Место | Поведение |
|-------|-----------|
| `CourseView.handleTapCourse` | Платный курс без PRO → `overlay.present(.proCoursePaywall)` |
| `CourseView` превью курса | `isProLocked` → кнопка «Разблокировать PRO» |

## 2. Список уроков и урок (Step)

| Место | Поведение |
|-------|-----------|
| `LessonsView` слоты хедера, карусель уроков, консоль (игра/продолжить) | Урок с `is_free: false` в JSON без PRO → paywall, без push в `Step` |
| Ранее: открывался Step по платному уроку — **исправлено** |

## 3. Навигация с главной и избранного

| Место | Поведение |
|-------|-----------|
| `MainView.openCourse` / `openLesson` | Курс из `CourseData` с `is_pro` без PRO → paywall |
| `MainView` поиск по курсам (`searchCoursesSection`) | Тап по карточке результата: платный курс без PRO → paywall |
| `FavoriteView.onOpenCourse` | То же по `CourseData.shared.course(with:)` |
| `AllFavoritesView` список курсов | То же |

## 4. Игры

| Место | Поведение |
|-------|-----------|
| `GameModePickerDS` | `mode.isPro && !isProUser` → строка заблокирована, «нужен PRO», кнопка «Начать» disabled |
| Пикеры (урок, курс, итоги Step, игровой парк) | Тап по заблокированному PRO-режиму → paywall (где добавлен `onLockedTap`) |
| `AppShell.GameView` | Прямой deep link в `.game` с PRO-типом без подписки → экран-заглушка + paywall, не `HomeTaskView` |

`HomeGameType.requiresProSubscription` в `HomeTaskData.swift` — соответствие `GameModeType.isPro`.

## 5. Спикер

| Место | Поведение |
|-------|-----------|
| `SpeakerView` `onRequestBreakdown` | PRO → полный разбор + API тонов; free → оверлей с базовым сравнением, upsell тонов в UI |
| Лимиты попыток | `SpeakerDailyAttemptsStore` / `SpeakerConversationAttemptsStore` + `isPro` в шапке |

## 6. Подборки / лимиты (Main)

| Место | Поведение |
|-------|-----------|
| `MainManager` | `dailyPicksExtra` через `ProManager.shared.can(.dailyPicksExtra)`; лимиты 5/10 и 5/10 курсов |

## 7. Прочее

| Место | Поведение |
|-------|-----------|
| `CourseView` / `MainView` карточки подборки | Тапы по PRO-карточкам ведут на paywall |
| `ProfileView` | Restore через `ProManager.restorePurchases()` → RevenueCat |

## 8. Рекомендации на будущее

- Держать новые платные фичи за `ProFeature` + один сценарий paywall (`proCoursePaywall` / `speakerPaywall`).
- При добавлении нового маршрута в `.game` или `.lesson` — проверять курс/урок через `CourseData` или `LessonBundle.isFree`.
