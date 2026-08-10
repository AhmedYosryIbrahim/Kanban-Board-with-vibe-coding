#!/usr/bin/env bash
set -e

IMAGE_NAME=kanban-app
CONTAINER_NAME=kanban-app
PORT=3000
VOLUME_NAME=kanban-data

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker is not installed or not on PATH."
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "Error: the Docker daemon is not running."
  exit 1
fi

if [ ! -f .env ]; then
  echo "Error: .env not found in $ROOT_DIR"
  echo "Create it with: OPENROUTER_API_KEY=your-key"
  exit 1
fi

docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true

docker build -t "$IMAGE_NAME" .

docker run -d \
  --name "$CONTAINER_NAME" \
  -p "$PORT:$PORT" \
  --env-file .env \
  -v "$VOLUME_NAME:/app/data" \
  "$IMAGE_NAME"

echo "Kanban is running at http://localhost:$PORT"
