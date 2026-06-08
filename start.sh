#!/bin/bash
echo "Starting EaseInn..."

# Start backend
echo "Starting Backend..."
cd backend
npm run dev &
BACKEND_PID=$!
cd ..

# Start web dashboard
echo "Starting Web Dashboard..."
cd frontend/web
flutter run -d chrome &
WEB_PID=$!
cd ../..

# Wait for both
wait $BACKEND_PID $WEB_PID
