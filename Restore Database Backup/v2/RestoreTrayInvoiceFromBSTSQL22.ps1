Import-Module "C:\scripts\Restore Database Backup\v2\Common.psm1" -Force

$server = $env:ComputerName
$database = "TRAYINVOICE"    
$pathThere = '\\kaizar\users\Valdenir.Filho\SQL_Backup\'
$fileThere = Join-Path $pathThere "TrayinvoiceFromTestServer.bak"
$AppSettingsSqlScriptFilePath = "\\files.hq.trayport.com\kaizar\Operations\itsm\Business Systems\Scripts\Restore Database Backup\psscripts\$server\AppSettings.sql"

if(ExecuteFixedPathRestore -server $server -localFolder "TrayInvoice22" -database $database -fileThere $fileThere -eq $TRUE){
	Write-Host "Executing AppSettings script"
	Invoke-Sqlcmd -InputFile $AppSettingsSqlScriptFilePath -ServerInstance $server -ErrorAction Stop -TrustServerCertificate
		
	TruncateTable -server $server -database $database -table "Log"
	ShrinkDatabase -server $server -database $database
}
