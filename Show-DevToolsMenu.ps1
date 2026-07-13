#Requires -Version 5.1
<#
.SYNOPSIS
    Interactive searchable menu for launching DevTools scripts and functions.

.DESCRIPTION
    Displays all available profile functions and standalone scripts in an
    interactive, filterable TUI. Supports keyboard navigation (Up/Down),
    type-to-filter search, and Enter to execute.

.EXAMPLE
    Show-DevToolsMenu
    # Or via alias: MENU
#>
function Show-DevToolsMenu {
    [CmdletBinding()]
    param()

    # Define menu entries: Label (what user sees) and Action (scriptblock to invoke)
    $menuItems = @(
        @{ Label = "Set-BarriLocation";          Description = "Navigate to Barri project folder";         Action = { Set-Location -Path "C:\dev\BusinessSystems.Barri" } }
        @{ Label = "Restore-Barri";              Description = "Run the local DB restoration script";      Action = { & 'C:\dev\BusinessSystems.Barri\Deployment Scripts\LocalDev\RestoreBarriSanitized.ps1' } }
        @{ Label = "Invoke-BarriMigration";      Description = "Run Barri database migrations (Flyway)";   Action = { & 'C:\scripts\Invoke-BarriMigration.ps1' } }
        @{ Label = "Invoke-BarriResetAndMigrate"; Description = "Full DB reset (Restore + Migrate)";       Action = { & 'C:\dev\BusinessSystems.Barri\Deployment Scripts\LocalDev\RestoreBarriSanitized.ps1'; & 'C:\scripts\Invoke-BarriMigration.ps1' } }
        @{ Label = "Invoke-BarriScaffold";       Description = "Launch EF scaffolding in VS context";      Action = { Invoke-BarriScaffold } }
        @{ Label = "Update-Repos";               Description = "Scan all repos in C:\dev and pull";        Action = { & 'C:\scripts\Update-Repos.ps1' } }
        @{ Label = "Invoke-MonitoringMigration"; Description = "Run monitoring database migrations";       Action = { & 'C:\scripts\Invoke-MonitoringMigration.ps1' } }
        @{ Label = "Sync-ConfigBackup";          Description = "Backup or restore config files";           Action = { & 'C:\scripts\Sync-ConfigBackup.ps1' -Operation Restore } }
        @{ Label = "Get-InvoicePeriod";          Description = "Query invoice periods by year";            Action = { $y = Read-Host "Enter 2-digit year (e.g. 25 for 2025)"; if ($y -match '^\d{1,2}$') { Get-InvoicePeriod -Year ([int]$y) } else { Write-Host "Invalid year." -ForegroundColor Red } } }
        @{ Label = "Move-GitFileWithHistory";    Description = "Batch move files preserving git history";  Action = { $s = Read-Host "Source file path"; $d = Read-Host "Destination path"; if ($s -and $d) { & 'C:\scripts\Move-GitFileWithHistory.ps1' -SourceFilePath $s -DestinationFile $d } } }
        @{ Label = "Backup-Script";              Description = "Archive and version a script";             Action = { & 'C:\scripts\Backup-Script.ps1' } }
        @{ Label = "Approve-SnapshotTestFile";   Description = "Manage snapshot test approvals";           Action = { & 'C:\scripts\Approve-SnapshotTestFile.ps1' } }
        @{ Label = "Build-BarriSolution";        Description = "Full rebuild of Barri solution";           Action = { & 'C:\scripts\Build-BarriSolution.ps1' } }
        @{ Label = "Clear-BarriHangfire";        Description = "Clear Hangfire job tables locally";        Action = { & 'C:\scripts\Clear-BarriHangfire.ps1' } }
        @{ Label = "Restore-Database";           Description = "Interactive DB restore menu";              Action = { & 'C:\scripts\Restore-Database.ps1' } }
        @{ Label = "Get-BackupFileReport";       Description = "Report .bak files and disk usage";         Action = { & 'C:\scripts\Get-BackupFileReport.ps1' } }
        @{ Label = "Invoke-IndexAutomation";     Description = "Deploy/rollback performance indexes";      Action = { $a = Read-Host "Action (Implement/Revert)"; $e = Read-Host "Environment (Local/Test/Approval/ApprovalSlim)"; if ($a -and $e) { & 'C:\scripts\Invoke-IndexAutomation.ps1' -Action $a -Environment $e } } }
        @{ Label = "Reset-BillingPeriod";        Description = "Reset a billing period (Local/Test/Appr)"; Action = { $e = Read-Host "Environment (Local/Test/Approval)"; $p = Read-Host "PeriodID"; if ($e -and $p -match '^\d+$') { & 'C:\scripts\Reset-BillingPeriod.ps1' -Environment $e -PeriodID ([int]$p) } else { Write-Host "Invalid input." -ForegroundColor Red } } }
        @{ Label = "Install-DotNetHosting";      Description = "Deploy .NET Hosting Bundle to servers";    Action = { & 'C:\scripts\Install-DotNetHosting.ps1' } }
        @{ Label = "Get-DotNetServerVersion";    Description = "Query .NET versions on remote servers";    Action = { & 'C:\scripts\Get-DotNetServerVersion.ps1' } }
        @{ Label = "Import-SqlScript";           Description = "Import a large SQL file via sqlcmd";       Action = { $f = Read-Host "Full path to SQL file"; if ($f -and (Test-Path -LiteralPath $f)) { & 'C:\scripts\Import-SqlScript.ps1' -FilePath $f } else { Write-Host "File not found." -ForegroundColor Red } } }
        @{ Label = "Get-ProjectFrameworkVersion"; Description = "Report .NET framework versions from .csproj"; Action = { & 'C:\scripts\Get-ProjectFrameworkVersion.ps1' } }
        @{ Label = "Sync-SolutionFolder";        Description = "Sync folder structure to .sln file";       Action = { $s = Read-Host "Solution file path"; $t = Read-Host "Target folder path"; if ($s -and $t) { & 'C:\scripts\Sync-SolutionFolder.ps1' -SolutionPath $s -TargetFolderPath $t } } }
    )

    $filterText = ""
    $selectedIndex = 0
    [Console]::CursorVisible = $false

    try {
        while ($true) {
            Clear-Host
            Write-Host "=== DevTools Menu ===" -ForegroundColor Yellow
            Write-Host "Type to filter | Up/Down to navigate | Enter to run | Esc to exit" -ForegroundColor Gray
            Write-Host "Search: $filterText" -ForegroundColor Cyan
            Write-Host ("-" * 60)

            # Filter items
            $filtered = @()
            for ($i = 0; $i -lt $menuItems.Count; $i++) {
                $item = $menuItems[$i]
                $displayNum = $i + 1
                if ($item.Label -like "*$filterText*" -or $item.Description -like "*$filterText*" -or $displayNum.ToString() -eq $filterText) {
                    $filtered += [PSCustomObject]@{
                        OriginalIndex = $i
                        Label         = $item.Label
                        Description   = $item.Description
                        Action        = $item.Action
                        DisplayNum    = $displayNum
                    }
                }
            }

            # Bound-check selected index
            if ($selectedIndex -ge $filtered.Count) {
                $selectedIndex = [math]::Max(0, $filtered.Count - 1)
            }

            # Render
            if ($filtered.Count -eq 0) {
                Write-Host "  [No items match your search]" -ForegroundColor Red
            }
            else {
                for ($i = 0; $i -lt $filtered.Count; $i++) {
                    $entry = $filtered[$i]
                    $line = "[{0,2}] {1,-30} {2}" -f $entry.DisplayNum, $entry.Label, $entry.Description

                    if ($i -eq $selectedIndex) {
                        Write-Host " > $line" -ForegroundColor Black -BackgroundColor Cyan
                    }
                    else {
                        Write-Host "   $line"
                    }
                }
            }

            # Handle keyboard input
            $keyInfo = [Console]::ReadKey($true)

            switch ($keyInfo.Key) {
                "UpArrow" {
                    if ($filtered.Count -gt 0) {
                        $selectedIndex = if ($selectedIndex -eq 0) { $filtered.Count - 1 } else { $selectedIndex - 1 }
                    }
                }
                "DownArrow" {
                    if ($filtered.Count -gt 0) {
                        $selectedIndex = if ($selectedIndex -eq $filtered.Count - 1) { 0 } else { $selectedIndex + 1 }
                    }
                }
                "Enter" {
                    if ($filtered.Count -gt 0) {
                        [Console]::CursorVisible = $true
                        Clear-Host
                        Write-Host "Executing: $($filtered[$selectedIndex].Label)...`n" -ForegroundColor Green
                        & $filtered[$selectedIndex].Action
                        return
                    }
                }
                "Backspace" {
                    if ($filterText.Length -gt 0) {
                        $filterText = $filterText.Substring(0, $filterText.Length - 1)
                        $selectedIndex = 0
                    }
                }
                "Escape" {
                    [Console]::CursorVisible = $true
                    Clear-Host
                    return
                }
                Default {
                    if (-not [char]::IsControl($keyInfo.KeyChar)) {
                        $filterText += $keyInfo.KeyChar
                        $selectedIndex = 0
                    }
                }
            }
        }
    }
    finally {
        [Console]::CursorVisible = $true
    }
}
