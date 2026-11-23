param([int]$RobotId = 1, [string]$HikDebugSource = '', [switch]$HikMqtt)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$prefix = Join-Path $env:USERPROFILE 'RMTools\msys64\ucrt64'
$env:PATH = "$prefix\bin;$env:PATH"
$env:QT_PLUGIN_PATH = "$prefix\share\qt6\plugins"
$env:QML_IMPORT_PATH = "$prefix\share\qt6\qml"
$env:RM_MQTT_BROKER = '192.168.12.1'
$env:RM_MQTT_PORT = '3333'
$env:RM_CLIENT_ROBOT_ID = "$RobotId"
$env:RM_VIDEO_STREAM_URL = 'udp://192.168.12.2:3334'
$env:RM_HIK_DEBUG_SOURCE = $HikDebugSource
$env:RM_HIK_MQTT = if ($HikMqtt) { '1' } else { '' }
$build = Join-Path $root 'RM26_Client\build\windows'
$exe = Join-Path $build 'RoboMasterClient2025.exe'
Start-Process -FilePath $exe -WorkingDirectory $build -PassThru
