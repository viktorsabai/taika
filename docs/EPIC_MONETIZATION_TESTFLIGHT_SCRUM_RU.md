# Taika — эпик монетизации, рекламы и TestFlight

**Статус эпика:** In progress — discovery / device QA  
**Ветка:** `feature/monetization-testflight-scrum`  
**Владелец продукта:** Viktor  
**Дата фиксации:** 21 августа 2026 года  
**Статус следующих шагов:** TBD

## 1. Контекст продукта

Taika — iOS-приложение для русскоязычных пользователей, изучающих разговорный тайский. Основной опыт строится вокруг коротких ежедневных сессий: курс → урок → шаги → аудио → Speaker → повторение/игровое закрепление.

Продукт позиционируется как гибрид языкового курса и audio-first-приложения. Поэтому монетизация не должна превращать обучение в поток рекламных пауз. Главный актив продукта — качество и регулярность core loop, а не максимальное число рекламных показов.

Текущая техническая основа:

| Область | Текущее состояние |
|---|---|
| UI/архитектура | Swift + SwiftUI; принцип `Data → Manager → View → DS` |
| Подписка | `ProManager`, RevenueCat, entitlement `pro` |
| Тарифы в конфигурации | 349 THB/month, 1,690 THB/year, 3,990 THB/lifetime |
| Intro trial | 7 дней |
| Free/Pro gates | Игры, Speaker advanced, AI advanced, daily picks, unlimited sessions |
| Игры | HomeTask / игровое завершение с возможным переходом к следующей игре |
| TestFlight | Сначала device QA и internal TestFlight, затем небольшая внешняя группа |
| Реклама | SDK и единый AdsManager пока не внедрены |
| Аналитика | Требуется единая схема событий для TestFlight и монетизации |

## 2. Главная цель

> **Сразу выйти на реалистичный план монетизации, который можно проверить данными, а не строить на предположениях.**

Реалистичный план означает, что Taika:

1. сохраняет полноценный бесплатный core loop;
2. использует Taika+ как основной предсказуемый источник выручки;
3. монетизирует Free-пользователей через добровольные рекламные награды;
4. полностью отключает рекламу для Taika+;
5. принимает решения по частоте рекламы, тарифам и paywall на основании TestFlight-метрик;
6. оставляет возможность быстро выключить проблемный рекламный placement.

## 3. Ближайшая цель

> **Подготовить код к TestFlight так, чтобы после теста можно было посмотреть продуктовые метрики, статистику и поведение пользователей.**

На ближайшем этапе приоритетом является не максимальная рекламная выручка, а наблюдаемость продукта:

- корректно фиксировать запуск и завершение основных сценариев;
- измерять, где пользователь теряется;
- видеть возвращение на следующий день;
- понимать, доходит ли пользователь до Speaker и игр;
- фиксировать намерение открыть Pro-функцию;
- подготовить события для будущего rewarded-flow и подписки;
- не добавлять рекламу в активный урок до подтверждения качества core loop.

## 4. Scrum-структура эпика

### Epic A — Device QA и исправление core loop

**Цель:** устранить типологические рассинхроны и ошибки, обнаруживаемые при самостоятельном тестировании на реальном устройстве.

**Область проверки:** онбординг, Main, курсы, уроки, шаги, аудио, Speaker, игры, избранное, прогресс, авторизация, повторный запуск и обновление приложения.

**Definition of Done:** пользователь может пройти основной сценарий на iPhone, закрыть приложение, открыть его снова и продолжить без потери или рассинхронизации прогресса.

### Epic B — TestFlight readiness

**Цель:** подготовить стабильную сборку для второго iPhone и небольшой внешней группы.

**Последовательность:**

| Шаг | Содержание | Результат |
|---|---|---|
| B1 | Проверка на основном устройстве | Список воспроизводимых багов |
| B2 | Исправление критичных рассинхронов | Стабильный core loop |
| B3 | Internal TestFlight | Установка на второй iPhone |
| B4 | Проверка чистой установки и обновления | Нет регрессий при миграции состояния |
| B5 | External TestFlight smoke test | Небольшой тестерский feedback |
| B6 | Недельный тест | Первые метрики и приоритеты исправлений |

