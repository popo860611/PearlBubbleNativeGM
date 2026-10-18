param(
    [Parameter(Mandatory = $false)]
    [string]$GameRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$ExpectedOriginalMain = '00FFAD7C10C87CEB95DA3B6B7D364F841A7D9B42E2F08DE935CC62C64E9BABCC'
$ExpectedInstalledMain = 'B76670884FBEE02F79EE0F9962F524FA35AEF019419186F0597724EC60A40510'
$ExpectedBridge = '5C7DA14BE8CBB0F7BD9F1BAE68D7D047A2DB99C7C719543343A226BE5FD99493'
$ExpectedExe = '685640AB1881E193C2C2769887E88878DCBC1EF121E4955909BFADFD8F8F3DE4'

# Exact supported StarMJ371 builds. Unknown hashes are never patched.
$PackedOriginalExe = 'DF22272AD7A25A40BC929084C7DED2940AB9F8B1C7887193ACAF8A4013A39FAF'
$FreshUnpackedExe = 'F84886B2D4647D4E7C69721CB9A9F47EDB5040D79134E127EF710B986F16E50B'
$OriginalCompatExe = 'C0F42853AAA87079CBA31EDD0C4B7B0777B3DE69CC6F2EFA54C06B0BF76146C0'
$KnownWorkingV2Exe = '99B991D853DF49DB23BFA0A07B6B4A769E7FF25D7D9F9C047479FFE66E67D23B'
$ExpectedUpx = 'F4C0CC7ACA0F1FF0D0B750E966B44139F2FA1A2DB7281F48FC52194400712E1D'
$PatchOffset = 0x3E6790

function Get-Sha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    try {
        $sha = [Security.Cryptography.SHA256]::Create()
        try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
        finally { $sha.Dispose() }
    } finally { $stream.Dispose() }
}

function Set-OriginalCompatibilityPatch([string]$Path) {
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    try {
        $stream.Position = $PatchOffset
        $before = $stream.ReadByte()
        if ($before -ne 0x75) {
            throw ('StarMJ371 補丁前位元組不符：offset=0x{0:X}, expected=75, actual={1:X2}' -f $PatchOffset, $before)
        }
        $stream.Position = $PatchOffset
        $stream.WriteByte(0xEB)
        # Restore the validated internal helper call used by the known-good v2 build.
        $stream.Position = 0x3E77A9
        $helper = New-Object byte[] 5
        [void]$stream.Read($helper, 0, $helper.Length)
        $expectedHelper = [byte[]](0xE8, 0x92, 0x19, 0xFD, 0xFF)
        if ([BitConverter]::ToString($helper) -ne [BitConverter]::ToString($expectedHelper)) {
            throw ('StarMJ371 helper call 不符：actual={0}' -f [BitConverter]::ToString($helper))
        }
        $stream.Position = 0x3E77A9
        $patchedHelper = [byte[]](0xE8, 0x62, 0x00, 0x00, 0x00)
        $stream.Write($patchedHelper, 0, $patchedHelper.Length)
        $stream.Flush()
    } finally { $stream.Dispose() }
}

if (Get-Process -Name 'StarMJ371*','PearlBubbleNativeGM' -ErrorAction SilentlyContinue) {
    throw '請先關閉所有 StarMJ371 與 PearlBubbleNativeGM 程序。'
}

$Root = [IO.Path]::GetFullPath($GameRoot)
$Main = Join-Path $Root 'tmpNew\Lua\PearlBubbleLua\main.lua'
$Bridge = Join-Path $Root 'tmpNew\Lua\PearlBubbleLua\NativeGMBridge.lua'
$ControlExe = Join-Path $Root 'PearlBubbleNativeGM.exe'
$GameExe = Join-Path $Root 'StarMJ371.exe'
$Payload = Join-Path $PSScriptRoot 'payload'
$Upx = Join-Path $PSScriptRoot 'tools\upx\upx.exe'
$ResourceArchive = Join-Path (Split-Path -Parent $PSScriptRoot) 'resource-pack\PearlBubbleLua_ResourcePack_v2.1.zip'
$Backup = Join-Path $Root 'tmpNew\PearlBubbleNativeGM_backup_portable'
$Manifest = Join-Path $Backup 'manifest.json'

foreach ($item in @(
    @{ Path = (Join-Path $Payload 'main.lua'); Hash = $ExpectedInstalledMain },
    @{ Path = (Join-Path $Payload 'NativeGMBridge.lua'); Hash = $ExpectedBridge },
    @{ Path = (Join-Path $Payload 'PearlBubbleNativeGM.exe'); Hash = $ExpectedExe },
    @{ Path = $Upx; Hash = $ExpectedUpx }
)) {
    if (-not (Test-Path -LiteralPath $item.Path)) { throw "安裝包缺少檔案：$($item.Path)" }
    $actual = Get-Sha256 $item.Path
    if ($actual -ne $item.Hash) { throw "安裝包雜湊不符：$($item.Path)" }
}

