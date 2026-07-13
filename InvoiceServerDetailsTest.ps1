# ==========================================
# 1. Variables & Connection Setup
# ==========================================

# Updated list of Invoice Server IDs
$invoiceServerIds = "127887,127597,127786,127833,127472,125840,127824,127897,126761,124361,126822,127737,127875,127767"
$connectionString = "Data Source=localhost;Initial Catalog=TRAYINVOICE;Integrated Security=True;TrustServerCertificate=True;Encrypt=True"

# Define the SQL Queries using Here-Strings
$query1 = @"
UPDATE Invoices 
SET StatusID = 1, Approver = NULL, AppId = NULL
WHERE InvoiceID IN(
	SELECT InvoiceID FROM InvoiceServerDetails WHERE InvoiceServerID IN ($invoiceServerIds)
)
"@

$query2 = @"
UPDATE InvoiceLineItems SET Complete = 0 WHERE InvoiceID IN(
	SELECT InvoiceID FROM InvoiceServerDetails WHERE InvoiceServerID IN ($invoiceServerIds)
)
"@

# ==========================================
# 2. Execute SQL Queries
# ==========================================

try {
    Write-Host "Connecting to database..." -ForegroundColor Cyan
    $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
    $connection.Open()

    Write-Host "Executing Update 1 (Invoices)..."
    $command1 = $connection.CreateCommand()
    $command1.CommandText = $query1
    $rowsAffected1 = $command1.ExecuteNonQuery()
    Write-Host "Rows updated in Invoices: $rowsAffected1" -ForegroundColor Green

    Write-Host "Executing Update 2 (InvoiceLineItems)..."
    $command2 = $connection.CreateCommand()
    $command2.CommandText = $query2
    $rowsAffected2 = $command2.ExecuteNonQuery()
    Write-Host "Rows updated in InvoiceLineItems: $rowsAffected2" -ForegroundColor Green

} catch {
    Write-Host "An error occurred executing SQL: $_" -ForegroundColor Red
} finally {
    if ($connection.State -eq 'Open') {
        $connection.Close()
        Write-Host "Database connection closed." -ForegroundColor Cyan
    }
}

# ==========================================
# 3. Open Chrome Tabs
# ==========================================

Write-Host "Opening Chrome tabs..." -ForegroundColor Cyan

# Split the string into an array and filter out duplicate IDs
$idArray = $invoiceServerIds -split ',' | Select-Object -Unique

foreach ($id in $idArray) {
    $url = "https://localhost:59127/InvoiceServerDetails/Details/$id"
    
    try {
        Start-Process "chrome.exe" -ArgumentList $url
        Start-Sleep -Milliseconds 200 # Brief pause to prevent browser stuttering
    } catch {
        Write-Host "Failed to open Chrome for ID $id. Is Chrome installed and in your PATH?" -ForegroundColor Red
    }
}

Write-Host "Script complete!" -ForegroundColor Green