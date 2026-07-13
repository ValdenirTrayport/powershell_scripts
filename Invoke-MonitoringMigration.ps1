#Requires -Version 5.1
<#
.SYNOPSIS
    Runs Flyway database migrations for the Monitoring (TCMSOrionDashboard) database.

.DESCRIPTION
    Executes 'flyway migrate' against the local TCMSOrionDashboard database using
    the migration scripts located in the BusinessSystems.Monitoring repository.

.EXAMPLE
    .\Invoke-MonitoringMigration.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$flywayUrl       = "jdbc:sqlserver://localhost;encrypt=true;databaseName=TCMSOrionDashboard;integratedSecurity=true;trustServerCertificate=true"
$migrationsPath  = "C:\dev\BusinessSystems.Monitoring\.migrations"

if (-not (Get-Command flyway -ErrorAction SilentlyContinue)) {
    Write-Error "Flyway is not installed or not in PATH. Please install Flyway CLI."
    return
}

if (-not (Test-Path -LiteralPath $migrationsPath -PathType Container)) {
    Write-Error "Migrations directory not found: $migrationsPath"
    return
}

Write-Host "`nFlyway Version:" -ForegroundColor Cyan
flyway --version

Write-Host "`nRunning Flyway migrate on TCMSOrionDashboard (Monitoring)..." -ForegroundColor Yellow
Write-Host "  URL:       $flywayUrl" -ForegroundColor Gray
Write-Host "  Location:  filesystem:$migrationsPath`n" -ForegroundColor Gray

flyway migrate `
    "-url=$flywayUrl" `
    "-locations=filesystem:$migrationsPath"

if ($LASTEXITCODE -eq 0) {
    Write-Host "`nMigration completed successfully." -ForegroundColor Green
}
else {
    Write-Error "Flyway migration failed with exit code $LASTEXITCODE."
}
