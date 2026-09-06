// Repositoryの永続化、集計、エラー変換、複数探索を端末なしで検証する。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soba_no_inochi/data/models/app_models.dart';
import 'package:soba_no_inochi/data/repositories/repositories.dart';
import 'package:soba_no_inochi/data/services/services.dart';
import 'package:uuid/uuid.dart';

import 'support/fakes.dart';

void main() {
  test('device location service calculates stable haversine distance', () {
    final service = DeviceLocationService();
    final recordedAt = DateTime(2026, 9, 4, 9);
    final from = GeoPoint(
      latitude: 35,
      longitude: 136,
      accuracy: 4,
      recordedAt: recordedAt,
    );
    final to = GeoPoint(
      latitude: 35.0001,
      longitude: 136,
      accuracy: 4,
      recordedAt: recordedAt,
    );
    expect(service.distanceBetween(from, to), closeTo(11.12, 0.05));
  });

  test('exploration records distance and supports pause and resume', () async {
    final location = FakeLocationService();
    final clock = FakeClockService(DateTime(2026, 9, 4, 9));
    final repository = LocalExplorationRepository(
      InMemoryDatabaseService(),
      location,
      clock,
      const Uuid(),
    );
    await repository.start();
    expect(location.startCount, 1);
    expect(location.tracking, isTrue);
    final first = GeoPoint(
      latitude: 35,
      longitude: 136,
      accuracy: 4,
      recordedAt: clock.now(),
    );
    location.emit(first);
    location.emit(
      GeoPoint(
        latitude: 35.0001,
        longitude: 136,
        accuracy: 4,
        recordedAt: clock.now(),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(repository.active?.trackPoints, hasLength(2));
    expect(repository.active?.distanceMeters, 10);
    await repository.pause();
    expect(repository.active?.phase, ExplorationPhase.paused);
    expect(location.stopCount, 1);
    expect(location.tracking, isFalse);
    await repository.pause();
    expect(location.stopCount, 1);
    await repository.resume();
    expect(repository.active?.phase, ExplorationPhase.active);
    expect(location.startCount, 2);
    expect(location.tracking, isTrue);
    await repository.resume();
    expect(location.startCount, 2);
    await repository.stop();
    expect(repository.active?.phase, ExplorationPhase.completed);
    expect(location.stopCount, 2);
    expect(location.tracking, isFalse);
    await repository.dispose();
    await location.close();
  });

  test('exploration ends automatically after thirty minutes', () async {
    final location = FakeLocationService();
    final clock = FakeClockService(DateTime(2026, 9, 4, 9));
    final repository = LocalExplorationRepository(
      InMemoryDatabaseService(),
      location,
      clock,
      const Uuid(),
    );
    await repository.start();
    clock.advance(const Duration(minutes: 30));
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(repository.active?.phase, ExplorationPhase.completed);
    expect(repository.active?.elapsedSeconds, 30 * 60);
    expect(location.stopCount, 1);
    expect(location.tracking, isFalse);
    await repository.dispose();
    await location.close();
  });

  test('automatic stop failure is reported and retried', () async {
    final location = FakeLocationService()..failToStop = true;
    final clock = FakeClockService(DateTime(2026, 9, 4, 9));
    final repository = LocalExplorationRepository(
      InMemoryDatabaseService(),
      location,
      clock,
      const Uuid(),
    );
    final issues = <ExplorationIssue>[];
    final issueSubscription = repository.watchIssues().listen(issues.add);
    await repository.start();
    clock.advance(const Duration(minutes: 30));
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(repository.active?.phase, ExplorationPhase.active);
    expect(issues, [ExplorationIssue.automaticStopFailed]);
    expect(location.tracking, isTrue);

    location.failToStop = false;
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(repository.active?.phase, ExplorationPhase.completed);
    expect(location.stopCount, 1);
    expect(location.tracking, isFalse);
    await issueSubscription.cancel();
    await repository.dispose();
    await location.close();
  });

  test(
    'restoring an interrupted active exploration pauses without restart',
    () async {
      final database = InMemoryDatabaseService();
      final location = FakeLocationService();
      final interrupted = Exploration(
        id: 'interrupted',
        startedAt: DateTime(2026, 9, 4, 9),
        phase: ExplorationPhase.active,
        elapsedSeconds: 75,
      );
      await database.write(
        'active_exploration',
        jsonEncode(interrupted.toJson()),
      );
      final repository = LocalExplorationRepository(
        database,
        location,
        FakeClockService(DateTime(2026, 9, 4, 9, 2)),
        const Uuid(),
      );

      await repository.restore();

      expect(repository.active?.phase, ExplorationPhase.paused);
      expect(repository.active?.elapsedSeconds, 75);
      expect(location.startCount, 0);
      expect(location.tracking, isFalse);
      expect(
        Exploration.fromJson(
          jsonDecode(database.values['active_exploration']!)
              as Map<String, Object?>,
        ).phase,
        ExplorationPhase.paused,
      );
      await repository.dispose();
      await location.close();
    },
  );

  test('clear and dispose both stop an active location session', () async {
    final location = FakeLocationService();
    final repository = LocalExplorationRepository(
      InMemoryDatabaseService(),
      location,
      FakeClockService(DateTime(2026, 9, 4, 9)),
      const Uuid(),
    );
    await repository.start();
    await repository.clearActive();
    expect(repository.active, isNull);
    expect(location.stopCount, 1);
    expect(location.tracking, isFalse);

    await repository.start();
    await repository.dispose();
    expect(location.stopCount, 2);
    expect(location.tracking, isFalse);
    await location.close();
  });

  test('failed tracking start does not leave an active exploration', () async {
    final location = FakeLocationService()..failToStart = true;
    final repository = LocalExplorationRepository(
      InMemoryDatabaseService(),
      location,
      FakeClockService(DateTime(2026, 9, 4, 9)),
      const Uuid(),
    );
    await expectLater(repository.start(), throwsStateError);
    expect(repository.active, isNull);
    expect(location.tracking, isFalse);
    await repository.dispose();
    await location.close();
  });

  test('location denial is converted to a repository error', () async {
    final location = FakeLocationService()..access = LocationAccess.denied;
    final repository = LocalExplorationRepository(
      InMemoryDatabaseService(),
      location,
      FakeClockService(DateTime(2026, 9, 4, 9)),
      const Uuid(),
    );
    await expectLater(
      repository.start(),
      throwsA(
        isA<LocationAccessException>().having(
          (error) => error.access,
          'access',
          LocationAccess.denied,
        ),
      ),
    );
    await repository.dispose();
    await location.close();
  });

  test('indeterminate observations remain valid journal content', () async {
    final database = InMemoryDatabaseService();
    final temp = await Directory.systemTemp.createTemp('soba-test');
    final source = File('${temp.path}/source.jpg');
    await source.writeAsBytes([1, 2, 3]);
    final clock = FakeClockService(DateTime(2026, 9, 4, 10));
    final observations = LocalObservationRepository(
      database,
      FakeCameraService(source.path),
      FakeImageSanitizationService(),
      FakeFileService(temp),
      FakeAiClassificationService(ClassificationStatus.indeterminate),
      clock,
      const Uuid(),
    );
    final item = await observations.capture('exploration-1');
    await observations.updateDetails(item!.id, foundAt: '葉の上', note: 'わからない');
    final classified = await observations.classifyCurrent();
    expect(
      classified.single.classification,
      ClassificationStatus.indeterminate,
    );
    final journal = LocalJournalRepository(database, clock, const Uuid());
    final entry = await journal.save(
      Exploration(
        id: 'exploration-1',
        startedAt: clock.now(),
        endedAt: clock.now(),
        phase: ExplorationPhase.completed,
      ),
      classified,
    );
    expect(entry.observations, hasLength(1));
    observations.dispose();
    await temp.delete(recursive: true);
  });

  test('journal keeps multiple explorations on the same day', () async {
    final database = InMemoryDatabaseService();
    final clock = FakeClockService(DateTime(2026, 9, 4, 10));
    final repository = LocalJournalRepository(database, clock, const Uuid());
    for (final id in ['morning', 'afternoon']) {
      await repository.save(
        Exploration(
          id: id,
          startedAt: clock.now(),
          endedAt: clock.now(),
          phase: ExplorationPhase.completed,
        ),
        const [],
      );
      clock.advance(const Duration(hours: 2));
    }
    final entries = await repository.list();
    expect(entries, hasLength(2));
    expect(
      entries.map((entry) => entry.exploration.id),
      containsAll(['morning', 'afternoon']),
    );
  });

  test(
    'journal and companion updates are idempotent per exploration',
    () async {
      final database = InMemoryDatabaseService();
      final clock = FakeClockService(DateTime(2026, 9, 6, 12));
      final journals = LocalJournalRepository(database, clock, const Uuid());
      final companion = LocalCompanionRepository(database);
      final exploration = Exploration(
        id: 'retry-target',
        startedAt: clock.now(),
        endedAt: clock.now(),
        phase: ExplorationPhase.completed,
      );
      final observations = [
        Observation(
          id: 'observation-1',
          explorationId: exploration.id,
          imagePath: '/safe/photo.jpg',
          createdAt: clock.now(),
          classification: ClassificationStatus.usable,
        ),
      ];

      final firstEntry = await journals.save(exploration, observations);
      final retriedEntry = await journals.save(exploration, observations);
      expect(retriedEntry.id, firstEntry.id);
      expect(await journals.list(), hasLength(1));

      await companion.applyObservations(exploration.id, observations);
      await companion.applyObservations(exploration.id, observations);
      final state = await companion.load();
      expect(state.observationCount, 1);
      expect(state.stage, CompanionStage.changing);
    },
  );
}
