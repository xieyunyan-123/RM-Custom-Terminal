param(
    [string]$MsysRoot = "$env:USERPROFILE\RMTools\msys64",
    [int]$Jobs = 4
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
# Use the ASCII junction created for this checkout to avoid toolchain path encoding issues.
$alias = "$env:USERPROFILE\RMTools\terminal-workspace"
if ((Test-Path "$alias\RM26_Client") -and ((Get-Item $alias).Target -eq $root)) { $root = $alias }
$source = Join-Path $root 'RM26_Client'
$build = Join-Path $source 'build\windows'
$prefix = Join-Path $MsysRoot 'ucrt64'
$env:PATH = "$prefix\bin;$env:PATH"
$env:QT_PLUGIN_PATH = "$prefix\share\qt6\plugins"
$env:QML_IMPORT_PATH = "$prefix\share\qt6\qml"
if (!(Test-Path "$source\config.json")) { Copy-Item "$source\config.example.json" "$source\config.json" }
& "$prefix\bin\cmake.exe" -S $source -B $build -G Ninja "-DCMAKE_PREFIX_PATH=$prefix" "-DCMAKE_C_COMPILER=$prefix/bin/gcc.exe" "-DCMAKE_CXX_COMPILER=$prefix/bin/g++.exe" "-DCMAKE_MAKE_PROGRAM=$prefix/bin/ninja.exe" "-DPAHO_MQTT_ROOT=$prefix" -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=ON -DRM26_ENABLE_DEVTOOLS=OFF
if ($LASTEXITCODE -ne 0) { throw 'CMake configuration failed.' }
& "$prefix\bin\cmake.exe" --build $build --parallel $Jobs
if ($LASTEXITCODE -ne 0) { throw 'Client build failed.' }
