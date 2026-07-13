#Requires -Version 5.1
<#
.SYNOPSIS
    Archives and versions scripts from C:\scripts into C:\scripts\archive.

.DESCRIPTION
    Displays available scripts in a multi-column format, prompts for selection,
    then creates a versioned copy (e.g. script_v3.ps1) in the archive folder.
    Duplicate detection via MD5 hash prevents redundant versions.

.EXAMPLE
    .\Backup-Script.ps1
#>
[CmdletBinding()]
param()

$sourceDir  = $PSScriptRoot
$archiveDir = Join-Path -Path $PSScriptRoot -ChildPath "archive"

# Ensure the archive directory exists
if (-not (Test-Path $archiveDir)) {
    New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null
    Write-Host "Created archive directory at $archiveDir" -ForegroundColor Cyan
}

# Get all files non-recursively (excluding the archive folder itself if it was a file, though it's a dir)
$files = Get-ChildItem -Path $sourceDir -File

if ($files.Count -eq 0) {
    Write-Host "No files found in $sourceDir." -ForegroundColor Yellow
    return
}

Write-Host "`n Available Scripts in $sourceDir :`n" -ForegroundColor Cyan

# --- Multi-column display logic ---
$colCount = 3
$rowCount = [math]::Ceiling($files.Count / $colCount)

for ($r = 0; $r -lt $rowCount; $r++) {
    $line = ""
    for ($c = 0; $c -lt $colCount; $c++) {
        $index = ($r * $colCount) + $c
        if ($index -lt $files.Count) {
            $num = $index + 1
            # Truncate very long filenames for neat columns
            $name = $files[$index].Name
            if ($name.Length -gt 28) { $name = $name.Substring(0, 25) + "..." }
            
            $str = "[{0,2}] {1}" -f $num, $name
            $line += "{0,-35}" -f $str
        }
    }
    Write-Host $line -ForegroundColor White
}

Write-Host ""
$selection = Read-Host "Enter the number of the script to archive (or press Enter to cancel)"

# Validate input
if ([string]::IsNullOrWhiteSpace($selection) -or $selection -notmatch '^\d+$' -or [int]$selection -lt 1 -or [int]$selection -gt $files.Count) {
    Write-Warning "Operation cancelled or invalid selection."
    return
}

# Get the selected file
$selectedFile = $files[[int]$selection - 1]
$baseName = $selectedFile.BaseName
$extension = $selectedFile.Extension

Write-Host "`nProcessing '$($selectedFile.Name)'..." -ForegroundColor Cyan

# Define temporary copy path
$tempCopyPath = Join-Path $archiveDir $selectedFile.Name

# Step 1: Copy file to archive
Copy-Item -Path $selectedFile.FullName -Destination $tempCopyPath -Force

# Step 2: Check for existing versions and compare content
$existingVersions = Get-ChildItem -Path $archiveDir -Filter "$baseName`_v*$extension" -File
$isDuplicate = $false
$duplicateVersionName = ""

# Hash the file we just copied for comparison
$selectedHash = (Get-FileHash -Path $tempCopyPath -Algorithm MD5).Hash

foreach ($version in $existingVersions) {
    $versionHash = (Get-FileHash -Path $version.FullName -Algorithm MD5).Hash
    
    if ($selectedHash -eq $versionHash) {
        $isDuplicate = $true
        $duplicateVersionName = $version.Name
        break
    }
}

# Step 3 & 4: Handle Match or Rename
if ($isDuplicate) {
    # If content matches an existing version, delete the copy and warn
    Remove-Item -Path $tempCopyPath -Force
    Write-Host "[WARNING] Content is identical to existing version '$duplicateVersionName'. Archiving aborted, file cleaned up." -ForegroundColor Yellow
} else {
    # If no match, find the highest version number
    $maxVersion = 0
    foreach ($version in $existingVersions) {
        # Extract the version number using Regex (e.g., matching "_v12")
        if ($version.BaseName -match "_v(\d+)$") {
            $vNum = [int]$matches[1]
            if ($vNum -gt $maxVersion) {
                $maxVersion = $vNum
            }
        }
    }

    # Increment version
    $nextVersion = $maxVersion + 1
    $newFileName = "${baseName}_v${nextVersion}${extension}"
    $newFilePath = Join-Path $archiveDir $newFileName

    # Rename the file
    Rename-Item -Path $tempCopyPath -NewName $newFileName

    Write-Host "[SUCCESS] File uniquely archived as '$newFileName'." -ForegroundColor Green
}