@echo off
setlocal
chcp 65001 >nul
title PearlBubble Native GM - Runtime Check

set "IPC=%TEMP%\PearlBubbleNativeGM"
set "STATUS=%IPC%\PearlBubbleNativeGM.status"

echo Runtime IPC: %IPC%
if not exist "%STATUS%" (
    echo.
    echo BRIDGE NOT CONNECTED
    echo Start the game, enter Deep Sea Dragon Pearl, then start the GM panel.
    pause
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$p=$env:STATUS; $age=((Get-Date).ToUniversalTime()-(Get-Item -LiteralPath $p).LastWriteTimeUtc).TotalSeconds; if($age -gt 5){Write-Host ('STALE - bridge has not updated for {0:N1} seconds' -f $age) -ForegroundColor Red; exit 2}else{Write-Host 'PASS - bridge is updating' -ForegroundColor Green}; Get-Content -LiteralPath $p -Encoding UTF8"
set "RC=%ERRORLEVEL%"
echo.
echo Send a screenshot of this window if a button still has no response.
pause
exit /b %RC%
