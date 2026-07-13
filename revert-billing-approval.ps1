<#
.SYNOPSIS
Safely creates a temporary index for performance.

1. Cleans Hangfire tables for [HangFire] and [Calculation] schemas.
2. Safely creates a temporary index for performance.
3. Deletes records related to a specific PeriodID from various Invoice tables.
4. Enables automatic invoice creation for the specified PeriodID.

.PARAMETER PeriodID
The identifier for the period whose related invoice data should be deleted.

.EXAMPLE
.\revert-billing-dev.ps1 -PeriodID 413

.NOTES
The index is dropped and recreated for consistency, preventing 'already exists' errors.
#>
param(
    [Parameter(Mandatory=$true)]
    [int]$PeriodID
)

# --- ⚙️ Configuration ---
$ConnectionString = "Data Source=bs-dsql22;Initial Catalog=TRAYINVOICE_SLIM;Integrated Security=True;TrustServerCertificate=True;"

$BatchSize = 50

# --- 🛡️ Exclusions - These invoices will be spared from deletion ---
$ExcludedInvoiceIds = @(
	
	#AddConcessionsTestFewSamples and AddConcessionsTestLots
    69582,69584,69589,69590,69592,69596,69600,69602,
    69603,
    69605,
    69608,
    69615,
    69617,
    69619,
    69620,
    69622,
    69625,
    69633,
    69635,
    69636,
    69642,
    69647,
    69651,
    69653,
    69654,
    69656,
    69658,
    69659,
    69660,
    69663,
    69665,
    69668,
    69671,
    69672,
    69674,
    69676,
    69679,
    69682,
    69683,
    69685,
    69687,
    69689,
    69692,
    69694,
    69696,
    69697,
    69703,
    69704,
    69706,
    69712,
    69713,
    69716,
    69718,
    69720,
    69722,
    69723,
    69728,
    69730,
    69731,
    69734,
    69739,
    69740,
    69744,
    69746,
    69747,
    69750,
    69755,
    69758,
    69759,
    69763,
    69765,
    69767,
    69770,
    69772,
    69774,
    69777,
    69778,
    69781,
    69784,
    69788,
    69792,
    69795,
    69796,
    69799,
    69800,
    69803,
    69807,
    69809,
    69810,
    69812,
    69816,
    69819,
    69820,
    69823,
    69829,
    69832,
    69833,
    69839,
    69840,
    69841,
    69845,
    69848,
    69851,
    69854,
    69855,
    69859,
    69862,
    69863,
    69866,
    69869,
    69870,
    69873,
    69875,
    69877,
    69882,
    69883,
    69885,
    69887,
    69890,
    69891,
    69894,
    69897,
    69898,
    69901,
    69903,
    69905,
    69907,
    69909,
    69911,
    69914,
    69916,
    69918,
    69919,
    69921,
    69923,
    69925,
    69927,
    69930,
    69932,
    69933,
    69935,
    69937,
    69938,
    69941,
    69944,
    69945,
    69947,
    69951,
    69954,
    69955,
    69960,
    69961,
    69965,
    69967,
    69969,
    69971,
    69973,
    69975,
    69978,
    69980,
    69981,
    69985,
    69986,
    69988,
    69991,
    69992,
    69994,
    69997,
    69999,
    70002,
    70004,
    70005,
    70008,
    70009,
    70011,
    70013,
    70016,
    70018,
    70023,
    70024,
    70027,
    70028,
    70031,
    70033,
    70036,
    70037,
    70041,
    70043,
    70045,
    70048,
    70049,
    70051,
    70053,
    70056,
    70058,
    70063,
    70064,
    70066,
    70068,
    70070,
    70075,
    70077,
    70079,
    70083,
    70087,
    70088,
    70091,
    70094,
    70096,
    70098,
    70099,
    70101,
    70103,
    70107,
    70109,
    70111,
    70113,
    70115,
    70119,
    70121,
    70123,
    70125,
    70128,
    70129,
    70131,
    70133,
    70136,
    70138,
    70140,
    70144,
    70145,
    70148,
    70150,
    70152,
    70154,
    70157,
    70160,
    70162,
    70164,
    70165,
    70168,
    70170,
    70171,
    70176,70177,70179,70183,70186,70188,70190,70191,70193,70196,70201,70202,70205,70208,70210,70214,70215,70218,70220,70223,70226,70227,
	
	69665, 69671, 69687, 69692, 70846,
	69668, 69689,
    75511, 82476, 85142, 85243, 86586, 86591, 86927, 87377,
    # Barri.ApprovalTests.InvoiceWriter tests
    76667,81507,86251,86329,86860,87269,87292,87461,88016,88190,88307,88354,88270,
    87446, 87509, 87580, 87869, 88126, 88268, 94196, 94408,
    94430, 94792, 94901, 94914, 95142, 95167, 95474, 96235,
    130697, 155092, 
    # InvoiceManagerTests (Jan2021) PowernextTgwSaasTigfInvoiceProfileId & NaturgasFynTgwJdProfileId
    113236, 113573, 155322, 170733, 81148, 80781,
    # AT Calculation (Mar-17)
    80571,80591,80657,80671,80676,80699,80701,80732,80749,
    80782,80789,80820,80886,80898,80923,80930,80941,80953,
    80981,80987,81019,81046,81060,81130,81194
    # AT Calculation (Apr-17)
    81228,81248,81312,81326,81332,81354,81356,81385,81402,
    81433,81440,81464,81470,81534,81548,81573,81580,81592,
    81606,81636,81642,81674,81701,81714,81787
    # EMA Profile Calculation Report Tests
    170410,170803,170765,170679,170411
)

