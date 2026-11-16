
 // Road Runner — Unit Tests for SqliteRunRepository
// Owner: Nadeesha
// SRS reference: Section 8.5

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/core/contract/contract.dart';
import 'package:road_runner/data/app_database.dart';
import 'package:road_runner/data/run.dart';
import 'package:road_runner/data/run_repository.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  group('SqliteRunRepository Tests (SRS §8.5)', () {
    late FakeDatabase fakeDb;
    late AppDatabase appDatabase;
    late SqliteRunRepository repository;
    late Directory tempDir;

    setUp(() {
      fakeDb = FakeDatabase();
      appDatabase = AppDatabase(database: fakeDb);
      tempDir = Directory.systemTemp.createTempSync('road_runner_repo_test_');
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

    test('saveFromFile imports valid JSONL, computes metrics, and inserts into DB', () async {
      final runId = 'test-run-123';
      final file = File('${tempDir.path}/$runId.jsonl');

      // Approximately 1 km run with one pause.
      // The first accepted point after resuming becomes a new distance baseline.
      final content = StringBuffer()
        ..writeln('{"v":1,"runId":"$runId","startedAtUtcMs":1731600000000}')
        // First point before pause.
        ..writeln('{"k":"p","seq":0,"t":1731600000000,"lat":0.0,"lon":0.0,"acc":4.0,"spd":2.78,"alt":10.0,"ok":1}')
        ..writeln('{"k":"s","t":1731600050000,"state":"paused"}')
        ..writeln('{"k":"s","t":1731600070000,"state":"running"}')
        // First point after resume: new baseline.
        ..writeln('{"k":"p","seq":1,"t":1731600070000,"lat":0.0,"lon":0.0,"acc":3.0,"spd":0.0,"alt":10.0,"ok":true}')
        // Rejected GPS spike.
        ..writeln('{"k":"p","seq":2,"t":1731600100000,"lat":5.0,"lon":5.0,"acc":50.0,"spd":20.0,"alt":10.0,"ok":false}')
        // Approximately 1,000 metres from the resumed baseline.
        ..writeln('{"k":"p","seq":3,"t":1731600320000,"lat":0.0089933,"lon":0.0,"acc":3.5,"spd":3.2,"alt":12.0,"ok":true}')
        ..writeln('{"k":"end","t":1731600320000}');

      await file.writeAsString(content.toString());

      await repository.saveFromFile(runId, file.path);

      // Verify Run was inserted
      final run = await repository.get(runId);
      expect(run, isNotNull);
      expect(run!.id, runId);
      expect(run.startedAtUtcMs, 1731600000000);
      expect(run.endedAtUtcMs, 1731600320000);

      // Total elapsed = 320,000ms, paused = 20,000ms -> movingMs = 300,000ms
      expect(run.movingMs, 300000);

      // Distance computed between accepted points only
      expect(run.distanceM, closeTo(1000.0, 1.0));
      expect(run.avgPaceSecPerKm, isNotNull);
      expect(run.avgPaceSecPerKm!, closeTo(300.0, 1.0));

      // Max speed among accepted points only
      expect(run.maxSpeedMps, closeTo(3.2, 0.01));
      expect(run.status, kStateSaved);

      // Verify all GPS points were inserted (including baseline and rejected point).
      final points = await repository.getPoints(runId);
      expect(points, hasLength(4));

      expect(points[0].seq, 0);
      expect(points[0].accepted, isTrue);

      expect(points[1].seq, 1);
      expect(points[1].accepted, isTrue);

      expect(points[2].seq, 2);
      expect(points[2].accepted, isFalse);

      expect(points[3].seq, 3);
      expect(points[3].accepted, isTrue);

      // Verify pause intervals were inserted
      final pauses = await repository.getPauses(runId);
      expect(pauses, hasLength(1));
      expect(pauses.first.startMs, 1731600050000);
      expect(pauses.first.endMs, 1731600070000);
    });

    test('saveFromFile handles incomplete crashed run without end record', () async {
      final runId = 'crashed-run-456';
      final file = File('${tempDir.path}/$runId.jsonl');

      final content = StringBuffer()
        ..writeln('{"v":1,"runId":"$runId","startedAtUtcMs":1000}')
        ..writeln('{"k":"p","seq":0,"t":1000,"lat":0.0,"lon":0.0,"acc":3.0,"spd":2.5,"alt":5.0,"ok":1}')
        ..writeln('{"k":"p","seq":1,"t":5000,"lat":0.0001,"lon":0.0,"acc":3.0,"spd":2.5,"alt":5.0,"ok":1}');

      // No end record
      await file.writeAsString(content.toString());

      await repository.saveFromFile(runId, file.path);

      final run = await repository.get(runId);
      expect(run, isNotNull);
      expect(run!.id, runId);
      expect(run.startedAtUtcMs, 1000);
      expect(run.endedAtUtcMs, 5000);
      expect(run.movingMs, 4000);
    });

    // Test: Kotlin sends boolean values instead of 1/0.
    test('saveFromFile accepts boolean ok values from Kotlin JSONL', () async {
      const runId = 'boolean-ok-test';
      final file = File('${tempDir.path}/$runId.jsonl');

      final content = StringBuffer()
        ..writeln('{"v":1,"runId":"$runId","startedAtUtcMs":1000}')
        ..writeln('{"k":"p","seq":0,"t":1000,"lat":0.0,"lon":0.0,"acc":3.0,"spd":2.0,"alt":5.0,"ok":true}')
        ..writeln('{"k":"p","seq":1,"t":5000,"lat":0.0001,"lon":0.0,"acc":3.0,"spd":2.0,"alt":5.0,"ok":false}')
        ..writeln('{"k":"end","t":5000}');

      await file.writeAsString(content.toString());

      await repository.saveFromFile(runId, file.path);

      final points = await repository.getPoints(runId);

      expect(points, hasLength(2));
      expect(points[0].accepted, isTrue);
      expect(points[1].accepted, isFalse);
    });

    test('saveFromFile handles an immediate-stop run with zero GPS points', () async {
      const runId = 'zero-point-run';
      final file = File('${tempDir.path}/$runId.jsonl');

      final content = StringBuffer()
        ..writeln('{"v":1,"runId":"$runId","startedAtUtcMs":1000}')
        ..writeln('{"k":"end","t":1000}');

      await file.writeAsString(content.toString());
      await repository.saveFromFile(runId, file.path);

      final run = await repository.get(runId);
      expect(run, isNotNull);
      expect(run!.id, runId);
      expect(run.distanceM, 0.0);
      expect(run.avgPaceSecPerKm, isNull);
      expect(run.movingMs, 0);

      final points = await repository.getPoints(runId);
      expect(points, isEmpty);
    });

    test('saveFromFile rejects malformed files or runId mismatch', () async {
      final file = File('${tempDir.path}/bad.jsonl');

      // 1. Missing file
      expect(
        () => repository.saveFromFile(
          'id-1',
          '${tempDir.path}/nonexistent.jsonl',
        ),
        throwsA(isA<FileSystemException>()),
      );

      // 2. Empty file
      await file.writeAsString('');
      expect(
        () => repository.saveFromFile('id-1', file.path),
        throwsA(isA<FormatException>()),
      );

      // 3. Run ID mismatch
      await file.writeAsString(
        '{"v":1,"runId":"id-WRONG","startedAtUtcMs":1000}\n',
      );
      expect(
        () => repository.saveFromFile('id-EXPECTED', file.path),
        throwsA(isA<FormatException>()),
      );

      // 4. Corrupt JSON line
      await file.writeAsString(
        '{"v":1,"runId":"id-1","startedAtUtcMs":1000}\n{not-json\n',
      );
      expect(
        () => repository.saveFromFile('id-1', file.path),
        throwsA(isA<FormatException>()),
      );
    });

    test('list returns runs sorted by started_at_utc_ms descending', () async {
      final runOld = const Run(
        id: 'run-old',
        startedAtUtcMs: 1000,
        endedAtUtcMs: 2000,
        movingMs: 1000,
        distanceM: 500.0,
      );

      final runNew = const Run(
        id: 'run-new',
        startedAtUtcMs: 5000,
        endedAtUtcMs: 6000,
        movingMs: 1000,
        distanceM: 500.0,
      );

      fakeDb.tables[AppDatabase.tableRuns]!.add(runOld.toDbMap());
      fakeDb.tables[AppDatabase.tableRuns]!.add(runNew.toDbMap());

      final runs = await repository.list();
      expect(runs, hasLength(2));
      expect(runs[0].id, 'run-new');
      expect(runs[1].id, 'run-old');
    });

    test('get returns null if run does not exist', () async {
      expect(await repository.get('non-existent-id'), isNull);
    });

    test('delete removes run, associated points, and pause intervals', () async {
      final runId = 'to-delete';

      fakeDb.tables[AppDatabase.tableRuns]!.add({
        'id': runId,
        'started_at_utc_ms': 1000,
        'ended_at_utc_ms': 2000,
        'moving_ms': 1000,
        'distance_m': 100.0,
        'status': 'saved',
      });

      fakeDb.tables[AppDatabase.tableRunPoints]!.add({
        'run_id': runId,
        'seq': 0,
        't_utc_ms': 1000,
        'lat': 0.0,
        'lon': 0.0,
        'acc_m': 3.0,
        'accepted': 1,
      });

      fakeDb.tables[AppDatabase.tableRunPauses]!.add({
        'run_id': runId,
        'start_ms': 1200,
        'end_ms': 1400,
      });

      expect(await repository.get(runId), isNotNull);
      expect(await repository.getPoints(runId), hasLength(1));
      expect(await repository.getPauses(runId), hasLength(1));

      await repository.delete(runId);

      expect(await repository.get(runId), isNull);
      expect(await repository.getPoints(runId), isEmpty);
      expect(await repository.getPauses(runId), isEmpty);
    });

    test('saveFromFile persists pause intervals and getPauses returns them in chronological order', () async {
      final runId = 'run-with-multiple-pauses';
      final file = File('${tempDir.path}/$runId.jsonl');

      final content = StringBuffer()
        ..writeln('{"v":1,"runId":"$runId","startedAtUtcMs":1000}')
        ..writeln('{"k":"p","seq":0,"t":1000,"lat":0.0,"lon":0.0,"acc":4.0,"spd":2.5,"alt":10.0,"ok":1}')
        ..writeln('{"k":"s","t":1500,"state":"paused"}')
        ..writeln('{"k":"s","t":2000,"state":"running"}')
        ..writeln('{"k":"p","seq":1,"t":2500,"lat":0.001,"lon":0.0,"acc":4.0,"spd":2.5,"alt":10.0,"ok":1}')
        ..writeln('{"k":"s","t":3000,"state":"paused"}')
        ..writeln('{"k":"s","t":3500,"state":"running"}')
        ..writeln('{"k":"p","seq":2,"t":4000,"lat":0.002,"lon":0.0,"acc":4.0,"spd":2.5,"alt":10.0,"ok":1}')
        ..writeln('{"k":"end","t":4000}');

      await file.writeAsString(content.toString());
      await repository.saveFromFile(runId, file.path);

      final pauses = await repository.getPauses(runId);
      expect(pauses, hasLength(2));
      expect(pauses[0].startMs, 1500);
      expect(pauses[0].endMs, 2000);
      expect(pauses[1].startMs, 3000);
      expect(pauses[1].endMs, 3500);
    });

    test('saving the same run again replaces previous pause intervals instead of duplicating', () async {
      final runId = 'run-replace-pauses';
      final file = File('${tempDir.path}/$runId.jsonl');

      // Initial run with 2 pauses
      final content1 = StringBuffer()
        ..writeln('{"v":1,"runId":"$runId","startedAtUtcMs":1000}')
        ..writeln('{"k":"p","seq":0,"t":1000,"lat":0.0,"lon":0.0,"acc":4.0,"spd":2.5,"alt":10.0,"ok":1}')
        ..writeln('{"k":"s","t":1500,"state":"paused"}')
        ..writeln('{"k":"s","t":2000,"state":"running"}')
        ..writeln('{"k":"s","t":2500,"state":"paused"}')
        ..writeln('{"k":"s","t":3000,"state":"running"}')
        ..writeln('{"k":"end","t":3000}');

      await file.writeAsString(content1.toString());
      await repository.saveFromFile(runId, file.path);

      expect(await repository.getPauses(runId), hasLength(2));

      // Overwrite file with updated content (only 1 pause)
      final content2 = StringBuffer()
        ..writeln('{"v":1,"runId":"$runId","startedAtUtcMs":1000}')
        ..writeln('{"k":"p","seq":0,"t":1000,"lat":0.0,"lon":0.0,"acc":4.0,"spd":2.5,"alt":10.0,"ok":1}')
        ..writeln('{"k":"s","t":1800,"state":"paused"}')
        ..writeln('{"k":"s","t":2200,"state":"running"}')
        ..writeln('{"k":"end","t":3000}');

      await file.writeAsString(content2.toString());
      await repository.saveFromFile(runId, file.path);

      final updatedPauses = await repository.getPauses(runId);
      expect(updatedPauses, hasLength(1));
      expect(updatedPauses.first.startMs, 1800);
      expect(updatedPauses.first.endMs, 2200);
    });

    test('getPauses returns empty list for runs without pauses or non-existent runs', () async {
      final runId = 'no-pause-run';
      final file = File('${tempDir.path}/$runId.jsonl');

      final content = StringBuffer()
        ..writeln('{"v":1,"runId":"$runId","startedAtUtcMs":1000}')
        ..writeln('{"k":"p","seq":0,"t":1000,"lat":0.0,"lon":0.0,"acc":4.0,"spd":2.5,"alt":10.0,"ok":1}')
        ..writeln('{"k":"end","t":2000}');

      await file.writeAsString(content.toString());
      await repository.saveFromFile(runId, file.path);

      expect(await repository.getPauses(runId), isEmpty);
      expect(await repository.getPauses('non-existent-run'), isEmpty);
    });

    test('getUnfinishedRunPath returns path of latest unclosed JSONL file', () async {
      // Completed run
      final completed = File('${tempDir.path}/completed.jsonl');
      await completed.writeAsString(
        '{"v":1,"runId":"completed","startedAtUtcMs":1000}\n'
        '{"k":"p","seq":0,"t":1000,"lat":0.0,"lon":0.0,"acc":3.0,"spd":2.0,"alt":5.0,"ok":1}\n'
        '{"k":"end","t":2000}\n',
      );

      expect(await repository.getUnfinishedRunPath(), isNull);

      // Unfinished run (no end record)
      final unfinished = File('${tempDir.path}/unfinished.jsonl');
      await unfinished.writeAsString(
        '{"v":1,"runId":"unfinished","startedAtUtcMs":3000}\n'
        '{"k":"p","seq":0,"t":3000,"lat":0.0,"lon":0.0,"acc":3.0,"spd":2.0,"alt":5.0,"ok":1}\n',
      );

      final path = await repository.getUnfinishedRunPath();
      expect(path, isNotNull);
      expect(File(path!).existsSync(), isTrue);
      expect(path, contains('unfinished.jsonl'));
    });
  });
}

