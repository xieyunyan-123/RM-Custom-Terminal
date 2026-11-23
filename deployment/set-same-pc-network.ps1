param([switch]$Undo)

$ErrorActionPreference = 'Stop'
$runtime = Join-Path (Split-Path $PSScriptRoot -Parent) '.local\runtime'
$stateFile = Join-Path $runtime 'same-pc-network.json'
$logFile = Join-Path $runtime 'same-pc-network.log'
New-Item -ItemType Directory -Force $runtime | Out-Null
Start-Transcript -Path $logFile -Append
try {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    if (!$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Run this script in an administrator PowerShell.'
    }
    if ($Undo) {
        if (Test-Path -LiteralPath $stateFile) {
            $state = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json
            foreach ($address in $state.added) {
                Get-NetIPAddress -InterfaceIndex 1 -IPAddress $address -ErrorAction SilentlyContinue |
                    Remove-NetIPAddress -Confirm:$false
            }
            Remove-Item -LiteralPath $stateFile
        }
    } else {
        if (!(Test-Path -LiteralPath $stateFile)) {
            $snapshot = @(Get-NetIPAddress -AddressFamily IPv4 | Select-Object InterfaceIndex, InterfaceAlias, IPAddress, PrefixLength, SkipAsSource)
            @{ before = $snapshot; added = @() } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $stateFile -Encoding UTF8
        }
        $state = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json
        foreach ($address in @('192.168.12.1', '192.168.12.2')) {
            $existing = Get-NetIPAddress -IPAddress $address -ErrorAction SilentlyContinue
            if ($existing) {
                if ($existing.InterfaceIndex -ne 1) { throw "$address already belongs to another interface." }
                continue
            }
            & netsh interface ipv4 add address name=1 address=$address mask=255.255.255.0 store=active skipassource=true
            if ($LASTEXITCODE -ne 0) { throw "Failed to add $address" }
            $state.added = @($state.added) + $address
            $state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $stateFile -Encoding UTF8
        }
    }
    Get-NetIPAddress -InterfaceIndex 1 -AddressFamily IPv4 | Format-Table IPAddress, PrefixLength, SkipAsSource
} finally {
    Stop-Transcript
}
