# Thai Tone Assessment Engine (Phase C)

Local Python pipeline for Thai pronunciation and tone assessment. Phase C implements the **Pitch Tracker**: segment audio by syllables, extract F0 contours, and compare to the 5 Thai tones (Mid, Low, Falling, High, Rising).

## Setup

```bash
cd scripts/thai_tone_assessment
python3 -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

**m4a / mp3:** For uploads in m4a or mp3, the API converts to WAV with `ffmpeg` before analysis to avoid `librosa.load()` hanging on some systems. Install ffmpeg (e.g. `brew install ffmpeg`) if you use recordings from the iOS app (.m4a).

## Usage

### CLI

```bash
python run_phase_c.py --text "มา" --audio path/to/recording.wav
```

Output: JSON with per-syllable `syllable`, `tone_expected`, `tone_actual`, `tone_score`, `feedback`. Compatible with Phase D API shape.

### API (для мобильного приложения)

Сервер принимает POST с аудиофайлом и текстом, возвращает тот же JSON.

```bash
# Из папки scripts/thai_tone_assessment — одной командой (сам освободит порт 8000, если занят):
./start_api.sh
# Или вручную:
python -m uvicorn api:app --reload --host 0.0.0.0 --port 8000
```

**Порт 8000 занят (Address already in use):** завершай только сервер, не клиенты (иначе можно «убить» приложение в симуляторе). На macOS:
```bash
# Только процесс, слушающий порт 8000 (uvicorn):
lsof -i :8000 -sTCP:LISTEN -t | xargs kill
```

Пример запроса (curl):

```bash
curl -X POST http://localhost:8000/assess \
  -F "file=@recording.wav" \
  -F "text=มา" \
  -F "expected_tones=Mid"
```

Ответ: `{"total_score": 85, "syllables": [{ "syllable": "มา", "tone_expected": "Mid", "tone_actual": "Mid", "tone_score": 95, "feedback": "Perfect", ... }]}`.

**Тест на устройстве (iPhone/iPad в одной Wi‑Fi с Mac):**
1. На Mac запусти API из этой папки: `./start_api.sh`.
2. Узнай IP Mac (Системные настройки → Сеть, или в терминале: `ipconfig getifaddr en0`).
3. В Xcode: Product → Scheme → Edit Scheme… → Run → вкладка Arguments → Environment Variables. Добавь переменную `TAIKA_TONE_API_URL` = `http://192.168.1.104:8000` (без слэша в конце).
4. Собери и запусти taika на устройстве. Разбор тонов будет ходить на твой Mac по Wi‑Fi.

**Почему в приложении пишет «Не удалось загрузить разбор по тонам»:**

- **Симулятор:** API должен быть запущен на том же Mac (`./start_api.sh` из этой папки). В Debug для симулятора URL по умолчанию `http://127.0.0.1:8000`.
- **Устройство:** В Xcode задана переменная `TAIKA_TONE_API_URL` = `http://<IP Mac>:8000`. Mac и iPhone в одной Wi‑Fi сети.
- **Сервер упал или не ответил:** В консоли, где запущен uvicorn, появятся ошибки (таймаут, исключение в pitch_tracker и т.д.). Проверь логи и README (trim, ffmpeg, порт).
- **Ответ без `syllables`:** Сервер вернул не 2xx или JSON без массива `syllables`. В Xcode консоли приложения при запросе разбора выводится `[speaker] tone API: ...` — смотри статус и ответ.

## Input

- **--text**: Thai word or phrase (target).
- **--audio**: Path to WAV file (user recording). Mono preferred; will be resampled to 16 kHz if needed.
- **expected_tones** (optional): Comma-separated expected tone per syllable, e.g. `Mid,Low` for สวัสดีครับ. If omitted, all syllables are compared to **Mid** — so scores can be low when the correct tone is Low/Falling/High/Rising. For better scores, send expected tones from your content (e.g. from step/card data).

## Output (Phase C)

```json
{
  "syllables": [
    {
      "syllable": "มา",
      "tone_expected": "Mid",
      "tone_actual": "Mid",
      "tone_score": 95,
      "feedback": "Perfect"
    }
  ]
}
```

Later (Phase D): `total_score`, `phoneme_score` per syllable when GoP is wired.

## Modules

- **pitch_tracker.py**: Load WAV (librosa), segment by syllables: **energy-based boundaries** (RMS, local minima) или equal-duration fallback; extract F0 (librosa.pyin).
- **tone_templates.py**: Reference contours for 5 Thai tones (normalized semitones).
- **tone_compare.py**: Normalize user F0, DTW vs templates, tone_score 0–100, **specific feedback** («You used X instead of Y»).
- **run_phase_c.py**: CLI and JSON output; каждый слог возвращает **f0_contour** (нормализованный контур в полутонах) для графика в UI.

## Тестирование

Не нужно гонять тысячи фраз скриптом. В приложении при тапе «получить разбор» отправляется один запрос на `/assess` с текущей фразой и записью — этого достаточно для проверки. Массовый прогон (например, по списку фраз + эталонным аудио) можно добавить отдельным скриптом при необходимости.

## Verification

