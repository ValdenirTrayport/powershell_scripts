#Requires -Version 5.1
<#
.SYNOPSIS
    Automates the deployment and rollback of performance tuning indexes
    and lock escalation overrides for TRAYINVOICE.

.PARAMETER Action
    Implement or Revert the index changes.

.PARAMETER Environment
    Target environment: Local, Test, Approval, or ApprovalSlim.

.EXAMPLE
    .\Invoke-IndexAutomation.ps1 -Action Implement -Environment Local

.EXAMPLE
    .\Invoke-IndexAutomation.ps1 -Action Revert -Environment Test
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Implement', 'Revert')]
    [string]$Action,

    [Parameter(Mandatory)]
    [ValidateSet('Local', 'Test', 'Approval', 'ApprovalSlim')]
    [string]$Environment
)

$ErrorActionPreference = 'Stop'

# ==============================================================================
# 1. LOAD CONNECTION STRING FROM CENTRALISED CONFIG
# ==============================================================================
$configPath = Join-Path -Path $PSScriptRoot -ChildPath "config\ConnectionStrings.json"
$connections = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$selectedConn = $connections.$Environment.ConnectionString

# ==============================================================================
# 2. DEFINE SQL SCRIPTS
# ==============================================================================

$implementScript = @"
/* PHASE 1: Invoice Server Detail Indexes */
CREATE INDEX IX_InvoiceServerLogins_InvoiceServerID ON InvoiceServerLogins(InvoiceServerID);
CREATE INDEX IX_InvoiceServerDetailUsers_InvoiceServerID ON InvoiceServerDetailUsers(InvoiceServerID);
CREATE INDEX IX_BillingLogFiles_InvoiceServerDetailsID ON BillingLogFiles(InvoiceServerDetailsID);
CREATE INDEX IX_InvoiceServerTradesignalLogins_InvoiceServerId ON InvoiceServerTradesignalLogins(InvoiceServerId);
CREATE INDEX IX_InvoiceServerT7Logins_InvoiceServerId ON InvoiceServerT7Logins(InvoiceServerId);
CREATE INDEX IX_InvoiceServerGmePassThroughLogins_InvoiceServerId ON InvoiceServerGmePassThroughLogins(InvoiceServerId);
CREATE INDEX IX_InvoiceServerMercuriaSingleScreenLogins_InvoiceServerId ON InvoiceServerMercuriaSingleScreenLogins(InvoiceServerId);
CREATE INDEX IX_InvoiceServerGVPortalLogins_InvoiceServerID ON InvoiceServerGVPortalLogins(InvoiceServerID);
CREATE INDEX IX_InvoiceServerMdeUserLogins_InvoiceServerID ON InvoiceServerMdeUserLogins(InvoiceServerID);
CREATE INDEX IX_InvoiceServerUpstreamLogins_InvoiceServerID ON InvoiceServerUpstreamLogins(InvoiceServerID);
CREATE INDEX IX_InvoiceServerMdeDataFeedLogins_InvoiceServerID ON InvoiceServerMdeDataFeedLogins(InvoiceServerID);
CREATE INDEX IX_InvoiceServerRemitLogins_InvoiceServerId ON InvoiceServerRemitLogins(InvoiceServerId);
CREATE INDEX IX_InvoiceServerTvcmLogins_InvoiceServerId ON InvoiceServerTvcmLogins(InvoiceServerId);
CREATE INDEX IX_InvoiceServerICELogins_InvoiceServerID ON InvoiceServerICELogins(InvoiceServerID);
CREATE INDEX IX_InvoiceServerJouleChartingLogins_InvoiceServerDetailsID ON InvoiceServerJouleChartingLogins(InvoiceServerDetailsID);
CREATE INDEX IX_InvoiceServerDataAnalyticsLogins_InvoiceServerId ON InvoiceServerDataAnalyticsLogins(InvoiceServerId);
CREATE INDEX IX_InvoiceServerJTTLogins_InvoiceServerID ON InvoiceServerJTTLogins(InvoiceServerID);
CREATE INDEX IX_InvoiceServerATLogins_InvoiceServerID ON InvoiceServerATLogins(InvoiceServerID);
CREATE INDEX IX_InvoiceServerJMLogins_InvoiceServerID ON InvoiceServerJMLogins(InvoiceServerID);
GO

