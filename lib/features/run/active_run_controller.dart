// Road Runner — Active Run controller (bridge-driven state).
// Owner: Tharushi
// SRS reference: Section 4.2, 4.5, 8.3, FR-20–23
//
// Local to the Run feature. Talks ONLY to the TrackingBridge interface
// (Aadila). The parent owns the bridge: this controller never calls
// bridge.dispose() and never stops a run on its own.
//
// Open integration questions (see lib/features/run/README.md):
//  * Whether TrackingSnapshot.elapsedMs keeps rising while paused.
//  * Whether TrackingStatus.filePath is filled after a run is stopped from
//    the notification (used to recover the RunResult).

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../bridge/tracking_bridge.dart';
import '../../core/contract/contract.dart';

/// Where the run is, as far as this screen knows.
enum RunPhase {
  /// Waiting for the bridge to start (or resync) the run.
  starting,

  /// Starting failed; the user can try again or exit.
  startFailed,

  /// Tracking confirmed by the bridge.
  running,

  /// Paused, confirmed by the bridge.
  paused,

  /// Finishing: stopRun() (or result recovery) in progress.
  stopping,

  /// Finished; the RunResult has been handed to the parent.
  finished,

  /// The run was stopped outside this screen and no result could be
  /// recovered from the bridge. Needs Aadila/Praveen integration.
  stoppedUnresolved,
}

/// Problems shown to the user.
enum RunIssueKind {
  locationOff,
  permissionDenied,
  serviceFailed,
  pauseFailed,
  resumeFailed,
  stopFailed,
}

/// One reported problem. [id] makes each report distinct.
@immutable
class RunIssue {
  const RunIssue(this.kind, this.id);

  final RunIssueKind kind;
  final int id;

  @override
  bool operator ==(Object other) =>
      other is RunIssue && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);
}

/// Immutable snapshot of what the Active Run screen shows.
@immutable
class ActiveRunState {
  const ActiveRunState({
    this.phase = RunPhase.starting,
    this.runId,
    this.snapshot,
    this.gpsQuality,
    this.busy = false,
    this.issue,
  });

  final RunPhase phase;
  final String? runId;

  /// Latest snapshot from the bridge. Null until the first one arrives —
  /// the screen shows placeholders, never invented values.
  final TrackingSnapshot? snapshot;

  /// One of kGpsSearching / kGpsWeak / kGpsGood, or null if not reported yet.
  final String? gpsQuality;

  /// True while a bridge operation is in progress. Blocks duplicate actions.
  final bool busy;

  /// Problem to show, or null.
  final RunIssue? issue;

  bool get canPause => phase == RunPhase.running && !busy;
  bool get canResume => phase == RunPhase.paused && !busy;
  bool get canStop =>
      (phase == RunPhase.running || phase == RunPhase.paused) && !busy;

  ActiveRunState copyWith({
    RunPhase? phase,
    String? runId,
    TrackingSnapshot? snapshot,
    String? gpsQuality,
    bool? busy,
    RunIssue? issue,
    bool clearIssue = false,
  }) {
    return ActiveRunState(
      phase: phase ?? this.phase,
      runId: runId ?? this.runId,
      snapshot: snapshot ?? this.snapshot,
      gpsQuality: gpsQuality ?? this.gpsQuality,
      busy: busy ?? this.busy,
      issue: clearIssue ? null : (issue ?? this.issue),
    );
  }
}

/// Drives the Active Run screen from [TrackingBridge] events and calls.
class ActiveRunController extends ChangeNotifier {
  ActiveRunController({required this.bridge, required this.onRunFinished});

  /// Owned by the parent. Never disposed or stopped here on teardown.
  final TrackingBridge bridge;

  /// Receives the real [RunResult] exactly once.
  final ValueChanged<RunResult> onRunFinished;

  ActiveRunState _state = const ActiveRunState();
  ActiveRunState get state => _state;

