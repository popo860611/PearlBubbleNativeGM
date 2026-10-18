@echo off
setlocal DisableDelayedExpansion
chcp 65001 >nul
title PearlBubble Native GM - Start

set "PB_SELF=%~f0"
set "PB_DIR=%~dp0"
fltmc >nul 2>&1
if errorlevel 1 (
    echo Requesting administrator privileges for the Program Files game folder...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { Start-Process -FilePath $env:PB_SELF -WorkingDirectory $env:PB_DIR -Verb RunAs -ErrorAction Stop } catch { exit 1 }"
    if errorlevel 1 (
        echo Administrator permission was not granted.
        pause
        exit /b 1
    )
    exit /b 0
)

for %%I in ("%~dp0.") do set "GAME_ROOT=%%~fI"
echo Start the game and enter Deep Sea Dragon Pearl first.
echo Game folder: %GAME_ROOT%

if not exist "%GAME_ROOT%\PearlBubbleNativeGM.exe" (
    echo ERROR: %GAME_ROOT%\PearlBubbleNativeGM.exe was not found.
    pause
    exit /b 1
)

start "PearlBubble Native GM" "%GAME_ROOT%\PearlBubbleNativeGM.exe" --root "%GAME_ROOT%"
echo Native GM started. Press Insert to show or hide the menu.
timeout /t 3 >nul
exit /b 0

