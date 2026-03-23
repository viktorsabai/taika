

# PRO COMPONENT — TAiKA

## 1. BUSINESS ROLE

PRO — это не просто подписка.
Это стратегический слой монетизации и feature-gating внутри Taika.

PRO отвечает за:
- ограничение и расширение функционала
- дифференциацию Free / Pro опыта
- управление доступом к играм
- расширенный Speaker режим
- будущие AI-функции
- premium learning tools

PRO не рисует UI.
PRO не управляет навигацией.
PRO не обучает.

PRO определяет: что доступно пользователю.

---

## 2. POSITION IN PRODUCT ARCHITECTURE

Global Architecture:

Main  
↓  
Course  
↓  
Lessons  
↓  
Step  
↓  
HomeTask / Speaker  

PRO слой — горизонтальный.
Он пересекает все уровни.

Feature gating происходит через ProManager.

---

## 3. PRO MANAGER — ARCHITECTURAL CONTRACT

### ProManager responsibilities:

- хранит состояние подписки
- знает текущий tier
- проверяет entitlement
- синхронизируется с UserSession
- управляет restore / purchase flow
- предоставляет canAccess(feature:) API

### ProManager НЕ должен:

- рисовать paywall
- содержать UI логику
- управлять навигацией
- знать детали HomeTaskManager или StepManager

---

### 3.1 Entitlement Model (v1.1)

ProManager must support:

- feature-based gating (enum ProFeature)
- quota-based gating (AI usage, speaker attempts)
- tier-based configuration (Free / Pro / future Pro+)

Entitlement must NOT be a simple boolean isPro.
It must support:

- canAccess(feature: ProFeature)
- canConsume(quota: ProQuota)
- consume(quota:)

Quota examples:
- speakerAttemptsPerDay
- aiDetailedAnalysisCredits

Quota state must be persisted in UserSession, but calculated through ProManager.

---

## 4. FEATURE GATING STRATEGY

Каждая фича проверяется через:

```
ProManager.shared.can(.featureName)
```

Пример:

- RecallGame (PRO)
- Advanced Speaker scoring
- AI detailed analysis
- Extended lesson packs

Free пользователь:
- видит карточку
- может увидеть preview
- при попытке доступа — показывается PRO overlay

PRO пользователь:
- получает полный доступ
- без редиректов
- без дополнительных проверок в UI

---

### Hard vs Soft Gating

Hard Gating:
- RecallGame
- Advanced Speaker breakdown
- AI detailed analytics

Soft Gating:
- Access allowed but limited attempts
- Upgrade prompt shown after quota exhaustion

All gating decisions must originate from ProManager.
UI must never calculate limits.

---

## 5. FREE VS PRO EXPERIENCE

### FREE:

- базовый match game
- базовый speaker (ограниченный анализ)
- ограниченное количество игр
- soft paywall entry points

### PRO:

- расширенные игры
- syllable builder
- full speaker breakdown
- advanced scoring
- future AI personalization

---

## 6. PAYWALL STRATEGY

PROView — это UI-слой.

Он:
- показывает ценность
- не содержит логики entitlement
- вызывает ProManager для purchase / restore

OverlayPresenter используется для:
- soft paywall
- upsell внутри игр

Не используется для:
- навигации
- постоянных экранов

---

## 7. SCALABILITY

Система должна поддерживать:

- multiple tiers (Pro / Pro+)
- lifetime purchase
- limited time unlock
- experimental feature flags
- AI credit system (quota-based, identity-bound, persisted via UserSession)
- per-feature experimental rollout (feature flags)
- latency-safe mode (disable heavy AI if API unstable)

Расширение происходит через:

- добавление новых enum cases в ProFeature
- обновление can(.feature)
- без изменения UI-слоев

---

## 9.1 Integration With Mastery & Speaker

PRO must integrate with:

- SpeakerManager (advanced scoring enabled only if canAccess(.advancedSpeaker))
- ProgressManager (detailed mastery analytics unlocked via PRO)
- HomeTaskManager (RecallGame unlocked via PRO)

Critical rule:
PRO must never compute mastery or learning logic.
It only gates access to enhanced analysis.


## 8. USER FLOWS

### Flow: Free user taps PRO game

1. User taps RecallGame
2. ProManager.can(.recallGame) → false
3. Показывается PRO overlay
4. После покупки:
   - entitlement обновляется
   - экран перезагружается
   - доступ открывается

### Flow: PRO user

1. Tap game
2. can(.recallGame) → true
3. Игра открывается напрямую

---

## 9. ANTI-PATTERNS

Запрещено:

- проверять isPro напрямую во View
- дублировать gating в нескольких менеджерах
- смешивать UI и subscription logic
- создавать кастомные флаги вне ProManager

Единственная точка правды — ProManager.

---

## 10. SUMMARY

PRO = monetization layer Taika.

Он:
- не интерфейс
- не экран
- не логика уроков

Он — контроль доступа.

Если PRO начинает управлять UI —
архитектура нарушена.

Если UI начинает проверять подписку напрямую —
архитектура нарушена.

ProManager — Single Source of Truth.

Additionally:

- ProManager must restore entitlements on app reinstall (via backend receipt validation or local secure restore).
- Entitlement changes must propagate reactively (Published / ObservableObject).
- No business logic duplication across managers.

This document reflects the actual architectural contract expected by Tech Lead implementation.
