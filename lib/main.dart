import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Split;
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:latlong2/latlong.dart';

import 'bridge/native_tracking_bridge.dart';
import 'bridge/tracking_bridge.dart';
import 'core/contract/contract.dart';
import 'core/theme/app_palette.dart';
import 'core/theme/app_spacing.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_preference.dart';
import 'data/goal_repository.dart';
import 'data/current_location_client.dart';
import 'data/current_weather_client.dart';
import 'data/run.dart';
import 'data/run_repository.dart';
import 'data/planned_route.dart';
import 'data/planned_route_repository.dart';
import 'data/run_enrichment_service.dart';
import 'domain/achievements/goals_summary.dart';
import 'domain/achievements/milestone_notice.dart';
import 'domain/stats/stats.dart';
import 'features/account/account_gateway.dart';
import 'features/account/account_models.dart';
import 'features/achievements/goals_badges_screen.dart';
import 'features/app_strings.dart';
import 'features/history/history_run.dart';
import 'features/history/history_screen.dart';
import 'features/history/history_summary.dart';
import 'features/home/home_screen.dart';
import 'features/home/widgets/sky_header.dart' show HeaderIconButton;
import 'features/permissions/permission_gateway.dart';
import 'features/permissions/permissions_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/route_planning/ors_directions_client.dart';
import 'features/route_planning/route_planning_screen.dart';
import 'features/route_planning/saved_routes_screen.dart';
import 'features/run/active_run_screen.dart';
import 'features/run/live_run_formatter.dart';
import 'features/run/run_start_sheet.dart';
import 'features/settings/settings_screen.dart';
import 'features/splash/splash_screen.dart';
import 'features/summary/run_summary.dart';
import 'features/summary/summary_screen.dart';

// Road Runner — application entry point & integration shell.
// Owner: Praveen (integration shell) / Tharushi (screens & theme)

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Allow offline/local-first startup if Firebase is not configured.
  }
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
    this.goalRepository,
    this.permissionGateway,
    this.accountGateway,
    this.themePreference,
    this.currentLocationGetter,
    this.forecastFetcher,
    this.checkStartupState = true,
  });

  /// Optional bridge override for testing; defaults to [NativeTrackingBridge].
  final TrackingBridge? bridge;

  /// Optional repository override for testing; defaults to [SqliteRunRepository].
  final RunRepository? repository;

  /// Optional goal repository override for testing.
  final GoalRepository? goalRepository;

  /// Optional permission gateway override for testing; defaults to
  /// [PermissionHandlerGateway].
  final PermissionGateway? permissionGateway;

  /// Optional account gateway override for testing; defaults to
  /// [FirebaseAccountGateway] when Firebase is initialized.
  final AccountGateway? accountGateway;
  final ThemePreference? themePreference;
  final Future<LatLng?> Function()? currentLocationGetter;
  final Future<LocalForecast?> Function(double, double)? forecastFetcher;

  /// Whether to query native state, unfinished runs, and saved runs on startup.
  /// Can be disabled in isolated smoke tests.
  final bool checkStartupState;

  @override
  State<RoadRunnerApp> createState() => _RoadRunnerAppState();
}

