@echo off
setlocal DisableDelayedExpansion
chcp 65001 >nul
title PearlBubble Native GM - Install

set "DEFAULT_ROOT=D:\明星\StarAIO"
set "GAME_ROOT=%DEFAULT_ROOT%"

echo ==================================================
echo   PearlBubble Native GM v2.1 - Automatic Installer
echo ==================================================
echo.
echo Close StarMJ371 and PearlBubbleNativeGM first.
echo Default game folder: %DEFAULT_ROOT%
echo.
set /p "INPUT_ROOT=Game folder (press Enter for default): "
if not "%INPUT_ROOT%"=="" set "GAME_ROOT=%INPUT_ROOT%"

echo.
echo Installing to: %GAME_ROOT%
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer\install.ps1" -GameRoot "%GAME_ROOT%"
set "RESULT=%ERRORLEVEL%"

echo.
if "%RESULT%"=="0" (
    echo Installation completed successfully.
    echo Start the game, enter Deep Sea Dragon Pearl, then run START_GM.bat.
) else (
    echo Installation failed. Read the error above; no success is claimed.
)
echo.
pause
exit /b %RESULT%

