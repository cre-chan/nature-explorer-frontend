// 設定の保存と関連Repositoryをまたぐ全削除を調整するViewModel。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/models/app_models.dart';

/// 設定値、読込中、表示用エラーをまとめた状態。
class SettingsUiState {
  const SettingsUiState({
    this.loading = true,
    this.settings = const AppSettings(),
    this.deleting = false,
    this.error,
  });
  final bool loading;
  final AppSettings settings;
  final bool deleting;
  final String? error;
  SettingsUiState copyWith({
    bool? loading,
    AppSettings? settings,
    bool? deleting,
    String? error,
  }) => SettingsUiState(
    loading: loading ?? this.loading,
    settings: settings ?? this.settings,
    deleting: deleting ?? this.deleting,
    error: error,
  );
}

/// 設定保存と複数Repositoryにまたがる全削除を調整するViewModel。
class SettingsViewModel extends Notifier<SettingsUiState> {
  @override
  SettingsUiState build() => const SettingsUiState();
  Future<void> load() async => state = SettingsUiState(
    loading: false,
    settings: await ref.read(settingsRepositoryProvider).load(),
  );
  Future<void> setInvites(bool value) =>
      _save(state.settings.copyWith(explorationInvites: value));
  Future<void> setGrowth(bool value) =>
      _save(state.settings.copyWith(growthNotifications: value));
  Future<void> setLocation(bool value) =>
      _save(state.settings.copyWith(locationTracking: value));
  Future<void> _save(AppSettings value) async => state = state.copyWith(
    settings: await ref.read(settingsRepositoryProvider).save(value),
  );
  Future<bool> deleteAll() async {
    state = state.copyWith(deleting: true);
    try {
      // 購読中の進行データを先に止め、削除後にDBへ再保存されるのを防ぐ。
      await ref.read(explorationRepositoryProvider).clearActive();
      await ref.read(observationRepositoryProvider).clearCurrent();
      await ref.read(settingsRepositoryProvider).deleteAllData();
      state = const SettingsUiState(loading: false);
      return true;
    } catch (_) {
      state = state.copyWith(deleting: false, error: 'データを削除できませんでした');
      return false;
    }
  }
}

/// SettingsViewへ状態と設定コマンドを供給するProvider。
final settingsViewModelProvider =
    NotifierProvider<SettingsViewModel, SettingsUiState>(SettingsViewModel.new);
