param(
    [string]$Installer = (Join-Path $PSScriptRoot '..\bootstrap-windows\build\KnoxBridgeSetup.exe'),
    [string]$PackageZip = (Join-Path $PSScriptRoot '..\build\distributions\KnoxBridgeRuntime-0.1.0-alpha3.zip')
)
$ErrorActionPreference = 'Stop'
$installerPath = (Resolve-Path -LiteralPath $Installer).Path
$zipPath = (Resolve-Path -LiteralPath $PackageZip).Path
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('KnoxBridge-Installer-Check-' + [guid]::NewGuid().ToString('N'))
$extracted = Join-Path $tempRoot 'payload.zip'
New-Item -ItemType Directory -Path $tempRoot | Out-Null
try {
    $process = Start-Process -FilePath $installerPath -ArgumentList @('--extract-payload', ('"' + $extracted + '"')) -Wait -PassThru -NoNewWindow
    if ($process.ExitCode -ne 0 -or !(Test-Path -LiteralPath $extracted -PathType Leaf)) { throw "Installer payload extraction failed (exit $($process.ExitCode))." }
    $expected = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash
    $actual = (Get-FileHash -LiteralPath $extracted -Algorithm SHA256).Hash
    if ($actual -ne $expected) { throw 'The embedded setup archive differs from the packaged player archive.' }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $contents = [IO.Compression.ZipFile]::OpenRead($extracted)
    try {
        $names = @($contents.Entries | ForEach-Object FullName)
        foreach ($required in @('scripts/user-setup.ps1', 'scripts/install.ps1', 'knoxbridge-agent-0.1.0-alpha3.jar', 'bootstrap-windows/knoxbridge-bootstrap.dll')) {
            if ($names -notcontains $required) { throw "The embedded archive is missing required file: $required" }
        }
    } finally { $contents.Dispose() }
    Write-Output "Standalone Windows installer verification PASS embeddedSha256=$actual"
} finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
