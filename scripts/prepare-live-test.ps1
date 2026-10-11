param(
    [Parameter(Mandatory=$true)][string]$GameDirectory,
    [Parameter(Mandatory=$true)][string]$KnoxSurvivorsDirectory,
    [Parameter(Mandatory=$true)][string]$FirstPartyFixture,
    [switch]$PreApproveModule
)
$ErrorActionPreference = 'Stop'
$bridgeRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$game = (Resolve-Path -LiteralPath $GameDirectory).Path
$knox = (Resolve-Path -LiteralPath $KnoxSurvivorsDirectory).Path
$sourceFixture = (Resolve-Path -LiteralPath $FirstPartyFixture).Path
$fixture = Join-Path $bridgeRoot ('build/live-signature-' + [Guid]::NewGuid().ToString('N'))
$profile = Join-Path $fixture 'userhome'
$cache = Join-Path $profile 'Zomboid'
$mods = Join-Path $cache 'mods'
$runtime = Join-Path $fixture '.knoxbridge'
New-Item -ItemType Directory -Force -Path $mods, $runtime | Out-Null
Copy-Item -LiteralPath (Join-Path $game 'ProjectZomboid64.exe') -Destination $fixture
Get-ChildItem -LiteralPath $game -File -Filter '*.dll' | Copy-Item -Destination $fixture
New-Item -ItemType Junction -Path (Join-Path $fixture 'jre64') -Target (Join-Path $game 'jre64') | Out-Null
Copy-Item -LiteralPath (Join-Path $bridgeRoot 'runtime-core/build/libs/knoxbridge-agent-0.1.0-alpha11.jar') -Destination (Join-Path $runtime 'knoxbridge-agent.jar')
Copy-Item -LiteralPath (Join-Path $bridgeRoot 'bootstrap-windows/build/knoxbridge-bootstrap.dll') -Destination $runtime
Copy-Item -LiteralPath (Join-Path $knox 'mod') -Destination (Join-Path $mods 'KnoxSurvivors') -Recurse
$knoxJava = Join-Path $mods 'KnoxSurvivors/42/media/java'
New-Item -ItemType Directory -Force -Path $knoxJava | Out-Null
$signedJar = Join-Path $sourceFixture 'mods/KnoxSurvivors/42/media/java/knox-agent.jar'
Copy-Item -LiteralPath $signedJar, ($signedJar + '.knoxsig') -Destination $knoxJava
$bridgeMod = Join-Path $mods 'KnoxBridgeRuntime'
$bridge42 = Join-Path $bridgeMod '42'
New-Item -ItemType Directory -Force -Path $bridge42, (Join-Path $bridgeMod 'common') | Out-Null
Copy-Item -LiteralPath (Join-Path $bridgeRoot 'workshop/mod/42/media') -Destination $bridge42 -Recurse
$info = "name=KnoxBridge Runtime`nid=KnoxBridgeRuntime`nauthor=exe-create`ndescription=Disposable local signature test.`n"
[IO.File]::WriteAllText((Join-Path $bridgeMod 'mod.info'), $info)
[IO.File]::WriteAllText((Join-Path $bridge42 'mod.info'), $info)
[IO.File]::WriteAllText((Join-Path $mods 'default.txt'), "VERSION = 1,`nmods`n{`n    mod = KnoxBridgeRuntime,`n    mod = KnoxSurvivors,`n}`nmaps`n{`n}`n")
# PZ 42.21 resets enabled mods once when this version marker is absent.
# This disposable profile already has an explicit test-only mod selection.
[IO.File]::WriteAllText((Join-Path $mods 'reset-mods-42_00.txt'), 'Disposable Build 42 test profile with explicitly selected mods.')
[IO.File]::WriteAllText((Join-Path $cache 'options.ini'), "version=14`nwidth=1280`nheight=720`nfullScreen=false`nframeRate=60`n")
$configuration = Get-Content -LiteralPath (Join-Path $game 'ProjectZomboid64.json') -Raw | ConvertFrom-Json
$configuration.classpath = @($configuration.classpath | ForEach-Object { if ([IO.Path]::IsPathRooted($_)) { $_ } else { [IO.Path]::GetFullPath((Join-Path $game $_)) } })
$configuration.vmArgs = @($configuration.vmArgs | Where-Object { $_ -notmatch '^-javaagent:|^-agentpath:|^-agentlib:|^-Duser.home=|^-Xmx|^-Dzomboid.steam=' }) + @(
    '-Xmx3g', '-Dzomboid.steam=0', "-Duser.home=$profile",
    "-agentpath:$(Join-Path $runtime 'knoxbridge-bootstrap.dll')", "-javaagent:$(Join-Path $runtime 'knoxbridge-agent.jar')")
[IO.File]::WriteAllText((Join-Path $fixture 'ProjectZomboid64.json'), ($configuration | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
$java = Join-Path $game 'jre64/bin/java.exe'
$agent = Join-Path $runtime 'knoxbridge-agent.jar'
$hash = [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash([IO.File]::ReadAllBytes($signedJar))).Replace('-', '').ToLowerInvariant()
if ($PreApproveModule) {
    & $java "-Duser.home=$profile" '-cp' $agent 'com.knoxbridge.runtime.TrustCtl' $hash 'allow'
    if ($LASTEXITCODE -ne 0) { throw 'Disposable test approval failed' }
}
[IO.File]::WriteAllText((Join-Path $fixture 'test.json'), ([ordered]@{ fixture=$fixture; game=$game; profile=$profile; cache=$cache; moduleSha256=$hash; signedWithDisposableTestKey=$true; preApproved=$PreApproveModule.IsPresent; normalSteamAcceptance=$false } | ConvertTo-Json))
Write-Output "Prepared disposable native game test: $fixture"
Write-Output "Launch copied ProjectZomboid64.exe with -cachedir=$cache -nosteam -modfolders mods; working directory $game"
