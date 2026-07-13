#Requires -Version 5.1
<#
.SYNOPSIS
    Imports a large SQL script file into SQL Server using sqlcmd.

.DESCRIPTION
    Executes a SQL script file against the local SQL Server instance using sqlcmd
    with optimised settings for large files (UTF-16 LE support, variable substitution
    disabled, error-only output mode).

.PARAMETER FilePath
    Full path to the SQL script file to import.

.PARAMETER Server
    SQL Server instance name. Defaults to localhost (.).

.EXAMPLE
    .\Import-SqlScript.ps1 -FilePath "C:\Backups\TRAYINVOICE_data.sql"

.EXAMPLE
    .\Import-SqlScript.ps1 -FilePath "C:\Backups\data.sql" -Server "bs-tsql22"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$FilePath,

    [Parameter()]
    [string]$Server = "."
)

$ErrorActionPreference = 'Stop'

$LogFile = Join-Path -Path $PSScriptRoot -ChildPath "import_errors.log"

Write-Host "`nStarting SQL Import..." -ForegroundColor Cyan
Write-Host "  File:   $FilePath" -ForegroundColor Gray
Write-Host "  Server: $Server" -ForegroundColor Gray
Write-Host "  Log:    $LogFile" -ForegroundColor Gray
Write-Host "------------------------------------------------"

$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# -x: Disables variable substitution (prevents JSON $(...) from crashing)
# -b: Exit on error
# -m 1: Severity 1+ only (quiet mode)
# -r 1: Redirects messages to stderr
sqlcmd -S $Server -i "$FilePath" -x -b -m 1 -r 1 2> "$LogFile"

$Stopwatch.Stop()
$Time = $Stopwatch.Elapsed

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n[SUCCESS] Import finished successfully!" -ForegroundColor Green
}
else {
    Write-Host "`n[FAILED] The import stopped. Check the log: $LogFile" -ForegroundColor Red
    Get-Content -LiteralPath $LogFile -TotalCount 10 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
}

Write-Host "Total Execution Time: $($Time.Hours)h $($Time.Minutes)m $($Time.Seconds)s`n"