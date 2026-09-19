@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0install-native-host.ps1" %*
exit /b %ERRORLEVEL%
