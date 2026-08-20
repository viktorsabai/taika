# Профиль Taika — продуктовый follow-up

**Статус:** аудит текущего SwiftUI состояния без внесения изменений в код.

**Источник аудита:** `taika/Profile/ProfileView.swift`, текущая release branch `2026-01-21-k7hb-d2004`, и два пользовательских device screenshots: основной профиль и раскрытый раздел «Ещё».

## 1. Короткий verdict

Сейчас профиль — это рабочая техническая страница настроек, но не до конца сформированный продуктовый hub. Его текущая роль смешивает четыре разных задачи: управление аккаунтом, конверсию в Taika+, объяснение продукта, а также поддержку и внутреннюю отладку. Для Debug-сборки это допустимо. Для production UX такая структура недостаточно ясно отвечает на вопрос пользователя: «зачем мне сюда заходить и что я здесь могу сделать?»

Профиль не нужно превращать в социальную страницу с аватаром и лишней персонализацией. Для Taika его правильная роль — **центр доверия и управления доступом**: аккаунт, подписка, восстановление покупки, связь с командой, юридическая информация и безопасное управление данными. Прогресс, курсы, словарь и Speaker должны оставаться в своих основных разделах, а профиль должен давать к ним только понятные ссылки там, где это помогает аккаунту или подписке.

Моя оценка текущей product readiness: **6,5/10**. Визуально это ближе к системному iOS Settings, чем к остальному liquid-glass Taika. Это не обязательно ошибка само по себе, но сейчас переход между Taika header и системным list выглядит как смена продукта. Содержательно основной риск — Debug/TestFlight information частично уже отделена условной компиляцией, но тестовые сценарии и production copy всё ещё недостаточно строго разведены.

## 2. Что сейчас есть в коде

| Блок | Текущее поведение | Фактическая роль |
|---|---|---|
| Header | `TaikaScreenPageTitle("Профиль")` и crown control в shell | Навигационная оболочка |
| Build badge | `TaikaBuildChannel.badgeTitle/subtitle` | Debug/TestFlight visibility layer |
| Account | Apple ID sign-in, display name, account state | Identity and purchase recovery prerequisite |
| Taika+ | `ProfileProSheet`, paywall opening, restore purchases | Primary monetisation entry |
| Product explanation | `Как устроена Taika` | Trust/onboarding reference |
| More | `ProfileMoreSheet` | Secondary links and legal/support |
| Data | Reset progress, `ProfileDebugSheet` under `#if DEBUG` | Destructive action and internal tooling |
| Onboarding | Full-screen re-entry through `showOnboarding` | QA/debug or recovery path, not normal profile navigation |

Внутри `ProfileView` также выполняется `ProManager.shared.syncCustomerInfoFromRevenueCat()` и попытка soft wall при появлении профиля. Это значит, что профиль является не только UI-страницей, но и точкой синхронизации entitlement state. Эту ответственность нужно сохранить, но не показывать пользователю как техническую механику.

## 3. As-Is: что работает

Текущая структура уже содержит основные обязательные production flows: Apple ID, открытие Taika+, восстановление покупки, support, website, Instagram, privacy, terms, version и destructive reset. Это хороший минимальный foundation.

Отдельный плюс — `#if DEBUG` для кнопки «Отладка». Debug sheet содержит тестовый Taika+ toggle и внутренние действия, поэтому он не должен попадать в production binary при корректной конфигурации. Build badge также полезен для QA: на screenshot он сразу показывает, что пользователь находится в локальной сборке или TestFlight-like environment.

Наличие отдельного `ProfileMoreSheet` тоже логично как промежуточный шаг: основной профиль не перегружен всеми юридическими и контактными пунктами.

## 4. As-Is: основные проблемы

### 4.1. Профиль не имеет одного ясного сценария

