#Requires -Version 5.1
<#
.SYNOPSIS
    Resets a billing period by deleting all invoice data for a given PeriodID
    across Local, Test, or Approval environments.

.DESCRIPTION
    Consolidated billing period reset tool that:
    1. Cleans Hangfire job tables for environment-specific schemas.
    2. Creates a temporary performance index on InvoiceServerDetails.
    3. Deletes dependent records (server logins, invoice metadata, billing logs).
    4. Bulk-deletes InvoiceServerDetails and Invoices in configurable batches.
    5. Re-enables automatic invoice creation for the target period.

    Environment-specific configuration (connection strings, table mappings,
    exclusion lists, and Hangfire schemas) is loaded from an internal registry.

.PARAMETER Environment
    Target environment: Local, Test, or Approval.

.PARAMETER PeriodID
    The billing period identifier whose invoice data will be deleted.

.PARAMETER BatchSize
    Number of records per DELETE batch. Defaults per environment (50/25/50).

.EXAMPLE
    .\Reset-BillingPeriod.ps1 -Environment Local -PeriodID 413

.EXAMPLE
    .\Reset-BillingPeriod.ps1 -Environment Approval -PeriodID 410 -BatchSize 100

.NOTES
    PowerShell 5.1+ (Windows PowerShell) or PowerShell 7+.
    Uses Windows Authentication (Integrated Security).
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Local', 'Test', 'Approval')]
    [string]$Environment,

    [Parameter(Mandatory)]
    [int]$PeriodID,

    [Parameter()]
    [int]$BatchSize = 0
)

$ErrorActionPreference = 'Stop'

