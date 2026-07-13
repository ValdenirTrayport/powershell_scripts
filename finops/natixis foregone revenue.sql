
SELECT P.PeriodID 
	  ,P.PeriodName
	  ,I.InvoiceID
	  ,SRV.InvoiceServerID
	  ,L.username	  
	  ,COUNT(*) AS [Concessioned Logins]
	  ,ILB.Cost
	  ,OtherReadOnlyUsers.CountOfOtherReadOnlyUsers
	  ,TraderUsers.CountOfTradeUsers
FROM Invoices I
JOIN InvoiceProfiles IP ON I.InvoiceProfileID = IP.InvoiceProfileID
JOIN InvoicePeriods P ON P.PeriodID = I.PeriodID
JOIN InvoiceServerDetails SRV ON I.InvoiceID = SRV.InvoiceID
JOIN InvoiceServerLogins L ON L.InvoiceServerID = SRV.InvoiceServerID
JOIN InvoiceLicenceBands ILB ON ILB.InvoiceID = I.InvoiceID
CROSS APPLY (SELECT count(*) CountOfOtherReadOnlyUsers FROM InvoiceServerLogins ROL WHERE ROL.InvoiceServerID = SRV.InvoiceServerID AND ROL.usertype = 'ReadOnly' AND ROL.concession = 0) OtherReadOnlyUsers
CROSS APPLY (SELECT count(*) CountOfTradeUsers FROM InvoiceServerLogins RWL WHERE RWL.InvoiceServerID = SRV.InvoiceServerID AND RWL.usertype = 'Trader' AND RWL.concession = 0) TraderUsers
WHERE 1=1
  AND IP.CompanyID = 1157
  AND L.concession = 1
  AND L.username IN ('1821_NATX-API', '1821_NATX-Curve')
  --AND ILB.LicenceBandTypeID = 3
  AND ILB.Description = 'Read-Only Users Fee'
  AND I.StatusID = 4
GROUP BY P.PeriodID 
	  ,P.PeriodName
	  ,I.InvoiceID
	  ,SRV.InvoiceServerID
	  ,L.username
	  ,OtherReadOnlyUsers.CountOfOtherReadOnlyUsers
	  ,TraderUsers.CountOfTradeUsers
	  ,ILB.Cost
ORDER BY P.PeriodID

