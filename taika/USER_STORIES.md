

# 🌀 Taika — User Stories (Product Backlog v1.0)

## Scope

Документ фиксирует полный набор User Stories для MVP Taika с учетом:
- Step как атомарной единицы обучения
- Lesson / Course иерархии
- HomeTask (Reinforcement)
- Speaker (Pronunciation Engine)
- UserSession / Progress
- PRO-gating
- Premium positioning (Expat-focused)

---

# 1. Core Learning (Step & Lesson)

## 1.1 Step Rendering

**US.1.1 — Step Card**
Как пользователь, я хочу видеть карточку шага (Step) с:
- тайским текстом
- корректной сегментацией по слогам
- транскрипцией
- кнопкой воспроизведения аудио

чтобы я мог соотнести написание, слоги и звук.

**Acceptance Criteria:**
- Слоги отображаются строго в соответствии с `steps.json`
- Тоновые знаки учитываются как часть слога
- Аудио запускается без задержек
- UI соответствует CardDS / AppDS

---

## 1.2 Completion Logic

**US.1.2 — Step Completion**
Как пользователь, я хочу, чтобы Step помечался как Completed только после:
- просмотра
- взаимодействия (аудио или игра)
- или прохождения минимального действия

чтобы Completion не равнялся “прокликал”.

---

## 1.3 Context Awareness

**US.1.3 — Content Type Awareness**
Как пользователь, я хочу видеть тип контента (Word / Phrase / Dialogue),
чтобы понимать применимость в жизни.

---

## 1.4 Navigation

**US.1.4 — Structured Navigation**
Как пользователь, я хочу возвращаться из Step в Lesson,
из Lesson в Course,
через AppShell header,
чтобы структура ощущалась системной.

---

# 2. Reinforcement (HomeTask / Games)

## 2.1 Match Game (Free)

**US.2.1 — Visual Reinforcement**
Как бесплатный пользователь,
я хочу сопоставлять тайское слово с переводом,
чтобы закреплять визуальную память.

---

## 2.2 Recall Game (PRO)

**US.2.2 — Syllable Recall**
Как PRO пользователь,
я хочу собирать фразу из слогов,
чтобы тренировать активное воспроизведение.

**Acceptance Criteria:**
- Количество слотов = количеству слогов из StepData
- Проверка происходит:
  - по нажатию кнопки “Check”
  - либо после полного заполнения
- Никакой автопроверки на каждом тапе
- Неправильные слоги подсвечиваются после проверки
- После успешной сборки — переход к следующему Step

**Mastery Impact:**
- Успешный Recall увеличивает ReinforcementScore
- ReinforcementScore влияет на MasteryScore Step
- Recall не изменяет CompletionState напрямую

---

## 2.3 Validation UX

**US.2.3 — Controlled Validation**
Как пользователь,
я хочу сам инициировать проверку,
чтобы избежать фрустрации от преждевременного red state.

---

## 2.4 Reinforcement Score

**US.2.4 — Mastery Tracking**
Как пользователь,
я хочу видеть рост моего Reinforcement Score,
чтобы понимать прогресс не только в Completion, но и в Mastery.

---

# 3. Pronunciation (Speaker)

## 3.1 Recording

**US.3.1 — Record Attempt**
Как пользователь,
я хочу записать произношение конкретного Step,
чтобы сравнить себя с эталоном.

---

## 3.2 Scoring

**US.3.2 — Pronunciation Score**
Как пользователь,
я хочу получить оценку произношения,
чтобы видеть динамику своего Production-навыка.

**Acceptance Criteria:**
- Оценка сохраняется как отдельный Attempt
- Mastery не рассчитывается по одной попытке
- В расчет Mastery идет:
  - либо среднее последних 3 попыток
  - либо 3 успешные попытки подряд
- Лучший single-score сохраняется отдельно как BestAttempt (для мотивации)

---

## 3.3 Detailed Analytics (PRO)

**US.3.3 — Syllable Feedback**
Как PRO пользователь,
я хочу видеть:
- оценку по слогам
- подсказки по тонам
- слабые зоны

чтобы точечно улучшать речь.

---

# 4. Progress & Session

## 4.1 Main Dashboard

