import 'dart:async';

import 'package:flutter/material.dart' hide Split;
import 'package:flutter/services.dart';

import 'bridge/native_tracking_bridge.dart';
import 'bridge/tracking_bridge.dart';
import 'core/contract/contract.dart';
import 'core/theme/app_palette.dart';
import 'core/theme/app_spacing.dart';
import 'core/theme/app_theme.dart';
import 'data/run.dart';
import 'data/run_repository.dart';
import 'data/run_weather_client.dart';
import 'domain/stats/stats.dart';
import 'features/app_strings.dart';
import 'features/history/history_run.dart';
import 'features/history/history_screen.dart';
import 'features/history/history_summary.dart';
import 'features/home/home_screen.dart';
import 'features/home/widgets/sky_header.dart' show HeaderIconButton;
import 'features/permissions/permission_gateway.dart';
import 'features/permissions/permissions_screen.dart';
import 'features/run/active_run_screen.dart';
import 'features/run/live_run_formatter.dart';
import 'features/settings/settings_screen.dart';
import 'features/splash/splash_screen.dart';
import 'features/summary/run_summary.dart';
import 'features/summary/summary_screen.dart';

// Road Runner — application entry point & integration shell.
// Owner: Praveen (integration shell) / Tharushi (screens & theme)

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RoadRunnerApp());
}