# =============================================================================
# 1. Environment Configuration
# =============================================================================
$EnvironmentConfig = @{
    Local = @{
        ConnectionString  = "Data Source=localhost;Initial Catalog=TRAYINVOICE;Integrated Security=True;TrustServerCertificate=True;"
        DefaultBatchSize  = 50
        HangfireSchemas   = @("HangFire", "Calculation")
        CleanHangfire     = $true
        HasBillingLogDeps = $false
        ExcludedInvoiceIds = @()
        ServerIdMapping   = [ordered]@{
            "InvoiceServerICELogins"                 = "InvoiceServerID"
            "InvoiceServerJouleChartingLogins"       = "InvoiceServerDetailsID"
            "InvoiceServerTradesignalLogins"         = "InvoiceServerId"
            "InvoiceServerGmePassThroughLogins"      = "InvoiceServerId"
            "InvoiceServerMercuriaSingleScreenLogins"= "InvoiceServerId"
            "InvoiceServerATLogins"                  = "InvoiceServerID"
            "InvoiceServerTvcmLogins"                = "InvoiceServerId"
            "InvoiceServerJMLogins"                  = "InvoiceServerID"
            "InvoiceServerT7Logins"                  = "InvoiceServerId"
        }
        InvoiceIdMapping  = [ordered]@{
            "InvoiceTags"            = "InvoiceId"
            "EmailSent"              = "InvoiceID"
            "InvoiceRejections"      = "InvoiceID"
            "InvoiceEmaLicenceBands" = "InvoiceID"
            "InvoiceMetaData"        = "InvoiceID"
        }
    }
    Test = @{
        ConnectionString  = "Data Source=bs-tsql22;Initial Catalog=TRAYINVOICE;Integrated Security=True;TrustServerCertificate=True;"
        DefaultBatchSize  = 25
        HangfireSchemas   = @()
        CleanHangfire     = $false
        HasBillingLogDeps = $false
        ExcludedInvoiceIds = @()
        ServerIdMapping   = [ordered]@{
            "InvoiceServerICELogins"                 = "InvoiceServerID"
            "InvoiceServerJouleChartingLogins"       = "InvoiceServerDetailsID"
            "InvoiceServerTradesignalLogins"         = "InvoiceServerId"
            "InvoiceServerGmePassThroughLogins"      = "InvoiceServerId"
            "InvoiceServerMercuriaSingleScreenLogins"= "InvoiceServerId"
            "InvoiceServerATLogins"                  = "InvoiceServerID"
            "InvoiceServerTvcmLogins"                = "InvoiceServerId"
            "InvoiceServerJMLogins"                  = "InvoiceServerID"
            "InvoiceServerT7Logins"                  = "InvoiceServerId"
        }
        InvoiceIdMapping  = [ordered]@{
            "InvoiceTags"            = "InvoiceId"
            "EmailSent"              = "InvoiceID"
            "InvoiceRejections"      = "InvoiceID"
            "InvoiceEmaLicenceBands" = "InvoiceID"
            "InvoiceMetaData"        = "InvoiceID"
        }
    }
    Approval = @{
        ConnectionString  = "Data Source=bs-dsql22;Initial Catalog=TRAYINVOICE_SLIM;Integrated Security=True;TrustServerCertificate=True;"
        DefaultBatchSize  = 50
        HangfireSchemas   = @("HangFire", "BarriHangFire")
        CleanHangfire     = $true
        HasBillingLogDeps = $true
        ExcludedInvoiceIds = @()  # Loaded from external config file
        ServerIdMapping   = [ordered]@{
            "InvoiceServerDataAnalyticsLogins"       = "InvoiceServerId"
            "InvoiceServerICELogins"                 = "InvoiceServerID"
            "InvoiceServerUpstreamLogins"            = "InvoiceServerID"
            "InvoiceServerTradesignalLogins"         = "InvoiceServerId"
            "InvoiceServerGmePassThroughLogins"      = "InvoiceServerId"
            "InvoiceServerMercuriaSingleScreenLogins"= "InvoiceServerId"
            "InvoiceServerJouleChartingLogins"       = "InvoiceServerDetailsID"
            "InvoiceServerATLogins"                  = "InvoiceServerID"
            "InvoiceServerTvcmLogins"                = "InvoiceServerId"
            "InvoiceServerJMLogins"                  = "InvoiceServerID"
            "InvoiceServerJTTLogins"                 = "InvoiceServerID"
            "InvoiceServerT7Logins"                  = "InvoiceServerId"
            "InvoiceServerRemitLogins"               = "InvoiceServerId"
        }
        InvoiceIdMapping  = [ordered]@{
            "InvoiceTags"            = "InvoiceId"
            "EmailSent"              = "InvoiceID"
            "InvoiceRejections"      = "InvoiceID"
            "InvoiceEmaLicenceBands" = "InvoiceID"
            "InvoiceUserLogins"      = "InvoiceID"
            "InvoiceSAASUserNames"   = "InvoiceID"
        }
    }
}

# =============================================================================
# 2. Load Configuration
# =============================================================================
$Config = $EnvironmentConfig[$Environment]
$ConnectionString = $Config.ConnectionString

if ($BatchSize -eq 0) {
    $BatchSize = $Config.DefaultBatchSize
}

# Load excluded invoice IDs from external JSON if it exists (Approval environment)
$exclusionFilePath = Join-Path -Path $PSScriptRoot -ChildPath "config\ExcludedInvoiceIds.json"
if ($Environment -eq 'Approval' -and (Test-Path -LiteralPath $exclusionFilePath)) {
    $Config.ExcludedInvoiceIds = Get-Content -LiteralPath $exclusionFilePath -Raw | ConvertFrom-Json
}

# =============================================================================
# 3. Helper Functions
# =============================================================================
function Invoke-SqlNonQuery {
    <#
    .SYNOPSIS
        Executes a non-query SQL statement and returns rows affected with timing.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Query,
        [Parameter(Mandatory)][string]$ConnectionStr,
        [string]$ActionDescription = "executing SQL query",
        [int]$Timeout = 120
    )

    $conn = New-Object System.Data.SqlClient.SqlConnection($ConnectionStr)
    $cmd = New-Object System.Data.SqlClient.SqlCommand($Query, $conn)
    $cmd.CommandTimeout = $Timeout

    try {
        $conn.Open()
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $rowsAffected = $cmd.ExecuteNonQuery()
        $stopwatch.Stop()

        return [PSCustomObject]@{
            RowsAffected = $rowsAffected
            ElapsedMs    = [math]::Round($stopwatch.Elapsed.TotalMilliseconds, 2)
        }
    }
    catch {
        Write-Error "Error while ${ActionDescription}: $($_.Exception.Message)"
        Write-Error "Query attempted: $Query"
        return $null
    }
    finally {
        if ($conn.State -eq [System.Data.ConnectionState]::Open) {
            $conn.Close()
        }
    }
}

