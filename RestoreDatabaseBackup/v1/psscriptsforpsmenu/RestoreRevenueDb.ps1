$server = $env:ComputerName
$database = "RevenueDb"
$pathThere = '\\files.hq.trayport.com\ISBACKUPS\BACKUPS\IS\SQL Backups\bs-sql-dumps\it-sql-gen-ag$it-sql-gen-ag\RevenueDB\FULL_COPY_ONLY'

ExecuteStandardRestore -server $server -database $database -pathThere $pathThere