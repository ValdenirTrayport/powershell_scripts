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
    Write-Host " [A] Analysis Data       [B] BusSysHangfire"
    Write-Host " [E] EmaTradeData        [V] Events"
    Write-Host " [X] ExchangeData        [J] Joule Direct"
    Write-Host " [R] RevenueDb           [S] ScheduledJobs"
    Write-Host " [T] TrayInvoice         [2] TrayInvoice (22)"
    Write-Host " [M] TCMS RefData        [U] UserAnalysis"
    Write-Host " [N] ServiceNowMonitor   [D] Disk Maintenance"
    Write-Host " [Q] Quit"
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
    'b' = "BusSysHangfire"
    'e' = "RestoreEmaTradeData"
    'v' = "RestoreEvents"
    'x' = "RestoreExchangeData"
    'j' = "RestoreJouleDirect"
    'r' = "RestoreRevenueDb"
    's' = "RestoreScheduledJobs"
    't' = "RestoreTrayInvoice"
    '2' = "RestoreTrayInvoiceFromBSTSQL22"
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
