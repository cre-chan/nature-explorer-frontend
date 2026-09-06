// 全データ削除の失敗表示と再試行を、端末ファイルを使わずに検証する。
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soba_no_inochi/app/providers.dart';
import 'package:soba_no_inochi/features/settings/settings_view_model.dart';

import 'support/fakes.dart';

void main() {
  test(
    'photo deletion failure is shown and a later retry clears all data',
    () async {
      final database = InMemoryDatabaseService();
      await database.write('settings', 'saved-settings');
      final temp = await Directory.systemTemp.createTemp('soba-settings-test');
      File('${temp.path}/photo.jpg').writeAsBytesSync([1, 2, 3]);
      final files = FakeFileService(temp)..failToDelete = true;
      final location = FakeLocationService();
      final container = ProviderContainer(
        overrides: [
          databaseServiceProvider.overrideWithValue(database),
          fileServiceProvider.overrideWithValue(files),
          locationServiceProvider.overrideWithValue(location),
        ],
      );
      final viewModel = container.read(settingsViewModelProvider.notifier);

      expect(await viewModel.deleteAll(), isFalse);
      expect(container.read(settingsViewModelProvider).error, isNotNull);
      expect(temp.existsSync(), isTrue);

      files.failToDelete = false;
      expect(await viewModel.deleteAll(), isTrue);
      expect(database.values, isEmpty);
      expect(temp.existsSync(), isFalse);
      expect(files.deleteCount, 2);

      container.dispose();
      await Future<void>.delayed(Duration.zero);
      await location.close();
    },
  );
}
