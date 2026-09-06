// 日記一覧と現在の探索結果の保存順序を管理するViewModel。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/models/app_models.dart';

/// 日記一覧、読込中、表示用エラーをまとめた状態。
class JournalUiState {
  const JournalUiState({
    this.loading = true,
    this.entries = const [],
    this.saving = false,
    this.error,
  });
  final bool loading;
  final List<JournalEntry> entries;
  final bool saving;
  final String? error;
  JournalUiState copyWith({
    bool? loading,
    List<JournalEntry>? entries,
    bool? saving,
    String? error,
  }) => JournalUiState(
    loading: loading ?? this.loading,
    entries: entries ?? this.entries,
    saving: saving ?? this.saving,
    error: error,
  );
}

/// 日記保存と相棒更新の順序を調整するViewModel。
class JournalViewModel extends Notifier<JournalUiState> {
  @override
  JournalUiState build() => const JournalUiState();
  Future<void> load() async => state = JournalUiState(
    loading: false,
    entries: await ref.read(journalRepositoryProvider).list(),
  );
  Future<bool> saveCurrent() async {
    // 日記保存後に相棒を更新し、最後に進行中データを消して再探索可能にする。
    final exploration = ref.read(explorationRepositoryProvider).active;
    final observations = ref.read(observationRepositoryProvider).current;
    if (exploration == null || observations.isEmpty) return false;
    state = state.copyWith(saving: true);
    try {
      await ref.read(journalRepositoryProvider).save(exploration, observations);
      await ref
          .read(companionRepositoryProvider)
          .applyObservations(observations);
      await ref.read(explorationRepositoryProvider).clearActive();
      await ref.read(observationRepositoryProvider).clearCurrent();
      await load();
      return true;
    } catch (_) {
      state = state.copyWith(saving: false, error: '日記を保存できませんでした');
      return false;
    }
  }
}

/// JournalViewへ状態と保存コマンドを供給するProvider。
final journalViewModelProvider =
    NotifierProvider<JournalViewModel, JournalUiState>(JournalViewModel.new);
