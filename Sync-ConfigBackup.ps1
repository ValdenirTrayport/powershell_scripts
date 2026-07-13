# This file backs up or restores config files to/from a storage folder
param(    
    [ValidateSet('Backup', 'Restore')]
    [string]$Operation
)

$sourceRoot = "C:\dev"
$destinationRoot = "\\files.hq.trayport.com\kaizar\users\Valdenir.Filho\trayport\environment\config-files-repository"

# If $Operation is Restore, flip paths so the remaining logic maps seamlessly
if ($Operation -eq 'Restore') {
    $tempRoot = $sourceRoot
    $sourceRoot = $destinationRoot
    $destinationRoot = $tempRoot
}

# Define targets. 'Web.config' is filtered explicitly inside the loop for precision.
$includePatterns = @('*.Debug.config', '*.Development.json', 'Web.config')

Get-ChildItem -Path $sourceRoot -File -Recurse -Include $includePatterns | ForEach-Object {
    $fullName = $_.FullName

    # 1. Explicit path filter for Web.config to prevent pulling untargeted files
    if ($_.Name -eq 'Web.config' -and -not $fullName.Contains('\BusinessSystems.Monitoring\MonitoringDashboard\')) {
        return # Skip
    }

    # 2. Extract the relative path from the current root to normalize Backup vs Restore operations
    $relativePath = $fullName.Substring($sourceRoot.Length).TrimStart('\')

    # 3. Apply exclusions using standard Windows backslashes BEFORE making any changes to disk
    if ($relativePath -like "learn\*" -or $relativePath -like "*\learn\*" -or
        $relativePath -like "*\bin\*" -or $relativePath -like "*\obj\*") {
        return # Skip safely
    }

    # 4. Construct the target path safely using native path utilities instead of string manipulation
    $targetPath = Join-Path -Path $destinationRoot -ChildPath $relativePath
    $targetFolder = Split-Path -Path $targetPath -Parent

    # 5. Performance optimization: Only create directory structures if they don't already exist
    if (-not (Test-Path -Path $targetFolder)) {
        New-Item -ItemType Directory -Force -Path $targetFolder | Out-Null
    }

    # 6. Execute file copy
    Write-Host "Copying $($fullName) to`n$($targetPath) `n" -NoNewLine
    Copy-Item -Path $fullName -Destination $targetPath -Force
    Write-Host "Done!`n"
}