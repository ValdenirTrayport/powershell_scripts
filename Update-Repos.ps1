#Requires -Version 5.1
<#
.SYNOPSIS
    Scans all repositories in C:\dev and pulls the latest from main/master.

.DESCRIPTION
    Iterates through all first-level directories under C:\dev, checks out the
    default branch (main or master), backs up modified config files, cleans
    .vs folders, and performs a fetch + rebase. Non-git directories are
    automatically added to an exclusion list.

.EXAMPLE
    .\Update-Repos.ps1
#>
[CmdletBinding()]
param()

# Configuration
$targetDir = "C:\dev"
# Places the specific exclusion file name in the same directory as this script
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
    return
}

# Track whether the backup script has been executed during this run
$backupExecuted = $false

# Lists to collect data for the final summary
$failedPendingChanges = @()
$failedBranchCheckout = @()
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
        
        # 2. Handle Pending Changes Evaluator
        if ($gitStatus) {
            $hasVsFolder = $false
            $hasConfigFiles = $false
            $filesToClean = @()

            foreach ($line in $gitStatus) {
                if ($line.Length -gt 3) {
                    # Extract status code (e.g., '??', ' M', 'M ') and relative path
                    $statusCode = $line.Substring(0, 2)
                    $relPath = $line.Substring(3).Trim('"')
                    
                    # Check if pending changes include .vs folder
                    if ($relPath -like ".vs/*" -or $relPath -eq ".vs" -or $relPath -like "*/.vs/*") {
                        $hasVsFolder = $true
                    }

                    # Check for specific configuration files
                    $isConfig = $false
                    if ($relPath -like "*Debug.config" -or $relPath -like "*Development.json") {
                        $isConfig = $true
                    }
                    # Web.config conditional rule
                    elseif ($relPath -like "*Web.config" -and $dir.FullName -like "*\BusinessSystems.Monitoring\MonitoringDashboard\*") {
                        $isConfig = $true
                    }

                    if ($isConfig) {
                        $hasConfigFiles = $true
                        # Keep track of path and status type
                        $filesToClean += [PSCustomObject]@{
                            RelPath    = $relPath
                            StatusCode = $statusCode
                        }
                    }
                }
            }

            # Action: Delete .vs folder if found
            if ($hasVsFolder) {
                $vsPath = Join-Path $dir.FullName ".vs"
                if (Test-Path $vsPath) {
                    Write-Host "  [.vs folder found] Deleting .vs directory in '$($dir.Name)'..." -ForegroundColor Gray
                    Remove-Item -Path $vsPath -Recurse -Force -ErrorAction SilentlyContinue
                }
            }

            # Action: Backup and clean target config files if found
            if ($hasConfigFiles) {
                # Only run the backup script if it hasn't run yet during this script execution
                if (-not $backupExecuted) {
                    Write-Host "  [Config files found] Backing up configurations for '$($dir.Name)'..." -ForegroundColor Cyan
                    
                    # Run the backup script synchronously and silently in the background
                    & "C:\scripts\Sync-ConfigBackup.ps1" -Operation Backup *>$null
                    
                    # Set flag to true so it skips running this script again for subsequent repos
                    $backupExecuted = $true
                }
                else {
                    Write-Host "  [Config files found] Backup already executed previously. Skipping backup script..." -ForegroundColor Gray
                }
                
                # Clean up target files depending on whether they are tracked or untracked
                foreach ($file in $filesToClean) {
                    if ($file.StatusCode -eq "??") {
                        # Untracked file: safely delete it from disk
                        $normalizedPath = $file.RelPath -replace '/', '\'
                        $fullPath = Join-Path $dir.FullName $normalizedPath
                        if (Test-Path $fullPath) {
                            Write-Host "  Deleting untracked configuration file: $(Split-Path $fullPath -Leaf)" -ForegroundColor Gray
                            Remove-Item -Path $fullPath -Force -ErrorAction SilentlyContinue
                        }
                    }
                    else {
                        # Tracked file: Discard staged or unstaged local changes via Git checkout HEAD
                        Write-Host "  Discarding local modifications to tracked file: $($file.RelPath)" -ForegroundColor Gray
                        git -C $dir.FullName checkout HEAD -- $file.RelPath 2>$null
                    }
                }
            }

            # Re-check git status after cleanups to see if we can now proceed
            $gitStatus = git -C $dir.FullName status --porcelain
            if ($gitStatus) {
                # If there are still unrelated pending changes remaining, fail and move to next repo
                $failedPendingChanges += $dir.Name
                continue
            }
        }
        
        # Try to checkout main. Fallback to master if main doesn't exist.
        Write-Host "Processing Git repo: $($dir.Name)" -ForegroundColor Cyan
        
        git -C $dir.FullName checkout main 2>$null
        if ($LASTEXITCODE -ne 0) {
            # 'main' failed, attempt 'master' fallback
            git -C $dir.FullName checkout master 2>$null
            if ($LASTEXITCODE -ne 0) {
                # Both failed, collect for final summary and skip repo
                $failedBranchCheckout += $dir.Name
                continue
            }
        }
        
        # Run fetch and rebase (executed on whichever branch successfully checked out)
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

# 2. Folders that failed branch checkout (MAGENTA)
if ($failedBranchCheckout.Count -gt 0) {
    Write-Host "`n[!] FAILED TO CHECKOUT DEFAULT BRANCH:" -ForegroundColor Magenta
    foreach ($folder in $failedBranchCheckout) {
        Write-Host "    WARNING: Skipping '$folder': Neither 'main' nor 'master' branches exist." -ForegroundColor Magenta
    }
}

# 3. Folders skipped because they were already excluded (GRAY)
if ($skippedExclusions.Count -gt 0) {
    Write-Host "`n[-] ALREADY IN EXCLUSION LIST:" -ForegroundColor Gray
    foreach ($folder in $skippedExclusions) {
        Write-Host "    Skipping '$folder' (In exclusion list)" -ForegroundColor Gray
    }
}

# 4. Folders newly added to the exclusion list (YELLOW)
if ($newlyExcluded.Count -gt 0) {
    Write-Host "`n[+] NEWLY ADDED TO EXCLUSION LIST (NOT GIT REPOS):" -ForegroundColor Yellow
    foreach ($folder in $newlyExcluded) {
        Write-Host "    '$folder' is not a Git repository. Added to exclusions." -ForegroundColor Yellow
    }
}

Write-Host "`n==========================================" -ForegroundColor White