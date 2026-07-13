#Requires -Version 5.1
<#
.SYNOPSIS
    Scans .csproj files and reports their target framework versions.

.DESCRIPTION
    Reads a list of project file paths from an input file, extracts the
    TargetFramework / TargetFrameworks / TargetFrameworkVersion element from each,
    normalises old-style version strings (e.g. "v4.7.2" -> "net472"), and exports
    results to a CSV file.

.PARAMETER InputFile
    Path to a text file containing one .csproj path per line.

.PARAMETER OutputFile
    Path for the output CSV report.

.EXAMPLE
    .\Get-ProjectFrameworkVersion.ps1
    .\Get-ProjectFrameworkVersion.ps1 -InputFile "C:\mylist.txt" -OutputFile "C:\report.csv"
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$InputFile = (Join-Path -Path $PSScriptRoot -ChildPath "projects-for-conversion.txt"),

    [Parameter()]
    [string]$OutputFile = (Join-Path -Path ([Environment]::GetFolderPath('Desktop')) -ChildPath "framework_results.csv")
)

$ErrorActionPreference = 'Stop'

function ConvertTo-NormalisedFramework {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RawVersion)

    switch ($RawVersion) {
        "v3.5"   { return "net35" }
        "v4.5"   { return "net45" }
        "v4.5.2" { return "net452" }
        "v4.6"   { return "net46" }
        "v4.6.1" { return "net461" }
        "v4.6.2" { return "net462" }
        "v4.7.2" { return "net472" }
        "v4.8"   { return "net48" }
        default  { return $RawVersion }
    }
}

if (-not (Test-Path -LiteralPath $InputFile)) {
    Write-Error "Input file not found: $InputFile"
    return
}

Write-Host "Reading projects from $InputFile..." -ForegroundColor Cyan

$lines = Get-Content -LiteralPath $InputFile
$results = @()

foreach ($line in $lines) {
    $filePath = $line.Trim()
    if ([string]::IsNullOrWhiteSpace($filePath)) { continue }

    $framework = "Unknown"

    if (Test-Path -LiteralPath $filePath -PathType Leaf) {
        $content = Get-Content -LiteralPath $filePath -Raw

        if ($content -match '(?i)<TargetFramework>(.*?)</TargetFramework>') {
            $framework = $Matches[1]
        }
        elseif ($content -match '(?i)<TargetFrameworks>(.*?)</TargetFrameworks>') {
            $framework = $Matches[1]
        }
        elseif ($content -match '(?i)<TargetFrameworkVersion>(.*?)</TargetFrameworkVersion>') {
            $framework = $Matches[1]
        }
        else {
            $framework = "Framework node not found"
        }
    }
    else {
        $framework = "File Not Found"
    }

    $results += [PSCustomObject]@{
        ProjectFile     = $filePath
        TargetFramework = ConvertTo-NormalisedFramework -RawVersion $framework
    }
}

$results | Export-Csv -LiteralPath $OutputFile -NoTypeInformation
Write-Host "Results exported to $OutputFile ($($results.Count) projects scanned)." -ForegroundColor Green
