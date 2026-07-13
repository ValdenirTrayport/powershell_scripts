$ConnectionString = "Data Source=localhost;Initial Catalog=TRAYINVOICE;Integrated Security=True;TrustServerCertificate=True;" 
$Schemas = @("HangFire", "Calculation")

foreach ($Schema in $Schemas) {
    Write-Host "Cleaning schema: [$Schema]..." -ForegroundColor Cyan

    $SqlQuery = @"
    -- Disable constraints to allow truncation/deletion
    EXEC sp_MSforeachtable 'ALTER TABLE ? NOCHECK CONSTRAINT ALL'

    -- Clear tables in specific order to avoid dependency issues
    DELETE FROM [$Schema].[AggregatedCounter];
    DELETE FROM [$Schema].[Counter];
    DELETE FROM [$Schema].[JobParameter];
    DELETE FROM [$Schema].[JobQueue];
    DELETE FROM [$Schema].[List];
    DELETE FROM [$Schema].[Set];
    DELETE FROM [$Schema].[State];
    DELETE FROM [$Schema].[Hash];
    
    -- Delete jobs last
    DELETE FROM [$Schema].[Job];

    -- Re-enable constraints
    EXEC sp_MSforeachtable 'ALTER TABLE ? WITH CHECK CHECK CONSTRAINT ALL'
"@

    try {
        $Connection = New-Object Microsoft.Data.SqlClient.SqlConnection($ConnectionString)
        $Command = $Connection.CreateCommand()
        $Command.CommandText = $SqlQuery
        
        $Connection.Open()
        $RowsAffected = $Command.ExecuteNonQuery()
        $Connection.Close()
        
        Write-Host "Successfully cleared [$Schema]." -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to clear [$Schema]: $($_.Exception.Message)"
    }
}