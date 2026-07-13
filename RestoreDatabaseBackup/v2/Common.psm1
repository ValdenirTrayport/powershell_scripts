Try {
    Import-Module SqlServer -Force -ErrorAction Stop
} Catch {
    Write-Host "❌ Failed to load SqlServer module. Please run: Install-Module SqlServer" -ForegroundColor Red
}

Import-Module BitsTransfer -Force
$DESTINATION_PATH = 'C:\dbbackup'
$SQL_DATA_PATH = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\DATA'

Function Ensure-Folder([string]$path) {
    if (-not (Test-Path -Path $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
}

Function Copy-BackupFileSafe([string]$sourceFile, [string]$destinationFile) {
    Ensure-Folder -path (Split-Path -Path $destinationFile -Parent)

    Try {
        Write-Host "....⏳ Transferring backup via BITS..." -ForegroundColor Gray
        Start-BitsTransfer -Source $sourceFile -Destination $destinationFile -DisplayName "DB_Restore_Transfer" -ErrorAction Stop
    }
    Catch {
        Write-Host "....⚠️ BITS failed, falling back to Copy-Item" -ForegroundColor Yellow
        Write-Host "....📝 BITS error: $($_.Exception.Message)" -ForegroundColor DarkYellow
        Copy-Item -Path $sourceFile -Destination $destinationFile -Force -ErrorAction Stop
    }

    Return $destinationFile
}

Function ExecuteStandardRestore([string]$server, [string]$database, [string]$pathThere) {
    Try {	
        Write-Host "🚀 Starting restore for: $database" -ForegroundColor Cyan
        
        Write-Host "....📦 Locating and copying newest backup file in '$pathThere'" -ForegroundColor Gray
        $fileHere = CopyNewestItem -sourcePath $pathThere -destination $script:DESTINATION_PATH
    
        Write-Host "....💾 Restoring database from '$fileHere'" -ForegroundColor Gray
        RestoreDatabase -serverName $server -databaseName $database -backupFile $fileHere
        
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

Function ExecuteFixedPathRestore([string]$server, [string]$localFolder, [string]$database, [string]$fileThere) {
    Try {	
        Write-Host "🚀 Starting fixed-path restore for: $database" -ForegroundColor Cyan
        
        $localDirPath = Join-Path $script:DESTINATION_PATH $localFolder
        if (-not (Test-Path $localDirPath)) { New-Item -ItemType Directory -Force -Path $localDirPath | Out-Null }
        
        $fileName = Split-Path $fileThere -Leaf
        $fileHere = Join-Path $localDirPath $fileName

        Copy-BackupFileSafe -sourceFile $fileThere -destinationFile $fileHere | Out-Null
    
        Write-Host "....💾 Restoring database from '$fileHere'" -ForegroundColor Gray
        RestoreDatabase -serverName $server -databaseName $database -backupFile $fileHere
        
        Write-Host "✅ Database $database restored successfully." -ForegroundColor Green
        Return $TRUE
    }
    Catch {
        Write-Host "❌ Error restoring $database" -ForegroundColor Red
        Write-Host "📝 Details: $($_.Exception.Message)" -ForegroundColor Red
        Return $FALSE
    }
}

Function CopyNewestItem([string]$sourcePath, [string]$destination) {
    Ensure-Folder -path $destination

    $latestSourceFile = Get-ChildItem -Path $sourcePath -Filter "*.bak" -File -ErrorAction Stop |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $latestSourceFile) {
        throw "No .bak files found in '$sourcePath'."
    }
    
    $fileThere = Join-Path -Path $sourcePath -ChildPath $latestSourceFile.Name
    $fileHere = Join-Path -Path $destination -ChildPath $latestSourceFile.Name

    if (Test-Path $fileHere) {
        Write-Host "....✅ Backup already exists locally, skipping download." -ForegroundColor DarkGreen
        Return $fileHere
    }

    Return (Copy-BackupFileSafe -sourceFile $fileThere -destinationFile $fileHere)
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
    
    # Set to Simple Recovery for Dev/Test efficiency
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

Function TruncateTable([string]$server, [string]$database, [string]$table) {
    Write-Host "....🗑️ Truncating table [$table] in $database" -ForegroundColor Gray
    Invoke-Sqlcmd -ServerInstance $server -Database $database -Query "TRUNCATE TABLE [$table];" -TrustServerCertificate -ErrorAction SilentlyContinue
}

Function ShrinkDatabase([string]$server, [string]$database) {
    Write-Host "....🗜️ Shrinking database $database" -ForegroundColor Gray
    Invoke-Sqlcmd -ServerInstance $server -Database $database -Query "DBCC SHRINKDATABASE (N'$database');" -TrustServerCertificate -ErrorAction SilentlyContinue
}

Function PopulatePassword([int]$PasswordId, [string]$AppSettingName, [string]$ServerInstance, [string]$Database) {
    Write-Host "....🔑 Generating/Populating password for $AppSettingName (ID: $PasswordId)" -ForegroundColor Gray
    # Add your custom API/SQL logic here to fetch the clear-text password and inject it into the DB
}
