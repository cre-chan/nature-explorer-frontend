$ErrorActionPreference = 'Stop'

# 専用SDKだけをこのプロセスへ設定し、Gradle用パスを同期してからFlutterを実行する。
$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDirectory 'env.ps1')
& (Join-Path $ScriptDirectory 'configure_android.ps1')
& (Join-Path $env:FLUTTER_ROOT 'bin\flutter.bat') @args
exit $LASTEXITCODE
