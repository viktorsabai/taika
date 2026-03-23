# product initiative — taika app

## 1. vision

taika — это персональный digital thai tutor для русскоязычных пользователей.

мы не делаем «еще одно приложение с карточками».
мы строим экосистему обучения:
course → lesson → step → practice → speaker → reinforcement → progress.

ключевая идея:
- обучение через структуру
- минималистичный premium‑дизайн
- эмоциональный контакт (taika как персональная кун кру)
- четкий прогресс и управляемая сложность

---

## 2. target audience

### primary segment
- русскоязычные экспаты в таиланде
- digital nomads
- зимовщики
- люди, планирующие переезд

### secondary segment
- путешественники
- удаленные сотрудники международных компаний
- люди, изучающие тайский «для себя»

pain points:
- нет понятной структуры обучения
- хаос в youtube / tiktok / random-курсах
- сложно понять тональность и фонетику
- нет ощущения реального прогресса

---

## 3. product positioning

taika = structured thai learning system.

мы отличаемся от:
- duolingo (игровизация без глубины)
- random youtube курсов (без структуры)
- локальных thai школ (нет digital continuity)

наши преимущества:
- строгая архитектура обучения (course → lesson → step)
- speaker (практика произношения)
- home task (игровая закрепляющая практика)
- pro‑режим с глубокой аналитикой
- единая айдентика и эмоциональный стиль

---

## 4. core product structure

### 4.1 main
- входная точка
- навигация
- быстрый доступ к курсам
- отображение прогресса

### 4.2 course
- список курсов
- прогресс по каждому курсу
- фильтрация

### 4.3 lessons
- список уроков внутри курса
- статусы: locked / available / completed
- выбор режима практики

### 4.4 step
- учебный материал
- аудио
- транскрипция
- примеры

### 4.5 home task (games)
- match (free)
- recall builder (pro)
- повторение материала

### 4.6 speaker
- запись речи
- анализ
- скоринг
- free режим (упрощенный)
- pro режим (детальная аналитика)

### 4.7 profile
- прогресс
- streak
- активность
- подписка

---

## 5. monetization model

### free
- доступ к базовым курсам
- match game
- базовый speaker (ограниченный функционал)

### pro
- advanced speaker analytics
- recall builder game
- дополнительные режимы практики
- расширенная статистика

модель: подписка (monthly / yearly)

---

## 6. market overview

### рынок
- growing expat population в таиланде
- рост digital nomads
- спрос на локальную интеграцию

конкуренты:
- duolingo
- ling
- italki
- локальные школы

gap:
- нет продукта с фокусом именно на русскоязычную аудиторию
- нет сильной структуры + speaker‑аналитики

---

## 7. key metrics

### acquisition
- installs
- onboarding completion rate

### activation
- first lesson completion
- first speaker attempt

### engagement
- lessons per week
- games per week
- speaker usage frequency

### retention
- day 1 / day 7 / day 30 retention
- streak consistency

### monetization
- free → pro conversion rate
- pro retention
- ARPU

---

## 8. north star metric

active learners completing at least 3 lessons per week.

---

## 9. long-term roadmap

- расширение курсов
- AI‑feedback для speaker
- adaptive difficulty
- spaced repetition engine
- b2b версии для школ

---

## 10. architectural principle

строгий контракт слоев:
- DS = визуал
- View = сборка
- Manager = бизнес‑логика
- Session = глобальное состояние

никаких костылей.
никакой логики в DS.
никаких визуальных дублей.

---

это мета‑эпик продукта taika.

дальше все фичи и эпики должны соответствовать этому документу.

---

## 11. unit economics

### 11.1 pricing hypothesis

- monthly pro: 599–799 thb
- yearly pro: 4 990–6 990 thb
- free → pro target conversion: 5–12%

позиционирование: premium niche, не массовый freemium.

---

### 11.2 cost structure (estimated)

fixed costs:
- development time (founder cost)
- design / content production
- server infrastructure

variable costs:
- speaker api (audio processing / ai scoring)
- cloud storage
- app store commission (15–30%)

