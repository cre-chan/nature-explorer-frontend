// ProviderをFakeへ差し替え、初回同意から日記保存までの主要UIフローを検証する。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soba_no_inochi/app/app.dart';
import 'package:soba_no_inochi/app/providers.dart';
import 'package:soba_no_inochi/data/models/app_models.dart';
import 'package:soba_no_inochi/features/exploration/exploration_view.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('onboarding to journal flow can run with provider fakes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final temp = Directory.systemTemp.createTempSync('soba-widget');
    final source = File('${temp.path}/source.jpg')..writeAsBytesSync([1, 2, 3]);
    final location = FakeLocationService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseServiceProvider.overrideWithValue(InMemoryDatabaseService()),
          clockServiceProvider.overrideWithValue(
            FakeClockService(DateTime(2026, 9, 4, 9)),
          ),
          locationServiceProvider.overrideWithValue(location),
          cameraServiceProvider.overrideWithValue(
            FakeCameraService(source.path),
          ),
          fileServiceProvider.overrideWithValue(FakeFileService(temp)),
          imageSanitizationServiceProvider.overrideWithValue(
            FakeImageSanitizationService(),
          ),
          aiClassificationServiceProvider.overrideWithValue(
            FakeAiClassificationService(),
          ),
        ],
        child: const SobaNoInochiApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('ミドリに会う'), findsOneWidget);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.text('ミドリに会う'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('葉っぱの食べあとを探してみよう'), findsOneWidget);
    await tester.tap(find.text('葉っぱの食べあとを探してみよう'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, '探索を始める'))
        .onPressed!();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.text('探索を始める'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(find.text('写真を撮る'), findsOneWidget);
    tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, '写真を撮る'))
        .onPressed!();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.text('どこで見つけましたか？'), findsOneWidget);
    await tester.tap(find.text('葉の上'));
    await tester.pump();
    await tester.tap(find.text('記録して探索を続ける'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    tester
        .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '探索を終了する'))
        .onPressed!();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.textContaining('ミドリの模様'), findsOneWidget);
    await tester.tap(find.text('自然日記に残す'));
    await tester.pumpAndSettle();
    expect(find.text('1つの小さな発見'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await location.close();
    temp.deleteSync(recursive: true);
  });

  testWidgets('location denial is shown without leaving preparation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final location = FakeLocationService()..access = LocationAccess.denied;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseServiceProvider.overrideWithValue(InMemoryDatabaseService()),
          clockServiceProvider.overrideWithValue(
            FakeClockService(DateTime(2026, 9, 4, 9)),
          ),
          locationServiceProvider.overrideWithValue(location),
        ],
        child: const MaterialApp(home: ExplorationPrepView()),
      ),
    );
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.text('探索を始める'));
    await tester.pump();
    expect(find.text('探索には位置情報の許可が必要です'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await location.close();
  });
}
