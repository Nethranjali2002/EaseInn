@echo off
echo Starting EaseInn...

echo Starting Backend...
start "Backend" cmd /k "cd backend && npm run dev"

echo Starting Web Dashboard...
start "Web Dashboard" cmd /k "cd frontend\web && flutter run -d chrome"

echo Both started!
