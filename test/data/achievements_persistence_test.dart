// Road Runner — Integration Tests for Badge Persistence & Recalculation
// Owner: Nadeesha
// SRS reference: Section 8.5

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/data/app_database.dart';
import 'package:road_runner/data/run.dart';
import 'package:road_runner/data/run_repository.dart';

import 'run_repository_test.dart';

void main() {
  group('Badge Persistence & Recalculation Tests', () {
    late FakeDatabase fakeDb;
    late AppDatabase appDatabase;
    late SqliteRunRepository repository;
    late Directory tempDir;

    setUp(() {
      fakeDb = FakeDatabase();
      appDatabase = AppDatabase(database: fakeDb);
      tempDir = Directory.systemTemp.createTempSync('road_runner_badge_test_');
      repository = SqliteRunRepository(
        database: appDatabase,
        runsDirectoryPath: tempDir.path,
      );
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('first run imported receives firstRun badge', () async {
      const runId = 'first-ever-run';
      final file = File('${tempDir.path}/$runId.jsonl');

      final content = StringBuffer()
        ..writeln('{"v":1,"runId":"$runId","startedAtUtcMs":1000}')
        ..writeln(
          '{"k":"p","seq":0,"t":1000,"lat":0.0,"lon":0.0,"acc":3.0,"spd":2.5,"alt":10.0,"ok":1}',
        )
        ..writeln('{"k":"end","t":2000}');

      await file.writeAsString(content.toString());
      await repository.saveFromFile(runId, file.path);

      final badges = await repository.getBadgesForRun(runId);
      expect(badges, hasLength(1));
      expect(badges.first.type, BadgeType.firstRun);
    });

    test(
      'repeated import produces identical badge rows (idempotency)',
      () async {
        const runId = 'idempotent-badge-run';
        final file = File('${tempDir.path}/$runId.jsonl');

        final content = StringBuffer()
          ..writeln('{"v":1,"runId":"$runId","startedAtUtcMs":1000}')
          ..writeln(
            '{"k":"p","seq":0,"t":1000,"lat":0.0,"lon":0.0,"acc":3.0,"spd":2.5,"alt":10.0,"ok":1}',
          )
          ..writeln('{"k":"end","t":2000}');

        await file.writeAsString(content.toString());
        await repository.saveFromFile(runId, file.path);

        final badges1 = await repository.getBadgesForRun(runId);
        expect(badges1, hasLength(1));

        // Re-import the exact same run file
        await repository.saveFromFile(runId, file.path);

        final badges2 = await repository.getBadgesForRun(runId);
        expect(badges2, hasLength(1));
        expect(badges2.first.type, BadgeType.firstRun);
      },
    );

    test('deleting earliest run recalculates and transfers firstRun badge to next run', () async {
      // Run 1: started at 1000
      final file1 = File('${tempDir.path}/run-1.jsonl');
      await file1.writeAsString(
        '{"v":1,"runId":"run-1","startedAtUtcMs":1000}\n'
        '{"k":"p","seq":0,"t":1000,"lat":0.0,"lon":0.0,"acc":3.0,"spd":2.5,"alt":10.0,"ok":1}\n'
        '{"k":"end","t":2000}\n',
      );
      await repository.saveFromFile('run-1', file1.path);

      // Run 2: started at 5000
      final file2 = File('${tempDir.path}/run-2.jsonl');
      await file2.writeAsString(
        '{"v":1,"runId":"run-2","startedAtUtcMs":5000}\n'
        '{"k":"p","seq":0,"t":5000,"lat":0.0,"lon":0.0,"acc":3.0,"spd":2.5,"alt":10.0,"ok":1}\n'
        '{"k":"end","t":6000}\n',
      );
      await repository.saveFromFile('run-2', file2.path);

      // Initially run-1 is firstRun, run-2 has no firstRun badge
      final badgesRun1Before = await repository.getBadgesForRun('run-1');
      expect(badgesRun1Before.any((b) => b.type == BadgeType.firstRun), isTrue);

      final badgesRun2Before = await repository.getBadgesForRun('run-2');
      expect(
        badgesRun2Before.any((b) => b.type == BadgeType.firstRun),
        isFalse,
      );

      // Delete run-1
      await repository.delete('run-1');

      // Now run-2 is the earliest run, so it must inherit firstRun badge!
      final badgesRun2After = await repository.getBadgesForRun('run-2');
      expect(badgesRun2After.any((b) => b.type == BadgeType.firstRun), isTrue);
    });

    test('getCurrentStreak returns active consecutive days', () async {
      final now = DateTime.now();
      final todayStr =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';

      final runToday = Run(
        id: 'today-run',
        startedAtUtcMs: now.millisecondsSinceEpoch,
        endedAtUtcMs: now.millisecondsSinceEpoch + 1000,
        movingMs: 1000,
        distanceM: 1000,
        localStartDay: todayStr,
      );

      fakeDb.tables[AppDatabase.tableRuns]!.add(runToday.toDbMap());

      final streak = await repository.getCurrentStreak();
      expect(streak, 1);
    });
  });
}
