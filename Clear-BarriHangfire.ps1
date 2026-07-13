#Requires -Version 5.1
<#
.SYNOPSIS
    Clears all Hangfire job tables in the local TRAYINVOICE database.

.DESCRIPTION
    Deletes all records from HangFire and Calculation schema tables in dependency
    order. Used to reset the local job queue during development.

.EXAMPLE
    .\Clear-BarriHangfire.ps1
#>
[CmdletBinding(SupportsShouldProcess)]
param()

$ErrorActionPreference = 'Stop'

# Load connection string from centralised config
$configPath = Join-Path -Path $PSScriptRoot -ChildPath "config\ConnectionStrings.json"
$connections = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$ConnectionString = $connections.Local.ConnectionString

$Schemas = @("HangFire", "Calculation")

foreach ($Schema in $Schemas) {
    if (-not $PSCmdlet.ShouldProcess("[$Schema] tables", "Delete all rows")) {
        continue
    }

    Write-Host "Cleaning schema: [$Schema]..." -ForegroundColor Cyan

    $SqlQuery = @"
DELETE FROM [$Schema].[AggregatedCounter];
DELETE FROM [$Schema].[Counter];
DELETE FROM [$Schema].[JobParameter];
DELETE FROM [$Schema].[JobQueue];
DELETE FROM [$Schema].[List];
DELETE FROM [$Schema].[Set];
DELETE FROM [$Schema].[State];
DELETE FROM [$Schema].[Hash];
DELETE FROM [$Schema].[Job];
"@

    $Connection = $null
    try {
        $Connection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
        $Command = $Connection.CreateCommand()
        $Command.CommandText = $SqlQuery

        $Connection.Open()
        $null = $Command.ExecuteNonQuery()
        Write-Host "Successfully cleared [$Schema]." -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to clear [$Schema]: $($_.Exception.Message)"
    }
    finally {
        if ($null -ne $Connection -and $Connection.State -eq [System.Data.ConnectionState]::Open) {
            $Connection.Close()
        }
    }
}