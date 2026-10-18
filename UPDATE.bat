@echo off
setlocal
chcp 65001 >nul
title PearlBubble Native GM - Update

echo Close StarMJ371 and PearlBubbleNativeGM before updating.
echo Existing backups and account data will be preserved.
echo.
call "%~dp0INSTALL.bat"
exit /b %ERRORLEVEL%
