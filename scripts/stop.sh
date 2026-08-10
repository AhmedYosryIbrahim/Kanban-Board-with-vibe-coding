#!/usr/bin/env bash
set -e

CONTAINER_NAME=kanban-app

if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker is not installed or not on PATH."
  exit 1
fi

docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
docker rm "$CONTAINER_NAME" >/dev/null 2>&1 || true

echo "Kanban stopped. The kanban-data volume was left in place."
