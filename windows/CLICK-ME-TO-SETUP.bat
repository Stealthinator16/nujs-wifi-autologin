@echo off
echo Requesting administrator access...
powershell -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -NoExit -File \"%~dp0setup.ps1\"' -Verb RunAs"
if %errorlevel% neq 0 (
    echo.
    echo [!] Failed to launch PowerShell. Trying fallback...
    echo.
    powershell -NoProfile -ExecutionPolicy Bypass -NoExit -File "%~dp0setup.ps1" 2>&1 | tee "%~dp0setup-log.txt"
    pause
)
