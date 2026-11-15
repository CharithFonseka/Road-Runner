// Road Runner — ActiveRunController tests.
// Owner: Tharushi

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/bridge/tracking_bridge.dart';
import 'package:road_runner/core/contract/contract.dart';
import 'package:road_runner/features/run/active_run_controller.dart';

import 'fake_tracking_bridge.dart';

void main() {
  late FakeTrackingBridge bridge;
  late List<RunResult> results;
  late ActiveRunController controller;

  setUp(() {
    bridge = FakeTrackingBridge();
    results = [];
    controller = ActiveRunController(
      bridge: bridge,
      onRunFinished: results.add,
    );
  });

  tearDown(() {
    if (!controller.isDisposed) controller.dispose();
    bridge.close();
  });

  test('starts in the starting phase with no snapshot', () {
    expect(controller.state.phase, RunPhase.starting);
    expect(controller.state.snapshot, isNull);
    expect(controller.state.gpsQuality, isNull);
  });

  group('start', () {
    test('subscribes, starts a run and becomes running', () async {
      await controller.start();
      expect(bridge.hasListener, isTrue);
      expect(bridge.startCalls, 1);
      expect(controller.state.phase, RunPhase.running);
      expect(controller.state.runId, 'test-run');
      expect(controller.state.busy, isFalse);
    });

    test('adopts a run that is already paused instead of starting', () async {
      const TrackingSnapshot snap = TrackingSnapshot(
        elapsedMs: 90000,
        movingMs: 80000,
        distanceM: 300,
        speedMps: 0,
      );
      bridge.initialStatus = const TrackingStatus(
        state: kStatePaused,
        runId: 'existing',
        snapshot: snap,
      );
      await controller.start();
      expect(bridge.startCalls, 0);
      expect(controller.state.phase, RunPhase.paused);
      expect(controller.state.runId, 'existing');
      expect(controller.state.snapshot, same(snap));
    });

    test('failure maps the error code and allows Try Again', () async {
      bridge.startError = platformError(kErrorLocationOff);
      await controller.start();
      expect(controller.state.phase, RunPhase.startFailed);
      expect(controller.state.issue?.kind, RunIssueKind.locationOff);

      bridge.startError = null;
      await controller.start();
      expect(bridge.startCalls, 2);
      expect(controller.state.phase, RunPhase.running);
      expect(controller.state.issue, isNull);
    });

    test('permission and unknown errors are mapped', () async {
      bridge.startError = platformError(kErrorPermissionDenied);
      await controller.start();
      expect(controller.state.issue?.kind, RunIssueKind.permissionDenied);

      bridge.startError = StateError('boom');
      await controller.start();
      expect(controller.state.issue?.kind, RunIssueKind.serviceFailed);
    });

    test('duplicate start calls start only once', () async {
      bridge.startGate = Completer<void>();
      final Future<void> first = controller.start();
      final Future<void> second = controller.start();
      bridge.startGate!.complete();
      await Future.wait([first, second]);
      expect(bridge.startCalls, 1);
    });
  });

  group('events', () {
    setUp(() => controller.start());

    test('snapshots replace the displayed values', () async {
      await pumpEventQueue();
      bridge.emitSnapshot(elapsedMs: 1000, distanceM: 10);
      expect(controller.state.snapshot?.elapsedMs, 1000);
      bridge.emitSnapshot(elapsedMs: 2000, distanceM: 20, paceSecPerKm: 300);
      expect(controller.state.snapshot?.distanceM, 20);
      expect(controller.state.snapshot?.paceSecPerKm, 300);
    });

    test('GPS quality follows the bridge', () async {
      await pumpEventQueue();
      for (final String q in [kGpsSearching, kGpsWeak, kGpsGood]) {
        bridge.emitGps(q);
        expect(controller.state.gpsQuality, q);
      }
    });

    test('error events show a message without changing the phase', () async {
      await pumpEventQueue();
      bridge.emit(
        const TrackingErrorEvent(code: kErrorLocationOff, message: 'off'),
      );
      expect(controller.state.phase, RunPhase.running);
      expect(controller.state.issue?.kind, RunIssueKind.locationOff);
      controller.clearIssue();
      expect(controller.state.issue, isNull);
    });
  });

  group('pause and resume', () {
    setUp(() => controller.start());

    test('pause then resume follow bridge confirmation', () async {
      await pumpEventQueue();
      await controller.pause();
      expect(controller.state.phase, RunPhase.paused);
      await controller.resume();
      expect(controller.state.phase, RunPhase.running);
      expect((bridge.pauseCalls, bridge.resumeCalls), (1, 1));
    });

    test('paused keeps the latest snapshot as reported', () async {
      await pumpEventQueue();
      bridge.emitSnapshot(elapsedMs: 5000, distanceM: 800, speedMps: 3);
      await controller.pause();
      final TrackingSnapshot? kept = controller.state.snapshot;
      expect(kept?.distanceM, 800);
      expect(kept?.speedMps, 3);
    });

    test('phase is not paused until the bridge confirms', () async {
      await pumpEventQueue();
      bridge.pauseGate = Completer<void>();
      final Future<void> pending = controller.pause();
      expect(controller.state.phase, RunPhase.running);
      expect(controller.state.busy, isTrue);
      // Duplicate tap while busy is ignored.
      await controller.pause();
      expect(bridge.pauseCalls, 1);
      bridge.pauseGate!.complete();
      await pending;
      expect(controller.state.phase, RunPhase.paused);
    });

    test('pause failure keeps running and reports it', () async {
      await pumpEventQueue();
      bridge.pauseError = platformError(kErrorServiceFailed);
      await controller.pause();
      expect(controller.state.phase, RunPhase.running);
      expect(controller.state.issue?.kind, RunIssueKind.pauseFailed);
    });

    test('resume failure stays paused and reports it', () async {
      await pumpEventQueue();
      await controller.pause();
      bridge.resumeError = platformError(kErrorServiceFailed);
      await controller.resume();
      expect(controller.state.phase, RunPhase.paused);
      expect(controller.state.issue?.kind, RunIssueKind.resumeFailed);
    });
  });

  group('finish', () {
    setUp(() => controller.start());

    test('delivers the real RunResult exactly once', () async {
      await pumpEventQueue();
      await controller.finish();
      await controller.finish();
      expect(bridge.stopCalls, 1);
      expect(controller.state.phase, RunPhase.finished);
      expect(results, [same(bridge.stopResult)]);
    });

    test('failure restores the previous phase and allows retry', () async {
      await pumpEventQueue();
      await controller.pause();
      bridge.stopError = platformError(kErrorServiceFailed);
      await controller.finish();
      expect(controller.state.phase, RunPhase.paused);
      expect(controller.state.issue?.kind, RunIssueKind.stopFailed);
      expect(results, isEmpty);

      bridge.stopError = null;
      await controller.finish();
      expect(controller.state.phase, RunPhase.finished);
      expect(results, hasLength(1));
    });

    test('result still reaches the parent if disposed mid-stop', () async {
      await pumpEventQueue();
      bridge.stopGate = Completer<void>();
      final Future<void> pending = controller.finish();
      controller.dispose();
      bridge.stopGate!.complete();
      await pending;
      expect(results, hasLength(1));
    });
  });

  group('stop from outside the screen', () {
    setUp(() => controller.start());

    test('without a file path, ends unresolved and invents nothing', () async {
      await pumpEventQueue();
      bridge.stopFromNotification();
      await pumpEventQueue();
      expect(controller.state.phase, RunPhase.stoppedUnresolved);
      expect(results, isEmpty);
      expect(bridge.stopCalls, 0);
    });

    test('with runId and filePath from getState, passes them on', () async {
      await pumpEventQueue();
      bridge.statusAfterStop = const TrackingStatus(
        state: kStateStopped,
        runId: 'test-run',
        filePath: '/bridge/runs/test-run.jsonl',
      );
      bridge.stopFromNotification();
      await pumpEventQueue();
      expect(controller.state.phase, RunPhase.finished);
      expect(results.single.filePath, '/bridge/runs/test-run.jsonl');
    });
  });

  test('dispose cancels the subscription but never the bridge', () async {
    await controller.start();
    controller.dispose();
    expect(bridge.hasListener, isFalse);
    expect(bridge.disposeCalls, 0);
    expect(bridge.stopCalls, 0);
    // Late events are ignored safely.
    bridge.emitSnapshot(elapsedMs: 1);
  });
}
