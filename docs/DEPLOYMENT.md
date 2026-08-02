# Деплой интеграционного API (Smart Speaker + Tone Assessment)

## Текущее состояние

- **Локально:** API на Mac (`./start_api.sh`), приложение подключается по `http://192.168.x.x:8000` в одной Wi‑Fi сети
- **Release-сборка:** `toneAssessmentBaseURL == nil` — API не вызывается, Smart Speaker и разбор по тонам недоступны

## Что нужно для TestFlight / App Store

1. **Бэкенд API** — публичный HTTPS URL, доступный с любого устройства
2. **iOS app** — использовать этот URL в Release-сборках вместо `nil`

---

## Компоненты API

| Эндпоинт | Зависимости | Сложность деплоя |
|----------|-------------|------------------|
| `POST /smart_speaker` | FastAPI, steps.json, SQLite, опционально OpenAI | Легко |
| `POST /assess` | + librosa, scipy, ffmpeg, PyThaiNLP | Тяжелее |

**Рекомендация:** сначала поднять **только Smart Speaker** — он легкий и даёт основной UX. Разбор по тонам (assess) можно добавить позже.

---

## Варианты деплоя

### 1. Railway / Render / Fly.io (быстрый старт)

**Railway** (рекомендуется для старта):
- Подключить репозиторий
- Указать папку `scripts/thai_tone_assessment`
- Добавить переменные: `TAIKA_STEPS_JSON` (или bundled), `OPENAI_API_KEY` (опционально)
- Автодеплой из `main`

**Render:**
- Web Service, Python, Build: `pip install -r requirements.txt`
- Start: `uvicorn api:app --host 0.0.0.0 --port $PORT`
- Нужен `render.yaml` или настройки в UI

**Fly.io:**
- `fly launch` в папке API
- Требуется `Dockerfile` (см. ниже)

### 2. VPS (Hetzner, DigitalOcean, etc.)

Полный контроль, стабильно, ~5–10 €/мес:

```bash
# На сервере
git clone <repo>
cd taika/scripts/thai_tone_assessment
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
# systemd или pm2 для автозапуска
uvicorn api:app --host 0.0.0.0 --port 8000
# Nginx + Let's Encrypt для HTTPS
```

### 3. Разделить Smart Speaker и Tone Assessment

- **Smart Speaker** — отдельный легкий сервис (FastAPI + steps.json + SQLite)
- **Tone Assessment** — отдельный тяжелый сервис (librosa, ffmpeg) или отключить в проде до готовности

---

## Минимальные шаги для TestFlight (Smart Speaker)

### Шаг 1: Деплой API

**Вариант A — Railway:**

1. [railway.app](https://railway.app) → проект → сервис **taika**
2. **Settings → Source → Root Directory** — оставь **пустым** (корень репо).  
   Не `scripts/thai_tone_assessment`: Dockerfile копирует `steps.json` из корня репо.
3. **Settings → Build → Builder** — **Dockerfile** (не Railpack).
4. **Settings → Build → Dockerfile path** — `scripts/thai_tone_assessment/Dockerfile`  
   (или положись на `railway.json` в корне — там `"builder": "DOCKERFILE"`).
5. **Variables:**
   - `OPENAI_API_KEY` — ключ OpenAI (для новых фраз)
   - `TAIKA_SMART_MODEL` — `gpt-4o-mini` (опционально)
6. **Deploy** → Redeploy (старый failed deploy 3 месяца назад не перезапустится сам — нужен новый деплой после push в GitHub).

Если видишь **«Error creating build plan with Railpack»** — Railway игнорирует Dockerfile. Проверь п.2–4 и что в репо есть актуальный `railway.json` с `"builder": "DOCKERFILE"`.

**Вариант B — Docker:**

Сборка из корня репо (`taika/`):

```bash
cd taika
docker build -f scripts/thai_tone_assessment/Dockerfile .
```

`Dockerfile` уже есть: копирует `steps.json` и API в образ.

### Шаг 2: iOS — URL для Release

Сейчас в Release `toneAssessmentBaseURL` и `smartSpeakerBaseURL` = `nil`.

**Варианты:**

1. **xcconfig** — отдельный конфиг для Release с `TAIKA_API_BASE_URL = https://xxx.railway.app`
2. **Info.plist** — ключ `TaikaAPIBaseURL`, читать в коде
3. **Прямо в коде** — для релиза подставлять прод URL

Пример изменения в `SpeakerManager.swift`:

```swift
// В Release: подставлять прод URL из Info.plist или константы
#if DEBUG
// ... текущая логика
#else
// Release: прод URL из Info.plist или xcconfig
static var toneAssessmentBaseURL: String? = {
    if let url = Bundle.main.object(forInfoDictionaryKey: "TaikaAPIBaseURL") as? String, !url.isEmpty {
        return url
    }
    return nil
}()
#endif
```

В `Info.plist` уже есть ключ `TaikaAPIBaseURL` — заполни его прод URL:

```xml
<key>TaikaAPIBaseURL</key>
<string>https://your-api.up.railway.app</string>
```

Без слэша в конце. В Release-сборке приложение читает этот URL автоматически.

### Шаг 3: Тест

1. API задеплоен, есть HTTPS URL
2. Добавить URL в Info.plist или в код
3. Собрать Release, загрузить в TestFlight
4. Установить на устройство — Smart Speaker должен работать без локальной сети

---

## Что усложняет «сразу стабильно»

1. **Сеть** — локальный IP работает только в одной Wi‑Fi. Нужен публичный HTTPS
2. **HTTPS** — App Store требует HTTPS для внешних запросов (ATS)
3. **Ресурсы** — `/assess` с librosa + ffmpeg может требовать 512MB–1GB RAM
4. **steps.json** — должен быть доступен на сервере (в репо, в образе или через env)

---

## Чеклист перед TestFlight

- [ ] API задеплоен (Railway / Render / VPS)
- [ ] URL HTTPS и доступен с любого устройства
- [ ] `steps.json` на месте
- [ ] Smart Speaker отвечает на `POST /smart_speaker` (проверить curl)
- [ ] `TaikaAPIBaseURL` в Info.plist или коде для Release
- [ ] Собрана Release-сборка, Smart Speaker работает на TestFlight-установке

---

## Диагностика Smart Speaker

Проверка с Mac (подставь свой URL из Railway):

```bash
# 1. Сервер жив?
curl -s https://taika-production.up.railway.app/health

# Ожидается: {"status":"ok","steps_json":true,"openai_configured":true,"model":"gpt-4o-mini"}
# Если {"message":"Application not found"} — проект на Railway удалён или спит; нужен передеплой.

# 2. Перевод фразы из steps.json (без OpenAI)
curl -s -X POST https://taika-production.up.railway.app/smart_speaker \
  -H "Content-Type: application/json" \
  -d '{"text_ru":"Привет","politeness":"female"}'

# 3. Произвольная фраза (нужен OPENAI_API_KEY в Railway Variables)
curl -s -X POST https://taika-production.up.railway.app/smart_speaker \
  -H "Content-Type: application/json" \
  -d '{"text_ru":"Привет как дела","politeness":"female"}'
```

**Переменные Railway (обязательно для новых фраз):**

| Variable | Значение |
|----------|----------|
| `OPENAI_API_KEY` | ключ OpenAI |
| `TAIKA_SMART_MODEL` | `gpt-4o-mini` (опционально) |
| `TAIKA_STEPS_JSON` | `/app/steps.json` (уже в Dockerfile) |

После добавления переменных — **Redeploy** сервиса. Docker слушает `$PORT` (Railway подставляет автоматически).
