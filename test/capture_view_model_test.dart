// カメラキャンセル後も探索を維持し、再撮影できることを検証する。
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soba_no_inochi/app/providers.dart';
import 'package:soba_no_inochi/features/observation/capture_view_model.dart';

import 'support/fakes.dart';

void main() {
  test(
    'camera cancellation keeps exploration active and allows retry',
    () async {
      final temp = await Directory.systemTemp.createTemp('soba-camera-cancel');
      final camera = FakeCameraService(null);
      final database = InMemoryDatabaseService();
      final location = FakeLocationService();
      final container = ProviderContainer(
        overrides: [
          databaseServiceProvider.overrideWithValue(database),
          locationServiceProvider.overrideWithValue(location),
          cameraServiceProvider.overrideWithValue(camera),
          fileServiceProvider.overrideWithValue(FakeFileService(temp)),
          imageSanitizationServiceProvider.overrideWithValue(
            FakeImageSanitizationService(),
          ),
          clockServiceProvider.overrideWithValue(
            FakeClockService(DateTime(2026, 9, 6, 12)),
          ),
        ],
      );
      final exploration = container.read(explorationRepositoryProvider);
      await exploration.start();
      final viewModel = container.read(captureViewModelProvider.notifier);

      expect(await viewModel.capture(), isNull);
      final cancelledState = container.read(captureViewModelProvider);
      expect(cancelledState.capturing, isFalse);
      expect(cancelledState.draft, isNull);
      expect(cancelledState.error, isNull);
      expect(container.read(observationRepositoryProvider).current, isEmpty);
      expect(database.values['current_observations'], isNull);
      expect(exploration.active, isNotNull);
      expect(location.tracking, isTrue);

      final source = File('${temp.path}/source.jpg')
        ..writeAsBytesSync([1, 2, 3]);
      camera.source = source.path;
      final captured = await viewModel.capture();
      expect(captured, isNotNull);
      expect(camera.captureCount, 2);
      expect(
        container.read(observationRepositoryProvider).current,
        hasLength(1),
      );
      expect(exploration.active, isNotNull);
      expect(location.tracking, isTrue);

      await exploration.clearActive();
      container.dispose();
      await Future<void>.delayed(Duration.zero);
      await location.close();
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    },
  );
}
