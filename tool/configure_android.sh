#!/bin/sh
set -eu

# 専用SDKの環境変数を、このシェルプロセス内へ読み込む。
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/env.sh"

# スクリプト位置からプロジェクトルートを解決し、実行場所への依存をなくす。
project_root=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
properties="$project_root/android/local.properties"
temporary="$properties.tmp"

# まず一時ファイルへ固定SDKの場所を書き、途中終了で既存設定を壊さないようにする。
printf '%s\n' \
  "sdk.dir=$ANDROID_SDK_ROOT" \
  "flutter.sdk=$FLUTTER_ROOT" > "$temporary"

# 内容に変更がある場合だけ置換し、不要なGradle再評価を避ける。
if [ ! -f "$properties" ] || ! cmp -s "$temporary" "$properties"; then
  mv "$temporary" "$properties"
else
  rm "$temporary"
fi
