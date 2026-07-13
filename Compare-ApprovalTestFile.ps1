# Define the target directory to scan
$targetDir = "C:\dev\BusinessSystems.Barri\Barri.ApprovalTests\ApprovedFiles"

# Define the path to the WinMerge executable
# (Checks standard 64-bit and 32-bit install locations)
$winMergePath = "C:\Program Files\WinMerge\WinMergeU.exe"
if (-not (Test-Path $winMergePath)) {
    $winMergePath = "C:\Program Files (x86)\WinMerge\WinMergeU.exe"
}

# Verify WinMerge was found
if (-not (Test-Path $winMergePath)) {
    Write-Warning "WinMerge executable not found at standard locations. Please update the `$winMergePath variable manually."
    exit
}

# Find all files ending in .received.txt, searching subfolders recursively
$receivedFiles = Get-ChildItem -Path $targetDir -Filter "*.received.txt" -Recurse

if ($receivedFiles.Count -eq 0) {
    Write-Host "No .received.txt files found in $targetDir." -ForegroundColor Green
    exit
}

Write-Host "Found $($receivedFiles.Count) received file(s). Launching WinMerge..." -ForegroundColor Cyan

foreach ($receivedFile in $receivedFiles) {
    # Generate the expected path for the matching .approved.txt file
    $approvedFileName = $receivedFile.Name -replace '\.received\.txt$', '.approved.txt'
    $approvedFilePath = Join-Path -Path $receivedFile.DirectoryName -ChildPath $approvedFileName

    # Check if the matching approved file actually exists
    if (Test-Path $approvedFilePath) {
        Write-Host "Comparing: $approvedFileName <--> $($receivedFile.Name)"
        
        # Launch WinMerge with the two files
        # The approved file is placed on the left, received on the right
        $arguments = "`"$approvedFilePath`" `"$($receivedFile.FullName)`""
        
        # Note: If you want the script to pause and wait for you to close WinMerge 
        # before opening the next pair, add '-Wait' to the command below.
        Start-Process -FilePath $winMergePath -ArgumentList $arguments
    }
    else {
        # If there is no approved file yet (e.g., a brand new test)
        Write-Host "No matching .approved.txt found for: $($receivedFile.Name) (This might be a new test)" -ForegroundColor Yellow
        
        # Optional: You can still open WinMerge with just the received file if you want to inspect it
        # Start-Process -FilePath $winMergePath -ArgumentList "`"$($receivedFile.FullName)`""
    }
}

Write-Host "Done." -ForegroundColor Green