# Taika — Analytics Events Specification

**Статус:** Draft for TestFlight implementation  
**Версия схемы:** `analytics_v1`  
**Ветка:** `feature/monetization-testflight-scrum`  
**Главная цель:** измерить activation, engagement, retention и монетизационную воронку до публичного релиза.

## 1. Принципы

Аналитика должна отвечать на продуктовые вопросы, а не просто собирать максимум кликов. Для первого TestFlight приоритет — понять, может ли пользователь пройти первый meaningful-сценарий, вернуться на следующий день, дойти до Speaker/игр и увидеть понятную ценность Taika+.

Все бизнес-решения должны оставаться в Manager-слое. View отправляет событие через единый `AnalyticsManager`, а `UserSession` продолжает хранить локальную пользовательскую активность, необходимую для прогресса и UI. Эти два типа данных не следует смешивать: локальный `USActivityEvent` — это продуктовый журнал состояния пользователя, а analytics event — удалённое или локально буферизуемое измерительное событие.

Новая схема не должна отправлять сырой голос, аудиозаписи, распознанный текст целиком, email, Apple ID, точную геолокацию или другой ненужный персональный контент. Для Speaker достаточно отправлять факт попытки, длительность, статус анализа, score bucket и технический статус результата.

## 2. Базовая модель события

Рекомендуемая структура:

```swift
struct AnalyticsEvent {
    let name: String
    let schemaVersion: String       // "analytics_v1"
    let eventId: String             // UUID, idempotency key
    let occurredAt: Date
    let sessionId: String
    let anonymousId: String
    let userId: String?             // nil до входа; не использовать email
    let appVersion: String
    let buildNumber: String
    let osVersion: String
    let deviceModel: String
    let locale: String
    let timezone: String             // coarse timezone identifier only
    let isPro: Bool
    let source: String?              // onboarding, main, course, speaker, favorites, paywall...
    let properties: [String: Any]
}
```

### Обязательные поля каждого события

| Поле | Правило |
|---|---|
| `event_name` | Только `snake_case`, стабильное имя, без локализованного текста |
| `event_id` | UUID; используется для дедупликации |
| `schema_version` | Сейчас `analytics_v1` |
| `occurred_at` | Время события в UTC; UI может показывать Bangkok day отдельно |
| `session_id` | Новый ID при запуске/возврате из background после длительного перерыва |
| `anonymous_id` | Устойчивый installation ID без email и Apple ID |
| `user_id` | Внутренний хэшированный/opaque ID, только после авторизации и при наличии необходимости |
| `app_version` / `build_number` | Обязательны для TestFlight-разреза |
| `platform` | `ios` |
| `is_pro` | Состояние entitlement на момент события |
| `source` | Экран или источник входа |
| `properties` | Только whitelist-поля из этой спецификации |

### Общие свойства для продуктовых событий

Если применимо, событие может содержать:

`course_id`, `lesson_id`, `step_index`, `game_id`, `game_origin`, `speaker_mode`, `attempt_id`, `session_number`, `content_pack_version`, `progress_percent_bucket`, `duration_sec_bucket`, `error_code`, `paywall_context`, `experiment_id`, `variant_id`.

Не следует отправлять title, subtitle или свободный текст карточки: эти значения меняются при локализации и усложняют агрегацию. Для отчётов лучше использовать стабильные IDs.

## 3. Жизненный цикл приложения и сессии

| Event | Когда отправлять | Обязательные свойства |
|---|---|---|
| `app_installed_first_open` | Первый запуск после установки | `install_source`, `app_version` |
| `app_opened` | При создании активной сессии | `launch_type`: `fresh`, `foreground`, `relaunch` |
| `app_backgrounded` | При уходе в background, если сессия была meaningful | `session_duration_sec_bucket`, `session_completed` |
| `app_updated` | Первый запуск новой версии | `previous_app_version`, `app_version` |
| `session_started` | Начало аналитической сессии | `session_number`, `entry_point` |
| `session_ended` | Сессия закончилась по timeout/background/explicit completion | `duration_sec_bucket`, `meaningful_actions_count`, `end_reason` |
| `crash_or_fatal_error` | Только если доступен crash reporter | `screen`, `error_code`, `app_version` |

