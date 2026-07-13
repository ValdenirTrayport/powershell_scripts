# 1. Ask the user for the file path
$InputFile = Read-Host "Enter the full path to your SQL script (e.g., C:\Scripts\Backup.sql)"

# Clean up any quotes the user might have accidentally included in the copy-paste
$InputFile = $InputFile.Replace('"', '')

# 2. Verify the file exists before starting
if (Test-Path $InputFile) {
    $Server = "."
    $Database = "MyDatabaseName"

    Write-Host "`n--- Starting Database Import ---" -ForegroundColor Cyan
    Write-Host "File: $InputFile"
    Write-Host "Target: $Database on $Server"
    Write-Host "Time Started: $(Get-Date -Format 'HH:mm:ss')"
    Write-Host "--------------------------------"

    # 3. Start the Stopwatch
    $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    # 4. Execute the SQL Command
    # -a 32767: Larger packet size
    # -b: Terminate and return error if a batch fails
    sqlcmd -S $Server -i $InputFile -a 32767 -b

    # 5. Stop the Timer
    $Stopwatch.Stop()

    # 6. Display Results
    $Time = $Stopwatch.Elapsed
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n[SUCCESS] Import Complete!" -ForegroundColor Green
    } else {
        Write-Host "`n[ERROR] The import encountered an issue (Exit Code: $LASTEXITCODE)." -ForegroundColor Red
    }
    
    Write-Host "Total Execution Time: $($Time.Hours)h $($Time.Minutes)m $($Time.Seconds).$($Time.Milliseconds)s"
} else {
    Write-Host "`n[ERROR] File not found at: $InputFile" -ForegroundColor Red
    Write-Host "Please check the path and try again."
}

# Keep the window open so you can see the final time
Read-Host "`nPress Enter to exit"