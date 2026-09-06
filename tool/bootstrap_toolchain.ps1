$ErrorActionPreference = 'Stop'

# スクリプト位置を基準に環境設定を読み込み、実行場所への依存をなくす。
$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDirectory 'env.ps1')

# 公式Flutter Windows SDKはx64配布のため、未対応CPUでは早期に停止する。
$architecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
if ($architecture -ne [System.Runtime.InteropServices.Architecture]::X64) {
    throw "Unsupported Windows CPU architecture: $architecture"
}

# .toolchain.lockと同じWindows x64向けURL・SHA-256を固定する。
$FlutterUrl = 'https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.47.2-stable.zip'
$FlutterSha = '37934f2128a55d77a38baba12fd611157ed23a47bf7d2b7d17e9e84da118409d'
$JavaUrl = 'https://api.adoptium.net/v3/binary/version/jdk-17.0.20.1+1/windows/x64/jdk/hotspot/normal/eclipse'
$JavaSha = 'e53a79c3c3d86865bd7e787903884331068e71321714ffd44f145785affc7cb0'
$AndroidUrl = 'https://dl.google.com/android/repository/commandlinetools-win-15859902_latest.zip'
$AndroidSha = '90ae805d20434428bffcb699c290860f19bb5f66a67e6b330067e3de801fb04a'

# 再実行時にアーカイブを再利用できるダウンロード領域を用意する。
$Downloads = Join-Path $ToolchainRoot 'downloads'
New-Item -ItemType Directory -Force -Path $Downloads | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $ToolchainRoot 'flutter') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $ToolchainRoot 'jdk') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $env:ANDROID_SDK_ROOT 'cmdline-tools') | Out-Null

# ファイルを必要なときだけ取得し、SHA-256不一致なら展開せず停止する。
function Get-VerifiedArchive {
    param(
        [Parameter(Mandatory)] [string] $Url,
        [Parameter(Mandatory)] [string] $Destination,
        [Parameter(Mandatory)] [string] $ExpectedSha256
    )
    if (-not (Test-Path $Destination)) {
        Invoke-WebRequest -Uri $Url -OutFile $Destination
    }
    $actual = (Get-FileHash -Algorithm SHA256 -Path $Destination).Hash.ToLowerInvariant()
    if ($actual -ne $ExpectedSha256) {
        throw "Checksum mismatch: $Destination"
    }
}

# Flutter SDKを一時領域で展開してから固定バージョンの場所へ移す。
$FlutterExecutable = Join-Path $env:FLUTTER_ROOT 'bin\flutter.bat'
if (-not (Test-Path $FlutterExecutable)) {
    $archive = Join-Path $Downloads 'flutter-3.47.2-windows-x64.zip'
    Get-VerifiedArchive -Url $FlutterUrl -Destination $archive -ExpectedSha256 $FlutterSha
    $staging = Join-Path ([IO.Path]::GetTempPath()) ("nature-flutter-" + [guid]::NewGuid())
    Expand-Archive -Path $archive -DestinationPath $staging
    Move-Item -Path (Join-Path $staging 'flutter') -Destination $env:FLUTTER_ROOT
    Remove-Item -Recurse -Force $staging
}

# Temurin JDK 17を専用領域へ展開し、WindowsのJava設定は変更しない。
$JavaExecutable = Join-Path $env:JAVA_HOME 'bin\java.exe'
if (-not (Test-Path $JavaExecutable)) {
    $archive = Join-Path $Downloads 'temurin-17.0.20.1-windows-x64.zip'
    Get-VerifiedArchive -Url $JavaUrl -Destination $archive -ExpectedSha256 $JavaSha
    $staging = Join-Path ([IO.Path]::GetTempPath()) ("nature-java-" + [guid]::NewGuid())
    Expand-Archive -Path $archive -DestinationPath $staging
    $expandedJdk = Get-ChildItem -Path $staging -Directory | Select-Object -First 1
    Move-Item -Path $expandedJdk.FullName -Destination $env:JAVA_HOME
    Remove-Item -Recurse -Force $staging
}

# Android Command-line Toolsをrevision別の専用ディレクトリへ展開する。
$SdkManager = Join-Path $env:ANDROID_SDK_ROOT 'cmdline-tools\15859902\bin\sdkmanager.bat'
if (-not (Test-Path $SdkManager)) {
    $archive = Join-Path $Downloads 'android-commandlinetools-15859902-windows-x64.zip'
    Get-VerifiedArchive -Url $AndroidUrl -Destination $archive -ExpectedSha256 $AndroidSha
    $staging = Join-Path ([IO.Path]::GetTempPath()) ("nature-android-" + [guid]::NewGuid())
    Expand-Archive -Path $archive -DestinationPath $staging
    $destination = Join-Path $env:ANDROID_SDK_ROOT 'cmdline-tools\15859902'
    Move-Item -Path (Join-Path $staging 'cmdline-tools') -Destination $destination
    Remove-Item -Recurse -Force $staging
}

# SDKライセンスへ回答し、ビルドに必要な固定パッケージを導入する。
(1..100 | ForEach-Object { 'y' }) | & $SdkManager --licenses
if ($LASTEXITCODE -ne 0) { throw "sdkmanager licenses failed with exit code $LASTEXITCODE" }
& $SdkManager `
    'platform-tools' `
    'platforms;android-34' `
    'platforms;android-35' `
    'platforms;android-36' `
    'build-tools;36.0.0' `
    'ndk;28.2.13676358' `
    'cmake;3.22.1'
if ($LASTEXITCODE -ne 0) { throw "sdkmanager failed with exit code $LASTEXITCODE" }

# Gradle用のGit管理外設定を、Windowsパスを正規化して生成する。
& (Join-Path $ScriptDirectory 'configure_android.ps1')

# 実際の配置先を表示し、CIログや利用者が確認できるようにする。
Write-Host "Toolchain ready for windows-x64 at $ToolchainRoot"
