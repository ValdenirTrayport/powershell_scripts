Import-Module "C:\scripts\Restore Database Backup\psscriptsforpsmenu\Common.psm1" -Force

$server = $env:ComputerName
$database = "PROD_AGGREGATION"
$pathThere = '\\tmsbackups.hq.trayport.com\backups\TMS\Environment Backups\Database\DC2-SQL-AGG-01P$AGG01\PROD_AGGREGATION\FULL'

ExecuteStandardRestore -server $server -database $database -pathThere $pathThere