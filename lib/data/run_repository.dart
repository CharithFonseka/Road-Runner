// Road Runner — SQLite Run Repository Implementation
// Owner: Nadeesha
// SRS reference: Section 8.5

import 'dart:convert';
import 'dart:io';

import 'package:road_runner/core/contract/contract.dart';
import 'package:road_runner/data/app_database.dart';
import 'package:road_runner/data/run.dart';
import 'package:road_runner/domain/stats/stats.dart';
import 'package:sqflite/sqflite.dart';

/// Repository interface for saving, loading, and managing runs and GPS points.
abstract class RunRepository {
  Future<void> saveFromFile(String runId, String filePath);
  Future<List<Run>> list();
  Future<Run?> get(String runId);
  Future<List<Point>> getPoints(String runId);
  Future<List<PauseInterval>> getPauses(String runId);
  Future<void> delete(String runId);
  Future<String?> getUnfinishedRunPath();
  Future<void> updateDetails(
    String runId, {
    String? runName,
    String? placeName,
    double? temperatureC,
    double? windKmh,
    int? weatherCode,
    String? localStartDay,
  });
}

/// SQLite-backed implementation of [RunRepository] using [AppDatabase].
class SqliteRunRepository implements RunRepository {
  final AppDatabase _database;
  final String? runsDirectoryPath;

  SqliteRunRepository({AppDatabase? database, this.runsDirectoryPath})
    : _database = database ?? AppDatabase.instance;

  @override
  Future<void> saveFromFile(String runId, String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('Run file does not exist', filePath);
    }

    final List<String> lines = await file.readAsLines();
    if (lines.isEmpty) {
      throw const FormatException('Run file is empty');
    }

    // 1. Parse header line
    final dynamic rawHeader;
    try {
      rawHeader = jsonDecode(lines.first);
    } catch (e) {
      throw FormatException('Header line is not valid JSON: ${lines.first}');
    }

    if (rawHeader is! Map<String, dynamic>) {
      throw const FormatException('Header line is not a JSON object');
    }

    final int? version = (rawHeader[kRunFileKeyVersion] as num?)?.toInt();
    if (version != kRunFileVersion) {
      throw FormatException('Unsupported run file version: $version');
    }

    final String? headerRunId = rawHeader[kKeyRunId]?.toString();
    if (headerRunId == null || headerRunId.isEmpty) {
      throw const FormatException('Missing runId in header');
    }
    if (headerRunId != runId) {
      throw FormatException(
        'Run ID mismatch: expected $runId, found $headerRunId',
      );
    }

    final int? startedAtUtcMs = (rawHeader[kRunFileKeyStartedAtUtcMs] as num?)
        ?.toInt();
    if (startedAtUtcMs == null || startedAtUtcMs <= 0) {
      throw const FormatException(
        'Invalid or missing startedAtUtcMs in header',
      );
    }

    // 2. Parse points, pause/resume state records, and end record
    final List<Point> points = [];
    final List<PauseInterval> pauses = [];
    int? endedAtUtcMs;
    int? currentPauseStartMs;

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final dynamic decoded;
      try {
        decoded = jsonDecode(line);
      } catch (e) {
        throw FormatException('Malformed JSON on line ${i + 1}: $line');
      }

      if (decoded is! Map<String, dynamic>) {
        throw FormatException(
          'Line ${i + 1} is not a valid JSON object: $line',
        );
      }

