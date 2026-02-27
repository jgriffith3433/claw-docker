@echo off
echo ================================================
echo  OpenClaw - Docker Environment
echo ================================================
echo.

cd /d "%~dp0"

echo Cleaning up any existing containers...
docker compose -f docker-compose.dev.yml down 2>nul

echo.
echo Building OpenClaw image (this may take a while)...
docker compose -f docker-compose.dev.yml build

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo BUILD FAILED! See errors above.
    pause
    exit /b 1
)

echo.
echo Starting OpenClaw gateway...
docker compose -f docker-compose.dev.yml up -d openclaw-gateway

echo.
echo ================================================
echo  OpenClaw is starting!
echo ================================================
echo.
echo  Gateway:  http://localhost:18789
echo  Web UI:   http://localhost:18789/?token=%OPENCLAW_GATEWAY_TOKEN%
echo  Bridge:   http://localhost:18790
echo.
echo Showing logs (press Ctrl+C to exit)...
echo.
docker compose -f docker-compose.dev.yml logs -f openclaw-gateway
