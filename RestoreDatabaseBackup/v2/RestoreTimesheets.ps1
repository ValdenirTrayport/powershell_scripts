Import-Module "C:\scripts\Restore Database Backup\v2\Common.psm1" -Force

$server = $env:ComputerName
$database = "Timesheets"
$pathThere = '\\isbackups\Backups\IS\SQL Backups\is-sql14ag-def\IS-SQL14GC-DEF$IS-SQL14SN-DEF\Timesheets\FULL'

ExecuteStandardRestore -server $server -database $database -pathThere $pathThere
