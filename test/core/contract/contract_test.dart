// Road Runner — Unit tests for the Core Contract (SRS §4.2 – §4.7).
// Owner: Praveen

import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/core/contract/contract.dart';

void main() {
  group('Core Contract — Channels & Methods (SRS §4.5)', () {
    test('channel names match SRS §4.5', () {
      expect(kControlChannel, 'roadrunner/control');
      expect(kEventsChannel, 'roadrunner/events');
    });

    test('control method names match SRS §4.5', () {
      expect(kMethodStartRun, 'startRun');
      expect(kMethodPauseRun, 'pauseRun');
      expect(kMethodResumeRun, 'resumeRun');
      expect(kMethodStopRun, 'stopRun');
      expect(kMethodGetState, 'getState');
      expect(kMethodGetUnfinishedRun, 'getUnfinishedRun');
      expect(kMethodDiscardRun, 'discardRun');
    });
  });

  group('Core Contract — States, Events, GPS & Errors (SRS §4.2, §4.5)', () {
    test('run states match SRS §4.2 & §4.3', () {
      expect(kStateIdle, 'idle');
      expect(kStateRunning, 'running');
      expect(kStatePaused, 'paused');
      expect(kStateStopped, 'stopped');
      expect(kStateSaved, 'saved');
    });

    test('event types match SRS §4.5', () {
      expect(kEventTypeState, 'state');
      expect(kEventTypeGps, 'gps');
      expect(kEventTypeSnapshot, 'snapshot');
      expect(kEventTypeError, 'error');
    });

    test('GPS quality values match SRS §4.5', () {
      expect(kGpsSearching, 'searching');
      expect(kGpsWeak, 'weak');
      expect(kGpsGood, 'good');
    });

    test('error codes match SRS §4.5', () {
      expect(kErrorLocationOff, 'LOCATION_OFF');
      expect(kErrorPermissionDenied, 'PERMISSION_DENIED');
      expect(kErrorServiceFailed, 'SERVICE_FAILED');
    });
  });

  group('Core Contract — Run File v1 & Filter/Calc Config (SRS §4.4, §4.6, §4.7)', () {
    test('run file format constants match SRS §4.4', () {
      expect(kRunFileVersion, 1);
      expect(kRunFileKindPoint, 'p');
      expect(kRunFileKindState, 's');
      expect(kRunFileKindEnd, 'end');
    });

    test('FilterConfig thresholds match SRS §4.6', () {
      expect(FilterConfig.maxAccuracyM, 25.0);
      expect(FilterConfig.firstFixMaxAccuracyM, 20.0);
      expect(FilterConfig.maxImpliedSpeedMps, 12.0);
      expect(FilterConfig.stationarySpeedMps, 0.5);
      expect(FilterConfig.tinyMoveM, 2.0);
      expect(FilterConfig.maxGapSeconds, 10);
      expect(FilterConfig.earthRadiusM, 6371000.0);
    });

    test('CalcConfig thresholds match SRS §4.7', () {
      expect(CalcConfig.minDistanceForPaceM, 50.0);
      expect(CalcConfig.minSpeedForPaceMps, 0.5);
      expect(CalcConfig.maxPaceSecPerKm, 1200.0);
      expect(CalcConfig.splitDistanceM, 1000.0);
      expect(CalcConfig.speedSmoothingWindowS, 5);
    });
  });
}
