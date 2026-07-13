Import-Module "C:\scripts\Restore Database Backup\v2\Common.psm1" -Force

$server = $env:ComputerName
$database = "PROD_REFERENCEDATA"
$pathThere = '\\files.hq.trayport.com\TMSBACKUPS\Backups\TMS\Environment Backups\DataBase\SQL-CLU-MIS-10P$SQL-AG-MIS-10P\PROD_REFERENCEDATA\FULL'

ExecuteStandardRestore -server $server -database $database -pathThere $pathThere
