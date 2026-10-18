@echo off
setlocal DisableDelayedExpansion
chcp 65001 >nul
title PearlBubble Native GM - Install

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

echo ==================================================
echo   PearlBubble Native GM v2.3 - Original EXE Compatible Installer
echo ==================================================
echo.
echo Close StarMJ371 and PearlBubbleNativeGM first.
echo Target game folder: %GAME_ROOT%
echo Place this entire package in the StarAIO game folder before running.
echo Original StarMJ371.exe is accepted and backed up automatically.

echo.
echo Installing to: %GAME_ROOT%
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer\install.ps1" -GameRoot "%GAME_ROOT%"
set "RESULT=%ERRORLEVEL%"

echo.
if "%RESULT%"=="0" (
    echo Installation completed successfully.
    echo The package includes the Deep Sea Dragon Pearl Lua resource pack.
    echo Start StarMJ371.exe, enter Deep Sea Dragon Pearl, then run START_GM.bat.
) else (
    echo Installation failed. Read the error above; no success is claimed.
)
echo.
pause
exit /b %RESULT%

