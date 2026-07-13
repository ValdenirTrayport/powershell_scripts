#Requires -Version 7.0
<#
.SYNOPSIS
    Interactive manager for reviewing and approving snapshot / approval test files.

.DESCRIPTION
    Scans the approval and verify test directories for pending '*.received.*'
    snapshot files, compares each against its approved/verified baseline, and lets
    the operator approve them individually or in bulk.

      - Text snapshots are compared using line-ending-normalised content matching.
      - Excel snapshots are compared using MD5 file hashing (Excel files are
        binary archives, so a hash is the fastest reliable identity check).

    Bulk approvals always require explicit confirmation before any files are moved.

.NOTES
    Target environment : PowerShell 7+ (Core)
    Author role        : PowerShell Automation Specialist
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# =============================================================================
# 1. Configuration
# =============================================================================
$approvalTestsPath      = "C:\dev\BusinessSystems.Barri\Barri.ApprovalTests\ApprovedFiles"
$verifyTestsPath        = "C:\dev\BusinessSystems.Barri\Tests\Trayport.Barri.SnapshotTests\_VerifiedFiles"
$winMergePath           = "C:\Program Files\WinMerge\WinMergeU.exe"
# Standard path for Office 365 / Office 2016 Professional Plus
$spreadsheetComparePath = "C:\Program Files\Microsoft Office\root\vfs\ProgramFilesX86\Microsoft Office\Office16\DCF\SPREADSHEETCOMPARE.EXE"
$appVLPPath             = "C:\Program Files\Microsoft Office\root\Client\AppVLP.exe"

# Excel extensions are compared via hashing instead of text normalisation.
$script:ExcelExtensions = @('.xlsx', '.xls', '.xlsm', '.xlsb')

# =============================================================================
# 2. Helper Functions
# =============================================================================
function Get-ExpectedBaselinePath {
    <#
        Rebuilds the expected baseline path from a received snapshot path by
        swapping the '.received' marker for the target action ('approved'/'verified')
        while preserving the original file extension.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][string]$ReceivedPath,
        [Parameter(Mandatory)][string]$Extension,
        [Parameter(Mandatory)][string]$TargetAction
    )

    $escapedExt = [regex]::Escape($Extension)
    return $ReceivedPath -replace "received${escapedExt}$", "$TargetAction$Extension"
}

function Test-SnapshotIdentical {
    <#
        Returns $true when the received file is functionally identical to its
        baseline. Excel files are hashed; text files are compared after
        normalising line endings and trimming surrounding whitespace.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][string]$ReceivedPath,
        [Parameter(Mandatory)][string]$ExpectedPath,
        [Parameter(Mandatory)][string]$Extension
    )

    if (-not (Test-Path -LiteralPath $ExpectedPath -PathType Leaf)) {
        return $false
    }

    try {
        if ($Extension -in $script:ExcelExtensions) {
            $hashReceived = (Get-FileHash -LiteralPath $ReceivedPath -Algorithm MD5).Hash
            $hashExpected = (Get-FileHash -LiteralPath $ExpectedPath -Algorithm MD5).Hash
            return ($hashReceived -eq $hashExpected)
        }

        $normReceived = [System.IO.File]::ReadAllText($ReceivedPath).Replace("`r`n", "`n").Trim()
        $normExpected = [System.IO.File]::ReadAllText($ExpectedPath).Replace("`r`n", "`n").Trim()
        return ($normReceived -eq $normExpected)
    }
    catch {
        return $false
    }
}

