// Road Runner — Unit Tests for NativeTrackingBridge
// Owner: Aadila
// SRS reference: Section 4.5, 8.3

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/bridge/native_tracking_bridge.dart';
import 'package:road_runner/bridge/tracking_bridge.dart';
import 'package:road_runner/core/contract/contract.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NativeTrackingBridge MethodChannel Tests (SRS §4.5)', () {
    late NativeTrackingBridge bridge;
    final log = <MethodCall>[];

    setUp(() {
      log.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel(kControlChannel),
        (MethodCall methodCall) async {
          log.add(methodCall);
          switch (methodCall.method) {
            case kMethodStartRun:
              return {kKeyRunId: 'test-run-123'};
            case kMethodPauseRun:
            case kMethodResumeRun:
            case kMethodDiscardRun:
              return null;
            case kMethodStopRun:
              return {
                kKeyRunId: 'test-run-123',
                kKeyFilePath: '/data/runs/test-run-123.jsonl',
              };
            case kMethodGetState:
              return {
                kKeyState: kStateRunning,
                kKeyRunId: 'test-run-123',
                kKeySnapshot: {
                  kKeyElapsedMs: 5000,
                  kKeyMovingMs: 4000,
                  kKeyDistanceM: 12.5,
                  kKeySpeedMps: 2.8,
                  kKeyPaceSecPerKm: 357.1,
                },
              };
            case kMethodGetUnfinishedRun:
              return {
                kKeyRunId: 'unfinished-1',
                kKeyFilePath: '/data/runs/unfinished-1.jsonl',
              };
            default:
              return null;
          }
        },
      );

      bridge = NativeTrackingBridge();
    });

    tearDown(() {
      bridge.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel(kControlChannel), null);
    });

    test('startRun calls kMethodStartRun and returns runId', () async {
      final runId = await bridge.startRun();
      expect(runId, 'test-run-123');
      expect(log, hasLength(1));
      expect(log.first.method, kMethodStartRun);
    });

    test('pauseRun calls kMethodPauseRun', () async {
      await bridge.pauseRun();
      expect(log.any((call) => call.method == kMethodPauseRun), isTrue);
    });

    test('resumeRun calls kMethodResumeRun', () async {
      await bridge.resumeRun();
      expect(log.any((call) => call.method == kMethodResumeRun), isTrue);
    });

    test('stopRun calls kMethodStopRun and returns RunResult', () async {
      final result = await bridge.stopRun();
      expect(result.runId, 'test-run-123');
      expect(result.filePath, '/data/runs/test-run-123.jsonl');
      expect(log.any((call) => call.method == kMethodStopRun), isTrue);
    });

    test('getState calls kMethodGetState and parses snapshot', () async {
      final status = await bridge.getState();
      expect(status.state, kStateRunning);
      expect(status.runId, 'test-run-123');
      expect(status.snapshot, isNotNull);
      expect(status.snapshot!.elapsedMs, 5000);
      expect(status.snapshot!.distanceM, 12.5);
      expect(status.snapshot!.speedMps, 2.8);
      expect(status.snapshot!.paceSecPerKm, 357.1);
    });

    test('getUnfinishedRun and discardRun call proper methods', () async {
      final unfinished = await bridge.getUnfinishedRun();
      expect(unfinished, isNotNull);
      expect(unfinished!.runId, 'unfinished-1');

      await bridge.discardRun('unfinished-1');
      expect(
        log.any((call) =>
            call.method == kMethodDiscardRun &&
            (call.arguments as Map)[kKeyRunId] == 'unfinished-1'),
        isTrue,
      );
    });
  });

  group('TrackingEvent Parsing & Malformed Protection (SRS §8.3 Check 6)', () {
    test('TrackingEvent.fromMap parses valid state event', () {
      final event = TrackingEvent.fromMap({
        kKeyType: kEventTypeState,
        kKeyState: kStatePaused,
        kKeyRunId: 'abc',
      });
      expect(event, isA<TrackingStateEvent>());
      final stateEvent = event as TrackingStateEvent;
      expect(stateEvent.state, kStatePaused);
      expect(stateEvent.runId, 'abc');
    });

    test('TrackingEvent.fromMap parses valid gps event', () {
      final event = TrackingEvent.fromMap({
        kKeyType: kEventTypeGps,
        kKeyQuality: kGpsGood,
      });
      expect(event, isA<TrackingGpsEvent>());
      final gpsEvent = event as TrackingGpsEvent;
      expect(gpsEvent.quality, kGpsGood);
    });

    test('TrackingEvent.fromMap parses valid snapshot event', () {
      final event = TrackingEvent.fromMap({
        kKeyType: kEventTypeSnapshot,
        kKeyElapsedMs: 1000,
        kKeyMovingMs: 1000,
        kKeyDistanceM: 2.7,
        kKeySpeedMps: 2.7,
        kKeyPaceSecPerKm: 370.0,
      });
      expect(event, isA<TrackingSnapshotEvent>());
      final snapshotEvent = event as TrackingSnapshotEvent;
      expect(snapshotEvent.snapshot.distanceM, 2.7);
      expect(snapshotEvent.snapshot.paceSecPerKm, 370.0);
    });

    test('TrackingEvent.fromMap parses error event and maps correctly', () {
      final event = TrackingEvent.fromMap({
        kKeyType: kEventTypeError,
        kKeyCode: kErrorPermissionDenied,
        kKeyMessage: 'GPS permission denied',
      });
      expect(event, isA<TrackingErrorEvent>());
      final errEvent = event as TrackingErrorEvent;
      expect(errEvent.code, kErrorPermissionDenied);
      expect(errEvent.message, 'GPS permission denied');
    });

    test('TrackingEvent.fromMap handles malformed payloads gracefully without crashing', () {
      expect(TrackingEvent.fromMap({}), isNull);
      expect(TrackingEvent.fromMap({'weird_unknown_key': 123}), isNull);
      expect(TrackingEvent.fromMap({'type': 'alien_event_type'}), isNull);

      // Snapshot with missing or corrupted types falls back safely
      final malformedSnapshot = TrackingEvent.fromMap({
        'type': 'snapshot',
        'elapsedMs': 'invalid_string',
        'distanceM': null,
      });
      expect(malformedSnapshot, isA<TrackingSnapshotEvent>());
      final parsed = malformedSnapshot as TrackingSnapshotEvent;
      expect(parsed.snapshot.elapsedMs, 0);
      expect(parsed.snapshot.distanceM, 0.0);
    });
  });
}
