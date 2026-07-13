#Requires -Version 5.1
<#
.SYNOPSIS
    Runs Flyway database migrations for the Barri (TRAYINVOICE) database.

.DESCRIPTION
    Executes 'flyway migrate' against the local TRAYINVOICE database using the
    migration scripts located in the BusinessSystems.Barri repository.
    Out-of-order migrations are enabled.

.EXAMPLE
    .\Invoke-BarriMigration.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$flywayUrl       = "jdbc:sqlserver://localhost;encrypt=true;databaseName=TRAYINVOICE;integratedSecurity=true;trustServerCertificate=true"
$migrationsPath  = "C:\dev\BusinessSystems.Barri\.migrations"

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

Write-Host "`nRunning Flyway migrate on TRAYINVOICE (Barri)..." -ForegroundColor Yellow
Write-Host "  URL:       $flywayUrl" -ForegroundColor Gray
Write-Host "  Location:  filesystem:$migrationsPath" -ForegroundColor Gray
Write-Host "  Schemas:   dbo" -ForegroundColor Gray
Write-Host "  OutOfOrder: true`n" -ForegroundColor Gray

flyway migrate `
    "-url=$flywayUrl" `
    "-locations=filesystem:$migrationsPath" `
    "-schemas=dbo" `
    "-outOfOrder=true"

if ($LASTEXITCODE -eq 0) {
    Write-Host "`nMigration completed successfully." -ForegroundColor Green
}
else {
    Write-Error "Flyway migration failed with exit code $LASTEXITCODE."
}