function Invoke-SqlBulkDelete {
    <#
    .SYNOPSIS
        Fetches IDs from a query, then deletes rows in batches to avoid lock escalation.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$TableName,
        [Parameter(Mandatory)][string]$IdColumnName,
        [Parameter(Mandatory)][string]$IdListQuery,
        [Parameter(Mandatory)][string]$ConnectionStr,
        [int]$BatchSz = 50
    )

    $idList = @()
    $conn = New-Object System.Data.SqlClient.SqlConnection($ConnectionStr)
    $cmd = New-Object System.Data.SqlClient.SqlCommand($IdListQuery, $conn)

    try {
        Write-Host "  Fetching $IdColumnName for $TableName..." -ForegroundColor Yellow
        $conn.Open()
        $reader = $cmd.ExecuteReader()

        while ($reader.Read()) {
            if (-not $reader.IsDBNull(0)) {
                $idList += $reader.GetInt32(0)
            }
        }
        $reader.Close()

        $totalIds = $idList.Count
        Write-Host "  Found $totalIds records to delete from $TableName." -ForegroundColor Cyan

        if ($totalIds -eq 0) {
            Write-Host "  No records to delete from $TableName. Skipping." -ForegroundColor Gray
            return
        }

        $i = 0
        while ($i -lt $totalIds) {
            $batchIds = $idList[$i..([System.Math]::Min($i + $BatchSz - 1, $totalIds - 1))]
            $idString = $batchIds -join ','
            $deleteQuery = "DELETE FROM $TableName WHERE $IdColumnName IN ($idString)"

            $result = Invoke-SqlNonQuery -Query $deleteQuery -ConnectionStr $ConnectionStr -ActionDescription "bulk deleting $TableName batch"

            if ($null -ne $result) {
                Write-Host "  [$($i + 1)..$([System.Math]::Min($i + $BatchSz, $totalIds)) of $totalIds] Deleted $($result.RowsAffected) rows in $($result.ElapsedMs) ms." -ForegroundColor Green
            }

            $i += $BatchSz
        }
    }
    catch {
        Write-Error "Error during bulk delete for ${TableName}: $($_.Exception.Message)"
    }
    finally {
        if ($conn.State -eq [System.Data.ConnectionState]::Open) {
            $conn.Close()
        }
    }
}

function Get-InvoiceIdSubQuery {
    <#
    .SYNOPSIS
        Builds the WHERE clause subquery for invoice IDs, respecting exclusions.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][int]$TargetPeriodId,
        [int[]]$ExcludedIds = @()
    )

    $excludedFilter = ""
    if ($ExcludedIds.Count -gt 0) {
        $excludedFilter = " AND InvoiceID NOT IN ($($ExcludedIds -join ','))"
    }

    return "SELECT InvoiceID FROM Invoices WHERE PeriodID = $TargetPeriodId$excludedFilter"
}

# =============================================================================
# 4. Main Execution
# =============================================================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " BILLING PERIOD RESET: $Environment"      -ForegroundColor Cyan
Write-Host " PeriodID: $PeriodID | Batch Size: $BatchSize" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

if (-not $PSCmdlet.ShouldProcess("PeriodID $PeriodID on $Environment", "Delete all invoice data")) {
    return
}

# Build subqueries
$invoiceIDSubQuery = Get-InvoiceIdSubQuery -TargetPeriodId $PeriodID -ExcludedIds $Config.ExcludedInvoiceIds
$serverIDSubQuery  = "SELECT InvoiceServerID FROM InvoiceServerDetails WHERE InvoiceID IN ($invoiceIDSubQuery)"

