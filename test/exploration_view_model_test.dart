// 位置セッションの失敗時に、探索UIが端末状態と食い違わないことを検証する。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soba_no_inochi/app/providers.dart';
import 'package:soba_no_inochi/data/models/app_models.dart';
import 'package:soba_no_inochi/features/exploration/exploration_view_model.dart';

import 'support/fakes.dart';

void main() {
  test('pause failure keeps exploration active and exposes an error', () async {
    final location = FakeLocationService();
    final container = ProviderContainer(
      overrides: [
        databaseServiceProvider.overrideWithValue(InMemoryDatabaseService()),
        clockServiceProvider.overrideWithValue(
          FakeClockService(DateTime(2026, 9, 4, 9)),
        ),
        locationServiceProvider.overrideWithValue(location),
      ],
    );
    final viewModel = container.read(explorationViewModelProvider.notifier);
    viewModel.setSafetyAccepted(true);
    expect(await viewModel.start(), isTrue);

    location.failToStop = true;
    expect(await viewModel.togglePause(), isFalse);
    final state = container.read(explorationViewModelProvider);
    expect(state.exploration?.phase, ExplorationPhase.active);
    expect(state.busy, isFalse);
    expect(state.error, contains('位置記録を停止できませんでした'));

    location.failToStop = false;
    await container.read(explorationRepositoryProvider).clearActive();
    container.dispose();
    await Future<void>.delayed(Duration.zero);
    await location.close();
  });

  test('repository null emission clears the exploration UI state', () async {
    final location = FakeLocationService();
    final container = ProviderContainer(
      overrides: [
        databaseServiceProvider.overrideWithValue(InMemoryDatabaseService()),
        clockServiceProvider.overrideWithValue(
          FakeClockService(DateTime(2026, 9, 4, 9)),
        ),
        locationServiceProvider.overrideWithValue(location),
      ],
    );
    final viewModel = container.read(explorationViewModelProvider.notifier);
    viewModel.setSafetyAccepted(true);
    expect(await viewModel.start(), isTrue);
    expect(container.read(explorationViewModelProvider).exploration, isNotNull);

    await container.read(explorationRepositoryProvider).clearActive();
    await Future<void>.delayed(Duration.zero);

    expect(container.read(explorationViewModelProvider).exploration, isNull);
    container.dispose();
    await Future<void>.delayed(Duration.zero);
    await location.close();
  });

  test(
    'automatic stop failure is exposed and a later retry completes',
    () async {
      final location = FakeLocationService()..failToStop = true;
      final clock = FakeClockService(DateTime(2026, 9, 4, 9));
      final container = ProviderContainer(
        overrides: [
          databaseServiceProvider.overrideWithValue(InMemoryDatabaseService()),
          clockServiceProvider.overrideWithValue(clock),
          locationServiceProvider.overrideWithValue(location),
        ],
      );
      final viewModel = container.read(explorationViewModelProvider.notifier);
      viewModel.setSafetyAccepted(true);
      expect(await viewModel.start(), isTrue);

      clock.advance(const Duration(minutes: 30));
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(
        container.read(explorationViewModelProvider).error,
        contains('自動終了'),
      );
      expect(
        container.read(explorationViewModelProvider).exploration?.phase,
        ExplorationPhase.active,
      );

      location.failToStop = false;
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(
        container.read(explorationViewModelProvider).exploration?.phase,
        ExplorationPhase.completed,
      );
      expect(container.read(explorationViewModelProvider).error, isNull);
      container.dispose();
      await Future<void>.delayed(Duration.zero);
      await location.close();
    },
  );
}
