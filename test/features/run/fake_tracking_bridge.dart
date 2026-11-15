// Road Runner — controllable TrackingBridge for Run feature tests.
// Owner: Tharushi
//
// Test-only. Every call can be made to succeed, fail or wait, and every
// call is counted, so tests can check exactly what the screen asked for.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:road_runner/bridge/tracking_bridge.dart';
import 'package:road_runner/core/contract/contract.dart';

class FakeTrackingBridge implements TrackingBridge {
  final StreamController<TrackingEvent> _events =
      StreamController<TrackingEvent>.broadcast(sync: true);

  // ─── Behaviour switches ───────────────────────────────────────────────────

  TrackingStatus initialStatus = const TrackingStatus(state: kStateIdle);
  TrackingStatus statusAfterStop = const TrackingStatus(state: kStateStopped);

  String startRunId = 'test-run';
  Object? startError;
  Object? pauseError;
  Object? resumeError;
  Object? stopError;
  RunResult stopResult = const RunResult(
    runId: 'test-run',
    filePath: '/test/runs/test-run.jsonl',
  );

  /// When set, the matching call waits for the completer.
  Completer<void>? startGate;
  Completer<void>? pauseGate;
  Completer<void>? stopGate;

  // ─── Call counters ────────────────────────────────────────────────────────

  int getStateCalls = 0;
  int startCalls = 0;
  int pauseCalls = 0;
  int resumeCalls = 0;
  int stopCalls = 0;
  int disposeCalls = 0;

  bool get hasListener => _events.hasListener;

  bool _stopped = false;

  // ─── Event helpers ────────────────────────────────────────────────────────

  void emit(TrackingEvent event) => _events.add(event);

  void emitSnapshot({
    int elapsedMs = 0,
    int movingMs = 0,
    double distanceM = 0,
    double speedMps = 0,
    double? paceSecPerKm,
  }) {
    emit(
      TrackingSnapshotEvent(
        snapshot: TrackingSnapshot(
          elapsedMs: elapsedMs,
          movingMs: movingMs,
          distanceM: distanceM,
          speedMps: speedMps,
          paceSecPerKm: paceSecPerKm,
        ),
      ),
    );
  }

  void emitGps(String quality) => emit(TrackingGpsEvent(quality: quality));

  void emitState(String state, {String? runId}) =>
      emit(TrackingStateEvent(state: state, runId: runId));

  /// Simulates "Stop" pressed in the notification.
  void stopFromNotification() {
    _stopped = true;
    emitState(kStateStopped, runId: startRunId);
  }

  // ─── TrackingBridge ───────────────────────────────────────────────────────

  @override
  Stream<TrackingEvent> get events => _events.stream;

  @override
  Future<TrackingStatus> getState() async {
    getStateCalls++;
    return _stopped ? statusAfterStop : initialStatus;
  }

  @override
  Future<String> startRun() async {
    startCalls++;
    await startGate?.future;
    final Object? error = startError;
    if (error != null) throw error;
    emitState(kStateRunning, runId: startRunId);
    return startRunId;
  }

  @override
  Future<void> pauseRun() async {
    pauseCalls++;
    await pauseGate?.future;
    final Object? error = pauseError;
    if (error != null) throw error;
    emitState(kStatePaused, runId: startRunId);
  }

  @override
  Future<void> resumeRun() async {
    resumeCalls++;
    final Object? error = resumeError;
    if (error != null) throw error;
    emitState(kStateRunning, runId: startRunId);
  }

  @override
  Future<RunResult> stopRun() async {
    stopCalls++;
    await stopGate?.future;
    final Object? error = stopError;
    if (error != null) throw error;
    _stopped = true;
    emitState(kStateStopped, runId: stopResult.runId);
    return stopResult;
  }

  @override
  Future<RunResult?> getUnfinishedRun() async => null;

  @override
  Future<void> discardRun(String runId) async {}

  @override
  void dispose() {
    disposeCalls++;
  }

  Future<void> close() => _events.close();
}

PlatformException platformError(String code) =>
    PlatformException(code: code, message: 'test');
