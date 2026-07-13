$scriptDir = "C:\scripts\Restore Database Backup\v2"
$modulePath = Join-Path $scriptDir "Common.psm1"

if (Test-Path $modulePath) {
    # Import with Global scope so child scripts can see the functions
    Import-Module $modulePath -Scope Global -Force 
    Write-Host "✅ Common Module Loaded" -ForegroundColor Green
} else {
    Write-Host "❌ Critical Error: Common.psm1 not found at $modulePath" -ForegroundColor Red
    Pause
    exit
}

Function Show-Menu {
    Clear-Host
    $destPath = (Get-Module Common).Invoke({ $DESTINATION_PATH })
    $files = @(Get-ChildItem -Path $destPath -File -Recurse -ErrorAction SilentlyContinue)
    $totalBytes = [int64](($files | Measure-Object -Property Length -Sum).Sum)

    Clear-Host
    Write-Host "**********************************************" -ForegroundColor Cyan
    Write-Host "* 🚀     DATABASE RESTORE AUTOMATION v2      *" -ForegroundColor White -BackgroundColor DarkBlue
    Write-Host "**********************************************" -ForegroundColor Cyan
    Write-Host " [A] Analysis Data       [B] Barri"
    Write-Host " [H] BusSysHangfire      [E] EmaTradeData"
    Write-Host " [V] Events              [X] ExchangeData"
    Write-Host " [J] Joule Direct        [F] ReferenceData"
	Write-Host " [R] RevenueDb           [S] ScheduledJobs"
    Write-Host " [N] ServiceNowMonitor   [M] TCMS RefData"
    Write-Host " [U] UserAnalysis"
    Write-Host " [D] Disk Maintenance    [Q] Quit"
    Write-Host "**********************************************" -ForegroundColor Cyan
    Write-Host (" Status: {0} file(s) | {1} bytes" -f $files.Count, ("{0:N0}" -f $totalBytes)) -ForegroundColor Gray
    Write-Host "**********************************************" -ForegroundColor Cyan
}

Function Show-DiskMaintenance {
    $destPath = (Get-Module Common).Invoke({ $DESTINATION_PATH })

    do {
        Clear-Host
        Write-Host "********************************************" -ForegroundColor Cyan
        Write-Host "* 🗄️      DISK MAINTENANCE                 *" -ForegroundColor White -BackgroundColor DarkBlue
        Write-Host "* Path: $destPath" -ForegroundColor Gray
        Write-Host "********************************************" -ForegroundColor Cyan

        $files = @(Get-ChildItem -Path $destPath -File -Recurse -ErrorAction SilentlyContinue)

        if ($files.Count -eq 0) {
            Write-Host "  (no files found)" -ForegroundColor DarkGray
        } else {
            for ($i = 0; $i -lt $files.Count; $i++) {
                $size = "{0:N2} MB" -f ($files[$i].Length / 1MB)
                $relativePath = $files[$i].FullName.Substring($destPath.TrimEnd('\\').Length).TrimStart('\\')
                Write-Host " [$($i + 1)] $relativePath  ($size)"
            }
        }

        Write-Host "--------------------------------------------" -ForegroundColor Cyan
        Write-Host " [A] Delete all files"
        Write-Host " [B] Back to main menu"
        Write-Host "--------------------------------------------" -ForegroundColor Cyan

        $pick = (Read-Host "Select an option").ToLower()

        if ($pick -eq 'b') {
            break
        } elseif ($pick -eq 'a') {
            if ($files.Count -eq 0) {
                Write-Host "  Nothing to delete." -ForegroundColor Yellow
                Start-Sleep -Seconds 1
            } else {
                $confirm = Read-Host "⚠️  Delete all $($files.Count) file(s)? (Y/N)"
                if ($confirm.ToLower() -eq 'y') {
                    $files | Remove-Item -Force
                    Write-Host "✅ All files deleted." -ForegroundColor Green
                    Start-Sleep -Seconds 1
                }
            }
        } elseif ($pick -match '^\d+$') {
            $idx = [int]$pick - 1
            if ($idx -ge 0 -and $idx -lt $files.Count) {
                $relativePath = $files[$idx].FullName.Substring($destPath.TrimEnd('\\').Length).TrimStart('\\')
                $confirm = Read-Host "⚠️  Delete '$relativePath'? (Y/N)"
                if ($confirm.ToLower() -eq 'y') {
                    Remove-Item -Path $files[$idx].FullName -Force
                    Write-Host "✅ Deleted '$relativePath'." -ForegroundColor Green
                    Start-Sleep -Seconds 1
                }
            } else {
                Write-Host "  Invalid selection." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    } while ($true)
}

# ENFORCE NO-ADMIN RULE 
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "❌ FATAL ERROR: This script cannot be run with privileges." -ForegroundColor Red
    Pause
    exit
}

$dbMap = @{
    'a' = "RestoreAnalysisData"
    'h' = "BusSysHangfire"
    'e' = "RestoreEmaTradeData"
    'v' = "RestoreEvents"
    'x' = "RestoreExchangeData"
    'j' = "RestoreJouleDirect"
	'f' = "RestoreReferenceData"
    'r' = "RestoreRevenueDb"
    's' = "RestoreScheduledJobs"
    'm' = "RestoreTCMSRefData"
    'u' = "RestoreUserAnalysis"
    'n' = "RestoreServiceNowMonitor"
}

do {
    Show-Menu
    $input = Read-Host "Select an option"
    $choice = $input.ToLower()

    if ($choice -eq 'd') {
        Show-DiskMaintenance
    } elseif ($choice -eq 'b') {
        # Special case for Barri
        $fullPath = "C:\dev\BusinessSystems.Barri\Deployment Scripts\LocalDev\RestoreBarriSanitized.ps1"
        if (Test-Path $fullPath) {
            Write-Host "🛠 Running RestoreBarriSanitized.ps1..." -ForegroundColor Yellow
            & $fullPath
            Write-Host "`nDone." -ForegroundColor Green
        } else {
            Write-Host "❌ Error: Could not find script at $fullPath" -ForegroundColor Red
        }
        $confirm = Read-Host "Restore another? (Y/N)" 
        if ($confirm.ToLower() -ne 'y') { break }
    } elseif ($dbMap.ContainsKey($choice)) {
        $scriptName = "$($dbMap[$choice]).ps1"
        $fullPath = Join-Path -Path $scriptDir -ChildPath $scriptName
        Write-Host "🛠 Running $scriptName..." -ForegroundColor Yellow
        & $fullPath
        Write-Host "`nDone." -ForegroundColor Green
        $confirm = Read-Host "Restore another? (Y/N)" 
        if ($confirm.ToLower() -ne 'y') { break }
    }
} while ($choice -ne 'q')

Clear-Host