# Bâtit le noyau C++ de la grille (cpp/ → godot/addons/sensen_grille/bin/), voir « Modules de la simulation et le C++ ».
# Prérequis : Visual Studio Build Tools (C++ x64), Python 3 avec SCons (pip install scons), git.
#   powershell -ExecutionPolicy Bypass -File tools/build_cpp.ps1 [-Target template_release|template_debug] [-Jobs 8]
param(
	[string]$Target = "template_release",
	[int]$Jobs = 8
)
$ErrorActionPreference = "Stop"
$racine = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$cpp = Join-Path $racine "cpp"
if (-not (Test-Path (Join-Path $cpp "godot-cpp\SConstruct"))) {
	Write-Host "godot-cpp absent : clonage de la branche 4.5 (la plus récente compatible avec le 4.6.3 du projet)"
	git clone --depth 1 --branch 4.5 https://github.com/godotengine/godot-cpp.git (Join-Path $cpp "godot-cpp")
	if (-not $?) { throw "clonage de godot-cpp impossible" }
}
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vcvars = $null
if (Test-Path $vswhere) {
	$vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
	if ($vs) { $vcvars = Join-Path $vs "VC\Auxiliary\Build\vcvars64.bat" }
}
if (-not $vcvars -or -not (Test-Path $vcvars)) {
	$candidats = Get-ChildItem "${env:ProgramFiles(x86)}\Microsoft Visual Studio\*\*\VC\Auxiliary\Build\vcvars64.bat" -ErrorAction SilentlyContinue
	if ($candidats) { $vcvars = $candidats[0].FullName }
}
if (-not $vcvars) { throw "vcvars64.bat introuvable : installer les Build Tools C++ de Visual Studio" }
Write-Host "compilateur : $vcvars"
$scons = "python -m SCons platform=windows target=$Target arch=x86_64 build_profile=build_profile.json debug_symbols=no -j$Jobs"
Set-Location $cpp
cmd /c "call ""$vcvars"" >nul && $scons"
if ($LASTEXITCODE -ne 0) { throw "scons a échoué ($LASTEXITCODE)" }
Get-ChildItem (Join-Path $racine "godot\addons\sensen_grille\bin") | Format-Table Name, Length, LastWriteTime
