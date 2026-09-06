// 初回同意状態と中断された探索の復元先を管理するViewModel。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/models/app_models.dart';
import '../../data/repositories/repositories.dart';

/// 初期化、同意、安全確認、復元先をまとめた表示状態。
class OnboardingUiState {
  const OnboardingUiState({
    this.loading = true,
    this.accepted = false,
    this.safetyChecked = false,
    this.resumePath,
    this.error,
  });
  final bool loading;
  final bool accepted;
  final bool safetyChecked;
  final String? resumePath;
  final String? error;
  OnboardingUiState copyWith({
    bool? loading,
    bool? accepted,
    bool? safetyChecked,
    String? resumePath,
    String? error,
  }) => OnboardingUiState(
    loading: loading ?? this.loading,
    accepted: accepted ?? this.accepted,
    safetyChecked: safetyChecked ?? this.safetyChecked,
    resumePath: resumePath ?? this.resumePath,
    error: error,
  );
}

/// 同意の保存と中断データの復元先決定を調整するViewModel。
class OnboardingViewModel extends Notifier<OnboardingUiState> {
  @override
  OnboardingUiState build() => const OnboardingUiState();

  /// 設定と中断データを読み、位置停止を確認できた場合だけ復元先を決める。
  Future<void> load() async {
    final previous = state;
    state = OnboardingUiState(
      accepted: previous.accepted,
      safetyChecked: previous.safetyChecked,
    );
    // 同意済みユーザーを復旧失敗時に初回同意画面へ戻さないため、設定を先に読む。
    final settings = await ref.read(settingsRepositoryProvider).load();
    final explorationRepository = ref.read(explorationRepositoryProvider);
    try {
      await explorationRepository.restore();
    } on ExplorationRestoreException {
      state = OnboardingUiState(
        loading: false,
        accepted: settings.onboardingAccepted,
        safetyChecked: previous.safetyChecked,
        error: '中断した探索の位置記録を停止できませんでした。もう一度お試しください',
      );
      return;
    }
    final active = explorationRepository.active;
    if (active != null) {
      await ref.read(observationRepositoryProvider).restore(active.id);
    }
    state = OnboardingUiState(
      loading: false,
      accepted: settings.onboardingAccepted,
      safetyChecked: previous.safetyChecked,
      resumePath: active == null
          ? '/home'
          : active.phase == ExplorationPhase.completed
          ? '/review'
          : '/exploration/paused',
    );
  }

  void setSafetyChecked(bool value) =>
      state = state.copyWith(safetyChecked: value);
  Future<bool> accept() async {
    if (!state.safetyChecked) return false;
    try {
      final repository = ref.read(settingsRepositoryProvider);
      final current = await repository.load();
      await repository.save(current.copyWith(onboardingAccepted: true));
      state = state.copyWith(accepted: true, loading: false);
      return true;
    } catch (_) {
      state = state.copyWith(loading: false, error: '同意内容を保存できませんでした');
      return false;
    }
  }
}

/// OnboardingViewへ状態とコマンドを供給するProvider。
final onboardingViewModelProvider =
    NotifierProvider<OnboardingViewModel, OnboardingUiState>(
      OnboardingViewModel.new,
    );
