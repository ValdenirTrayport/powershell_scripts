[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$SolutionPath,

    [Parameter(Mandatory = $true)]
    [string]$TargetFolderPath
)

# 1. Validation
if (-not (Test-Path $SolutionPath)) {
    Write-Error "Solution file not found: $SolutionPath"
    return
}
if (-not (Test-Path $TargetFolderPath)) {
    Write-Error "Target folder not found: $TargetFolderPath"
    return
}

$SolutionDir = Split-Path -Parent (Resolve-Path $SolutionPath)
$TargetFolderFullName = (Get-Item $TargetFolderPath).FullName
$RootFolderName = (Get-Item $TargetFolderPath).Name

# Validate that the target folder lives inside the solution directory hierarchy
if (-not $TargetFolderFullName.StartsWith($SolutionDir, [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Error "The target folder must reside inside the Solution file's directory tree."
    return
}

# 2. Read Solution Content
$slnContent = [System.IO.File]::ReadAllLines($SolutionPath)

# Solution Folder Type GUID identifier used by Visual Studio
$FolderTypeGuid = "{2150E333-8FDC-42A3-9474-1A3956D46DE8}"

# Track folders we map: Key = Absolute Path, Value = Metadata Custom Object
$FolderMap = @{}

# Look for existing solution folder definitions to preserve or update
Write-Host "Scanning existing solution items..."
for ($i = 0; $i -lt $slnContent.Length; $i++) {
    $line = $slnContent[$i]
    if ($line -match '^Project\("\{2150E333-8FDC-42A3-9474-1A3956D46DE8\}"\) = "([^"]+)", "([^"]+)", "(\{[^"]+\})"') {
        $name = $Matches[1]
        $path = $Matches[2]
        $guid = $Matches[3]
        
        # If it matches our targeted path structure, let's catalog its GUID
        if ($path.StartsWith($RootFolderName) -or $path -eq $RootFolderName) {
            $fullDiskPath = Join-Path $SolutionDir $path
            if (Test-Path $fullDiskPath) {
                $FolderMap[$fullDiskPath] = [PSCustomObject]@{
                    Guid = $guid
                    Name = $name
                    RelativePath = $path
                    IsNew = $false
                    Files = @()
                }
            }
        }
    }
}

# 3. Scan disk and map out structure
Write-Host "Mapping disk files and folders..."
$allDirs = Get-ChildItem -Path $TargetFolderFullName -Directory -Recurse
$dirsToProcess = @((Get-Item $TargetFolderFullName)) + $allDirs

foreach ($dir in $dirsToProcess) {
    $fullPath = $dir.FullName
    $relativePath = $fullPath.Substring($SolutionDir.Length).TrimStart('\')
    
    if (-not $FolderMap.ContainsKey($fullPath)) {
        $FolderMap[$fullPath] = [PSCustomObject]@{
            Guid = ("{" + [Guid]::NewGuid().ToString().ToUpper() + "}")
            Name = $dir.Name
            RelativePath = $relativePath
            IsNew = $true
            Files = @()
        }
    }
    
    # Collect all direct files inside this folder
    $files = Get-ChildItem -Path $fullPath -File
    foreach ($file in $files) {
        $fileRelativePath = $file.FullName.Substring($SolutionDir.Length).TrimStart('\')
        $FolderMap[$fullPath].Files += $fileRelativePath
    }
}

# 4. Construct the New Project Blocks
$NewProjectBlocks = @()
foreach ($key in $FolderMap.Keys) {
    $folder = $FolderMap[$key]
    if ($folder.IsNew) {
        $NewProjectBlocks += "Project(`"$FolderTypeGuid`") = `"$($folder.Name)`", `"$($folder.RelativePath)`", `"$($folder.Guid)`""
        if ($folder.Files.Count -gt 0) {
            $NewProjectBlocks += "`tProjectSection(SolutionItems) = preProject"
            foreach ($file in $folder.Files) {
                $NewProjectBlocks += "`t`t$file = $file"
            }
            $NewProjectBlocks += "`tEndProjectSection"
        }
        $NewProjectBlocks += "EndProject"
    }
}

# 5. Build up clean NestedProjects block
$NestedProjectsLines = @()
foreach ($key in $FolderMap.Keys) {
    $childFolder = $FolderMap[$key]
    $parentPath = Split-Path $key -Parent
    
    if ($FolderMap.ContainsKey($parentPath)) {
        $parentFolder = $FolderMap[$parentPath]
        $NestedProjectsLines += "`t`t$($childFolder.Guid) = $($parentFolder.Guid)"
    }
}

# 6. Reconstruct the Solution File safely
$OutputLines = @()
$inNestedProjects = $false
$nestedProjectsFound = $false

# Scrub older definitions of these targeted items out first to avoid corruption duplicates
$skipLine = $false
$inTargetedProjectBlock = $false

for ($i = 0; $i -lt $slnContent.Length; $i++) {
    $line = $slnContent[$i]
    
    # Check if starting an existing targeted project block that we are completely refreshing
    if ($line -match '^Project\("\{2150E333-8FDC-42A3-9474-1A3956D46DE8\}"\)') {
        foreach ($folder in $FolderMap.Values) {
            if ($line -contains $folder.Guid) {
                $inTargetedProjectBlock = $true
                break
            }
        }
    }
    
    if ($inTargetedProjectBlock) {
        if ($line -eq "EndProject") {
            $inTargetedProjectBlock = $false
        }
        continue # Skip writing this obsolete structural line
    }

    # Handle NestedProjects block updates
    if ($line -match 'GlobalSection\(NestedProjects\)\s*=\s*preSolution') {
        $inNestedProjects = $true
        $nestedProjectsFound = $true
        $OutputLines += $line
        continue
    }
    
    if ($inNestedProjects) {
        if ($line -match 'EndGlobalSection') {
            $inNestedProjects = $false
            # Write our new layout nesting instructions out safely inside the block
            foreach ($nestLine in $NestedProjectsLines) {
                $OutputLines += $nestLine
            }
            $OutputLines += $line
        } else {
            # Strip out older folder keys that match our sync directories to rewrite cleanly
            $isOldTargetedNest = $false
            foreach ($folder in $FolderMap.Values) {
                if ($line -match $folder.Guid) { $isOldTargetedNest = $true; break }
            }
            if (-not $isOldTargetedNest) {
                $OutputLines += $line
            }
        }
        continue
    }

    # Standard Line Retention
    if ($line -eq "Global") {
        # Inject our new project definitions directly right before Global configuration begins
        foreach ($blockLine in $NewProjectBlocks) {
            $OutputLines += $blockLine
        }
    }
    
    $OutputLines += $line
}

# Fallback block injection if GlobalSection(NestedProjects) was entirely missing originally
if (-not $nestedProjectsFound -and $NestedProjectsLines.Count -gt 0) {
    # Find insertion index right before the Global End
    $globalEndIndex = $OutputLines.IndexOf("EndGlobal")
    if ($globalEndIndex -gt -1) {
        $fallbackBlock = @(
            "`tGlobalSection(NestedProjects) = preSolution"
        ) + $NestedProjectsLines + @(
            "`tEndGlobalSection"
        )
        $OutputLines.InsertRange($globalEndIndex, $fallbackBlock)
    }
}

# 7. Write out output safely with proper UTF-8 Windows encoding
[System.IO.File]::WriteAllLines($SolutionPath, $OutputLines)
Write-Host "Success! Solution file synced cleanly with physical disk paths." -ForegroundColor Green