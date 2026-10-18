param(
    [Parameter(Mandatory = $false)]
    [string]$GameRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
if (Get-Process -Name 'StarMJ371*','PearlBubbleNativeGM' -ErrorAction SilentlyContinue) {
    throw '請先關閉所有 StarMJ371 與 PearlBubbleNativeGM 程序。'
}

$Root = [IO.Path]::GetFullPath($GameRoot)
$Main = Join-Path $Root 'tmpNew\Lua\PearlBubbleLua\main.lua'
$Bridge = Join-Path $Root 'tmpNew\Lua\PearlBubbleLua\NativeGMBridge.lua'
$ControlExe = Join-Path $Root 'PearlBubbleNativeGM.exe'
$GameExe = Join-Path $Root 'StarMJ371.exe'
$Backup = Join-Path $Root 'tmpNew\PearlBubbleNativeGM_backup_portable'
$Manifest = Join-Path $Backup 'manifest.json'

if (-not (Test-Path -LiteralPath $Manifest)) { throw "找不到備份 manifest：$Manifest" }
Copy-Item -LiteralPath (Join-Path $Backup 'main.lua.original') -Destination $Main -Force

$BridgeBackup = Join-Path $Backup 'NativeGMBridge.lua.original'
if (Test-Path -LiteralPath $BridgeBackup) { Copy-Item -LiteralPath $BridgeBackup -Destination $Bridge -Force }
elseif (Test-Path -LiteralPath $Bridge) { Remove-Item -LiteralPath $Bridge -Force }

$ControlBackup = Join-Path $Backup 'PearlBubbleNativeGM.exe.original'
if (Test-Path -LiteralPath $ControlBackup) { Copy-Item -LiteralPath $ControlBackup -Destination $ControlExe -Force }
elseif (Test-Path -LiteralPath $ControlExe) { Remove-Item -LiteralPath $ControlExe -Force }

$GameBackup = Join-Path $Backup 'StarMJ371.exe.original'
if (Test-Path -LiteralPath $GameBackup) {
    Copy-Item -LiteralPath $GameBackup -Destination $GameExe -Force
    Write-Host '已還原原始 StarMJ371.exe。' -ForegroundColor Green
} else {
    Write-Host '沒有 StarMJ371.exe 備份；保持目前遊戲執行檔不變。' -ForegroundColor Yellow
}

Write-Host '已還原安裝前檔案。' -ForegroundColor Green
