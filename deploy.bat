@echo off
echo 🚀 Flood Prediction System - Vercel Deployment Script
echo ==================================================

REM Check if Node.js is installed
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Node.js not found. Please install Node.js first.
    echo    Download from: https://nodejs.org/
    pause
    exit /b 1
)

REM Check if Vercel CLI is installed
vercel --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ⚠️  Vercel CLI not found. Installing...
    npm install -g vercel
)

REM Check if we're in the right directory
if not exist "vercel.json" (
    echo ❌ vercel.json not found. Make sure you're in the project root directory.
    pause
    exit /b 1
)

echo ✅ Project structure validated

REM Display project info
echo.
echo 📊 Project Information:
echo    Frontend: Flutter Web (index.html)
echo    Backend: Python Flask APIs
echo    APIs: /api/index.py (main), /api/map.py (routing)

REM Check Python dependencies
echo.
echo 🐍 Checking Python dependencies...
if exist "requirements.txt" (
    echo    ✅ requirements.txt found
    for /f %%i in ('type requirements.txt ^| find /c /v ""') do echo    📦 Dependencies: %%i packages
) else (
    echo    ❌ requirements.txt not found
    pause
    exit /b 1
)

REM Deploy to Vercel
echo.
echo 🚀 Starting Vercel deployment...
echo    This will deploy your app to Vercel's global network
echo.

REM Run vercel deploy
vercel --prod

echo.
echo ✅ Deployment completed!
echo.
echo 🔗 Your app should now be available at the URL shown above
echo.
echo 🧪 Test your deployment:
echo    1. Visit your app URL to see the Flutter frontend
echo    2. Test API: [YOUR_URL]/api/health
echo    3. Test prediction: POST to [YOUR_URL]/api/predict_flood
echo    4. Test map: [YOUR_URL]/api/map?region=andheri
echo.
echo 📚 For more help, see DEPLOYMENT_README.md
echo.
pause