Семь дней — это длительность нашего тестового цикла, а не ограничение Apple. Apple указывает, что TestFlight-сборка может тестироваться до 90 дней; для внешнего тестирования может потребоваться beta review.

### Epic C — Analytics foundation

**Цель:** сделать поведение приложения измеримым до подключения полноценной рекламы.

**Минимальные события:**

| Событие | Назначение |
|---|---|
| `app_open` | Активность и возвращаемость |
| `onboarding_completed` | Прохождение первого входа |
| `course_opened` | Интерес к курсам |
| `lesson_started` | Начало учебного действия |
| `lesson_completed` | Завершение урока |
| `speaker_started` | Начало практики речи |
| `speaker_result` | Получение результата Speaker |
| `game_started` | Начало игры |
| `game_completed` | Завершение игры |
| `pro_feature_locked` | Намерение открыть платную функцию |
| `paywall_viewed` | Просмотр предложения Taika+ |
| `trial_started` | Начало 7-дневного trial |
| `purchase_success` | Успешная покупка |
| `restore_success` | Восстановление покупки |
| `session_completed` | Завершение meaningful-сессии |
| `next_session_24h` | Возвращение в течение 24 часов |

Все события должны иметь единый контекст: `user_id` или анонимный installation ID, `session_id`, `app_version`, `device`, `course_id`, `lesson_id`, `source`, `is_pro` и timestamp. Не следует отправлять в аналитику сырой голос пользователя или лишние персональные данные.

### Epic D — Taika+ production readiness

**Цель:** привести текущую RevenueCat-модель из состояния заглушек к проверяемому коммерческому потоку.

**Задачи:**

1. Заполнить реальный `REVENUECAT_PUBLIC_API_KEY`.
2. Проверить entitlement `pro` и соответствие продуктов в RevenueCat/App Store Connect.
3. Проверить monthly, annual, lifetime и 7-day intro trial.
4. Проверить restore purchases.
5. Проверить состояние после отмены и истечения подписки.
6. Сделать рабочими `privacy` и `terms` URL.
7. Проверить paywall на физическом устройстве.
8. Добавить App Review Notes для нетривиальных функций и IAP.

**Definition of Done:** пользователь может начать trial, купить тариф, восстановить покупку на втором iPhone, а Taika+ корректно снимает все Pro-гейты и отключает рекламу.

### Epic E — Rewarded advertising foundation

**Цель:** монетизировать Free-пользователя через добровольный обмен просмотра на ограниченную дополнительную возможность.

**Приоритетный первый placement:** открыть одну Pro-игру на сегодня после просмотра rewarded-рекламы.

**Последующие placements:**

| Placement | Награда | Приоритет |
|---|---|---:|
| `pro_game_one_session` | Одна сессия Pro-игры сегодня | P0 |
| `speaker_extra_attempt` | Одна дополнительная попытка Speaker | P1 |
| `daily_pick_extra` | Дополнительная ежедневная подборка | P1 |
| `error_review_extra` | Ещё один повтор ошибок | P2 |
| `course_preview_one_day` | Временный доступ к одному premium-курсу | P2 |

**Правила:**

- Rewarded-реклама всегда запускается только после явного нажатия пользователя.
- Награда выдаётся только после подтверждения успешного просмотра рекламой.
- Taika+ никогда не видит рекламу и не должен ждать рекламный preload.
- Free-лимиты должны быть понятными и одинаковыми во всех экранах.
- Для первого релиза рекомендуется максимум 1 Pro-игра через рекламу в день и 2–3 rewarded-показа в день суммарно.
- Реклама не показывается во время урока, аудио, записи Speaker, анализа голоса, онбординга или сразу после неудачной попытки.
- Interstitial между обычными шагами урока не используется.
- Interstitial после крупной игры остаётся отдельной гипотезой и имеет статус TBD.

### Epic F — Экономика и эксперименты

**Цель:** заменить прогнозные допущения фактическими метриками после TestFlight.

**Рабочая модель:**

```text
Subscription net revenue = paid users × weighted net monthly value
Ad net revenue = impressions / 1,000 × realized eCPM × ad net factor
Total revenue = subscription net revenue + ad net revenue
```

Текущие рабочие сценарии не являются обещанием результата:

