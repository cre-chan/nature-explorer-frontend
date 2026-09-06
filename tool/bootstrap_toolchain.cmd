@echo off
REM Execution Policyをシステム変更せず、この1プロセスだけBypassしてbootstrapを起動する。
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0bootstrap_toolchain.ps1" %*
exit /b %ERRORLEVEL%
