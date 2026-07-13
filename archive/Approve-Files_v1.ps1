# =============================================================================
# 1. Configuration Variables
# =============================================================================
$approvalTestsPath = "C:\dev\BusinessSystems.Barri\Barri.ApprovalTests\ApprovedFiles"
$verifyTestsPath   = "C:\dev\BusinessSystems.Barri\Tests\Trayport.Barri.SnapshotTests\_VerifiedFiles"
$winMergePath      = "C:\Program Files\WinMerge\WinMergeU.exe"

# =============================================================================
# Core Logic & Reusable Function
# =============================================================================
function Manage-SnapshotDirectory {
    param (
        [Parameter(Mandatory=$true)]
        [string]$TargetDirectory,
        
        [Parameter(Mandatory=$true)]
        [string]$TargetSuffix,
        
        [Parameter(Mandatory=$true)]
        [string]$WinMergePath
    )

    # Validate if target directory exists before running
    if (-not (Test-Path -Path $TargetDirectory -PathType Container)) {
        Write-Host "Error: The target directory '$TargetDirectory' does not exist." -ForegroundColor Red
        Read-Host "Press Enter to return to the main menu..."
        return
    }

    # 3. Sub-Menu Loop (Numbered File List)
    while ($true) {
        Clear-Host
        Write-Host "==================================================" -ForegroundColor Cyan
        Write-Host "  PENDING SNAPSHOTS IN: $TargetDirectory"            -ForegroundColor Cyan
        Write-Host "  (Analyzing text content instantly...)"             -ForegroundColor Cyan
        Write-Host "==================================================" -ForegroundColor Cyan

        # Recursively scan directory for files ending in received.txt
        $files = Get-ChildItem -Path $TargetDirectory -Filter "*received.txt" -Recurse -File -ErrorAction SilentlyContinue
        
        # Track identical files for the batch approval feature
        $identicalFiles = [System.Collections.Generic.List[object]]::new()

        if ($files.Count -eq 0) {
            Write-Host "No pending 'received.txt' files found!" -ForegroundColor Green
        } else {
            for ($i = 0; $i -lt $files.Count; $i++) {
                $currentFile = $files[$i]
                $expectedPath = $currentFile.FullName -replace 'received\.txt$', $TargetSuffix
                
                $isIdentical = $false
                
                # Smart text-normalization comparison check
                if (Test-Path -Path $expectedPath -PathType Leaf) {
                    try {
                        $textReceived = [System.IO.File]::ReadAllText($currentFile.FullName)
                        $textExpected = [System.IO.File]::ReadAllText($expectedPath)
                        
                        $normReceived = $textReceived.Replace("`r`n", "`n").Trim()
                        $normExpected = $textExpected.Replace("`r`n", "`n").Trim()
                        
                        if ($normReceived -eq $normExpected) {
                            $isIdentical = $true
                            $null = $identicalFiles.Add($currentFile)
                        }
                    } catch {
                        $isIdentical = $false
                    }
                }
                
                # Print the file line item colorized based on status
                if ($isIdentical) {
                    Write-Host "[$($i + 1)] [IDENTICAL] $($currentFile.FullName)" -ForegroundColor Green
                } else {
                    Write-Host "[$($i + 1)] [DIFFERENT] $($currentFile.FullName)" -ForegroundColor Red
                }
            }
        }
        
        Write-Host "--------------------------------------------------" -ForegroundColor Cyan
        
        # Display options side-by-side
        Write-Host "[0] Back to Main Menu" -ForegroundColor Cyan -NoNewline
        if ($identicalFiles.Count -gt 0) {
            Write-Host "    [A] Approve All Identical ($($identicalFiles.Count) files)" -ForegroundColor Green
        } else {
            Write-Host "" # Print newline
        }
        
        Write-Host "==================================================" -ForegroundColor Cyan

        $choice = Read-Host "Select a file number or an action option"
        $choiceClean = $choice.ToUpper().Trim()
        
        # Go back to Main Menu
        if ($choiceClean -eq '0') {
            break
        }

        # Option [A]: Batch Approve All Identical Files
        if ($choiceClean -eq 'A') {
            if ($identicalFiles.Count -eq 0) {
                Write-Host "There are no identical files to approve." -ForegroundColor Red
                Start-Sleep -Seconds 1.5
                continue
            }

            Write-Host "`nApproving $($identicalFiles.Count) identical file(s)..." -ForegroundColor Green
            foreach ($file in $identicalFiles) {
                $expectedPath = $file.FullName -replace 'received\.txt$', $TargetSuffix
                try {
                    Move-Item -Path $file.FullName -Destination $expectedPath -Force -ErrorAction Stop
                    Write-Host "Approved: $($file.Name)" -ForegroundColor Green
                } catch {
                    Write-Host "Error approving $($file.Name): $_" -ForegroundColor Red
                }
            }
            Start-Sleep -Seconds 2
            continue # Refresh the list view
        }

        # Validate file number selection input
        if ($choiceClean -match '^\d+$' -and [int]$choiceClean -ge 1 -and [int]$choiceClean -le $files.Count) {
            $selectedIndex = [int]$choiceClean - 1
            $selectedFile  = $files[$selectedIndex]
            
            # 4. Action Menu Loop (Compare or Approve)
            while ($true) {
                Write-Host "`nSelected File: $($selectedFile.FullName)" -ForegroundColor Cyan
                $action = Read-Host "Do you want to [C]ompare, [A]pprove, or [B]ack to list?"
                $action = $action.ToUpper().Trim()

                # [C] Compare Option - Launches the full WinMerge GUI for manual analysis
                if ($action -eq 'C') {
                    if (-not (Test-Path -Path $WinMergePath -PathType Leaf)) {
                        Write-Host "Error: WinMerge executable not found at '$WinMergePath'." -ForegroundColor Red
                        continue
                    }
                    $expectedPath = $selectedFile.FullName -replace 'received\.txt$', $TargetSuffix
                    Write-Host "Launching WinMerge GUI..." -ForegroundColor Cyan
                    Start-Process -FilePath $WinMergePath -ArgumentList "`"$($selectedFile.FullName)`"", "`"$expectedPath`"" -Wait
                }
                # [A] Approve Option
                elseif ($action -eq 'A') {
                    $expectedPath = $selectedFile.FullName -replace 'received\.txt$', $TargetSuffix
                    try {
                        Move-Item -Path $selectedFile.FullName -Destination $expectedPath -Force -ErrorAction Stop
                        Write-Host "Successfully approved! File converted to $TargetSuffix" -ForegroundColor Green
                        Start-Sleep -Seconds 1
                        break # Break out of Action Menu loop to refresh the Sub-Menu list
                    }
                    catch {
                        Write-Host "Error approving file: $_" -ForegroundColor Red
                    }
                }
                # [B] Back Option
                elseif ($action -eq 'B') {
                    break # Return to the current file list
                }
                else {
                    Write-Host "Invalid option. Please enter C, A, or B." -ForegroundColor Red
                }
            }
        } else {
            Write-Host "Invalid selection. Please enter a valid number or option letter." -ForegroundColor Red
            Start-Sleep -Seconds 1.5
        }
    }
}

# =============================================================================
# Main Menu Loop
# =============================================================================
while ($true) {
    Clear-Host
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "      SNAPSHOT TEST MANAGEMENT MENU      " -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "1. Approval Tests (Target: approved.txt)"  -ForegroundColor Cyan
    Write-Host "2. Verify Tests   (Target: verified.txt)"  -ForegroundColor Cyan
    Write-Host "3. Exit"                                   -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan

    $mainChoice = Read-Host "Please select an option (1-3)"

    switch ($mainChoice) {
        '1' {
            Manage-SnapshotDirectory -TargetDirectory $approvalTestsPath -TargetSuffix "approved.txt" -WinMergePath $winMergePath
        }
        '2' {
            Manage-SnapshotDirectory -TargetDirectory $verifyTestsPath -TargetSuffix "verified.txt" -WinMergePath $winMergePath
        }
        '3' {
            Write-Host "`nExiting script. Goodbye!" -ForegroundColor Green
            exit
        }
        Default {
            Write-Host "Invalid selection. Please enter 1, 2, or 3." -ForegroundColor Red
            Start-Sleep -Seconds 1.5
        }
    }
}