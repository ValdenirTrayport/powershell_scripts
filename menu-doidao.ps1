function Show-SearchableMenu {
    param (
        [string]$Title = "Script Launcher",
        [array]$Scripts = @()
    )

    $filterText = ""
    $selectedIndex = 0
    [Console]::CursorVisible = $false

    while ($true) {
        Clear-Host
        Write-Host "=== $Title ===" -ForegroundColor Yellow
        Write-Host "Type to filter | Up/Down to navigate | Enter to execute | Esc to exit" -ForegroundColor Gray
        Write-Host "Search: $filterText" -ForegroundColor Cyan
        Write-Host ("-" * 30)

        # 1. Filter items based on what has been typed so far (matches text OR the original number)
        $filteredItems = @()
        for ($i = 0; $i -lt $Scripts.Count; $i++) {
            $displayNumber = $i + 1
            $itemText = $Scripts[$i]
            
            # Match if search text is found in the script name OR the item number
            if ($itemText -like "*$filterText*" -or $displayNumber.ToString() -eq $filterText) {
                # Store the original index so we know what to run later
                $filteredItems += ,[PSCustomObject]@{ OriginalIndex = $i; Name = $itemText; DisplayNum = $displayNumber }
            }
        }

        # Bound-check the selected index so it doesn't break if the list shrinks
        if ($selectedIndex -ge $filteredItems.Count) { 
            $selectedIndex = [math]::Max(0, $filteredItems.Count - 1) 
        }

        # 2. Render the filtered menu
        if ($filteredItems.Count -eq 0) {
            Write-Host "  [No scripts match your search]" -ForegroundColor Red
        } else {
            for ($i = 0; $i -lt $filteredItems.Count; $i++) {
                $item = $filteredItems[$i]
                $line = " [$($item.DisplayNum)] $($item.Name)"

                if ($i -eq $selectedIndex) {
                    Write-Host " > $line " -ForegroundColor Black -BackgroundColor Cyan
                } else {
                    Write-Host "   $line"
                }
            }
        }

        # 3. Handle Keyboard Input
        $keyInfo = [Console]::ReadKey($true)

        switch ($keyInfo.Key) {
            "UpArrow" {
                if ($filteredItems.Count -gt 0) {
                    $selectedIndex = if ($selectedIndex -eq 0) { $filteredItems.Count - 1 } else { $selectedIndex - 1 }
                }
            }
            "DownArrow" {
                if ($filteredItems.Count -gt 0) {
                    $selectedIndex = if ($selectedIndex -eq $filteredItems.Count - 1) { 0 } else { $selectedIndex + 1 }
                }
            }
            "Enter" {
                if ($filteredItems.Count -gt 0) {
                    [Console]::CursorVisible = $true
                    # Return the original script name
                    return $Scripts[$filteredItems[$selectedIndex].OriginalIndex]
                }
            }
            "Backspace" {
                if ($filterText.Length -gt 0) {
                    $filterText = $filterText.Substring(0, $filterText.Length - 1)
                    $selectedIndex = 0 # Reset selection to top on change
                }
            }
            "Escape" {
                [Console]::CursorVisible = $true
                return $null
            }
            Default {
                # If it's a normal printable character or digit, append to search
                if (-not [char]::IsControl($keyInfo.KeyChar)) {
                    $filterText += $keyInfo.KeyChar
                    $selectedIndex = 0 # Reset selection to top on change
                }
            }
        }
    }
}

# --- Demo Usage ---
# Replace this list with your actual script names or file paths
$myScripts = @(
    "Backup-Database.ps1",
    "Check-ServerHealth.ps1",
    "Deploy-ToStaging.ps1",
    "Generate-UserReport.ps1",
    "Optimize-DiskSpace.ps1",
    "Restart-IISPool.ps1",
    "Update-ActiveDirectory.ps1"
)

$selectedScript = Show-SearchableMenu -Title "DevOps Automation Panel" -Scripts $myScripts

# Execute selection
Clear-Host
if ($selectedScript) {
    Write-Host "Executing: $selectedScript..." -ForegroundColor Green
    # To actually run it, you would use: & "C:\path\to\scripts\$selectedScript"
} else {
    Write-Host "Menu cancelled." -ForegroundColor Yellow
}