# アーキテクチャ

## 依存方向

このプロジェクトはFlutter公式MVVMを基準にし、依存を次の一方向へ限定します。

```text
View → ViewModel → Repository → Service → 端末・SQLite
             ↘ Domain model ↙
```

Riverpod Providerは`Service → Repository → ViewModel → View`の順に依存を組み立てます。ViewModelはServiceやSQLite、GPS、カメラを直接参照しません。Repository同士も依存せず、複数Repositoryを使う操作はViewModelが調整します。

## View

Viewは描画、簡単な表示分岐、入力イベントからViewModelコマンドを呼ぶ処理だけを持ちます。

| 機能 | ファイル | 主なクラス |
| --- | --- | --- |
| アプリ・ルーティング | `lib/app/app.dart` | `SobaNoInochiApp`、`appRouter` |
| 初回同意 | `lib/features/onboarding/onboarding_view.dart` | `OnboardingView` |
| ホーム・相棒 | `lib/features/home/home_view.dart` | `HomeView`、`CompanionView` |
| 探索 | `lib/features/exploration/exploration_view.dart` | `ExplorationPrepView`、`ExplorationView`、`GpsStatusView`、`ReviewView` |
| 探索の一時停止 | `lib/features/exploration/paused_exploration_view.dart` | `PausedExplorationView` |
| 探索終了確認 | `lib/features/exploration/exploration_stop_dialog.dart` | `confirmExplorationStop` |
| 撮影 | `lib/features/observation/capture_view.dart` | `CaptureView` |
| 観察入力 | `lib/features/observation/observation_view.dart` | `ObservationView` |
| 日記 | `lib/features/journal/journal_view.dart` | `JournalView` |
| 設定 | `lib/features/settings/settings_view.dart` | `SettingsView` |
| 共通表示 | `lib/features/shared/presentation.dart` | `AppPage`、`PagePadding`、`Eyebrow`、`InfoRow`、`CompanionArt` |

## ViewModel

ViewModelはRiverpod `Notifier`としてUI状態、表示用変換、入力検証、ユーザー操作のコマンドを管理します。

| 機能 | ファイル | 状態・ViewModel |
| --- | --- | --- |
| 初回同意・復元先 | `lib/features/onboarding/onboarding_view_model.dart` | `OnboardingUiState`、`OnboardingViewModel` |
| ホーム集計 | `lib/features/home/home_view_model.dart` | `HomeUiState`、`HomeViewModel` |
| 相棒 | `lib/features/home/companion_view_model.dart` | `CompanionViewModel` |
| 探索状態・操作 | `lib/features/exploration/exploration_view_model.dart` | `ExplorationUiState`、`ExplorationViewModel` |
| GPS表示状態 | `lib/features/exploration/gps_status_view_model.dart` | `GpsUiState`、`GpsStatusViewModel` |
| 撮影状態 | `lib/features/observation/capture_view_model.dart` | `CaptureUiState`、`CaptureViewModel` |
| 観察・AI確認 | `lib/features/observation/observation_view_model.dart` | `ObservationUiState`、`ObservationViewModel` |
| 日記一覧・保存 | `lib/features/journal/journal_view_model.dart` | `JournalUiState`、`JournalViewModel` |
| 設定・全削除 | `lib/features/settings/settings_view_model.dart` | `SettingsUiState`、`SettingsViewModel` |

## Repository

Repositoryはアプリデータの唯一の窓口です。永続化順序、集計、キャッシュ、端末由来エラーのアプリ向け変換を担当し、ViewModelへドメインモデルを返します。

すべて`lib/data/repositories/repositories.dart`に定義されています。

| インターフェース | ローカル実装 | 責務 |
| --- | --- | --- |
| `ExplorationRepository` | `LocalExplorationRepository` | 探索開始・一時停止・再開・終了・30分自動終了、位置セッションの直列化、GPS点と距離の保存、中断状態の復元、非同期エラー通知 |
| `ObservationRepository` | `LocalObservationRepository` | 撮影、画像無害化、観察入力、AIモック判定、現在の観察の復元 |
| `JournalRepository` | `LocalJournalRepository` | 探索IDを冪等キーとして探索と観察を保存し、同日の複数探索を保持 |
| `CompanionRepository` | `LocalCompanionRepository` | 適用済み探索IDと相棒状態を同時保存し、観察結果を探索ごとに一度だけ反映 |
| `SettingsRepository` | `LocalSettingsRepository` | 同意・通知・位置設定の保存、DBと写真の一括削除 |

