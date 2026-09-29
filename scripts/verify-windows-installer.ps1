param(
    [string]$Installer = (Join-Path $PSScriptRoot '..\bootstrap-windows\build\KnoxBridgeSetup.exe'),
    [string]$PackageZip = (Join-Path $PSScriptRoot '..\build\distributions\KnoxBridgeRuntime-0.1.0-alpha8.zip')
)
$ErrorActionPreference = 'Stop'
$installerSource = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\windows-installer\Program.cs') -Raw
if ($installerSource -match '(?i)(powershell\.exe|cmd\.exe|CreateProcessW|Process\.Start)') {
    throw 'The Windows installer must not start a command interpreter or PowerShell child process.'
}
if ($installerSource -match 'Manage module trust') { throw 'Module allow/deny decisions belong to the Bridge in-game UI, not the installer.' }
$installerPath = (Resolve-Path -LiteralPath $Installer).Path
$zipPath = (Resolve-Path -LiteralPath $PackageZip).Path
$expected = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToUpperInvariant()
$payloadResult = & $installerPath --verify-payload
if ($LASTEXITCODE -ne 0 -or -not ($payloadResult -match [regex]::Escape("sha256=$expected"))) {
    throw 'The installer embedded payload did not match the verified player archive.'
}
$selfTest = & $installerPath --self-test
if ($LASTEXITCODE -ne 0 -or -not ($selfTest -match 'self-test PASS checks=8')) { throw 'The native installer fixture self-test failed.' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$contents = [IO.Compression.ZipFile]::OpenRead($zipPath)
try {
    $names = @($contents.Entries | ForEach-Object FullName)
    $agent = @($names | Where-Object { $_ -match '^knoxbridge-agent-.+\.jar$' } | Select-Object -First 1)
    if ($agent.Count -ne 1 -or $names -notcontains ($agent[0] + '.sha256')) { throw 'The player archive must contain exactly one versioned KnoxBridge agent and its checksum.' }
    foreach ($required in @('bootstrap-windows/knoxbridge-bootstrap.dll', 'bootstrap-windows/knoxbridge-bootstrap.dll.sha256', 'scripts/setup-unix.sh', 'scripts/setup-unix.py')) {
        if ($names -notcontains $required) { throw "The player archive is missing required file: $required" }
    }
    foreach ($forbidden in @('KnoxBridge Setup.cmd', 'scripts/user-setup.ps1', 'scripts/install.ps1', 'scripts/uninstall.ps1')) {
        if ($names -contains $forbidden) { throw "The player archive unexpectedly includes legacy Windows setup entry: $forbidden" }
    }
} finally { $contents.Dispose() }
Write-Output "Native Windows installer verification PASS embeddedSha256=$expected selfTest=pass childShell=absent"
