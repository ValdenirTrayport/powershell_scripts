# Define your input and output paths
$inputFile = "C:\scripts\projects-for-conversion.txt"
$outputFile = "C:\Users\valdenirf\Desktop\framework_results.csv"

function Get-Normalised-Framework-Version {
    param (
        [string[]]$RawFrameworkVersion
    )

    switch($RawFrameworkVersion){
		"v3.5" {return "net35" }
		"v4.5" {return "net45" }
		"v4.5.2" {return "net452" }
		"v4.6" {return "net46" }
		"v4.6.1" {return "net461" }
		"v4.6.2" {return "net462" }
		"v4.7.2" {return "net472" }
		"v4.8" {return "net48" }
		default {return $RawFrameworkVersion }
	}
}


Write-Host "Reading projects from $inputFile..."

$lines = Get-Content -Path $inputFile
$results = @()

foreach ($line in $lines) {
    # Remove the "" prefix
    $filePath = $line #-replace '\\s*', ''
    $filePath = $filePath.Trim()

    if ([string]::IsNullOrWhiteSpace($filePath)) { continue }

    # Safeguard check to warn you if backslashes are missing
    if ($filePath -notmatch '\\') {
        Write-Warning "Missing backslashes detected in path: $filePath"
    }

    $framework = "Unknown"

    if (Test-Path -Path $filePath -PathType Leaf) {
        $content = Get-Content -Path $filePath -Raw

        if ($content -match '(?i)<TargetFramework>(.*?)</TargetFramework>') {
            $framework = $matches[1]
        } elseif ($content -match '(?i)<TargetFrameworks>(.*?)</TargetFrameworks>') {
            $framework = $matches[1]
        } elseif ($content -match '(?i)<TargetFrameworkVersion>(.*?)</TargetFrameworkVersion>') {
            $framework = $matches[1]
        } else {
            $framework = "Framework node not found (Check if standard .csproj)"
        }
    } else {
        $framework = "File Not Found"
    }

    $results += [PSCustomObject]@{
        ProjectFile = $filePath
        TargetFramework = Get-Normalised-Framework-Version -RawFrameworkVersion $framework
    }
}

$results | Export-Csv -Path $outputFile -NoTypeInformation
Write-Host "Script completed! Results exported to $outputFile."

