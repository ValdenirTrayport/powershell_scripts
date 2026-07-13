
Add-Type -Assembly System.IO.Compression.FileSystem
#Add-Type -AssemblyName "Microsoft.SqlServer.Smo, Version=12.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" 

#load assemblies
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | Out-Null
#Need SmoExtended for backup
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoExtended") | Out-Null

Try
{
    $DbServerName = $env:ComputerName
    $localDbName = "BusSysHangfire"
    $localDbLogName = $localDbName+"_Log"
    $backupfileLocation = '\\isbackups\Backups\IS\SQL Backups\is-sql14ag-def\IS-SQL14GC-DEF$IS-SQL14AG-DEF\BusSysHangfire\FULL'
    $moveToFileLocation = "C:\Program Files\Microsoft SQL Server\MSSQL12.MSSQLSERVER\MSSQL\DATA"
    $backupFileLocal = 'C:\'

    $LatestTrayInvoiceBackupFile = Get-ChildItem -Path $backupfileLocation -Filter "*.bak" | Sort CreationTime -Descending | Select -First 1 -ErrorAction Stop
    $LatestTrayInvoiceBackupFileLocation = Join-Path -Path $backupfileLocation -ChildPath $LatestTrayInvoiceBackupFile
    $LocalTrayInvoiceBackupFile = Join-Path -Path $backupFileLocal -ChildPath $LatestTrayInvoiceBackupFile

    $RelocateData = New-Object Microsoft.SqlServer.Management.Smo.RelocateFile($localDbName, "C:\Program Files\Microsoft SQL Server\MSSQL12.MSSQLSERVER\MSSQL\DATA\$localDbName.mdf") -ErrorAction Stop
    $RelocateLog = New-Object Microsoft.SqlServer.Management.Smo.RelocateFile($localDbLogName, "C:\Program Files\Microsoft SQL Server\MSSQL12.MSSQLSERVER\MSSQL\DATA\$localDbName.ldf") -ErrorAction Stop

    Write-Host "Restoring database $localDbName"

    Write-Host "....Copying database backup file to local file system"
    Copy-Item -Path $LatestTrayInvoiceBackupFileLocation -Destination $LocalTrayInvoiceBackupFile -ErrorAction Stop
        
    Write-Host "....Creating server object"
    $smo = New-Object Microsoft.SqlServer.Management.Smo.Server $DbServerName -ErrorAction Stop

    Write-Host "....Killing database processes"
    $smo.KillAllProcesses($localDbName)

    Write-Host "....Executing restore"
    Restore-SqlDatabase -ServerInstance $DbServerName -Database $localDbName -BackupFile $LocalTrayInvoiceBackupFile -ReplaceDatabase -RelocateFile @($RelocateData,$RelocateLog) -ErrorAction Stop

    Write-Host "Removing database backup file from local file system"
    Remove-Item $LocalTrayInvoiceBackupFile -ErrorAction Stop
}
Catch
{
    Write-Host "There has been an error executing your script."

    Write-Host "....Removing database backup file from local file system"
	Remove-Item $LocalTrayInvoiceBackupFile -ErrorAction Stop

    Write-Host $_.Exception.Message
    Write-Host $_.Exception.ItemName
    Read-Host
}