/* PHASE 2: Invoice Header & Line Item Foreign Keys */
CREATE NONCLUSTERED INDEX [IX_InvoiceLineItems_InvoiceID] ON [dbo].[InvoiceLineItems] ([InvoiceID]);
CREATE NONCLUSTERED INDEX [IX_InvoiceLicenceBands_InvoiceID] ON [dbo].[InvoiceLicenceBands] ([InvoiceID]);
CREATE NONCLUSTERED INDEX [IX_InvoiceUserNumbers_InvoiceID] ON [dbo].[InvoiceUserNumbers] ([InvoiceID]);
CREATE NONCLUSTERED INDEX [IX_InvoiceTradesignalLicenceBands_InvoiceId] ON [dbo].[InvoiceTradesignalLicenceBands] ([InvoiceId]);
CREATE NONCLUSTERED INDEX [IX_InvoiceAtLicenceBands_InvoiceID] ON [dbo].[InvoiceAtLicenceBands] ([InvoiceID]);
CREATE NONCLUSTERED INDEX [IX_InvoiceIceRollingLicenceBands_InvoiceId] ON [dbo].[InvoiceIceRollingLicenceBands] ([InvoiceId]);
GO

/* Phase 3: COVERING & COMPOSITE INDEXES */
CREATE NONCLUSTERED INDEX [IX_InvoiceLicenceBandUserType_InvoiceLicenceBandID_UserTypeID] 
ON [dbo].[InvoiceLicenceBandUserType] ([InvoiceLicenceBandID] ASC, [UserTypeID] ASC)
INCLUDE ([InvoiceLicenceBandUserTypeID], [Ratio]) WITH (SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF) ON [PRIMARY];

CREATE NONCLUSTERED INDEX [IX_InvoiceProfileLineItems_InvoiceProfileID_LineItemID_EndPeriod] 
ON [dbo].[InvoiceProfileLineItems] ([InvoiceProfileID] ASC, [InvoiceProfileLineItemID] ASC, [EndPeriodID] ASC)
INCLUDE ([StartPeriodID]) WITH (SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF) ON [PRIMARY];

CREATE NONCLUSTERED INDEX [IX_Invoices_InvoiceProfileID_PeriodID_StatusID] 
ON [dbo].[Invoices] ([InvoiceProfileID] ASC, [PeriodID] ASC, [StatusID] ASC)
WITH (SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF) ON [PRIMARY];

CREATE NONCLUSTERED INDEX [IX_Invoices_InvoiceProfileID_InvoiceID_Covering] 
ON [dbo].[Invoices] ([InvoiceProfileID] ASC, [InvoiceID] ASC)
INCLUDE ([PeriodID],[InvoiceTypeID],[StatusID],[PaymentDueDate],[GrossCostGBP],[NetCost],[GrossCost],
         [FXRate],[InvoiceFileName],[InternalNote],[ExternalNote],[PrintDate],[SageInvoiceDate],
         [ExportedToSageFile],[PDFBatched],[PaidDate],[InvoiceSent],[InvoicePaid],[TaxRate],[PrepayStatement],
         [IgnoreProfileExternalNote],[DoNotAttachToEmail],[Approver],[ExportedToOracleDate],[ClientManagerNote],
         [ReasonID],[AppId],[Notifications],[CreationDate],[InvoiceNumber],[InvoiceAccrualCategoryId],
         [InvoiceAccrualOtherReason],[InvoicePaidStatusId],[BillingPeriod]) 
WITH (SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF) ON [PRIMARY];
GO

/* Phase 4: Index Profile Configurations */
CREATE NONCLUSTERED INDEX [IX_InvoiceProfileTradesignalLicenceBands_InvoiceProfileId] ON [dbo].[InvoiceProfileTradesignalLicenceBands] ([InvoiceProfileId]);
CREATE NONCLUSTERED INDEX [IX_InvoiceProfileAtLicenceBands_InvoiceProfileID] ON [dbo].[InvoiceProfileAtLicenceBands] ([InvoiceProfileID]);
CREATE NONCLUSTERED INDEX [IX_InvoiceProfileIceRollingLicenceBands_InvoiceProfileId] ON [dbo].[InvoiceProfileIceRollingLicenceBands] ([InvoiceProfileId]);
CREATE NONCLUSTERED INDEX [IX_InvoiceProfileEmaLicenceBands_InvoiceProfileID] ON [dbo].[InvoiceProfileEmaLicenceBands] ([InvoiceProfileID]);
CREATE NONCLUSTERED INDEX [IX_InvoiceProfileLicenceBands_InvoiceProfileID] ON [dbo].[InvoiceProfileLicenceBands] ([InvoiceProfileID]);
CREATE NONCLUSTERED INDEX [IX_LicenceServers_InvoiceProfileID] ON [dbo].[LicenceServers] ([InvoiceProfileID]);
CREATE NONCLUSTERED INDEX [IX_ProfileTags_InvoiceProfileId] ON [dbo].[ProfileTags] ([InvoiceProfileId]);
GO