function Get-PendingSnapshot {
    <#
        Scans a directory for pending '*.received.*' snapshots and emits a model
        object per file containing its baseline path and comparison status. All
        expensive work (path rebuild + comparison) happens here exactly once.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][string]$TargetDirectory,
        [Parameter(Mandatory)][string]$TargetAction
    )

    $receivedFiles = Get-ChildItem -LiteralPath $TargetDirectory -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '\.received\.(txt|xlsx|xls|xlsm|xlsb)$' }

    foreach ($file in $receivedFiles) {
        $expectedPath   = Get-ExpectedBaselinePath -ReceivedPath $file.FullName -Extension $file.Extension -TargetAction $TargetAction
        $baselineExists = Test-Path -LiteralPath $expectedPath -PathType Leaf

        $isIdentical = $false
        if ($baselineExists) {
            $isIdentical = Test-SnapshotIdentical -ReceivedPath $file.FullName -ExpectedPath $expectedPath -Extension $file.Extension
        }

        [PSCustomObject]@{
            Name           = $file.Name
            FullName       = $file.FullName
            Extension      = $file.Extension
            ExpectedPath   = $expectedPath
            BaselineExists = $baselineExists
            IsIdentical    = $isIdentical
        }
    }
}

function Approve-Snapshot {
    <#
        Promotes a single received file to its baseline location, returning $true
        on success and $false (with a message) on failure.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][string]$ReceivedPath,
        [Parameter(Mandatory)][string]$ExpectedPath,
        [Parameter(Mandatory)][string]$DisplayName
    )

    try {
        Move-Item -LiteralPath $ReceivedPath -Destination $ExpectedPath -Force
        Write-Host "  Approved: $DisplayName" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "  Error approving ${DisplayName}: $_" -ForegroundColor Red
        return $false
    }
}

function Confirm-Action {
    <# Simple Y/N confirmation guard. Returns $true only on an explicit 'Y'. #>
    [CmdletBinding()]
    param ([Parameter(Mandatory)][string]$Message)

    $response = Read-Host "$Message [Y/N]"
    return ($response.Trim().ToUpper() -eq 'Y')
}

