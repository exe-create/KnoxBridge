param([string]$OutputDirectory = (Join-Path $PSScriptRoot '..\bootstrap-windows\build'))
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$source = Join-Path $root 'bootstrap-windows\src\knoxbridge_bootstrap.cpp'
$output = [IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Force -Path $output | Out-Null
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (!(Test-Path -LiteralPath $vswhere)) { throw 'Visual Studio Installer vswhere.exe was not found; install the C++ x64 build tools to produce the Windows bootstrap.' }
$install = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (!$install) { throw 'Visual Studio C++ x64 build tools are not installed.' }
$devCmd = Join-Path $install 'Common7\Tools\VsDevCmd.bat'
if (!(Test-Path -LiteralPath $devCmd)) { throw "Visual Studio developer environment is missing: $devCmd" }
$dll = Join-Path $output 'knoxbridge-bootstrap.dll'
$commandFile = Join-Path $output 'build-native.cmd'
$script = @"
@echo off
call "$devCmd" -arch=x64 -host_arch=x64 >nul
if errorlevel 1 exit /b %errorlevel%
pushd "$output"
cl.exe /nologo /LD /O2 /MT /W4 /DUNICODE /D_UNICODE /Fo.\ "$source" /link /OUT:"$dll" kernel32.lib
set BUILD_RESULT=%errorlevel%
popd
exit /b %BUILD_RESULT%
"@
[IO.File]::WriteAllText($commandFile, $script, [Text.Encoding]::ASCII)
& $env:ComSpec /d /c "`"$commandFile`""
if ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $dll)) { throw "Native bootstrap build failed with exit $LASTEXITCODE." }
Write-Output "KnoxBridge Windows bootstrap build PASS path=$dll"
