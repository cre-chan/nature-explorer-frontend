# テストケース

自動テストは端末Service ProviderをFakeへ上書きし、端末なしで決定的に実行します。位置通知、OSによるプロセス終了、カメラ実装固有の一時ファイルはAndroid実機でも確認します。

## 今回追加した回帰ケース

| 対象 | 前提・操作 | 期待結果 |
| --- | --- | --- |
| 中断探索の復元 | DBへ`active`探索を保存して起動する | 位置記録を開始せず`paused`で復元する |
| 一時停止専用画面 | 一時停止画面を開く | 中央の再開操作まで位置記録が停止している |
| 自動終了失敗 | 30分経過時の位置停止をFakeで失敗させる | active状態とエラーを維持し、次回再試行の成功後に完了する |
| nullable状態 | Repositoryが`null`を通知する | `ExplorationUiState.exploration`が`null`になる |
| 0件の手動終了 | 観察せず終了を押す | 確認後に終了し、0件の日記を保存できる |

未実装のテストケースと挙動検討は、文書内へ将来仕様として固定せず、[GitHub Issues](https://github.com/cre-chan/nature-explorer-frontend/issues)で管理します。
