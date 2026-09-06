// 現在の観察一覧、入力保存、AIモック確認を管理するViewModel。
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/models/app_models.dart';

/// 現在の観察一覧とAI確認処理の表示状態。
class ObservationUiState {
  const ObservationUiState({
    this.observations = const [],
    this.classifying = false,
    this.error,
  });
  final List<Observation> observations;
  final bool classifying;
  final String? error;
  ObservationUiState copyWith({
    List<Observation>? observations,
    bool? classifying,
    String? error,
  }) => ObservationUiState(
    observations: observations ?? this.observations,
    classifying: classifying ?? this.classifying,
    error: error,
  );
}

/// 観察入力とAI確認をRepositoryへ委譲するViewModel。
class ObservationViewModel extends Notifier<ObservationUiState> {
  StreamSubscription<List<Observation>>? _subscription;
  @override
  ObservationUiState build() {
    final repository = ref.watch(observationRepositoryProvider);
    _subscription = repository.watchCurrent().listen(
      (value) => state = state.copyWith(observations: value),
    );
    ref.onDispose(() => _subscription?.cancel());
    return ObservationUiState(observations: repository.current);
  }

  Observation? find(String id) {
    for (final item in state.observations) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<bool> submit(
    String id, {
    required String foundAt,
    required String note,
  }) async {
    if (foundAt.isEmpty) return false;
    await ref
        .read(observationRepositoryProvider)
        .updateDetails(id, foundAt: foundAt, note: note);
    return true;
  }

  Future<void> classify() async {
    state = state.copyWith(classifying: true);
    try {
      final items = await ref
          .read(observationRepositoryProvider)
          .classifyCurrent();
      state = state.copyWith(observations: items, classifying: false);
    } catch (_) {
      state = state.copyWith(classifying: false, error: '確認結果を取得できませんでした');
    }
  }
}

/// 観察View群へ状態とコマンドを供給するProvider。
final observationViewModelProvider =
    NotifierProvider<ObservationViewModel, ObservationUiState>(
      ObservationViewModel.new,
    );
