#Requires -Version 5.1
<#
.SYNOPSIS
    Deploys .NET Hosting Bundle to remote servers.

.DESCRIPTION
    Copies the .NET Hosting installer to targeted servers via PSRemoting
    and performs a silent installation. Automatically skips servers that
    are already on the target version or higher.

.EXAMPLE
    .\Install-DotNetHosting.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# =====================================================================
# 1. Configuration & Interactive Prompt
# =====================================================================

# The target version we are deploying (extracted from the filename)
$TargetVersionStr = "10.0.8"
$TargetVersion    = [version]$TargetVersionStr

# 📁 The network path to the .NET installer
$NetworkPath = "\\files.hq.trayport.com\zeus\User\Valdenir.Filho\dotnet-hosting-$TargetVersionStr-win.exe"

# 🌍 Prompt the user to choose the environment OR a specific server
Write-Host "💡 You can enter an Environment (e.g., PROD, TEST), a Server (e.g., bs-web01), or ALL." -ForegroundColor Cyan
$TargetInput = Read-Host "👉 Please enter your target"
$TargetInput = $TargetInput.Trim().ToUpper()

# =====================================================================
# 2. Raw Server Data
# =====================================================================
$rawServerList = @"
PROD	is-barri01
PROD	is-barri02
PROD	is-barri03
PROD	bs-web01
PROD	BS-WEB02
PROD	bs-web03
PROD	bs-web04
PROD	bs-logmanager01
PROD	bs-prod1
PROD	bs-web05
PROD	bs-web06
PROD	bs-snmonitor
TCMS	tsv-automation
TCMS	tsv-pauto
TCMS	tsv-api-01
PROD	bs-automkt01
PROD    bs-dataaut01
PROD	bs-t-buddy01	
TEST	bs-tautomkt01
TEST	bs-tweb02
TEST	bs-tweb03
TEST	bs-tbarri01
TEST	bs-tbarri02
TEST	bs-tbarri03
SANDBOX	BS-ADOTEST02
TEST	bs-adoagent01 
TEST	bs-test1
TEST	bs-tweb04
TEST	bs-tweb05
"@

# =====================================================================
# 3. Pre-flight Checks & Data Parsing
# =====================================================================

if (-not (Test-Path $NetworkPath)) {
    Write-Host "❌ ERROR: Cannot access the network file. Please check the path and your permissions." -ForegroundColor Red
    exit
}

$allServers = @()
foreach ($line in ($rawServerList -split "`n")) {
    $cleanLine = $line.Trim() -replace '\s+', ' '
    if ([string]::IsNullOrWhiteSpace($cleanLine)) { continue }
    
    $parts = $cleanLine -split ' '
    if ($parts.Count -ge 2) {
        $allServers += [PSCustomObject]@{
            Environment = $parts[0].ToUpper()
            Server      = $parts[1]
        }
    }
}

# 🎯 Filter based on Environment OR Server Name
if ($TargetInput -eq "ALL") {
    $filteredServers = $allServers
} else {
    # Check if the input matches an environment first, otherwise assume it's a server name
    $envMatch = $allServers | Where-Object { $_.Environment -eq $TargetInput }
    if ($envMatch) {
        $filteredServers = $envMatch
    } else {
        $filteredServers = $allServers | Where-Object { $_.Server -ieq $TargetInput }
    }
}

$serverNames = $filteredServers.Server

if ($serverNames.Count -eq 0) {
    Write-Host "⚠️ No servers or environments found matching: '$TargetInput'. Exiting..." -ForegroundColor Yellow
    exit
}

Write-Host "`n📡 Establishing connections to $($serverNames.Count) target(s)..." -ForegroundColor Cyan

# =====================================================================
# 4. Session Creation & Smart Version Checking
# =====================================================================

$sessions = New-PSSession -ComputerName $serverNames -ErrorAction SilentlyContinue

if (-not $sessions) {
    Write-Host "💥 FATAL ERROR: Could not establish any remote sessions. Check server status and PSRemoting." -ForegroundColor Red
    exit
}

Write-Host "🔎 Checking current .NET 10 versions on remote servers..." -ForegroundColor Cyan