**Session policy:** новая сессия начинается при первом foreground или после 30 минут background. Обычные короткие переключения между экранами не создают новую сессию.

## 4. Onboarding и activation

| Event | Когда отправлять | Свойства |
|---|---|---|
| `onboarding_started` | Открыт onboarding | `entry_reason`: `first_open`, `reset`, `deep_link` |
| `onboarding_step_viewed` | Показан конкретный экран onboarding | `step_id`, `step_index` |
| `onboarding_step_completed` | Пользователь завершил экран | `step_id`, `step_index`, `duration_sec_bucket` |
| `onboarding_skipped` | Onboarding пропущен | `step_id`, `skip_reason` |
| `onboarding_completed` | Завершён обязательный onboarding | `duration_sec_bucket`, `steps_completed` |
| `auth_wall_viewed` | Показан soft wall авторизации | `context` |
| `auth_started` | Нажата авторизация | `method`: `apple` |
| `auth_completed` | Успешная авторизация | `method`, `is_first_auth` |
| `auth_failed` | Ошибка авторизации | `method`, `error_code` |
| `quick_start_started` | Пользователь начал первый guided flow | `course_id`, `lesson_id` |
| `activation_milestone_reached` | Пользователь достиг milestone | `milestone`: `first_lesson_started`, `first_lesson_completed`, `first_speaker_result`, `first_game_completed` |

### Определение activation

Для TestFlight считать минимум две версии:

1. **Activation A:** `onboarding_completed` + `lesson_started` в течение 24 часов.
2. **Activation B:** `onboarding_completed` + `lesson_completed` или `speaker_result` в течение 24 часов.

Основной продуктовый activation milestone для Taika — **первое завершение meaningful learning action**, то есть `lesson_completed`, `speaker_result` или `game_completed`, а не просто открытие приложения.

## 5. Навигация и контент

| Event | Когда отправлять | Свойства |
|---|---|---|
| `tab_viewed` | Пользователь открыл root tab | `tab`: `main`, `courses`, `speaker`, `favorites`, `profile` |
| `course_list_viewed` | Открыт список курсов | `filter`, `sort` |
| `course_opened` | Открыта карточка курса | `course_id`, `source` |
| `lesson_list_viewed` | Открыт список уроков | `course_id`, `lesson_count` |
| `lesson_opened` | Открыт урок | `course_id`, `lesson_id`, `lesson_status` |
| `step_viewed` | Показан учебный шаг | `course_id`, `lesson_id`, `step_index`, `step_type` |
| `step_audio_started` | Начато воспроизведение эталона | `course_id`, `lesson_id`, `step_index`, `audio_type` |
| `step_audio_completed` | Дослушано аудио | `course_id`, `lesson_id`, `step_index`, `duration_sec_bucket` |
| `step_learned` | Шаг отмечен выученным | `course_id`, `lesson_id`, `step_index`, `learned_source` |
| `favorite_added` | Добавлена карточка/курс/лайфхак | `favorite_kind`, `ref_id`, `source` |
| `favorite_removed` | Удалено избранное | `favorite_kind`, `ref_id`, `source` |
| `search_started` | Начат поиск | `scope`: `courses`, `lessons`, `favorites` |
| `search_result_opened` | Открыт результат поиска | `scope`, `result_type`, `result_id` |

## 6. Уроки и core loop

