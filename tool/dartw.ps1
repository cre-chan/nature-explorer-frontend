$ErrorActionPreference = 'Stop'

# Flutter同梱の固定Dart SDKへすべての引数をそのまま渡す。
$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDirectory 'env.ps1')
& (Join-Path $env:FLUTTER_ROOT 'bin\dart.bat') @args
exit $LASTEXITCODE
