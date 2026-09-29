param(
    [Parameter(Mandatory=$true)][string]$PackageZip,
    [string]$OutputDirectory
)
$ErrorActionPreference = 'Stop'
if (!$OutputDirectory) { $OutputDirectory = Join-Path $PSScriptRoot '..\bootstrap-windows\build' }
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$zip = (Resolve-Path -LiteralPath $PackageZip).Path
$output = [IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Force -Path $output | Out-Null
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (!(Test-Path -LiteralPath $vswhere)) { throw 'Visual Studio Installer vswhere.exe was not found; install the C++ x64 build tools to produce the Windows installer.' }
$install = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (!$install) { throw 'Visual Studio C++ x64 build tools are not installed.' }
$devCmd = Join-Path $install 'Common7\Tools\VsDevCmd.bat'
$source = Join-Path $root 'bootstrap-windows\src\knoxbridge_setup.cpp'
$res = Join-Path $output 'knoxbridge_setup_payload.rc'
$exe = Join-Path $output 'KnoxBridgeSetup.exe'
$rcText = '101 RCDATA "' + $zip.Replace('\','\\') + '"' + "`r`n"
[IO.File]::WriteAllText($res, $rcText, [Text.Encoding]::ASCII)
$commandFile = Join-Path $output 'build-installer.cmd'
$script = @"
@echo off
call "$devCmd" -arch=x64 -host_arch=x64 >nul
if errorlevel 1 exit /b %errorlevel%
pushd "$output"
rc.exe /nologo /fo knoxbridge_setup_payload.res knoxbridge_setup_payload.rc
if errorlevel 1 exit /b %errorlevel%
cl.exe /nologo /O2 /MT /W4 /EHsc /std:c++17 /Fe:"$exe" "$source" knoxbridge_setup_payload.res /link shell32.lib ole32.lib
set BUILD_RESULT=%errorlevel%
popd
exit /b %BUILD_RESULT%
"@
[IO.File]::WriteAllText($commandFile, $script, [Text.Encoding]::ASCII)
& $env:ComSpec /d /c "`"$commandFile`""
if ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $exe)) { throw "Windows installer build failed with exit $LASTEXITCODE." }
Write-Output "KnoxBridge standalone Windows installer build PASS path=$exe"
