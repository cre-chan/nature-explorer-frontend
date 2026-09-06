// 日記確定途中の失敗後も、重複せず再試行できることを検証する。
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soba_no_inochi/app/providers.dart';
import 'package:soba_no_inochi/features/journal/journal_view_model.dart';

import 'support/fakes.dart';

void main() {
  test(
    'retry after progress cleanup failure does not duplicate results',
    () async {
      final database = InMemoryDatabaseService();
      final location = FakeLocationService();
      final clock = FakeClockService(DateTime(2026, 9, 6, 12));
      final temp = await Directory.systemTemp.createTemp('soba-journal-retry');
      final source = File('${temp.path}/source.jpg')
        ..writeAsBytesSync([1, 2, 3]);
      final container = ProviderContainer(
        overrides: [
          databaseServiceProvider.overrideWithValue(database),
          locationServiceProvider.overrideWithValue(location),
          clockServiceProvider.overrideWithValue(clock),
          cameraServiceProvider.overrideWithValue(
            FakeCameraService(source.path),
          ),
          fileServiceProvider.overrideWithValue(FakeFileService(temp)),
          imageSanitizationServiceProvider.overrideWithValue(
            FakeImageSanitizationService(),
          ),
        ],
      );
      final exploration = container.read(explorationRepositoryProvider);
      await exploration.start();
      await exploration.stop();
      await container
          .read(observationRepositoryProvider)
          .capture(exploration.active!.id);
      database.failNextDeleteForKey = 'active_exploration';
      final viewModel = container.read(journalViewModelProvider.notifier);

      expect(await viewModel.saveCurrent(), isFalse);
      expect(container.read(journalViewModelProvider).error, isNotNull);
      expect(
        await container.read(journalRepositoryProvider).list(),
        hasLength(1),
      );
      expect(
        (await container.read(companionRepositoryProvider).load())
            .observationCount,
        1,
      );
      expect(exploration.active, isNotNull);
      expect(
        container.read(observationRepositoryProvider).current,
        hasLength(1),
      );

      expect(await viewModel.saveCurrent(), isTrue);
      expect(
        await container.read(journalRepositoryProvider).list(),
        hasLength(1),
      );
      expect(
        (await container.read(companionRepositoryProvider).load())
            .observationCount,
        1,
      );
      expect(exploration.active, isNull);
      expect(container.read(observationRepositoryProvider).current, isEmpty);

      container.dispose();
      await Future<void>.delayed(Duration.zero);
      await location.close();
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    },
  );
}
