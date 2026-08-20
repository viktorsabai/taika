# Profile mockup state system

## Цель

Показать профиль как control center Taika: аккаунт, доступ, подписка, доверие, поддержка и безопасное управление данными. Профиль не дублирует курсы, Speaker, словарь или Game Park.

## Mockup set

| Mockup | State | Главный пользовательский вопрос | Основное действие |
|---|---|---|---|
| Production v1 | Обычный production profile | Что я могу управлять здесь? | Открыть Taika+, войти, получить поддержку |
| Account/Restore v1 | Apple ID и восстановление | Как восстановить доступ на новом устройстве? | Войти через Apple ID / восстановить покупку |
| Taika+ states v1 | Активный trial/entitlement | Что мне доступно и как управлять подпиской? | Управление подпиской / восстановление |
| Support/More/Reset v1 | Вторичные ссылки и данные | Где помощь, legal и безопасный reset? | Support, legal, reset с подтверждением |
| TestFlight/Debug v1 | Build-channel boundary | Как сообщить о проблеме и что доступно QA? | Feedback в TestFlight; Debug tools только в Debug |

## Unified visual contract

Все states используют один Taika continuous dark canvas, одну header identity, одну typography hierarchy, один icon column и одну restrained pink-lilac accent. Роли различаются содержанием и плотностью, но не превращаются в случайные отдельные дизайн-системы.

Production profile спокоен и list-oriented. Taika+ допускает более выразительную accent surface. Restore и reset используют компактные action surfaces. TestFlight имеет технический marker, но не показывает внутренние entitlement toggles. Debug остаётся строго debug-only.

## Approval questions

1. Достаточно ли ясно, что профиль — это центр аккаунта и доступа, а не второй home screen?
2. Нужно ли показывать `Восстановить покупку` постоянно или только для logged-in/entitlement-relevant states?
3. Должен ли support быть на первом уровне профиля или оставаться внутри `Ещё`?
4. Принимаем ли мы отдельный compact `TestFlight` marker с feedback CTA?
5. Оставляем ли reset в `Ещё` или выносим его в отдельный data/privacy destination?

## Next implementation decomposition

После approval: P0 channel separation + state-aware Taika+ + restore/account copy; P1 support/More simplification + explainer; P2 visual polish and TestFlight feedback metadata.
