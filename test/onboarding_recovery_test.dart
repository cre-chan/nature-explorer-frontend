// 起動時の位置停止失敗を一時停止と誤表示せず、再試行できることを検証する。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:soba_no_inochi/app/providers.dart';
import 'package:soba_no_inochi/data/models/app_models.dart';
import 'package:soba_no_inochi/features/onboarding/onboarding_view.dart';

import 'support/fakes.dart';

void main() {
  testWidgets(
    'restore stop failure blocks paused route until explicit retry succeeds',
    (tester) async {
      final database = InMemoryDatabaseService();
      final temp = Directory.systemTemp.createTempSync('soba-restore-retry');
      final location = FakeLocationService()
        ..tracking = true
        ..failToStop = true;
      final interrupted = Exploration(
        id: 'interrupted-widget',
        startedAt: DateTime(2026, 9, 7, 9),
        phase: ExplorationPhase.active,
      );
      await database.write(
        'active_exploration',
        jsonEncode(interrupted.toJson()),
      );
      await database.write(
        'settings',
        jsonEncode(const AppSettings(onboardingAccepted: true).toJson()),
      );
      final container = ProviderContainer(
        overrides: [
          databaseServiceProvider.overrideWithValue(database),
          fileServiceProvider.overrideWithValue(FakeFileService(temp)),
          locationServiceProvider.overrideWithValue(location),
          clockServiceProvider.overrideWithValue(
            FakeClockService(DateTime(2026, 9, 7, 9, 2)),
          ),
        ],
      );
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const OnboardingView()),
          GoRoute(
            path: '/exploration/paused',
            builder: (_, _) => const Scaffold(body: Text('paused-route')),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('位置記録を停止できませんでした'), findsOneWidget);
      expect(find.text('位置記録の停止を再試行する'), findsOneWidget);
      expect(find.text('paused-route'), findsNothing);
      expect(location.tracking, isTrue);
      expect(
        Exploration.fromJson(
          jsonDecode(database.values['active_exploration']!)
              as Map<String, Object?>,
        ).phase,
        ExplorationPhase.active,
      );

      location.failToStop = false;
      await tester.tap(find.text('位置記録の停止を再試行する'));
      await tester.pumpAndSettle();

      expect(find.text('paused-route'), findsOneWidget);
      expect(location.stopCount, 1);
      expect(location.tracking, isFalse);
      expect(
        Exploration.fromJson(
          jsonDecode(database.values['active_exploration']!)
              as Map<String, Object?>,
        ).phase,
        ExplorationPhase.paused,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      router.dispose();
      container.dispose();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await location.close();
      temp.deleteSync(recursive: true);
    },
  );
}
