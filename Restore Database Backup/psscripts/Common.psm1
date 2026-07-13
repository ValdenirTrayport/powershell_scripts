# 1. LOAD MODULES ONLY (Avoid manual Assembly loading to prevent the RelocateFile error)
Import-Module BitsTransfer -Force
Import-Module SqlServer -Force

$DESTINATION_PATH = 'C:\dev'

Function ExecuteStandardRestore([string]$server, [string]$database, [string]$pathThere) {
    Try {    
        Write-Host "🚀 Starting restore for: $database" -ForegroundColor Cyan
        
        Write-Host "....📦 Locating and copying newest backup file" -ForegroundColor Gray
        $fileHere = CopyNewestItem -sourcePath $pathThere -destination $DESTINATION_PATH
        
        Write-Host "....💾 Restoring database from '$fileHere'" -ForegroundColor Gray
        RestoreDatabase -serverName $server -databaseName $database -backupFile $fileHere
        
        Write-Host "✅ Database $database restored successfully." -ForegroundColor Green

        Return $true
    }
    Catch {
        Write-Host "❌ Error restoring $database" -ForegroundColor Red
        Write-Host "📝 Details: $($_.Exception.Message)" -ForegroundColor Red
        Return $false
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
    $server = New-Object Microsoft.SqlServer.Management.Smo.Server $serverName
    return $server.Databases.Name -contains $databaseName
}

Function RestoreDatabase([string]$serverName, [string]$databaseName, [string]$backupFile) {
    # 1. Connect to Server
    $server = New-Object Microsoft.SqlServer.Management.Smo.Server $serverName
    Write-Host "....🔪 Terminating active connections" -ForegroundColor Gray
    $server.KillAllProcesses($databaseName)
    
    # 2. Setup Restore Object
    $restore = New-Object Microsoft.SqlServer.Management.Smo.Restore
    $restore.Action = "Database"
    $restore.Database = $databaseName
    $restore.ReplaceDatabase = $true
    
    $device = New-Object Microsoft.SqlServer.Management.Smo.BackupDeviceItem($backupFile, "File")
    $restore.Devices.Add($device)
    
    # 3. Handle Relocation
    $paths = GetDefaultDatabaseFilePath -ServerName $serverName
    
    # We use the generic Smo.RelocateFile to avoid the "Type X to Type X" error
    $mdf = New-Object Microsoft.SqlServer.Management.Smo.RelocateFile($databaseName, "$($paths.DatabasePath)\$databaseName.mdf")
    $ldf = New-Object Microsoft.SqlServer.Management.Smo.RelocateFile("${databaseName}_Log", "$($paths.LogPath)\${databaseName}_Log.ldf")
    
    $restore.RelocateFiles.Add($mdf) | Out-Null
    $restore.RelocateFiles.Add($ldf) | Out-Null
    
    # 4. Execute
    Write-Host "....⏳ Restoring $databaseName..." -ForegroundColor Gray
    $restore.SqlRestore($server)
    
    # 5. Set to Simple Recovery
    $server.Refresh()
    $db = $server.Databases[$databaseName]
    $db.RecoveryModel = "Simple"
    $db.Alter()
    
    # 6. Notification
    AnnounceCompletion -Message "Dear Master, The $databaseName database restore is complete."
}

function announcecompletion([string]$message) {
    try {
        # bulletproof volume: simulate 'volume down' 50 times (mute), then 'volume up' 5 times (~10%)
        $objshell = new-object -comobject wscript.shell
        for ($i = 0; $i -lt 50; $i++) { $objshell.sendkeys([char]174) } # zero out
        for ($i = 0; $i -lt 15; $i++) { $objshell.sendkeys([char]175) }  # up to ~10%

        add-type -assemblyname system.speech
        $voice = new-object system.speech.synthesis.speechsynthesizer
        try { $voice.selectvoicebyhints(0, 0, 0, "en-gb") } catch {}
        $voice.speak($message)
    } catch {
        write-warning "could not play audio notification, but restore was successful."
    }finally{
		for ($i = 0; $i -lt 50; $i++) { $objshell.sendkeys([char]174) } # zero out volume again
	}
}

# $AudioCode = @"
# using System;
# using System.Runtime.InteropServices;

# public class CoreAudio {
    # [DllImport("user32.dll")]
    # public static extern IntPtr SendMessageW(IntPtr hWnd, int Msg, IntPtr wParam, IntPtr lParam);
# }
# "@
# Add-Type -TypeDefinition $AudioCode

# Function AnnounceCompletion([string]$Message) {
	# # 2. Use a Shell Object to set volume precisely via COM
	# $objSpeaker = New-Object -ComObject MMDeviceEnumerator
	# $objDevice = $objSpeaker.GetDefaultAudioEndpoint(0, 0) # 0 = Render, 0 = Multimedia
	# $AudioInterface = $objDevice.Activate([Guid]'{5CDF2C82-1507-4E73-ABA1-28F140240D4E}', 1, [IntPtr]::Zero)

	# # 3. SET THE VOLUME (0.1 = 10%, 1.0 = 100%)
	# # We cast the interface to the Volume Control type
	# $VolControl = [Microsoft.VisualBasic.Interaction]::CallByName($AudioInterface, "SetMasterVolumeLevelScalar", [Microsoft.VisualBasic.CallType]::Method, 0.1, $null)

	# # --- THE TASK ---
	# Add-Type -AssemblyName System.Speech
	# $voice = New-Object System.Speech.Synthesis.SpeechSynthesizer
	# try { $voice.SelectVoiceByHints(0, 0, 0, "en-GB") } catch {}

	# Write-Host "Volume set to 10%. Speaking..." -ForegroundColor Cyan
	# $voice.Speak($Message)
# }


Function GetDefaultDatabaseFilePath([string]$ServerName) {
    $SMOServer = New-Object Microsoft.SqlServer.Management.Smo.Server $ServerName 
    $dbPath = if ($SMOServer.Settings.DefaultFile) { $SMOServer.Settings.DefaultFile } else { $SMOServer.Information.MasterDBPath }
    $logPath = if ($SMOServer.Settings.DefaultLog) { $SMOServer.Settings.DefaultLog } else { $SMOServer.Information.MasterDBLogPath }

    Return [PsCustomObject]@{ DatabasePath = $dbPath; LogPath = $logPath }
}

# ... (Include your CopyNewestItem, DbExists, and GetDefaultDatabaseFilePath functions here)