// ─── Test Fakes for Deterministic In-Memory SQLite Testing ───────────────────

class FakeDatabase extends Fake implements Database {
  final Map<String, List<Map<String, Object?>>> tables = {
    AppDatabase.tableRuns: [],
    AppDatabase.tableRunPoints: [],
    AppDatabase.tableRunPauses: [],
  };

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) async {
    final txn = FakeTransaction(this);
    return await action(txn);
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final rows = List<Map<String, Object?>>.from(tables[table] ?? []);

    var filtered = rows;

    if (where != null && whereArgs != null) {
      if (where.startsWith('id = ?')) {
        final id = whereArgs.first;
        filtered = filtered.where((r) => r['id'] == id).toList();
      } else if (where.startsWith('run_id = ?')) {
        final runId = whereArgs.first;
        filtered = filtered.where((r) => r['run_id'] == runId).toList();
      }
    }

    if (orderBy != null) {
      if (orderBy.contains('started_at_utc_ms DESC')) {
        filtered.sort((a, b) =>
            ((b['started_at_utc_ms'] as num?) ?? 0)
                .compareTo((a['started_at_utc_ms'] as num?) ?? 0));
      } else if (orderBy.contains('seq ASC')) {
        filtered.sort((a, b) =>
            ((a['seq'] as num?) ?? 0).compareTo((b['seq'] as num?) ?? 0));
      } else if (orderBy.contains('start_ms ASC')) {
        filtered.sort((a, b) =>
            ((a['start_ms'] as num?) ?? 0)
                .compareTo((b['start_ms'] as num?) ?? 0));
      }
    }

    if (limit != null && filtered.length > limit) {
      filtered = filtered.take(limit).toList();
    }

    return filtered;
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final list = tables[table]!;

    if (conflictAlgorithm == ConflictAlgorithm.replace) {
      list.removeWhere((item) => item['id'] == values['id']);
    }

    list.add(Map<String, Object?>.from(values));
    return 1;
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final list = tables[table]!;
    final initialLength = list.length;

    if (where != null && whereArgs != null) {
      if (where.startsWith('id = ?')) {
        list.removeWhere((item) => item['id'] == whereArgs.first);
      } else if (where.startsWith('run_id = ?')) {
        list.removeWhere((item) => item['run_id'] == whereArgs.first);
      }
    } else {
      list.clear();
    }

    return initialLength - list.length;
  }

  @override
  Batch batch() => FakeBatch(this);
}

class FakeTransaction extends Fake implements Transaction {
  final FakeDatabase _db;

  FakeTransaction(this._db);

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    return _db.insert(table, values, conflictAlgorithm: conflictAlgorithm);
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    return _db.delete(table, where: where, whereArgs: whereArgs);
  }

  @override
  Batch batch() => FakeBatch(_db);
}

class FakeBatch extends Fake implements Batch {
  final FakeDatabase _db;
  final List<void Function()> _operations = [];

  FakeBatch(this._db);

  @override
  void insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    _operations.add(() {
      _db.insert(table, values, conflictAlgorithm: conflictAlgorithm);
    });
  }

  @override
  Future<List<Object?>> commit({
    bool? exclusive,
    bool? noResult,
    bool? continueOnError,
  }) async {
    for (final op in _operations) {
      op();
    }

    return [];
  }
}
