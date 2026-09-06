#!/bin/sh
set -eu

# このスクリプト自身の場所を基準にし、任意の作業ディレクトリから実行できるようにする。
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

# OSごとのユーザー専用SDK配置先と、プロセス内だけの環境変数を読み込む。
. "$SCRIPT_DIR/env.sh"

# CPU名を配布物のキーへ正規化する。Flutter公式バイナリがないCPUでは停止する。
case "$(uname -m)" in
  arm64|aarch64) CPU=arm64 ;;
  x86_64|amd64) CPU=x64 ;;
  *) echo "Unsupported CPU architecture: $(uname -m)" >&2; exit 1 ;;
esac

# OSとCPUの組み合わせごとに、ロック済みの公式URLとSHA-256を選ぶ。
case "$(uname -s)-$CPU" in
  Darwin-arm64)
    PLATFORM=macos-arm64
    FLUTTER_URL=https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_arm64_3.47.2-stable.zip
    FLUTTER_SHA=f456fd6733053d9301828a2e702d6cbec872923126809aa8c48eb0a696d6cc01
    FLUTTER_FORMAT=zip
    JAVA_URL=https://api.adoptium.net/v3/binary/version/jdk-17.0.20.1+1/mac/aarch64/jdk/hotspot/normal/eclipse
    JAVA_SHA=196d13ba5f10414bef7f6a05a9b3f00edacb18ebacef2b99485db9e2ee18f0e8
    ANDROID_URL=https://dl.google.com/android/repository/commandlinetools-mac_arm64-15859902_latest.zip
    ANDROID_SHA=835b62a26162b229b441d1f6d4680383815a270809eb33522c0d480fa5002c4e
    ;;
  Darwin-x64)
    PLATFORM=macos-x64
    FLUTTER_URL=https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_3.47.2-stable.zip
    FLUTTER_SHA=b6fd6ba98c8503d5ee06a6670627b5b1c36167ece3427435ec83b66e9b28c6b5
    FLUTTER_FORMAT=zip
    JAVA_URL=https://api.adoptium.net/v3/binary/version/jdk-17.0.20.1+1/mac/x64/jdk/hotspot/normal/eclipse
    JAVA_SHA=c01975da12ed4235250ff891fe8bba73a9e73037d444b269c9d0922b5dbc8e0a
    ANDROID_URL=https://dl.google.com/android/repository/commandlinetools-mac_x86_64-15859902_latest.zip
    ANDROID_SHA=c5a6378ab5cf7e0d5701921405115befff13e9ff7417fb588389338f8bd050f3
    ;;
  Linux-x64)
    PLATFORM=linux-x64
    FLUTTER_URL=https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.2-stable.tar.xz
    FLUTTER_SHA=447878859d01ca9bfdb99a85f245af07ed8a15fedcd9d189c4749e8e92d1f185
    FLUTTER_FORMAT=tar.xz
    JAVA_URL=https://api.adoptium.net/v3/binary/version/jdk-17.0.20.1+1/linux/x64/jdk/hotspot/normal/eclipse
    JAVA_SHA=3808d1d15e3ec6bd5b84057fb5d84c33d8a1536a258146bcea2e603fc726e08e
    ANDROID_URL=https://dl.google.com/android/repository/commandlinetools-linux-15859902_latest.zip
    ANDROID_SHA=4e4c464f145a7512b57d088ac6c278c03c9eea610886b35a5e0804e74eedf583
    ;;
  *)
    echo "Unsupported platform: $(uname -s)-$CPU. See .toolchain.lock." >&2
    exit 1
    ;;
esac

# ダウンロード済みアーカイブを再利用できる専用ディレクトリを準備する。
DOWNLOADS="$TOOLCHAIN_ROOT/downloads"
mkdir -p "$DOWNLOADS" "$TOOLCHAIN_ROOT/flutter" "$TOOLCHAIN_ROOT/jdk" "$ANDROID_SDK_ROOT/cmdline-tools"