$HangfireSchemas = @("HangFire", "BarriHangFire")

# --- 🔑 Column Mapping (Server ID) ---
$ServerIdMapping = @{
	"InvoiceServerDataAnalyticsLogins"			= "InvoiceServerId"
    "InvoiceServerICELogins"              		= "InvoiceServerID"
	"InvoiceServerUpstreamLogins"				= "InvoiceServerID"
    "InvoiceServerTradesignalLogins"      		= "InvoiceServerId"
    "InvoiceServerGmePassThroughLogins"   		= "InvoiceServerId"
    "InvoiceServerMercuriaSingleScreenLogins" 	= "InvoiceServerId"
	"InvoiceServerJouleChartingLogins"			= "InvoiceServerDetailsID"
    "InvoiceServerATLogins"               		= "InvoiceServerID"
    "InvoiceServerTvcmLogins"             		= "InvoiceServerId"
    "InvoiceServerJMLogins"               		= "InvoiceServerID"
    "InvoiceServerJTTLogins"           		    = "InvoiceServerID" 
    "InvoiceServerT7Logins"		  		    	= "InvoiceServerId"
    "InvoiceServerRemitLogins"		  	    	= "InvoiceServerId"
}

# --- 🔑 Column Mapping (Invoice ID) ---
$InvoiceIdMapping = @{
    "InvoiceTags"                         = "InvoiceId"
    "EmailSent"                           = "InvoiceID"
    "InvoiceRejections"                   = "InvoiceID"
    "InvoiceEmaLicenceBands"              = "InvoiceID"
    "InvoiceUserLogins"					  = "InvoiceID"
    "InvoiceSAASUserNames"				  = "InvoiceID"
	#"InvoiceMetaData"					  = "InvoiceID"
}