| Event | Когда отправлять | Свойства |
|---|---|---|
| `lesson_started` | Первый step в текущем открытии урока | `course_id`, `lesson_id`, `lesson_index`, `entry_source` |
| `lesson_step_completed` | Шаг пройден по правилам продукта | `course_id`, `lesson_id`, `step_index`, `completion_type` |
| `lesson_paused` | Пользователь покинул урок до завершения | `course_id`, `lesson_id`, `last_step_index`, `progress_percent_bucket` |
| `lesson_completed` | Все условия завершения урока выполнены | `course_id`, `lesson_id`, `duration_sec_bucket`, `steps_completed`, `speaker_used`, `game_used` |
| `lesson_restarted` | Урок начат повторно | `course_id`, `lesson_id`, `restart_reason` |
| `course_completed` | Завершён курс по правилам контента | `course_id`, `lesson_count`, `duration_sec_bucket` |
| `continue_learning_tapped` | Нажата кнопка следующего урока/курса | `course_id`, `lesson_id`, `destination_type` |

**Idempotency:** `lesson_completed` и `course_completed` должны иметь стабильный completion key, например `course_id|lesson_id|completion_version`, чтобы повторный рендер SwiftUI не создавал дубли.

## 7. Speaker

| Event | Когда отправлять | Свойства |
|---|---|---|
| `speaker_opened` | Открыт Speaker | `entry_source`, `course_id`, `queue_size_bucket`, `speaker_mode` |
| `speaker_phrase_viewed` | Показана фраза | `phrase_id`, `course_id`, `lesson_id`, `queue_position_bucket` |
| `speaker_reference_played` | Проигран эталон | `phrase_id`, `playback_count_bucket` |
| `speaker_recording_started` | Начата запись | `phrase_id`, `speaker_mode` |
| `speaker_recording_cancelled` | Запись отменена | `phrase_id`, `duration_sec_bucket`, `cancel_reason` |
| `speaker_recording_completed` | Запись завершена | `phrase_id`, `duration_sec_bucket` |
| `speaker_analysis_started` | Запущен анализ | `phrase_id`, `analysis_version` |
| `speaker_analysis_completed` | Анализ завершён | `phrase_id`, `result_status`, `score_bucket`, `analysis_version` |
| `speaker_analysis_failed` | Анализ завершился ошибкой | `phrase_id`, `error_code`, `analysis_version` |
| `speaker_attempt_completed` | Попытка засчитана продуктом | `phrase_id`, `score_bucket`, `success_bucket`, `attempt_source` |
| `speaker_extra_attempt_requested` | Пользователь достиг лимита и запросил награду | `limit_type`, `offer_context` |
| `speaker_extra_attempt_granted` | Награда выдана | `reward_source`, `daily_reward_count` |

В `score_bucket` использовать интервалы, например `0_39`, `40_59`, `60_79`, `80_100`; не отправлять индивидуальные аудиоданные и не строить аналитику на сыром распознанном тексте.

## 8. Игры и Pro-игры

| Event | Когда отправлять | Свойства |
|---|---|---|
| `game_park_viewed` | Открыт игровой парк | `game_count`, `is_pro` |
| `game_locked_viewed` | Пользователь увидел замок Pro-игры | `game_id`, `lock_reason`, `source` |
| `game_unlock_offer_viewed` | Показано предложение открыть игру за рекламу | `game_id`, `offer_type`: `rewarded`, `paywall` |
| `game_started` | Игра реально началась | `game_id`, `game_origin`, `is_pro_game`, `unlock_source` |
| `game_round_started` | Начался раунд | `game_id`, `round_index` |
| `game_answer_submitted` | Отправлен ответ | `game_id`, `round_index`, `answer_result`, `attempt_index` |
| `game_round_completed` | Раунд завершён | `game_id`, `round_index`, `score_bucket` |
| `game_completed` | Игра завершена | `game_id`, `duration_sec_bucket`, `score_bucket`, `rounds_completed`, `unlock_source` |
| `game_abandoned` | Игра покинута до результата | `game_id`, `round_index`, `progress_percent_bucket`, `exit_reason` |
| `game_retry_tapped` | Нажато повторить | `game_id`, `source` |
| `game_next_tapped` | Нажата следующая игра | `game_id`, `next_game_id`, `is_pro` |

## 9. Paywall и подписка

