// MVVMの各層で共有する、端末APIへ依存しないドメインモデル。
import 'dart:convert';

/// 探索が記録中・一時停止中・完了済みのどれかを表す。
enum ExplorationPhase { active, paused, completed }

/// 観察画像に対するAIモックの確認結果。
enum ClassificationStatus { pending, usable, indeterminate, outside }

/// 観察の蓄積によって変わる相棒の段階。
enum CompanionStage { juvenile, changing }

/// 端末固有の位置権限をUIから独立した状態へ正規化する。
enum LocationAccess { granted, denied, deniedForever, serviceDisabled }

/// 距離集計と復元のためだけに保持する位置観測点。
///
/// 正確な緯度・経度はViewへ直接表示しない。
class GeoPoint {
  const GeoPoint({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.recordedAt,
  });
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime recordedAt;

  Map<String, Object?> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'accuracy': accuracy,
    'recordedAt': recordedAt.toIso8601String(),
  };
  factory GeoPoint.fromJson(Map<String, Object?> json) => GeoPoint(
    latitude: (json['latitude']! as num).toDouble(),
    longitude: (json['longitude']! as num).toDouble(),
    accuracy: (json['accuracy']! as num).toDouble(),
    recordedAt: DateTime.parse(json['recordedAt']! as String),
  );
}

/// 1回の探索における時間、概算距離、位置履歴を保持する。
class Exploration {
  const Exploration({
    required this.id,
    required this.startedAt,
    required this.phase,
    this.endedAt,
    this.elapsedSeconds = 0,
    this.distanceMeters = 0,
    this.trackPoints = const [],
    this.syncState = 'local',
  });
  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final ExplorationPhase phase;
  final int elapsedSeconds;
  final double distanceMeters;
  final List<GeoPoint> trackPoints;
  final String syncState;

  Exploration copyWith({
    DateTime? endedAt,
    ExplorationPhase? phase,
    int? elapsedSeconds,
    double? distanceMeters,
    List<GeoPoint>? trackPoints,
  }) => Exploration(
    id: id,
    startedAt: startedAt,
    endedAt: endedAt ?? this.endedAt,
    phase: phase ?? this.phase,
    elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
    distanceMeters: distanceMeters ?? this.distanceMeters,
    trackPoints: trackPoints ?? this.trackPoints,
    syncState: syncState,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt?.toIso8601String(),
    'phase': phase.name,
    'elapsedSeconds': elapsedSeconds,
    'distanceMeters': distanceMeters,
    'trackPoints': trackPoints.map((p) => p.toJson()).toList(),
    'syncState': syncState,
  };
  factory Exploration.fromJson(Map<String, Object?> json) => Exploration(
    id: json['id']! as String,
    startedAt: DateTime.parse(json['startedAt']! as String),
    endedAt: json['endedAt'] == null
        ? null
        : DateTime.parse(json['endedAt']! as String),
    phase: ExplorationPhase.values.byName(json['phase']! as String),
    elapsedSeconds: json['elapsedSeconds']! as int,
    distanceMeters: (json['distanceMeters']! as num).toDouble(),
    trackPoints: (json['trackPoints']! as List<Object?>)
        .map((p) => GeoPoint.fromJson(p! as Map<String, Object?>))
        .toList(),
    syncState: json['syncState']! as String,
  );
}

/// 1枚の写真と、その場で入力した観察内容を保持する。
class Observation {
  const Observation({
    required this.id,
    required this.explorationId,
    required this.imagePath,
    required this.createdAt,
    this.foundAt = '',
    this.note = '',
    this.classification = ClassificationStatus.pending,
    this.syncState = 'local',
  });
  final String id;
  final String explorationId;
  final String imagePath;
  final DateTime createdAt;
  final String foundAt;
  final String note;
  final ClassificationStatus classification;
  final String syncState;

