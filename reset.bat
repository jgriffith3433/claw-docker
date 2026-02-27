@echo off
echo ================================================
echo  OpenClaw - Reset Volume
echo ================================================
echo.
echo This will wipe the config volume and re-seed
echo from openclaw.seed.json on next start.
echo.

cd /d "%~dp0"

echo Stopping containers...
docker compose -f docker-compose.dev.yml down -v

echo.
echo Done! Volume wiped. Run start.bat to rebuild and start fresh.
pause
