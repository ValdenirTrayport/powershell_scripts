Import-Module "C:\scripts\Restore Database Backup\v2\Common.psm1" -Force

$server = $env:ComputerName
$database = "BusSysHangfire"	
$pathThere = '\\files.hq.trayport.com\ISBACKUPS\BACKUPS\IS\SQL Backups\bs-sql-dumps\it-sql-gen-ag$it-sql-gen-ag\BusSysHangfire\FULL_COPY_ONLY'

ExecuteStandardRestore -server $server -database $database -pathThere $pathThere
