param(
    [Parameter(Mandatory=$true)][string]$GameDirectory,
    [string]$AgentJarPath = (Join-Path $PSScriptRoot '..\runtime-core\build\libs\knoxbridge-agent-0.1.0-alpha4.jar'),
    [string]$BootstrapDllPath = (Join-Path $PSScriptRoot '..\bootstrap-windows\build\knoxbridge-bootstrap.dll')
)
$ErrorActionPreference = 'Stop'
$game = (Resolve-Path -LiteralPath $GameDirectory).Path
$jsonPath = Join-Path $game 'ProjectZomboid64.json'
if (!(Test-Path -LiteralPath $jsonPath -PathType Leaf)) { throw "ProjectZomboid64.json not found in $game" }
$batchPath = Join-Path $game 'ProjectZomboid64.bat'
if (Test-Path -LiteralPath $batchPath -PathType Leaf) {
    $batchBootstrap = Get-Content -LiteralPath $batchPath -Raw | Select-String -Pattern '(?i)(javaagent:|agentlib:zbNative|ZombieBuddy)'
    if ($batchBootstrap) { throw 'A Java runtime bootstrap appears in ProjectZomboid64.bat. Remove that runtime before installing KnoxBridge.' }
}
if (!(Test-Path -LiteralPath $AgentJarPath -PathType Leaf)) { throw "KnoxBridge agent JAR not found: $AgentJarPath" }
if (!(Test-Path -LiteralPath $BootstrapDllPath -PathType Leaf)) { throw "KnoxBridge Windows bootstrap DLL not found: $BootstrapDllPath. Build it with scripts/build-windows-bootstrap.ps1 first." }
$stateDir = Join-Path $game '.knoxbridge'
$statePath = Join-Path $stateDir 'install-state.json'
$backupPath = Join-Path $stateDir 'ProjectZomboid64.json.original'
$installedAgent = Join-Path $stateDir 'knoxbridge-agent.jar'
$installedBootstrap = Join-Path $stateDir 'knoxbridge-bootstrap.dll'
$agentArg = "-javaagent:$installedAgent"
$bootstrapArg = "-agentpath:$installedBootstrap"
$hadState = Test-Path -LiteralPath $statePath
$userEditsPreserved = $false
if (!$hadState) {
    if (Test-Path -LiteralPath $backupPath) { throw 'An unmanaged KnoxBridge backup already exists; refusing to overwrite it.' }
    if (Test-Path -LiteralPath $installedAgent) { throw 'An unmanaged KnoxBridge agent file already exists; refusing to overwrite it.' }
}
$priorState = $null
if ($hadState) {
    $priorState = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    $beforeHash = (Get-FileHash -LiteralPath $jsonPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $userEditsPreserved = [bool]$priorState.userEditsPreserved -or ($beforeHash -ne [string]$priorState.installedJsonSha256)
}
$doc = Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json
if ($null -eq $doc.vmArgs) { throw 'ProjectZomboid64.json has no vmArgs array; refusing to guess its structure.' }
$args = @($doc.vmArgs)
$allVmArgs = @($args)
if ($null -ne $doc.windows) {
    foreach ($platformConfig in $doc.windows.PSObject.Properties) {
        if ($null -ne $platformConfig.Value.vmArgs) { $allVmArgs += @($platformConfig.Value.vmArgs) }
    }
}
if ($hadState) {
    $state = $priorState
    $agentArg = [string]$state.agentArgument
    $bootstrapArg = [string]$state.bootstrapArgument
    if (!(Test-Path -LiteralPath $backupPath -PathType Leaf)) { throw 'KnoxBridge backup is missing; refusing repair.' }
} else {
    $conflict = $args | Where-Object { $_ -match '(?i)(javaagent:|agentpath:|agentlib:zbNative|ZombieBuddy)' }
    if ($conflict) { throw 'A Java runtime bootstrap is already configured. Remove that runtime before installing KnoxBridge.' }
}
$otherBootstrap = $allVmArgs | Where-Object { $_ -ne $agentArg -and $_ -ne $bootstrapArg -and $_ -match '(?i)(javaagent:|agentpath:|agentlib:zbNative|ZombieBuddy)' }
if ($otherBootstrap) { throw 'Another Java runtime bootstrap is present in the game JSON. Remove it before installing KnoxBridge.' }
if (!$hadState -and ($args -contains $agentArg -or $args -contains $bootstrapArg)) { throw 'An unmanaged KnoxBridge bootstrap entry already exists; refusing to claim it.' }
$args = @($args | Where-Object { $_ -ne $agentArg -and $_ -ne $bootstrapArg }) + @($bootstrapArg, $agentArg)
if (!$hadState) {
    New-Item -ItemType Directory -Force -Path $stateDir | Out-Null
    Copy-Item -LiteralPath $jsonPath -Destination $backupPath
}
$doc.vmArgs = $args
Copy-Item -LiteralPath $AgentJarPath -Destination $installedAgent -Force
Copy-Item -LiteralPath $BootstrapDllPath -Destination $installedBootstrap -Force
$tmp = "$jsonPath.knoxbridge.tmp"
$json = $doc | ConvertTo-Json -Depth 100
[System.IO.File]::WriteAllText($tmp, $json + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
Move-Item -LiteralPath $tmp -Destination $jsonPath -Force
$sha = (Get-FileHash -LiteralPath $installedAgent -Algorithm SHA256).Hash.ToLowerInvariant()
$bootstrapSha = (Get-FileHash -LiteralPath $installedBootstrap -Algorithm SHA256).Hash.ToLowerInvariant()
$jsonSha = (Get-FileHash -LiteralPath $jsonPath -Algorithm SHA256).Hash.ToLowerInvariant()
$state = [ordered]@{ owner='KnoxBridge Runtime'; version='0.1.0-alpha4'; agentArgument=$agentArg; agentSha256=$sha; bootstrapArgument=$bootstrapArg; bootstrapSha256=$bootstrapSha; installedJsonSha256=$jsonSha; userEditsPreserved=$userEditsPreserved; installedAt=[DateTime]::UtcNow.ToString('o') }
[System.IO.File]::WriteAllText($statePath, ($state | ConvertTo-Json -Depth 5) + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
Write-Output "KnoxBridge install PASS game=$game sha256=$sha"
