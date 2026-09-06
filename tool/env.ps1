$ErrorActionPreference = 'Stop'

# Windows標準のユーザーデータ領域へSDKを隔離し、システム設定は変更しない。
$ToolchainRoot = if ($env:TOOLCHAIN_ROOT) {
    $env:TOOLCHAIN_ROOT
} else {
    Join-Path $env:LOCALAPPDATA 'nature-explorer'
}

# このPowerShellプロセスと子プロセスだけに、固定SDKの場所を公開する。
$env:TOOLCHAIN_ROOT = $ToolchainRoot
$env:FLUTTER_ROOT = Join-Path $ToolchainRoot 'flutter\3.47.2'
$env:ANDROID_SDK_ROOT = Join-Path $ToolchainRoot 'android-sdk'
$env:ANDROID_HOME = $env:ANDROID_SDK_ROOT
$env:JAVA_HOME = Join-Path $ToolchainRoot 'jdk\temurin-17'

# 専用SDKをコマンド探索の先頭へ置くが、利用者の既存PATHは保持する。
$separator = [IO.Path]::PathSeparator
$env:Path = @(
    (Join-Path $env:FLUTTER_ROOT 'bin')
    (Join-Path $env:ANDROID_SDK_ROOT 'platform-tools')
    (Join-Path $env:JAVA_HOME 'bin')
    $env:Path
) -join $separator
