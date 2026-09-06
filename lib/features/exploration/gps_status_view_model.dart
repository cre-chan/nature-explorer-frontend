// 正確な座標を公開せず、GPS記録状態だけをView向けに変換するViewModel。
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/models/app_models.dart';

/// 座標を含めず、記録中かどうかと観測数だけを表すGPS表示状態。
class GpsUiState {
  const GpsUiState({
    this.recording = false,
    this.paused = false,
    this.pointCount = 0,
  });
  final bool recording;
  final bool paused;
  final int pointCount;
}

/// 探索データからプライバシーに配慮したGPS表示状態を作るViewModel。
class GpsStatusViewModel extends Notifier<GpsUiState> {
  StreamSubscription<Exploration?>? _subscription;
  @override
  GpsUiState build() {
    final repository = ref.watch(explorationRepositoryProvider);
    _subscription = repository.watchActive().listen(_update);
    ref.onDispose(() => _subscription?.cancel());
    final active = repository.active;
    return GpsUiState(
      recording: active?.phase == ExplorationPhase.active,
      paused: active?.phase == ExplorationPhase.paused,
      pointCount: active?.trackPoints.length ?? 0,
    );
  }

  void _update(Exploration? value) => state = GpsUiState(
    recording: value?.phase == ExplorationPhase.active,
    paused: value?.phase == ExplorationPhase.paused,
    pointCount: value?.trackPoints.length ?? 0,
  );
}

/// GpsStatusViewへ座標を含まない状態を供給するProvider。
final gpsStatusViewModelProvider =
    NotifierProvider<GpsStatusViewModel, GpsUiState>(GpsStatusViewModel.new);
