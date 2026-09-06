$ErrorActionPreference = 'Stop'

# 固定revisionのsdkmanagerへすべての引数をそのまま渡す。
$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDirectory 'env.ps1')
& (Join-Path $env:ANDROID_SDK_ROOT 'cmdline-tools\15859902\bin\sdkmanager.bat') @args
exit $LASTEXITCODE
