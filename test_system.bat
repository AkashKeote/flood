@echo off
echo Testing Flood Prediction System...
echo =================================

cd /d "C:\Users\AkashK\Desktop\Akash\flood\flood"

echo Current directory: %CD%
echo.

echo Running comprehensive system test...
python test_flood_system.py

echo.
echo Test completed!
pause