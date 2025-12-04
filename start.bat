@echo off
echo Starting Image Bed Backend...
cd backend
start "ImageBed Backend" go run main.go

timeout /t 3

echo Starting Image Bed Frontend...
cd ..\frontend
start "ImageBed Frontend" npm run dev

echo.
echo ========================================
echo Image Bed System is starting...
echo Backend: http://localhost:8080
echo Frontend: http://localhost:5173
echo ========================================
echo.
pause
