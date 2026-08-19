# Profile Control Center Epic — декомпозиция и план merge

## Product decision

Profile остаётся **control center аккаунта, доступа и доверия**. Это не социальная страница, не второй Home и не самостоятельный слой бизнес-логики обучения. Утверждённый visual direction: та же motion-first айдентика, что в onboarding — тёмный непрерывный canvas, жидкое стекло, мягкие waveform/orb-сферы и хаотичные techno-формы как restrained background motion.

Главное правило: motion объясняет состояние и следующий шаг, но не конкурирует с контентом. Любая анимация должна быть полезной: показать активность, подтвердить tap, объяснить loading/restore или направить к следующему действию.

## Current implementation boundary

По текущему `taika/Profile/ProfileView.swift` уже существуют build-channel определения `TaikaBuildChannel`, состояния TestFlight/Debug, `ProfileProSheet`, `ProfileMoreSheet`, `ProfileDebugSheet`, restore flow через `ProManager` и legal URLs через `TaikaProConfig`. Поэтому эпик не требует новой архитектуры.

`ProfileView` должен продолжать агрегировать данные, а не пересчитывать их. Прогресс статистики должен приходить через существующий `ProfileManager`/profile data sources. `Profile` не должен напрямую обращаться к `StepData`, дублировать `ProManager` или принимать решения за образовательную навигацию.

## P0 — trust, access and channel correctness

| User outcome | Implementation scope | Acceptance criteria |
|---|---|---|
| Пользователь понимает, к какому аккаунту привязан прогресс | Пересобрать account block в существующем ProfileView: Apple ID status, bind/sign-in, restore entry | Logged-out, bound и restore-in-progress states различимы; нет дублирующих CTA |
| Пользователь понимает доступ Taika+ | Привести inactive, trial, active, expired/error состояния к одной canonical glass geometry | В каждом состоянии один главный CTA и один secondary action; paywall не дублируется внутри Profile |
| Пользователь может восстановить покупку | Сохранить существующий `ProManager.restorePurchases()` и добавить success/error/recovery presentation | Double tap блокируется; loading виден; error не создаёт dead-end; retry доступен |
| Production не показывает внутренние инструменты | Оставить TestFlight/Debug surface за существующими build flags/configuration | Production не содержит Debug/TestFlight labels, reset onboarding или diagnostics |
| TestFlight/Debug полезны tech lead, но не обычному пользователю | Сохранить отдельную debug sheet и сделать её визуально вторичной | Debug actions недоступны в production; TestFlight feedback отделён от production support |

## P1 — progress value and useful destinations

| User outcome | Implementation scope | Acceptance criteria |
|---|---|---|
| Пользователь видит личный прогресс | Добавить compact Profile entry “Твой ритм” и detail screen на данных существующего progress layer | Метрики берутся только из реальной истории; no fake achievements/rankings |
| Новый пользователь понимает empty state | Добавить onboarding-style empty state с waveform/orb и CTA “Начать первый урок” | Нет придуманных нулевых достижений; есть понятный первый шаг и альтернативный Speaker path |
| Активный пользователь понимает, что делать дальше | В detail screen добавить “Что продолжить”: курс и Speaker | CTA ведут в существующие routes; Profile не становится владельцем учебной навигации |
| Поддержка находится быстро | Объединить support и feedback в “Поддержка и обратная связь” | Один entry point; внутри problem/question/support actions; нет дублей сайта и Telegram в основном списке |
| Legal не занимает много места | Объединить privacy policy и terms в “Правовые документы” | В Profile одна строка; внутри отдельный legal screen с двумя документами |

## P2 — motion, resilience and accessibility

| Scope | Acceptance criteria |
|---|---|
| Onboarding-derived orb/wave motion | Motion работает на profile entry, loading/restore и statistics reveal; не создаёт layout shift |
| Reduced Motion | `prefersReducedMotion`/SwiftUI accessibility setting отключает непрерывные формы и оставляет instant state changes |
| Dynamic Type and VoiceOver | Все rows имеют понятные labels/hints; text does not clip at accessibility sizes |
| Loading/error/offline polish | Every async state has visible loading, retry or recovery; no stuck spinner or blank sheet |
| Analytics audit | Track only meaningful profile actions: account bind, restore, open stats, support, legal; no sensitive text capture |
| Device acceptance | Проверить safe areas, sheet geometry, dark mode, iPhone sizes, TestFlight and Debug channels on physical device |

## Recommended implementation order in the same branch

Сначала отдельный P0 commit: channel separation verification, account/access hierarchy, Apple ID/restore state machine и Taika+ state rendering. Затем P1 commit: statistics entry/detail/empty state, support grouping и combined legal destination. После device feedback — P2 polish commit для motion, reduced motion, Dynamic Type, VoiceOver и async resilience.

Не создавать новую feature branch и не менять Speaker, Dictionary или learning navigation в рамках этого эпика. Все изменения собираются в текущей approved release branch и объединяются в один consolidated delivery после device review.

## Visual acceptance

Каждый informational block использует одну material language: continuous dark canvas, одинаковый blur/border/radius token set и role-specific content density. Статистика использует сферические или хаотичные techno-form motifs только как фон/feedback layer. В production не должно быть резкой границы header/body, пыльного фона, декоративных диаграмм без смысла или больших пустых карточек.

## Owner approval checkpoints

1. Утвердить P0 state map и проверить на device.
2. Проверить, что статистика показывает только реальные данные и не повторяет Home.
3. Проверить Production/TestFlight/Debug boundaries.
4. После acceptance собрать consolidated commit для merge в текущую release branch.
