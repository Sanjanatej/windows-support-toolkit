<#
.SYNOPSIS
    Generates a system health report for a Windows PC.
.DESCRIPTION
    Collects CPU load, RAM usage, disk usage, uptime and the top memory-hungry
    processes, flags anything above a threshold, prints the report and saves
    a timestamped copy in the reports folder.
.EXAMPLE
    .\Get-HealthReport.ps1
.EXAMPLE
    .\Get-HealthReport.ps1 -DiskWarn 80
#>
[CmdletBinding()]
param(
    [string]$OutputDir = (Join-Path $PSScriptRoot "..\reports"),
    [int]$CpuWarn  = 85,
    [int]$RamWarn  = 85,
    [int]$DiskWarn = 90
)

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# ---- Collect data ----
$os = Get-CimInstance -ClassName Win32_OperatingSystem

$cpuLoad = [math]::Round(
    (Get-CimInstance -ClassName Win32_Processor |
        Measure-Object -Property LoadPercentage -Average).Average, 1)

# These values are reported in KB, so dividing by 1MB (1048576) gives GB
$totalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
$freeGB  = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
$usedGB  = [math]::Round($totalGB - $freeGB, 2)
$ramPct  = [math]::Round(($usedGB / $totalGB) * 100, 1)

$uptime     = (Get-Date) - $os.LastBootUpTime
$uptimeText = "{0} days, {1} hours, {2} minutes" -f $uptime.Days, $uptime.Hours, $uptime.Minutes

$disks = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
    $usedPct = 0
    if ($_.Size -gt 0) {
        $usedPct = [math]::Round((($_.Size - $_.FreeSpace) / $_.Size) * 100, 1)
    }
    [pscustomobject]@{
        Drive   = $_.DeviceID
        SizeGB  = [math]::Round($_.Size / 1GB, 1)
        FreeGB  = [math]::Round($_.FreeSpace / 1GB, 1)
        UsedPct = $usedPct
    }
}

$topProcs = Get-Process |
    Sort-Object -Property WorkingSet64 -Descending |
    Select-Object -First 5 -Property Name, Id,
        @{ Name = 'MemoryMB'; Expression = { [math]::Round($_.WorkingSet64 / 1MB, 0) } }

# ---- Check thresholds ----
$warnings = @()
if ($cpuLoad -ge $CpuWarn) { $warnings += "High CPU load: $cpuLoad% (limit $CpuWarn%)" }
if ($ramPct  -ge $RamWarn) { $warnings += "High memory usage: $ramPct% (limit $RamWarn%)" }
foreach ($d in $disks) {
    if ($d.UsedPct -ge $DiskWarn) {
        $warnings += "Disk $($d.Drive) is $($d.UsedPct)% full (limit $DiskWarn%)"
    }
}

# ---- Build the report ----
$report = @()
$report += "=============================================="
$report += " WINDOWS SYSTEM HEALTH REPORT"
$report += "=============================================="
$report += " Generated : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$report += " Computer  : $env:COMPUTERNAME"
$report += " OS        : $($os.Caption) (build $($os.BuildNumber))"
$report += " Uptime    : $uptimeText"
$report += ""
$report += "--- CPU ---"
$report += " Load      : $cpuLoad %"
$report += ""
$report += "--- MEMORY ---"
$report += " Used      : $usedGB GB of $totalGB GB ($ramPct %)"
$report += ""
$report += "--- DISKS ---"
$report += ($disks | Format-Table -AutoSize | Out-String).TrimEnd()
$report += ""
$report += "--- TOP 5 PROCESSES BY MEMORY ---"
$report += ($topProcs | Format-Table -AutoSize | Out-String).TrimEnd()
$report += ""
$report += "--- STATUS ---"
if ($warnings.Count -eq 0) {
    $report += " HEALTHY: no thresholds exceeded."
} else {
    $report += " ATTENTION NEEDED:"
    foreach ($w in $warnings) { $report += "  - $w" }
}
$report += "=============================================="

# ---- Show and save ----
$file = Join-Path $OutputDir ("health-{0}.txt" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
$report | Set-Content -Path $file -Encoding UTF8
$report | ForEach-Object { Write-Host $_ }
Write-Host ""
Write-Host "Report saved to: $file"
