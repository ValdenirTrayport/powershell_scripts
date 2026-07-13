# 1. Configuration & Input
$InputFile = Read-Host "Paste the full path to your 1.4GB SQL script"
$InputFile = $InputFile.Replace('"', '') 

if (Test-Path $InputFile) {
    $Server = "." 
    $LogFile = "$PSScriptRoot\import_errors.log"

    Write-Host "`n[SYSTEM] Starting Massive Data Import (v1.9.0 Engine)..." -ForegroundColor Cyan
    Write-Host "[INFO] Auto-detecting Encoding (UTF-16 LE BOM supported)"
    Write-Host "[INFO] Errors only mode enabled."
    Write-Host "------------------------------------------------"

    # 2. Start the Timer
    $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    # 3. Execute v1.9.0 SQLCMD
    # -S: Server
    # -i: Input File
    # -b: Exit on error
    # -m 1: This is the 'Quiet' flag (Severity 1 and above only)
    # -x: Disables variable substitution (Stops JSON $(...) from crashing)
    # -r 1: Redirects messages to stderr
    sqlcmd -S . -i "$InputFile" -x -b -m 1 -r 1 2> "$LogFile"

    # 4. Stop the Timer
    $Stopwatch.Stop()
    $Time = $Stopwatch.Elapsed

    # 5. Result Logic
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n[SUCCESS] Import finished successfully!" -ForegroundColor Green
    } else {
        Write-Host "`n[FAILED] The import stopped. Check the log: $LogFile" -ForegroundColor Red
        # Show the actual SQL error from the log
        Get-Content $LogFile -TotalCount 10 | Write-Host -ForegroundColor Gray
    }

    Write-Host "Total Execution Time: $($Time.Hours)h $($Time.Minutes)m $($Time.Seconds)s"
} else {
    Write-Host "`n[ERROR] File not found." -ForegroundColor Red
}

Read-Host "`nPress Enter to exit"