# そばのいのち

身近な虫や痕跡を静かに観察し、その記憶を相棒の変化として残すAndroid-firstのFlutterプロトタイプです。

## 1. 初期設定

対応環境はmacOS（Apple Silicon／Intel）、Linux x64、Windows x64です。Android Studio、グローバルFlutter、システムJavaは使用しません。Linuxでは事前にGit、`curl`または`wget`、`unzip`、XZ対応の`tar`を用意してください。

macOS／Linux:

```sh
cd path/to/nature-explorer
./tool/bootstrap_toolchain.sh
./tool/flutterw pub get
```

Windows PowerShell:

```powershell
Set-Location path\to\nature-explorer
.\tool\bootstrap_toolchain.cmd
.\tool\flutterw.cmd pub get
```

SDKはOS標準のユーザー専用データ領域へ配置されます。保存先とバージョンは[.toolchain.lock](.toolchain.lock)で確認できます。生成される`android/local.properties`はGit管理外です。

## 2. テスト

macOS／Linux:

```sh
./tool/flutterw analyze
./tool/flutterw test
./tool/flutterw doctor -v
```

Windows PowerShell:

```powershell
.\tool\flutterw.cmd analyze
.\tool\flutterw.cmd test
.\tool\flutterw.cmd doctor -v
```

テストではRiverpod Providerを上書きし、GPS、カメラ、時刻、AI、DBをFake実装へ差し替えます。

