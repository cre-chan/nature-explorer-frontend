// 探索の開始・一時停止・再開・終了と、そのUI状態を管理するViewModel。
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/models/app_models.dart';
import '../../data/repositories/repositories.dart';

const _unchangedExploration = Object();

/// 探索本体、安全確認、処理中、表示用エラーをまとめた状態。
class ExplorationUiState {
  const ExplorationUiState({
    this.exploration,
    this.safetyAccepted = false,
    this.busy = false,
    this.error,
  });
  final Exploration? exploration;
  final bool safetyAccepted;
  final bool busy;
  final String? error;
  ExplorationUiState copyWith({
    Object? exploration = _unchangedExploration,
    bool? safetyAccepted,
    bool? busy,
    String? error,
  }) => ExplorationUiState(
    exploration: identical(exploration, _unchangedExploration)
        ? this.exploration
        : exploration as Exploration?,
    safetyAccepted: safetyAccepted ?? this.safetyAccepted,
    busy: busy ?? this.busy,
    error: error,
  );
}

/// 探索Repositoryのストリームを購読し、ユーザー操作をコマンド化するViewModel。
class ExplorationViewModel extends Notifier<ExplorationUiState> {
  StreamSubscription<Exploration?>? _subscription;
  StreamSubscription<ExplorationIssue>? _issueSubscription;
  @override
  ExplorationUiState build() {
    final repository = ref.watch(explorationRepositoryProvider);
    _subscription = repository.watchActive().listen(
      (value) => state = state.copyWith(exploration: value),
    );
    _issueSubscription = repository.watchIssues().listen((issue) {
      if (issue == ExplorationIssue.automaticStopFailed) {
        state = state.copyWith(error: '30分の自動終了で位置記録を停止できませんでした。停止を再試行しています');
      }
    });
    ref.onDispose(() {
      _subscription?.cancel();
      _issueSubscription?.cancel();
    });
    return ExplorationUiState(exploration: repository.active);
  }

  void setSafetyAccepted(bool value) =>
      state = state.copyWith(safetyAccepted: value);
  Future<bool> start() async {
    if (!state.safetyAccepted) return false;
    state = state.copyWith(busy: true);
    try {
      final settings = await ref.read(settingsRepositoryProvider).load();
      if (!settings.locationTracking) {
        state = state.copyWith(busy: false, error: '設定でクエスト中の位置記録を有効にしてください');
        return false;
      }
      final exploration = await ref.read(explorationRepositoryProvider).start();
      state = state.copyWith(exploration: exploration, busy: false);
      return true;
    } on LocationAccessException catch (error) {
      final message = switch (error.access) {
        LocationAccess.serviceDisabled => '端末の位置情報を有効にしてください',
        LocationAccess.deniedForever => '設定から位置情報を許可してください',
        _ => '探索には位置情報の許可が必要です',
      };
      state = state.copyWith(busy: false, error: message);
      return false;
    } catch (_) {
      state = state.copyWith(busy: false, error: '探索を開始できませんでした');
      return false;
    }
  }

  Future<bool> togglePause() async {
    final exploration = state.exploration;
    if (exploration == null || state.busy) return false;
    final resuming = exploration.phase == ExplorationPhase.paused;
    state = state.copyWith(busy: true);
    try {
      if (resuming) {
        await ref.read(explorationRepositoryProvider).resume();
      } else {
        await ref.read(explorationRepositoryProvider).pause();
      }
      state = state.copyWith(busy: false);
      return true;
    } catch (_) {
      state = state.copyWith(
        busy: false,
        error: resuming ? '位置記録を再開できませんでした' : '位置記録を停止できませんでした。アプリを終了してください',
      );
      return false;
    }
  }

  Future<Exploration?> stop() async {
    if (state.busy) return null;
    state = state.copyWith(busy: true);
    try {
      final exploration = await ref.read(explorationRepositoryProvider).stop();
      state = state.copyWith(busy: false);
      return exploration;
    } catch (_) {
      state = state.copyWith(
        busy: false,
        error: '位置記録を停止できませんでした。アプリを終了してください',
      );
      return null;
    }
  }
}

/// 探索View群へ状態とコマンドを供給するProvider。
final explorationViewModelProvider =
    NotifierProvider<ExplorationViewModel, ExplorationUiState>(
      ExplorationViewModel.new,
    );
