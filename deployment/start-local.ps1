param(
    [string]$MsysRoot = "$env:USERPROFILE\RMTools\msys64",
    [switch]$NoClient
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$source = Join-Path $root 'RM26_Client'
$runtime = Join-Path $root '.local\runtime'
New-Item -ItemType Directory -Force $runtime | Out-Null
$prefix = Join-Path $MsysRoot 'ucrt64'
$env:PATH = "$prefix\bin;$env:PATH"
$env:QT_PLUGIN_PATH = "$prefix\share\qt6\plugins"
$env:QML_IMPORT_PATH = "$prefix\share\qt6\qml"
$env:PYTHONIOENCODING = 'utf-8'
$env:PYTHONUNBUFFERED = '1'
$stateFile = Join-Path $runtime 'processes.json'
if (Test-Path $stateFile) { throw 'A saved local session exists. Run stop-local.ps1 first.' }
foreach ($port in @(3333,8000)) {
    if (Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue) { throw "Port $port is already in use." }
}
$exe = Join-Path $source 'build\windows\RoboMasterClient2025.exe'
if (!$NoClient -and !(Test-Path $exe)) { throw 'Build the client with build-windows.ps1 first.' }
@('listener 3333 127.0.0.1','allow_anonymous true','persistence false') | Set-Content -Encoding ascii "$runtime\mosquitto.conf"
$owned = @()
function Save-OwnedProcess($process, $kind) {
    $script:owned += @{ id=$process.Id; startedTicks=$process.StartTime.ToUniversalTime().Ticks.ToString(); kind=$kind }
    ConvertTo-Json -InputObject @($script:owned) | Set-Content -Encoding utf8 $stateFile
}
try {
    $broker = Start-Process "$prefix\bin\mosquitto.exe" -ArgumentList @('-c', ('"' + "$runtime\mosquitto.conf" + '"')) -WindowStyle Hidden -PassThru -RedirectStandardOutput "$runtime\mqtt.out.log" -RedirectStandardError "$runtime\mqtt.err.log"
    Save-OwnedProcess $broker 'broker'
    $ready=$false
    for ($i=0;$i -lt 40;$i++) {
        if (Get-NetTCPConnection -State Listen -LocalPort 3333 -ErrorAction SilentlyContinue) { $ready=$true; break }
        Start-Sleep -Milliseconds 250
    }
    if (!$ready) { throw 'MQTT broker did not start. Check .local/runtime/mqtt.err.log.' }
    $sim = Start-Process "$source\sim\.venv\Scripts\python.exe" -WorkingDirectory "$source\sim" -ArgumentList @('-m','server.main','--mqtt-host','127.0.0.1','--mqtt-port','3333','--current-robot-id','1','--web-host','127.0.0.1','--web-port','8000') -WindowStyle Hidden -PassThru -RedirectStandardOutput "$runtime\sim.out.log" -RedirectStandardError "$runtime\sim.err.log"
    Save-OwnedProcess $sim 'simulator'
    $ready=$false
    for ($i=0;$i -lt 60;$i++) {
        try { $null=Invoke-WebRequest 'http://127.0.0.1:8000/' -UseBasicParsing -TimeoutSec 1; $ready=$true; break } catch { Start-Sleep -Milliseconds 250 }
    }
    if (!$ready) { throw 'Simulator did not start. Check .local/runtime/sim.err.log.' }
    if (!$NoClient) {
        $client = Start-Process $exe -WorkingDirectory (Split-Path $exe) -WindowStyle Hidden -PassThru
        Save-OwnedProcess $client 'client'
    }
    Write-Host 'Local simulator: http://127.0.0.1:8000/'
    Write-Host 'MQTT: 127.0.0.1:3333; robot ID: 1; main video UDP: 3334.'
    Write-Host 'Stop this session with deployment/stop-local.ps1.'
} catch {
    & "$PSScriptRoot\stop-local.ps1"
    throw
}
