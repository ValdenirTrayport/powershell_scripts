Import-Module "C:\scripts\Restore Database Backup\v2\Common.psm1" -Force

$server = $env:ComputerName
$database = "TCMSOrionDashboard"	
$localFolder = "Monitoring"
$fileThere = '\\BS-TSQL16-IT\Database Backups\TCMSOrionDashboard_DevTest.bak'

if(ExecuteFixedPathRestore -server $server -localFolder $localFolder -database $database -fileThere $fileThere -eq $TRUE){

	Write-Host "....Enabling Service Broker"
	Invoke-Sqlcmd -Query "ALTER DATABASE $database SET ENABLE_BROKER;" -ServerInstance $server -TrustServerCertificate
	
	TruncateTable -server $server -database $database -table "PerformanceApiSnapshots"
	ShrinkDatabase -server $server -database $database
}