自動テストで確認済みの回帰ケースは[docs/test-cases.md](docs/test-cases.md)、未実装の異常系と挙動検討は[GitHub Issues](https://github.com/cre-chan/nature-explorer-frontend/issues)で管理します。

### Android実機で対話的にデバッグする

開発中の実機テストでは、`flutter run`をwrapper経由で実行します。この方法ならアプリのインストールと起動に加え、Flutterログ、Androidログ、例外、Hot Reload操作が同じターミナルへ表示されます。`DEVICE_SERIAL`は`devices -l`の各行の先頭に表示される値へ置き換えてください。

macOS／Linux:

```sh
./tool/adbw devices -l
./tool/flutterw run -d DEVICE_SERIAL
```

Windows PowerShell:

```powershell
.\tool\adbw.cmd devices -l
.\tool\flutterw.cmd run -d DEVICE_SERIAL
```

起動後は、同じターミナルで次のキーを使用できます。

| キー | 動作 |
| --- | --- |
| `r` | Hot Reloadを実行します。 |
| `R` | Hot Restartを実行します。 |
| `h` | 使用可能な操作を表示します。 |
| `q` | デバッグ接続と端末上のアプリを終了します。 |
| `d` | デバッガーだけを切断し、端末上のアプリは動かしたままにします。 |

`Application finished.`と表示されれば終了済みです。USBケーブルを抜く前に`q`で終了すると、探索中の位置サービスもアプリと一緒に停止します。

## 3. リリース（debug APKの受入確認）

この段階の配布物は署名済みストア版ではなく、研究用プロトタイプのdebug APKです。

次の手順はA102SOで実際に確認済みです。すべてリポジトリルートで実行し、`DEVICE_SERIAL`は`devices -l`の各行の先頭に表示される値へ置き換えてください。`flutter install`はAPKを起動しないため、ADBで上書きインストールした後に`MainActivity`を明示的に起動します。この方法はデバッガーを接続しない受入確認用です。開発中は前節の`flutter run`を使用してください。

macOS／Linux:

```sh
./tool/flutterw build apk --debug
./tool/adbw devices -l
./tool/adbw -s DEVICE_SERIAL install -r build/app/outputs/flutter-apk/app-debug.apk
./tool/adbw -s DEVICE_SERIAL shell am start -W -n jp.sobanoinochi.prototype/.MainActivity
```

Windows PowerShell:

```powershell
.\tool\flutterw.cmd build apk --debug
.\tool\adbw.cmd devices -l
.\tool\adbw.cmd -s DEVICE_SERIAL install -r build\app\outputs\flutter-apk\app-debug.apk
.\tool\adbw.cmd -s DEVICE_SERIAL shell am start -W -n jp.sobanoinochi.prototype/.MainActivity
```

APKは`build/app/outputs/flutter-apk/app-debug.apk`へ生成されます。インストールに成功すると`Success`、起動に成功すると`Status: ok`と対象Activityが表示されます。`-r`は既存のアプリデータを維持したままAPKを上書きします。

ADBで起動したアプリのログを表示する場合は、まずプロセスIDを取得します。表示された数値を`APP_PID`へ入れて、次のコマンドを別のターミナルで実行してください。

macOS／Linux:

```sh
./tool/adbw -s DEVICE_SERIAL shell pidof jp.sobanoinochi.prototype
./tool/adbw -s DEVICE_SERIAL logcat --pid=APP_PID
```

Windows PowerShell:

```powershell
.\tool\adbw.cmd -s DEVICE_SERIAL shell pidof jp.sobanoinochi.prototype
.\tool\adbw.cmd -s DEVICE_SERIAL logcat --pid=APP_PID
```

ログ表示だけを終了する場合は`Ctrl+C`を押します。ADBで起動したアプリ本体と位置サービスを終了する場合は、次を実行します。アプリデータは削除されません。

macOS／Linux:

```sh
./tool/adbw -s DEVICE_SERIAL shell am force-stop jp.sobanoinochi.prototype
```

Windows PowerShell:

```powershell
.\tool\adbw.cmd -s DEVICE_SERIAL shell am force-stop jp.sobanoinochi.prototype
```

起動できない場合は、次の順番で確認してください。

1. `devices -l`で対象端末の状態が`device`になっていることを確認します。`unauthorized`の場合は端末をロック解除し、USBデバッグを許可します。
2. `DEVICE_SERIAL`を文字どおり入力せず、表示された端末シリアルへ置き換えます。複数端末が接続されていても、`-s`で対象を固定できます。
3. 依存プラグインを変更した直後など、ビルドキャッシュが不整合になった場合は次を実行してから、上記4コマンドをやり直します。

macOS／Linux:

```sh
./tool/flutterw clean
./tool/flutterw pub get
```

Windows PowerShell:

```powershell
.\tool\flutterw.cmd clean
.\tool\flutterw.cmd pub get
```

USB ADBを優先し、利用できない場合のみ無線ADBを使います。

```sh
./tool/adbw pair HOST:PAIR_PORT
./tool/adbw connect HOST:DEBUG_PORT
```

Windowsでは上記コマンドの`./tool/adbw`を`.\tool\adbw.cmd`へ置き換えてください。ストア配布へ進むときは、リリース署名、秘密情報の安全な注入、実機受入テスト、プライバシーレビューを別途行います。

実機では、探索開始後にバックグラウンドへ移すと「そばのいのち・探索中」通知が表示されることを確認します。一時停止または終了後は2秒以内に通知と端末の位置使用表示が消えること、再開と一時停止を3回繰り返しても通知や位置サービスが重複しないことを確認してください。正確な座標や経路は確認画面へ表示しません。

探索中にアプリのプロセスが終了した場合、次回起動時は探索を自動再開せず、一時停止専用画面を表示します。中央の「探索を再開する」を押したときだけ位置記録が再開されることを確認してください。手動終了は観察が0件でも選べますが、確認ダイアログの「終了する」を押すまで終了しません。0件の探索も自然日記へ保存でき、相棒の観察数は増えません。

30分の自動終了で位置サービスの停止に失敗した場合は、探索を終了済みと表示せず、画面へエラーを表示して停止を再試行します。実機確認では30分経過後に通知と位置使用表示が消え、振り返り画面へ進めることを確認してください。

## スクリプト

すべてのラッパーは専用SDKを現在のプロセスにだけ設定します。グローバルPATH、シェル設定、システムJavaやNode.jsは変更しません。

| macOS／Linux | Windows | 役割 |
| --- | --- | --- |
| `tool/bootstrap_toolchain.sh` | `tool/bootstrap_toolchain.cmd` | OSとCPUを判定し、SHA-256を検証してFlutter、Temurin JDK、Android CLI Toolsをユーザー領域へ導入します。 |
| `tool/env.sh` | `tool/env.ps1` | 固定SDKのパスを呼び出し元プロセスへ設定します。 |
| `tool/configure_android.sh` | `tool/configure_android.ps1` | Gradle用の`android/local.properties`を固定値から生成します。 |
| `tool/flutterw` | `tool/flutterw.cmd` | 固定Flutterを実行し、実行前にAndroid SDK設定を同期します。 |
| `tool/dartw` | `tool/dartw.cmd` | Flutter同梱の固定Dartを実行します。 |
| `tool/adbw` | `tool/adbw.cmd` | ユーザー専用Android SDKのADBを実行します。 |
| `tool/sdkmanagerw` | `tool/sdkmanagerw.cmd` | 固定revisionのAndroid SDK Managerを実行します。 |

Windowsの`.cmd`は同名の`.ps1`実装を現在のプロセスだけExecution Policyを緩和して起動します。プロジェクト内では`flutter`や`dart`を直接実行せず、必ず対応するラッパーを使ってください。

## アーキテクチャ

依存方向は`View → ViewModel → Repository → Service`です。Riverpodを状態管理とDI、go_routerを画面遷移に使用します。

- クラスとファイルの対応: [docs/architecture.md](docs/architecture.md)
- MVVM技術判断: [docs/adr/0001-flutter-mvvm.md](docs/adr/0001-flutter-mvvm.md)
- ツールチェーン技術判断: [docs/adr/0002-portable-toolchain-wrappers.md](docs/adr/0002-portable-toolchain-wrappers.md)
- 位置セッション技術判断: [docs/adr/0003-explicit-location-session-lifecycle.md](docs/adr/0003-explicit-location-session-lifecycle.md)
- 中断探索の復元判断: [docs/adr/0004-interrupted-exploration-recovery.md](docs/adr/0004-interrupted-exploration-recovery.md)
- 回帰・異常系テスト設計: [docs/test-cases.md](docs/test-cases.md)
- エージェント向け実装規則: [AGENTS.md](AGENTS.md)
