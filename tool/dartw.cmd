@echo off
REM 固定DartのPowerShell wrapperへ、利用者の引数をそのまま渡す。
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0dartw.ps1" %*
exit /b %ERRORLEVEL%
