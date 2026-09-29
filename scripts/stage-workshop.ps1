param(
    [string]$WorkshopDirectory = (Join-Path $env:USERPROFILE 'Zomboid\Workshop\KnoxBridgeRuntime'),
    [string]$ModTemplateDirectory = (Join-Path $env:USERPROFILE 'Zomboid\Workshop\ModTemplate'),
    [string]$WorkshopItemId = '3810025624'
)
$ErrorActionPreference = 'Stop'
$bridgeArtwork = Join-Path $PSScriptRoot '..\workshop\preview.png'
if (!(Test-Path -LiteralPath $bridgeArtwork)) {
    throw "KnoxBridge Workshop artwork not found: $bridgeArtwork"
}
$stage = [IO.Path]::GetFullPath($WorkshopDirectory)
if (Test-Path -LiteralPath $stage) {
    $backupRoot = Join-Path $env:USERPROFILE 'Zomboid\WorkshopBackups'
    New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
    $backup = Join-Path $backupRoot ('KnoxBridgeRuntime-before-marker-only-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    Move-Item -LiteralPath $stage -Destination $backup
    Write-Output "Previous Workshop staging preserved at $backup"
}
$content = Join-Path $stage 'Contents'
$modRoot = Join-Path $content 'mods\KnoxBridgeRuntime'
$bridge42 = Join-Path $modRoot '42'
$developerRoot = Join-Path $modRoot 'developer'
$developerDocs = Join-Path $developerRoot 'docs'
$developerLib = Join-Path $developerRoot 'lib'
New-Item -ItemType Directory -Force -Path $bridge42 | Out-Null
New-Item -ItemType Directory -Force -Path $developerDocs, $developerLib | Out-Null
Copy-Item -LiteralPath $bridgeArtwork -Destination (Join-Path $stage 'preview.png')
Copy-Item -LiteralPath $bridgeArtwork -Destination (Join-Path $modRoot 'poster.png')
Copy-Item -LiteralPath $bridgeArtwork -Destination (Join-Path $bridge42 'poster.png')
$bridgeMedia = Join-Path $PSScriptRoot '..\workshop\mod\42\media'
if (!(Test-Path -LiteralPath $bridgeMedia)) { throw "KnoxBridge Workshop Lua/UI sources not found: $bridgeMedia" }
Copy-Item -LiteralPath $bridgeMedia -Destination $bridge42 -Recurse
$metadata = "name=KnoxBridge Runtime`nid=KnoxBridgeRuntime`nauthor=exe-create`ndescription=Required PZ dependency marker with KnoxBridge API and mod-author guides. Download the separate player setup from GitHub Releases.`nposter=poster.png`n"
[IO.File]::WriteAllText((Join-Path $modRoot 'mod.info'), $metadata, [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $bridge42 'mod.info'), $metadata, [Text.UTF8Encoding]::new($false))
$versionText = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\build.gradle.kts') -Raw
if ($versionText -notmatch 'version\s*=\s*"([^"]+)"') { throw 'Could not read KnoxBridge version from build.gradle.kts' }
$version = $Matches[1]
$apiJar = Join-Path $PSScriptRoot "..\runtime-api\build\libs\runtime-api-$version.jar"
if (!(Test-Path -LiteralPath $apiJar)) {
    $gradle = Join-Path $PSScriptRoot '..\gradlew.bat'
    & $gradle ':runtime-api:jar'
    if ($LASTEXITCODE -ne 0) { throw "Could not build KnoxBridge runtime API (exit $LASTEXITCODE)" }
}
if (!(Test-Path -LiteralPath $apiJar)) { throw "Runtime API JAR not found: $apiJar" }
Copy-Item -LiteralPath $apiJar -Destination $developerLib
Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..\LICENSE') -Destination $developerRoot
$exampleSource = Join-Path $PSScriptRoot '..\examples\minimal-module'
$exampleDestination = Join-Path $developerRoot 'example'
$exampleSourceFiles = @(
    'build.gradle.kts',
    'settings.gradle.kts',
    'knoxbridge.properties',
    'mod.info',
    'src\main\java\org\example\mymod\MyModule.java'
)
foreach ($relativePath in $exampleSourceFiles) {
    $destinationFile = Join-Path $exampleDestination $relativePath
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destinationFile) | Out-Null
    Copy-Item -LiteralPath (Join-Path $exampleSource $relativePath) -Destination $destinationFile
}
foreach ($guide in @('MODULE_API.md', 'PATCH_API.md', 'COMPATIBILITY.md', 'INSTALLATION.md')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "..\docs\$guide") -Destination $developerDocs
}
$quickStart = @"
KnoxBridge Runtime - Workshop files

PLAYER SETUP
This Workshop item is a Project Zomboid dependency marker and author reference. It does not install or activate the Java runtime. Download the official player setup from:
https://github.com/exe-create/KnoxBridge/releases/latest
Follow developer/docs/INSTALLATION.md. The Windows installer and Linux/macOS setup archive are distributed on GitHub Releases.

BRIDGE MODULE REVIEW
- Enable KnoxBridge Runtime in the PZ Mods menu. Its full-screen main-menu Review Java Mods gate lists enabled-mod JARs before world entry.
- Unknown hashes stay blocked by default and remain visible in the launch review. Choices apply on the next launch; the optional remember toggle saves them for that exact SHA-256.
- JARs without a valid KnoxBridge descriptor are listed but cannot be loaded until their author adds Bridge compatibility.
- If the UI cannot save a decision, leave the module blocked and report the problem.

