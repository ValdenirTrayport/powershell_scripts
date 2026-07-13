# Configuration
$targetDir = "C:\dev"
# Places the exclusion file in the same directory as this script
$exclusionFile = Join-Path $PSScriptRoot "Update-Repos-Exclusion-List.txt"

# Create the exclusion file if it doesn't exist yet
if (-not (Test-Path $exclusionFile)) {
    New-Item -Path $exclusionFile -ItemType File -Force | Out-Null
}

# Read exclusion list, remove empty lines, and trim whitespace
$exclusions = @()
if (Test-Path $exclusionFile) {
    $exclusions = Get-Content $exclusionFile | Where-Object { $_.Trim() -ne "" } | ForEach-Object { $_.Trim() }
}

# Ensure the target directory exists
if (-not (Test-Path $targetDir)) {
    Write-Error "Target directory '$targetDir' does not exist."
    exit
}

# Lists to collect data for the final summary
$failedPendingChanges = @()
$skippedExclusions = @()
$newlyExcluded = @()

# Get all first-level directories only
$directories = Get-ChildItem -Path $targetDir -Directory
$totalDirs = $directories.Count
$currentDirIndex = 0

foreach ($dir in $directories) {
    $currentDirIndex++
    # Calculate percentage for the progress bar
    $percentComplete = [int](($currentDirIndex / $totalDirs) * 100)
    
    # Display the progress bar at the top of the console
    Write-Progress -Activity "Updating C:\dev Repositories" `
                   -Status "Processing folder: $($dir.Name) ($currentDirIndex of $totalDirs)" `
                   -PercentComplete $percentComplete

    # 1. Check if the folder name is in the exclusion list
    if ($exclusions -contains $dir.Name) {
        $skippedExclusions += $dir.Name
        continue
    }

    $gitPath = Join-Path $dir.FullName ".git"

    # Check if it's a Git repository
    if (Test-Path $gitPath) {
        
        # Check for pending changes (staged, unstaged, or untracked changes)
        $gitStatus = git -C $dir.FullName status --porcelain
        
        # 2. Check if it has pending changes
        if ($gitStatus) {
            $failedPendingChanges += $dir.Name
            continue
        }
        
        # Try to checkout main
        Write-Host "Processing Git repo: $($dir.Name)" -ForegroundColor Cyan
        git -C $dir.FullName checkout main 2>$null
        if ($LASTEXITCODE -ne 0) {			
			git -C $dir.FullName checkout master 2>$null
			if ($LASTEXITCODE -ne 0) {			
				Write-Warning "Could not checkout branch in '$($dir.Name)'. Coult not find either main or master."
				continue
			}
        }
        
        # Run fetch and rebase
        Write-Host "  Fetching updates..." -ForegroundColor Gray
        git -C $dir.FullName fetch
        
        Write-Host "  Rebasing..." -ForegroundColor Gray
        git -C $dir.FullName rebase
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Successfully updated '$($dir.Name)'" -ForegroundColor Green
        } else {
            Write-Error "Failed to rebase '$($dir.Name)'. You may need to resolve conflicts manually."
        }
    }
    # 3. Not a git repo: Add to exclusion list
    else {
        Add-Content -Path $exclusionFile -Value $dir.Name
        $exclusions += $dir.Name # Update array for this execution
        $newlyExcluded += $dir.Name
    }
}

# Explicitly clear the progress bar when finished
Write-Progress -Activity "Updating C:\dev Repositories" -Completed
Write-Host "`nFinished processing directories." -ForegroundColor Green


# ==========================================
#              FINAL SUMMARY
# ==========================================
Write-Host "`n==========================================" -ForegroundColor White
Write-Host "            EXECUTION SUMMARY             " -ForegroundColor White
Write-Host "==========================================" -ForegroundColor White

# 1. Folders that failed due to pending changes (RED)
if ($failedPendingChanges.Count -gt 0) {
    Write-Host "`n[!] FAILED DUE TO PENDING CHANGES:" -ForegroundColor Red
    foreach ($folder in $failedPendingChanges) {
        Write-Host "    WARNING: Skipping '$folder': Pending changes prevent checkout and rebase." -ForegroundColor Red
    }
}

# 2. Folders skipped because they were already excluded (GRAY)
if ($skippedExclusions.Count -gt 0) {
    Write-Host "`n[-] ALREADY IN EXCLUSION LIST:" -ForegroundColor Gray
    foreach ($folder in $skippedExclusions) {
        Write-Host "    Skipping '$folder' (In exclusion list)" -ForegroundColor Gray
    }
}

# 3. Folders newly added to the exclusion list (YELLOW)
if ($newlyExcluded.Count -gt 0) {
    Write-Host "`n[+] NEWLY ADDED TO EXCLUSION LIST (NOT GIT REPOS):" -ForegroundColor Yellow
    foreach ($folder in $newlyExcluded) {
        Write-Host "    '$folder' is not a Git repository. Added to exclusions." -ForegroundColor Yellow
    }
}

Write-Host "`n==========================================" -ForegroundColor White