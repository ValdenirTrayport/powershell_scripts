#
#	This script moves files to a new location while keeping its history
#	Usage:
#		Add this scrript to your system Path
#		Call the script from the folder where the source script is
#
[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$true, HelpMessage="Enter the source file path.")]
    [string]$SourceFilePath,

    [Parameter(Mandatory=$true, HelpMessage="Enter the destination file path.")]
    [string]$DestinationFile
)

cls

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

if ($pscmdlet.shouldcontinue("are you sure you want to move`n$($sourcefile) to`n$($destinationfile)?`n this will unstage any eventual staged files and commit files to your branch.", "confirm move")){

	#this command will unstage everything that might be in the staging area as we need a clean staging area for this operation
	git restore --staged .

	#this command will move the file to its new location, preserving the history
	git mv $sourcefile $destinationfile

	#this will commit the new file
	git commit -m "moved $sourcefile to $destinationfile"

	#this command will restore the original file back to its original location and history
	git checkout head^ -- $sourcefile

	#this command will commit the original file back into the branch
	git commit -m "restored $sourcefile and its history"

}

