// 画像無害化失敗時に観察を保存せず、ユーザーへ通知して再撮影できることを検証する。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soba_no_inochi/app/providers.dart';
import 'package:soba_no_inochi/data/models/app_models.dart';
import 'package:soba_no_inochi/features/observation/capture_view.dart';
import 'package:soba_no_inochi/features/observation/capture_view_model.dart';

import 'support/fakes.dart';

class _FailingCaptureViewModel extends CaptureViewModel {
  @override
  CaptureUiState build() => const CaptureUiState();

  @override
  Future<Observation?> capture() async {
    state = const CaptureUiState(error: '写真を安全に保存できませんでした');
    return null;
  }
}

void main() {
  test(
    'sanitization failure does not persist and a retry can succeed',
    () async {
      final temp = await Directory.systemTemp.createTemp('soba-sanitize-fail');
      final source = File('${temp.path}/source.jpg')
        ..writeAsBytesSync([1, 2, 3]);
      final database = InMemoryDatabaseService();
      final location = FakeLocationService();
      final sanitizer = FakeImageSanitizationService()..failToSanitize = true;
      final container = ProviderContainer(
        overrides: [
          databaseServiceProvider.overrideWithValue(database),
          locationServiceProvider.overrideWithValue(location),
          cameraServiceProvider.overrideWithValue(
            FakeCameraService(source.path),
          ),
          fileServiceProvider.overrideWithValue(FakeFileService(temp)),
          imageSanitizationServiceProvider.overrideWithValue(sanitizer),
          clockServiceProvider.overrideWithValue(
            FakeClockService(DateTime(2026, 9, 6, 12)),
          ),
        ],
      );
      final exploration = container.read(explorationRepositoryProvider);
      await exploration.start();
      final viewModel = container.read(captureViewModelProvider.notifier);

      expect(await viewModel.capture(), isNull);
      expect(container.read(captureViewModelProvider).error, isNotNull);
      expect(container.read(observationRepositoryProvider).current, isEmpty);
      expect(database.values['current_observations'], isNull);
      expect(location.tracking, isTrue);

      sanitizer.failToSanitize = false;
      expect(await viewModel.capture(), isNotNull);
      expect(
        container.read(observationRepositoryProvider).current,
        hasLength(1),
      );
      expect(sanitizer.sanitizeCount, 2);
      expect(location.tracking, isTrue);

      await exploration.clearActive();
      container.dispose();
      await Future<void>.delayed(Duration.zero);
      await location.close();
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    },
  );

  testWidgets('sanitization failure is shown in a snackbar', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          captureViewModelProvider.overrideWith(_FailingCaptureViewModel.new),
        ],
        child: const MaterialApp(
          home: Scaffold(body: CaptureView(enabled: true)),
        ),
      ),
    );

    await tester.tap(find.text('写真を撮る'));
    await tester.pump();

    expect(find.text('写真を安全に保存できませんでした'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });
}
