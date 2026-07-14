#Requires -Version 5.1
<#
.SYNOPSIS
    Interactive sub-menu for scaffolding EF database contexts in Barri.

.DESCRIPTION
    Presents a selectable list of database scaffold targets. Each target runs
    scaffold-database with the correct connection string inside the matching
    project folder.

.EXAMPLE
    Invoke-BarriDatabaseScaffold
#>
function Invoke-BarriDatabaseScaffold {
    [CmdletBinding()]
    param()

    $scaffoldTargets = @(
        @{
            Label            = "User Analysis"
            ProjectFolder    = "C:\dev\BusinessSystems.Barri\Trayport.BS.Entities.UserAnalysis"
            ConnectionString = "Data Source=localhost;Initial Catalog=UserAnalysis;Integrated Security=True;TrustServerCertificate=True;Encrypt=True"
        }
    )

    $selectedIndex = 0
    [Console]::CursorVisible = $false

    try {
        while ($true) {
            Clear-Host
            Write-Host "=== Scaffold Database in Barri ===" -ForegroundColor Yellow
            Write-Host "Up/Down to navigate | Enter to run | Esc to go back" -ForegroundColor Gray
            Write-Host ("-" * 50)

            for ($i = 0; $i -lt $scaffoldTargets.Count; $i++) {
                $entry = $scaffoldTargets[$i]
                $line = "[{0}] {1}" -f ($i + 1), $entry.Label

                if ($i -eq $selectedIndex) {
                    Write-Host " > $line" -ForegroundColor Black -BackgroundColor Cyan
                }
                else {
                    Write-Host "   $line"
                }
            }

            $keyInfo = [Console]::ReadKey($true)

            switch ($keyInfo.Key) {
                "UpArrow" {
                    $selectedIndex = if ($selectedIndex -eq 0) { $scaffoldTargets.Count - 1 } else { $selectedIndex - 1 }
                }
                "DownArrow" {
                    $selectedIndex = if ($selectedIndex -eq $scaffoldTargets.Count - 1) { 0 } else { $selectedIndex + 1 }
                }
                "Enter" {
                    [Console]::CursorVisible = $true
                    Clear-Host

                    $target = $scaffoldTargets[$selectedIndex]
                    Write-Host "Scaffolding: $($target.Label)..." -ForegroundColor Green
                    Write-Host "Project: $($target.ProjectFolder)" -ForegroundColor Gray
                    Write-Host ""

                    Push-Location -Path $target.ProjectFolder
                    try {
                        dotnet ef dbcontext scaffold $target.ConnectionString Microsoft.EntityFrameworkCore.SqlServer --force
                    }
                    finally {
                        Pop-Location
                    }
                    return
                }
                "Escape" {
                    [Console]::CursorVisible = $true
                    Clear-Host
                    return
                }
            }
        }
    }
    finally {
        [Console]::CursorVisible = $true
    }
}

Invoke-BarriDatabaseScaffold
