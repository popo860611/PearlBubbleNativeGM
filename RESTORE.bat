@echo off
setlocal DisableDelayedExpansion
chcp 65001 >nul
title PearlBubble Native GM - Restore

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
echo Close StarMJ371 and PearlBubbleNativeGM first.
echo Restore game folder: %GAME_ROOT%

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer\restore.ps1" -GameRoot "%GAME_ROOT%"
set "RESULT=%ERRORLEVEL%"
echo.
if "%RESULT%"=="0" (echo Restore completed.) else (echo Restore failed.)
pause
exit /b %RESULT%

