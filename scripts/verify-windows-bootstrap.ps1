param([Parameter(Mandatory=$true)][string]$GameDirectory)
$ErrorActionPreference = 'Stop'
$game = (Resolve-Path -LiteralPath $GameDirectory).Path
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$sourceExe = Join-Path $game 'ProjectZomboid64.exe'
$sourceJre = Join-Path $game 'jre64'
if (!(Test-Path -LiteralPath $sourceExe -PathType Leaf) -or !(Test-Path -LiteralPath $sourceJre -PathType Container)) { throw 'PZ Windows launcher or bundled JRE is missing.' }
$agent = Join-Path $root 'runtime-core\build\libs\knoxbridge-agent-0.1.0-alpha1.jar'
$native = Join-Path $root 'bootstrap-windows\build\knoxbridge-bootstrap.dll'
$smokeJar = Join-Path $root 'bootstrap-smoke\build\libs\bootstrap-smoke.jar'
if (!(Test-Path -LiteralPath $agent) -or !(Test-Path -LiteralPath $native) -or !(Test-Path -LiteralPath $smokeJar)) { throw 'Build artifacts are missing; run gradlew verify first.' }
$fixture = Join-Path $root ('build\bootstrap-smoke-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $fixture | Out-Null
Copy-Item -LiteralPath $sourceExe -Destination (Join-Path $fixture 'ProjectZomboid64.exe')
Get-ChildItem -LiteralPath $game -File -Filter '*.dll' | Copy-Item -Destination $fixture
New-Item -ItemType Junction -Path (Join-Path $fixture 'jre64') -Target $sourceJre | Out-Null
$runtimeDirectory = New-Item -ItemType Directory -Force -Path (Join-Path $fixture '.knoxbridge')
Copy-Item -LiteralPath $agent -Destination (Join-Path $runtimeDirectory.FullName 'knoxbridge-agent.jar')
Copy-Item -LiteralPath $native -Destination (Join-Path $runtimeDirectory.FullName 'knoxbridge-bootstrap.dll')
Copy-Item -LiteralPath $smokeJar -Destination (Join-Path $fixture 'bootstrap-smoke.jar')
$userData = Join-Path $fixture 'isolated-user-data'
$agentPath = Join-Path $fixture '.knoxbridge\knoxbridge-agent.jar'
$nativePath = Join-Path $fixture '.knoxbridge\knoxbridge-bootstrap.dll'
$configuration = [ordered]@{
    mainClass = 'com/knoxbridge/smoke/BootstrapSmokeMain'
    classpath = @('bootstrap-smoke.jar', '.knoxbridge/knoxbridge-agent.jar')
    vmArgs = @("-Duser.home=$userData", "-agentpath:$nativePath", "-javaagent:$agentPath")
}
[IO.File]::WriteAllText((Join-Path $fixture 'ProjectZomboid64.json'), ($configuration | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
$stdout = Join-Path $fixture 'stdout.txt'; $stderr = Join-Path $fixture 'stderr.txt'
$process = Start-Process -FilePath (Join-Path $fixture 'ProjectZomboid64.exe') -WorkingDirectory $fixture -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$agentLog = Join-Path $userData 'Zomboid\KnoxBridge\knoxbridge.log'
if (!(Test-Path -LiteralPath $agentLog)) { throw "Windows launcher did not start the agent (exit=$($process.ExitCode)). See $stderr" }
$logText = Get-Content -LiteralPath $agentLog -Raw
$outText = if (Test-Path -LiteralPath $stdout) { Get-Content -LiteralPath $stdout -Raw } else { '' }
if ($logText -notmatch 'KnoxBridge runtime start PASS' -or $outText -notmatch 'KnoxBridge bootstrap smoke PASS') {
    throw "Windows launcher smoke failed (exit=$($process.ExitCode)); inspect fixture $fixture"
}
Write-Output "KnoxBridge Windows launcher bootstrap PASS java=$($logText | Select-String -Pattern 'java version=.*' | Select-Object -First 1)"
Write-Output "Fixture retained for inspection: $fixture"
