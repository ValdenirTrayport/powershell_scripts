#Requires -Version 5.1
<#
.SYNOPSIS
    Reports on .bak database backup files found in specified directories.

.DESCRIPTION
    Scans target directories recursively for .bak files, displays a sorted report
    by size, and outputs summary totals per folder.

.PARAMETER Path
    One or more directory paths to scan. Defaults to C:\dev and C:\DatabaseLocalBackups.

.EXAMPLE
    .\Get-BackupFileReport.ps1

.EXAMPLE
    .\Get-BackupFileReport.ps1 -Path "D:\Backups"
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string[]]$Path = @("C:\dev", "C:\DatabaseLocalBackups")
)

foreach ($targetPath in $Path) {
    if (-not (Test-Path -LiteralPath $targetPath)) {
        Write-Warning "Path not found: $targetPath"
        continue
    }

    Write-Host "`n--- Checking Folder: $targetPath ---" -ForegroundColor Cyan

    $files = Get-ChildItem -LiteralPath $targetPath -Filter "*.bak" -Recurse -File -ErrorAction SilentlyContinue

    if ($files) {
        $files | Select-Object Name,
            @{Name="Size(MB)"; Expression={[math]::Round($_.Length / 1MB, 2)}},
            @{Name="LastModified"; Expression={$_.LastWriteTime}} |
            Sort-Object "Size(MB)" -Descending |
            Format-Table -AutoSize

        $totalSizeBytes = ($files | Measure-Object -Property Length -Sum).Sum
        $totalGB = [math]::Round($totalSizeBytes / 1GB, 2)
        Write-Host ">> Total for ${targetPath}: $totalGB GB ($($files.Count) files)" -ForegroundColor Yellow
    }
    else {
        Write-Host "No .bak files found in $targetPath." -ForegroundColor Gray
    }
}