# --- Step 1: Clean Hangfire Tables ---
if ($Config.CleanHangfire -and $Config.HangfireSchemas.Count -gt 0) {
    Write-Host "--- Step 1: Cleaning Hangfire Instances ---" -ForegroundColor Cyan

    foreach ($Schema in $Config.HangfireSchemas) {
        $hangfireQuery = @"
DELETE FROM [$Schema].[AggregatedCounter];
DELETE FROM [$Schema].[Counter];
DELETE FROM [$Schema].[JobParameter];
DELETE FROM [$Schema].[JobQueue];
DELETE FROM [$Schema].[List];
DELETE FROM [$Schema].[Set];
DELETE FROM [$Schema].[State];
DELETE FROM [$Schema].[Hash];
DELETE FROM [$Schema].[Job];
"@
        $result = Invoke-SqlNonQuery -Query $hangfireQuery -ConnectionStr $ConnectionString -ActionDescription "Cleaning Hangfire schema [$Schema]"
        if ($null -ne $result) {
            Write-Host "  Hangfire schema [$Schema] cleared." -ForegroundColor Green
        }
    }
    Write-Host ""
}

# --- Step 2: Create Performance Index ---
Write-Host "--- Step 2: Optimising for Deletion (Performance Index) ---" -ForegroundColor Cyan
$createIndexQuery = @"
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_InvoiceServerDetails_InvoiceId' AND object_id = OBJECT_ID('dbo.InvoiceServerDetails'))
    DROP INDEX [IX_InvoiceServerDetails_InvoiceId] ON [dbo].[InvoiceServerDetails];

CREATE NONCLUSTERED INDEX [IX_InvoiceServerDetails_InvoiceId] ON [dbo].[InvoiceServerDetails] ([InvoiceID] ASC);
"@

$result = Invoke-SqlNonQuery -Query $createIndexQuery -ConnectionStr $ConnectionString -ActionDescription "creating performance index"
if ($null -ne $result) {
    Write-Host "  Index [IX_InvoiceServerDetails_InvoiceId] created/recreated." -ForegroundColor Green
}
else {
    Write-Host "  Index creation failed. Continuing with deletion..." -ForegroundColor Yellow
}
Write-Host ""

# --- Step 3: Approval-specific BillingLogFile dependencies ---
if ($Config.HasBillingLogDeps) {
    Write-Host "--- Step 3: Cleaning BillingLogFile Dependencies ---" -ForegroundColor Cyan

    $billingLogFileIdSubQuery = "SELECT Id FROM BillingLogFiles WHERE InvoiceServerDetailsID IN ($serverIDSubQuery)"
    $jouleChartingSubQuery    = "SELECT Id FROM JouleChartingLogAggregates WHERE BillingLogFileId IN ($billingLogFileIdSubQuery)"

    $result = Invoke-SqlNonQuery -Query "DELETE FROM JouleChartingLogAggregates WHERE Id IN ($jouleChartingSubQuery)" -ConnectionStr $ConnectionString -ActionDescription "Deleting JouleChartingLogAggregates" -Timeout 300
    if ($null -ne $result) {
        Write-Host "  Deleted $($result.RowsAffected) rows from JouleChartingLogAggregates in $($result.ElapsedMs) ms." -ForegroundColor Green
    }

    $result = Invoke-SqlNonQuery -Query "DELETE FROM BillingLogFiles WHERE InvoiceServerDetailsID IN ($serverIDSubQuery)" -ConnectionStr $ConnectionString -ActionDescription "Deleting BillingLogFiles" -Timeout 300
    if ($null -ne $result) {
        Write-Host "  Deleted $($result.RowsAffected) rows from BillingLogFiles in $($result.ElapsedMs) ms." -ForegroundColor Green
    }
    Write-Host ""
}

# --- Step 4: Delete Server Login Dependencies ---
Write-Host "--- Step 4: Deleting Server Login Dependencies ---" -ForegroundColor Yellow

