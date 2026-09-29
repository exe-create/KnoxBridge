param(
    [Parameter(Mandatory=$true)][string]$PackageZip,
    [string]$OutputDirectory
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$zip = (Resolve-Path -LiteralPath $PackageZip).Path
if (!$OutputDirectory) { $OutputDirectory = Join-Path $root 'bootstrap-windows\build' }
$output = [IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Force -Path $output | Out-Null
$project = Join-Path $root 'windows-installer\KnoxBridge.Installer.csproj'
$dotnetArgs = @(
    'publish', $project, '--configuration', 'Release', '--runtime', 'win-x64', '--self-contained', 'true',
    '-p:PublishSingleFile=true', '-p:IncludeNativeLibrariesForSelfExtract=true', '-p:DebugType=None',
    '-p:DebugSymbols=false', "-p:PayloadPath=$zip", '--output', $output
)
& dotnet @dotnetArgs
if ($LASTEXITCODE -ne 0) { throw "Native Windows installer build failed with exit $LASTEXITCODE." }
$exe = Join-Path $output 'KnoxBridgeSetup.exe'
if (!(Test-Path -LiteralPath $exe)) { throw 'Native Windows installer was not produced.' }
Write-Output "KnoxBridge native Windows installer build PASS path=$exe"
