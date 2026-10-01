# Thai Tone Assessment + Smart Speaker API
# Сборка из корня репо: cd taika && docker build -f scripts/thai_tone_assessment/Dockerfile .
FROM python:3.11-slim

RUN apt-get update && apt-get install -y --no-install-recommends ffmpeg \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY scripts/thai_tone_assessment/requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Модель произношения w2p для букв Smart Speaker (thai_translit). Скачиваем при сборке:
# в рантайме без неё буквы деградируют до чтения по написанию без скрытых гласных.
RUN SSL_CERT_FILE="$(python -c 'import certifi; print(certifi.where())')" python -c "\
from pythainlp.corpus import download; download('thai_w2p_npz'); \
from pythainlp.transliterate import pronunciate; \
assert pronunciate('โทรศัพท์', engine='w2p'), 'w2p failed'"

COPY steps.json ./
COPY scripts/thai_tone_assessment/ ./
COPY scripts/thai_taika_phonetic.py ./thai_taika_phonetic.py

ENV TAIKA_STEPS_JSON=/app/steps.json
ENV PYTHONUNBUFFERED=1
ENV PORT=8000
EXPOSE 8000

# Railway injects $PORT; default 8000 for local docker run.
CMD ["sh", "-c", "uvicorn api:app --host 0.0.0.0 --port ${PORT:-8000}"]
