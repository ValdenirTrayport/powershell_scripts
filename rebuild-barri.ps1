$baseBarriPath = "C:\dev\BusinessSystems.Barri"
$baseCommonPath = "C:\dev\BusinessSystems.Common"
$logDirectory = "C:\dev\BuildLogs"
$excludePattern = "\\GVAPIWrapper(\\|$)"

$commonSln   = Join-Path $baseCommonPath "BusinessSystemsCommon.sln"
$trayportSln = Join-Path $baseBarriPath "Trayport.sln"
$barriSln    = Join-Path $baseBarriPath "Barri.sln"

# Ensure the log directory exists
if (-Not (Test-Path $logDirectory)) {
    New-Item -ItemType Directory -Path $logDirectory | Out-Null
}
Write-Host "Build logs will be saved to: $logDirectory" -ForegroundColor Yellow

# ====================================================================
# 1. Delete 'obj' and 'bin' folders (Excluding GVAPIWrapper)
# ====================================================================
if (Test-Path $baseBarriPath) {
    Write-Host "`n--> Cleaning 'bin' and 'obj' folders under $baseBarriPath..." -ForegroundColor Cyan

    $foldersToDelete = Get-ChildItem -Path $baseBarriPath -Include bin, obj -Recurse -Directory

    foreach ($folder in $foldersToDelete) {
        if ($folder.FullName -notmatch $excludePattern) {
            Write-Host "Deleting: $($folder.FullName)" -ForegroundColor DarkGray
            Remove-Item -Path $folder.FullName -Recurse -Force
        } else {
            Write-Host "Skipping excluded: $($folder.FullName)" -ForegroundColor DarkYellow
        }
    }
    Write-Host "Clean complete." -ForegroundColor Green
} else {
    Write-Warning "Directory $baseBarriPath does not exist. Skipping clean step."
}

# ====================================================================
# 2. Process BusinessSystemsCommon.sln FIRST
# ====================================================================
Write-Host "`n--> Processing Common Solution: $commonSln" -ForegroundColor Cyan
if (Test-Path $commonSln) {
    Write-Host "Restoring Common..." -ForegroundColor DarkGray
    msbuild $commonSln -t:Restore
    if ($LASTEXITCODE -ne 0) { Write-Error "Restore failed for Common"; exit $LASTEXITCODE }

    Write-Host "Building Common (Creating Full and Warnings-Only logs)..." -ForegroundColor DarkGray
    msbuild $commonSln -fl1 -flp1:"LogFile=$logDirectory\Common_Build.log;Verbosity=detailed" -fl2 -flp2:"LogFile=$logDirectory\Common_Warnings.log;WarningsOnly"
    if ($LASTEXITCODE -ne 0) { Write-Error "Build failed for Common. Check Common_Build.log"; exit $LASTEXITCODE }
    
    Write-Host "Common processed successfully." -ForegroundColor Green
} else {
    Write-Warning "Could not find $commonSln"
}

# ====================================================================
# 3. RESTORE Remaining Solutions
# ====================================================================
Write-Host "`n--> Restoring Remaining Solutions..." -ForegroundColor Cyan

if (Test-Path $trayportSln) {
    Write-Host "Restoring $trayportSln (Full Framework)" -ForegroundColor DarkGray
    msbuild $trayportSln -t:Restore
    if ($LASTEXITCODE -ne 0) { Write-Error "Restore failed for Trayport"; exit $LASTEXITCODE }
}

if (Test-Path $barriSln) {
    Write-Host "Restoring $barriSln (.NET 10)" -ForegroundColor DarkGray
    dotnet restore $barriSln
    if ($LASTEXITCODE -ne 0) { Write-Error "Restore failed for Barri"; exit $LASTEXITCODE }
}
Write-Host "Restores complete." -ForegroundColor Green

# ====================================================================
# 4. BUILD Remaining Solutions
# ====================================================================
Write-Host "`n--> Building Remaining Solutions..." -ForegroundColor Cyan

if (Test-Path $trayportSln) {
    Write-Host "Building $trayportSln (Creating Full and Warnings-Only logs)..." -ForegroundColor DarkGray
    msbuild $trayportSln -fl1 -flp1:"LogFile=$logDirectory\Trayport_Build.log;Verbosity=detailed" -fl2 -flp2:"LogFile=$logDirectory\Trayport_Warnings.log;WarningsOnly"
    if ($LASTEXITCODE -ne 0) { Write-Error "Build failed for Trayport. Check Trayport_Build.log"; exit $LASTEXITCODE }
}

if (Test-Path $barriSln) {
    Write-Host "Building $barriSln (Creating Full and Warnings-Only logs)..." -ForegroundColor DarkGray
    # dotnet build securely passes msbuild file logger parameters
    dotnet build $barriSln --no-restore -fl1 -flp1:"LogFile=$logDirectory\Barri_Build.log;Verbosity=detailed" -fl2 -flp2:"LogFile=$logDirectory\Barri_Warnings.log;WarningsOnly"
    if ($LASTEXITCODE -ne 0) { Write-Error "Build failed for Barri. Check Barri_Build.log"; exit $LASTEXITCODE }
}

Write-Host "`nAll operations completed successfully!" -ForegroundColor Green