@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0deployment\start-local.ps1"
if errorlevel 1 pause
