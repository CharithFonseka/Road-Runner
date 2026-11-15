import 'dart:async';

import 'package:flutter/material.dart' hide Split;

import 'bridge/native_tracking_bridge.dart';
import 'bridge/tracking_bridge.dart';
import 'core/contract/contract.dart';
import 'core/theme/app_theme.dart';
import 'data/run.dart';
import 'data/run_repository.dart';
import 'domain/stats/stats.dart';
import 'features/app_strings.dart';
import 'features/history/history_run.dart';
import 'features/history/history_screen.dart';
import 'features/home/home_screen.dart';
import 'features/home/last_run_summary.dart';
import 'features/permissions/permission_gateway.dart';
import 'features/permissions/permissions_screen.dart';
import 'features/run/active_run_screen.dart';
import 'features/run/live_run_formatter.dart';
import 'features/summary/run_summary.dart';
import 'features/summary/summary_screen.dart';

// Road Runner — application entry point & integration shell.
// Owner: Praveen (integration shell) / Tharushi (screens & theme)

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RoadRunnerApp());
}

/// Root application widget wiring Home, Permissions, Active Run, Summary,
/// and History with [TrackingBridge], [RunRepository], and [PermissionGateway].
class RoadRunnerApp extends StatefulWidget {
  const RoadRunnerApp({
    super.key,
    this.bridge,
    this.repository,
    this.permissionGateway,
    this.checkStartupState = true,
  });

  /// Optional bridge override for testing; defaults to [NativeTrackingBridge].
  final TrackingBridge? bridge;

  /// Optional repository override for testing; defaults to [SqliteRunRepository].
  final RunRepository? repository;

  /// Optional permission gateway override for testing; defaults to
  /// [PermissionHandlerGateway].
  final PermissionGateway? permissionGateway;

  /// Whether to query native state, unfinished runs, and saved runs on startup.
  /// Can be disabled in isolated smoke tests.
  final bool checkStartupState;

  @override
  State<RoadRunnerApp> createState() => _RoadRunnerAppState();
}

