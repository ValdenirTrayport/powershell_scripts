
Import-Module "C:\scripts\Restore Database Backup\psscripts\Common.psm1" -Force


$server = $env:ComputerName
$database = "TRAYINVOICE"    
$pathThere = '\\files.hq.trayport.com\ISBACKUPS\BACKUPS\IS\SQL Backups\bs-sql-dumps\it-sql-gen-ag$it-sql-gen-ag\TRAYINVOICE\FULL_COPY_ONLY'

$AppSettingsSqlScriptFilePath = "C:\My BusinessSystems\Restore Database Backup\psscripts\$server\AppSettings.sql"
$AppSettingsSqlScriptFilePath = "C:\dev\BusinessSystems.Barri\Deployment Scripts\LocalDev\DEVLAP67.sql"

$EmailResetSqlScriptFilePath = "\\files.hq.trayport.com\kaizar\Operations\itsm\Business Systems\Scripts\BARRI\DevTestUpdateEmailAddresses.sql"


$locations = GetDefaultDatabaseFilePath -ServerName $server


write-host 'Default File Locations' 
write-host '======================' 
write-host 'File Location :' $locations.DatabasePath
write-host 'Log Location :' $locations.LogPath
write-host 'Backup Location :' $locations.BackupPath
write-host ''

#$result = ExecuteFixedPathRestore -server $server -localFolder "Barri" -database $database -pathThere $pathThere
#$result = $true

#Write-Host $result

if(ExecuteStandardRestore -server $server -database $database -pathThere $pathThere -eq $TRUE){
	
	Write-Host "Sleeping for 40 seconds"
	Start-Sleep -Seconds 40

	Write-Host "Executing AppSettings script"
	Invoke-Sqlcmd -InputFile $AppSettingsSqlScriptFilePath -ServerInstance $server -ErrorAction Stop -TrustServerCertificate
	
	#Update these calls with new clear text passwords as they get added to Barri
	PopulatePassword -PasswordId 113565 -AppSettingName "CrmClientSecret" -ServerInstance $server -Database $database
	PopulatePassword -PasswordId 127497 -AppSettingName "ClimateWebScreenDataCollectionClientSecret" -ServerInstance $server -Database $database
		
    #Execute Change Emails script
    Invoke-Sqlcmd -InputFile $EmailResetSqlScriptFilePath -ServerInstance $server -ErrorAction Stop -TrustServerCertificate
		
	TruncateTable -server $server -database $database -table "Log"
	
	ShrinkDatabase -server $server -database $database
}




if($result -eq $true){
		
	Write-Host "Executing AppSettings script"
	Invoke-Sqlcmd -InputFile $AppSettingsSqlScriptFilePath -ServerInstance $server -ErrorAction Stop -TrustServerCertificate
		
    #Execute Change Emails script
    Invoke-Sqlcmd -InputFile $EmailResetSqlScriptFilePath -ServerInstance $server -ErrorAction Stop -TrustServerCertificate
		
	TruncateTable -server $server -database $database -table "Log"
	
	ShrinkDatabase -server $server -database $database
}
