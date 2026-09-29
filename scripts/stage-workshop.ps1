param(
    [string]$WorkshopDirectory = (Join-Path $env:USERPROFILE 'Zomboid\Workshop\KnoxBridgeRuntime'),
    [string]$ModTemplateDirectory = (Join-Path $env:USERPROFILE 'Zomboid\Workshop\ModTemplate'),
    [string]$WorkshopItemId = '3810025624'
)
$ErrorActionPreference = 'Stop'
$templatePreview = Join-Path $ModTemplateDirectory 'preview.png'
$templatePoster = Join-Path $ModTemplateDirectory 'Contents\mods\ModTemplate\poster.png'
if (!(Test-Path -LiteralPath $templatePreview) -or !(Test-Path -LiteralPath $templatePoster)) {
    throw "Default ModTemplate preview/poster images not found under $ModTemplateDirectory"
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
New-Item -ItemType Directory -Force -Path $bridge42 | Out-Null
Copy-Item -LiteralPath $templatePreview -Destination (Join-Path $stage 'preview.png')
Copy-Item -LiteralPath $templatePoster -Destination $modRoot
Copy-Item -LiteralPath $templatePoster -Destination $bridge42
$metadata = "name=KnoxBridge Runtime`nid=KnoxBridgeRuntime`nauthor=exe-create`ndescription=Required dependency marker for Java modules using KnoxBridge Runtime. Download the separate setup package from GitHub Releases.`nposter=poster.png`n"
[IO.File]::WriteAllText((Join-Path $modRoot 'mod.info'), $metadata, [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $bridge42 'mod.info'), $metadata, [Text.UTF8Encoding]::new($false))
$idLine = if ($WorkshopItemId) { "id=$WorkshopItemId`n" } else { '' }
$description = 'KnoxBridge Runtime is a standalone Java-mod runtime and required dependency for Knox Survivors Java features and compatible Build 42 modules. Subscribe to this Workshop item and Knox Survivors, then download KnoxBridgeSetup.exe from https://github.com/exe-create/KnoxBridge/releases/latest. Windows: run setup, choose Install/Update, enable Knox Survivors in PZ Mods, and start normally through Steam. The installer is unsigned; an unknown-publisher notice may appear. If Windows Security reports malware, stop and do not run or whitelist the file; report the detection name and release SHA-256. Linux/macOS: extract the ZIP, close Steam, and run sh scripts/setup-unix.sh (Python 3 required; those platforms are not live-verified). Existing installations are unaffected by the installer update. KnoxBridge and ZombieBuddy are alternatives; do not configure both on one Project Zomboid launch. Java modules run with the same permissions as the game and are not sandboxed. Approve only code you trust.'
$workshop = "version=1`n${idLine}title=KnoxBridge Runtime (Required by Knox Survivors)`ndescription=$description`ntags=Build 42`nvisibility=public`n"
[IO.File]::WriteAllText((Join-Path $stage 'workshop.txt'), $workshop, [Text.UTF8Encoding]::new($false))
$expected = @(
    'mods\KnoxBridgeRuntime\mod.info',
    'mods\KnoxBridgeRuntime\poster.png',
    'mods\KnoxBridgeRuntime\42\mod.info',
    'mods\KnoxBridgeRuntime\42\poster.png'
)
$actual = @(Get-ChildItem -LiteralPath $content -Recurse -File | ForEach-Object { $_.FullName.Substring($content.Length).TrimStart([char[]]@('\','/')).Replace('/', '\') })
if ((($actual | Sort-Object) -join "`n") -ne (($expected | Sort-Object) -join "`n")) {
    throw "Workshop Contents must contain only the four Steam-safe dependency marker files. Actual: $($actual -join ', ')"
}
$forbidden = @('.exe','.dll','.bat','.app','.dylib','.sh','.so','.zip','.jar','.ps1')
$bad = Get-ChildItem -LiteralPath $content -Recurse -File | Where-Object { $forbidden -contains $_.Extension.ToLowerInvariant() }
if ($bad) { throw "Steam-forbidden file remains in Contents: $($bad.FullName -join ', ')" }
Write-Output "KnoxBridge marker-only Workshop staging PASS path=$stage files=$($actual.Count)"
