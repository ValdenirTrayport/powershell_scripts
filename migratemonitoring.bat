@echo off
REM Creating a Newline variable (the two blank lines are required!)
set NLM=^


set NL=^^^%NLM%%NLM%^%NLM%%NLM%
REM Example Usage:
REM echo There should be a newline%NL%inserted here.

cls
call flyway --version

@echo %NL%%NL%Running flyway on Monitoring
@echo Running the following command:
@echo    flyway migrate
@echo       -url=jdbc:sqlserver://localhost;encrypt=true;databaseName=TCMSOrionDashboard;integratedSecurity=true;trustServerCertificate=true
@echo       -locations=filesystem:C:\dev\BusinessSystems.Monitoring\.migrations

flyway migrate -url=jdbc:sqlserver://localhost;encrypt=true;databaseName=TCMSOrionDashboard;integratedSecurity=true;trustServerCertificate=true -locations=filesystem:C:\dev\BusinessSystems.Monitoring\.migrations