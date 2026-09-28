param([Parameter(Mandatory=$true)][string]$GameDirectory)
$ErrorActionPreference = 'Stop'
$game = (Resolve-Path -LiteralPath $GameDirectory).Path
$stateDir = Join-Path $game '.knoxbridge'
$statePath = Join-Path $stateDir 'install-state.json'
$jsonPath = Join-Path $game 'ProjectZomboid64.json'
if (!(Test-Path -LiteralPath $statePath) -or !(Test-Path -LiteralPath $jsonPath)) { throw 'KnoxBridge installation state or game JSON is missing.' }
$state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
$doc = Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json
if (@($doc.vmArgs) -notcontains [string]$state.agentArgument) { throw 'KnoxBridge JVM argument is missing.' }
if (@($doc.vmArgs) -notcontains [string]$state.bootstrapArgument) { throw 'KnoxBridge native bootstrap argument is missing.' }
$nativeIndex = [Array]::IndexOf([object[]]$doc.vmArgs, [string]$state.bootstrapArgument)
$agentIndex = [Array]::IndexOf([object[]]$doc.vmArgs, [string]$state.agentArgument)
if ($nativeIndex -lt 0 -or $agentIndex -le $nativeIndex) { throw 'KnoxBridge native bootstrap must precede the Java agent.' }
$agentPath = ([string]$state.agentArgument).Substring('-javaagent:'.Length)
if (!(Test-Path -LiteralPath $agentPath)) { throw "KnoxBridge JAR missing: $agentPath" }
$sha = (Get-FileHash -LiteralPath $agentPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($sha -ne [string]$state.agentSha256) { throw 'KnoxBridge JAR hash differs from the installed record.' }
$bootstrapPath = ([string]$state.bootstrapArgument).Substring('-agentpath:'.Length)
if (!(Test-Path -LiteralPath $bootstrapPath)) { throw "KnoxBridge bootstrap DLL missing: $bootstrapPath" }
$bootstrapSha = (Get-FileHash -LiteralPath $bootstrapPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($bootstrapSha -ne [string]$state.bootstrapSha256) { throw 'KnoxBridge native bootstrap hash differs from the installed record.' }
Write-Output "KnoxBridge installation PASS version=$($state.version) sha256=$sha"
