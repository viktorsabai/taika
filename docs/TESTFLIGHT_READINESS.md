# TestFlight readiness — первые юзер-тесты

Внутреннее ТЗ / чеклист готовности. Цель первого TF: **guided core-loop** (учить → говорить → лайкать), не полный продукт и не монетизация.

Дата фиксации: 2026-07-24. Обновлено: после disk cleanup + hygiene.

---

## Вердикт

| Цель TF | Статус |
|--------|--------|
| Понятно ли учить / говорить / лайкать | **Да**, после hygiene-списка ниже |
| Покупки / Plus | **Нет**, пока RC + legal |
| Retention / «прогресс не сбросился» | Welcome персистится (`taika.welcome.seen.v1`) |

---

## Блокеры (не звать тестеров на покупки)

1. **RevenueCat** — `REVENUECAT_PUBLIC_API_KEY` в `Info.plist` пустой → paywall «добавьте ключ…».
2. **Legal URLs** — `taika.app/privacy` и `/terms` (см. `TaikaProConfig.Legal`) сейчас 404.
3. **Telegram CTA** — скрыт в soft wall (`AuthSoftWallView`).

Пока 1–2 открыты: TF только на обучение/речь.

---

## Hygiene перед тестерами (high)

- [x] Persist Welcome (не каждый cold start) — `AppStorage("taika.welcome.seen.v1")`
- [x] Человеческие ошибки спикера (без Railway / `start_api.sh` / OPENAI в UI)
- [x] Единое имя продукта в UI: **Taika+** (не PRO / Plus вперемешку)
- [x] About/Plus не продают «личный путь» без двери в Course («Мои»/«Словарь» скрыты)
- [x] Убрать «Голос Таики → Скоро» из хедера Main
- [x] Убрать stub «Язык интерфейса» из профиля
- [x] Словарь — сегмент во вкладке Избранное; иконка книги в хедере Main / Speaker (не Favorites)
- [x] Пустые состояния спикера — сияющая сфера (AI-style), без наслоения старых заглушек
- [x] Боковой вход в Speaker (Favorites / словарь / урок) собирает очередь через `SpeakerRequestedCourseId` (`__favorites__` / `__dictionary__` / courseId)
- [x] Хедер Speaker при возврате: back + логотип (не пустая полоска)

---

## Можно жить в TF (записать в notes)

- Grand Dialogue скрыт (`TaikaReleaseFlags.showGrandDialogue = false`) → Audio Recall.
- Soft wall auth — best-effort (только Apple).
- Оценка спикера — ориентир, не экзамен.
- Словарь / персональные фразы — иконка книги в хедере → Избранное «Словарь» или sheet умного спикера.

---

## Скрипт для тестеров (6 шагов)

1. Cold open → Welcome один раз → Main (разминка / подборка).
2. Course → База → урок → 3–5 степов, 1–2 лайка, аудио.
3. Speaker (тренировка) → запись → любой score; без инженерных текстов.
4. Умный спикер → idle выглядит «ценно»; словарь из хедера.
5. Избранное → карточки; словарь — иконка в хедере.
6. Kill & relaunch → Welcome не каждый раз; прогресс/лайки на месте.

---

## Следующий билд («монетизация»)

Отдельно, когда: RC ключ + offerings, legal pages, paywall карусель проверена на устройстве.
