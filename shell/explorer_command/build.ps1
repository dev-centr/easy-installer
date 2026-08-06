#Requires -Version 7
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$outDir = Join-Path $here 'build'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (-not (Test-Path $vswhere)) {
    Write-Error 'vswhere not found. Install Visual Studio Build Tools with C++ workload.'
}
$vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vs) {
    Write-Error 'MSVC VC Tools not found.'
}
$aux = Join-Path $vs 'VC\Auxiliary\Build\vcvars64.bat'
$src = Join-Path $here 'EasyInstallerExplorerCommand.cpp'
$def = Join-Path $here 'EasyInstallerExplorerCommand.def'
$dll = Join-Path $outDir 'EasyInstallerExplorerCommand.dll'

$cmd = @"
call `"$aux`" >nul && cl /nologo /O2 /LD /EHsc /std:c++17 /utf-8 `"$src`" /Fe:`"$dll`" /link /DEF:`"$def`" ole32.lib shell32.lib shlwapi.lib
"@
cmd /c $cmd
if ($LASTEXITCODE -ne 0) {
    Write-Error "cl failed with exit $LASTEXITCODE"
}
Write-Host "Built $dll"
