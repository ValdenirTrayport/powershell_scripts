# Simplified dependency loading for Common.psm1
Try {
    Import-Module SqlServer -Force -ErrorAction Stop
    # Allow the SqlServer module to provide SMO; no need for manual Add-Type/LoadWithPartialName
} Catch {
    Write-Host "❌ Failed to load SqlServer module. Please run: Install-Module SqlServer" -ForegroundColor Red
}

Import-Module BitsTransfer -Force
$DESTINATION_PATH = 'C:\dbbackup'
$SQL_DATA_PATH = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\DATA'

Function ExecuteStandardRestore([string]$server, [string]$database, [string]$pathThere) {
    Try {	
        Write-Host "🚀 Starting restore for: $database" -ForegroundColor Cyan
        
        Write-Host "....📦 Locating and copying newest backup file in '$pathThere'" -ForegroundColor Gray
        $fileHere = CopyNewestItem -sourcePath $pathThere -destination $script:DESTINATION_PATH
        
        Write-Host "....💾 Restoring database from '$fileHere'" -ForegroundColor Gray
        RestoreDatabase -serverName $server -databaseName $database -backupFile $fileHere
        
        # IMPROVEMENT: Backup file is NOT deleted per request 
        Write-Host "✅ Database $database restored successfully." -ForegroundColor Green
        Write-Host "ℹ️ Backup preserved at: $fileHere" -ForegroundColor Yellow
        Return $TRUE
    }
    Catch {
        Write-Host "❌ Error restoring $database" -ForegroundColor Red
        Write-Host "📝 Details: $($_.Exception.Message)" -ForegroundColor Red
        Return $FALSE
    }
}

Function CopyNewestItem([string]$sourcePath, [string]$destination) {
    $latestSourceFile = Get-ChildItem -Path $sourcePath -Filter "*.bak" | 
        Sort-Object CreationTime -Descending | Select-Object -First 1 -ErrorAction Stop
    
    $fileThere = Join-Path -Path $sourcePath -ChildPath $latestSourceFile.Name
    $fileHere = Join-Path -Path $destination -ChildPath $latestSourceFile.Name
    
    Write-Host "....⏳ Transferring backup via BITS..." -ForegroundColor Gray
    Start-BitsTransfer -Source $fileThere -Destination $fileHere -DisplayName "DB_Restore_Transfer"
    
    Return $fileHere
}

Function DbExists([string]$serverName, [string]$databaseName) {
    $server = New-Object ("Microsoft.SqlServer.Management.Smo.Server") $serverName
    return $server.Databases.Name -contains $databaseName
}

Function RestoreDatabase([string]$serverName, [string]$databaseName, [string]$backupFile) {
    $smo = New-Object Microsoft.SqlServer.Management.Smo.Server $serverName
    
    Write-Host "....🔪 Terminating active connections" -ForegroundColor Gray
    $smo.KillAllProcesses($databaseName)
    
    $paths = GetDefaultDatabaseFilePath -ServerName $serverName

    # Read actual logical file names from the backup header
    $restoreObj = New-Object Microsoft.SqlServer.Management.Smo.Restore
    $restoreObj.Devices.AddDevice($backupFile, [Microsoft.SqlServer.Management.Smo.DeviceType]::File)
    $fileList = $restoreObj.ReadFileList($smo)

    $relocFiles = @()
    foreach ($file in $fileList) {
        if ($file.Type -eq 'L') {
            $newPath = Join-Path $paths.LogPath "${databaseName}_Log.ldf"
        } else {
            $newPath = Join-Path $paths.DatabasePath "$databaseName.mdf"
        }
        $relocFiles += New-Object Microsoft.SqlServer.Management.Smo.RelocateFile($file.LogicalName, $newPath)
    }

    $restoreParams = @{
        ServerInstance = $serverName
        Database = $databaseName
        BackupFile = $backupFile
        RelocateFile = $relocFiles
        ErrorAction = "Stop"
    }

    if (DbExists -serverName $serverName -databaseName $databaseName) {
        Restore-SqlDatabase @restoreParams -ReplaceDatabase
    } else {
        Restore-SqlDatabase @restoreParams
    }
    
    # Set to Simple Recovery for Dev/Test efficiency [cite: 23]
    $db = $smo.Databases[$databaseName]
    $db.RecoveryModel = [Microsoft.SqlServer.Management.Smo.RecoveryModel]::Simple
    $db.Alter()
}

Function GetDefaultDatabaseFilePath([string]$ServerName) {
    $SMOServer = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $ServerName 
    $dbPath = if ($SMOServer.Settings.DefaultFile) { $SMOServer.Settings.DefaultFile } else { $script:SQL_DATA_PATH }
    $logPath = if ($SMOServer.Settings.DefaultLog) { $SMOServer.Settings.DefaultLog } else { $script:SQL_DATA_PATH }

    Return [PsCustomObject]@{ DatabasePath = $dbPath; LogPath = $logPath }
}