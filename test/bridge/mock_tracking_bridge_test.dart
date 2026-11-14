// Road Runner — Unit Tests for MockTrackingBridge
// Owner: Aadila
// SRS reference: Section 4.5, 8.3

import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/bridge/mock_tracking_bridge.dart';
import 'package:road_runner/bridge/tracking_bridge.dart';
import 'package:road_runner/core/contract/contract.dart';

void main() {
  group('MockTrackingBridge Tests (SRS §8.3)', () {
    late MockTrackingBridge bridge;

    setUp(() {
      bridge = MockTrackingBridge(
        tickDuration: const Duration(milliseconds: 10),
      );
    });

    tearDown(() {
      bridge.dispose();
    });

    test('startRun transitions to running and emits state & GPS events', () async {
      final events = <TrackingEvent>[];
      final subscription = bridge.events.listen(events.add);

      final runId = await bridge.startRun();
      expect(runId, isNotEmpty);
      expect(runId, startsWith('mock-'));

      final status = await bridge.getState();
      expect(status.state, kStateRunning);
      expect(status.runId, runId);

      // Wait a couple ticks
      await Future<void>.delayed(const Duration(milliseconds: 35));

      expect(events, isNotEmpty);
      expect(events[0], isA<TrackingStateEvent>());
      final stateEvent = events[0] as TrackingStateEvent;
      expect(stateEvent.state, kStateRunning);
      expect(stateEvent.runId, runId);

      expect(events[1], isA<TrackingGpsEvent>());
      final gpsEvent = events[1] as TrackingGpsEvent;
      expect(gpsEvent.quality, kGpsSearching);

      await subscription.cancel();
    });

    test('emits snapshots with moving distance and speed around 10 km/h (~2.78 m/s)', () async {
      final snapshots = <TrackingSnapshot>[];
      final subscription = bridge.events.listen((event) {
        if (event is TrackingSnapshotEvent) {
          snapshots.add(event.snapshot);
        }
      });

      await bridge.startRun();
      await Future<void>.delayed(const Duration(milliseconds: 45));

      expect(snapshots, isNotEmpty);
      final first = snapshots.first;
      expect(first.elapsedMs, greaterThanOrEqualTo(1000));
      expect(first.movingMs, greaterThanOrEqualTo(1000));
      expect(first.distanceM, greaterThan(0.0));
      expect(first.speedMps, inInclusiveRange(2.4, 3.2));

      await subscription.cancel();
    });

    test('pauseRun stops moving time accumulation and sets speed to zero', () async {
      final snapshots = <TrackingSnapshot>[];
      final states = <String>[];

      final subscription = bridge.events.listen((event) {
        if (event is TrackingStateEvent) {
          states.add(event.state);
        } else if (event is TrackingSnapshotEvent) {
          snapshots.add(event.snapshot);
        }
      });

      await bridge.startRun();
      await Future<void>.delayed(const Duration(milliseconds: 25));

      await bridge.pauseRun();
      expect(states, contains(kStatePaused));

      final status = await bridge.getState();
      expect(status.state, kStatePaused);

      await Future<void>.delayed(const Duration(milliseconds: 35));
      expect(snapshots.last.speedMps, 0.0);

      await bridge.resumeRun();
      expect(states, contains(kStateRunning));

      await subscription.cancel();
    });

    test('stopRun transitions to stopped and returns RunResult', () async {
      final runId = await bridge.startRun();
      final result = await bridge.stopRun();

      expect(result.runId, runId);
      expect(result.filePath, contains(runId));

      final status = await bridge.getState();
      expect(status.state, kStateStopped);
    });

    test('getUnfinishedRun and discardRun work properly', () async {
      expect(await bridge.getUnfinishedRun(), isNull);

      bridge.setUnfinishedRun('recovery-run-123', '/data/recovery.jsonl');
      final unfinished = await bridge.getUnfinishedRun();
      expect(unfinished, isNotNull);
      expect(unfinished!.runId, 'recovery-run-123');

      await bridge.discardRun('recovery-run-123');
      expect(await bridge.getUnfinishedRun(), isNull);
    });
  });
}
