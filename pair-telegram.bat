@echo off
echo ================================================
echo  OpenClaw - Telegram Pairing
echo ================================================
echo.
echo Step 1: Send any message to your bot on Telegram.
echo         You should receive a pairing code.
echo.
echo Step 2: Enter that code below to approve the pairing.
echo.

set /p CODE=Pairing code: 

if "%CODE%"=="" (
    echo No code entered. Aborting.
    pause
    exit /b 1
)

echo.
echo Approving pairing code %CODE%...
docker compose -f docker-compose.dev.yml run --rm openclaw-cli pairing approve %CODE%

echo.
pause