class _RoadRunnerAppState extends State<RoadRunnerApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final LiveRunFormatter _formatter = const LiveRunFormatter();

  late final TrackingBridge _bridge;
  late final bool _ownsBridge;
  late final RunRepository _repository;
  late final PermissionGateway _permissionGateway;

  LastRunSummary? _lastRun;
  bool _startupChecked = false;

  @override
  void initState() {
    super.initState();
    _ownsBridge = widget.bridge == null;
    _bridge = widget.bridge ?? NativeTrackingBridge();
    _repository = widget.repository ?? SqliteRunRepository();
    _permissionGateway =
        widget.permissionGateway ?? const PermissionHandlerGateway();

    if (widget.checkStartupState) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_initializeAppFlow());
      });
    }
  }

  @override
  void dispose() {
    if (_ownsBridge) {
      _bridge.dispose();
    }
    super.dispose();
  }

  Future<void> _initializeAppFlow() async {
    if (_startupChecked || !mounted) return;
    _startupChecked = true;

    await _refreshLastRun();

    // 1. Resync with any active run in the native foreground service (FR-23).
    try {
      final TrackingStatus status = await _bridge.getState();
      if (!mounted) return;
      if (status.state == kStateRunning || status.state == kStatePaused) {
        _openActiveRun();
        return;
      }
    } catch (_) {
      // Fall through to idle startup if native state cannot be read.
    }

    // 2. Check for an unfinished run left behind by a crash/force-stop (FR-05).
    try {
      final RunResult? unfinished = await _bridge.getUnfinishedRun();
      if (!mounted || unfinished == null) return;
      await _promptRecoverRun(unfinished);
    } catch (_) {
      // Ignore recovery errors on startup.
    }
  }

  Future<void> _refreshLastRun() async {
    try {
      final List<Run> runs = await _repository.list();
      if (!mounted) return;
      if (runs.isEmpty) {
        setState(() => _lastRun = null);
        return;
      }

      runs.sort((a, b) => b.startedAtUtcMs.compareTo(a.startedAtUtcMs));
      final Run latest = runs.first;
      final String rawPace = formatPace(latest.avgPaceSecPerKm);
      final String paceLabel = rawPace == LiveRunFormatter.pacePlaceholder
          ? rawPace
          : '$rawPace${AppStrings.unitPerKm}';

      setState(() {
        _lastRun = LastRunSummary(
          dateLabel: _formatDateLabel(latest.startedAtUtcMs),
          distance: formatDistance(latest.distanceM),
          duration: _formatter.elapsed(latest.movingMs),
          averagePace: paceLabel,
        );
      });
    } catch (_) {
      // Keep current state if database is not yet available.
    }
  }

  String _formatDateLabel(int startedAtUtcMs) {
    final DateTime local = DateTime.fromMillisecondsSinceEpoch(
      startedAtUtcMs,
      isUtc: true,
    ).toLocal();
    final BuildContext? ctx = _navigatorKey.currentContext;
    if (ctx != null) {
      return MaterialLocalizations.of(ctx).formatMediumDate(local);
    }
    final String m = local.month.toString().padLeft(2, '0');
    final String d = local.day.toString().padLeft(2, '0');
    return '${local.year}-$m-$d';
  }

  Future<void> _promptRecoverRun(RunResult unfinished) async {
    final BuildContext? ctx = _navigatorKey.currentContext;
    if (ctx == null) return;

    final bool? recover = await showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Recover unfinished run?'),
        content: const Text(
          'Road Runner found an unfinished run from your last session. '
          'Would you like to save and view it, or discard it?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Recover run'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (recover == true) {
      await _saveAndOpenSummary(unfinished, replaceTop: false);
    } else {
      try {
        await _bridge.discardRun(unfinished.runId);
      } catch (_) {
        // Ignore discard failure.
      }
    }
  }

  Future<void> _handleStartRun() async {
    try {
      final PermissionSnapshot snapshot = await _permissionGateway.check();
      if (!mounted) return;
      if (snapshot.location == PermissionAccess.granted &&
          snapshot.locationServicesEnabled) {
        _openActiveRun();
        return;
      }
    } catch (_) {
      // Fall through to PermissionsScreen if check fails.
    }

    _navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (context) => PermissionsScreen(
          gateway: _permissionGateway,
          onContinue: () {
            _navigatorKey.currentState?.pop();
            _openActiveRun();
          },
          onNotNow: () {
            _navigatorKey.currentState?.pop();
          },
        ),
      ),
    );
  }

  void _openPermissions() {
    _navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (context) => PermissionsScreen(
          gateway: _permissionGateway,
          onContinue: () => _navigatorKey.currentState?.pop(),
          onNotNow: () => _navigatorKey.currentState?.pop(),
        ),
      ),
    );
  }

  void _openActiveRun() {
    _navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (context) => ActiveRunScreen(
          bridge: _bridge,
          formatter: _formatter,
          onRunFinished: (result) {
            unawaited(_saveAndOpenSummary(result, replaceTop: true));
          },
          onExit: () {
            _navigatorKey.currentState?.popUntil((route) => route.isFirst);
            unawaited(_refreshLastRun());
          },
        ),
      ),
    );
  }

  Future<void> _saveAndOpenSummary(
    RunResult result, {
    required bool replaceTop,
  }) async {
    try {
      await _repository.saveFromFile(result.runId, result.filePath);
      await _refreshLastRun();
      final RunSummary? summary = await _loadRunSummary(result.runId);
      if (!mounted) return;

      if (summary == null) {
        _navigatorKey.currentState?.popUntil((route) => route.isFirst);
        return;
      }

      final route = MaterialPageRoute<void>(
        builder: (context) => _buildSummaryScreen(summary),
      );
      if (replaceTop) {
        _navigatorKey.currentState?.pushReplacement(route);
      } else {
        _navigatorKey.currentState?.push(route);
      }
    } catch (_) {
      if (!mounted) return;
      _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    }
  }

  Future<void> _openHistory() async {
    List<HistoryRun> historyRuns = const [];
    try {
      final List<Run> runs = await _repository.list();
      historyRuns = runs
          .map(
            (r) => HistoryRun(
              runId: r.id,
              startedAt: DateTime.fromMillisecondsSinceEpoch(
                r.startedAtUtcMs,
                isUtc: true,
              ),
              distanceM: r.distanceM,
              movingMs: r.movingMs,
              averagePaceSecPerKm: r.avgPaceSecPerKm,
            ),
          )
          .toList();
    } catch (_) {
      historyRuns = const [];
    }

    if (!mounted) return;
    _navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (context) => HistoryScreen(
          runs: historyRuns,
          formatter: _formatter,
          onRunSelected: (runId) {
            unawaited(_openSummaryForRunId(runId));
          },
          onBackToHome: () {
            _navigatorKey.currentState?.popUntil((route) => route.isFirst);
          },
        ),
      ),
    );
  }

  Future<void> _openSummaryForRunId(String runId) async {
    final RunSummary? summary = await _loadRunSummary(runId);
    if (!mounted || summary == null) return;
    _navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (context) => _buildSummaryScreen(summary),
      ),
    );
  }

  Future<RunSummary?> _loadRunSummary(String runId) async {
    final Run? run = await _repository.get(runId);
    if (run == null) return null;
    final List<Point> points = await _repository.getPoints(runId);

    final List<RoutePoint> route = points
        .where((p) => p.accepted)
        .map((p) => RoutePoint(lat: p.lat, lon: p.lon, speedMps: p.speedMps))
        .toList();

    final List<Split> fullSplits =
        computeSplits(points).where((s) => !s.isPartial).toList();
    int? fastestMs;
    if (fullSplits.isNotEmpty) {
      fastestMs = fullSplits
          .map((s) => s.durationMs)
          .reduce((a, b) => a < b ? a : b);
    }

    final List<SplitSummary> splitSummaries = fullSplits
        .map(
          (s) => SplitSummary(
            km: s.kmIndex,
            durationMs: s.durationMs,
            isFastest: fastestMs != null && s.durationMs == fastestMs,
          ),
        )
        .toList();

    final double? avgSpeedMps =
        run.movingMs > 0 ? run.distanceM / (run.movingMs / 1000.0) : null;

    return RunSummary(
      runId: run.id,
      startedAt: DateTime.fromMillisecondsSinceEpoch(
        run.startedAtUtcMs,
        isUtc: true,
      ),
      distanceM: run.distanceM,
      movingMs: run.movingMs,
      averagePaceSecPerKm: run.avgPaceSecPerKm,
      averageSpeedMps: avgSpeedMps,
      route: route,
      splits: splitSummaries,
    );
  }

  Widget _buildSummaryScreen(RunSummary summary) {
    return SummaryScreen(
      summary: summary,
      formatter: _formatter,
      onBackToHome: () {
        _navigatorKey.currentState?.popUntil((route) => route.isFirst);
        unawaited(_refreshLastRun());
      },
      onOpenHistory: () {
        unawaited(_openHistory());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: HomeScreen(
        lastRun: _lastRun,
        onStartRun: () => unawaited(_handleStartRun()),
        onOpenHistory: () => unawaited(_openHistory()),
        onOpenPermissions: _openPermissions,
      ),
    );
  }
}
