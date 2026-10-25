<#
.SYNOPSIS
    Diagnoses where a network problem is: adapter, router, internet or DNS.
.DESCRIPTION
    Runs four checks in order and prints a plain-English diagnosis:
      1. Is there an active network adapter with a default gateway?
      2. Can the router (gateway) be reached?
      3. Can the internet be reached by IP address?
      4. Can a name be resolved by DNS?
    Every result is also written to a daily log file.
.EXAMPLE
    .\Test-NetworkHealth.ps1
.EXAMPLE
    # Simulate a DNS failure safely, without changing any system setting
    .\Test-NetworkHealth.ps1 -DnsTestName "this-name-does-not-exist.invalid"
.EXAMPLE
    # Simulate "router OK but no internet"
    .\Test-NetworkHealth.ps1 -InternetTarget "10.255.255.1"
#>
[CmdletBinding()]
param(
    [string]$InternetTarget = "8.8.8.8",
    [string]$DnsTestName    = "google.com"
)

$logDir = Join-Path $PSScriptRoot "..\logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$logFile = Join-Path $logDir ("network-{0}.log" -f (Get-Date -Format 'yyyyMMdd'))

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $line = "{0} [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Write-Host $line
    Add-Content -Path $logFile -Value $line
}

Write-Log "Network diagnosis started"

# ---- Check 1: active adapter with a gateway ----
$config = Get-NetIPConfiguration |
    Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' } |
    Select-Object -First 1

if (-not $config) {
    Write-Log "No active adapter with a default gateway found." "FAIL"
    Write-Log "DIAGNOSIS: This PC is not connected to a network. Check Wi-Fi/cable and that airplane mode is off." "RESULT"
    return
}

$adapterName = $config.InterfaceAlias
$ipAddress   = $config.IPv4Address.IPAddress
$gateway     = $config.IPv4DefaultGateway.NextHop
Write-Log "Adapter: $adapterName | IP: $ipAddress | Gateway: $gateway"

# ---- Check 2: router ----
$gatewayOk = Test-Connection -ComputerName $gateway -Count 2 -Quiet
if ($gatewayOk) { Write-Log "Router ($gateway) reachable" "PASS" }
else            { Write-Log "Router ($gateway) NOT reachable" "FAIL" }

# ---- Check 3: internet by IP ----
$internetOk = Test-Connection -ComputerName $InternetTarget -Count 2 -Quiet
if ($internetOk) { Write-Log "Internet target ($InternetTarget) reachable" "PASS" }
else             { Write-Log "Internet target ($InternetTarget) NOT reachable" "FAIL" }

# ---- Check 4: DNS ----
$dnsOk = $false
try {
    $answer = Resolve-DnsName -Name $DnsTestName -ErrorAction Stop
    if ($answer) { $dnsOk = $true }
} catch {
    $dnsOk = $false
}
if ($dnsOk) { Write-Log "DNS lookup for '$DnsTestName' worked" "PASS" }
else        { Write-Log "DNS lookup for '$DnsTestName' FAILED" "FAIL" }

# ---- Diagnosis ----
if (-not $gatewayOk) {
    $diagnosis = "Cannot reach the router. Check Wi-Fi/cable, restart the router, then run: ipconfig /release and ipconfig /renew."
}
elseif (-not $internetOk) {
    $diagnosis = "Router is reachable but the internet is not. Likely a router/ISP issue. Restart the router or contact the ISP."
}
elseif (-not $dnsOk) {
    $diagnosis = "Internet works but DNS is failing. Run: ipconfig /flushdns, or set the DNS server to 8.8.8.8."
}
else {
    $diagnosis = "All checks passed. The network looks healthy."
}

Write-Log "DIAGNOSIS: $diagnosis" "RESULT"
Write-Host ""
Write-Host "Log saved to: $logFile"