| Event | Когда отправлять | Свойства |
|---|---|---|
| `paywall_impression` | Paywall реально показан пользователю | `paywall_id`, `context`, `trigger`, `is_first_view` |
| `paywall_cta_tapped` | Нажат CTA | `paywall_id`, `selected_package`, `context` |
| `paywall_closed` | Paywall закрыт | `paywall_id`, `close_method`, `time_open_sec_bucket` |
| `offerings_load_started` | Начата загрузка RevenueCat offerings | `placement` |
| `offerings_loaded` | Offerings успешно загружены | `placement`, `package_count`, `load_duration_ms_bucket` |
| `offerings_load_failed` | Offerings не загрузились | `placement`, `error_code` |
| `trial_eligibility_checked` | Проверена доступность trial | `package_id`, `eligible` |
| `purchase_started` | StoreKit/RevenueCat purchase вызван | `product_id`, `package_id`, `billing_period` |
| `purchase_succeeded` | Покупка подтверждена entitlement | `product_id`, `package_id`, `billing_period`, `is_trial`, `price_bucket`, `currency` |
| `purchase_failed` | Покупка завершилась ошибкой | `product_id`, `error_code`, `is_user_cancel` |
| `purchase_cancelled` | Пользователь отменил системный purchase sheet | `product_id`, `package_id` |
| `restore_started` | Начато восстановление | `source` |
| `restore_succeeded` | Восстановление дало entitlement | `restored_product_count`, `source` |
| `restore_empty` | Restore завершён без покупок | `source` |
| `restore_failed` | Ошибка restore | `error_code` |
| `entitlement_changed` | Изменился `isPro` | `old_state`, `new_state`, `source`, `expiration_bucket` |
| `subscription_management_opened` | Открыто управление подпиской | `source` |
| `subscription_expired` | Entitlement стал неактивным | `previous_product_id`, `expiration_reason` |
| `subscription_reactivated` | Пользователь вернулся в платный статус | `product_id`, `reactivation_source` |

Цена в событиях должна быть числом в минимальных единицах или нормализованным `price_bucket`; точная локализованная строка цены не является стабильным аналитическим полем.

## 10. Rewarded-реклама

| Event | Когда отправлять | Свойства |
|---|---|---|
| `rewarded_offer_impression` | Показан opt-in экран предложения | `placement`, `reward_type`, `reward_value`, `daily_count` |
| `rewarded_offer_tapped` | Пользователь согласился посмотреть | `placement`, `reward_type` |
| `ad_load_started` | Начата загрузка ad unit | `ad_format`, `placement` |
| `ad_loaded` | Реклама готова | `ad_format`, `placement`, `load_duration_ms_bucket` |
| `ad_load_failed` | Не удалось загрузить | `ad_format`, `placement`, `error_code` |
| `ad_presented` | Full-screen ad показан | `ad_format`, `placement`, `network` |
| `ad_impression` | Зафиксирована impression callback | `ad_format`, `placement`, `network` |
| `ad_clicked` | Пользователь нажал объявление | `ad_format`, `placement`, `network` |
| `ad_dismissed` | Реклама закрыта | `ad_format`, `placement`, `watch_duration_bucket` |
| `reward_earned` | SDK сообщил, что награда заработана | `placement`, `reward_type`, `reward_value` |
| `reward_granted` | Taika выдала награду продукту | `placement`, `reward_type`, `reward_id`, `grant_status` |
| `reward_grant_failed` | Не удалось выдать награду | `placement`, `reward_type`, `error_code` |
| `rewarded_cooldown_blocked` | Показ заблокирован frequency/cooldown policy | `placement`, `block_reason`, `daily_count` |

**Ключевая воронка rewarded:** `rewarded_offer_impression → rewarded_offer_tapped → ad_presented → reward_earned → reward_granted → rewarded_feature_started`.

## 11. Источник привлечения и маркетинг

Для каждого первого запуска и перехода из campaign/deep link сохранять:

`acquisition_source`, `campaign_id`, `creative_id`, `keyword`, `custom_product_page_id`, `referrer_type`, `deep_link_destination`.

Значения должны быть нормализованы:

