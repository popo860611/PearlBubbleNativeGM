@echo off
setlocal DisableDelayedExpansion
chcp 65001 >nul
title PearlBubble Native GM - Start

set "DEFAULT_ROOT=D:\明星\StarAIO"
set "GAME_ROOT=%DEFAULT_ROOT%"
echo Start the game and enter Deep Sea Dragon Pearl first.
echo.
set /p "INPUT_ROOT=Game folder (press Enter for %DEFAULT_ROOT%): "
if not "%INPUT_ROOT%"=="" set "GAME_ROOT=%INPUT_ROOT%"

if not exist "%GAME_ROOT%\PearlBubbleNativeGM.exe" (
    echo ERROR: %GAME_ROOT%\PearlBubbleNativeGM.exe was not found.
    pause
    exit /b 1
)

start "PearlBubble Native GM" "%GAME_ROOT%\PearlBubbleNativeGM.exe" --root "%GAME_ROOT%"
echo Native GM started. Press Insert to show or hide the menu.
timeout /t 3 >nul
exit /b 0

