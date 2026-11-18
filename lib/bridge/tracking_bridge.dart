// Road Runner — TrackingBridge Interface & Models (Dart side)
// Owner: Aadila
// SRS reference: Section 4.5, 8.3

import 'dart:async';

import 'package:road_runner/core/contract/contract.dart';

int _parseInt(dynamic value, [int defaultValue = 0]) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? defaultValue;
  return defaultValue;
}

double _parseDouble(dynamic value, [double defaultValue = 0.0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? defaultValue;
  return defaultValue;
}

double? _parseNullableDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

/// Periodic live metrics snapshot emitted while tracking a run.
class TrackingSnapshot {
  final int elapsedMs;
  final int movingMs;
  final double distanceM;
  final double speedMps;
  final double? paceSecPerKm;
  final double? lat;
  final double? lon;
  final int? seq;

  const TrackingSnapshot({
    required this.elapsedMs,
    required this.movingMs,
    required this.distanceM,
    required this.speedMps,
    this.paceSecPerKm,
    this.lat,
    this.lon,
    this.seq,
  });

  factory TrackingSnapshot.fromMap(Map<dynamic, dynamic> map) {
    return TrackingSnapshot(
      elapsedMs: _parseInt(map[kKeyElapsedMs]),
      movingMs: _parseInt(map[kKeyMovingMs]),
      distanceM: _parseDouble(map[kKeyDistanceM]),
      speedMps: _parseDouble(map[kKeySpeedMps]),
      paceSecPerKm: _parseNullableDouble(map[kKeyPaceSecPerKm]),
      lat: _parseNullableDouble(map[kKeyLat]),
      lon: _parseNullableDouble(map[kKeyLon]),
      seq: map[kKeySeq] == null ? null : _parseInt(map[kKeySeq]),
    );
  }

  Map<String, dynamic> toMap() => {
    kKeyElapsedMs: elapsedMs,
    kKeyMovingMs: movingMs,
    kKeyDistanceM: distanceM,
    kKeySpeedMps: speedMps,
    kKeyPaceSecPerKm: paceSecPerKm,
    kKeyLat: lat,
    kKeyLon: lon,
    kKeySeq: seq,
  };

  @override
  String toString() =>
      'TrackingSnapshot(elapsedMs: $elapsedMs, movingMs: $movingMs, distanceM: $distanceM, speedMps: $speedMps, paceSecPerKm: $paceSecPerKm)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackingSnapshot &&
          runtimeType == other.runtimeType &&
          elapsedMs == other.elapsedMs &&
          movingMs == other.movingMs &&
          distanceM == other.distanceM &&
          speedMps == other.speedMps &&
          paceSecPerKm == other.paceSecPerKm &&
          lat == other.lat &&
          lon == other.lon &&
          seq == other.seq;

  @override
  int get hashCode => Object.hash(
    elapsedMs,
    movingMs,
    distanceM,
    speedMps,
    paceSecPerKm,
    lat,
    lon,
    seq,
  );
}

/// One accepted GPS point. Sequence is the run-file sequence number.
class TrackingPoint {
  const TrackingPoint({
    required this.seq,
    required this.lat,
    required this.lon,
  });

  final int seq;
  final double lat;
  final double lon;

  static TrackingPoint? fromMap(Map<dynamic, dynamic> map) {
    final lat = _parseNullableDouble(map[kKeyLat]);
    final lon = _parseNullableDouble(map[kKeyLon]);
    final rawSeq = map[kKeySeq];
    final seq = rawSeq is int ? rawSeq : int.tryParse('$rawSeq');
    if (lat == null ||
        lon == null ||
        seq == null ||
        seq < 0 ||
        !lat.isFinite ||
        !lon.isFinite ||
        lat < -90 ||
        lat > 90 ||
        lon < -180 ||
        lon > 180) {
      return null;
    }
    return TrackingPoint(seq: seq, lat: lat, lon: lon);
  }
}

/// Current status of the native tracking service.
class TrackingStatus {
  final String state;
  final String? runId;
  final TrackingSnapshot? snapshot;
  final String? filePath;

  const TrackingStatus({
    required this.state,
    this.runId,
    this.snapshot,
    this.filePath,
  });

  factory TrackingStatus.fromMap(Map<dynamic, dynamic> map) {
    final rawSnapshot = map[kKeySnapshot];
    return TrackingStatus(
      state: map[kKeyState]?.toString() ?? kStateIdle,
      runId: map[kKeyRunId]?.toString(),
      snapshot: rawSnapshot is Map<dynamic, dynamic>
          ? TrackingSnapshot.fromMap(rawSnapshot)
          : null,
      filePath: map[kKeyFilePath]?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
    kKeyState: state,
    if (runId != null) kKeyRunId: runId,
    if (snapshot != null) kKeySnapshot: snapshot!.toMap(),
    if (filePath != null) kKeyFilePath: filePath,
  };

  @override
  String toString() =>
      'TrackingStatus(state: $state, runId: $runId, snapshot: $snapshot, filePath: $filePath)';
}

/// Result returned when a run completes or is retrieved from storage.
class RunResult {
  final String runId;
  final String filePath;

  const RunResult({required this.runId, required this.filePath});

  factory RunResult.fromMap(Map<dynamic, dynamic> map) {
    return RunResult(
      runId: map[kKeyRunId]?.toString() ?? '',
      filePath: map[kKeyFilePath]?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {kKeyRunId: runId, kKeyFilePath: filePath};

  @override
  String toString() => 'RunResult(runId: $runId, filePath: $filePath)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RunResult &&
          runtimeType == other.runtimeType &&
          runId == other.runId &&
          filePath == other.filePath;

  @override
  int get hashCode => Object.hash(runId, filePath);
}

/// Base sealed class for events pushed across the event channel (SRS §4.5).
sealed class TrackingEvent {
  const TrackingEvent();

  static TrackingEvent? fromMap(Map<dynamic, dynamic> map) {
    try {
      final type = map[kKeyType]?.toString();
      switch (type) {
        case kEventTypeState:
          final state = map[kKeyState]?.toString() ?? kStateIdle;
          final runId = map[kKeyRunId]?.toString();
          return TrackingStateEvent(state: state, runId: runId);

        case kEventTypeGps:
          final quality = map[kKeyQuality]?.toString() ?? kGpsSearching;
          return TrackingGpsEvent(quality: quality);

        case kEventTypeSnapshot:
          return TrackingSnapshotEvent(snapshot: TrackingSnapshot.fromMap(map));

        case kEventTypePoint:
          final point = TrackingPoint.fromMap(map);
          return point == null ? null : TrackingPointEvent(point: point);

        case kEventTypeError:
          final code = map[kKeyCode]?.toString() ?? kErrorServiceFailed;
          final message = map[kKeyMessage]?.toString() ?? '';
          return TrackingErrorEvent(code: code, message: message);

        default:
          // Ignore unknown/malformed events gracefully (SRS §8.3 Check 6)
          return null;
      }
    } catch (_) {
      return null;
    }
  }
}

/// State transition event (SRS §4.5).
class TrackingStateEvent extends TrackingEvent {
  final String state;
  final String? runId;

  const TrackingStateEvent({required this.state, this.runId});

  @override
  String toString() => 'TrackingStateEvent(state: $state, runId: $runId)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackingStateEvent &&
          runtimeType == other.runtimeType &&
          state == other.state &&
          runId == other.runId;

  @override
  int get hashCode => Object.hash(state, runId);
}

/// GPS signal quality update event (SRS §4.5).
class TrackingGpsEvent extends TrackingEvent {
  final String quality;

  const TrackingGpsEvent({required this.quality});

  @override
  String toString() => 'TrackingGpsEvent(quality: $quality)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackingGpsEvent &&
          runtimeType == other.runtimeType &&
          quality == other.quality;

  @override
  int get hashCode => quality.hashCode;
}

/// Periodic snapshot update event emitted once per second while running (SRS §4.5).
class TrackingSnapshotEvent extends TrackingEvent {
  final TrackingSnapshot snapshot;

  const TrackingSnapshotEvent({required this.snapshot});

  @override
  String toString() => 'TrackingSnapshotEvent(snapshot: $snapshot)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackingSnapshotEvent &&
          runtimeType == other.runtimeType &&
          snapshot == other.snapshot;

  @override
  int get hashCode => snapshot.hashCode;
}

class TrackingPointEvent extends TrackingEvent {
  const TrackingPointEvent({required this.point});

  final TrackingPoint point;
}

/// Error event from native service (SRS §4.5).
class TrackingErrorEvent extends TrackingEvent {
  final String code;
  final String message;

  const TrackingErrorEvent({required this.code, required this.message});

  @override
  String toString() => 'TrackingErrorEvent(code: $code, message: $message)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackingErrorEvent &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          message == other.message;

  @override
  int get hashCode => Object.hash(code, message);
}

/// Contract for the Dart-side bridge between Flutter and the native tracking service.
/// All Flutter screens and view models communicate exclusively with this interface.
abstract class TrackingBridge {
  /// Stream of events pushed from the native service (states, gps quality, snapshots, errors).
  Stream<TrackingEvent> get events;

  /// Start a new tracking session. Returns the unique [runId].
  Future<String> startRun();

  /// Pause the active run.
  Future<void> pauseRun();

  /// Resume a paused run.
  Future<void> resumeRun();

  /// Stop the active run. Returns the [RunResult] with [runId] and [filePath].
  Future<RunResult> stopRun();

  /// Get current native service state, run ID, and latest snapshot (for app launch resync, FR-23).
  Future<TrackingStatus> getState();

  /// Check if an unfinished run file exists after a crash/restart.
  Future<RunResult?> getUnfinishedRun();

  /// Discard an unfinished or aborted run.
  Future<void> discardRun(String runId);

  /// Clean up listeners or background timers.
  void dispose();
}