На первом screenshot пользователь видит список технических пунктов, но не получает короткого ответа, зачем профиль нужен. `Debug`, `Локальная сборка для разработки`, версия и «Привязать Apple ID» визуально конкурируют с Taika+ и полезными ссылками. Для обычного пользователя это ощущается как экран настроек разработчика, а не как зрелый личный центр приложения.

### 4.2. Debug/TestFlight слой недостаточно строго отделён по смыслу

`#if DEBUG` хорошо скрывает отладочную кнопку, но build badge и раздел «Тестирование» должны быть разведены по build channel. Локальная Debug-сборка, TestFlight и production — три разных контекста:

| Channel | Что показывать | Что не показывать |
|---|---|---|
| Debug | Build badge, Debug tools, reset/re-entry helpers | Ничего критичного для QA не скрывать |
| TestFlight | Небольшой QA-индикатор, версия/build, feedback shortcut | Debug toggles, fake entitlement controls, destructive helpers без явного QA-контекста |
| Production | Версия, support, legal, account, subscription | Любые слова Debug, local build, тестовые переключатели и внутренние reset flows |

Сейчас визуальный screenshot «Тестирование» выглядит как production-visible area. Даже если часть controls условно скрыта, copy boundary нужно сделать явным в коде через build channel, а не только через `#if DEBUG`.

### 4.3. Taika+ CTA слишком плоский

`Открыть Taika+` находится в секции, но не объясняет разницу между подпиской, trial и восстановлением доступа на уровне профиля. Основной CTA должен быть состояниезависимым: `Попробовать Taika+`, `Открыть Taika+`, `Подписка активна`, `Восстановить покупку` или `Управление подпиской`. Нельзя всегда показывать один и тот же глагол.

### 4.4. Account и restore purchase связаны неочевидно

Кнопка `Привязать Apple ID` визуально находится отдельно от Taika+, хотя restore flow в коде требует login. Пользователь может не понять, почему восстановление покупки зависит от аккаунта. Нужно объяснить это inline только в состоянии, когда это действительно необходимо: «Войди через Apple ID, чтобы восстановить подписку на новом устройстве».

### 4.5. `Как устроена Taika` — правильный пункт, но слабая формулировка роли

Сейчас это скорее справочная ссылка. В продукте он должен отвечать на ключевой trust-вопрос: «Почему Taika — не просто переводчик?» Содержимое должно объяснять четыре части системы: курсы, Speaker, pronunciation practice и games. Это не должен быть второй onboarding, а короткий product explainer, который можно открыть позже.

### 4.6. «Ещё» создаёт лишний уровень навигации

Внутри `ProfileMoreSheet` находятся support, site, Instagram, legal, version, reset и Debug. Это логично как техническая декомпозиция, но пользовательский путь становится двухшаговым: Profile → Ещё → нужное действие. Для популярных действий support и restore account лучше быть доступны без дополнительного sheet. В «Ещё» стоит оставить редко используемые legal/about links и destructive data actions.

### 4.7. Reset progress находится слишком близко к обычным действиям

Сброс прогресса — необратимое по смыслу действие и должно быть отдельной зоной с явным explanatory copy. Сейчас оно находится в том же list-based layer, что и Debug. В production оно должно быть в «Данные и приватность» или в нижней части «Ещё», с подтверждением уже реализованным в коде.

## 5. To-Be: продуктовая роль профиля

Профиль должен стать коротким control center, а не второй главной навигацией.

> **Профиль Taika — место, где пользователь управляет доступом, подпиской, аккаунтом и доверием к приложению.**

Recommended production hierarchy:

1. **Account identity:** Apple ID state and sync explanation only when relevant.
2. **Taika+ access:** state-aware subscription card, restore/manage access.
3. **Product trust:** «Как работает Taika» as a compact explainer.
4. **Support:** support and feedback entry.
5. **About/legal:** version, website, privacy and terms.
6. **Data:** reset progress at the bottom, visually separated.

Профиль не должен показывать summary курсов, словаря или игр: эти объекты уже имеют свои destinations. Если они появятся в профиле, возникнет дублирование Main/Courses/Speaker/Favorites navigation.

