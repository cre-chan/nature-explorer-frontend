$ErrorActionPreference = 'Stop'

# 固定SDKの環境変数を、このPowerShellプロセス内へ読み込む。
$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDirectory 'env.ps1')

# Java Propertiesで安全に扱えるよう、Windowsの区切り文字をスラッシュへ変換する。
$sdkPath = $env:ANDROID_SDK_ROOT.Replace('\', '/')
$flutterPath = $env:FLUTTER_ROOT.Replace('\', '/')
$content = "sdk.dir=$sdkPath`nflutter.sdk=$flutterPath`n"

# local.propertiesをUTF-8（BOMなし）で生成し、リポジトリには含めない。
$ProjectRoot = Split-Path -Parent $ScriptDirectory
$properties = Join-Path $ProjectRoot 'android\local.properties'
$encoding = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText($properties, $content, $encoding)
