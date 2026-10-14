param(
    [Parameter(Mandatory = $false)]
    [string]$GameRoot = 'D:\明星\StarAIO'
)

$ErrorActionPreference = 'Stop'
$ExpectedOriginalMain = '00FFAD7C10C87CEB95DA3B6B7D364F841A7D9B42E2F08DE935CC62C64E9BABCC'
$ExpectedInstalledMain = 'B76670884FBEE02F79EE0F9962F524FA35AEF019419186F0597724EC60A40510'
$ExpectedBridge = '63043B62EC78937BB018EBB8171CE38CE209BCB8F3EE3252BA2EE17888B45824'
$ExpectedExe = '774F515D85E4A9CA30817C3D68A31062C06557A11EC043FF3C26D1CA2C13E422'

function Get-Sha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    try {
        $sha = [Security.Cryptography.SHA256]::Create()
        try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
        finally { $sha.Dispose() }
    } finally { $stream.Dispose() }
}

if (Get-Process -Name 'StarMJ371*','PearlBubbleNativeGM' -ErrorAction SilentlyContinue) {
    throw '請先關閉所有 StarMJ371 與 PearlBubbleNativeGM 程序。'
}

$Root = [IO.Path]::GetFullPath($GameRoot)
$Main = Join-Path $Root 'tmpNew\Lua\PearlBubbleLua\main.lua'
$Bridge = Join-Path $Root 'tmpNew\Lua\PearlBubbleLua\NativeGMBridge.lua'
$Exe = Join-Path $Root 'PearlBubbleNativeGM.exe'
$Payload = Join-Path $PSScriptRoot 'payload'
$Backup = Join-Path $Root 'tmpNew\PearlBubbleNativeGM_backup_portable'
$Manifest = Join-Path $Backup 'manifest.json'

foreach ($item in @(
    @{ Path = (Join-Path $Payload 'main.lua'); Hash = $ExpectedInstalledMain },
    @{ Path = (Join-Path $Payload 'NativeGMBridge.lua'); Hash = $ExpectedBridge },
    @{ Path = (Join-Path $Payload 'PearlBubbleNativeGM.exe'); Hash = $ExpectedExe }
)) {
    if (-not (Test-Path -LiteralPath $item.Path)) { throw "安裝包缺少檔案：$($item.Path)" }
    $actual = Get-Sha256 $item.Path
    if ($actual -ne $item.Hash) { throw "安裝包雜湊不符：$($item.Path)" }
}

if (-not (Test-Path -LiteralPath $Main)) { throw "找不到遊戲 main.lua：$Main" }
$CurrentMain = Get-Sha256 $Main
if ($CurrentMain -ne $ExpectedOriginalMain -and $CurrentMain -ne $ExpectedInstalledMain) {
    throw "遊戲版本不相容；main.lua SHA-256=$CurrentMain"
}

New-Item -ItemType Directory -Force -Path $Backup | Out-Null
if (-not (Test-Path -LiteralPath $Manifest)) {
    Copy-Item -LiteralPath $Main -Destination (Join-Path $Backup 'main.lua.original')
    $data = [ordered]@{
        installedAt = (Get-Date).ToString('o')
        gameRoot = $Root
        mainOriginalSha256 = $CurrentMain
        bridgeExisted = (Test-Path -LiteralPath $Bridge)
        exeExisted = (Test-Path -LiteralPath $Exe)
    }
    if ($data.bridgeExisted) { Copy-Item -LiteralPath $Bridge -Destination (Join-Path $Backup 'NativeGMBridge.lua.original') }
    if ($data.exeExisted) { Copy-Item -LiteralPath $Exe -Destination (Join-Path $Backup 'PearlBubbleNativeGM.exe.original') }
    $data | ConvertTo-Json | Set-Content -LiteralPath $Manifest -Encoding UTF8
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Bridge) | Out-Null
Copy-Item -LiteralPath (Join-Path $Payload 'main.lua') -Destination $Main -Force
Copy-Item -LiteralPath (Join-Path $Payload 'NativeGMBridge.lua') -Destination $Bridge -Force
Copy-Item -LiteralPath (Join-Path $Payload 'PearlBubbleNativeGM.exe') -Destination $Exe -Force

Write-Host '安裝完成。' -ForegroundColor Green
& (Join-Path $PSScriptRoot 'status.ps1') -GameRoot $Root

