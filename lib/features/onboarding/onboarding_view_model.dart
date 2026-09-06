// 初回同意状態と中断された探索の復元先を管理するViewModel。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/models/app_models.dart';

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
  Future<void> load() async {
    // 設定を表示する前に探索と観察を復元し、再開先の不整合を避ける。
    final explorationRepository = ref.read(explorationRepositoryProvider);
    await explorationRepository.restore();
    final active = explorationRepository.active;
    if (active != null) {
      await ref.read(observationRepositoryProvider).restore(active.id);
    }
    final settings = await ref.read(settingsRepositoryProvider).load();
    state = state.copyWith(
      loading: false,
      accepted: settings.onboardingAccepted,
      resumePath: active == null
          ? '/home'
          : active.phase == ExplorationPhase.completed
          ? '/review'
          : '/exploration/active',
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
