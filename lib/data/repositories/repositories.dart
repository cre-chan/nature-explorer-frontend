// 永続化、集計、エラー変換を担う、アプリデータの唯一の窓口。
import 'dart:async';
import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../models/app_models.dart';
import '../services/services.dart';

/// 位置権限の拒否理由をViewModelへ伝えるRepository境界の例外。
class LocationAccessException implements Exception {
  const LocationAccessException(this.access);
  final LocationAccess access;
}

/// ユーザー操作外で発生した探索処理の失敗種別。
enum ExplorationIssue { automaticStopFailed }

/// 探索のライフサイクルと集計済み状態を提供するデータ窓口。
abstract interface class ExplorationRepository {
  Stream<Exploration?> watchActive();
  Stream<ExplorationIssue> watchIssues();
  Exploration? get active;
  Future<Exploration> start();
  Future<void> pause();
  Future<void> resume();
  Future<Exploration?> stop();
  Future<void> restore();
  Future<void> clearActive();
  Future<void> dispose();
}

/// 現在の探索に紐づく撮影・観察を提供するデータ窓口。
abstract interface class ObservationRepository {
  Stream<List<Observation>> watchCurrent();
  List<Observation> get current;
  Future<Observation?> capture(String explorationId);
  Future<void> updateDetails(
    String id, {
    required String foundAt,
    required String note,
  });
  Future<List<Observation>> classifyCurrent();
  Future<void> clearCurrent();
  Future<void> restore(String explorationId);
  void dispose();
}

/// 完了した探索の日記を保存・取得するデータ窓口。
abstract interface class JournalRepository {
  Future<List<JournalEntry>> list();
  Future<JournalEntry> save(
    Exploration exploration,
    List<Observation> observations,
  );
}

/// 相棒の状態を保存・更新するデータ窓口。
abstract interface class CompanionRepository {
  Future<Companion> load();
  Future<Companion> applyObservations(List<Observation> observations);
}

/// 設定の保存と全データ削除を提供するデータ窓口。
abstract interface class SettingsRepository {
  Future<AppSettings> load();
  Future<AppSettings> save(AppSettings settings);
  Future<void> deleteAllData();
}

/// GPS購読、距離集計、30分自動終了をまとめて永続化するローカル実装。
class LocalExplorationRepository implements ExplorationRepository {
  LocalExplorationRepository(
    this._database,
    this._location,
    this._clock,
    this._uuid,
  );
  final DatabaseService _database;
  final LocationService _location;
  final ClockService _clock;
  final Uuid _uuid;
  final _controller = StreamController<Exploration?>.broadcast();
  final _issueController = StreamController<ExplorationIssue>.broadcast();
  StreamSubscription<GeoPoint>? _locations;
  Timer? _ticker;
  Exploration? _active;
  DateTime? _resumedAt;
  int _elapsedBeforeResume = 0;
  bool _automaticStopRunning = false;
  bool _automaticStopFailureReported = false;

  @override
  Exploration? get active => _active;
  @override
  Stream<Exploration?> watchActive() => _controller.stream;
  @override
  Stream<ExplorationIssue> watchIssues() => _issueController.stream;

  @override
  Future<Exploration> start() async {
    final access = await _location.requestAccess();
    if (access != LocationAccess.granted) throw LocationAccessException(access);
    final now = _clock.now();
    _active = Exploration(
      id: _uuid.v4(),
      startedAt: now,
      phase: ExplorationPhase.active,
    );
    _resumedAt = now;
    _elapsedBeforeResume = 0;
    _automaticStopFailureReported = false;
    try {
      await _beginTracking();
      await _persist();
      _emit();
      return _active!;
    } catch (_) {
      // 開始失敗を進行中として残さず、開始途中の端末リソースも閉じる。
      _active = null;
      _resumedAt = null;
      await _endTracking();
      rethrow;
    }
  }