**US.4.1 — Daily Streak**
Как пользователь,
я хочу видеть streak и быстрый доступ к последнему уроку,
чтобы не терять ритм.

---

## 4.2 Course Completion

**US.4.2 — Course Progress**
Как пользователь,
я хочу видеть процент завершения курса,
чтобы понимать масштаб пути.

---

## 4.3 Persistence

**US.4.3 — Session Persistence**
Как пользователь,
я хочу, чтобы прогресс сохранялся после перезапуска,
через UserSession и ProgressManager.

---

## 4.4 Mastery vs Completion

**US.4.4 — Mastery Differentiation**
Как пользователь,
я хочу понимать разницу между Completion и Mastery,
чтобы осознавать реальный уровень владения, а не только факт прохождения.

**Acceptance Criteria:**
- Completion = факт прохождения Step
- Mastery рассчитывается через:
  - Reinforcement (игры)
  - Production (Speaker)
- Один удачный Speaker attempt НЕ делает Step “Mastered”
- Для Mastery требуется стабильность (минимум 3 успешные попытки подряд ИЛИ среднее из последних 3 попыток выше порога)
- LessonsManager может помечать Lesson как “Completed but Low Mastery” (soft warning, без блокировки)

---

# 5. Monetization & PRO

## 5.1 Paywall

**US.5.1 — Contextual Paywall**
Как бесплатный пользователь,
при попытке доступа к PRO-функции,
я хочу видеть:
- преимущества PRO
- конкретную ценность (Recall + Speaker Analytics)

---

## 5.2 Entitlement Sync

**US.5.2 — Instant Unlock**
Как PRO пользователь,
я хочу, чтобы функции активировались мгновенно,
без перезагрузки контента.

---

# 6. Retention Loop

## 6.1 Learning Loop

Как пользователь,
я прохожу цикл:
Step → Reinforcement → Speaker → Progress update → Next Step,
чтобы чувствовать системный рост.

## 6.2 Mastery Decay Notification

**US.6.2 — Mastery Decay Return Loop**  
Как пользователь,  
я хочу получить уведомление, когда мой Step из состояния Stable переходит обратно в Learning,  
чтобы я мог вовремя восстановить знания и не терять навык.

**Acceptance Criteria:**
- MasteryModel должен отслеживать decay по времени или отсутствию активности
- При переходе Stable → Learning Step помечается как “Needs Review”
- Main Dashboard отображает индикатор “Review Required”
- Уведомление может быть:
  - In-app (баннер / badge)
  - Push (Phase 2)
- Это не блокирует доступ к новым Lessons, а формирует Retention Loop

---

# 7. Hidden System Stories (Non-Functional)

## 7.1 Content Integrity

- Контент должен соответствовать Content Standard v1.0
- Слоги не должны ломать Recall или Speaker

## 7.2 Performance

- Speaker latency < 3s
- Game interactions без layout shifts
- Нет overflow за safe area

## 7.3 Architectural Discipline

- Логика в Manager
- UI в DS
- Навигация через NavigationIntent
- Gating через ProManager

## 7.4 Manager Recovery State

**US.7.4 — Mastery Recovery State**

Как система,  
я должен уметь восстановить CompletionState и MasteryScore из UserSession при:
- переустановке приложения
- повторной авторизации
- обновлении версии

чтобы пользователь не терял прогресс освоения.

**Acceptance Criteria:**
- ProgressManager хранит MasteryScore и ReinforcementScore отдельно от Completion
- UserSession сериализует MasteryModel
- При инициализации AppShell выполняется синхронизация состояния
- Отсутствие данных не должно приводить к crash (fallback в Initial state)
- Recovery не нарушает PRO entitlement

---

# 8. Expansion (Phase 2)

- Social Share Pronunciation Score
- Weekly Mastery Report
- Adaptive Difficulty
- Community ranking (optional)

---

# Definition of MVP Ready

MVP считается готовым, если:

1. Step → Recall → Speaker образуют единый Learning Loop  
2. Completion и Mastery считаются раздельно  
3. Recall и Speaker корректно влияют на MasteryScore  
4. PRO gating корректен и не ломает pipeline  
5. Нет логики в DS  
6. Контент соответствует Content Standard v1.0  
7. Нет layout overflow / safe area нарушений  
