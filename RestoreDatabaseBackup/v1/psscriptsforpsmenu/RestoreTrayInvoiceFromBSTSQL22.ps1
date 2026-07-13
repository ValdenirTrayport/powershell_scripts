Import-Module "C:\scripts\Restore Database Backup\psscriptsforpsmenu\Common.psm1" -Force

$server = $env:ComputerName
$sourceServer = "BS_TSQL22"
$database = "TRAYINVOICE"    
$pathThere = '\\kaizar\users\Valdenir.Filho\SQL_Backup\'
$backupFile = "$pathThere'TrayinvoiceFromTestServer.bak"
$AppSettingsSqlScriptFilePath = "\\files.hq.trayport.com\kaizar\Operations\itsm\Business Systems\Scripts\Restore Database Backup\psscripts\$server\AppSettings.sql"

RestoreDatabase([string]$sourceServer, [string]$databaseName, [string]$backupFile)

if(ExecuteStandardRestore -server $server -database $database -pathThere $pathThere -eq $TRUE){
	Write-Host "Executing AppSettings script"
	Invoke-Sqlcmd -InputFile $AppSettingsSqlScriptFilePath -ServerInstance $server -ErrorAction Stop -TrustServerCertificate
		
	TruncateTable -server $server -database $database -table "Log"
	
	ShrinkDatabase -server $server -database $database
}