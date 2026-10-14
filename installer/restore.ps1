param(
    [Parameter(Mandatory = $false)]
    [string]$GameRoot = 'D:\明星\StarAIO'
)

$ErrorActionPreference = 'Stop'
if (Get-Process -Name 'StarMJ371*','PearlBubbleNativeGM' -ErrorAction SilentlyContinue) {
    throw '請先關閉所有 StarMJ371 與 PearlBubbleNativeGM 程序。'
}

$Root = [IO.Path]::GetFullPath($GameRoot)
$Main = Join-Path $Root 'tmpNew\Lua\PearlBubbleLua\main.lua'
$Bridge = Join-Path $Root 'tmpNew\Lua\PearlBubbleLua\NativeGMBridge.lua'
$Exe = Join-Path $Root 'PearlBubbleNativeGM.exe'
$Backup = Join-Path $Root 'tmpNew\PearlBubbleNativeGM_backup_portable'
$Manifest = Join-Path $Backup 'manifest.json'

if (-not (Test-Path -LiteralPath $Manifest)) { throw "找不到備份 manifest：$Manifest" }
$data = Get-Content -LiteralPath $Manifest -Raw -Encoding UTF8 | ConvertFrom-Json
Copy-Item -LiteralPath (Join-Path $Backup 'main.lua.original') -Destination $Main -Force

if ($data.bridgeExisted) {
    Copy-Item -LiteralPath (Join-Path $Backup 'NativeGMBridge.lua.original') -Destination $Bridge -Force
} elseif (Test-Path -LiteralPath $Bridge) {
    Remove-Item -LiteralPath $Bridge -Force
}

if ($data.exeExisted) {
    Copy-Item -LiteralPath (Join-Path $Backup 'PearlBubbleNativeGM.exe.original') -Destination $Exe -Force
} elseif (Test-Path -LiteralPath $Exe) {
    Remove-Item -LiteralPath $Exe -Force
}

Write-Host '已還原安裝前檔案。' -ForegroundColor Green