# curlを優先し、Linuxでcurlがない場合だけwgetへフォールバックする。
download() {
  url=$1
  output=$2
  if command -v curl >/dev/null 2>&1; then
    curl -L --fail --retry 3 "$url" -o "$output"
  elif command -v wget >/dev/null 2>&1; then
    wget -O "$output" "$url"
  else
    echo "curl or wget is required." >&2
    exit 1
  fi
}

# OS差を吸収してSHA-256を算出し、改ざん・不完全ダウンロードを検出する。
sha256() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    openssl dgst -sha256 "$1" | awk '{print $NF}'
  fi
}

# 必要な場合だけ取得し、チェックサムが一致しなければ展開前に停止する。
fetch() {
  url=$1
  output=$2
  expected=$3
  [ -f "$output" ] || download "$url" "$output"
  actual=$(sha256 "$output")
  [ "$actual" = "$expected" ] || {
    echo "Checksum mismatch: $output" >&2
    exit 1
  }
}

# Flutter SDKを一時ディレクトリで展開してから、固定バージョンの場所へ移す。
if [ ! -x "$FLUTTER_ROOT/bin/flutter" ]; then
  FLUTTER_ARCHIVE="$DOWNLOADS/flutter-3.47.2-$PLATFORM.$FLUTTER_FORMAT"
  fetch "$FLUTTER_URL" "$FLUTTER_ARCHIVE" "$FLUTTER_SHA"
  temporary=$(mktemp -d)
  if [ "$FLUTTER_FORMAT" = zip ]; then
    unzip -q "$FLUTTER_ARCHIVE" -d "$temporary"
  else
    tar -xJf "$FLUTTER_ARCHIVE" -C "$temporary"
  fi
  mv "$temporary/flutter" "$FLUTTER_ROOT"
  rmdir "$temporary"
fi

# Temurin JDK 17を専用領域へ展開し、システムJavaは変更しない。
if [ ! -x "$JAVA_HOME/bin/java" ]; then
  JAVA_ARCHIVE="$DOWNLOADS/temurin-17.0.20.1-$PLATFORM.tar.gz"
  fetch "$JAVA_URL" "$JAVA_ARCHIVE" "$JAVA_SHA"
  mkdir -p "$TOOLCHAIN_ROOT/jdk/temurin-17"
  tar -xzf "$JAVA_ARCHIVE" -C "$TOOLCHAIN_ROOT/jdk/temurin-17" --strip-components=1
fi

# Android Command-line Toolsをrevision別ディレクトリへ展開する。
SDKMANAGER="$ANDROID_SDK_ROOT/cmdline-tools/15859902/bin/sdkmanager"
if [ ! -x "$SDKMANAGER" ]; then
  ANDROID_ARCHIVE="$DOWNLOADS/android-commandlinetools-15859902-$PLATFORM.zip"
  fetch "$ANDROID_URL" "$ANDROID_ARCHIVE" "$ANDROID_SHA"
  temporary=$(mktemp -d)
  unzip -q "$ANDROID_ARCHIVE" -d "$temporary"
  mkdir -p "$ANDROID_SDK_ROOT/cmdline-tools/15859902"
  mv "$temporary/cmdline-tools"/* "$ANDROID_SDK_ROOT/cmdline-tools/15859902"
  rmdir "$temporary/cmdline-tools" "$temporary"
fi

# Androidライセンスへ回答し、ビルドに必要な固定バージョンだけを導入する。
yes | "$SDKMANAGER" --licenses
"$SDKMANAGER" \
  'platform-tools' \
  'platforms;android-34' \
  'platforms;android-35' \
  'platforms;android-36' \
  'build-tools;36.0.0' \
  'ndk;28.2.13676358' \
  'cmake;3.22.1'

# Gradleが専用SDKを参照できるよう、Git管理外のlocal.propertiesを生成する。
"$SCRIPT_DIR/configure_android.sh"

# 利用されたプラットフォームと配置先を最後に表示して確認しやすくする。
echo "Toolchain ready for $PLATFORM at $TOOLCHAIN_ROOT"
