@echo off
setlocal DisableDelayedExpansion
chcp 65001 >nul
title PearlBubble Native GM - Status

set "DEFAULT_ROOT=D:\明星\StarAIO"
set "GAME_ROOT=%DEFAULT_ROOT%"
set /p "INPUT_ROOT=Game folder (press Enter for %DEFAULT_ROOT%): "
if not "%INPUT_ROOT%"=="" set "GAME_ROOT=%INPUT_ROOT%"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer\status.ps1" -GameRoot "%GAME_ROOT%"
set "RESULT=%ERRORLEVEL%"
echo.
if "%RESULT%"=="0" (echo Status: PASS) else (echo Status: FAILED or DRIFTED)
pause
exit /b %RESULT%

