$ErrorActionPreference = 'Stop'
$stateFile = Join-Path (Split-Path $PSScriptRoot -Parent) '.local\runtime\processes.json'
if (!(Test-Path $stateFile)) { Write-Host 'No saved local session.'; return }
$owned = @(Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json)
[array]::Reverse($owned)
foreach ($entry in $owned) {
    $process = Get-Process -Id $entry.id -ErrorAction SilentlyContinue
    if ($process -and $process.StartTime.ToUniversalTime().Ticks.ToString() -eq [string]$entry.startedTicks) {
        # Python virtual-environment launchers create a child interpreter on Windows.
        $children = @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$($process.Id)" -ErrorAction SilentlyContinue)
        foreach ($child in $children) {
            Stop-Process -Id $child.ProcessId -ErrorAction SilentlyContinue
            Wait-Process -Id $child.ProcessId -Timeout 10 -ErrorAction SilentlyContinue
        }
        Stop-Process -Id $process.Id
        Wait-Process -Id $process.Id -Timeout 10 -ErrorAction SilentlyContinue
    }
}
Remove-Item -LiteralPath $stateFile
Write-Host 'Stopped processes created by this local session.'
