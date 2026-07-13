USE TRAYINVOICE;
GO

DECLARE 
	@SERVER_NAME VARCHAR(8),
	@ERR_MSG NVARCHAR(150)

SET @SERVER_NAME = 'DEVWS543';
SET @ERR_MSG = 'This script can only be run in the server ' + @SERVER_NAME

IF @@SERVERNAME <> @SERVER_NAME
	THROW 50001, @ERR_MSG, 1

--REMOVING ALL EXISTING SETTINGS
DELETE dbo.AppSettings
DELETE dbo.AppSettingsProfiles

SET XACT_ABORT ON
BEGIN TRAN

DECLARE @profileName NVARCHAR(50) = 'Debug';
INSERT INTO AppSettingsProfiles (Name, [Description]) VALUES (@profileName, 'Values for both MVC and WebForms on Test server')

DECLARE @appSettingsProfileId INT;
SELECT @appSettingsProfileId = ID FROM AppSettingsProfiles WHERE Name = @profileName
 
---INSERTS----

INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'BaseFont', 'E:\\BARRI\\Admin\\\MyriadWebPro.ttf')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'ContigoLegacyInvoiceTemplate', 'E:\Barri\Admin\ContigoLegacyInvoiceTemplate.pdf')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'ContigoTrayportInvoiceTemplate', 'E:\Barri\Admin\ContigoTrayportInvoiceTemplate.pdf')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'CountUserExePath', 'E:\\Barri\\CountUsers\\CountUsers.Exe')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'PDFTemplateCredit', 'E:\\BARRI\\Admin\\CreditNoteTemplate.pdf')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'PDFTemplateInvoice', 'E:\\BARRI\\Admin\\InvoiceTemplate.pdf')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'PDFTrayportLogo', 'E:\\BARRI\\Admin\\TrayportLogo.PNG')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'SymbolFont',  'E:\Barri\Admin\FreeSerif.ttf')

INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'SQLServer', 'localhost')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'RemitCompleteDBConnectionString', 'Data Source=bs-tsql14;Initial Catalog=RMIT_V_TPT_00_REMIT;Trusted_Connection=True;Connect Timeout=60; Application Name=REMIT_BARRI')


INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'JouleDirectProdDbConnectionString', 'Data Source=bs-tsql14;Initial Catalog=UserAnalysis;Trusted_Connection=True')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'JouleDirectProdDbBillingView', 'JouleDirectBillingView')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'JouleDirectUserAnalysisCopyDbConnectionString', 'Data Source=bs-tsql14;Initial Catalog=UserAnalysis;Trusted_Connection=True')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'JouleDirectUserAnalysisCopyBillingView', 'JouleDirectBillingView')


INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'AppName', 'TEST TEST TEST ALEX BARRi TEST TEST TEST TEST')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'BarriPath', 'http://localhost:50100/')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'invoice_link', 'http://localhost:50100/Invoices/Details.aspx?InvoiceID=')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'newApprovalPageLink', 'http://localhost:13060')


INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'BusinessSystemsPagePassword', 'AQAAANCMnd8BFdERjHoAwE/Cl+sBAAAAmUFTt6chqEW2BvihWZcKwQAAAAACAAAAAAADZgAAwAAAABAAAACNglJw+tbiJTpVyUYgSsnlAAAAAASAAACgAAAAEAAAAB55807AJZ/ffYcwhFaoiPsIAAAAqZGhbeJec7QUAAAA0NRHd8SF3tlE7ZayOIRVfyxNSiI=')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'CRMUserNamePassword', 'AQAAANCMnd8BFdERjHoAwE/Cl+sBAAAAmUFTt6chqEW2BvihWZcKwQAAAAACAAAAAAADZgAAwAAAABAAAADB6rts6LkQjhi2y2OHzJJ0AAAAAASAAACgAAAAEAAAAE5y5arx80FGKyB80/zJOzIQAAAAKAGUgTE9Pp7ZTLP7jQcUFBQAAAAykSJfFpF9f/ta52Z1tQT5sVAZzw==')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'CherwellPassword', 'AQAAANCMnd8BFdERjHoAwE/Cl+sBAAAAmUFTt6chqEW2BvihWZcKwQAAAAACAAAAAAADZgAAwAAAABAAAAC9XmPjTMIkVciFTZhfLflYAAAAAASAAACgAAAAEAAAADSRtkoNqYLFNsscLBgQobAQAAAAE/cnzBHDme2TPrMN0R8etBQAAAACz0DcY8R1OPIquLXPEDu59e7lRg==')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'CountUserDBPassword', 'AQAAANCMnd8BFdERjHoAwE/Cl+sBAAAAmUFTt6chqEW2BvihWZcKwQAAAAACAAAAAAADZgAAwAAAABAAAAC9XmPjTMIkVciFTZhfLflYAAAAAASAAACgAAAAEAAAADSRtkoNqYLFNsscLBgQobAQAAAAE/cnzBHDme2TPrMN0R8etBQAAAACz0DcY8R1OPIquLXPEDu59e7lRg==')




INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'ADPassword', 'Wibble9999')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'ADUsername', 'TIMS2')

INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'AdministratorADGroup', 'FG Business Systems')



INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'BillableIceCompanies', 'ICE,ICEE,ICEF,ICEM,ICET,ICEO,ICES,ICEU')

INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'CRMOrgUri', 'https://crm/Trayport/XrmServices/2011/Organization.svc')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'CRMUserName', 'dynamicsadmin')

INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'CherwellConnection', '[common]trayport.cherwellondemand.com')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'CherwellModuleName', '')

INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'CherwellUsername', 'barri')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'ClientManagerBrokerADGroup', 'Res Invoicing System Broker Approver')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'ClientManagerCrossADGroup', 'Res Invoicing System All Invoices Approver')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'ClientManagerExchangeADGroup', 'Res Invoicing System Exchange Approver')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'ClientManagerTraderADGroup', 'Res Invoicing System Trader Approver')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'ClientValidationEnabled', 'true')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'CommercialSupportBrokerADGroup', 'Res Invoicing System Broker Commercial Support')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'CommercialSupportExchangeADGroup', 'Res Invoicing System Exchange Commercial Support')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'CommercialSupportTraderADGroup', 'Res Invoicing System Trader Commercial Support')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'ConsultancyPath', '\\kaizar\support\Billing\Consultancy Billing')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'ContigoApproverADGroup', 'Res Invoicing System Contigo Approver')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'ContigoCalculateADGroup', 'Res Invoicing System Contigo Invoice Calculate')

INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'CountUserDBLogin', 'countusers')

INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'CountUserDefaultParametersBSB', 'BtsConnector*,GlobalVision,Global Vision,GV API,GV API*,GV8API,GV8API*,GV API Translator,Exchange Gateway,TradingGateway,Trading Gateway,GV8 Implied Price Calculator,GV8 FixGateway Client,ClearingGateway.Service,GV8 Clearing, BatchAPI_Trayport,CBOE Trade Reporter,Commodities.Services.Service,EAClient,EnergieAG.GetTrades,ExxetaTrayportConnector_GFI,ExxetaTrayportConnector_ICAP,ExxetaTrayportConnector_TFS,FirstQuote Service,GshGlobalVisionServer,GV8APIClient,GVWebpageFeeder,Link.Ren.Atr.TrayPortFileIntegration,LoaderCore,LoaderCore.vshost,MarexSpectron.Bloomberg.Service,MarexSpectron.Remit.vshost,natGAS.GlobalVision.BrokerService,python,RMDS,TPort2GuiBos8,TPort2RMDSService,Tradition.Services.IdexFeed,Trayport,Trayport GlobalVision,Trayport.vshost,TrayportServer,TrayportSubscriberWinService,UDXCacheServerGRIFFIN,UDXCacheServerICAP,UDXCacheServerSPECTRON,VantageTradeMonitor,vb6,Joule,Trayport Joule,Joule*')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'CountUserDefaultParametersESB', 'BtsConnector*,GlobalVision,Global Vision,GV8 Clearing,GlobalVision Deal Editor,GV API,GV API*,GV8API,GV8API*,GV API Translator,Exchange Gateway,TradingGateway,Trading Gateway,GV8 Implied Price Calculator,GV8 FixGateway Client, BatchAPI_Trayport,CBOE Trade Reporter,Commodities.Services.Service,EAClient,EnergieAG.GetTrades,ExxetaTrayportConnector_GFI,ExxetaTrayportConnector_ICAP,ExxetaTrayportConnector_TFS,FirstQuote Service,GshGlobalVisionServer,GV8APIClient,GVWebpageFeeder,Link.Ren.Atr.TrayPortFileIntegration,LoaderCore,LoaderCore.vshost,MarexSpectron.Bloomberg.Service,MarexSpectron.Remit.vshost,natGAS.GlobalVision.BrokerService,python,RMDS,TPort2GuiBos8,TPort2RMDSService,Tradition.Services.IdexFeed,Trayport,Trayport GlobalVision,Trayport.vshost,TrayportServer,TrayportSubscriberWinService,UDXCacheServerGRIFFIN,UDXCacheServerICAP,UDXCacheServerSPECTRON,VantageTradeMonitor,vb6,Joule,Trayport Joule,Joule*')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'CountUserDefaultParametersIMP', 'BtsConnector*,GlobalVision,Global Vision,GV API,GV API*,GV8API,GV8API*,TradingGateway,Trading Gateway,GV8APIClient,Trayport GlobalVision,Joule,Trayport Joule,Joule*')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'CountUserDefaultParametersTSB', 'BtsConnector*,GlobalVision,Global Vision,GV API*,Joule,Trayport Joule,Joule*')

INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'CreditNoteNotifcationTo', 'alex.weir@trayport.com')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'CreditNoteNotificationFrom', 'businesssystems@trayport.com')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'DynamicsBillableTimeValue', '100000010')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'EndOfBillingRunDay', '8')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'FinanceADGroup', 'Res Invoicing System Finance')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'FirstLevelCreditNoteApproval', 'Res Invoicing System FirstLevelCreditNoteApproval')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'FourthLevelCreditNoteApproval', 'Res Invoicing System FourthLevelCreditNoteApproval')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'InvoiceContigoEmailCCAddress', 'businesssystemstest@trayport.com')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'InvoiceContigoEmailFrom', 'accounts@contigosoftware.com')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'InvoiceContigoEmailFromDisplayName', 'Accounts')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'InvoiceEmailCCAddress', 'businesssystemstest@trayport.com')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'InvoiceEmailFrom', 'businesssystems@trayport.com')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'InvoiceEmailFromDisplayName', 'Business Systems')

INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'MultiClientCustomerPortalFilePath', 'saas\multi-client customer portal')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'OrmbFtpHost', '')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'OrmbFtpPassword', '')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'OrmbFtpUserName', '')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'OrmbUploadToFtp', 'FALSE')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'OtherApproverADGroup', 'Res Invoicing System Other Approver')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'PDFOutputPath', '\\kaizar\commercial\invoices\TEST_TEST_TEST')


INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'ReportOutputPath', '\\kaizar\commercial\invoices\TEST_TEST_TEST\Reports')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'SMTPHost', '172.16.1.125')

INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'SecondLevelCreditNoteApproval', 'Res Invoicing System SecondLevelCreditNoteApproval')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'StartingPeriod', '221')

INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'TemplateImagesPath', '\\kaizar\commercial\invoices\Email_Images\')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'ThirdLevelCreditNoteApproval', 'Res Invoicing System ThirdLevelCreditNoteApproval')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'TradesignalReportPath', '\\kaizar\commercial\Invoices\TEST_TEST_TEST\Tradesignal_Tier_2_Report')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'TrayportIncSageFileName', 'Inc')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'TrayportLtdSageFileName', 'Ltd')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'Version', '3.38.1')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'apiURL', 'http://api.local.yahoo.com/MapsService/V1/geocode?appid=7nloTx3V34EtMkvjojNd_2dexo4R9bRKXe.eJdGDgbeeqY4g13uCwNIQMP1d4nAlJLyWh0jt3.c-')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'billingHandoverEmailCc', 'alex.weir@trayport.com')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'billingHandoverEmailFrom', 'businesssystems@trayport.com')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'billingHandoverEmailTo', 'alex.weir@trayport.com')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'businesssystems', 'Business Systems<alex.weir@trayport.com>')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'cts', 'Commercial Team Support<alex.weir@trayport.com>')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'finance', 'Finance<alex.weir@trayport.com>')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'googleKey', 'ABQIAAAAj8SNC6yXMki7x7Tguc92ExSNR1TQHyfz0uHjGQa52kmPsa2o-RTCrHm2Q9umhr4F9kxzpKuhBUC8YA')

INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'postBillingHandoverEmailSubject', 'Post Billing Handover')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'preBillingHandoverEmailSubject', 'Pre Billing Handover')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'threadLimit', '100')

INSERT INTO AppSettings (AppSettingsProfileId,Name,Value) VALUES(@appSettingsProfileId, 'ForceHttps', 'false')
INSERT INTO AppSettings (AppSettingsProfileId,Name,Value) VALUES(@appSettingsProfileId, 'MvcHttpsPort', '9443')
INSERT INTO AppSettings (AppSettingsProfileId,Name,Value) VALUES(@appSettingsProfileId, 'WebFormsHttpsPort', '443')

INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'SendAllInvoicesSubject', 'Barri Automated Invoice Sending')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'SendAllInvoiceEmailTime', '5:30pm')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'BusinessSystemsTest', 'businesssystemstest@trayport.com')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'ConsultancyEmailAddresses', 'businesssystems@trayport.com,businesssystems@trayport.com')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'TrayportCreditNoteApprovalEmailRecipient', 'alex.weir@trayport.com')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'ContigoCreditNoteApprovalEmailRecipient', 'alex.weir@trayport.com')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'JouleDirectProdDbCompaniesTable', 'JouleDirectCompanies')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'JouleDirectProdDbUsersTable', 'JouleDirectUsers')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'EmaTradeDataCollectionDownloadFolder', '\\kaizar\Operations\itsm\Business Systems\Products\EmaTradeDataCollection\Testing')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'SimpleCsvFolder', 'E:\EMATesting')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'DetailedCsvFolder', 'E:\EMATesting')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'MissingScrubbedSeqItems', 'E:\EMATesting')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'ExcelBillingStorageWhenFilledFolder', 'E:\EMATesting\FilledExcelTemplate')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'ExchangeDataConnectionString', '')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'EmaTradeDataConnectionString', '')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'JouleDirectImportTimespanInDays', '-7')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'WorkdayUsername', 'trayportbarribilling@tmx')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'WorkdayPassword', 'AQAAANCMnd8BFdERjHoAwE/Cl+sBAAAAl7UfdsXVR0yVVEtHnyTN2gAAAAACAAAAAAADZgAAwAAAABAAAACzQ/q282hev7BuY6sD2ID6AAAAAASAAACgAAAAEAAAAMAouwmhFx/Rtsl7YqtOQ9oQAAAAKQg+56sByLqMmlY7n6xitRQAAADdE3j9zV40G2dfPabc6DF6SaloeA==')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'WorkdayRevenueEndpoint', 'https://wd3-impl-services1.workday.com/ccx/service/tmx/Revenue_Management/v29.1')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'WorkdayHrEndpoint', 'https://wd3-impl-services1.workday.com/ccx/service/tmx/Human_Resources/v29.1')



/* DO NOT CHANGE - THESE CONFIG VALUES SHOULD ALWAYS BE LIVE VALUES */
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'LiveServiceAccount', 'HQ\IIS_InvSys')
INSERT INTO AppSettings (AppSettingsProfileId, Name, Value) VALUES (@appSettingsProfileId, 'LiveMachineName', 'IS-BARRI')



---INSERTS----

COMMIT TRAN
SET XACT_ABORT OFF


UPDATE InvoicePeriods
SET AutomaticInvoiceCreation = 0