/* Phase 5: Disable Lock Escalation */
ALTER TABLE [dbo].[Invoices] SET (LOCK_ESCALATION = DISABLE);
GO

ALTER TABLE [dbo].[InvoiceProfileLineItems] SET (LOCK_ESCALATION = DISABLE);
GO

ALTER TABLE [dbo].[InvoiceServerDetails] SET (LOCK_ESCALATION = DISABLE);
GO
"@

$revertScript = @"
/* ROLLBACK PHASE 5: Re-Enable Lock Escalation */
ALTER TABLE [dbo].[Invoices] SET (LOCK_ESCALATION = TABLE);
GO

ALTER TABLE [dbo].[InvoiceProfileLineItems] SET (LOCK_ESCALATION = TABLE);
GO

ALTER TABLE [dbo].[InvoiceServerDetails] SET (LOCK_ESCALATION = TABLE);
GO

/* ROLLBACK PHASE 4 */
DROP INDEX IF EXISTS [IX_ProfileTags_InvoiceProfileId] ON [dbo].[ProfileTags];
DROP INDEX IF EXISTS [IX_LicenceServers_InvoiceProfileID] ON [dbo].[LicenceServers];
DROP INDEX IF EXISTS [IX_InvoiceProfileLicenceBands_InvoiceProfileID] ON [dbo].[InvoiceProfileLicenceBands];
DROP INDEX IF EXISTS [IX_InvoiceProfileEmaLicenceBands_InvoiceProfileID] ON [dbo].[InvoiceProfileEmaLicenceBands];
DROP INDEX IF EXISTS [IX_InvoiceProfileIceRollingLicenceBands_InvoiceProfileId] ON [dbo].[InvoiceProfileIceRollingLicenceBands];
DROP INDEX IF EXISTS [IX_InvoiceProfileAtLicenceBands_InvoiceProfileID] ON [dbo].[InvoiceProfileAtLicenceBands];
DROP INDEX IF EXISTS [IX_InvoiceProfileTradesignalLicenceBands_InvoiceProfileId] ON [dbo].[InvoiceProfileTradesignalLicenceBands];
GO

/* ROLLBACK PHASE 3 */
DROP INDEX IF EXISTS [IX_Invoices_InvoiceProfileID_InvoiceID_Covering] ON [dbo].[Invoices];
DROP INDEX IF EXISTS [IX_Invoices_InvoiceProfileID_PeriodID_StatusID] ON [dbo].[Invoices];
DROP INDEX IF EXISTS [IX_InvoiceProfileLineItems_InvoiceProfileID_LineItemID_EndPeriod] ON [dbo].[InvoiceProfileLineItems];
DROP INDEX IF EXISTS [IX_InvoiceLicenceBandUserType_InvoiceLicenceBandID_UserTypeID] ON [dbo].[InvoiceLicenceBandUserType];
GO

/* ROLLBACK PHASE 2 */
DROP INDEX IF EXISTS [IX_InvoiceIceRollingLicenceBands_InvoiceId] ON [dbo].[InvoiceIceRollingLicenceBands];
DROP INDEX IF EXISTS [IX_InvoiceAtLicenceBands_InvoiceID] ON [dbo].[InvoiceAtLicenceBands];
DROP INDEX IF EXISTS [IX_InvoiceTradesignalLicenceBands_InvoiceId] ON [dbo].[InvoiceTradesignalLicenceBands];
DROP INDEX IF EXISTS [IX_InvoiceUserNumbers_InvoiceID] ON [dbo].[InvoiceUserNumbers];
DROP INDEX IF EXISTS [IX_InvoiceLicenceBands_InvoiceID] ON [dbo].[InvoiceLicenceBands];
DROP INDEX IF EXISTS [IX_InvoiceLineItems_InvoiceID] ON [dbo].[InvoiceLineItems];
GO