## 6. Рекомендованная visual system

Нужно сохранить native iOS list readability, но сделать её принадлежащей Taika:

- один continuous dark canvas под header и content;
- section labels в текущем muted uppercase стиле;
- единый row height и icon column;
- единый pink/lilac accent только для активной подписки, CTA и selected state;
- без тяжёлых отдельных cards вокруг каждой строки;
- Taika+ допускает более выразительную accent surface, остальные rows — спокойные translucent rows;
- Debug/TestFlight должен иметь сознательно технический, но не случайный визуальный marker.

То есть профиль не нужно превращать в такой же immersive overlay, как Speaker. Он должен быть спокойнее: это control center, а не focus stage.

## 7. P0/P1/P2 roadmap

### P0 — обязательно до production polish

Нужно развести build channels: production не должен показывать `Debug`, «локальная сборка» или test-only controls; TestFlight должен показывать компактный build/version marker и feedback action; Debug может сохранять debug tools.

Нужно сделать Taika+ section state-aware и связать account/restore explanation с реальным состоянием пользователя. Нужно также проверить, что `onAppear` sync не вызывает повторный soft wall при каждом возвращении на профиль без необходимости.

Нужно вынести reset progress в отдельную нижнюю data/privacy zone с ясным предупреждением и проверить dismissal/return path после confirm.

### P1 — улучшение product UX

Нужно сократить «Ещё»: support и feedback сделать быстрее доступными, а legal/about оставить внутри secondary destination. `Как устроена Taika` превратить в короткий product explainer с ясным CTA возврата в профиль.

Нужно добавить accessibility labels/hints для Apple ID, Taika+, restore, reset, support и build badge. Все внешние ссылки должны иметь одинаковую нативную confirmation/recovery behavior при отсутствии браузера.

### P2 — visual/product polish

Нужно выровнять profile spacing с новым header clearance, убрать визуальное ощущение «голого Settings» и добавить subtle Taika brand treatment вокруг identity/subscription zones без превращения страницы в рекламный экран.

Нужно добавить TestFlight feedback shortcut, который явно ведёт в support с указанием app version/build, но не показывать эту механику в production.

## 8. TestFlight validation plan

| Сценарий | Ожидаемый результат |
|---|---|
| Production profile | Нет Debug/TestFlight labels; доступны account, Taika+, support, legal, reset |
| Debug profile | Доступен Debug sheet и test entitlement controls; build badge ясно показывает local/debug |
| TestFlight profile | Видны версия/build и feedback route; Debug entitlement toggles отсутствуют |
| Logged-out user taps restore | Понятное объяснение входа через Apple ID; нет silently failed restore |
| Logged-in user taps restore | Loading state, success/no-purchase/error states, возврат в profile без зависания |
| Tap Taika+ | Открывается правильный paywall reason и после dismiss возвращается в profile |
| Tap reset | Confirmation, reset, success feedback, profile остаётся usable |
| Tap support/site/Instagram | Внешний URL открывается, при cancel пользователь остаётся в том же destination |
| Re-enter profile repeatedly | Entitlement sync не создаёт повторный unwanted soft wall или duplicate presentation |

## 9. Финальный verdict

**Сейчас:** функционально полезный, но технически смешанный Profile/More/Debug screen — примерно 6,5/10.

**Нужно:** не большой визуальный redesign, а product cleanup: жёстко разделить production/TestFlight/Debug, сделать subscription/account states ясными, сократить вторичную навигацию и перестроить reset/support hierarchy.

**Не нужно:** добавлять в профиль прогресс курсов, dictionary feed, game cards или копировать Speaker immersive canvas. Это создаст конкурирующие navigation centers.

**Следующий безопасный шаг:** сначала реализовать P0 в `ProfileView.swift` и связанных config/build-channel helpers, затем отдельно провести TestFlight validation. В этот pass не трогать overlay epic и не смешивать профиль с Game Park/Speaker primitives.
