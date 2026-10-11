param(
    [Parameter(Mandatory=$true)][string]$GameDirectory,
    [Parameter(Mandatory=$true)][string]$KnoxSurvivorsDirectory
)
$ErrorActionPreference = 'Stop'
$bridgeRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$game = (Resolve-Path -LiteralPath $GameDirectory).Path
$knox = (Resolve-Path -LiteralPath $KnoxSurvivorsDirectory).Path
$java = Join-Path $game 'jre64/bin/java.exe'
$agent = Join-Path $bridgeRoot 'runtime-core/build/libs/knoxbridge-agent-0.1.0-alpha11.jar'
$smoke = Join-Path $bridgeRoot 'bootstrap-smoke/build/libs/bootstrap-smoke.jar'
$knoxJar = Join-Path $knox 'java/build/libs/knox-agent-0.3.0-rc1.jar'
foreach ($file in @($java, $agent, $smoke, $knoxJar)) {
    if (!(Test-Path -LiteralPath $file -PathType Leaf)) { throw "Build/input missing: $file" }
}
$fixture = Join-Path $bridgeRoot ('build/first-party-' + [Guid]::NewGuid().ToString('N'))
$modRoot = Join-Path $fixture 'mods/KnoxSurvivors/42'
$probeRoot = Join-Path $fixture 'mods/KnoxBridgeHookProbe/42'
New-Item -ItemType Directory -Force -Path (Join-Path $modRoot 'media/java'), $probeRoot | Out-Null
Copy-Item -LiteralPath (Join-Path $knox 'mod/42/knoxbridge.properties') -Destination $modRoot
$moduleJar = Join-Path $modRoot 'media/java/knox-agent.jar'
Copy-Item -LiteralPath $knoxJar -Destination $moduleJar
Copy-Item -LiteralPath $smoke -Destination (Join-Path $probeRoot 'probe.jar')
[IO.File]::WriteAllText((Join-Path $probeRoot 'knoxbridge.properties'), "id=com.knoxbridge.probe`nversion=1`napiVersion=1`nentrypoint=com.knoxbridge.smoke.PzHookProbeModule`nclassLoader=system`njar=probe.jar`n")
function Invoke-CheckedJava([string[]]$JavaArguments) {
    & $java @JavaArguments
    if ($LASTEXITCODE -ne 0) { throw "JVM command failed exit=$LASTEXITCODE" }
}
function Get-Digest([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $digest = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($digest.ComputeHash($stream)).Replace('-', '').ToLowerInvariant() }
    finally { $stream.Dispose(); $digest.Dispose() }
}
$privateKey = Join-Path $fixture 'TEST-ONLY.pk8'
$publicKey = Join-Path $fixture 'TEST-ONLY.der'
$results = [Collections.Generic.List[object]]::new()
try {
    Invoke-CheckedJava @('-cp', $agent, 'com.knoxbridge.runtime.SigningTool', 'keygen', $privateKey, $publicKey)
    Invoke-CheckedJava @('-cp', $agent, 'com.knoxbridge.runtime.SigningTool', 'sign-module', $modRoot, $privateKey, $publicKey)
    $validSignature = [IO.File]::ReadAllText($moduleJar + '.knoxsig')
    $originalBytes = [IO.File]::ReadAllBytes($moduleJar)
    $originalHash = Get-Digest $moduleJar
    foreach ($case in @('signed-unknown', 'signed-allowed', 'signed-denied', 'invalid-signature-allowed', 'unsigned-allowed', 'changed-jar-old-approval')) {
        [IO.File]::WriteAllBytes($moduleJar, $originalBytes)
        [IO.File]::WriteAllText(($moduleJar + '.knoxsig'), $validSignature)
        $profile = Join-Path $fixture $case
        $allow = $case -ne 'signed-unknown' -and $case -ne 'signed-denied'
        $decision = if ($case -eq 'signed-denied') { 'deny' } else { 'allow' }
        if ($case -ne 'signed-unknown') {
            Invoke-CheckedJava @("-Duser.home=$profile", '-cp', $agent, 'com.knoxbridge.runtime.TrustCtl', $originalHash, $decision)
        }
        Invoke-CheckedJava @("-Duser.home=$profile", '-cp', $agent, 'com.knoxbridge.runtime.TrustCtl', (Get-Digest (Join-Path $probeRoot 'probe.jar')), 'allow')
        if ($case -eq 'invalid-signature-allowed') { [IO.File]::WriteAllText(($moduleJar + '.knoxsig'), 'invalid fixture signature') }
        if ($case -eq 'unsigned-allowed') { Remove-Item -LiteralPath ($moduleJar + '.knoxsig') }
        if ($case -eq 'changed-jar-old-approval') {
            $changed = [byte[]]::new($originalBytes.Length + 1)
            [Array]::Copy($originalBytes, $changed, $originalBytes.Length)
            [IO.File]::WriteAllBytes($moduleJar, $changed)
            Remove-Item -LiteralPath ($moduleJar + '.knoxsig')
            Invoke-CheckedJava @('-cp', $agent, 'com.knoxbridge.runtime.SigningTool', 'sign-module', $modRoot, $privateKey, $publicKey)
        }
        $expectLoaded = $allow -and $case -ne 'invalid-signature-allowed' -and $case -ne 'changed-jar-old-approval'
        $classPath = "$smoke;$agent;$(Join-Path $game 'projectzomboid.jar');$game"
        Push-Location $game
        try {
            $output = & $java "-Duser.home=$profile" "-Djava.library.path=$(Join-Path $game 'win64');$game" "-Dknoxbridge.enabledModPaths=$modRoot;$probeRoot" "-javaagent:$agent" '-cp' $classPath 'com.knoxbridge.smoke.FirstPartySmokeMain' $expectLoaded.ToString().ToLowerInvariant() 2>&1
            $exitCode = $LASTEXITCODE
        } finally { Pop-Location }
        [IO.File]::WriteAllText((Join-Path $profile 'stdout.txt'), ($output -join "`n"))
        if ($exitCode -ne 0 -or ($output -join "`n") -notmatch 'first-party JVM integration PASS') { throw "Case $case failed; inspect $profile/stdout.txt" }
        $runtimeLog = [IO.File]::ReadAllText((Join-Path $profile 'Zomboid/KnoxBridge/knoxbridge.log'))
        if ($runtimeLog -notmatch 'module discovered id=com\.knoxsurvivors\.knox-module ') {
            throw "Case $case did not discover the actual KnoxSurvivors candidate"
        }
        if (($case -eq 'signed-unknown' -or $case -eq 'changed-jar-old-approval') -and
                $runtimeLog -notmatch 'module blocked id=com\.knoxsurvivors\.knox-module decision=APPROVAL_REQUIRED') {
            throw "Case $case did not exercise unknown-hash blocking"
        }
        if ($case -eq 'signed-denied' -and
                $runtimeLog -notmatch 'module blocked id=com\.knoxsurvivors\.knox-module decision=DENY_EXACT') {
            throw 'Signed denied case did not exercise the exact-hash deny decision'
        }
        if ($case -eq 'invalid-signature-allowed' -and $runtimeLog -notmatch 'reason=invalid-signature') { throw 'Invalid signature gate was not exercised' }
        if ($expectLoaded) {
            $knoxLog = [IO.File]::ReadAllText((Join-Path $profile 'Zomboid/KnoxIsoPlayer.log'))
            if ($knoxLog -notmatch 'runtime start PASS source=knoxbridge' -or $knoxLog -match 'ERROR runtime start') { throw 'Actual KnoxSurvivors bootstrap did not complete' }
        }
        $results.Add([ordered]@{ scenario=$case; passed=$true; knoxLoaded=$expectLoaded; realPzEntryReturn=$true; moduleSha256=(Get-Digest $moduleJar) })
        Write-Output "First-party integration PASS scenario=$case knoxLoaded=$expectLoaded"
    }
    [IO.File]::WriteAllBytes($moduleJar, $originalBytes)
    [IO.File]::WriteAllText(($moduleJar + '.knoxsig'), $validSignature)
    [IO.File]::WriteAllText((Join-Path $fixture 'summary.json'), ($results | ConvertTo-Json -Depth 5))
    Write-Output "First-party JVM integration PASS scenarios=$($results.Count) fixture=$fixture"
} finally {
    Remove-Item -LiteralPath $privateKey, $publicKey -ErrorAction SilentlyContinue
}
