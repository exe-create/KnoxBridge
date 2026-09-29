$ErrorActionPreference = 'Stop'
$package = Split-Path -Parent $PSScriptRoot
$agent = Join-Path $package 'knoxbridge-agent-0.1.0-alpha2.jar'
$bootstrap = Join-Path $package 'bootstrap-windows\knoxbridge-bootstrap.dll'
$exampleSource = Join-Path $package 'example-mod\KnoxBridgeIndependentTest'
$logPath = Join-Path $env:USERPROFILE 'Zomboid\KnoxBridge\knoxbridge.log'
$trustPath = Join-Path $env:USERPROFILE 'Zomboid\KnoxBridge\trust.properties'

function Find-GameFolder {
    $candidates = @(
        'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid',
        'C:\Program Files\Steam\steamapps\common\ProjectZomboid',
        (Join-Path $env:ProgramFiles 'Steam\steamapps\common\ProjectZomboid')
    ) | Select-Object -Unique
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath (Join-Path $candidate 'ProjectZomboid64.json'))) { return $candidate }
    }
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = 'Choose the Project Zomboid game folder (the folder containing ProjectZomboid64.json).'
    $dialog.ShowNewFolderButton = $false
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return $null }
    return $dialog.SelectedPath
}

function Install-KnoxBridge {
    if (!(Test-Path -LiteralPath $agent) -or !(Test-Path -LiteralPath $bootstrap)) {
        throw 'The setup files are incomplete. Extract the entire KnoxBridge download before running setup.'
    }
    $game = Find-GameFolder
    if (!$game) { return }
    & (Join-Path $PSScriptRoot 'install.ps1') -GameDirectory $game -AgentJarPath $agent -BootstrapDllPath $bootstrap
    & (Join-Path $PSScriptRoot 'verify-installation.ps1') -GameDirectory $game
    if (Test-Path -LiteralPath $exampleSource) {
        $installExample = (Read-Host 'Also install the optional KnoxBridge independent test mod? (y/N)') -eq 'y'
        if ($installExample) {
            $mods = Join-Path $env:USERPROFILE 'Zomboid\mods'
            $example = Join-Path $mods 'KnoxBridgeIndependentTest'
            if (Test-Path -LiteralPath $example) {
                $descriptor = Join-Path $example '42\knoxbridge.properties'
                if (!(Test-Path -LiteralPath $descriptor) -or !(Select-String -LiteralPath $descriptor -SimpleMatch 'id=org.example.knoxbridge.greeting' -Quiet)) {
                    throw "A different mod already uses $example. Runtime is installed; move that folder before installing the test module."
                }
            } else {
                New-Item -ItemType Directory -Force -Path $mods | Out-Null
                Copy-Item -LiteralPath $exampleSource -Destination $example -Recurse
            }
        }
    }
    Write-Host ''
    Write-Host 'KnoxBridge is installed. No Steam Launch Options are needed; start Project Zomboid normally with Steam Play.'
    Write-Host 'For Knox Survivors, enable Knox Survivors in the PZ Mods menu; KnoxBridge Runtime is its required Workshop dependency.'
    Write-Host 'The first launch records the Knox module hash and asks for approval without loading it. Close the game, return here, choose “Approve a module”, approve the displayed hash, and relaunch.'
    if (Test-Path -LiteralPath $exampleSource) { Write-Host 'For independent runtime testing, enable the optional KnoxBridge Independent Test Module in the PZ Mods menu.' }
}

function Approve-LoggedModules {
    if (!(Test-Path -LiteralPath $logPath)) { throw "No KnoxBridge log found at $logPath. Install and launch the game once with the test mod enabled." }
    $lines = Get-Content -LiteralPath $logPath
    $found = @{}
    foreach ($line in $lines) {
        if ($line -match 'module discovered id=(\S+) source=(.*?) hash=([0-9a-f]{64})') {
            $id = $Matches[1]; $hash = $Matches[3]
            if ($lines | Where-Object { $_ -match "module approval required id=$([regex]::Escape($id)) decision=APPROVAL_REQUIRED" }) { $found[$hash] = $id }
        }
    }
    if ($found.Count -eq 0) { Write-Host 'No modules waiting for approval were found in the log.'; return }
    foreach ($hash in $found.Keys) {
        Write-Host "Module: $($found[$hash])"
        Write-Host "SHA-256: $hash"
        $answer = Read-Host 'Type ALLOW to trust this exact file, or press Enter to skip'
        if ($answer -ceq 'ALLOW') {
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $trustPath) | Out-Null
            Add-Content -LiteralPath $trustPath -Value "`n# Approved by KnoxBridge Setup $(Get-Date -Format o)`n$hash=allow" -Encoding ASCII
            Write-Host 'Approved. Restart the game to load this module.'
        } else { Write-Host 'Skipped.' }
    }
}

function Remove-KnoxBridge {
    $game = Find-GameFolder
    if (!$game) { return }
    & (Join-Path $PSScriptRoot 'uninstall.ps1') -GameDirectory $game
    $example = Join-Path $env:USERPROFILE 'Zomboid\mods\KnoxBridgeIndependentTest'
    $descriptor = Join-Path $example '42\knoxbridge.properties'
    if ((Test-Path -LiteralPath $descriptor) -and (Select-String -LiteralPath $descriptor -SimpleMatch 'id=org.example.knoxbridge.greeting' -Quiet)) {
        if ((Read-Host 'Also remove the bundled independent test module? (y/N)') -eq 'y') { Remove-Item -LiteralPath $example -Recurse -Force }
    }
}

while ($true) {
    Clear-Host
    Write-Host 'KnoxBridge Setup'
    Write-Host '1. Install or update KnoxBridge Runtime'
    Write-Host '2. Approve a module found during the last game launch'
    Write-Host '3. Uninstall KnoxBridge'
    Write-Host '4. Exit'
    $choice = Read-Host 'Choose 1-4'
    try {
        switch ($choice) {
            '1' { Install-KnoxBridge }
            '2' { Approve-LoggedModules }
            '3' { Remove-KnoxBridge }
            '4' { return }
            default { Write-Host 'Choose 1, 2, 3, or 4.' }
        }
    } catch { Write-Host "`nSetup stopped safely: $($_.Exception.Message)" }
    if ($choice -ne '4') { Write-Host ''; [void](Read-Host 'Press Enter to return to the menu') }
}
