@echo off
echo ================================================
echo  OpenClaw - Copy Deployment Files to EC2
echo ================================================

cd /d "%~dp0"

echo Copying deployment files to EC2 server...
echo Server: ec2-user@18.206.220.35
echo.

echo Creating directory on server...
ssh -i claw-server-key-server-key.pem ec2-user@18.206.220.35 "mkdir -p ~/openclaw/workspace"

echo Copying .env file (if exists)...
if exist .env (
    scp -i claw-server-key-server-key.pem .env ec2-user@18.206.220.35:~/openclaw/
    echo .env file copied successfully!
) else (
    echo WARNING: .env file not found!
    echo Create .env file from .env.example for production deployment
)

echo Copying deployment compose file...
scp -i claw-server-key-server-key.pem docker-compose.deploy.yml ec2-user@18.206.220.35:~/openclaw/

echo.
echo Deployment files copied successfully!
echo.
echo Files on server:
ssh -i claw-server-key-server-key.pem ec2-user@18.206.220.35 "cd ~/openclaw && ls -la"

echo.
pause
