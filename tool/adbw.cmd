@echo off
REM 専用Android SDKのADB wrapperへ、利用者の引数をそのまま渡す。
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0adbw.ps1" %*
exit /b %ERRORLEVEL%
