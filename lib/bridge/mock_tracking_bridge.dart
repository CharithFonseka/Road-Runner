// Road Runner — Mock TrackingBridge Implementation
// Owner: Aadila
// SRS reference: Section 4.5, 8.3

import 'dart:async';
import 'dart:math';

import 'package:road_runner/core/contract/contract.dart';

import 'tracking_bridge.dart';

/// Mock implementation of [TrackingBridge] that simulates a realistic 5-minute run
/// at approximately 10 km/h (~2.78 m/s, ~6:00 min/km pace) with GPS quality transitions
/// and pause/resume support for UI development.
class MockTrackingBridge implements TrackingBridge {
  final Duration tickDuration;
  final bool autoSimulatePause;

  final StreamController<TrackingEvent> _eventController =
      StreamController<TrackingEvent>.broadcast();

  Timer? _timer;
  String _state = kStateIdle;
  String? _currentRunId;
  String? _unfinishedRunId;
  String? _unfinishedFilePath;

  int _tickCount = 0;
  int _elapsedMs = 0;
  int _movingMs = 0;
  double _distanceM = 0.0;
  double _currentSpeedMps = 0.0;
  double? _paceSecPerKm;
  String _gpsQuality = kGpsSearching;
  int _pointSeq = -1;
  double? _lat;
  double? _lon;

  final Random _random = Random(42);

  MockTrackingBridge({
    this.tickDuration = const Duration(seconds: 1),
    this.autoSimulatePause = false,
  });

  @override
  Stream<TrackingEvent> get events => _eventController.stream;

  @override
  Future<String> startRun() async {
    _timer?.cancel();
    _currentRunId = 'mock-${DateTime.now().millisecondsSinceEpoch}';
    _state = kStateRunning;
    _tickCount = 0;
    _elapsedMs = 0;
    _movingMs = 0;
    _distanceM = 0.0;
    _currentSpeedMps = 0.0;
    _paceSecPerKm = null;
    _gpsQuality = kGpsSearching;
    _pointSeq = -1;
    _lat = null;
    _lon = null;

    _eventController.add(
      TrackingStateEvent(state: kStateRunning, runId: _currentRunId),
    );

    _eventController.add(TrackingGpsEvent(quality: _gpsQuality));

    _timer = Timer.periodic(tickDuration, _onTick);
    return _currentRunId!;
  }

  void _onTick(Timer timer) {
    if (_state == kStateStopped || _state == kStateIdle) {
      timer.cancel();
      return;
    }

    _tickCount++;
    _elapsedMs += 1000;

    // Simulate GPS acquisition stages
    if (_tickCount == 3 && _gpsQuality != kGpsWeak) {
      _gpsQuality = kGpsWeak;
      _eventController.add(TrackingGpsEvent(quality: _gpsQuality));
    } else if (_tickCount == 7 && _gpsQuality != kGpsGood) {
      _gpsQuality = kGpsGood;
      _eventController.add(TrackingGpsEvent(quality: _gpsQuality));
    }

    // Auto-simulation pause scenario (e.g. between 120s and 140s)
    if (autoSimulatePause) {
      if (_tickCount == 120 && _state == kStateRunning) {
        _state = kStatePaused;
        _eventController.add(
          TrackingStateEvent(state: kStatePaused, runId: _currentRunId),
        );
      } else if (_tickCount == 140 && _state == kStatePaused) {
        _state = kStateRunning;
        _eventController.add(
          TrackingStateEvent(state: kStateRunning, runId: _currentRunId),
        );
      }
    }

    if (_state == kStateRunning) {
      _movingMs += 1000;

      // Realistic variation around 10 km/h (2.778 m/s ± 0.15 m/s)
      final speedJitter = (_random.nextDouble() - 0.5) * 0.3;
      _currentSpeedMps = max(2.5, min(3.1, 2.78 + speedJitter));
      _distanceM += _currentSpeedMps * 1.0;
      if (_gpsQuality == kGpsGood) {
        _pointSeq++;
        _lat = -33.8688;
        _lon = 151.2093 + _distanceM / 93000;
        _eventController.add(
          TrackingPointEvent(
            point: TrackingPoint(seq: _pointSeq, lat: _lat!, lon: _lon!),
          ),
        );
      }

      if (_distanceM >= CalcConfig.minDistanceForPaceM && _movingMs > 0) {
        // pace = seconds per km
        _paceSecPerKm = (_movingMs / 1000.0) / (_distanceM / 1000.0);
      } else {
        _paceSecPerKm = null;
      }
    } else if (_state == kStatePaused) {
      _currentSpeedMps = 0.0;
      _paceSecPerKm = null;
    }

    final snapshot = TrackingSnapshot(
      elapsedMs: _elapsedMs,
      movingMs: _movingMs,
      distanceM: _distanceM,
      speedMps: _currentSpeedMps,
      paceSecPerKm: _paceSecPerKm,
      lat: _lat,
      lon: _lon,
      seq: _pointSeq < 0 ? null : _pointSeq,
    );

    _eventController.add(TrackingSnapshotEvent(snapshot: snapshot));

    // End after 5 minutes (300 seconds)
    if (_tickCount >= 300) {
      stopRun();
    }
  }

  @override
  Future<void> pauseRun() async {
    if (_state == kStateRunning) {
      _state = kStatePaused;
      _currentSpeedMps = 0.0;
      _eventController.add(
        TrackingStateEvent(state: kStatePaused, runId: _currentRunId),
      );
    }
  }

  @override
  Future<void> resumeRun() async {
    if (_state == kStatePaused) {
      _state = kStateRunning;
      _eventController.add(
        TrackingStateEvent(state: kStateRunning, runId: _currentRunId),
      );
    }
  }

  @override
  Future<RunResult> stopRun() async {
    _timer?.cancel();
    _timer = null;
    final runId = _currentRunId ?? 'mock-completed-run';
    final filePath = '/data/user/0/com.roadrunner.app/files/runs/$runId.jsonl';
    _state = kStateStopped;

    _eventController.add(
      TrackingStateEvent(state: kStateStopped, runId: runId),
    );

    return RunResult(runId: runId, filePath: filePath);
  }

  @override
  Future<TrackingStatus> getState() async {
    TrackingSnapshot? snapshot;
    if (_state == kStateRunning || _state == kStatePaused) {
      snapshot = TrackingSnapshot(
        elapsedMs: _elapsedMs,
        movingMs: _movingMs,
        distanceM: _distanceM,
        speedMps: _currentSpeedMps,
        paceSecPerKm: _paceSecPerKm,
        lat: _lat,
        lon: _lon,
        seq: _pointSeq < 0 ? null : _pointSeq,
      );
    }

    return TrackingStatus(
      state: _state,
      runId: _currentRunId,
      snapshot: snapshot,
    );
  }

  @override
  Future<RunResult?> getUnfinishedRun() async {
    if (_unfinishedRunId != null && _unfinishedFilePath != null) {
      return RunResult(
        runId: _unfinishedRunId!,
        filePath: _unfinishedFilePath!,
      );
    }
    return null;
  }

  /// Helper for testing crash recovery scenarios.
  void setUnfinishedRun(String runId, String filePath) {
    _unfinishedRunId = runId;
    _unfinishedFilePath = filePath;
  }

  @override
  Future<void> discardRun(String runId) async {
    if (_currentRunId == runId) {
      _timer?.cancel();
      _state = kStateIdle;
      _currentRunId = null;
    }
    if (_unfinishedRunId == runId) {
      _unfinishedRunId = null;
      _unfinishedFilePath = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _eventController.close();
  }
}
