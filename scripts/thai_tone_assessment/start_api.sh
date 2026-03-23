#!/bin/bash
# Освобождает порт 8000 (только сервер) и запускает API. Запускай из этой папки.
cd "$(dirname "$0")"
PID=$(lsof -i :8000 -sTCP:LISTEN -t 2>/dev/null)
if [ -n "$PID" ]; then
  echo "Освобождаю порт 8000 (PID $PID)..."
  kill -9 $PID 2>/dev/null
  sleep 1
fi
source .venv/bin/activate
# Явно задаём путь к steps.json (относительно папки api)
export TAIKA_STEPS_JSON="$(cd "$(dirname "$0")/../.." && pwd)/steps.json"
# Без --reload: сервер стабилен, не перезапускается при изменениях в lib-файлах.
# Для hot-reload при правке api.py запускай вручную: uvicorn api:app --reload --host 0.0.0.0 --port 8000
exec python -m uvicorn api:app --host 0.0.0.0 --port 8000
