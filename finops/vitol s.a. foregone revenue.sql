USE TRAYINVOICE

DECLARE @TargetCompanyID INT = 197; 

-- 1. Define Targets
DECLARE @TargetUsers TABLE (username VARCHAR(50) COLLATE Latin1_General_CI_AI);
INSERT INTO @TargetUsers VALUES ('amp'), ('nir'), ('moi');

;WITH 
-- Get all relevant invoices for this company (All Time)
TargetInvoices AS (
    SELECT I.InvoiceID, I.PeriodID, P.PeriodName
    FROM Invoices I
    JOIN InvoiceProfiles IP ON I.InvoiceProfileID = IP.InvoiceProfileID
    JOIN InvoicePeriods P ON I.PeriodID = P.PeriodID
    WHERE IP.CompanyID = @TargetCompanyID 
      AND I.StatusID = 4 -- Printed invoices only
),

-- Map Raw Logins to a broad "Billing Group" (Trader vs ReadOnly)
UserClassifications AS (
    SELECT 
        L.InvoiceServerID,
        L.username,
        L.concession,
        ISD.InvoiceID, 
        L.ApplicationNameSimple, 
        CASE 
            WHEN L.usertype IN ('Trader', 'ReadWrite API', 'DMA Trader', 'ICE Trader', 'ICE Endex Trader') THEN 'Trader'
            WHEN L.usertype IN ('ReadOnly', 'ReadOnly API', 'JM ReadOnly', 'DA ReadOnly User') THEN 'Read-only'
            ELSE 'Other' 
        END AS BillingGroup
    FROM InvoiceServerLogins L
    JOIN InvoiceServerDetails ISD ON L.InvoiceServerID = ISD.InvoiceServerID 
    WHERE L.username IS NOT NULL
),

-- Calculate Baseline Counts (Paying Users) PER INVOICE and PER GROUP
BaselineCounts AS (
    SELECT 
        UC.InvoiceID,
        UC.BillingGroup,
        COUNT(DISTINCT UC.username) as ExistingCount
    FROM UserClassifications UC
    JOIN TargetInvoices TI ON UC.InvoiceID = TI.InvoiceID
    WHERE UC.concession = 0 -- Paying users
    GROUP BY UC.InvoiceID, UC.BillingGroup
),

-- Identify our Target Concession Users and rank them
TargetStack AS (
    SELECT 
        UC.InvoiceID,
        UC.username,
        UC.BillingGroup,
        ROW_NUMBER() OVER (PARTITION BY UC.InvoiceID, UC.BillingGroup ORDER BY UC.username) as StackPosition
    FROM UserClassifications UC
    JOIN TargetInvoices TI ON UC.InvoiceID = TI.InvoiceID
    WHERE UC.username IN (SELECT username FROM @TargetUsers)
      AND UC.concession = 1 -- Only if they were actually concessioned
    GROUP BY UC.InvoiceID, UC.username, UC.BillingGroup
),

-- Calculate the Theoretical Index
CalculatedPositions AS (
    SELECT 
        TI.PeriodID,
        TI.PeriodName,
        TI.InvoiceID,
        TS.username,
        TS.BillingGroup,
        ISNULL(BC.ExistingCount, 0) + TS.StackPosition AS TheoreticalIndex
    FROM TargetStack TS
    JOIN TargetInvoices TI ON TS.InvoiceID = TI.InvoiceID
    LEFT JOIN BaselineCounts BC ON TS.InvoiceID = BC.InvoiceID AND TS.BillingGroup = BC.BillingGroup
)

-- Final Output: Join back to raw details
SELECT 
    CP.PeriodID,
    CP.PeriodName,
    CP.InvoiceID,
    L.InvoiceServerID,
    CP.username,
    L.ApplicationNameSimple,
    L.usertype AS OriginalUserType,
    CP.BillingGroup,
    CP.TheoreticalIndex,
    ILB.Description AS BandMatched,
    ILB.Cost AS TheoreticalCost
FROM CalculatedPositions CP
JOIN InvoiceLicenceBands ILB ON CP.InvoiceID = ILB.InvoiceID
-- Join back to Raw Logs to get the specific Server/App details
JOIN InvoiceServerDetails ISD ON CP.InvoiceID = ISD.InvoiceID
JOIN InvoiceServerLogins L ON ISD.InvoiceServerID = L.InvoiceServerID 
    AND L.username = CP.username
    AND L.concession = 1 
WHERE 
    -- 1. Range Match
    CP.TheoreticalIndex >= ILB.Min 
    AND CP.TheoreticalIndex <= ILB.Max
    
    -- 2. Band Description Match
    AND (
        (CP.BillingGroup = 'Trader' AND ILB.Description LIKE '%Trader%')
        OR 
        (CP.BillingGroup = 'Read-only' AND ILB.Description LIKE '%Read-only%')
        OR
        (ILB.LicenceBandTypeID = 1) 
    )

    -- 3. Ensure the Raw Login row matches the Billing Group we calculated
    AND (
        (CP.BillingGroup = 'Trader' AND L.usertype IN ('Trader', 'ReadWrite API', 'DMA Trader', 'ICE Trader', 'ICE Endex Trader'))
        OR
        (CP.BillingGroup = 'Read-only' AND L.usertype IN ('ReadOnly', 'ReadOnly API', 'JM ReadOnly', 'DA ReadOnly User'))
    )

ORDER BY CP.PeriodID, CP.username, L.ApplicationNameSimple;