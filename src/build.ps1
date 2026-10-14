$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$DotNetCommand = Get-Command dotnet -ErrorAction SilentlyContinue
$FallbackDotNet = 'D:\tool\dnSpy\32\.dotnet\dotnet.exe'
$Project = Join-Path $PSScriptRoot 'PearlBubbleNativeGM.csproj'
$Output = Join-Path $RepoRoot 'dist\PearlBubbleNativeGM'

if ($DotNetCommand) {
    $DotNet = $DotNetCommand.Source
} elseif (Test-Path -LiteralPath $FallbackDotNet) {
    $DotNet = $FallbackDotNet
} else {
    throw '找不到 .NET 8 SDK；請安裝 .NET 8 SDK 後再建置。'
}

& $DotNet publish $Project `
    -c Release `
    -r win-x86 `
    --self-contained true `
    -p:PublishSingleFile=true `
    -p:DebugType=None `
    -p:DebugSymbols=false `
    -o $Output

if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$Exe = Join-Path $Output 'PearlBubbleNativeGM.exe'
$Hash = (Get-FileHash -LiteralPath $Exe -Algorithm SHA256).Hash
Write-Host "built=$Exe"
Write-Host "sha256=$Hash"
