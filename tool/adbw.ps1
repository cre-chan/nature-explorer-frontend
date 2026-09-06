$ErrorActionPreference = 'Stop'

# ユーザー専用Android SDKのADBへすべての引数をそのまま渡す。
$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDirectory 'env.ps1')
& (Join-Path $env:ANDROID_SDK_ROOT 'platform-tools\adb.exe') @args
exit $LASTEXITCODE
