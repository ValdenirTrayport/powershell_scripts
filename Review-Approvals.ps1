# Configuration Paths
$TargetDirectory = "C:\dev\BusinessSystems.Barri\Barri.ApprovalTests\ApprovedFiles"
$AppVLP = "C:\Program Files\Microsoft Office\root\Client\AppVLP.exe"
$SpreadsheetCompare = "C:\Program Files\Microsoft Office\root\vfs\ProgramFilesX86\Microsoft Office\Office16\DCF\SPREADSHEETCOMPARE.EXE"
$TempTxtFile = Join-Path $env:TEMP "excel_diff_list.txt"

# Ensure target directory exists
if (-not (Test-Path $TargetDirectory)) {
    Write-Host "Error: Target directory does not exist: $TargetDirectory" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit
}

while ($true) {
    Clear-Host
    Write-Host "Scanning for Approval Test Files...`n" -ForegroundColor Cyan

    # Find all received files recursively
    $ReceivedFiles = Get-ChildItem -Path $TargetDirectory -Filter "*.received.xlsx" -Recurse

    # Match them up with approved files
    $Pairs = @()
    $Index = 1

    foreach ($RecFile in $ReceivedFiles) {
        $AppFilePath = $RecFile.FullName -replace '\.received\.xlsx$', '.approved.xlsx'
        
        if (Test-Path $AppFilePath) {
            # Discard the .received.xlsx extension for display as requested
            $CleanName = $RecFile.FullName -replace '\.received\.xlsx$', ''
            
            $Pairs += [PSCustomObject]@{
                Number       = $Index
                File         = $CleanName
                ApprovedPath = $AppFilePath
                ReceivedPath = $RecFile.FullName
            }
            $Index++
        }
    }

    # IF NO FILES FOUND: Inform user and exit
    if ($Pairs.Count -eq 0) {
        Write-Host "--------------------------------------------------" -ForegroundColor Green
        Write-Host "The folder is clean! No files to review." -ForegroundColor Green
        Write-Host "--------------------------------------------------" -ForegroundColor Green
        Read-Host "Press Enter to finish the script"
        break
    }

    # DISPLAY TABLE
    Write-Host "Files requiring review:" -ForegroundColor Yellow
    $Pairs | Format-Table Number, File -AutoSize

    # SELECT FILE
    $Selection = Read-Host "Enter the NUMBER of the file to manage (or 'q' to quit)"
    if ($Selection -eq 'q') { break }

    $SelectedPair = $Pairs | Where-Object { $_.Number -eq $Selection }

    if (-not $SelectedPair) {
        Write-Host "Invalid selection. Press Enter to try again." -ForegroundColor Red
        Read-Host
        continue
    }

    # DISPLAY MENU OPTIONS
    Write-Host "`nSelected: $($SelectedPair.File)" -ForegroundColor Cyan
    Write-Host "1. Compare" -ForegroundColor White
    Write-Host "2. Approve" -ForegroundColor White
    $Action = Read-Host "Choose an option (1 or 2)"

    # OPTION 1: COMPARE
    if ($Action -eq "1" -or $Action -eq "compare") {
        Write-Host "Launching Spreadsheet Compare..." -ForegroundColor Yellow
        
        # Write paths to temp file with clean ASCII encoding for Spreadsheet Compare
        $FilePathsForTool = @($SelectedPair.ApprovedPath, $SelectedPair.ReceivedPath)
        Set-Content -Path $TempTxtFile -Value $FilePathsForTool -Encoding Ascii
        
        # Execute via AppVLP virtual wrapper
        & $AppVLP $SpreadsheetCompare $TempTxtFile
        
        Write-Host "Comparison window spawned. Press Enter to return to the menu."
        Read-Host
    }
    # OPTION 2: APPROVE
    elseif ($Action -eq "2" -or $Action -eq "approve") {
        Write-Host "Approving change..." -ForegroundColor Yellow
        
        try {
            # Delete approved file
            Remove-Item -Path $SelectedPair.ApprovedPath -Force
            
            # Rename received file to approved file
            $ApprovedLeafName = Split-Path $SelectedPair.ApprovedPath -Leaf
            Rename-Item -Path $SelectedPair.ReceivedPath -NewName $ApprovedLeafName
            
            Write-Host "Success! File approved and updated." -ForegroundColor Green
        }
        catch {
            Write-Host "Error during file operations: $_" -ForegroundColor Red
        }
        
        Write-Host "Press Enter to refresh list."
        Read-Host
    }
    else {
        Write-Host "Invalid option selection. Press Enter to try again." -ForegroundColor Red
        Read-Host
    }
}