| Сценарий | MAU | Paid rate | Ориентир total/day |
|---|---:|---:|---:|
| Пессимистичный | 3,000 | 1% | ~274 THB / $7.83 |
| Реалистичный | 30,000 | 3% | ~8,602 THB / $245.77 |
| Оптимистичный | 300,000 | 5% | ~164,086 THB / $4,688 |

Эти цифры будут пересчитаны после появления собственных данных. В текущей модели комиссия Apple 15% применяется только при квалификации в Small Business Program; налоги, возвраты, валютные корректировки и рекламные расходы не включены полностью.

## 5. Product metrics для недельного теста

Главные метрики первой недели:

| Группа | Метрики |
|---|---|
| Activation | onboarding completion, first lesson started, first lesson completed |
| Engagement | sessions/user, lesson completion, game completion, Speaker attempts |
| Retention | D1, D3, D7 return; next session within 24h |
| Quality | crashes, failed audio, progress loss, navigation dead ends |
| Monetization intent | paywall views, Pro locks, trial starts, restore attempts |
| Ads readiness | eligible placement views, rewarded opt-in, completion, reward granted |

На первой неделе не оптимизируем приложение под максимальное количество показов. Сначала проверяем, возвращаются ли пользователи и понимают ли ценность продукта.

## 6. Definition of Ready для рекламной задачи

Рекламный код можно начинать внедрять после выполнения следующих условий:

- core loop проходит на реальном iPhone без критических рассинхронов;
- состояние прогресса сохраняется после kill/relaunch;
- есть минимальная аналитика и понятные session IDs;
- есть `ProManager` с рабочим состоянием entitlement;
- понятна разница Free/Taika+;
- есть privacy policy и terms;
- в проекте предусмотрены test ad IDs;
- есть глобальный cooldown/frequency policy;
- есть kill switch для отключения рекламы;
- rewarded-награда идемпотентна и не выдаётся дважды за один просмотр.

## 7. Текущие решения и нерешённые вопросы

### Зафиксированные решения

| Решение | Статус |
|---|---|
| Основная монетизация — Taika+ | Принято |
| Free получает полезный core loop | Принято |
| Rewarded за дополнительную возможность | Принято как направление |
| Taika+ полностью без рекламы | Принято |
| Первый rewarded placement — одна Pro-игра на сегодня | Рекомендуемый P0 |
| Interstitial между шагами урока | Не использовать |
| Семидневный TestFlight-цикл | Принято как рабочий цикл |
| Экономика сначала моделируется, затем калибруется TestFlight-данными | Принято |

### TBD

Следующие шаги, точные SDK, конкретные события, backend/analytics provider, частота rewarded, необходимость interstitial, финальные цены, порядок paywall, момент подключения внешних тестеров и дата публичного релиза остаются **TBD** до завершения текущего device QA и получения первых TestFlight-данных.

## 8. Связанные материалы

- `ANALYTICS_EVENTS_SPEC_RU.md` — детальная схема Analytics Events, свойств, воронок и acceptance criteria.
- `MARKETING_LAUNCH_PLAN_RU.md` — план pre-launch, TestFlight, App Store launch и первых каналов привлечения.
- `TAIKA_TESTFLIGHT_ADS_ECONOMICS_RU.md` — подробная экономика и процесс TestFlight.
- `TAIKA_MONETIZATION_RECOMMENDATIONS_RU.md` — предыдущий аудит монетизации и архитектурные рекомендации.
- `taika_economics_sources.md` — источники и допущения модели.
- `calc_economics.py` — воспроизводимый расчёт сценариев.
- `docs/TESTFLIGHT_READINESS.md` — текущий checklist готовности TestFlight.
- `ARCHITECTURE.md` — архитектурные ограничения и контракты проекта.

## References

[1]: https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/ "Apple TestFlight Overview"
[2]: https://developer.apple.com/app-store/small-business-program/ "Apple App Store Small Business Program"
[3]: https://developer.apple.com/app-store/review/guidelines/ "Apple App Review Guidelines"
[4]: https://developers.google.com/admob/ios/rewarded "Google Mobile Ads SDK Rewarded Ads"
[5]: https://www.revenuecat.com/state-of-subscription-apps-2025 "RevenueCat State of Subscription Apps 2025"
