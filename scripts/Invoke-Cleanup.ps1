<#
.SYNOPSIS
    Cleans temp files, flushes the DNS cache and optionally restarts a service.
.DESCRIPTION
    Safe by design: supports -WhatIf (dry run) so you can see what would happen
    before anything is changed. Every action is written to a log file.
.PARAMETER ServiceName
    Optional. Name of a Windows service to restart (for example: Spooler).
    Restarting a service needs PowerShell to be run as Administrator.
.PARAMETER OlderThanDays
    Only temp files older than this many days are removed (default 1).
.EXAMPLE
    .\Invoke-Cleanup.ps1 -WhatIf
.EXAMPLE
    .\Invoke-Cleanup.ps1
.EXAMPLE
    .\Invoke-Cleanup.ps1 -ServiceName Spooler
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$ServiceName,
    [int]$OlderThanDays = 1
)

$logDir = Join-Path $PSScriptRoot "..\logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force -WhatIf:$false | Out-Null
}
$logFile = Join-Path $logDir ("cleanup-{0}.log" -f (Get-Date -Format 'yyyyMMdd'))

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $line = "{0} [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Write-Host $line
    Add-Content -Path $logFile -Value $line -WhatIf:$false   # always log, even in a dry run
}

Write-Log "Cleanup started (dry run: $([bool]$WhatIfPreference))"

# ---- Step 1: old temp files ----
$cutoff   = (Get-Date).AddDays(-$OlderThanDays)
$tempPath = $env:TEMP
$files = @(
    Get-ChildItem -Path $tempPath -Recurse -Force -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $cutoff }
)
$sizeMB = [math]::Round((($files | Measure-Object -Property Length -Sum).Sum) / 1MB, 1)
Write-Log "Found $($files.Count) temp file(s) older than $OlderThanDays day(s), about $sizeMB MB, in $tempPath"

if ($files.Count -gt 0 -and $PSCmdlet.ShouldProcess("$($files.Count) files in $tempPath", "Delete")) {
    $deleted = 0
    foreach ($f in $files) {
        try {
            Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop
            $deleted++
        } catch {
            # file is in use, skip it
        }
    }
    Write-Log "Deleted $deleted of $($files.Count) file(s). The rest were in use."
}

# ---- Step 2: DNS cache ----
if ($PSCmdlet.ShouldProcess("DNS resolver cache", "Flush")) {
    Clear-DnsClientCache
    Write-Log "DNS cache flushed"
}

# ---- Step 3: optional service restart ----
if ($ServiceName) {
    $svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if (-not $svc) {
        Write-Log "Service '$ServiceName' not found" "ERROR"
    }
    elseif ($PSCmdlet.ShouldProcess($ServiceName, "Restart service")) {
        try {
            Restart-Service -Name $ServiceName -Force -ErrorAction Stop
            Start-Sleep -Seconds 2
            $status = (Get-Service -Name $ServiceName).Status
            Write-Log "Service '$ServiceName' status after restart: $status"
        } catch {
            Write-Log "Could not restart '$ServiceName': $($_.Exception.Message). Try PowerShell as Administrator." "ERROR"
        }
    }
}

Write-Log "Cleanup finished"
Write-Host ""
Write-Host "Log saved to: $logFile"
