// Road Runner — Core Contract (Dart side)
// Owner: Praveen
// SRS reference: Section 4.3 – 4.7
//
// DO NOT EDIT without opening a CCR (SRS §4.8).
// Every constant here must have an identical mirror in
// android/app/src/main/kotlin/com/roadrunner/app/bridge/Contract.kt.
// CI runs `bash scripts/check_contract.sh` to compare both files.

// ─── Channels (SRS §4.5) ──────────────────────────────────────────────────────

/// Channel used by Flutter to send commands to the native tracking service.
const String kControlChannel = 'roadrunner/control';

/// Channel used by the native tracking service to push events to Flutter.
const String kEventsChannel = 'roadrunner/events';

// ─── MethodChannel method names (SRS §4.5) ────────────────────────────────────

const String kMethodStartRun = 'startRun';
const String kMethodPauseRun = 'pauseRun';
const String kMethodResumeRun = 'resumeRun';
const String kMethodStopRun = 'stopRun';
const String kMethodGetState = 'getState';
const String kMethodGetUnfinishedRun = 'getUnfinishedRun';
const String kMethodDiscardRun = 'discardRun';

/// Bridge payload version for live position and route point support.
const int kBridgeContractVersion = 2;

// ─── Run states (SRS §4.2, §4.3, §4.5) ────────────────────────────────────────

const String kStateIdle = 'idle';
const String kStateRunning = 'running';
const String kStatePaused = 'paused';
const String kStateStopped = 'stopped';
const String kStateSaved = 'saved';

// ─── EventChannel event types (SRS §4.5) ──────────────────────────────────────

const String kEventTypeState = 'state';
const String kEventTypeGps = 'gps';
const String kEventTypeSnapshot = 'snapshot';
const String kEventTypePoint = 'point';
const String kEventTypeError = 'error';

// ─── GPS quality values (SRS §4.5) ────────────────────────────────────────────

const String kGpsSearching = 'searching';
const String kGpsWeak = 'weak';
const String kGpsGood = 'good';

// ─── Error codes (SRS §4.5) ───────────────────────────────────────────────────

const String kErrorLocationOff = 'LOCATION_OFF';
const String kErrorPermissionDenied = 'PERMISSION_DENIED';
const String kErrorServiceFailed = 'SERVICE_FAILED';

// ─── Bridge payload field keys (SRS §4.5) ─────────────────────────────────────

const String kKeyType = 'type';
const String kKeyState = 'state';
const String kKeyRunId = 'runId';
const String kKeyFilePath = 'filePath';
const String kKeySnapshot = 'snapshot';
const String kKeyQuality = 'quality';
const String kKeyElapsedMs = 'elapsedMs';
const String kKeyMovingMs = 'movingMs';
const String kKeyDistanceM = 'distanceM';
const String kKeySpeedMps = 'speedMps';
const String kKeyPaceSecPerKm = 'paceSecPerKm';
const String kKeyLat = 'lat';
const String kKeyLon = 'lon';
const String kKeySeq = 'seq';
const String kKeyCode = 'code';
const String kKeyMessage = 'message';

// ─── Run file format v1 (SRS §4.4) ────────────────────────────────────────────

/// Version tag written as the first line of every run file.
const int kRunFileVersion = 1;

/// Record kind: GPS point.
const String kRunFileKindPoint = 'p';

/// Record kind: state change (paused / running).
const String kRunFileKindState = 's';

/// Record kind: end-of-run marker.
const String kRunFileKindEnd = 'end';

/// Run file JSON keys (SRS §4.4).
const String kRunFileKeyVersion = 'v';
const String kRunFileKeyKind = 'k';
const String kRunFileKeyStartedAtUtcMs = 'startedAtUtcMs';
const String kRunFileKeySeq = 'seq';
const String kRunFileKeyTime = 't';
const String kRunFileKeyLat = 'lat';
const String kRunFileKeyLon = 'lon';
const String kRunFileKeyAcc = 'acc';
const String kRunFileKeySpeed = 'spd';
const String kRunFileKeyAlt = 'alt';
const String kRunFileKeyAccepted = 'ok';

// ─── GPS filter config (SRS §4.6) ─────────────────────────────────────────────

/// GPS filter configuration values (SRS §4.6).
/// Values change only by CCR (Rule C7).
class FilterConfig {
  FilterConfig._();

  /// Reject fixes with horizontal accuracy worse than this (meters).
  static const double maxAccuracyM = 25.0;

  /// The very first fix of a run must be better than this (meters).
  static const double firstFixMaxAccuracyM = 20.0;

  /// Reject a point whose implied speed vs the previous fix exceeds this (m/s).
  static const double maxImpliedSpeedMps = 12.0;

  /// Below this speed (m/s), a move smaller than [tinyMoveM] is ignored.
  static const double stationarySpeedMps = 0.5;

  /// Minimum move distance (m) when [stationarySpeedMps] is not exceeded.
  static const double tinyMoveM = 2.0;

  /// Gap threshold (seconds) noted in SRS §4.6.
  static const int maxGapSeconds = 10;

  /// Earth radius used for haversine distance (meters).
  static const double earthRadiusM = 6371000.0;
}

// ─── Calculation constants (SRS §4.7) ─────────────────────────────────────────

/// Calculation and display threshold constants (SRS §4.7).
class CalcConfig {
  CalcConfig._();

  /// Minimum distance (m) for average pace; below this, display '--:--'.
  static const double minDistanceForPaceM = 50.0;

  /// Minimum speed (m/s) to show current pace; below this, display '--:--'.
  static const double minSpeedForPaceMps = 0.5;

  /// Pace slower than this (20 min/km = 1200 s/km) displays '--:--'.
  static const double maxPaceSecPerKm = 1200.0;

  /// Split distance in meters (1 km).
  static const double splitDistanceM = 1000.0;

  /// Window in seconds to smooth current speed over.
  static const int speedSmoothingWindowS = 5;
}
