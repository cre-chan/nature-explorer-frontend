// ホームに必要な相棒状態と日記件数をRepositoryから集約するViewModel。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/models/app_models.dart';

/// ホームに表示する相棒と日記件数の状態。
class HomeUiState {
  const HomeUiState({
    this.loading = true,
    this.companion = const Companion(),
    this.journalCount = 0,
  });
  final bool loading;
  final Companion companion;
  final int journalCount;
}

/// 複数Repositoryの読取結果をホーム表示へ集約するViewModel。
class HomeViewModel extends Notifier<HomeUiState> {
  @override
  HomeUiState build() => const HomeUiState();
  Future<void> load() async {
    final companion = await ref.read(companionRepositoryProvider).load();
    final journals = await ref.read(journalRepositoryProvider).list();
    state = HomeUiState(
      loading: false,
      companion: companion,
      journalCount: journals.length,
    );
  }

  Future<void> prepareNewExploration() async {
    await ref.read(explorationRepositoryProvider).clearActive();
    await ref.read(observationRepositoryProvider).clearCurrent();
  }
}

/// HomeViewへ状態とコマンドを供給するProvider。
final homeViewModelProvider = NotifierProvider<HomeViewModel, HomeUiState>(
  HomeViewModel.new,
);
