@echo off
echo ================================================
echo  OpenClaw - Full Rebuild and Deploy
echo  Pulls latest OpenClaw code from GitHub
echo ================================================

cd /d "%~dp0"

echo Step 1: Building production image (no cache - full rebuild)...
docker compose -f docker-compose.prod.yml build --no-cache

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo BUILD FAILED! See errors above.
    pause
    exit /b 1
)

echo Step 2: Pushing image to Docker Hub...
echo Image: jgriffith3433/claw-docker:latest
docker compose -f docker-compose.prod.yml push

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo PUSH FAILED! Make sure you are logged in: docker login
    pause
    exit /b 1
)

echo Step 3: Copying deployment files to server...
call auto-copy-deploy.bat

echo Step 4: Deploying to EC2 server...
echo Server: ec2-user@18.206.220.35
echo.

echo Pulling latest image and restarting service...
ssh -i claw-server-key-server-key.pem ec2-user@18.206.220.35 "cd ~/openclaw && docker compose -f docker-compose.deploy.yml pull && docker compose -f docker-compose.deploy.yml down && docker compose -f docker-compose.deploy.yml up -d"

echo.
echo Step 5: Cleaning up sensitive files on server...
echo Removing .env file from server for security...
ssh -i claw-server-key-server-key.pem ec2-user@18.206.220.35 "cd ~/openclaw && rm -f .env && echo '.env removed from server'"

echo.
echo ================================================
echo  Full deployment completed successfully!
echo ================================================
echo.
echo  Gateway: http://18.206.220.35:18789
echo.
echo  To SSH into server: auto-ssh.bat
echo  To check deployment: ssh and run 'docker ps'
echo.
pause
