# Thai Tone Assessment + Smart Speaker API
# Сборка из корня репо: cd taika && docker build -f scripts/thai_tone_assessment/Dockerfile .
FROM python:3.11-slim

RUN apt-get update && apt-get install -y --no-install-recommends ffmpeg \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY scripts/thai_tone_assessment/requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY steps.json ./
COPY scripts/thai_tone_assessment/ ./

ENV TAIKA_STEPS_JSON=/app/steps.json
ENV PYTHONUNBUFFERED=1
EXPOSE 8000

CMD ["uvicorn", "api:app", "--host", "0.0.0.0", "--port", "8000"]
