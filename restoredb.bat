:BEGIN
echo off
cls
whoami /groups | find "S-1-16-12288" && set ELEVATED=true || set ELEVATED=false
IF %ELEVATED%==true GOTO ADMINRUN

rem net.exe session 1>NUL 2>NUL || (Echo This script requires elevated rights. & Exit /b 1)
echo ********************************************
echo *    PLEASE SELECT DATABASE TO RESTORE     *
echo ********************************************
echo * (A)nalysis Data                          *
echo * (B)usSysHangfire                         *
echo * (E)maTradeData                           *
echo *  E(v)ents                                *
echo *  E(x)changeData                          *
echo * (J)oule Direct                           *
echo * (R)evenueDb                              *
echo * (S)cheduledJobs (TODO needs script)      *
echo * (T)rayinvoice                            *
echo *  Trayinvoice from BS-TSQL(1)4            *
echo *  T(c)msOrionDashboard                    *
echo * TC(M)S_RefData                           *
echo * (U)serAnalysis                           *
echo ********************************************

set /p option=

IF "%option%"=="a" GOTO ANALYSISDATA
IF "%option%"=="A" GOTO ANALYSISDATA

IF "%option%"=="b" GOTO BUSSYSHANGFIRE
IF "%option%"=="B" GOTO BUSSYSHANGFIRE

IF "%option%"=="e" GOTO EMATRADEDATA
IF "%option%"=="E" GOTO EMATRADEDATA

IF "%option%"=="v" GOTO EVENTS
IF "%option%"=="V" GOTO EVENTS

IF "%option%"=="j" GOTO JOULEDIRECT
IF "%option%"=="J" GOTO JOULEDIRECT

IF "%option%"=="x" GOTO EXCHANGEDATA
IF "%option%"=="X" GOTO EXCHANGEDATA

IF "%option%"=="r" GOTO REVENUEDB
IF "%option%"=="R" GOTO REVENUEDB

IF "%option%"=="t" GOTO TRAYINVOICE
IF "%option%"=="T" GOTO TRAYINVOICE

IF "%option%"=="1" GOTO TRAYINVOICEBSTSQL14

IF "%option%"=="c" GOTO TCMSORIONDASHBOARD
IF "%option%"=="C" GOTO TCMSORIONDASHBOARD

IF "%option%"=="m" GOTO TCMSREFDATA
IF "%option%"=="M" GOTO TCMSREFDATA

IF "%option%"=="u" GOTO USERANALYSIS
IF "%option%"=="U" GOTO USERANALYSIS

echo.
	echo.
	echo Please make your selection with the options in brackets.
	echo (Case is not important)
	set /p option=	
	GOTO BEGIN

:ANALYSISDATA
	set databasename=RestoreAnalysisData
	GOTO RESTORE
:BUSSYSHANGFIRE
	set databasename=BusSysHangfire
	GOTO RESTORE
:EMATRADEDATA
	set databasename=RestoreEmaTradeData
	GOTO RESTORE
:EVENTS
	set databasename=RestoreEvents
	GOTO RESTORE
:EXCHANGEDATA
	set databasename=RestoreExchangeData
	GOTO RESTORE
:JOULEDIRECT
set databasename=RestoreJouleDirect
	GOTO RESTORE
:REVENUEDB
	set databasename=RestoreRevenueDb
	GOTO RESTORE
:TRAYINVOICE
	set databasename=RestoreTrayInvoice
	GOTO RESTORE
:TRAYINVOICEBSTSQL14
	set databasename=RestoreTrayInvoiceFromBSTSQL14
	GOTO RESTORE
:TCMSORIONDASHBOARD
	set databasename=RestoreTCMSOrionDashboard
	GOTO RESTORE
:TCMSREFDATA
	set databasename=RestoreTCMSRefData
	GOTO RESTORE
:USERANALYSIS
	set databasename=RestoreUserAnalysis

:RESTORE
	call PowerShell.exe -ExecutionPolicy Bypass -File "C:\scripts\Restore Database Backup\psscripts\%databasename%.ps1"

:FINISH

	echo.
	echo.
	echo Database %databasename% restored.
	echo Do you want to restore another database? (Y/N)
	
	set /p option=
	
	IF "%option%"=="n" GOTO END
	IF "%option%"=="N" GOTO END
	IF "%option%"=="y" GOTO BEGIN
	IF "%option%"=="Y" GOTO BEGIN
	
	echo.
	echo Please type Y for yes or N for no.
	GOTO FINISH

:END

    CLS
	GOTO EXIT
	
:ADMINRUN
	
	echo This script cannot be run with priviledges

:EXIT