  StreamSubscription<TrackingEvent>? _subscription;
  bool _disposed = false;
  bool _resultDelivered = false;
  int _issueCounter = 0;

  bool get isDisposed => _disposed;

  void _set(ActiveRunState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  RunIssue _newIssue(RunIssueKind kind) => RunIssue(kind, ++_issueCounter);

  static RunIssueKind _kindForError(Object error) {
    if (error is PlatformException) {
      switch (error.code) {
        case kErrorLocationOff:
          return RunIssueKind.locationOff;
        case kErrorPermissionDenied:
          return RunIssueKind.permissionDenied;
      }
    }
    return RunIssueKind.serviceFailed;
  }

  // ─── Start / resync ─────────────────────────────────────────────────────────

  /// Starts a run, or resyncs with one that is already running or paused
  /// (FR-23). Safe to call again after [RunPhase.startFailed] (Try Again).
  Future<void> start() async {
    if (_disposed || _state.busy) return;
    if (_state.phase != RunPhase.starting &&
        _state.phase != RunPhase.startFailed) {
      return;
    }

    // Subscribe BEFORE starting: the event stream is broadcast, so events
    // sent during startRun() would otherwise be missed.
    _subscription ??= bridge.events.listen(
      _onEvent,
      onError: (Object _) => _reportIssue(RunIssueKind.serviceFailed),
    );

    _set(
      _state.copyWith(phase: RunPhase.starting, busy: true, clearIssue: true),
    );

    try {
      final TrackingStatus status = await bridge.getState();
      if (_disposed) return;

      if (status.state == kStateRunning || status.state == kStatePaused) {
        _set(
          _state.copyWith(
            phase: status.state == kStateRunning
                ? RunPhase.running
                : RunPhase.paused,
            runId: status.runId,
            snapshot: status.snapshot,
            busy: false,
          ),
        );
        return;
      }

      final String runId = await bridge.startRun();
      if (_disposed) return;
      _set(
        _state.copyWith(
          // A confirmed state event may already have moved the phase on.
          phase: _state.phase == RunPhase.starting
              ? RunPhase.running
              : _state.phase,
          runId: runId,
          busy: false,
        ),
      );
    } catch (error) {
      _set(
        _state.copyWith(
          phase: RunPhase.startFailed,
          busy: false,
          issue: _newIssue(_kindForError(error)),
        ),
      );
    }
  }

  // ─── Pause / resume ─────────────────────────────────────────────────────────

  /// Pauses. The phase becomes paused only after the bridge confirms.
  Future<void> pause() async {
    if (_disposed || !_state.canPause) return;
    _set(_state.copyWith(busy: true, clearIssue: true));
    try {
      await bridge.pauseRun();
      if (_disposed) return;
      _set(
        _state.copyWith(
          phase: _state.phase == RunPhase.running
              ? RunPhase.paused
              : _state.phase,
          busy: false,
        ),
      );
    } catch (_) {
      _set(
        _state.copyWith(
          busy: false,
          issue: _newIssue(RunIssueKind.pauseFailed),
        ),
      );
    }
  }

  /// Resumes. The phase becomes running only after the bridge confirms.
  Future<void> resume() async {
    if (_disposed || !_state.canResume) return;
    _set(_state.copyWith(busy: true, clearIssue: true));
    try {
      await bridge.resumeRun();
      if (_disposed) return;
      _set(
        _state.copyWith(
          phase: _state.phase == RunPhase.paused
              ? RunPhase.running
              : _state.phase,
          busy: false,
        ),
      );
    } catch (_) {
      _set(
        _state.copyWith(
          busy: false,
          issue: _newIssue(RunIssueKind.resumeFailed),
        ),
      );
    }
  }

  // ─── Finish ─────────────────────────────────────────────────────────────────

  /// Stops the run. Call ONLY after the user confirmed "Finish Run".
  ///
  /// On success the real [RunResult] goes to onRunFinished — even if the
  /// screen was removed meanwhile, so a finished run is never lost. On
  /// failure the previous phase is restored so the user can retry.
  Future<void> finish() async {
    if (_disposed || !_state.canStop) return;
    final RunPhase previous = _state.phase;
    _set(
      _state.copyWith(phase: RunPhase.stopping, busy: true, clearIssue: true),
    );
    try {
      final RunResult result = await bridge.stopRun();
      _set(_state.copyWith(phase: RunPhase.finished, busy: false));
      _deliver(result);
    } catch (_) {
      _set(
        _state.copyWith(
          phase: previous,
          busy: false,
          issue: _newIssue(RunIssueKind.stopFailed),
        ),
      );
    }
  }

  void _deliver(RunResult result) {
    if (_resultDelivered) return;
    _resultDelivered = true;
    onRunFinished(result);
  }

  /// Hides the current problem message.
  void clearIssue() {
    if (_state.issue != null) _set(_state.copyWith(clearIssue: true));
  }

  // ─── Bridge events ──────────────────────────────────────────────────────────

  void _reportIssue(RunIssueKind kind) {
    if (_state.phase == RunPhase.finished) return;
    _set(_state.copyWith(issue: _newIssue(kind)));
  }

  void _onEvent(TrackingEvent event) {
    if (_disposed) return;
    switch (event) {
      case TrackingSnapshotEvent(:final TrackingSnapshot snapshot):
        if (_state.phase == RunPhase.finished ||
            _state.phase == RunPhase.stoppedUnresolved) {
          return;
        }
        _set(_state.copyWith(snapshot: snapshot));
      case TrackingGpsEvent(:final String quality):
        _set(_state.copyWith(gpsQuality: quality));
      case TrackingStateEvent(:final String state, :final String? runId):
        _onStateEvent(state, runId);
      case TrackingErrorEvent(:final String code):
        _reportIssue(_kindForError(PlatformException(code: code)));
    }
  }

  void _onStateEvent(String state, String? runId) {
    final RunPhase phase = _state.phase;
    switch (state) {
      case kStateRunning:
        if (phase == RunPhase.starting ||
            phase == RunPhase.paused ||
            phase == RunPhase.running) {
          _set(_state.copyWith(phase: RunPhase.running, runId: runId));
        }
      case kStatePaused:
        if (phase == RunPhase.starting ||
            phase == RunPhase.running ||
            phase == RunPhase.paused) {
          _set(_state.copyWith(phase: RunPhase.paused, runId: runId));
        }
      case kStateStopped:
        // Our own stopRun() is in progress, or already handled: ignore.
        if (phase == RunPhase.running || phase == RunPhase.paused) {
          _recoverExternalStop(runId);
        }
      default:
        break;
    }
  }

  /// The run was stopped without our stopRun() call (e.g. from the
  /// notification). The only supported way to learn the result is
  /// getState(): if it reports a stopped run with a runId AND a filePath,
  /// that real result is passed on. Otherwise nothing is invented and the
  /// screen shows [RunPhase.stoppedUnresolved].
  Future<void> _recoverExternalStop(String? eventRunId) async {
    _set(
      _state.copyWith(phase: RunPhase.stopping, busy: true, clearIssue: true),
    );
    try {
      final TrackingStatus status = await bridge.getState();
      final String? runId = status.runId ?? eventRunId;
      final String? filePath = status.filePath;
      if (status.state == kStateStopped &&
          runId != null &&
          runId.isNotEmpty &&
          filePath != null &&
          filePath.isNotEmpty) {
        _set(_state.copyWith(phase: RunPhase.finished, busy: false));
        _deliver(RunResult(runId: runId, filePath: filePath));
        return;
      }
    } catch (_) {
      // Fall through to the unresolved state.
    }
    _set(_state.copyWith(phase: RunPhase.stoppedUnresolved, busy: false));
  }

  // ─── Lifecycle ──────────────────────────────────────────────────────────────

  /// Cancels the event subscription. Does NOT stop the run or dispose the
  /// bridge — the parent owns both.
  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}
