@echo off
REM 固定FlutterのPowerShell wrapperへ、利用者の引数をそのまま渡す。
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0flutterw.ps1" %*
exit /b %ERRORLEVEL%