```bash
# Generate a short test tone (200 Hz, 0.5 s) and run Phase C
python -c "
import numpy as np, scipy.io.wavfile as wav
sr, y = 16000, (np.sin(2*np.pi*200*np.linspace(0,0.5,int(0.5*sr)))*0.3*32767).astype(np.int16)
wav.write('_test.wav', sr, y)
"
python run_phase_c.py --text "มา" --audio _test.wav --pretty
```

Expect JSON with `syllables[].tone_actual`, `tone_score`, `feedback`. A flat pitch (e.g. sine tone) should match **Mid** and score high. Run on real Thai recordings to tune template curves or DTW scale (`tone_compare.DTW_K`) if needed.

---

## Материал из steps.json

Фразы для спикера лежат в `steps.json` в корне репо. Скрипт `steps_to_contours.py`:

- **Манифест** — список всех phrase/casual/word с `thai`, `phonetic`, `expected_tones` (из стрелок ↘→↗ в phonetic):
  ```bash
  python steps_to_contours.py --manifest-only -o manifest.json
  ```
  По умолчанию читает `../../steps.json` (относительно папки скрипта). Всего ~2k фраз.

- **Эталонные контуры из WAV** — если есть папка с эталонными записями (один WAV на фразу), можно собрать `reference_contours.json` для подстановки реальных контуров вместо синтетических шаблонов. Имена файлов: `{step_id}.wav` или `{thai_без_пробелов}.wav`, например `course_b_1_l1_steps_1.wav` или `สวัสดี.wav`:
  ```bash
  python steps_to_contours.py --audio-dir /path/to/reference_wavs -o reference_contours.json
  ```
  Выход: `{ "step_id": { "syllables": [ { "syllable", "f0_contour" } ], "thai": "..." } }`. Дальше бэкенд или приложение могут подставлять эти контуры в разбор вместо плоского эталона.

---

## Почему нули? Что проверить

| Причина | Где | Что сделано / что проверить |
|--------|-----|-----------------------------|
| **Тишина** | `pitch_tracker.load_and_trim`: `top_db=25` режет по тишине | Снижен до **20** (`TRIM_TOP_DB`). Если trim отрезал >85% записи — trim отключается, используется полный файл. Тихий iPhone меньше «съедается». |
| **Нормализация** | `tone_compare.hz_to_semitones`: медиана по сегменту | Медиана ограничена диапазоном **80–350 Hz** (`REF_HZ_MIN/MAX`). Короткий/шумный фрагмент не даёт нереальную высоту и не уводит контур от шаблонов. |
| **Строгость DTW** | `tone_compare.DTW_K`: score = 100 − k×dist | **DTW_K = 5.0** (было 8): алгоритм мягче к отклонениям. Dist 10 → ~50%, dist 5 → ~75%. При стабильных нулях можно понизить до 4.0. |
| **Нет F0 в сегменте** | pYIN не нашёл голос в куске аудио | В консоли сервера: если в логах есть `f0_hz` с числами — проблема в калибровке/шаблонах; если пусто/NaN — запись тихая или сегмент слишком короткий. |

`get_feedback` не режет результат по порогу: он всегда возвращает тон и текст. Нули приходят только из `tone_score_from_distance` (DTW). Смягчение: меньше `DTW_K`, мягче trim, ограничение медианы.

**Отладка «почему 0»:** при каждом запросе `POST /assess` в консоль сервера (где запущен uvicorn) пишется обоснование разбора с префиксом `[tone_assess]`: длина аудио, число слогов и сегментов, по каждому слогу — число кадров с F0, мин/макс Hz, пустой ли контур, медиана для полутонов, DTW-дистанции до шаблонов и итоговый score. Смотри консоль после тапа «получить разбор».

---

## Roadmap vs текущая реализация (Loora-style)

| Шаг | Цель | Сейчас |
|-----|------|--------|
| **А. Разбивка на слоги** | PyThaiNLP: expectedThai → слоги | ✅ `get_syllables_from_text()` (han_solo). Ограничение: иногда одно слово = один токен. |
| **Эталонный тон** | Для каждого слога ожидаемый тон (Low, Mid, …) | ✅ Параметр `expected_tones`, по умолчанию Mid. |
| **Б. Временные метки** | Границы слогов по звуку, не «математика» | ✅ **Energy-based**: границы по RMS/тишине (локальные минимумы). Fallback: equal-duration. MFA/Wav2Vec2 опционально позже. |
| **В. Оценка тона** | F0 → контур → сравнение с эталоном | ✅ F0 (librosa.pyin), нормализация, DTW с 5 шаблонами, tone_score 0–100, feedback. |
| **PhonemeAccuracy** | Отдельно «звук слога» (распознан/нет) | ❌ `phoneme_score` в ответе пока `null` (заглушка под Phase D). |
| **Hybrid score** | Total = 0.4×Text + 0.3×Phoneme + 0.3×Tone | ✅ API принимает `text_score`, возвращает `hybrid_score`. Пока phoneme_avg = tone_avg. |
| **UI разбор** | Loora-style: стрелки тонов, цвета, кривая | ✅ Зелёный 90–100, жёлтый 50–89, красный 0–49. Тональные стрелки (ожидаемый vs фактический). Фидбек из API. Мини-график контура (f0_contour). |
