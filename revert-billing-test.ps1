<#
.SYNOPSIS
Safely creates a temporary index for performance, then deletes records related to a specific PeriodID from various Invoice tables in SQL Server.

.PARAMETER PeriodID
The identifier for the period whose related invoice data should be deleted.

.EXAMPLE
.\Delete-InvoiceData.ps1 -PeriodID 410

.NOTES
The index is dropped and recreated for consistency, preventing 'already exists' errors.
#>
param(
    [Parameter(Mandatory=$true)]
    [int]$PeriodID
)
cls
# --- ⚙️ Configuration ---
# **FIXED CONNECTION STRING**
$ConnectionString = "Data Source=bs-tsql22;Initial Catalog=TRAYINVOICE;Integrated Security=True;TrustServerCertificate=True;" 

$BatchSize = 25
# --- 🔑 Column Mapping (Server ID) ---
$ServerIdMapping = @{
    "InvoiceServerICELogins"              = "InvoiceServerID"
    "InvoiceServerJouleChartingLogins"    = "InvoiceServerDetailsID" 
    "InvoiceServerTradesignalLogins"      = "InvoiceServerId"
    "InvoiceServerGmePassThroughLogins"   = "InvoiceServerId"
    "InvoiceServerMercuriaSingleScreenLogins" = "InvoiceServerId"
    "InvoiceServerATLogins"               = "InvoiceServerID"
    "InvoiceServerTvcmLogins"             = "InvoiceServerId"
    "InvoiceServerJMLogins"               = "InvoiceServerID"
	"InvoiceServerT7Logins"				  = "InvoiceServerId"
}

# --- 🔑 Column Mapping (Invoice ID) ---
$InvoiceIdMapping = @{
    "InvoiceTags"                         = "InvoiceId"
    "EmailSent"                           = "InvoiceID"
    "InvoiceRejections"                   = "InvoiceID"
    "InvoiceEmaLicenceBands"              = "InvoiceID"
	"InvoiceMetaData"					  = "InvoiceID"
}
# -----------------------------------


function Execute-SqlNonQuery {
    param(
        [string]$Query,
        [string]$ConnectionStr,
        [string]$ActionDescription = "executing SQL query" 
    )
    
    $conn = New-Object System.Data.SqlClient.SqlConnection $ConnectionStr
    $cmd = New-Object System.Data.SqlClient.SqlCommand $Query, $conn
    
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
        Write-Error "Error while $($ActionDescription): $($_.Exception.Message)"
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
    param(
        [string]$TableName,
        [string]$IdColumnName,
        [string]$IdListQuery,
        [string]$ConnectionStr,
        [int]$BatchSz
    )

    $idList = @()
    $conn = New-Object System.Data.SqlClient.SqlConnection $ConnectionStr
    $cmd = New-Object System.Data.SqlClient.SqlCommand $IdListQuery, $conn
    
    try {
        Write-Host "Fetching all $IdColumnName for $TableName..." -ForegroundColor Yellow
        $conn.Open()
        $reader = $cmd.ExecuteReader()
        while ($reader.Read()) {
            if (-not ($reader.IsDBNull(0))) {
                $idList += $reader.GetInt32(0) 
            }
        }
        $reader.Close()

        $totalIds = $idList.Count
        Write-Host "Found $totalIds records to delete from $TableName." -ForegroundColor Cyan

        if ($totalIds -eq 0) {
            Write-Host "No records to delete from $TableName. Skipping."
            return
        }

        $i = 0
        while ($i -lt $totalIds) {
            # Ensure the batch doesn't exceed the list bounds
            $batchIds = $idList[$i..[System.Math]::Min($i + $BatchSz - 1, $totalIds - 1)]
            
            $idString = $batchIds -join ','
            
            # Use the specified ID column name
            $deleteQuery = "DELETE $TableName WHERE $IdColumnName IN ($idString)"
            
            $rowsAffected = Execute-SqlNonQuery -Query $deleteQuery -ConnectionStr $ConnectionString -ActionDescription "bulk deleting $TableName batch"
            
            if ($rowsAffected -ne $null) {
                Write-Host "[$($i + 1) of $totalIds] Successfully deleted $($rowsAffected.RowsAffected) records from $TableName in $($rowsAffected.ElapsedMs) ms." -ForegroundColor Green
            }
            
            $i += $BatchSz
        }
    }
    catch {
        Write-Error "Error during bulk delete for $($TableName): $($_.Exception.Message)"
    }
    finally {
        if ($conn.State -eq [System.Data.ConnectionState]::Open) {
            $conn.Close()
        }
    }
}

# --- 🚀 Main Execution ---

Write-Host "Starting deletion process for PeriodID: $PeriodID" -ForegroundColor Yellow
Write-Host ""

# --- 1. Create Performance Index (with EXISTS check)
$createIndexQuery = @"
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_InvoiceServerDetails_InvoiceId' AND object_id = OBJECT_ID('dbo.InvoiceServerDetails'))
BEGIN
    DROP INDEX [IX_InvoiceServerDetails_InvoiceId] ON [dbo].[InvoiceServerDetails];
    PRINT 'Existing index IX_InvoiceServerDetails_InvoiceId dropped.';
END

