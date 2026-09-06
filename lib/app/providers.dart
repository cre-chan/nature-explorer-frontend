// ServiceからRepositoryまでを一方向に組み立てるRiverpod DI定義。
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../data/repositories/repositories.dart';
import '../data/services/services.dart';

// Service Providerは端末実装の差し替え点。テストではFakeへ上書きする。
/// アプリ内JSON値をSQLiteへ保存するService。
final databaseServiceProvider = Provider<DatabaseService>(
  (ref) => SqliteDatabaseService(),
);

/// 現在時刻を供給するService。
final clockServiceProvider = Provider<ClockService>(
  (ref) => const SystemClockService(),
);

/// 位置権限と探索中の位置ストリームを供給するService。
final locationServiceProvider = Provider<LocationService>(
  (ref) => DeviceLocationService(),
);

/// 端末カメラを供給するService。
final cameraServiceProvider = Provider<CameraService>(
  (ref) => DeviceCameraService(ImagePicker()),
);

/// アプリ専用写真領域を供給するService。
final fileServiceProvider = Provider<FileService>((ref) => DeviceFileService());

/// 写真からEXIFを除去するService。
final imageSanitizationServiceProvider = Provider<ImageSanitizationService>(
  (ref) => ReencodingImageSanitizationService(),
);

/// 観察分類のモックを供給するService。
final aiClassificationServiceProvider = Provider<AiClassificationService>(
  (ref) => const MockAiClassificationService(),
);

/// ドメイン識別子を生成する依存。
final uuidProvider = Provider<Uuid>((ref) => const Uuid());

// Repository ProviderだけがService Providerへ依存する。
/// 探索データの唯一の窓口。
final explorationRepositoryProvider = Provider<ExplorationRepository>((ref) {
  final repository = LocalExplorationRepository(
    ref.watch(databaseServiceProvider),
    ref.watch(locationServiceProvider),
    ref.watch(clockServiceProvider),
    ref.watch(uuidProvider),
  );
  // Riverpodの破棄コールバックは待機できないため、Repository自身に非同期後始末を委ねる。
  ref.onDispose(() => unawaited(repository.dispose()));
  return repository;
});

/// 観察データの唯一の窓口。
final observationRepositoryProvider = Provider<ObservationRepository>((ref) {
  final repository = LocalObservationRepository(
    ref.watch(databaseServiceProvider),
    ref.watch(cameraServiceProvider),
    ref.watch(imageSanitizationServiceProvider),
    ref.watch(fileServiceProvider),
    ref.watch(aiClassificationServiceProvider),
    ref.watch(clockServiceProvider),
    ref.watch(uuidProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
});

/// 日記データの唯一の窓口。
final journalRepositoryProvider = Provider<JournalRepository>(
  (ref) => LocalJournalRepository(
    ref.watch(databaseServiceProvider),
    ref.watch(clockServiceProvider),
    ref.watch(uuidProvider),
  ),
);

/// 相棒データの唯一の窓口。
final companionRepositoryProvider = Provider<CompanionRepository>(
  (ref) => LocalCompanionRepository(ref.watch(databaseServiceProvider)),
);

/// 設定データの唯一の窓口。
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => LocalSettingsRepository(
    ref.watch(databaseServiceProvider),
    ref.watch(fileServiceProvider),
  ),
);
