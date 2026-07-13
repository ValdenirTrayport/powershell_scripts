Import-Module "C:\scripts\Restore Database Backup\psscripts\Common.psm1" -Force

$server = $env:ComputerName
$database = "Events"
$pathThere = '\\files.hq.trayport.com\ISBACKUPS\BACKUPS\IS\SQL Backups\bs-sql-dumps\it-sql-gen-ag$it-sql-gen-ag\Events\FULL_COPY_ONLY'

ExecuteStandardRestore -server $server -database $database -pathThere $pathThere