@echo off
setlocal

set CONTAINER_NAME=kanban-app

where docker >nul 2>&1
if errorlevel 1 (
  echo Error: docker is not installed or not on PATH.
  exit /b 1
)

docker stop %CONTAINER_NAME% >nul 2>&1
docker rm %CONTAINER_NAME% >nul 2>&1

echo Kanban stopped. The kanban-data volume was left in place.
