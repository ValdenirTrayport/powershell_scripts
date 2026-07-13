#This file backs up or restores config files to/from a storage folder
param(    
    [ValidateSet('Backup', 'Restore')]
    [string]$Operation
)

$sourceRoot = "C:\dev" #Development folder where development code lives
$destinationRoot = "\\files.hq.trayport.com\kaizar\users\Valdenir.Filho\trayport\environment\config-files-repository" #Local folder or file share where backup files will be stored

#If $Operation is Restore, it flips the paths so a Backup operation automatically becomes Restore
if($Operation -eq 'Restore'){
	$tempRoot = $sourceRoot
	$sourceRoot = $destinationRoot
	$destinationRoot = $tempRoot
}

#Copies all debugging config/appsettings recursively from the source to destination
Get-ChildItem -Path $sourceRoot `
			-File `
			-Recurse `
			-Include *.Debug.config,*.Development.json,*\BusinessSystems.Monitoring\MonitoringDashboard\Web.config `
			| foreach{
                if($_.FullName.Contains('C:\dev\learn')){continue}
				$remotePath = $_.FullName.Replace($sourceRoot, $destinationRoot)
				$remotePathWithoutFile = $remotePath.Replace($_.Name, "")
				New-Item -ItemType Directory -Force $remotePathWithoutFile				
				If((Test-Path -Path $remotePathWithoutFile) -eq $true -and `
				   $remotePathWithoutFile.Contains("/bin/") -eq $false -and `
				   $remotePathWithoutFile.Contains("/obj/") -eq $false){
					Write-Host "Copying $($_.FullName) to`n$($remotePath) `n" -NoNewLine
					Copy-Item -Path $_.FullName -Destination $remotePath -Force
					Write-Host "Done!`n"
				}
			}