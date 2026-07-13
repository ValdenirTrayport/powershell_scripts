use PROD_AGGREGATION;

SELECT c.CompanyName,
c.CompanyId,
r.Name as [RouteName],
c.IsEnabled AS [CompanyEnabled],
r.IsEnabled AS [RouteEnabled],
u.Login,
u.IsEnabled AS [TradelogicApiEnabled],
MAX(t.DealDate) AS [MaxDealDate]
FROM [PROD_AGGREGATION].[dbo].[CompanyIdentify] i
INNER JOIN RoutesToMarket r on r.RouteId = i.IdentifiableCompanyRouteId
INNER JOIN Companies c ON c.CompanyId = i.IdentifiableCompanyId
LEFT OUTER JOIN BrokerPrivateTrade t on t.CompanyId = i.IdentifiableCompanyId and i.IdentifiableCompanyRouteId = t.RouteId
LEFT OUTER JOIN Users u ON u.CompanyId = i.IdentifiableCompanyId AND (u.Login LIKE '%TRSEE%' or Login like 'tradelogic%' )
WHERE i.CompanyId = 556 -- Mercuria
AND Login is not NULL
AND u.IsEnabled = 1
AND c.IsEnabled = 1
AND r.IsEnabled = 1
AND t.DealDate >= '2025-10-01' and t.DealDate < '2025-11-01'
GROUP BY c.CompanyName, c.CompanyId, r.Name, c.IsEnabled, r.IsEnabled, u.Login, u.IsEnabled
HAVING MAX(t.DealDate) is not NULL;