примерная переменная стоимость на пользователя (speaker heavy usage):
≈ 20–60 thb / month

---

### 11.3 ltv model (hypothesis)

если:
- средняя подписка = 699 thb / month
- средний срок жизни pro = 6 месяцев

ltv ≈ 4 194 thb

при 10% conversion и 10 000 active users:
1 000 pro users
≈ 699 000 thb / month revenue

---

### 11.4 break-even logic

если инфраструктура + api ≈ 80 000–120 000 thb / month

break-even ≈ 150–200 pro users

это достижимо при ~2 000–3 000 активных free users.

---

## 12. growth strategy

### phase 1 — founder driven
- instagram / personal brand
- reels про жизнь в таиланде
- контент про адаптацию
- экспертность product builder + thai learner

### phase 2 — product-led growth
- встроенные streak‑механики
- sharable progress cards
- referral механика

### phase 3 — partnerships
- коллаборации с expat сообществами
- школы / коворкинги
- relocation‑агентства

---

## 13. motivation & founder thesis

taika — это:
- не просто язык
- а инструмент адаптации
- социальный капитал
- доступ к среде

это проект:
- с высокой маржинальностью
- с нишевым фокусом
- с понятной юнит экономикой
- с возможностью масштабирования в другие языки / рынки

если продукт достигает 5 000 pro пользователей:
≈ 3–4 млн thb / month revenue

это уже устойчивый digital бизнес.

---

## 14. strategic direction

таika не должна превращаться в:
- перегруженную gamification платформу
- дешевый duolingo‑клон
- хаотичный набор функций

она должна оставаться:
- структурированной
- спокойной
- premium
- эмоционально теплой

---

это не просто приложение.
это системный edtech‑бизнес с понятной экономикой.

---

## 15. swot analysis

### strengths
- четкая структурированная архитектура обучения (course → lesson → step)
- нишевый фокус на русскоязычных пользователях в таиланде
- встроенный speaker (реальная практика произношения)
- единая айдентика и системный дизайн
- высокая маржинальность цифрового продукта

### weaknesses
- зависимость от качества и объема контента
- ограниченные ресурсы (solo‑founder stage)
- высокая чувствительность к retention
- зависимость от сторонних api (speaker)

### opportunities
- рост expat / nomad сегмента
- расширение в другие языки (вьетнамский, индонезийский и тд)
- b2b партнерства с relocation и школами
- ai‑адаптивное обучение
- white‑label версии

### threats
- крупные edtech игроки
- копирование концепции
- рост стоимости ai api
- низкий willingness to pay в части аудитории

---

## 16. pricing strategy

### вариант 1 — simple premium
- free
- pro monthly
- pro yearly (–30% к monthly)

рекомендуемый старт:
- pro monthly: 699 thb
- pro yearly: 5 490 thb

---

### вариант 2 — tier model

free:
- базовые курсы
- match game
- ограниченный speaker

pro basic (699 thb):
- полный доступ к курсам
- recall game
- расширенный speaker

pro plus (999 thb):
- advanced analytics
- ai‑feedback
- приоритетная обработка speaker
- будущие премиальные функции

---

## 17. projected operating costs (12 months)

### development
если считать founder time условно:
≈ 150 000 – 300 000 thb / месяц (opportunity cost)

### infrastructure
- server / storage: 20 000 – 40 000 thb
- speaker api: 30 000 – 80 000 thb (зависит от нагрузки)

примерная общая операционная нагрузка:
≈ 80 000 – 150 000 thb / месяц

---

## 18. financial scenarios

### conservative
- 2 000 active users
- 5% conversion
= 100 pro
≈ 69 900 thb / month

### realistic
- 5 000 active users
- 8% conversion
= 400 pro
≈ 279 600 thb / month

### aggressive
- 10 000 active users
- 12% conversion
= 1 200 pro
≈ 838 800 thb / month

---

## 19. long-term valuation logic

при 1 млн thb / month recurring revenue
и 4–6x multiple для edtech saas

valuation ≈ 48–72 млн thb

---

этот документ теперь описывает не только продукт, но и бизнес-модель, риски и финансовую логику taika.