function Invoke-FileComparison {
    <#
        Routes a snapshot to the correct diff tool: Microsoft Spreadsheet Compare
        for Excel files, WinMerge for everything else.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][object]$Snapshot,
        [Parameter(Mandatory)][string]$WinMergePath,
        [Parameter(Mandatory)][string]$SpreadsheetComparePath,
        [Parameter(Mandatory)][string]$AppVLPPath
    )

    if (-not $Snapshot.BaselineExists) {
        Write-Host "No baseline exists yet for this snapshot - nothing to compare." -ForegroundColor Yellow
        Start-Sleep -Seconds 1.5
        return
    }

    if ($Snapshot.Extension.ToLower() -in $script:ExcelExtensions) {
        # --- ROUTE TO SPREADSHEET COMPARE ---
        if (-not (Test-Path -LiteralPath $SpreadsheetComparePath -PathType Leaf)) {
            Write-Host "Error: Microsoft Spreadsheet Compare not found at '$SpreadsheetComparePath'." -ForegroundColor Red
            return
        }

        $tempTxtPath = Join-Path -Path $env:TEMP -ChildPath "SpreadsheetCompareArgs_$([Guid]::NewGuid()).txt"
        try {
            # Line 1: received file. Line 2: baseline file.
            [System.IO.File]::WriteAllLines($tempTxtPath, @($Snapshot.FullName, $Snapshot.ExpectedPath))

            Write-Host "Launching Microsoft Spreadsheet Compare GUI..." -ForegroundColor Cyan
            if (Test-Path -LiteralPath $AppVLPPath -PathType Leaf) {
                # Launch within the required Office App-V virtual bubble context.
                Start-Process -FilePath $AppVLPPath -ArgumentList "`"$SpreadsheetComparePath`"", "`"$tempTxtPath`""
            }
            else {
                # Fallback for standalone non-virtual MSI Office installs.
                Start-Process -FilePath $SpreadsheetComparePath -ArgumentList "`"$tempTxtPath`""
            }

            # Give the GUI a moment to draw before returning control to the menu.
            Start-Sleep -Seconds 2
        }
        catch {
            Write-Host "Failed to invoke Spreadsheet Compare process: $_" -ForegroundColor Red
        }
    }
    else {
        # --- FALLBACK TO WINMERGE ---
        if (-not (Test-Path -LiteralPath $WinMergePath -PathType Leaf)) {
            Write-Host "Error: WinMerge executable not found at '$WinMergePath'." -ForegroundColor Red
            return
        }
        Write-Host "Launching WinMerge GUI..." -ForegroundColor Cyan
        Start-Process -FilePath $WinMergePath -ArgumentList "`"$($Snapshot.FullName)`"", "`"$($Snapshot.ExpectedPath)`"" -Wait
    }
}

# =============================================================================
# 3. Core Review Loop
# =============================================================================
function Invoke-SnapshotReview {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][string]$TargetDirectory,
        [Parameter(Mandatory)][string]$TargetAction,
        [Parameter(Mandatory)][string]$WinMergePath,
        [Parameter(Mandatory)][string]$SpreadsheetComparePath,
        [Parameter(Mandatory)][string]$AppVLPPath
    )

    if (-not (Test-Path -LiteralPath $TargetDirectory -PathType Container)) {
        Write-Host "Error: The target directory '$TargetDirectory' does not exist." -ForegroundColor Red
        Read-Host "Press Enter to return to the main menu..."
        return
    }

    # Sub-Menu Loop (Numbered File List)
    while ($true) {
        Clear-Host
        Write-Host "==================================================" -ForegroundColor Cyan
        Write-Host "  PENDING SNAPSHOTS IN: $TargetDirectory"            -ForegroundColor Cyan
        Write-Host "  (Analyzing Text & Excel snapshots instantly...)"   -ForegroundColor Cyan
        Write-Host "==================================================" -ForegroundColor Cyan

        # Build the snapshot model once - all comparisons happen here.
        $snapshots = @(Get-PendingSnapshot -TargetDirectory $TargetDirectory -TargetAction $TargetAction)

        if ($snapshots.Count -eq 0) {
            Write-Host "No pending 'received' snapshot files found!" -ForegroundColor Green
        }
        else {
            # Long, deeply-nested paths just add noise, so each row shows only
            # '...\filename.ext'. The full path is still shown once a file is selected.
            $differentRow = 0

            for ($i = 0; $i -lt $snapshots.Count; $i++) {
                $snap       = $snapshots[$i]
                $displayExt = $snap.Extension.ToUpper().TrimStart('.')
                $displayPath = '...\' + $snap.Name

                if ($snap.IsIdentical) {
                    Write-Host ("[{0}] [IDENTICAL] ({1}) {2}" -f ($i + 1), $displayExt, $displayPath) -ForegroundColor Green
                }
                elseif (-not $snap.BaselineExists) {
                    Write-Host ("[{0}] [NEW]       ({1}) {2}" -f ($i + 1), $displayExt, $displayPath) -ForegroundColor Yellow
                }
                else {
                    # Zebra-stripe the (often numerous) DIFFERENT rows to ease scanning.
                    $diffColor = if ($differentRow % 2 -eq 0) { 'Red' } else { 'White' }
                    $differentRow++
                    Write-Host ("[{0}] [DIFFERENT] ({1}) {2}" -f ($i + 1), $displayExt, $displayPath) -ForegroundColor $diffColor
                }
            }
        }

        Write-Host "--------------------------------------------------" -ForegroundColor Cyan

        # Display actions side-by-side.
        Write-Host "[0] Back to Main Menu" -ForegroundColor Cyan -NoNewline
        if ($snapshots.Count -gt 0) {
            $identicalCount = @($snapshots | Where-Object IsIdentical).Count
            Write-Host "    [A] Approve All Pending ($($snapshots.Count) files, $identicalCount identical)" -ForegroundColor Green
        }
        else {
            Write-Host ""  # newline
        }

        Write-Host "==================================================" -ForegroundColor Cyan

        $choiceClean = (Read-Host "Select a file number or an action option").Trim().ToUpper()

        # [0] Back to Main Menu
        if ($choiceClean -eq '0') {
            break
        }

        # [A] Approve ALL pending snapshots (including DIFFERENT ones).
        if ($choiceClean -eq 'A') {
            if ($snapshots.Count -eq 0) {
                Write-Host "There are no files to approve." -ForegroundColor Red
                Start-Sleep -Seconds 1.5
                continue
            }

            $identicalCount = @($snapshots | Where-Object IsIdentical).Count
            $differentCount = $snapshots.Count - $identicalCount

            Write-Host ""
            Write-Host "You are about to approve ALL $($snapshots.Count) pending snapshot(s):" -ForegroundColor Yellow
            Write-Host "  - $identicalCount identical (safe)" -ForegroundColor Green
            Write-Host "  - $differentCount differ and will OVERWRITE their current baseline" -ForegroundColor Red

            if (-not (Confirm-Action "Proceed with bulk approval?")) {
                Write-Host "Bulk approval cancelled." -ForegroundColor Cyan
                Start-Sleep -Seconds 1
                continue
            }

            Write-Host "`nApproving $($snapshots.Count) file(s)..." -ForegroundColor Green
            foreach ($snap in $snapshots) {
                [void](Approve-Snapshot -ReceivedPath $snap.FullName -ExpectedPath $snap.ExpectedPath -DisplayName $snap.Name)
            }
            Start-Sleep -Seconds 2
            continue
        }

        # File number selection.
        if ($choiceClean -match '^\d+$' -and [int]$choiceClean -ge 1 -and [int]$choiceClean -le $snapshots.Count) {
            $selectedSnapshot = $snapshots[[int]$choiceClean - 1]

            # Action Menu Loop (Compare / Approve / Back)
            while ($true) {
                Write-Host "`nSelected File: $($selectedSnapshot.FullName)" -ForegroundColor Cyan
                $action = (Read-Host "Do you want to [C]ompare, [A]pprove, or [B]ack to list?").Trim().ToUpper()

                switch ($action) {
                    'C' {
                        Invoke-FileComparison -Snapshot $selectedSnapshot -WinMergePath $WinMergePath -SpreadsheetComparePath $SpreadsheetComparePath -AppVLPPath $AppVLPPath
                    }
                    'A' {
                        if (Approve-Snapshot -ReceivedPath $selectedSnapshot.FullName -ExpectedPath $selectedSnapshot.ExpectedPath -DisplayName $selectedSnapshot.Name) {
                            Start-Sleep -Seconds 1
                        }
                        break
                    }
                    'B' {
                        break
                    }
                    Default {
                        Write-Host "Invalid option. Please enter C, A, or B." -ForegroundColor Red
                    }
                }

                if ($action -in @('A', 'B')) { break }
            }
        }
        else {
            Write-Host "Invalid selection. Please enter a valid number or option letter." -ForegroundColor Red
            Start-Sleep -Seconds 1.5
        }
    }
}

# =============================================================================
# 4. Main Menu Loop
# =============================================================================
while ($true) {
    Clear-Host
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "      SNAPSHOT TEST MANAGEMENT MENU      " -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "1. Approval Tests (Targets: approved.*)"   -ForegroundColor Cyan
    Write-Host "2. Verify Tests   (Targets: verified.*)"   -ForegroundColor Cyan
    Write-Host "3. Exit"                                   -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan

    $mainChoice = Read-Host "Please select an option (1-3)"

    switch ($mainChoice) {
        '1' {
            Invoke-SnapshotReview -TargetDirectory $approvalTestsPath -TargetAction "approved" -WinMergePath $winMergePath -SpreadsheetComparePath $spreadsheetComparePath -AppVLPPath $appVLPPath
        }
        '2' {
            Invoke-SnapshotReview -TargetDirectory $verifyTestsPath -TargetAction "verified" -WinMergePath $winMergePath -SpreadsheetComparePath $spreadsheetComparePath -AppVLPPath $appVLPPath
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