      final String? kind = decoded[kRunFileKeyKind]?.toString();
      switch (kind) {
        case kRunFileKindPoint:
          points.add(Point.fromJsonl(decoded));
          break;

        case kRunFileKindState:
          final String? state = decoded[kKeyState]?.toString();
          final int? t = (decoded[kRunFileKeyTime] as num?)?.toInt();
          if (t == null || t <= 0) break;

          if (state == kStatePaused) {
            currentPauseStartMs = t;
          } else if (state == kStateRunning) {
            if (currentPauseStartMs != null) {
              pauses.add(PauseInterval(startMs: currentPauseStartMs, endMs: t));
              currentPauseStartMs = null;
            }
          }
          break;

        case kRunFileKindEnd:
          endedAtUtcMs = (decoded[kRunFileKeyTime] as num?)?.toInt();
          break;

        default:
          break;
      }
    }

    // If no explicit end record was written (e.g. crashed/recovered run),
    // default end timestamp to the last recorded point's timestamp or start time.
    endedAtUtcMs ??= points.isNotEmpty ? points.last.tUtcMs : startedAtUtcMs;

    // If still in paused state when the file ended, close the pause interval.
    if (currentPauseStartMs != null && currentPauseStartMs < endedAtUtcMs) {
      pauses.add(
        PauseInterval(startMs: currentPauseStartMs, endMs: endedAtUtcMs),
      );
    }

    // 3. Compute running statistics using the pure Dart stats module.
    // Start a new distance segment after every pause.
    final List<Point> acceptedPoints = points
        .where((point) => point.accepted)
        .toList();

    double distanceM = 0.0;
    int pauseIndex = 0;
    Point? previousPoint;

    for (final point in acceptedPoints) {
      // Check whether a pause occurred before this point.
      while (pauseIndex < pauses.length &&
          pauses[pauseIndex].endMs <= point.tUtcMs) {
        final pause = pauses[pauseIndex];

        if (previousPoint != null && previousPoint.tUtcMs <= pause.startMs) {
          previousPoint = null;
        }

        pauseIndex++;
      }

      // Ignore points recorded during a pause.
      final isInsidePause =
          pauseIndex < pauses.length &&
          point.tUtcMs >= pauses[pauseIndex].startMs &&
          point.tUtcMs < pauses[pauseIndex].endMs;

      if (isInsidePause) {
        previousPoint = null;
        continue;
      }

      // Calculate distance within the same running segment.
      if (previousPoint != null) {
        final step = haversineM(
          previousPoint.lat,
          previousPoint.lon,
          point.lat,
          point.lon,
        );

        if (!step.isNaN && !step.isInfinite && step > 0.0) {
          distanceM += step;
        }
      }

      previousPoint = point;
    }

    final int movingMs = computeMovingMs(startedAtUtcMs, endedAtUtcMs, pauses);

    final double? avgPaceSecPerKm = computeAvgPaceSecPerKm(distanceM, movingMs);

    final double? maxSpeedMps = computeMaxSpeedMps(points);
    final localStart = DateTime.fromMillisecondsSinceEpoch(startedAtUtcMs)
        .toLocal();
    final existing = await get(runId);
    final run = Run(
      id: runId,
      startedAtUtcMs: startedAtUtcMs,
      endedAtUtcMs: endedAtUtcMs,
      movingMs: movingMs,
      distanceM: distanceM,
      avgPaceSecPerKm: avgPaceSecPerKm,
      maxSpeedMps: maxSpeedMps,
      status: kStateSaved,
      runName:
          existing?.runName ?? makeRunName(localStart, existing?.placeName),
      placeName: existing?.placeName,
      weatherTempC: existing?.weatherTempC,
      weatherWindKmh: existing?.weatherWindKmh,
      weatherCode: existing?.weatherCode,
      localStartDay: existing?.localStartDay ?? localDay(localStart),
    );

    // 4. Save to SQLite in a single transaction with a Batch for points and pauses
    final db = await _database.database;
    await db.transaction((txn) async {
      await txn.insert(
        AppDatabase.tableRuns,
        run.toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await txn.delete(
        AppDatabase.tableRunPoints,
        where: '${AppDatabase.colPointRunId} = ?',
        whereArgs: [runId],
      );

      await txn.delete(
        AppDatabase.tableRunPauses,
        where: '${AppDatabase.colPauseRunId} = ?',
        whereArgs: [runId],
      );

      final batch = txn.batch();
      for (final point in points) {
        batch.insert(AppDatabase.tableRunPoints, point.toDbMap(runId));
      }
      for (final pause in pauses) {
        batch.insert(AppDatabase.tableRunPauses, {
          AppDatabase.colPauseRunId: runId,
          AppDatabase.colPauseStartMs: pause.startMs,
          AppDatabase.colPauseEndMs: pause.endMs,
        });
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<List<Run>> list() async {
    final db = await _database.database;
    final List<Map<String, Object?>> rows = await db.query(
      AppDatabase.tableRuns,
      orderBy: '${AppDatabase.colStartedAtUtcMs} DESC',
    );
    return rows.map(Run.fromDbMap).toList();
  }

  @override
  Future<Run?> get(String runId) async {
    final db = await _database.database;
    final List<Map<String, Object?>> rows = await db.query(
      AppDatabase.tableRuns,
      where: '${AppDatabase.colRunId} = ?',
      whereArgs: [runId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Run.fromDbMap(rows.first);
  }

  @override
  Future<List<Point>> getPoints(String runId) async {
    final db = await _database.database;
    final List<Map<String, Object?>> rows = await db.query(
      AppDatabase.tableRunPoints,
      where: '${AppDatabase.colPointRunId} = ?',
      whereArgs: [runId],
      orderBy: '${AppDatabase.colPointSeq} ASC',
    );
    return rows.map(Point.fromDbMap).toList();
  }

  @override
  Future<List<PauseInterval>> getPauses(String runId) async {
    final db = await _database.database;
    final List<Map<String, Object?>> rows = await db.query(
      AppDatabase.tableRunPauses,
      where: '${AppDatabase.colPauseRunId} = ?',
      whereArgs: [runId],
      orderBy: '${AppDatabase.colPauseStartMs} ASC',
    );
    return rows.map((row) {
      return PauseInterval(
        startMs: (row[AppDatabase.colPauseStartMs] as num).toInt(),
        endMs: (row[AppDatabase.colPauseEndMs] as num).toInt(),
      );
    }).toList();
  }

  @override
  Future<void> delete(String runId) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      await txn.delete(
        AppDatabase.tableRunPoints,
        where: '${AppDatabase.colPointRunId} = ?',
        whereArgs: [runId],
      );
      await txn.delete(
        AppDatabase.tableRunPauses,
        where: '${AppDatabase.colPauseRunId} = ?',
        whereArgs: [runId],
      );
      await txn.delete(
        AppDatabase.tableRuns,
        where: '${AppDatabase.colRunId} = ?',
        whereArgs: [runId],
      );
    });
  }

  @override
  Future<void> updateDetails(
    String runId, {
    String? runName,
    String? placeName,
    double? temperatureC,
    double? windKmh,
    int? weatherCode,
    String? localStartDay,
  }) async {
    final values = <String, Object?>{};
    if (runName != null) values['run_name'] = runName;
    if (placeName != null) values['place_name'] = placeName;
    if (temperatureC != null) values['weather_temp_c'] = temperatureC;
    if (windKmh != null) values['weather_wind_kmh'] = windKmh;
    if (weatherCode != null) values['weather_code'] = weatherCode;
    if (localStartDay != null) values['local_start_day'] = localStartDay;

    if (values.isEmpty) return;

    final db = await _database.database;
    await db.update(
      AppDatabase.tableRuns,
      values,
      where: '${AppDatabase.colRunId} = ?',
      whereArgs: [runId],
    );
  }

  @override
  Future<String?> getUnfinishedRunPath() async {
    final String runsDirPath =
        runsDirectoryPath ?? '/data/user/0/com.roadrunner.app/files/runs';
    final runsDir = Directory(runsDirPath);
    if (!await runsDir.exists()) {
      return null;
    }

    final List<FileSystemEntity> entities = await runsDir.list().toList();
    final List<File> jsonlFiles = entities
        .whereType<File>()
        .where((f) => f.path.endsWith('.jsonl'))
        .toList();

    if (jsonlFiles.isEmpty) {
      return null;
    }

    // Sort by lastModified descending, then by file name descending (mirroring RunRecovery.kt)
    final fileStats = await Future.wait(
      jsonlFiles.map((f) async => MapEntry(f, await f.lastModified())),
    );
    fileStats.sort((a, b) {
      final cmp = b.value.compareTo(a.value);
      if (cmp != 0) return cmp;
      return b.key.path.compareTo(a.key.path);
    });

    final endLineRegex = RegExp(r'^\{"k":"end","t":[1-9][0-9]*\}$');

    for (final entry in fileStats) {
      final file = entry.key;
      final List<String> lines = await file.readAsLines();
      if (lines.isEmpty) continue;

      // 1. Verify header line
      final String header = lines.first.trim();
      final headerMatch = RegExp(
        r'^\{"v":1,"runId":"([^"]+)","startedAtUtcMs":(\d+)\}$',
      ).firstMatch(header);
      if (headerMatch == null) continue;

      final int? startedAt = int.tryParse(headerMatch.group(2) ?? '');
      if (startedAt == null || startedAt <= 0) continue;

      // 2. Find last non-empty line
      String? lastLine;
      for (int i = lines.length - 1; i >= 0; i--) {
        final line = lines[i].trim();
        if (line.isNotEmpty) {
          lastLine = line;
          break;
        }
      }

      if (lastLine == null) continue;

      // If the last line is NOT an end record, it is an unfinished run!
      if (!endLineRegex.hasMatch(lastLine)) {
        return file.path;
      }
    }

    return null;
  }
}

/// Builds a run name based on time of day and optional location name.
String makeRunName(DateTime localStart, String? placeName) {
  final hour = localStart.hour;
  final period = hour < 12
      ? 'Morning'
      : hour < 17
      ? 'Afternoon'
      : 'Evening';

  return placeName == null ? '$period run' : '$period run in $placeName';
}

/// Formats a local date as YYYY-MM-DD for daily streak calculations.
String localDay(DateTime localStart) =>
    '${localStart.year.toString().padLeft(4, '0')}-'
    '${localStart.month.toString().padLeft(2, '0')}-'
    '${localStart.day.toString().padLeft(2, '0')}';