class _RoadRunnerAppState extends State<RoadRunnerApp>
    with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final LiveRunFormatter _formatter = const LiveRunFormatter();
  final ValueNotifier<int> _shellRevision = ValueNotifier<int>(0);
  final ValueNotifier<int> _runsRevision = ValueNotifier<int>(0);
  late final ThemePreference _themePreference =
      widget.themePreference ?? ThemePreference();
  ThemeMode _themeMode = ThemeMode.system;
  bool _themeModeChangedManually = false;

  late final TrackingBridge _bridge;
  late final bool _ownsBridge;
  late final RunRepository _repository;
  late final GoalRepository _goalRepository;
  late final RunEnrichmentService _enrichment;
  final Map<String, Future<void>> _pendingEnrichments = {};
  late final PermissionGateway _permissionGateway;
  late final AccountGateway? _accountGateway;
  StreamSubscription<AccountUser?>? _authSub;

  static const MethodChannel _debugSimChannel = MethodChannel(
    'roadrunner/debug_sim',
  );

  List<HistoryRun> _recentRuns = const [];
  RecentRunsStatus _recentRunsStatus = RecentRunsStatus.ready;
  double? _weeklyDistanceKm;
  double? _weeklyGoalKm;
  AchievementsSnapshot? _homeAchievements;
  LocalForecast? _localForecast;
  LatLng? _lastKnownLocation;
  bool _forecastLoading = false;
  String? _forecastIssue;
  DateTime? _lastForecastFetch;
  late bool _startupCompleted = !widget.checkStartupState;
  bool _startupStarted = false;
  bool _isStartingRun = false;
  bool _debugSimulationEnabled = false;
  AccountUser? _accountUser;
  CloudUserProfile? _accountProfile;
  bool _accountBusy = false;
  String? _accountError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadThemeMode());
    _ownsBridge = widget.bridge == null;
    _bridge = widget.bridge ?? NativeTrackingBridge();
    _repository = widget.repository ?? SqliteRunRepository();
    _goalRepository =
        widget.goalRepository ??
        (widget.repository != null
            ? _InMemoryGoalRepository()
            : SqliteGoalRepository());
    _enrichment = RunEnrichmentService(repository: _repository);
    _permissionGateway =
        widget.permissionGateway ?? const PermissionHandlerGateway();
    _accountGateway =
        widget.accountGateway ??
        (Firebase.apps.isNotEmpty ? FirebaseAccountGateway() : null);

    if (_accountGateway != null) {
      _accountUser = _accountGateway.currentUser;
      _authSub = _accountGateway.authStateChanges.listen((user) {
        _accountUser = user;
        if (user == null) {
          _accountProfile = null;
        } else {
          unawaited(_syncAccount());
        }
        _notifyShell();
      });
      if (_accountUser != null) {
        unawaited(_syncAccount());
      }
    }

    if (widget.checkStartupState) {
      unawaited(_initializeAppFlow());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    _shellRevision.dispose();
    _runsRevision.dispose();
    if (_ownsBridge) {
      _bridge.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _startupCompleted) {
      unawaited(_refreshLocalForecast());
    }
  }

  void _notifyShell() {
    if (!mounted) return;
    _shellRevision.value++;
  }

  Future<void> _loadThemeMode() async {
    final mode = await _themePreference.load();
    if (mounted && !_themeModeChangedManually) {
      setState(() => _themeMode = mode);
    }
  }

  void _changeThemeMode(ThemeMode mode) {
    _themeModeChangedManually = true;
    setState(() => _themeMode = mode);
    unawaited(_saveThemeMode(mode));
  }

  Future<void> _saveThemeMode(ThemeMode mode) async {
    try {
      await _themePreference.save(mode);
    } catch (_) {
      final context = _navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Display choice could not be saved on this device.'),
          ),
        );
      }
    }
  }

  Future<void> _enrichRun(String runId) {
    if (_repository is! SqliteRunRepository) return Future<void>.value();
    final pending = _pendingEnrichments[runId];
    if (pending != null) return pending;
    final operation = _enrichment.enrichRun(runId);
    _pendingEnrichments[runId] = operation;
    operation.whenComplete(() => _pendingEnrichments.remove(runId)).ignore();
    return operation;
  }

  Future<void> _initializeAppFlow() async {
    if (_startupStarted || !mounted) return;
    _startupStarted = true;

    await _refreshRecentRuns();
    if (kDebugMode && _ownsBridge) {
      await _loadDebugSimulation();
    }

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
            runName: r.displayName,
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
      _weeklyDistanceKm = weeklyDistanceKm(runs);
      try {
        _weeklyGoalKm = await _goalRepository.getWeeklyGoalKm();
      } catch (_) {
        _weeklyGoalKm = null;
      }
      if (!mounted) return;
      _recentRunsStatus = RecentRunsStatus.ready;
      _notifyShell();
      _runsRevision.value++;
      unawaited(_refreshDashboardDetails());
    } catch (_) {
      if (!mounted) return;
      _recentRunsStatus = RecentRunsStatus.error;
      _notifyShell();
    }
  }

  Future<void> _refreshDashboardDetails() async {
    try {
      final snapshot = await _buildAchievementsSnapshot();
      if (!mounted) return;
      _homeAchievements = snapshot;
      _notifyShell();
    } catch (_) {
      // Run history remains usable if badge data cannot be read.
    }
    unawaited(_refreshLocalForecast());
  }

  Future<LatLng?> _currentLocation({bool requestPermission = false}) async {
    if (requestPermission) {
      final status = await _permissionGateway.check();
      if (status.location != PermissionAccess.granted) {
        await _permissionGateway.requestLocation();
      }
    }
    return (widget.currentLocationGetter ??
        const CurrentLocationClient().currentLocation)();
  }

  Future<void> _refreshLocalForecast({bool requestPermission = false}) async {
    if (_forecastLoading) return;
    final lastFetch = _lastForecastFetch;
    if (!requestPermission &&
        lastFetch != null &&
        DateTime.now().difference(lastFetch) < const Duration(minutes: 10)) {
      return;
    }
    _forecastLoading = true;
    _notifyShell();
    try {
      final location = await _currentLocation(
        requestPermission: requestPermission,
      );
      if (location == null) {
        _forecastIssue = 'Use location for the nearby forecast';
        _localForecast = null;
        return;
      }
      _lastKnownLocation = location;
      final fetcher = widget.forecastFetcher;
      final forecast = fetcher != null
          ? await fetcher(location.latitude, location.longitude)
          : await const CurrentWeatherClient().fetchForecast(
              location.latitude,
              location.longitude,
            );
      _localForecast = forecast;
      _forecastIssue = forecast == null
          ? 'Forecast unavailable · Tap to retry'
          : null;
      if (forecast != null) _lastForecastFetch = DateTime.now();
    } catch (_) {
      _forecastIssue = 'Use location for the nearby forecast';
      _localForecast = null;
    } finally {
      _forecastLoading = false;
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

  Future<void> _handleStartRun({
    PlannedRoute? plannedRoute,
    bool replaceTop = false,
    String? runName,
    String? displayName,
  }) async {
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
      _openActiveRun(
        plannedRoute: plannedRoute,
        replaceTop: replaceTop,
        runName: runName,
        displayName: displayName,
      );
      return;
    }

    _navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (context) => PermissionsScreen(
          gateway: _permissionGateway,
          onContinue: () {
            _navigatorKey.currentState?.pop();
            _openActiveRun(
              plannedRoute: plannedRoute,
              replaceTop: replaceTop,
              runName: runName,
              displayName: displayName,
            );
          },
          onNotNow: () {
            _navigatorKey.currentState?.pop();
          },
        ),
      ),
    );
  }

  Future<void> _showStartRunSheet({
    PlannedRoute? plannedRoute,
    bool replaceTop = false,
  }) async {
    final context = _navigatorKey.currentContext;
    if (context == null || _isStartingRun) return;
    final choice = await showModalBottomSheet<RunStartChoice>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => RunStartSheet(routeName: plannedRoute?.name),
    );
    if (!mounted || choice == null) return;
    await _handleStartRun(
      plannedRoute: plannedRoute,
      replaceTop: replaceTop,
      runName: choice.customName,
      displayName: choice.displayName,
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

  Future<void> _loadDebugSimulation() async {
    try {
      final bool? enabled = await _debugSimChannel.invokeMethod<bool>(
        'getEnabled',
      );
      if (mounted && enabled != null) {
        _debugSimulationEnabled = enabled;
      }
    } catch (_) {
      // Ignore on platforms without the debug channel.
    }
  }

  Future<void> _setDebugSimulation(bool enabled) async {
    _debugSimulationEnabled = enabled;
    _notifyShell();
    try {
      await _debugSimChannel.invokeMethod<void>('setEnabled', {
        'enabled': enabled,
      });
    } catch (_) {
      // Ignore on platforms without the debug channel.
    }
  }

  String _formatSignInError(Object error) {
    if (error is GoogleSignInException) {
      final String detail = error.description?.trim() ?? '';
      return detail.isNotEmpty
          ? 'Google sign-in failed (${error.code.name}): $detail'
          : 'Google sign-in failed (${error.code.name}).';
    }
    if (error is FirebaseAuthException) {
      return 'Firebase sign-in failed (${error.code}).';
    }
    return 'Could not sign in with Google. Please try again.';
  }

  Future<void> _signInWithGoogle() async {
    final AccountGateway? gateway = _accountGateway;
    if (gateway == null || _accountBusy) return;
    _accountBusy = true;
    _accountError = null;
    _notifyShell();
    try {
      final AccountUser? user = await gateway.signInWithGoogle();
      if (!mounted) return;
      _accountUser = user;
      if (user != null) {
        try {
          _accountProfile = await gateway.loadProfile(user.uid);
        } catch (_) {
          // Allow sign-in to succeed even if Firestore profile read fails.
        }
      }
    } catch (error) {
      if (!mounted) return;
      _accountError = _formatSignInError(error);
    } finally {
      _accountBusy = false;
      _notifyShell();
    }
  }

  Future<void> _signOut() async {
    final AccountGateway? gateway = _accountGateway;
    if (gateway == null || _accountBusy) return;
    _accountBusy = true;
    _accountError = null;
    _notifyShell();
    try {
      await gateway.signOut();
      if (!mounted) return;
      _accountUser = null;
      _accountProfile = null;
    } catch (_) {
      if (!mounted) return;
      _accountError = 'Could not sign out. Please try again.';
    } finally {
      _accountBusy = false;
      _notifyShell();
    }
  }

  Future<AchievementsSnapshot> _buildAchievementsSnapshot() async {
    final List<Run> runs = await _repository.list();
    final double goalKm = await _goalRepository.getWeeklyGoalKm();
    final Map<BadgeType, BadgeAward> earned = <BadgeType, BadgeAward>{};
    for (final Run run in runs) {
      final List<BadgeAward> runBadges = await _repository.getBadgesForRun(
        run.id,
      );
      for (final BadgeAward award in runBadges) {
        earned.putIfAbsent(award.type, () => award);
      }
    }
    return AchievementsSnapshot(
      weeklyDistanceKm: weeklyDistanceKm(runs),
      weeklyGoalKm: goalKm,
      weeklyRuns: weeklyRunCount(runs),
      currentStreakDays: currentDailyStreak(runs),
      longestStreakDays: longestDailyStreak(runs),
      earnedBadges: earned,
      longestRunKm: runs.isEmpty
          ? 0
          : runs.map((run) => run.distanceM).reduce((a, b) => a > b ? a : b) /
                1000,
    );
  }

  Future<void> _openGoals() async {
    AchievementsSnapshot snapshot = await _buildAchievementsSnapshot();
    if (!mounted) return;
    _navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (context) => StatefulBuilder(
          builder: (context, setScreenState) => GoalsBadgesScreen(
            snapshot: snapshot,
            isCloudSynced: _accountUser != null,
            onBack: () => _navigatorKey.currentState?.maybePop(),
            onGoalUpdated: (newGoalKm) {
              unawaited(() async {
                await _goalRepository.setWeeklyGoalKm(newGoalKm);
                final AchievementsSnapshot refreshed =
                    await _buildAchievementsSnapshot();
                if (!context.mounted) return;
                setScreenState(() => snapshot = refreshed);
                unawaited(_refreshRecentRuns());
                if (_accountUser != null) {
                  unawaited(_syncAccount());
                }
              }());
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openProfile({bool replaceCurrent = false}) async {
    AchievementsSnapshot snapshot;
    try {
      snapshot = await _buildAchievementsSnapshot();
    } catch (_) {
      snapshot = AchievementsSnapshot(
        weeklyDistanceKm: _weeklyDistanceKm ?? 0,
        weeklyGoalKm: _weeklyGoalKm ?? SqliteGoalRepository.defaultWeeklyGoalKm,
        weeklyRuns: 0,
        currentStreakDays: 0,
        longestStreakDays: 0,
        earnedBadges: const {},
      );
    }
    if (!mounted) return;
    final route = MaterialPageRoute<void>(
      builder: (context) => ListenableBuilder(
        listenable: _shellRevision,
        builder: (context, _) => ProfileScreen(
          snapshot: _homeAchievements ?? snapshot,
          user: _accountUser,
          accountBusy: _accountBusy,
          accountError: _accountError,
          onSignIn: _accountGateway == null
              ? null
              : () => unawaited(_signInWithGoogle()),
          onHome: _popToHome,
          onRoutes: () => unawaited(_openRoutesHome()),
          onRun: () => unawaited(_showStartRunSheet()),
          onHistory: () => unawaited(_openHistory(replaceCurrent: true)),
          onGoals: () => unawaited(_openGoals()),
          onSettings: _openSettings,
        ),
      ),
    );
    if (replaceCurrent) {
      _navigatorKey.currentState?.pushReplacement(route);
    } else {
      _navigatorKey.currentState?.push(route);
    }
  }

  Future<void> _syncAccount() async {
    final AccountGateway? gateway = _accountGateway;
    final AccountUser? user = _accountUser;
    if (gateway == null || user == null) return;
    _accountBusy = true;
    _accountError = null;
    _notifyShell();
    try {
      final AchievementsSnapshot local = await _buildAchievementsSnapshot();
      final CloudUserProfile? remote = await gateway.loadProfile(user.uid);
      final int nowMs = DateTime.now().millisecondsSinceEpoch;
      final List<String> badgeKeys = local.earnedBadges.keys
          .map((b) => b.key)
          .toList();
      final CloudUserProfile profile = CloudUserProfile(
        weeklyGoalKm: local.weeklyGoalKm,
        currentStreakDays: local.currentStreakDays,
        longestStreakDays:
            local.longestStreakDays > (remote?.longestStreakDays ?? 0)
            ? local.longestStreakDays
            : (remote?.longestStreakDays ?? 0),
        badges: badgeKeys,
        updatedAtMs: nowMs,
      );
      await gateway.saveProfile(user, profile);
      await gateway.saveGoal(
        user.uid,
        CloudGoal(
          id: 'weekly_distance',
          title: 'Run ${local.weeklyGoalKm.toStringAsFixed(0)} km this week',
          targetKm: local.weeklyGoalKm,
          period: 'weekly',
          updatedAtMs: nowMs,
        ),
      );
      for (final BadgeType type in local.earnedBadges.keys) {
        await gateway.saveBadge(
          user.uid,
          CloudBadge(id: type.key, earnedAtMs: nowMs),
        );
      }
      if (!mounted) return;
      _accountProfile = profile;
    } catch (_) {
      if (!mounted) return;
      _accountError = 'Cloud sync failed. Check your connection and try again.';
    } finally {
      _accountBusy = false;
      _notifyShell();
    }
  }

  void _openSettings({bool replaceCurrent = false}) {
    final route = MaterialPageRoute<void>(
      builder: (context) => ListenableBuilder(
        listenable: _shellRevision,
        builder: (context, _) => SettingsScreen(
          gateway: _permissionGateway,
          onBack: () => _navigatorKey.currentState?.maybePop(),
          onOpenHome: _popToHome,
          onOpenHistory: () => unawaited(_openHistory(replaceCurrent: true)),
          onOpenGoals: () => unawaited(_openGoals()),
          onManagePermissions: _openPermissions,
          debugSimulationEnabled: kDebugMode && _ownsBridge
              ? _debugSimulationEnabled
              : null,
          onDebugSimulationChanged: kDebugMode && _ownsBridge
              ? (value) => unawaited(_setDebugSimulation(value))
              : null,
          accountUser: _accountUser,
          accountProfile: _accountProfile,
          accountBusy: _accountBusy,
          accountError: _accountError,
          onSignInWithGoogle: _accountGateway != null
              ? () => unawaited(_signInWithGoogle())
              : null,
          onSignOut: _accountGateway != null
              ? () => unawaited(_signOut())
              : null,
          onSyncAccount: _accountGateway != null
              ? () => unawaited(_syncAccount())
              : null,
          themeMode: _themeMode,
          onThemeModeChanged: _changeThemeMode,
        ),
      ),
    );
    if (replaceCurrent) {
      _navigatorKey.currentState?.pushReplacement(route);
    } else {
      _navigatorKey.currentState?.push(route);
    }
  }

  void _openActiveRun({
    PlannedRoute? plannedRoute,
    bool replaceTop = false,
    String? runName,
    String? displayName,
  }) {
    final route = MaterialPageRoute<void>(
      builder: (context) => ActiveRunScreen(
        bridge: _bridge,
        formatter: _formatter,
        plannedRoute: plannedRoute,
        runName:
            displayName ??
            runName ??
            plannedRoute?.name ??
            makeRunName(DateTime.now(), null),
        onRunFinished: (result) {
          unawaited(
            _saveAndOpenSummary(
              result,
              replaceTop: true,
              customRunName: runName,
            ),
          );
        },
        onExit: () {
          _popToHome();
          unawaited(_refreshRecentRuns());
        },
      ),
    );
    if (replaceTop) {
      _navigatorKey.currentState?.pushReplacement(route);
    } else {
      _navigatorKey.currentState?.push(route);
    }
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
    String? customRunName,
  }) async {
    AchievementsSnapshot? beforeRun;
    try {
      beforeRun = await _buildAchievementsSnapshot();
    } catch (_) {
      // A missing progress snapshot must never prevent a run from saving.
    }
    while (mounted) {
      try {
        await _repository.saveFromFile(result.runId, result.filePath);
        if (customRunName != null) {
          await _repository.updateDetails(result.runId, runName: customRunName);
        }
        try {
          await _repository.recalculateBadges();
        } catch (_) {
          // Badge calculation errors must not block saving the run.
        }
        unawaited(_enrichRun(result.runId));
        if (_accountUser != null) {
          unawaited(_syncAccount());
        }
        try {
          await _bridge.discardRun(result.runId);
        } catch (_) {
          // Completed files or already-removed temp files may ignore discard.
        }
        await _refreshRecentRuns();
        if (kDebugMode && _ownsBridge) {
          await _loadDebugSimulation();
        }
        final RunSummary? summary = await _loadRunSummary(result.runId);
        if (!mounted) return;
        if (summary == null) {
          throw StateError('Saved run ${result.runId} was not found.');
        }

        var notices = <MilestoneNotice>[];
        if (beforeRun != null) {
          try {
            final afterRun = await _buildAchievementsSnapshot();
            final awards = await _repository.getBadgesForRun(result.runId);
            notices = milestoneNoticesAfterRun(
              before: beforeRun,
              after: afterRun,
              runAwards: awards,
              runDistanceKm: (summary.distanceM ?? 0) / 1000,
            );
          } catch (_) {
            // Milestone messages are optional; the saved summary still opens.
          }
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
        if (notices.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _showMilestonePopup(notices),
          );
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

  void _showMilestonePopup(List<MilestoneNotice> notices) {
    if (!mounted) return;
    final context = _navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        key: const Key('milestone.popup'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 7),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.emoji_events_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final notice in notices) ...[
                    Text(
                      notice.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(notice.message),
                    if (notice != notices.last) const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
        onOpenGoals: () => unawaited(_openGoals()),
        onPlanRoute: () => unawaited(_openRoutesHome()),
        onOpenProfile: () => unawaited(_openProfile(replaceCurrent: true)),
        onOpenRun: () => unawaited(_showStartRunSheet()),
        onStartRun: () {
          _popToHome();
          unawaited(_showStartRunSheet());
        },
      ),
    );
    if (replaceCurrent) {
      _navigatorKey.currentState?.pushReplacement(route);
    } else {
      _navigatorKey.currentState?.push(route);
    }
  }

  Future<void> _openRoutesHome() async {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    await navigator.push<void>(
      MaterialPageRoute(
        builder: (_) => SavedRoutesScreen(
          repository: PlannedRouteRepository(),
          onPlanRoute: () => _openRoutePlanner(),
          onRouteSelected: (route) => _openRoutePlanner(initialRoute: route),
          onHome: _popToHome,
          onRun: () => unawaited(_showStartRunSheet()),
          onHistory: () => unawaited(_openHistory(replaceCurrent: true)),
          onProfile: () => unawaited(_openProfile(replaceCurrent: true)),
        ),
      ),
    );
  }

  Future<void> _openRoutePlanner({PlannedRoute? initialRoute}) async {
    // Use a recent device fix if available; an older run is only a map-center
    // fallback, never labelled as the current position.
    var center = initialRoute == null
        ? _lastKnownLocation ?? const LatLng(0, 0)
        : LatLng(initialRoute.points.first.lat, initialRoute.points.first.lon);
    var zoom = initialRoute != null || _lastKnownLocation != null ? 14.0 : 2.0;
    if (initialRoute == null &&
        _lastKnownLocation == null &&
        _recentRuns.isNotEmpty) {
      try {
        final points = await _repository.getPoints(_recentRuns.first.runId);
        final first = points.where((point) => point.accepted).firstOrNull;
        if (first != null) {
          center = LatLng(first.lat, first.lon);
          zoom = 13;
        }
      } on Exception {
        // The world map remains available if a previous run cannot be read.
      }
    }
    if (!mounted) return;
    await _navigatorKey.currentState?.push<PlannedRoute>(
      MaterialPageRoute<PlannedRoute>(
        builder: (_) => RoutePlanningScreen(
          repository: PlannedRouteRepository(),
          directions: OrsDirectionsClient(
            apiKey: const String.fromEnvironment('ORS_API_KEY'),
          ),
          initialCenter: center,
          initialZoom: zoom,
          initialRoute: initialRoute,
          onCurrentLocation: () => _currentLocation(requestPermission: true),
          onStartRun: (plannedRoute) => unawaited(
            _showStartRunSheet(plannedRoute: plannedRoute, replaceTop: true),
          ),
        ),
      ),
    );
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
      runName: run.displayName,
      placeName: run.placeName,
      weatherTempC: run.weatherTempC,
      weatherWindKmh: run.weatherWindKmh,
      weatherCode: run.weatherCode,
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

  Future<RunSummary?> _enrichAndReloadSummary(String runId) async {
    if (_repository is! SqliteRunRepository) return null;
    try {
      await _enrichRun(runId);
      await _refreshRecentRuns();
      return await _loadRunSummary(runId);
    } on Exception {
      return null;
    }
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
      if (kDebugMode && _ownsBridge) {
        await _loadDebugSimulation();
      }
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
    return _SummaryDetailsLoader(
      initialSummary: summary,
      loadDetails: () => _enrichAndReloadSummary(summary.runId),
      builder: (shownSummary) => Stack(
        children: [
          SummaryScreen(
            summary: shownSummary,
            enableStreetMap: true,
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
      ),
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
      themeMode: _themeMode,
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
            weeklyDistanceKm: _weeklyDistanceKm,
            weeklyGoalKm: _weeklyGoalKm,
            isStartingRun: _isStartingRun,
            formatter: _formatter,
            onStartRun: () => unawaited(_showStartRunSheet()),
            onOpenRun: () => unawaited(_showStartRunSheet()),
            onPlanRoute: () => unawaited(_openRoutePlanner()),
            onOpenRoutes: () => unawaited(_openRoutesHome()),
            onOpenGoals: () => unawaited(_openGoals()),
            onOpenProfile: () => unawaited(_openProfile()),
            achievements: _homeAchievements,
            forecast: _localForecast,
            forecastLoading: _forecastLoading,
            forecastIssue: _forecastIssue,
            onUseLocation: () =>
                unawaited(_refreshLocalForecast(requestPermission: true)),
            onToggleTheme: (isDark) =>
                _changeThemeMode(isDark ? ThemeMode.light : ThemeMode.dark),
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

class _SummaryDetailsLoader extends StatefulWidget {
  const _SummaryDetailsLoader({
    required this.initialSummary,
    required this.loadDetails,
    required this.builder,
  });

  final RunSummary initialSummary;
  final Future<RunSummary?> Function() loadDetails;
  final Widget Function(RunSummary) builder;

  @override
  State<_SummaryDetailsLoader> createState() => _SummaryDetailsLoaderState();
}

class _SummaryDetailsLoaderState extends State<_SummaryDetailsLoader> {
  late RunSummary _summary = widget.initialSummary;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final updated = await widget.loadDetails();
    if (mounted && updated != null) setState(() => _summary = updated);
  }

  @override
  Widget build(BuildContext context) => widget.builder(_summary);
}

class _InMemoryGoalRepository implements GoalRepository {
  double _weeklyGoalKm = SqliteGoalRepository.defaultWeeklyGoalKm;

  @override
  Future<double> getWeeklyGoalKm() async => _weeklyGoalKm;

  @override
  Future<void> setWeeklyGoalKm(double goalKm) async {
    _weeklyGoalKm = goalKm.clamp(1.0, 1000.0);
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
    required this.onOpenGoals,
    required this.onPlanRoute,
    required this.onOpenProfile,
    required this.onOpenRun,
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
  final VoidCallback onOpenGoals;
  final VoidCallback onPlanRoute;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenRun;
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
              runName: r.displayName,
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
      onOpenGoals: widget.onOpenGoals,
      onPlanRoute: widget.onPlanRoute,
      onOpenProfile: widget.onOpenProfile,
      onOpenRun: widget.onOpenRun,
      onStartRun: widget.onStartRun,
    );
  }
}
