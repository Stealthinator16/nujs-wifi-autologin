@echo off
cd /d "%~dp0"
echo Requesting administrator access...
powershell -Command "Start-Process cmd -ArgumentList '/k cd /d \"%~dp0\" && python uninstall.py' -Verb RunAs"