/// Root application widget wiring Splash, Home, Settings, Permissions,
/// Active Run, Summary, and History with [TrackingBridge], [RunRepository],
/// and [PermissionGateway].
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
  final ValueNotifier<int> _shellRevision = ValueNotifier<int>(0);
  final ValueNotifier<int> _runsRevision = ValueNotifier<int>(0);

  late final TrackingBridge _bridge;
  late final bool _ownsBridge;
  late final RunRepository _repository;
  late final PermissionGateway _permissionGateway;

  List<HistoryRun> _recentRuns = const [];
  RecentRunsStatus _recentRunsStatus = RecentRunsStatus.ready;
  late bool _startupCompleted = !widget.checkStartupState;
  bool _startupStarted = false;
  bool _isStartingRun = false;

  @override
  void initState() {
    super.initState();
    _ownsBridge = widget.bridge == null;
    _bridge = widget.bridge ?? NativeTrackingBridge();
    _repository = widget.repository ?? SqliteRunRepository();
    _permissionGateway =
        widget.permissionGateway ?? const PermissionHandlerGateway();

    if (widget.checkStartupState) {
      unawaited(_initializeAppFlow());
    }
  }

  @override
  void dispose() {
    _shellRevision.dispose();
    _runsRevision.dispose();
    if (_ownsBridge) {
      _bridge.dispose();
    }
    super.dispose();
  }

  void _notifyShell() {
    if (!mounted) return;
    _shellRevision.value++;
  }

  Future<void> _initializeAppFlow() async {
    if (_startupStarted || !mounted) return;
    _startupStarted = true;

    await _refreshRecentRuns();

    bool resumeActiveRun = false;
    RunResult? pendingUnfinished;

    // 1. Resync with any active run in the native foreground service (FR-23).
    try {
      final TrackingStatus status = await _bridge.getState();
      if (!mounted) return;
      if (status.state == kStateRunning || status.state == kStatePaused) {
        resumeActiveRun = true;
      }
    } catch (_) {
      // Fall through to idle startup if native state cannot be read.
    }

    // 2. Check for an unfinished run left behind by a crash/force-stop (FR-05).
    if (!resumeActiveRun) {
      try {
        final RunResult? unfinished = await _bridge.getUnfinishedRun();
        if (!mounted) return;
        if (unfinished != null) {
          bool alreadySaved = false;
          try {
            alreadySaved = (await _repository.get(unfinished.runId)) != null;
          } catch (_) {
            alreadySaved = false;
          }

          if (alreadySaved) {
            try {
              await _bridge.discardRun(unfinished.runId);
            } catch (_) {
              // Ignore cleanup errors for already-saved runs.
            }
          } else {
            pendingUnfinished = unfinished;
          }
        }
      } catch (_) {
        // Ignore recovery errors on startup.
      }
    }

    if (!mounted) return;
    _startupCompleted = true;
    _notifyShell();

    if (resumeActiveRun) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openActiveRun();
      });
    } else if (pendingUnfinished != null) {
      final RunResult recovered = pendingUnfinished;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_promptRecoverRun(recovered));
      });
    }
  }

  List<HistoryRun> _mapSortedRuns(List<Run> runs) {
    final List<Run> sorted = List<Run>.from(runs)
      ..sort((a, b) {
        final int byTime = b.startedAtUtcMs.compareTo(a.startedAtUtcMs);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
    return sorted
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
  }

  Future<void> _refreshRecentRuns({bool showLoading = false}) async {
    if (showLoading) {
      _recentRunsStatus = RecentRunsStatus.loading;
      _notifyShell();
    }
    try {
      final List<Run> runs = await _repository.list();
      if (!mounted) return;
      _recentRuns = _mapSortedRuns(runs);
      _recentRunsStatus = RecentRunsStatus.ready;
      _notifyShell();
      _runsRevision.value++;
    } catch (_) {
      if (!mounted) return;
      _recentRunsStatus = RecentRunsStatus.error;
      _notifyShell();
    }
  }

  void _popToHome() {
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
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
    if (_isStartingRun) return;
    _isStartingRun = true;
    _notifyShell();

    bool canStartImmediately = false;
    try {
      final PermissionSnapshot snapshot = await _permissionGateway.check();
      if (!mounted) return;
      canStartImmediately =
          snapshot.location == PermissionAccess.granted &&
          snapshot.locationServicesEnabled;
    } catch (_) {
      canStartImmediately = false;
    } finally {
      _isStartingRun = false;
      _notifyShell();
    }

    if (!mounted) return;
    if (canStartImmediately) {
      _openActiveRun();
      return;
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

  void _openSettings({bool replaceCurrent = false}) {
    final route = MaterialPageRoute<void>(
      builder: (context) => SettingsScreen(
        gateway: _permissionGateway,
        onBack: () => _navigatorKey.currentState?.maybePop(),
        onOpenHome: _popToHome,
        onOpenHistory: () => unawaited(_openHistory(replaceCurrent: true)),
        onManagePermissions: _openPermissions,
      ),
    );
    if (replaceCurrent) {
      _navigatorKey.currentState?.pushReplacement(route);
    } else {
      _navigatorKey.currentState?.push(route);
    }
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
            _popToHome();
            unawaited(_refreshRecentRuns());
          },
        ),
      ),
    );
  }

  Future<bool> _promptSaveRunFailed() async {
    final BuildContext? ctx = _navigatorKey.currentContext;
    if (ctx == null) return false;

    final bool? retry = await showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Could not save run'),
        content: const Text(
          'Road Runner could not save your run to this device. '
          'Would you like to try again?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Return Home'),
          ),
          FilledButton(
            key: const Key('saveRun.retry'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
    return retry == true;
  }

  Future<void> _saveAndOpenSummary(
    RunResult result, {
    required bool replaceTop,
  }) async {
    while (mounted) {
      try {
        await _repository.saveFromFile(result.runId, result.filePath);
        unawaited(enrichRunWeather(result.runId, repository: _repository));
        try {
          await _bridge.discardRun(result.runId);
        } catch (_) {
          // Completed files or already-removed temp files may ignore discard.
        }
        await _refreshRecentRuns();
        final RunSummary? summary = await _loadRunSummary(result.runId);
        if (!mounted) return;
        if (summary == null) {
          throw StateError('Saved run ${result.runId} was not found.');
        }

        final route = MaterialPageRoute<void>(
          builder: (context) =>
              _buildSummaryScreen(context, summary, fromHistory: false),
        );
        if (replaceTop) {
          _navigatorKey.currentState?.pushReplacement(route);
        } else {
          _navigatorKey.currentState?.push(route);
        }
        return;
      } catch (_) {
        if (!mounted) return;
        final bool retry = await _promptSaveRunFailed();
        if (!mounted || !retry) {
          _popToHome();
          return;
        }
      }
    }
  }

  Future<void> _openHistory({
    bool replaceCurrent = false,
    DateTime? referenceDate,
  }) async {
    final route = MaterialPageRoute<void>(
      builder: (context) => _HistoryRouteScreen(
        repository: _repository,
        runsRevision: _runsRevision,
        formatter: _formatter,
        referenceDate: referenceDate,
        onRunSelected: (runId) {
          unawaited(_openSummaryForRunId(runId, fromHistory: true));
        },
        onBackToHome: _popToHome,
        onOpenHome: _popToHome,
        onOpenSettings: () => _openSettings(replaceCurrent: true),
        onStartRun: () {
          _popToHome();
          unawaited(_handleStartRun());
        },
      ),
    );
    if (replaceCurrent) {
      _navigatorKey.currentState?.pushReplacement(route);
    } else {
      _navigatorKey.currentState?.push(route);
    }
  }

  Future<void> _openSummaryForRunId(
    String runId, {
    required bool fromHistory,
  }) async {
    try {
      final RunSummary? summary = await _loadRunSummary(runId);
      if (!mounted) return;
      if (summary == null) {
        _showLoadSummaryError();
        return;
      }
      _navigatorKey.currentState?.push(
        MaterialPageRoute<void>(
          builder: (context) =>
              _buildSummaryScreen(context, summary, fromHistory: fromHistory),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      _showLoadSummaryError();
    }
  }

  void _showLoadSummaryError() {
    final BuildContext? ctx = _navigatorKey.currentContext;
    if (ctx == null) return;
    ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
      const SnackBar(content: Text('Could not open run summary.')),
    );
  }

  Future<RunSummary?> _loadRunSummary(String runId) async {
    final Run? run = await _repository.get(runId);
    if (run == null) return null;
    final List<Point> points = await _repository.getPoints(runId);
    final List<PauseInterval> pauses = await _repository.getPauses(runId);

    final List<RoutePoint> route = points
        .where((p) => p.accepted)
        .map((p) => RoutePoint(lat: p.lat, lon: p.lon, speedMps: p.speedMps))
        .toList();

    final List<Split> allSplits = computeSplits(points, pauses: pauses);
    final List<Split> fullSplits = allSplits
        .where((s) => !s.isPartial)
        .toList();
    final Split? partial = allSplits.where((s) => s.isPartial).lastOrNull;

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

    final double? avgSpeedMps = run.movingMs > 0
        ? run.distanceM / (run.movingMs / 1000.0)
        : null;

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
      partialSplit: partial == null
          ? null
          : PartialSplitSummary(
              distanceM: partial.distanceM,
              durationMs: partial.durationMs,
            ),
    );
  }

  Future<void> _confirmAndDeleteRun(
    String runId, {
    required bool fromHistory,
  }) async {
    final BuildContext? ctx = _navigatorKey.currentContext;
    if (ctx == null) return;

    final bool? confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete run?'),
        content: const Text(
          'This run will be permanently removed from your history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('summary.confirmDelete'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    try {
      await _repository.delete(runId);
      try {
        await _bridge.discardRun(runId);
      } catch (_) {
        // Ignore if there is no corresponding temp file.
      }
      await _refreshRecentRuns();
      if (!mounted) return;
      if (fromHistory) {
        _navigatorKey.currentState?.pop();
      } else {
        _popToHome();
      }
    } catch (_) {
      if (!mounted) return;
      final BuildContext? errCtx = _navigatorKey.currentContext;
      if (errCtx != null && errCtx.mounted) {
        ScaffoldMessenger.maybeOf(
          errCtx,
        )?.showSnackBar(const SnackBar(content: Text('Could not delete run.')));
      }
    }
  }

  Widget _buildSummaryScreen(
    BuildContext context,
    RunSummary summary, {
    required bool fromHistory,
  }) {
    final double topInset = MediaQuery.paddingOf(context).top;
    return Stack(
      children: [
        SummaryScreen(
          summary: summary,
          formatter: _formatter,
          onBack: fromHistory
              ? () => _navigatorKey.currentState?.maybePop()
              : _popToHome,
          onBackToHome: () {
            _popToHome();
            unawaited(_refreshRecentRuns());
          },
          onOpenHistory: () {
            if (fromHistory) {
              _navigatorKey.currentState?.pop();
            } else {
              _popToHome();
              unawaited(_openHistory());
            }
          },
        ),
        PositionedDirectional(
          top: topInset + AppSpacing.small,
          end: AppSpacing.medium,
          child: Material(
            type: MaterialType.transparency,
            child: HeaderIconButton(
              key: const Key('summary.delete'),
              icon: Icons.delete_outline_rounded,
              tooltip: 'Delete run',
              onPressed: () => unawaited(
                _confirmAndDeleteRun(summary.runId, fromHistory: fromHistory),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: AppTheme.themeMode,
      builder: (context, child) {
        final AppPalette palette = context.palette;
        final bool isDark = palette.isDark;
        final SystemUiOverlayStyle overlayStyle =
            (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
                .copyWith(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: isDark
                      ? Brightness.light
                      : Brightness.dark,
                  statusBarBrightness: isDark
                      ? Brightness.dark
                      : Brightness.light,
                  systemNavigationBarColor: palette.background,
                  systemNavigationBarDividerColor: Colors.transparent,
                  systemNavigationBarIconBrightness: isDark
                      ? Brightness.light
                      : Brightness.dark,
                );
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlayStyle,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: ListenableBuilder(
        listenable: _shellRevision,
        builder: (context, _) {
          if (!_startupCompleted) {
            return const SplashScreen();
          }
          return HomeScreen(
            recentRuns: _recentRuns,
            recentRunsStatus: _recentRunsStatus,
            isStartingRun: _isStartingRun,
            formatter: _formatter,
            onStartRun: () => unawaited(_handleStartRun()),
            onOpenHistory: () => unawaited(_openHistory()),
            onOpenPermissions: _openPermissions,
            onOpenSettings: _openSettings,
            onRetry: () => unawaited(_refreshRecentRuns(showLoading: true)),
            onRunSelected: (runId) =>
                unawaited(_openSummaryForRunId(runId, fromHistory: false)),
          );
        },
      ),
    );
  }
}

class _HistoryRouteScreen extends StatefulWidget {
  const _HistoryRouteScreen({
    required this.repository,
    required this.runsRevision,
    required this.formatter,
    required this.onRunSelected,
    required this.onBackToHome,
    required this.onOpenHome,
    required this.onOpenSettings,
    required this.onStartRun,
    this.referenceDate,
  });

  final RunRepository repository;
  final ValueNotifier<int> runsRevision;
  final LiveRunFormatter formatter;
  final ValueChanged<String> onRunSelected;
  final VoidCallback onBackToHome;
  final VoidCallback onOpenHome;
  final VoidCallback onOpenSettings;
  final VoidCallback onStartRun;
  final DateTime? referenceDate;

  @override
  State<_HistoryRouteScreen> createState() => _HistoryRouteScreenState();
}

class _HistoryRouteScreenState extends State<_HistoryRouteScreen> {
  List<HistoryRun> _runs = const [];
  bool _isLoading = true;
  bool _hasError = false;
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    widget.runsRevision.addListener(_onRunsChanged);
    unawaited(_loadRuns());
  }

  @override
  void dispose() {
    widget.runsRevision.removeListener(_onRunsChanged);
    super.dispose();
  }

  void _onRunsChanged() {
    unawaited(_loadRuns(showLoading: false));
  }

  Future<void> _loadRuns({bool showLoading = true}) async {
    final int token = ++_loadToken;
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }
    try {
      final List<Run> runs = await widget.repository.list();
      if (!mounted || token != _loadToken) return;
      final List<HistoryRun> mapped = runs
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
      setState(() {
        _runs = mapped;
        _isLoading = false;
        _hasError = false;
      });
    } catch (_) {
      if (!mounted || token != _loadToken) return;
      setState(() {
        _runs = const [];
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = (widget.referenceDate ?? DateTime.now()).toLocal();
    final DateTime thisMonthStart = DateTime(now.year, now.month);
    final DateTime lastMonthStart = DateTime(now.year, now.month - 1);

    return HistoryScreen(
      runs: _runs,
      formatter: widget.formatter,
      referenceDate: widget.referenceDate,
      isLoading: _isLoading,
      hasError: _hasError,
      onRetry: () => unawaited(_loadRuns()),
      thisMonthSummary: _hasError
          ? null
          : computeMonthlySummary(_runs, thisMonthStart),
      lastMonthSummary: _hasError
          ? null
          : computeMonthlySummary(_runs, lastMonthStart),
      onRunSelected: widget.onRunSelected,
      onBackToHome: widget.onBackToHome,
      onOpenHome: widget.onOpenHome,
      onOpenSettings: widget.onOpenSettings,
      onStartRun: widget.onStartRun,
    );
  }
}