  Observation copyWith({
    String? foundAt,
    String? note,
    ClassificationStatus? classification,
  }) => Observation(
    id: id,
    explorationId: explorationId,
    imagePath: imagePath,
    createdAt: createdAt,
    foundAt: foundAt ?? this.foundAt,
    note: note ?? this.note,
    classification: classification ?? this.classification,
    syncState: syncState,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'explorationId': explorationId,
    'imagePath': imagePath,
    'createdAt': createdAt.toIso8601String(),
    'foundAt': foundAt,
    'note': note,
    'classification': classification.name,
    'syncState': syncState,
  };
  factory Observation.fromJson(Map<String, Object?> json) => Observation(
    id: json['id']! as String,
    explorationId: json['explorationId']! as String,
    imagePath: json['imagePath']! as String,
    createdAt: DateTime.parse(json['createdAt']! as String),
    foundAt: json['foundAt']! as String,
    note: json['note']! as String,
    classification: ClassificationStatus.values.byName(
      json['classification']! as String,
    ),
    syncState: json['syncState']! as String,
  );
}

/// 完了した探索と観察をひとまとまりで保存した日記項目。
class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.exploration,
    required this.observations,
    required this.savedAt,
  });
  final String id;
  final Exploration exploration;
  final List<Observation> observations;
  final DateTime savedAt;
  Map<String, Object?> toJson() => {
    'id': id,
    'exploration': exploration.toJson(),
    'observations': observations.map((o) => o.toJson()).toList(),
    'savedAt': savedAt.toIso8601String(),
  };
  factory JournalEntry.fromJson(Map<String, Object?> json) => JournalEntry(
    id: json['id']! as String,
    exploration: Exploration.fromJson(
      json['exploration']! as Map<String, Object?>,
    ),
    observations: (json['observations']! as List<Object?>)
        .map((o) => Observation.fromJson(o! as Map<String, Object?>))
        .toList(),
    savedAt: DateTime.parse(json['savedAt']! as String),
  );
}

/// ユーザーと一緒に変化する相棒の状態。
class Companion {
  const Companion({
    this.name = 'ミドリ',
    this.stage = CompanionStage.juvenile,
    this.observationCount = 0,
  });
  final String name;
  final CompanionStage stage;
  final int observationCount;
  Map<String, Object?> toJson() => {
    'name': name,
    'stage': stage.name,
    'observationCount': observationCount,
  };
  factory Companion.fromJson(Map<String, Object?> json) => Companion(
    name: json['name']! as String,
    stage: CompanionStage.values.byName(json['stage']! as String),
    observationCount: json['observationCount']! as int,
  );
}

/// 同意状態と端末内のユーザー設定。
class AppSettings {
  const AppSettings({
    this.onboardingAccepted = false,
    this.explorationInvites = true,
    this.growthNotifications = true,
    this.locationTracking = true,
  });
  final bool onboardingAccepted;
  final bool explorationInvites;
  final bool growthNotifications;
  final bool locationTracking;
  AppSettings copyWith({
    bool? onboardingAccepted,
    bool? explorationInvites,
    bool? growthNotifications,
    bool? locationTracking,
  }) => AppSettings(
    onboardingAccepted: onboardingAccepted ?? this.onboardingAccepted,
    explorationInvites: explorationInvites ?? this.explorationInvites,
    growthNotifications: growthNotifications ?? this.growthNotifications,
    locationTracking: locationTracking ?? this.locationTracking,
  );
  Map<String, Object?> toJson() => {
    'onboardingAccepted': onboardingAccepted,
    'explorationInvites': explorationInvites,
    'growthNotifications': growthNotifications,
    'locationTracking': locationTracking,
  };
  factory AppSettings.fromJson(Map<String, Object?> json) => AppSettings(
    onboardingAccepted: json['onboardingAccepted']! as bool,
    explorationInvites: json['explorationInvites']! as bool,
    growthNotifications: json['growthNotifications']! as bool,
    locationTracking: json['locationTracking']! as bool,
  );
}

/// 複数モデルをSQLiteへ格納できるJSON文字列へ変換する。
String encodeMaps(Iterable<Map<String, Object?>> values) =>
    jsonEncode(values.toList());

/// JSON配列を型付きMapの一覧へ復元する。
List<Map<String, Object?>> decodeMaps(String? value) {
  if (value == null || value.isEmpty) return [];
  return (jsonDecode(value) as List<Object?>)
      .map(
        (item) => (item! as Map<Object?, Object?>).map(
          (key, value) => MapEntry(key! as String, value),
        ),
      )
      .toList();
}

/// 単一JSONオブジェクトを型付きMapへ復元する。
Map<String, Object?>? decodeMap(String? value) {
  if (value == null || value.isEmpty) return null;
  return (jsonDecode(value) as Map<Object?, Object?>).map(
    (key, value) => MapEntry(key! as String, value),
  );
}
