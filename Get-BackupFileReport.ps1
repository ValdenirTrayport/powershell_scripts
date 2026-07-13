# 1. Define your collection of paths here
$targetPaths = @("C:\dev", "C:\DatabaseLocalBackups")

foreach ($path in $targetPaths) {
    if (Test-Path $path) {
        Write-Host "`n--- Checking Folder: $path ---" -ForegroundColor Cyan
        
        # 2. Get all .bak files in this specific directory
        $files = Get-ChildItem $path -Filter "*.bak" -Recurse -File -ErrorAction SilentlyContinue
        
        if ($files) {
            # 3. Create a list of individual files sorted by size
            $fileReport = $files | Select-Object Name, 
                @{Name="Size(MB)"; Expression={[math]::Round($_.Length / 1MB, 2)}},
                @{Name="LastModified"; Expression={$_.LastWriteTime}} | 
                Sort-Object "Size(MB)" -Descending

            # Display the individual files
            $fileReport | Format-Table -AutoSize

            # 4. Calculate and display the total for THIS folder
            $totalSizeBytes = ($files | Measure-Object -Property Length -Sum).Sum
            $totalGB = [math]::Round($totalSizeBytes / 1GB, 2)
            
            Write-Host ">> Total for $path`: $totalGB GB ($($files.Count) files)" -ForegroundColor Yellow
        }
        else {
            Write-Host "No .bak files found in $path." -ForegroundColor Gray
        }
    }
    else {
        Write-Warning "Path not found: $path"
    }
}