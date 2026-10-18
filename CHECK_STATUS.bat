@echo off
setlocal DisableDelayedExpansion
chcp 65001 >nul
title PearlBubble Native GM - Status

for %%I in ("%~dp0.") do set "GAME_ROOT=%%~fI"
echo Checking game folder: %GAME_ROOT%

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer\status.ps1" -GameRoot "%GAME_ROOT%"
set "RESULT=%ERRORLEVEL%"
echo.
if "%RESULT%"=="0" (echo Status: PASS) else (echo Status: FAILED or DRIFTED)
pause
exit /b %RESULT%

