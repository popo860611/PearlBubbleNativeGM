param(
    [Parameter(Mandatory = $false)]
    [string]$GameRoot = 'D:\明星\StarAIO'
)

$Expected = [ordered]@{
    'tmpNew\Lua\PearlBubbleLua\main.lua' = 'B76670884FBEE02F79EE0F9962F524FA35AEF019419186F0597724EC60A40510'
    'tmpNew\Lua\PearlBubbleLua\NativeGMBridge.lua' = '63043B62EC78937BB018EBB8171CE38CE209BCB8F3EE3252BA2EE17888B45824'
    'PearlBubbleNativeGM.exe' = '774F515D85E4A9CA30817C3D68A31062C06557A11EC043FF3C26D1CA2C13E422'
}

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
    if (-not (Test-Path -LiteralPath $path)) {
        Write-Host "MISSING  $relative" -ForegroundColor Red
        $ok = $false
        continue
    }
    $hash = Get-Sha256 $path
    if ($hash -eq $Expected[$relative]) {
        Write-Host "PASS     $relative" -ForegroundColor Green
    } else {
        Write-Host "DRIFTED  $relative`n         $hash" -ForegroundColor Yellow
        $ok = $false
    }
}

if (-not $ok) { exit 1 }

