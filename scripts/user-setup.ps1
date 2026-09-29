$ErrorActionPreference = 'Stop'
$package = Split-Path -Parent $PSScriptRoot
$agent = Join-Path $package 'knoxbridge-agent-0.1.0-alpha8.jar'
$bootstrap = Join-Path $package 'bootstrap-windows\knoxbridge-bootstrap.dll'
$exampleSource = Join-Path $package 'example-mod\KnoxBridgeIndependentTest'
$logPath = Join-Path $env:USERPROFILE 'Zomboid\KnoxBridge\knoxbridge.log'
$trustPath = Join-Path $env:USERPROFILE 'Zomboid\KnoxBridge\trust.properties'
. (Join-Path $PSScriptRoot 'trust-decisions.ps1')

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
    Write-Host 'At the Project Zomboid main menu, use the KnoxBridge Workshop mod’s Review Java Mods screen to allow or keep compatible JARs denied. Decisions apply after a full restart; unsupported JARs remain blocked.'
    if (Test-Path -LiteralPath $exampleSource) { Write-Host 'For independent runtime testing, enable the optional KnoxBridge Independent Test Module in the PZ Mods menu.' }
}

function Approve-LoggedModules {
    if (!(Test-Path -LiteralPath $logPath)) { throw "No KnoxBridge log found at $logPath. Install and launch the game once with the test mod enabled." }
    $lines = @(Get-Content -LiteralPath $logPath)
    $runStart = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match 'KnoxBridge runtime start PASS') { $runStart = $i }
    }
    if ($runStart -lt 0) { Write-Host 'No game-launch session was found in the KnoxBridge log.'; return }
    $lines = @($lines | Select-Object -Skip $runStart)
    $found = @{}
    foreach ($line in $lines) {
        if ($line -match 'module discovered id=(\S+) source=(.*?) hash=([0-9a-f]{64})') {
            $id = $Matches[1]; $hash = $Matches[3]
            $found[$hash] = $id
        }
    }
    if ($found.Count -eq 0) { Write-Host 'No Java modules were discovered during the last game launch.'; return }
    foreach ($hash in $found.Keys) {
        Write-Host "Module: $($found[$hash])"
        Write-Host "SHA-256: $hash"
        if (Test-Path -LiteralPath $trustPath) {
            $current = Select-String -LiteralPath $trustPath -Pattern "^$([regex]::Escape($hash))=(allow|deny)$" | Select-Object -Last 1
            if ($current) { Write-Host "Current saved decision: $($current.Matches[0].Groups[1].Value)" }
        }
        $answer = Read-Host 'Type ALLOW to trust, DENY to block this exact file, or press Enter to skip'
        if ($answer -ceq 'ALLOW' -or $answer -ceq 'DENY') {
            $decision = $answer.ToLowerInvariant()
            Set-KnoxBridgeTrustDecision -TrustFile $trustPath -Hash $hash -Decision $decision
            Write-Host "Saved $decision for this exact JAR hash. Restart the game to apply it."
        } else { Write-Host 'No trust decision changed.' }
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
    Write-Host '2. Uninstall KnoxBridge'
    Write-Host '3. Exit'
    $choice = Read-Host 'Choose 1-3'
    try {
        switch ($choice) {
            '1' { Install-KnoxBridge }
            '2' { Remove-KnoxBridge }
            '3' { return }
            default { Write-Host 'Choose 1, 2, or 3.' }
        }
    } catch { Write-Host "`nSetup stopped safely: $($_.Exception.Message)" }
    if ($choice -ne '3') { Write-Host ''; [void](Read-Host 'Press Enter to return to the menu') }
}
