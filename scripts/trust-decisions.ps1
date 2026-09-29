function Set-KnoxBridgeTrustDecision {
    param(
        [Parameter(Mandatory=$true)][string]$TrustFile,
        [Parameter(Mandatory=$true)][string]$Hash,
        [Parameter(Mandatory=$true)][ValidateSet('allow','deny')][string]$Decision
    )
    if ($Hash -notmatch '^(?i)[0-9a-f]{64}$') { throw 'A full SHA-256 hash is required.' }
    $key = $Hash.ToLowerInvariant()
    $parent = Split-Path -Parent $TrustFile
    if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    $lines = @()
    if (Test-Path -LiteralPath $TrustFile -PathType Leaf) {
        $lines = @(Get-Content -LiteralPath $TrustFile | Where-Object {
            $_ -notmatch "^\s*$([regex]::Escape($key))\s*="
        })
    }
    $lines += "# Updated by KnoxBridge Setup $(Get-Date -Format o)"
    $lines += "$key=$Decision"
    [IO.File]::WriteAllLines($TrustFile, $lines, [Text.Encoding]::ASCII)
}