  Future<void> _beginTracking() async {
    // ネイティブ側の位置セッションを直列化し、再開時の重複サービスを防ぐ。
    await _endTracking();
    final positions = await _location.startTracking();
    _locations = positions.listen(_addPoint);
    _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  Future<void> _endTracking() async {
    _ticker?.cancel();
    _ticker = null;
    final locations = _locations;
    _locations = null;
    await locations?.cancel();
    // ストリーム解除とは別に、Androidの位置FGSと通知を明示的に終了する。
    await _location.stopTracking();
  }

  Future<void> _addPoint(GeoPoint point) async {
    final active = _active;
    if (active == null || active.phase != ExplorationPhase.active) return;
    final points = [...active.trackPoints];
    var distance = active.distanceMeters;
    if (points.isNotEmpty) {
      distance += _location.distanceBetween(points.last, point);
    }
    points.add(point);
    _active = active.copyWith(trackPoints: points, distanceMeters: distance);
    await _persist();
    _emit();
  }

  Future<void> _tick() async {
    final active = _active;
    final resumedAt = _resumedAt;
    if (active == null ||
        active.phase != ExplorationPhase.active ||
        resumedAt == null) {
      return;
    }
    final elapsed =
        _elapsedBeforeResume + _clock.now().difference(resumedAt).inSeconds;
    _active = active.copyWith(elapsedSeconds: elapsed);
    if (elapsed >= 30 * 60) {
      if (_automaticStopRunning) return;
      // UIが前面になくても、Repository自身が上限時間を保証する。
      _automaticStopRunning = true;
      try {
        await stop();
        _automaticStopFailureReported = false;
      } catch (_) {
        // 停止失敗後も再試行を続け、初回の失敗をViewModelへ通知する。
        if (!_automaticStopFailureReported) {
          _automaticStopFailureReported = true;
          _issueController.add(ExplorationIssue.automaticStopFailed);
        }
        if (_active?.phase == ExplorationPhase.active) _startTicker();
      } finally {
        _automaticStopRunning = false;
      }
    } else {
      _emit();
      if (elapsed % 15 == 0) await _persist();
    }
  }

  @override
  Future<void> pause() async {
    final active = _active;
    if (active == null || active.phase != ExplorationPhase.active) return;
    await _endTracking();
    _elapsedBeforeResume = active.elapsedSeconds;
    _resumedAt = null;
    _active = active.copyWith(phase: ExplorationPhase.paused);
    await _persist();
    _emit();
  }

  @override
  Future<void> resume() async {
    final active = _active;
    if (active == null || active.phase != ExplorationPhase.paused) return;
    await _beginTracking();
    _active = active.copyWith(phase: ExplorationPhase.active);
    _resumedAt = _clock.now();
    _automaticStopFailureReported = false;
    await _persist();
    _emit();
  }

  @override
  Future<Exploration?> stop() async {
    final active = _active;
    if (active == null) return null;
    await _endTracking();
    _resumedAt = null;
    _active = active.copyWith(
      phase: ExplorationPhase.completed,
      endedAt: _clock.now(),
    );
    await _persist();
    _emit();
    return _active;
  }

  @override
  Future<void> restore() async {
    final value = decodeMap(await _database.read('active_exploration'));
    if (value == null) return;
    _active = Exploration.fromJson(value);
    if (_active!.phase == ExplorationPhase.active) {
      // プロセス終了中は停止完了を保証できないため、次回起動時に必ず停止状態へ正規化する。
      _elapsedBeforeResume = _active!.elapsedSeconds;
      _resumedAt = null;
      await _endTracking();
      _active = _active!.copyWith(phase: ExplorationPhase.paused);
      await _persist();
    }
    _emit();
  }

  @override
  Future<void> clearActive() async {
    await _endTracking();
    _resumedAt = null;
    _active = null;
    await _database.delete('active_exploration');
    _emit();
  }

  Future<void> _persist() async {
    final value = _active;
    if (value != null) {
      await _database.write('active_exploration', jsonEncode(value.toJson()));
    }
  }

  void _emit() => _controller.add(_active);
  @override
  Future<void> dispose() async {
    try {
      await _endTracking();
    } finally {
      await _controller.close();
      await _issueController.close();
    }
  }
}

/// 撮影からメタデータ除去、入力、分類までを順序保証するローカル実装。
class LocalObservationRepository implements ObservationRepository {
  LocalObservationRepository(
    this._database,
    this._camera,
    this._sanitizer,
    this._files,
    this._ai,
    this._clock,
    this._uuid,
  );
  final DatabaseService _database;
  final CameraService _camera;
  final ImageSanitizationService _sanitizer;
  final FileService _files;
  final AiClassificationService _ai;
  final ClockService _clock;
  final Uuid _uuid;
  final _controller = StreamController<List<Observation>>.broadcast();
  List<Observation> _current = [];
  @override
  List<Observation> get current => List.unmodifiable(_current);
  @override
  Stream<List<Observation>> watchCurrent() => _controller.stream;