`LocationAccessException`は位置権限状態をViewModelが表示可能なエラーへ変換するためのRepository境界の例外です。

日記確定は`JournalViewModel`が日記保存、相棒更新、探索削除、観察削除の順に実行します。各Repositoryは探索IDによる冪等性または永続化成功後のメモリ更新を保証し、途中失敗後に同じ操作を再試行しても日記と相棒状態を重複させません。

## Service

Serviceは単一の外部データ源または端末機能をラップし、業務状態を持ちません。すべて`lib/data/services/services.dart`に定義されています。

| インターフェース | 端末実装 | 対象 |
| --- | --- | --- |
| `DatabaseService` | `SqliteDatabaseService` | SQLiteのkey-value永続化 |
| `ClockService` | `SystemClockService` | 現在時刻 |
| `LocationService` | `DeviceLocationService` | `location`による位置権限、15秒／10mの位置セッション、Android継続通知の明示的な開始・停止、距離計算 |
| `CameraService` | `DeviceCameraService` | 端末カメラ撮影 |
| `FileService` | `DeviceFileService` | アプリ専用写真領域 |
| `ImageSanitizationService` | `ReencodingImageSanitizationService` | JPEG再エンコードとEXIF除去 |
| `AiClassificationService` | `MockAiClassificationService` | 利用可能・判別困難・対象外のモック判定 |

## ProviderとDI

`lib/app/providers.dart`がServiceとRepositoryの実装を組み立てます。各ViewModel Providerは対応する`*_view_model.dart`にあります。テストは`test/support/fakes.dart`のFake ServiceでService Providerを上書きし、端末なしで同じRepository・ViewModel・Viewを検証します。

## ドメインモデル

`lib/data/models/app_models.dart`には`Exploration`、`GeoPoint`、`Observation`、`JournalEntry`、`Companion`、`AppSettings`と関連enumがあります。正確な座標は保存・距離集計にのみ使い、Viewへ渡す表示では座標や経路を描画しません。

## 位置セッションのライフサイクル

`LocationService.startTracking()`は位置ストリームとAndroidの位置フォアグラウンドサービスを開始し、`stopTracking()`は継続通知を含めて明示的に終了します。`LocalExplorationRepository`だけがこのAPIを呼び、一時停止、手動終了、30分自動終了、全削除、Repository破棄でストリーム解除後に停止完了を待ちます。

探索開始と再開は画面が表示されているユーザー操作からのみ行います。Androidでは`ACCESS_BACKGROUND_LOCATION`を要求せず、探索中の位置フォアグラウンドサービスが動作している間だけバックグラウンド記録を継続します。アプリのプロセス終了中は非同期停止の完了を保証できないため、次回起動時に保存状態が`active`なら位置サービスを停止し、探索を`paused`へ正規化して`PausedExplorationView`を表示します。位置記録は中央の再開ボタンを押すまで開始しません。

手動終了は観察件数にかかわらず選択でき、確認ダイアログで確定してから位置記録を停止します。観察0件の探索も日記へ保存できますが、相棒の観察数や成長状態は変化しません。

停止に失敗した場合は探索状態を一時停止または完了へ変更しません。手動操作の失敗はコマンド結果から、自動終了の失敗は`ExplorationRepository.watchIssues()`からViewModelへ伝え、画面へ表示します。30分自動終了は停止に成功するまで再試行します。

## 画面遷移

`lib/main.dart`が`ProviderScope`と`SobaNoInochiApp`を起動し、`lib/app/app.dart`の`GoRouter`が画面を管理します。中断探索は`/exploration/paused`、実行中探索は`/exploration/active`、終了後は`/review`へ遷移します。

## 機能追加時の判断

1. UIだけの変更はViewへ置きます。
2. UI状態、入力検証、複数Repositoryの調整はViewModelへ置きます。
3. 保存・取得・集計・エラー変換はRepositoryへ置きます。
4. SQLiteや端末APIの呼び出しはServiceへ置きます。
5. クラスの追加・移動・改名時は、この文書の対応表を同じ変更で更新します。
6. 複雑な処理が複数ViewModelで重複するまでUseCase層は追加しません。
