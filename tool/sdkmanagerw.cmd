@echo off
REM 固定Android SDK Manager wrapperへ、利用者の引数をそのまま渡す。
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0sdkmanagerw.ps1" %*
exit /b %ERRORLEVEL%
