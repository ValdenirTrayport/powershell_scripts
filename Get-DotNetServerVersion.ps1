#Requires -Version 5.1
<#
.SYNOPSIS
    Queries remote servers for their installed .NET runtime versions.

.DESCRIPTION
    Connects to all known Barri infrastructure servers via PSRemoting and
    reports installed .NET runtimes in a formatted table.

.EXAMPLE
    .\Get-DotNetServerVersion.ps1
#>
[CmdletBinding()]
param()

# 1. Define the raw input data
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
PROD    bs-dataaut01
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

# 2. Parse and clean the input data
$servers = @()
foreach ($line in ($rawServerList -split "`n")) {
    # Clean up mixed tabs, trailing spaces, and non-breaking spaces
    $cleanLine = $line.Trim() -replace '\s+', ' '
    if ([string]::IsNullOrWhiteSpace($cleanLine)) { continue }
    
    $parts = $cleanLine -split ' '
    if ($parts.Count -ge 2) {
        $servers += [PSCustomObject]@{
            Environment = $parts[0]
            Server = $parts[1]
        }
    }
}

# 3. Gather Data
$results = @()
$failedServers = @()

Write-Host "Querying servers... This may take a moment depending on network connectivity.`n" -ForegroundColor Cyan

foreach ($srv in $servers) {
    try {
        # Execute the command remotely
        $versions = Invoke-Command -ComputerName $srv.Server -ErrorAction Stop -ScriptBlock {
            if (Get-Command dotnet -ErrorAction SilentlyContinue) {
                # Get runtimes and strip out the local paths at the end of the string
                dotnet --list-runtimes | ForEach-Object { $_ -replace '\s*\[.*\]', '' }
            } else {
                "dotnet CLI not found"
            }
        }
        
        $results += [PSCustomObject]@{
            Environment = $srv.Environment
            Server      = $srv.Server
            Versions    = if ($null -ne $versions) { @($versions) } else { @("None found") }
        }
    } catch {
        # Catch WinRM, DNS, or offline errors
        $failedServers += [PSCustomObject]@{
            Environment = $srv.Environment
            Server      = $srv.Server
            Error       = $_.Exception.Message
        }
    }
}

# 4. Generate the ASCII Table Output
$envWidth = 13
$srvWidth = 15
$verWidth = 40
$totalWidth = $envWidth + $srvWidth + $verWidth + 10
$separator = "-" * $totalWidth

Write-Host " $separator"
Write-Host ("| {0,-$envWidth} | {1,-$srvWidth} | {2,-$verWidth} |" -f "Environment", "Server", "dotnet version")
Write-Host " $separator"

foreach ($res in $results) {
    $isFirstLine = $true
    
    foreach ($ver in $res.Versions) {
        if ($isFirstLine) {
            # Print Env and Server on the first line
            Write-Host ("| {0,-$envWidth} | {1,-$srvWidth} | {2,-$verWidth} |" -f $res.Environment, $res.Server, $ver)
            $isFirstLine = $false
        } else {
            # Leave Env and Server blank for subsequent versions on the same machine
            Write-Host ("| {0,-$envWidth} | {1,-$srvWidth} | {2,-$verWidth} |" -f "", "", $ver)
        }
    }
    # Add a thin line separator between servers (optional, comment out if you want a seamless block)
    Write-Host ("| {0,-$envWidth} | {1,-$srvWidth} | {2,-$verWidth} |" -f "", "", "")
}
Write-Host " $separator"

# 5. Output Failed Servers
if ($failedServers.Count -gt 0) {
    Write-Host "`nFailed Servers (Offline or PSRemoting disabled):" -ForegroundColor Red
    $failedServers | Format-Table -Property Environment, Server, Error -AutoSize
} else {
    Write-Host "`nAll servers queried successfully." -ForegroundColor Green
}