| Source | Пример |
|---|---|
| `organic_app_store` | Органическая выдача App Store |
| `apple_ads` | Apple Ads campaign |
| `telegram` | Пост/канал/партнёр |
| `youtube` | Видео/обзор |
| `tiktok` | Short-form creative |
| `instagram` | Reel/Story/profile |
| `community` | Форум/чат/сообщество |
| `referral` | Реферальная ссылка |
| `direct` | Неизвестный/прямой вход |

Для Apple Ads и Custom Product Pages использовать официальные идентификаторы кампании/страницы, а не ручные параметры, которые невозможно связать с App Store Connect.

## 12. Воронки и dashboards

### Dashboard 1 — Activation

```text
app_installed_first_open
→ onboarding_completed
→ course_opened
→ lesson_started
→ first_meaningful_action
→ D1_return
→ D7_return
```

Основные показатели: конверсия между шагами, median time-to-first-action, D1/D7 retention, доля пользователей с `lesson_completed`, `speaker_result` или `game_completed`.

### Dashboard 2 — Learning engagement

```text
course_opened
→ lesson_started
→ step_viewed
→ step_learned
→ lesson_completed
→ course_completed
```

Разрезы: course_id, lesson_id, source, app version, session number.

### Dashboard 3 — Speaker

```text
speaker_opened
→ speaker_phrase_viewed
→ speaker_recording_completed
→ speaker_analysis_completed
→ speaker_attempt_completed
→ next_session_24h
```

Важно отдельно показывать технические ошибки и пользовательские отмены.

### Dashboard 4 — Subscription

```text
paywall_impression
→ paywall_cta_tapped
→ trial_started / purchase_started
→ purchase_succeeded
→ first_renewal
→ active_after_30d
```

Основные показатели: paywall view rate, CTA rate, trial start rate, trial-to-paid, purchase failure rate, restore success, D7/D30 paid retention, proceeds per payer.

### Dashboard 5 — Rewarded

```text
pro_feature_locked
→ rewarded_offer_impression
→ rewarded_offer_tapped
→ ad_presented
→ reward_earned
→ reward_granted
→ feature_started
→ next_session_24h
```

Главный guardrail: сравнивать не только ad revenue, но и `next_session_24h`, lesson completion и trial start между пользователями, видевшими rewarded, и контрольной группой.

## 13. Privacy и качество данных

До подключения SDK нужно определить, какие поля реально нужны, обновить App Privacy в App Store Connect и описать аналитические/рекламные SDK в Privacy Policy. Нельзя передавать сырой голос Speaker в analytics pipeline. Для рекламного трекинга отдельно проверить ATT/consent-поведение и SKAdNetwork-конфигурацию.

Технические требования к `AnalyticsManager`:

- in-memory queue + offline persistence;
- batch отправка после появления сети;
- retry с backoff;
- дедупликация по `event_id`;
- ограничение размера payload;
- логирование ошибок без PII;
- возможность отключить analytics в debug/TestFlight diagnostics;
- отдельный `debug` sink, чтобы не смешивать тестовые события с production;
- feature flag для включения новых событий постепенно.

## 14. Acceptance criteria для первой версии

Первая версия аналитики готова, если:

1. на одном TestFlight-устройстве можно пройти activation funnel от `app_installed_first_open` до `lesson_completed`;
2. каждый event имеет `event_id`, `session_id`, `app_version` и `schema_version`;
3. повторный SwiftUI render не создаёт дубликаты completion events;
4. offline-события не теряются при кратком отсутствии сети;
5. Speaker analytics не содержит сырой аудио/текстовый контент;
6. paywall/purchase/restore события отделены от локального `UserSession.activityLog`;
7. rewarded-flow может показать `reward_granted` только один раз для одного `reward_id`;
8. App Store acquisition source сохраняется для последующей атрибуции;
9. доступен недельный dashboard с D1/D7 и конверсиями основных воронок;
10. все TBD-поля явно отмечены и не блокируют первую TestFlight-сборку.
