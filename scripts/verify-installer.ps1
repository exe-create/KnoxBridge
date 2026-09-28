$ErrorActionPreference = 'Stop'
$temp = Join-Path ([IO.Path]::GetTempPath()) ("knoxbridge-installer-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $temp | Out-Null
try {
    $game = Join-Path $temp 'game'; New-Item -ItemType Directory -Force -Path $game | Out-Null
    $json = '{"mainClass":"zombie/gameStates/MainScreenState","classpath":[".","projectzomboid.jar"],"vmArgs":["-Xmx4g","-Dexample=preserve"]}'
    [IO.File]::WriteAllText((Join-Path $game 'ProjectZomboid64.json'), $json)
    $dummyAgent = Join-Path $temp 'agent.jar'; [IO.File]::WriteAllBytes($dummyAgent, [byte[]](1,2,3,4))
    $dummyBootstrap = Join-Path $temp 'bootstrap.dll'; [IO.File]::WriteAllBytes($dummyBootstrap, [byte[]](5,6,7,8))
    & (Join-Path $PSScriptRoot 'install.ps1') -GameDirectory $game -AgentJarPath $dummyAgent -BootstrapDllPath $dummyBootstrap | Out-Null
    & (Join-Path $PSScriptRoot 'verify-installation.ps1') -GameDirectory $game | Out-Null
    $installed = Get-Content (Join-Path $game 'ProjectZomboid64.json') -Raw | ConvertFrom-Json
    if (@($installed.vmArgs) -notcontains '-Dexample=preserve') { throw 'Installer lost an unrelated VM argument.' }
    $installedHash = (Get-FileHash (Join-Path $game 'ProjectZomboid64.json') -Algorithm SHA256).Hash.ToLowerInvariant()
    & (Join-Path $PSScriptRoot 'install.ps1') -GameDirectory $game -AgentJarPath $dummyAgent -BootstrapDllPath $dummyBootstrap | Out-Null
    if ((Get-FileHash (Join-Path $game 'ProjectZomboid64.json') -Algorithm SHA256).Hash.ToLowerInvariant() -ne $installedHash) { throw 'Repeat install was not idempotent.' }
    & (Join-Path $PSScriptRoot 'uninstall.ps1') -GameDirectory $game | Out-Null
    if ((Get-Content (Join-Path $game 'ProjectZomboid64.json') -Raw) -ne $json) { throw 'Uninstall did not restore the original configuration.' }
    & (Join-Path $PSScriptRoot 'install.ps1') -GameDirectory $game -AgentJarPath $dummyAgent -BootstrapDllPath $dummyBootstrap | Out-Null
    $edited = Get-Content (Join-Path $game 'ProjectZomboid64.json') -Raw | ConvertFrom-Json; $edited.vmArgs += '-Duser=edit'
    Set-Content -LiteralPath (Join-Path $game 'ProjectZomboid64.json') -Value ($edited | ConvertTo-Json -Depth 100)
    & (Join-Path $PSScriptRoot 'install.ps1') -GameDirectory $game -AgentJarPath $dummyAgent -BootstrapDllPath $dummyBootstrap | Out-Null
    & (Join-Path $PSScriptRoot 'uninstall.ps1') -GameDirectory $game | Out-Null
    $after = Get-Content (Join-Path $game 'ProjectZomboid64.json') -Raw | ConvertFrom-Json
    if (@($after.vmArgs) -notcontains '-Duser=edit' -or @($after.vmArgs) -contains '-javaagent:') { throw 'Uninstall failed to preserve user edits or remove its own argument.' }
    $conflictGame = Join-Path $temp 'conflict-game'; New-Item -ItemType Directory -Force -Path $conflictGame | Out-Null
    $conflictJson = '{"vmArgs":["-agentlib:zbNative"]}'
    [IO.File]::WriteAllText((Join-Path $conflictGame 'ProjectZomboid64.json'), $conflictJson)
    $blocked = $false
    try { & (Join-Path $PSScriptRoot 'install.ps1') -GameDirectory $conflictGame -AgentJarPath $dummyAgent -BootstrapDllPath $dummyBootstrap | Out-Null }
    catch { $blocked = $true }
    if (!$blocked -or (Get-Content (Join-Path $conflictGame 'ProjectZomboid64.json') -Raw) -ne $conflictJson) { throw 'Installer did not fail safely on a competing bootstrap.' }
    Write-Output 'KnoxBridge installer verification PASS checks=9'
} finally { Remove-Item -LiteralPath $temp -Recurse -Force }
