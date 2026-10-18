$ErrorActionPreference = 'Stop'

$Workspace = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$DotNet = 'D:\tool\dnSpy\32\.dotnet\dotnet.exe'
$Project = Join-Path $PSScriptRoot 'PearlBubbleNativeGM.csproj'
$Output = Join-Path $Workspace 'outputs\PearlBubbleNativeGM'

if (-not (Test-Path -LiteralPath $DotNet)) {
    throw "Bundled .NET SDK not found: $DotNet"
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
