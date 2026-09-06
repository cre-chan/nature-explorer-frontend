// 撮影処理の進行状態と表示用エラーを管理するViewModel。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/models/app_models.dart';

/// 撮影中フラグと表示用エラーを持つ状態。
class CaptureUiState {
  const CaptureUiState({this.capturing = false, this.draft, this.error});
  final bool capturing;
  final Observation? draft;
  final String? error;
}

/// 撮影RepositoryのコマンドをUI向け状態で包むViewModel。
class CaptureViewModel extends Notifier<CaptureUiState> {
  @override
  CaptureUiState build() => const CaptureUiState();
  Future<Observation?> capture() async {
    final active = ref.read(explorationRepositoryProvider).active;
    if (active == null) {
      state = const CaptureUiState(error: '探索を開始してから撮影してください');
      return null;
    }
    state = const CaptureUiState(capturing: true);
    try {
      final observation = await ref
          .read(observationRepositoryProvider)
          .capture(active.id);
      state = CaptureUiState(draft: observation);
      return observation;
    } catch (_) {
      state = const CaptureUiState(error: '写真を安全に保存できませんでした');
      return null;
    }
  }

  void clearDraft() => state = const CaptureUiState();
}

/// CaptureViewへ状態と撮影コマンドを供給するProvider。
final captureViewModelProvider =
    NotifierProvider<CaptureViewModel, CaptureUiState>(CaptureViewModel.new);
