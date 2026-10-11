param(
    [Parameter(Mandatory=$true)][string[]]$Artifacts,
    [string]$KeyDirectory = (Join-Path $env:USERPROFILE '.knoxbridge-signing/exe-create'),
    [string]$AgentJar
)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (!$AgentJar) {
    $text = [IO.File]::ReadAllText((Join-Path $root 'build.gradle.kts'))
    if ($text -notmatch 'version\s*=\s*"([^"]+)"') { throw 'Missing version' }
    $AgentJar = Join-Path $root "runtime-core/build/libs/knoxbridge-agent-$($Matches[1]).jar"
}
$keyRoot = [IO.Path]::GetFullPath($KeyDirectory)
if ($keyRoot -eq $root -or $keyRoot.StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Private key must be outside repository' }
if ((Get-Item -LiteralPath $keyRoot).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Key directory must not be a junction' }
$publicKey = Join-Path $keyRoot 'publisher-public.der'
$fingerprint = & java '-cp' $AgentJar 'com.knoxbridge.runtime.SigningTool' 'fingerprint' $publicKey
if ($LASTEXITCODE -ne 0 -or $fingerprint -notmatch '^[0-9a-f]{64}$') { throw 'Invalid publisher key' }
if ($fingerprint -ne 'eda1c49f4f51e604d86c1889fe72f90f16c42ff7bb6c69f1d9be74d79645228f') { throw 'Key does not match the established .exe publisher identity' }
Add-Type -AssemblyName System.Security
$rawKey = Join-Path $keyRoot ('temporary-' + [Guid]::NewGuid().ToString('N') + '.pk8')
try {
    $bytes = [Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes((Join-Path $keyRoot 'publisher-private.pk8.dpapi')), $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
    [IO.File]::WriteAllBytes($rawKey, $bytes)
    [Array]::Clear($bytes, 0, $bytes.Length)
    foreach ($artifact in $Artifacts) {
        $path = (Resolve-Path -LiteralPath $artifact).Path
        if (Test-Path -LiteralPath ($path + '.knoxsig')) {
            & java '-cp' $AgentJar 'com.knoxbridge.runtime.SigningTool' 'verify-file' $path $fingerprint
            if ($LASTEXITCODE -ne 0) { throw "Stale signature: deliberately remove generated sidecar before signing $path" }
        } else {
            & java '-cp' $AgentJar 'com.knoxbridge.runtime.SigningTool' 'sign-file' $path $rawKey $publicKey
            if ($LASTEXITCODE -ne 0) { throw "Signing failed: $path" }
            & java '-cp' $AgentJar 'com.knoxbridge.runtime.SigningTool' 'verify-file' $path $fingerprint
            if ($LASTEXITCODE -ne 0) { throw "Signature verification failed: $path" }
        }
    }
} finally {
    if ($bytes) { [Array]::Clear($bytes, 0, $bytes.Length) }
    if (Test-Path -LiteralPath $rawKey) { [IO.File]::Delete($rawKey) }
}
