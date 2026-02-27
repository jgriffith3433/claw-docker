@echo off
:: Read token from .env file
for /f "tokens=2 delims==" %%a in ('findstr "OPENCLAW_GATEWAY_TOKEN" "%~dp0.env"') do set TOKEN=%%a
if "%TOKEN%"=="" (
    echo ERROR: Could not find OPENCLAW_GATEWAY_TOKEN in .env
    pause
    exit /b 1
)
start "" "http://localhost:18789/?token=%TOKEN%"
