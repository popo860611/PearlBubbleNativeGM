param(
    [Parameter(Mandatory = $false)]
    [string]$GameRoot = (Split-Path -Parent $PSScriptRoot)
)

$Expected = [ordered]@{
    'tmpNew\Lua\PearlBubbleLua\main.lua' = 'B76670884FBEE02F79EE0F9962F524FA35AEF019419186F0597724EC60A40510'
    'tmpNew\Lua\PearlBubbleLua\NativeGMBridge.lua' = '06F554EE83E6C826F22ADF623BA0F89363F96A05C63D2AD61736679934806F27'
    'PearlBubbleNativeGM.exe' = 'B0063DE0AE1557FF7BC9293BA103CDA46E36FA31956A5559A4D7F3AED8A6F610'
}
$AcceptedGameExe = @(
    'C0F42853AAA87079CBA31EDD0C4B7B0777B3DE69CC6F2EFA54C06B0BF76146C0',
    '99B991D853DF49DB23BFA0A07B6B4A769E7FF25D7D9F9C047479FFE66E67D23B'
)

function Get-Sha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    try {
        $sha = [Security.Cryptography.SHA256]::Create()
        try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
        finally { $sha.Dispose() }
    } finally { $stream.Dispose() }
}

$ok = $true
foreach ($relative in $Expected.Keys) {
    $path = Join-Path $GameRoot $relative
    if (-not (Test-Path -LiteralPath $path)) { Write-Host "MISSING  $relative" -ForegroundColor Red; $ok = $false; continue }
    $hash = Get-Sha256 $path
    if ($hash -eq $Expected[$relative]) { Write-Host "PASS     $relative" -ForegroundColor Green }
    else { Write-Host "DRIFTED  $relative`n         $hash" -ForegroundColor Yellow; $ok = $false }
}

$gamePath = Join-Path $GameRoot 'StarMJ371.exe'
if (-not (Test-Path -LiteralPath $gamePath)) {
    Write-Host 'MISSING  StarMJ371.exe' -ForegroundColor Red
    $ok = $false
} else {
    $gameHash = Get-Sha256 $gamePath
    if ($AcceptedGameExe -contains $gameHash) { Write-Host "PASS     StarMJ371.exe`n         $gameHash" -ForegroundColor Green }
    else { Write-Host "DRIFTED  StarMJ371.exe`n         $gameHash" -ForegroundColor Yellow; $ok = $false }
}

if (-not $ok) { exit 1 }
