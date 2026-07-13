#Requires -Version 5.1
<#
.SYNOPSIS
    Moves a file to a new location while preserving its full Git history.

.DESCRIPTION
    Uses a two-commit strategy to move a file and then restore the original,
    ensuring both locations retain the complete commit history.

.PARAMETER SourceFilePath
    The path of the source file to move.

.PARAMETER DestinationFile
    The destination file path or directory.

.EXAMPLE
    .\Move-GitFileWithHistory.ps1 -SourceFilePath "src\OldFile.cs" -DestinationFile "src\NewFolder\"
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, HelpMessage = "Enter the source file path.")]
    [string]$SourceFilePath,

    [Parameter(Mandatory, HelpMessage = "Enter the destination file path.")]
    [string]$DestinationFile
)

$ErrorActionPreference = 'Stop'

$SourceFileDirectory = Split-Path -Path $SourceFilePath -Parent
Set-Location -Path $SourceFileDirectory

$SourceFile = Split-Path -Path $SourceFilePath -Leaf

If(Test-Path -Path $DestinationFile -PathType Container){
	#create path if it does not exist
	New-Item -ItemType Directory -Path $DestinationFile -ErrorAction SilentlyContinue
	#concatenate filename to $DestinationFile
	$DestinationFile = [System.IO.Path]::Combine($DestinationFile, $SourceFile)
}

Write-Host "Moving $SourceFile to $DestinationFile and keeping history"

if ($PSCmdlet.ShouldProcess($SourceFile, "Move to $DestinationFile (preserving git history)")) {

	# Unstage any staged files — we need a clean staging area
	git restore --staged .

	# Move the file preserving history
	git mv $SourceFile $DestinationFile

	# Commit the move
	git commit -m "moved $SourceFile to $DestinationFile"

	# Restore the original file back
	git checkout HEAD^ -- $SourceFile

	# Commit the restoration
	git commit -m "restored $SourceFile and its history"
}

