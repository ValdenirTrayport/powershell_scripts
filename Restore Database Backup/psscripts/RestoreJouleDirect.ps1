Import-Module "C:\scripts\Restore Database Backup\psscripts\Common.psm1" -Force

$server = $env:ComputerName
$database = "PROD_AGGREGATION"
$pathThere = '\\files.hq.trayport.com\TMSBACKUPS\Backups\TMS\Environment Backups\Database\SQL-CLU-AGG-10P$SQL-AG-AGG-10P\PROD_AGGREGATION\FULL'

ExecuteStandardRestore -server $server -database $database -pathThere $pathThere