# Run a pre-check to find out what versions are currently installed
$versionChecks = Invoke-Command -Session $sessions -ScriptBlock {
    $highestVersion = "0.0.0"
    if (Get-Command dotnet -ErrorAction SilentlyContinue) {
        # Extract all 10.0.x versions from the runtimes list
        $matches = (dotnet --list-runtimes) | Select-String -Pattern '(10\.0\.\d+)' -AllMatches
        if ($matches) {
            # Parse versions, sort descending, grab the highest one
            $highestVersion = ($matches.Matches.Value | ForEach-Object { [version]$_ } | Sort-Object -Descending | Select-Object -First 1).ToString()
        }
    }
    
    [PSCustomObject]@{
        ComputerName   = $env:COMPUTERNAME
        CurrentVersion = $highestVersion
    }
}

# Determine which sessions actually need the update
$sessionsToUpgrade = @()

Write-Host "`n📊 Version Report:" -ForegroundColor Cyan
foreach ($vc in $versionChecks) {
    $currentVer = [version]$vc.CurrentVersion
    
    if ($currentVer -eq [version]"0.0.0") {
        Write-Host "   🔸 $($vc.ComputerName): No .NET 10 found. Will install $TargetVersionStr." -ForegroundColor Yellow
        $sessionsToUpgrade += $sessions | Where-Object { $_.ComputerName -ieq $vc.ComputerName }
    } elseif ($currentVer -lt $TargetVersion) {
        Write-Host "   🔄 $($vc.ComputerName): Outdated ($currentVer). Will update to $TargetVersionStr." -ForegroundColor Yellow
        $sessionsToUpgrade += $sessions | Where-Object { $_.ComputerName -ieq $vc.ComputerName }
    } else {
        Write-Host "   ✅ $($vc.ComputerName): Up to date ($currentVer). Skipping." -ForegroundColor Green
    }
}

if ($sessionsToUpgrade.Count -eq 0) {
    Write-Host "`n🎉 All targeted servers are already running .NET $TargetVersionStr or higher. Nothing to do!" -ForegroundColor Green
    $sessions | Remove-PSSession
    exit
}

# =====================================================================
# 5. Remote Execution Block (Only on servers needing updates)
# =====================================================================

$RemoteDestination = "C:\Windows\Temp\dotnet-hosting-$TargetVersionStr-win.exe"
Write-Host "`n📦 Pushing installer to the $($sessionsToUpgrade.Count) server(s) that need it..." -ForegroundColor Cyan

# Loop through each session explicitly to avoid array conversion errors
foreach ($session in $sessionsToUpgrade) {
    Copy-Item -Path $NetworkPath -Destination $RemoteDestination -ToSession $session
}

Write-Host "✅ Copy complete. Starting silent installations...`n" -ForegroundColor Green

Invoke-Command -Session $sessionsToUpgrade -ScriptBlock {
    # Rebuilding the variable inside the scriptblock so it has the correct path
    $TargetVerStr = "10.0.8" 
    $InstallerPath = "C:\Windows\Temp\dotnet-hosting-$TargetVerStr-win.exe"

    try {
        Write-Host "⏳ [$env:COMPUTERNAME] Executing silent installation..." -ForegroundColor Cyan
        
        $installProcess = Start-Process -FilePath $InstallerPath -ArgumentList "/quiet /install /norestart" -Wait -PassThru
        
        if ($installProcess.ExitCode -eq 0 -or $installProcess.ExitCode -eq 3010) {
            Write-Host "✅ [$env:COMPUTERNAME] SUCCESS: Updated to .NET $TargetVerStr." -ForegroundColor Green
            if ($installProcess.ExitCode -eq 3010) {
                Write-Host "⚠️ [$env:COMPUTERNAME] NOTE: A reboot is required to complete the installation." -ForegroundColor Yellow
            }
        } else {
            Write-Host "❌ [$env:COMPUTERNAME] ERROR: Installation failed with exit code $($installProcess.ExitCode)." -ForegroundColor Red
        }

    } catch {
        Write-Host "💥 [$env:COMPUTERNAME] EXCEPTION: $($_.Exception.Message)" -ForegroundColor Red
    } finally {
        if (Test-Path $InstallerPath) {
            Remove-Item -Path $InstallerPath -Force
            Write-Host "🧹 [$env:COMPUTERNAME] Cleaned up temporary installer file." -ForegroundColor DarkGray
        }
    }
}

# =====================================================================
# 6. Cleanup
# =====================================================================
Write-Host "`n🏁 Deployment finished. Closing remote sessions..." -ForegroundColor Cyan
$sessions | Remove-PSSession
Write-Host "🎉 All done!" -ForegroundColor Green