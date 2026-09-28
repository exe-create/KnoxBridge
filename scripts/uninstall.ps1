param([Parameter(Mandatory=$true)][string]$GameDirectory)
$ErrorActionPreference = 'Stop'
$game = (Resolve-Path -LiteralPath $GameDirectory).Path
$stateDir = Join-Path $game '.knoxbridge'
$statePath = Join-Path $stateDir 'install-state.json'
$backupPath = Join-Path $stateDir 'ProjectZomboid64.json.original'
$jsonPath = Join-Path $game 'ProjectZomboid64.json'
if (!(Test-Path -LiteralPath $statePath) -or !(Test-Path -LiteralPath $backupPath)) { throw 'KnoxBridge-owned install state or backup is missing; refusing uninstall.' }
$state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
$currentHash = (Get-FileHash -LiteralPath $jsonPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($currentHash -eq [string]$state.installedJsonSha256 -and !$state.userEditsPreserved) {
    Copy-Item -LiteralPath $backupPath -Destination $jsonPath -Force
    $configResult = 'original-restored'
} else {
    $doc = Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json
    $doc.vmArgs = @($doc.vmArgs | Where-Object { $_ -ne [string]$state.agentArgument -and $_ -ne [string]$state.bootstrapArgument })
    $tmp = "$jsonPath.knoxbridge.tmp"
    [System.IO.File]::WriteAllText($tmp, ($doc | ConvertTo-Json -Depth 100) + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $tmp -Destination $jsonPath -Force
    $configResult = 'owned-argument-removed-user-edits-preserved'
}
Remove-Item -LiteralPath (Join-Path $stateDir 'knoxbridge-agent.jar'), (Join-Path $stateDir 'knoxbridge-bootstrap.dll'), $statePath, $backupPath -Force -ErrorAction SilentlyContinue
if ((Test-Path -LiteralPath $stateDir -PathType Container) -and @(Get-ChildItem -LiteralPath $stateDir -Force).Count -eq 0) {
    Remove-Item -LiteralPath $stateDir -Force
}
Write-Output "KnoxBridge uninstall PASS config=$configResult"
