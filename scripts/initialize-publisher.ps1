param(
    [string]$KeyDirectory = (Join-Path $env:USERPROFILE '.knoxbridge-signing/exe-create'),
    [string]$AgentJar
)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (!$AgentJar) {
    $versionText = [IO.File]::ReadAllText((Join-Path $root 'build.gradle.kts'))
    if ($versionText -notmatch 'version\s*=\s*"([^"]+)"') { throw 'Missing version' }
    $AgentJar = Join-Path $root "runtime-core/build/libs/knoxbridge-agent-$($Matches[1]).jar"
}
$keyRoot = [IO.Path]::GetFullPath($KeyDirectory)
if ($keyRoot -eq $root -or $keyRoot.StartsWith($root.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Private key directory must be outside the repository' }
New-Item -ItemType Directory -Force -Path $keyRoot | Out-Null
if ((Get-Item -LiteralPath $keyRoot).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Signing-key directory must not be a symlink/junction' }
$sid = [Security.Principal.WindowsIdentity]::GetCurrent().User
$acl = [Security.AccessControl.DirectorySecurity]::new()
$acl.SetOwner($sid)
$acl.SetAccessRuleProtection($true, $false)
$acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($sid, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow'))
[IO.Directory]::SetAccessControl($keyRoot, $acl)
Add-Type -AssemblyName System.Security
$protectedKey = Join-Path $keyRoot 'publisher-private.pk8.dpapi'
$publicKey = Join-Path $keyRoot 'publisher-public.der'
if ((Test-Path -LiteralPath $protectedKey) -xor (Test-Path -LiteralPath $publicKey)) { throw 'Incomplete publisher-key pair; preserve files and resolve manually' }
if (!(Test-Path -LiteralPath $protectedKey)) {
    if (Test-Path -LiteralPath (Join-Path $root 'security/publisher-public.der')) { throw 'Publisher identity already exists. Restore its protected private key; do not silently generate a replacement identity.' }
    $rawKey = Join-Path $keyRoot ('temporary-' + [Guid]::NewGuid().ToString('N') + '.pk8')
    try {
        & java '-cp' $AgentJar 'com.knoxbridge.runtime.SigningTool' 'keygen' $rawKey $publicKey
        if ($LASTEXITCODE -ne 0) { throw 'Key generation failed' }
        $bytes = [IO.File]::ReadAllBytes($rawKey)
        $encrypted = [Security.Cryptography.ProtectedData]::Protect($bytes, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
        [IO.File]::WriteAllBytes($protectedKey, $encrypted)
        [Array]::Clear($bytes, 0, $bytes.Length)
    } finally {
        if ($bytes) { [Array]::Clear($bytes, 0, $bytes.Length) }
        if (Test-Path -LiteralPath $rawKey) { [IO.File]::Delete($rawKey) }
    }
}
$fingerprint = & java '-cp' $AgentJar 'com.knoxbridge.runtime.SigningTool' 'fingerprint' $publicKey
if ($LASTEXITCODE -ne 0 -or $fingerprint -notmatch '^[0-9a-f]{64}$') { throw 'Public fingerprint failed' }
if ($fingerprint -ne 'eda1c49f4f51e604d86c1889fe72f90f16c42ff7bb6c69f1d9be74d79645228f') { throw 'Publisher key does not match the established .exe identity' }
[IO.File]::WriteAllText((Join-Path $keyRoot 'publisher-fingerprint.txt'), "$fingerprint`n")
Write-Output "Publisher key ready: $keyRoot (private key protected for this Windows user)"
Write-Output "Public key SHA-256: $fingerprint"