if (-not (Test-Path -LiteralPath $Main)) {
    if (-not (Test-Path -LiteralPath $ResourceArchive)) {
        throw "找不到遊戲 main.lua，安裝包也缺少資源包：$ResourceArchive"
    }
    Write-Host '遊戲缺少深海龍珠 Lua，正在由內附資源包補齊…' -ForegroundColor Cyan
    $ExtractRoot = Join-Path ([IO.Path]::GetTempPath()) ('PearlBubbleResource_' + [Guid]::NewGuid().ToString('N'))
    try {
        Expand-Archive -LiteralPath $ResourceArchive -DestinationPath $ExtractRoot -Force
        $ResourceTmpNew = Join-Path $ExtractRoot 'tmpNew'
        if (-not (Test-Path -LiteralPath (Join-Path $ResourceTmpNew 'Lua\PearlBubbleLua\main.lua'))) {
            throw '內附資源包結構不正確，缺少 tmpNew\Lua\PearlBubbleLua\main.lua。'
        }
        $TargetTmpNew = Join-Path $Root 'tmpNew'
        New-Item -ItemType Directory -Force -Path $TargetTmpNew | Out-Null
        Copy-Item -Path (Join-Path $ResourceTmpNew '*') -Destination $TargetTmpNew -Recurse -Force
    } finally {
        if (Test-Path -LiteralPath $ExtractRoot) { Remove-Item -LiteralPath $ExtractRoot -Recurse -Force }
    }
}

if (-not (Test-Path -LiteralPath $Main)) { throw "資源安裝後仍找不到遊戲 main.lua：$Main" }
$CurrentMain = Get-Sha256 $Main
if ($CurrentMain -ne $ExpectedOriginalMain -and $CurrentMain -ne $ExpectedInstalledMain) {
    throw "遊戲版本不相容；main.lua SHA-256=$CurrentMain"
}
if (-not (Test-Path -LiteralPath $GameExe)) { throw "找不到原始遊戲執行檔：$GameExe" }

New-Item -ItemType Directory -Force -Path $Backup | Out-Null
$MainBackup = Join-Path $Backup 'main.lua.original'
$BridgeBackup = Join-Path $Backup 'NativeGMBridge.lua.original'
$ControlBackup = Join-Path $Backup 'PearlBubbleNativeGM.exe.original'
$GameBackup = Join-Path $Backup 'StarMJ371.exe.original'

if (-not (Test-Path -LiteralPath $MainBackup)) { Copy-Item -LiteralPath $Main -Destination $MainBackup }
if ((Test-Path -LiteralPath $Bridge) -and -not (Test-Path -LiteralPath $BridgeBackup)) { Copy-Item -LiteralPath $Bridge -Destination $BridgeBackup }
if ((Test-Path -LiteralPath $ControlExe) -and -not (Test-Path -LiteralPath $ControlBackup)) { Copy-Item -LiteralPath $ControlExe -Destination $ControlBackup }

$CurrentGameHash = Get-Sha256 $GameExe
if ($CurrentGameHash -eq $PackedOriginalExe -or $CurrentGameHash -eq $FreshUnpackedExe) {
    if (-not (Test-Path -LiteralPath $GameBackup)) { Copy-Item -LiteralPath $GameExe -Destination $GameBackup }
    $TempExe = Join-Path $Root ('StarMJ371.compat.' + [Guid]::NewGuid().ToString('N') + '.tmp')
    try {
        if ($CurrentGameHash -eq $PackedOriginalExe) {
            Write-Host '偵測到原始 StarMJ371.exe，正在建立相容版本…' -ForegroundColor Cyan
            & $Upx -q -d -o $TempExe $GameExe
            if ($LASTEXITCODE -ne 0) { throw "UPX 解殼失敗，exit code=$LASTEXITCODE" }
            $UnpackedHash = Get-Sha256 $TempExe
            if ($UnpackedHash -ne $FreshUnpackedExe) { throw "解殼結果雜湊不符：$UnpackedHash" }
        } else {
            Copy-Item -LiteralPath $GameExe -Destination $TempExe
        }
        Set-OriginalCompatibilityPatch $TempExe
        $CandidateHash = Get-Sha256 $TempExe
        if ($CandidateHash -ne $OriginalCompatExe) { throw "相容版本雜湊不符：$CandidateHash" }
        Copy-Item -LiteralPath $TempExe -Destination $GameExe -Force
        $CurrentGameHash = $CandidateHash
    } finally {
        if (Test-Path -LiteralPath $TempExe) { Remove-Item -LiteralPath $TempExe -Force }
    }
} elseif ($CurrentGameHash -ne $OriginalCompatExe -and $CurrentGameHash -ne $KnownWorkingV2Exe) {
    throw "StarMJ371.exe 版本不相容；SHA-256=$CurrentGameHash"
}

$data = [ordered]@{
    installedAt = (Get-Date).ToString('o')
    gameRoot = $Root
    mainOriginalSha256 = (Get-Sha256 $MainBackup)
    bridgeBackupPresent = (Test-Path -LiteralPath $BridgeBackup)
    controlExeBackupPresent = (Test-Path -LiteralPath $ControlBackup)
    gameExeBackupPresent = (Test-Path -LiteralPath $GameBackup)
    gameExeOriginalSha256 = $(if (Test-Path -LiteralPath $GameBackup) { Get-Sha256 $GameBackup } else { $null })
    gameExeInstalledSha256 = $CurrentGameHash
}
$data | ConvertTo-Json | Set-Content -LiteralPath $Manifest -Encoding UTF8

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Bridge) | Out-Null
Copy-Item -LiteralPath (Join-Path $Payload 'main.lua') -Destination $Main -Force
Copy-Item -LiteralPath (Join-Path $Payload 'NativeGMBridge.lua') -Destination $Bridge -Force
Copy-Item -LiteralPath (Join-Path $Payload 'PearlBubbleNativeGM.exe') -Destination $ControlExe -Force

Write-Host '安裝完成。之後直接執行 StarMJ371.exe。' -ForegroundColor Green
& (Join-Path $PSScriptRoot 'status.ps1') -GameRoot $Root

