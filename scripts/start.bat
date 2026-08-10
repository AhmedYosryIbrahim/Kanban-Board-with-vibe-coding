@echo off
setlocal

set IMAGE_NAME=kanban-app
set CONTAINER_NAME=kanban-app
set PORT=3000
set VOLUME_NAME=kanban-data

cd /d "%~dp0.."

where docker >nul 2>&1
if errorlevel 1 (
  echo Error: docker is not installed or not on PATH.
  exit /b 1
)

docker info >nul 2>&1
if errorlevel 1 (
  echo Error: the Docker daemon is not running.
  exit /b 1
)

if not exist .env (
  echo Error: .env not found in %cd%
  echo Create it with: OPENROUTER_API_KEY=your-key
  exit /b 1
)

docker rm -f %CONTAINER_NAME% >nul 2>&1

docker build -t %IMAGE_NAME% .
if errorlevel 1 exit /b 1

docker run -d --name %CONTAINER_NAME% -p %PORT%:%PORT% --env-file .env -v %VOLUME_NAME%:/app/data %IMAGE_NAME%
if errorlevel 1 exit /b 1

echo Kanban is running at http://localhost:%PORT%