MOD AUTHOR QUICK START
- Compile against developer/lib/runtime-api-$version.jar.
- Copy developer/example to a workspace with Java 17 and Gradle 8.14.3+, then run: gradle -p developer/example build "-PknoxbridgeApiJar=<path to developer/lib/runtime-api-$version.jar>".
- Copy the example mod.info and knoxbridge.properties into your PZ mod's 42 directory; copy build/libs/minimal-module.jar to 42/media/java/.
- Read developer/docs/MODULE_API.md before packaging.
- Use developer/docs/PATCH_API.md for patch contracts and developer/docs/COMPATIBILITY.md for verified boundaries.
- KnoxBridge does not make arbitrary Java mods compatible automatically; the mod author must integrate with its API and test against the target Project Zomboid build.

TRUST AND SAFETY
Java modules run with the game's account permissions and are not sandboxed. Approve only modules you trust. The author text in mod.info is a claim, not authenticated identity. KnoxBridge's runtime and API are maintained as independent project components.
"@
[IO.File]::WriteAllText((Join-Path $modRoot 'README.txt'), $quickStart, [Text.UTF8Encoding]::new($false))
$idLine = if ($WorkshopItemId) { "id=$WorkshopItemId`n" } else { '' }
$description = 'KnoxBridge Runtime is the required PZ dependency marker for Knox Survivors Java features. The Workshop item includes the Bridge-owned in-game Java mod review gate, API, and mod-author guides; it does not install the Java runtime. Download player setup from https://github.com/exe-create/KnoxBridge/releases/latest. Enable KnoxBridge Runtime and Knox Survivors in the PZ Mods menu. The full-screen Review Java Mods gate lists enabled-mod JARs at the main menu before world entry. Unknown files remain blocked by default. Allow/deny decisions use the exact SHA-256. Unchecked choices apply once; Remember next choice saves the next decision across launches. If you change your mind before continuing, the deny button becomes Undo pending choice. Quit and relaunch only when a choice changes the loaded Java modules. Only modules with a valid KnoxBridge descriptor/API can be allowed; authors must add compatibility. Displayed author metadata is unverified. Windows: run KnoxBridgeSetup.exe. Linux/macOS: extract the ZIP, close Steam, and run sh scripts/setup-unix.sh (Python 3 required; these platforms are not live-verified). An unsigned new installer may show a SmartScreen not-commonly-downloaded reputation warning; this is not a malware verdict or proof of safety. Verify the official source and release hash. If Windows Security identifies malware, stop and do not run or whitelist it. Configure only one Java instrumentation runtime for Project Zomboid at a time. Java modules have the same permissions as the game and are not sandboxed; approve only code you trust.'
$workshop = "version=1`n${idLine}title=KnoxBridge Runtime (Required by Knox Survivors)`ndescription=$description`ntags=Build 42`nvisibility=public`n"
[IO.File]::WriteAllText((Join-Path $stage 'workshop.txt'), $workshop, [Text.UTF8Encoding]::new($false))
$expected = @(
    'mods\KnoxBridgeRuntime\mod.info',
    'mods\KnoxBridgeRuntime\poster.png',
    'mods\KnoxBridgeRuntime\42\mod.info',
    'mods\KnoxBridgeRuntime\42\poster.png',
    'mods\KnoxBridgeRuntime\42\media\lua\client\KnoxBridgeModuleReview.lua',
    'mods\KnoxBridgeRuntime\42\media\lua\client\KnoxBridgeSupportButton.lua',
    'mods\KnoxBridgeRuntime\42\media\ui\knoxKofi.png',
    'mods\KnoxBridgeRuntime\README.txt',
    "mods\KnoxBridgeRuntime\developer\lib\runtime-api-$version.jar",
    'mods\KnoxBridgeRuntime\developer\LICENSE',
    'mods\KnoxBridgeRuntime\developer\docs\MODULE_API.md',
    'mods\KnoxBridgeRuntime\developer\docs\PATCH_API.md',
    'mods\KnoxBridgeRuntime\developer\docs\COMPATIBILITY.md',
    'mods\KnoxBridgeRuntime\developer\docs\INSTALLATION.md',
    'mods\KnoxBridgeRuntime\developer\example\build.gradle.kts',
    'mods\KnoxBridgeRuntime\developer\example\settings.gradle.kts',
    'mods\KnoxBridgeRuntime\developer\example\knoxbridge.properties',
    'mods\KnoxBridgeRuntime\developer\example\mod.info',
    'mods\KnoxBridgeRuntime\developer\example\src\main\java\org\example\mymod\MyModule.java'
)
$actual = @(Get-ChildItem -LiteralPath $content -Recurse -File | ForEach-Object { $_.FullName.Substring($content.Length).TrimStart([char[]]@('\','/')).Replace('/', '\') })
if ((($actual | Sort-Object) -join "`n") -ne (($expected | Sort-Object) -join "`n")) {
    throw "Workshop Contents do not match the reviewed runtime-marker and author-reference payload. Actual: $($actual -join ', ')"
}
$forbidden = @('.exe','.dll','.bat','.app','.dylib','.sh','.so','.zip','.ps1')
$bad = Get-ChildItem -LiteralPath $content -Recurse -File | Where-Object { $forbidden -contains $_.Extension.ToLowerInvariant() }
if ($bad) { throw "Steam-forbidden file remains in Contents: $($bad.FullName -join ', ')" }
Write-Output "KnoxBridge Workshop staging PASS path=$stage files=$($actual.Count) version=$version"