  @override
  Future<Observation?> capture(String explorationId) async {
    final source = await _camera.capture();
    if (source == null) return null;
    final id = _uuid.v4();
    final destination = await _files.newPhotoPath(id);
    // 元写真のパスは保存せず、無害化に成功したファイルだけを永続化する。
    final safePath = await _sanitizer.sanitize(
      source: source,
      destination: destination,
    );
    final observation = Observation(
      id: id,
      explorationId: explorationId,
      imagePath: safePath,
      createdAt: _clock.now(),
    );
    _current = [..._current, observation];
    await _persist();
    _emit();
    return observation;
  }

  @override
  Future<void> updateDetails(
    String id, {
    required String foundAt,
    required String note,
  }) async {
    _current = [
      for (final item in _current)
        if (item.id == id)
          item.copyWith(foundAt: foundAt, note: note.trim())
        else
          item,
    ];
    await _persist();
    _emit();
  }

  @override
  Future<List<Observation>> classifyCurrent() async {
    final classified = <Observation>[];
    for (final item in _current) {
      classified.add(item.copyWith(classification: await _ai.classify(item)));
    }
    _current = classified;
    await _persist();
    _emit();
    return current;
  }

  @override
  Future<void> clearCurrent() async {
    _current = [];
    await _database.delete('current_observations');
    _emit();
  }

  @override
  Future<void> restore(String explorationId) async {
    _current = decodeMaps(await _database.read('current_observations'))
        .map(Observation.fromJson)
        .where((item) => item.explorationId == explorationId)
        .toList();
    _emit();
  }

  Future<void> _persist() => _database.write(
    'current_observations',
    encodeMaps(_current.map((item) => item.toJson())),
  );
  void _emit() => _controller.add(current);
  @override
  void dispose() => _controller.close();
}

/// 完了探索を複数件保持できるローカル日記実装。
class LocalJournalRepository implements JournalRepository {
  LocalJournalRepository(this._database, this._clock, this._uuid);
  final DatabaseService _database;
  final ClockService _clock;
  final Uuid _uuid;
  @override
  Future<List<JournalEntry>> list() async =>
      decodeMaps(await _database.read('journal_entries'))
          .map(JournalEntry.fromJson)
          .toList()
        ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  @override
  Future<JournalEntry> save(
    Exploration exploration,
    List<Observation> observations,
  ) async {
    final entries = await list();
    final entry = JournalEntry(
      id: _uuid.v4(),
      exploration: exploration,
      observations: observations,
      savedAt: _clock.now(),
    );
    await _database.write(
      'journal_entries',
      encodeMaps([...entries, entry].map((item) => item.toJson())),
    );
    return entry;
  }
}

/// 観察結果を相棒の変化へ反映するローカル実装。
class LocalCompanionRepository implements CompanionRepository {
  LocalCompanionRepository(this._database);
  final DatabaseService _database;
  @override
  Future<Companion> load() async {
    final value = decodeMap(await _database.read('companion'));
    return value == null ? const Companion() : Companion.fromJson(value);
  }

  @override
  Future<Companion> applyObservations(List<Observation> observations) async {
    final current = await load();
    final useful = observations
        .where(
          (item) =>
              item.classification == ClassificationStatus.usable ||
              item.classification == ClassificationStatus.indeterminate,
        )
        .length;
    final updated = Companion(
      name: current.name,
      stage: useful > 0 ? CompanionStage.changing : current.stage,
      observationCount: current.observationCount + observations.length,
    );
    await _database.write('companion', jsonEncode(updated.toJson()));
    return updated;
  }
}

/// 設定と端末内データの一括削除を扱うローカル実装。
class LocalSettingsRepository implements SettingsRepository {
  LocalSettingsRepository(this._database, this._files);
  final DatabaseService _database;
  final FileService _files;
  @override
  Future<AppSettings> load() async {
    final value = decodeMap(await _database.read('settings'));
    return value == null ? const AppSettings() : AppSettings.fromJson(value);
  }

  @override
  Future<AppSettings> save(AppSettings settings) async {
    await _database.write('settings', jsonEncode(settings.toJson()));
    return settings;
  }

  @override
  Future<void> deleteAllData() async {
    await _database.clear();
    await _files.deleteAllPhotos();
  }
}