foreach ($entry in $Config.ServerIdMapping.GetEnumerator()) {
    $table    = $entry.Key
    $idColumn = $entry.Value

    $deleteQuery = "DELETE FROM $table WHERE $idColumn IN ($serverIDSubQuery)"
    $result = Invoke-SqlNonQuery -Query $deleteQuery -ConnectionStr $ConnectionString -ActionDescription "deleting from $table"

    if ($null -ne $result) {
        Write-Host "  Deleted $($result.RowsAffected) rows from $table ($idColumn) in $($result.ElapsedMs) ms." -ForegroundColor Green
    }
}
Write-Host ""

# --- Step 5: Delete Invoice-Level Dependencies ---
Write-Host "--- Step 5: Deleting Invoice-Level Dependencies ---" -ForegroundColor Yellow

foreach ($entry in $Config.InvoiceIdMapping.GetEnumerator()) {
    $table    = $entry.Key
    $idColumn = $entry.Value

    $deleteQuery = "DELETE FROM $table WHERE $idColumn IN ($invoiceIDSubQuery)"
    $result = Invoke-SqlNonQuery -Query $deleteQuery -ConnectionStr $ConnectionString -ActionDescription "deleting from $table"

    if ($null -ne $result) {
        Write-Host "  Deleted $($result.RowsAffected) rows from $table ($idColumn) in $($result.ElapsedMs) ms." -ForegroundColor Green
    }
}
Write-Host ""

# --- Step 6: Bulk Delete InvoiceServerDetails ---
Write-Host "--- Step 6: Bulk Deleting InvoiceServerDetails (Batch: $BatchSize) ---" -ForegroundColor Yellow
$bulkStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
Invoke-SqlBulkDelete -TableName "InvoiceServerDetails" -IdColumnName "InvoiceServerID" -IdListQuery $serverIDSubQuery -ConnectionStr $ConnectionString -BatchSz $BatchSize
$bulkStopwatch.Stop()
Write-Host "  Total time: $($bulkStopwatch.Elapsed.ToString('mm\:ss\.fff'))" -ForegroundColor Cyan
Write-Host ""

# --- Step 7: Bulk Delete Invoices ---
Write-Host "--- Step 7: Bulk Deleting Invoices (Batch: $BatchSize) ---" -ForegroundColor Yellow
$bulkStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
Invoke-SqlBulkDelete -TableName "Invoices" -IdColumnName "InvoiceID" -IdListQuery $invoiceIDSubQuery -ConnectionStr $ConnectionString -BatchSz $BatchSize
$bulkStopwatch.Stop()
Write-Host "  Total time: $($bulkStopwatch.Elapsed.ToString('mm\:ss\.fff'))" -ForegroundColor Cyan
Write-Host ""

# --- Step 8: Enable Automatic Calculation ---
Write-Host "--- Step 8: Enabling Automatic Calculation ---" -ForegroundColor Cyan
$updateQuery = "UPDATE InvoicePeriods SET AutomaticInvoiceCreation = 1 WHERE PeriodID = $PeriodID"
$result = Invoke-SqlNonQuery -Query $updateQuery -ConnectionStr $ConnectionString -ActionDescription "Enabling AutomaticInvoiceCreation"

if ($null -ne $result -and $result.RowsAffected -gt 0) {
    Write-Host "  AutomaticInvoiceCreation enabled for PeriodID $PeriodID." -ForegroundColor Green
}

# --- Step 9: Approval-specific AppSettingsProfiles cleanup ---
if ($Environment -eq 'Approval') {
    Write-Host "`n--- Step 9: Cleaning AppSettingsProfiles (Approval Lock) ---" -ForegroundColor Cyan
    $result = Invoke-SqlNonQuery -Query "DELETE FROM AppSettingsProfiles WHERE ID > 600" -ConnectionStr $ConnectionString -ActionDescription "Deleting Approval Test Lock" -Timeout 300
    if ($null -ne $result) {
        Write-Host "  Deleted $($result.RowsAffected) AppSettingsProfiles rows." -ForegroundColor Green
    }
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host " COMPLETE: Billing reset finished for PeriodID $PeriodID ($Environment)" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green