CREATE NONCLUSTERED INDEX [IX_InvoiceServerDetails_InvoiceId] ON [dbo].[InvoiceServerDetails]
(
	[InvoiceID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
"@

Write-Host "Attempting to create/recreate performance index on [InvoiceServerDetails]..." -ForegroundColor Yellow

# This will no longer throw a terminating error if the index exists
$rows = Execute-SqlNonQuery -Query $createIndexQuery -ConnectionStr $ConnectionString -ActionDescription "creating performance index"

if ($rows -ne $null) {
    Write-Host "Index [IX_InvoiceServerDetails_InvoiceId] successfully created/recreated." -ForegroundColor Green
} else {
    Write-Host "⚠️ Index creation/recreation failed (check error messages above). Continuing with deletion..." -ForegroundColor Red
}

Write-Host ""

# --- 2. Execute Direct Dependent Deletions (Server Logins)
Write-Host "--- Starting direct dependent deletions (Server Logins) ---" -ForegroundColor Yellow

# Subquery to find relevant InvoiceServerIDs
$serverIDSubQuery = "SELECT InvoiceServerID FROM InvoiceServerDetails WHERE InvoiceID IN (SELECT InvoiceID FROM Invoices WHERE PeriodID = $PeriodID)"

foreach ($entry in $ServerIdMapping.GetEnumerator()) {
    $table = $entry.Name
    $idColumn = $entry.Value
    
    $deleteQuery = "DELETE $table WHERE $idColumn IN ($serverIDSubQuery)"
    $rows = Execute-SqlNonQuery -Query $deleteQuery -ConnectionStr $ConnectionString -ActionDescription "deleting from $table"
    
    if ($rows -ne $null) {
        Write-Host "Deleted $($rows.RowsAffected) records from $table (on column $idColumn) in $($rows.ElapsedMs) ms." -ForegroundColor Green
    }
}

# --- 3. Execute Direct Dependent Deletions (Invoices)
Write-Host "--- Starting direct dependent deletions (Tags, Email, Rejections, Licence Bands) ---" -ForegroundColor Yellow

# Subquery to find relevant InvoiceIDs
$invoiceIDSubQuery = "SELECT InvoiceID FROM Invoices WHERE PeriodID = $PeriodID"

foreach ($entry in $InvoiceIdMapping.GetEnumerator()) {
    $table = $entry.Name
    $idColumn = $entry.Value
    
    $deleteQuery = "DELETE $table WHERE $idColumn IN ($invoiceIDSubQuery)"
    $rows = Execute-SqlNonQuery -Query $deleteQuery -ConnectionStr $ConnectionString -ActionDescription "deleting from $table"
    
    if ($rows -ne $null) {
        Write-Host "Deleted $($rows.RowsAffected) records from $table (on column $idColumn) in $($rows.ElapsedMs) ms." -ForegroundColor Green
    }
}

Write-Host "--- Direct dependent deletions complete ---" -ForegroundColor Yellow
Write-Host ""

# --- 4. Bulk Delete for InvoiceServerDetails (Batch: $BatchSize)
Write-Host "--- Starting bulk delete for InvoiceServerDetails (Batch Size: $BatchSize) ---" -ForegroundColor Yellow
$serverDetailsIdQuery = "SELECT InvoiceServerID FROM InvoiceServerDetails WHERE InvoiceID IN (SELECT InvoiceID FROM Invoices WHERE PeriodID = $PeriodID)"
$bulkInvoiceServerDetailsStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
Invoke-SqlBulkDelete -TableName "InvoiceServerDetails" -IdColumnName "InvoiceServerID" -IdListQuery $serverDetailsIdQuery -ConnectionStr $ConnectionString -BatchSz $BatchSize
$bulkInvoiceServerDetailsStopwatch.Stop()
Write-Host "Total time for InvoiceServerDetails bulk delete: $($bulkInvoiceServerDetailsStopwatch.Elapsed.ToString('mm\:ss\.fff'))" -ForegroundColor Cyan
Write-Host "--- Bulk delete for InvoiceServerDetails complete ---" -ForegroundColor Yellow
Write-Host ""

# --- 5. Bulk Delete for Invoices (Batch: $BatchSize)
Write-Host "--- Starting bulk delete for Invoices (Batch Size: $BatchSize) ---" -ForegroundColor Yellow
$invoicesIdQuery = "SELECT InvoiceID FROM Invoices WHERE PeriodID = $PeriodID"
$bulkInvoicesStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
Invoke-SqlBulkDelete -TableName "Invoices" -IdColumnName "InvoiceID" -IdListQuery $invoicesIdQuery -ConnectionStr $ConnectionString -BatchSz $BatchSize
$bulkInvoicesStopwatch.Stop()
Write-Host "Total time for Invoices bulk delete: $($bulkInvoicesStopwatch.Elapsed.ToString('mm\:ss\.fff'))" -ForegroundColor Cyan
Write-Host "--- Bulk delete for Invoices complete ---" -ForegroundColor Yellow
Write-Host ""

# --- 6. Enable Automatic Calculation ---
Write-Host "`n--- Enabling Automatic Calculation ---" -ForegroundColor Cyan
$updateQuery = "UPDATE InvoicePeriods SET AutomaticInvoiceCreation = 1 WHERE PeriodID = $PeriodID"
$rows = Execute-SqlNonQuery -Query $updateQuery -ConnectionStr $ConnectionString -ActionDescription "Enabling Automatic Calculation"

Write-Host "✅ Deletion script finished."