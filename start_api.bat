@echo off
echo Starting Flood Prediction API Server...
echo =====================================

cd /d "C:\Users\AkashK\Desktop\Akash\flood\flood\PredictionModel\src"

echo Current directory: %CD%
echo Checking Python installation...
python --version

echo.
echo Starting FastAPI server on http://127.0.0.1:7860
echo Press Ctrl+C to stop the server
echo.

python api.py

pause