# -----------------------------------
function Execute-SqlNonQuery {
    param(
        [string]$Query,
        [string]$ConnectionStr,
        [string]$ActionDescription = "executing SQL query",
        [int]$Timeout = 120 # Added a default 2-minute timeout
    )
    
    $conn = New-Object System.Data.SqlClient.SqlConnection $ConnectionStr
    $cmd = New-Object System.Data.SqlClient.SqlCommand $Query, $conn
    $cmd.CommandTimeout = $Timeout # Set the timeout here
    
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

function Get-InvoiceIdSubQuery {
    param(
        [int]$TargetPeriodId,
        [int[]]$ExcludedIds
    )

    $excludedFilter = ""
    if ($ExcludedIds.Count -gt 0) {
        $excludedFilter = " AND InvoiceID NOT IN ($($ExcludedIds -join ','))"
    }

    return "SELECT InvoiceID FROM Invoices WHERE PeriodID = $TargetPeriodId$excludedFilter"
}

function Get-InvoiceServerIdSubQuery {
    param(
        [string]$InvoiceIdSubQuery
    )
    return "SELECT InvoiceServerID FROM InvoiceServerDetails WHERE InvoiceID IN ($InvoiceIdSubQuery)"
}

function Get-BillingLogFileIds {
    param(
        [string]$InvoiceServerIdSubQuery
    )
    return "SELECT Id FROM BillingLogFiles WHERE InvoiceServerDetailsID IN ($InvoiceServerIdSubQuery)"
}

function Get-JouleChartingLogAggregatesIds {
    param(
        [string]$BillingLogFileIdSubQuery
    )
    return "SELECT Id FROM JouleChartingLogAggregates WHERE BillingLogFileId IN ($BillingLogFileIdSubQuery)"
}

# --- 🚀 Main Execution ---

Write-Host "Starting deletion process for PeriodID: $PeriodID" -ForegroundColor Yellow
Write-Host ""

$invoiceIDSubQuery = Get-InvoiceIdSubQuery -TargetPeriodId $PeriodID -ExcludedIds $ExcludedInvoiceIds
$serverIDSubQuery = Get-InvoiceServerIdSubQuery -InvoiceIdSubQuery $invoiceIDSubQuery
$billingLogFileIdSubQuery = Get-BillingLogFileIds -InvoiceServerIdSubQuery $serverIDSubQuery
$jouleChartingLogAggregatesIdsSubQuery = Get-JouleChartingLogAggregatesIds -BillingLogFileIdSubQuery $billingLogFileIdSubQuery

Write-Host "`n$invoiceIDSubQuery" -ForegroundColor White
Write-Host "`n$serverIDSubQuery" -ForegroundColor Cyan

$rows = Execute-SqlNonQuery -Query "DELETE AppSettingsProfiles WHERE ID > 600" -ConnectionStr $ConnectionString -ActionDescription "Deleting Approval Test Lock" -Timeout 300

# --- 1. Clean Hangfire Tables ---
Write-Host "`n--- Step 1: Cleaning Hangfire Instances ---" -ForegroundColor Cyan
foreach ($Schema in $HangfireSchemas) {
    $HangfireQuery = @"
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
    #$res = Execute-SqlNonQuery -Query $HangfireQuery -ConnectionStr $ConnectionString -ActionDescription "Cleaning Hangfire Schema [$Schema]"
    Write-Host "Hangfire schema [$Schema] cleared." -ForegroundColor Green
}

# --- 2. Create Performance Index ---
Write-Host "`n--- Step 2: Optimizing Database for Deletion ---" -ForegroundColor Cyan
$createIndexQuery = @"
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_InvoiceServerDetails_InvoiceId' AND object_id = OBJECT_ID('dbo.InvoiceServerDetails'))
    DROP INDEX [IX_InvoiceServerDetails_InvoiceId] ON [dbo].[InvoiceServerDetails];

CREATE NONCLUSTERED INDEX [IX_InvoiceServerDetails_InvoiceId] ON [dbo].[InvoiceServerDetails] ([InvoiceID] ASC);
"@

Write-Host "Attempting to create/recreate performance index on [InvoiceServerDetails]..." -ForegroundColor Yellow


# --- 3. Execute Direct Dependency Deletions (BillingLogFiles)
Write-Host "`n--- Step 3: Starting direct dependency deletions (BillingLogFiles) ---" -ForegroundColor Yellow

$rows = Execute-SqlNonQuery -Query "DELETE FROM JouleChartingLogAggregates WHERE Id IN ($jouleChartingLogAggregatesIdsSubQuery)" -ConnectionStr $ConnectionString -ActionDescription "Deleting from JouleChartingLogAggregates (dependent on BillingLogFiles)" -Timeout 300
if ($rows -ne $null) {
    Write-Host "Deleted $($rows.RowsAffected) records from JouleChartingLogAggregates (dependency on BillingLogFiles) in $($rows.ElapsedMs) ms." -ForegroundColor Green
}

# --- 4. Execute Direct Dependency Deletions (Server Logins)
Write-Host "`n--- Step 4: Starting direct dependency deletions (Server Logins) ---" -ForegroundColor Yellow

$rows = Execute-SqlNonQuery -Query "DELETE FROM BillingLogFiles WHERE InvoiceServerDetailsID IN ($serverIDSubQuery)" -ConnectionStr $ConnectionString -ActionDescription "Deleting from BillingLogFiles" -Timeout 300
if ($rows -ne $null) {
    Write-Host "Deleted $($rows.RowsAffected) records from BillingLogFiles in $($rows.ElapsedMs) ms." -ForegroundColor Green
}

foreach ($entry in $ServerIdMapping.GetEnumerator()) {
    $table = $entry.Name
    $idColumn = $entry.Value
    
    $deleteQuery = "DELETE $table WHERE $idColumn IN ($serverIDSubQuery)"
    $rows = Execute-SqlNonQuery -Query $deleteQuery -ConnectionStr $ConnectionString -ActionDescription "deleting from $table"
    
    if ($rows -ne $null) {
        Write-Host "Deleted $($rows.RowsAffected) records from $table (on column $idColumn) in $($rows.ElapsedMs) ms." -ForegroundColor Green
    }
}

# --- 5. Execute Direct Dependency Deletions (Invoices)
Write-Host "`n--- Step 5: Starting direct dependency deletions (Tags, Email, Rejections, Licence Bands) ---" -ForegroundColor Yellow

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

# --- 6. Bulk Delete for InvoiceServerDetails (Batch: $BatchSize)
Write-Host "`n--- Step 6: Starting bulk delete for InvoiceServerDetails (Batch Size: $BatchSize) ---" -ForegroundColor Yellow
$serverDetailsIdQuery = $serverIDSubQuery
$bulkInvoiceServerDetailsStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
Invoke-SqlBulkDelete -TableName "InvoiceServerDetails" -IdColumnName "InvoiceServerID" -IdListQuery $serverDetailsIdQuery -ConnectionStr $ConnectionString -BatchSz $BatchSize
$bulkInvoiceServerDetailsStopwatch.Stop()
Write-Host "Total time for InvoiceServerDetails bulk delete: $($bulkInvoiceServerDetailsStopwatch.Elapsed.ToString('mm\:ss\.fff'))" -ForegroundColor Cyan
Write-Host "--- Bulk delete for InvoiceServerDetails complete ---" -ForegroundColor Yellow
Write-Host ""

# --- 7. Bulk Delete for Invoices (Batch: $BatchSize)
Write-Host "`n--- Step 7: Starting bulk delete for Invoices (Batch Size: $BatchSize) ---" -ForegroundColor Yellow
$invoicesIdQuery = $invoiceIDSubQuery
$bulkInvoicesStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
Invoke-SqlBulkDelete -TableName "Invoices" -IdColumnName "InvoiceID" -IdListQuery $invoicesIdQuery -ConnectionStr $ConnectionString -BatchSz $BatchSize
$bulkInvoicesStopwatch.Stop()
Write-Host "Total time for Invoices bulk delete: $($bulkInvoicesStopwatch.Elapsed.ToString('mm\:ss\.fff'))" -ForegroundColor Cyan
Write-Host "--- Bulk delete for Invoices complete ---" -ForegroundColor Yellow
Write-Host ""

# --- 8. Enable Automatic Calculation ---
Write-Host "`n--- Step 8: Enabling Automatic Calculation ---" -ForegroundColor Cyan
$updateQuery = "UPDATE InvoicePeriods SET AutomaticInvoiceCreation = 1 WHERE PeriodID = $PeriodID"
$rows = Execute-SqlNonQuery -Query $updateQuery -ConnectionStr $ConnectionString -ActionDescription "Enabling Automatic Calculation"

if ($rows -ne $null -and $rows.RowsAffected -gt 0) {
    Write-Host "Successfully enabled Automatic Calculation for PeriodID $PeriodID." -ForegroundColor Green
}

Write-Host "✅ Deletion script finished."