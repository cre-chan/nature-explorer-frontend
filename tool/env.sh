#!/bin/sh

# このファイルは呼び出し元のプロセス内だけで環境変数を設定する。
# シェル設定やシステム全体のPATHは変更しない。

# OS標準のユーザーデータ領域を選び、SDKをリポジトリ外へ隔離する。
case "$(uname -s)" in
  Darwin)
    TOOLCHAIN_ROOT="${TOOLCHAIN_ROOT:-$HOME/Library/Developer/nature-explorer}"
    JAVA_HOME_SUFFIX=/Contents/Home
    ;;
  Linux)
    TOOLCHAIN_ROOT="${TOOLCHAIN_ROOT:-${XDG_DATA_HOME:-$HOME/.local/share}/nature-explorer}"
    JAVA_HOME_SUFFIX=
    ;;
  *)
    echo "Unsupported POSIX platform. On Windows use tool/*.ps1." >&2
    return 1 2>/dev/null || exit 1
    ;;
esac

# 固定バージョンのFlutter、Android SDK、JDKだけをラッパーから参照する。
export TOOLCHAIN_ROOT
export FLUTTER_ROOT="$TOOLCHAIN_ROOT/flutter/3.47.2"
export ANDROID_SDK_ROOT="$TOOLCHAIN_ROOT/android-sdk"
export ANDROID_HOME="$ANDROID_SDK_ROOT"
export JAVA_HOME="$TOOLCHAIN_ROOT/jdk/temurin-17$JAVA_HOME_SUFFIX"

# 専用SDKを優先するが、元のPATHは保持して利用者の環境を壊さない。
export PATH="$FLUTTER_ROOT/bin:$ANDROID_SDK_ROOT/platform-tools:$JAVA_HOME/bin:${PATH:-/usr/bin:/bin:/usr/sbin:/sbin}"
