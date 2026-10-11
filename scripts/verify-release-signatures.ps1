param([string]$Version = '0.1.0-alpha11')
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$agent = Join-Path $root "runtime-core/build/libs/knoxbridge-agent-$Version.jar"
$fingerprint = 'eda1c49f4f51e604d86c1889fe72f90f16c42ff7bb6c69f1d9be74d79645228f'
function Verify-File([string]$Path) {
    & java '-cp' $agent 'com.knoxbridge.runtime.SigningTool' 'verify-file' $Path $fingerprint
    if ($LASTEXITCODE -ne 0) { throw "Invalid release signature: $Path" }
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$temp = Join-Path ([IO.Path]::GetTempPath()) ('knoxbridge-release-verify-' + [Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($temp) | Out-Null
try {
    foreach ($zipName in @("KnoxBridgeRuntime-$Version.zip", "knoxbridge-runtime-$Version.zip")) {
        $zipPath = Join-Path $root "build/distributions/$zipName"
        Verify-File $zipPath
        $zip = [IO.Compression.ZipFile]::OpenRead($zipPath)
        try {
            if (@($zip.Entries | Where-Object { $_.FullName -match '(?i)\.(pk8|dpapi|pfx|p12|keystore|jks|pem|key)$' }).Count) { throw 'Private-key material found in archive' }
            $names = @("knoxbridge-agent-$Version.jar", 'bootstrap-windows/knoxbridge-bootstrap.dll')
            if ($zipName.StartsWith('knoxbridge-runtime-')) { $names += "runtime-api-$Version.jar" }
            foreach ($name in $names) {
                $out = Join-Path $temp ([Guid]::NewGuid().ToString('N'))
                [IO.Directory]::CreateDirectory($out) | Out-Null
                $destination = Join-Path $out ([IO.Path]::GetFileName($name))
                foreach ($suffix in @('', '.knoxsig')) {
                    $entry = $zip.GetEntry($name + $suffix)
                    if (!$entry) { throw "Archive missing signed artifact: $name$suffix" }
                    [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destination + $suffix)
                }
                Verify-File $destination
            }
        } finally { $zip.Dispose() }
    }
    Verify-File (Join-Path $root 'bootstrap-windows/build/KnoxBridgeSetup.exe')
    Write-Output 'Release signatures PASS owner fingerprint, final archives/EXE, embedded runtime/API/DLL, no private keys'
} finally {
    # Only this newly-created random temporary directory is removed.
    if ([IO.Path]::GetFullPath($temp).StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()), [StringComparison]::OrdinalIgnoreCase)) { [IO.Directory]::Delete($temp, $true) }
}