/* ROLLBACK PHASE 1 */
DROP INDEX IF EXISTS [IX_InvoiceServerJMLogins_InvoiceServerID] ON [dbo].[InvoiceServerJMLogins];
DROP INDEX IF EXISTS [IX_InvoiceServerATLogins_InvoiceServerID] ON [dbo].[InvoiceServerATLogins];
DROP INDEX IF EXISTS [IX_InvoiceServerJTTLogins_InvoiceServerID] ON [dbo].[InvoiceServerJTTLogins];
DROP INDEX IF EXISTS [IX_InvoiceServerDataAnalyticsLogins_InvoiceServerId] ON [dbo].[InvoiceServerDataAnalyticsLogins];
DROP INDEX IF EXISTS [IX_InvoiceServerJouleChartingLogins_InvoiceServerDetailsID] ON [dbo].[InvoiceServerJouleChartingLogins];
DROP INDEX IF EXISTS [IX_InvoiceServerICELogins_InvoiceServerID] ON [dbo].[InvoiceServerICELogins];
DROP INDEX IF EXISTS [IX_InvoiceServerTvcmLogins_InvoiceServerId] ON [dbo].[InvoiceServerTvcmLogins];
DROP INDEX IF EXISTS [IX_InvoiceServerRemitLogins_InvoiceServerId] ON [dbo].[InvoiceServerRemitLogins];
DROP INDEX IF EXISTS [IX_InvoiceServerMdeDataFeedLogins_InvoiceServerID] ON [dbo].[InvoiceServerMdeDataFeedLogins];
DROP INDEX IF EXISTS [IX_InvoiceServerUpstreamLogins_InvoiceServerID] ON [dbo].[InvoiceServerUpstreamLogins];
DROP INDEX IF EXISTS [IX_InvoiceServerMdeUserLogins_InvoiceServerID] ON [dbo].[InvoiceServerMdeUserLogins];
DROP INDEX IF EXISTS [IX_InvoiceServerGVPortalLogins_InvoiceServerID] ON [dbo].[InvoiceServerGVPortalLogins];
DROP INDEX IF EXISTS [IX_InvoiceServerMercuriaSingleScreenLogins_InvoiceServerId] ON [dbo].[InvoiceServerMercuriaSingleScreenLogins];
DROP INDEX IF EXISTS [IX_InvoiceServerGmePassThroughLogins_InvoiceServerId] ON [dbo].[InvoiceServerGmePassThroughLogins];
DROP INDEX IF EXISTS [IX_InvoiceServerT7Logins_InvoiceServerId] ON [dbo].[InvoiceServerT7Logins];
DROP INDEX IF EXISTS [IX_InvoiceServerTradesignalLogins_InvoiceServerId] ON [dbo].[InvoiceServerTradesignalLogins];
DROP INDEX IF EXISTS [IX_BillingLogFiles_InvoiceServerDetailsID] ON [dbo].[BillingLogFiles];
DROP INDEX IF EXISTS [IX_InvoiceServerDetailUsers_InvoiceServerID] ON [dbo].[InvoiceServerDetailUsers];
DROP INDEX IF EXISTS [IX_InvoiceServerLogins_InvoiceServerID] ON [dbo].[InvoiceServerLogins];
GO
"@

# ==============================================================================
# 3. EXECUTION
# ==============================================================================
$scriptToRun = if ($Action -eq 'Implement') { $implementScript } else { $revertScript }

Write-Host "`n=============================================" -ForegroundColor Cyan
Write-Host " INDEX AUTOMATION: $Action on $Environment"    -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

if (-not $PSCmdlet.ShouldProcess("$Environment database", "$Action performance indexes")) {
    return
}

Write-Host "`nConnecting to database..." -ForegroundColor Cyan

$connection = $null
try {
    $connection = New-Object System.Data.SqlClient.SqlConnection
    $connection.ConnectionString = $selectedConn
    $connection.Open()

    # Split the script by 'GO' to handle batches (.NET SqlCommand doesn't support GO natively)
    $batches = $scriptToRun -split "(?m)^\s*GO\s*$"

    $command = $connection.CreateCommand()
    $command.CommandTimeout = 300

    $batchCount = 1
    foreach ($batch in $batches) {
        if (-not [string]::IsNullOrWhiteSpace($batch)) {
            Write-Host "  Executing Batch $batchCount..." -ForegroundColor DarkGray
            $command.CommandText = $batch
            $command.ExecuteNonQuery() | Out-Null
            $batchCount++
        }
    }

    Write-Host "`n=============================================" -ForegroundColor Green
    Write-Host " SUCCESS: $Action completed on $Environment." -ForegroundColor Green
    Write-Host "=============================================" -ForegroundColor Green
}
catch {
    Write-Error "Failed to execute $Action on ${Environment}: $($_.Exception.Message)"
}
finally {
    if ($null -ne $connection -and $connection.State -eq 'Open') {
        $connection.Close()
    }
}