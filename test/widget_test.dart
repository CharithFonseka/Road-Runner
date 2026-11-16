// Road Runner — integration shell smoke & flow tests.

import 'dart:async';

import 'package:flutter/material.dart' hide Split;
import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/bridge/tracking_bridge.dart';
import 'package:road_runner/core/contract/contract.dart';
import 'package:road_runner/data/run.dart';
import 'package:road_runner/data/run_repository.dart';
import 'package:road_runner/domain/stats/stats.dart';
import 'package:road_runner/features/app_strings.dart';
import 'package:road_runner/features/history/history_screen.dart';
import 'package:road_runner/features/home/home_screen.dart';
import 'package:road_runner/features/home/widgets/recent_runs_card.dart';
import 'package:road_runner/features/home/widgets/slide_to_start.dart';
import 'package:road_runner/features/permissions/permission_gateway.dart';
import 'package:road_runner/features/permissions/permissions_screen.dart';
import 'package:road_runner/features/run/active_run_screen.dart';
import 'package:road_runner/features/run/widgets/stop_run_dialog.dart';
import 'package:road_runner/features/settings/settings_screen.dart';
import 'package:road_runner/features/shared/app_navigation_drawer.dart';
import 'package:road_runner/features/splash/splash_screen.dart';
import 'package:road_runner/features/summary/summary_screen.dart';
import 'package:road_runner/main.dart';

class _StubTrackingBridge implements TrackingBridge {
  final StreamController<TrackingEvent> _controller =
      StreamController<TrackingEvent>.broadcast();

  TrackingStatus currentStatus = const TrackingStatus(state: kStateIdle);
  RunResult? unfinishedRun;
  final List<String> discardedRunIds = [];

  @override
  Stream<TrackingEvent> get events => _controller.stream;

  @override
  Future<String> startRun() async => 'run-1';

  @override
  Future<void> pauseRun() async {}

  @override
  Future<void> resumeRun() async {}

  @override
  Future<RunResult> stopRun() async =>
      const RunResult(runId: 'run-1', filePath: '/tmp/run-1.jsonl');

  @override
  Future<TrackingStatus> getState() async => currentStatus;

  @override
  Future<RunResult?> getUnfinishedRun() async => unfinishedRun;

  @override
  Future<void> discardRun(String runId) async {
    discardedRunIds.add(runId);
    if (unfinishedRun?.runId == runId) {
      unfinishedRun = null;
    }
  }

  @override
  void dispose() {
    _controller.close();
  }
}

class _StubRunRepository implements RunRepository {
  final List<Run> runs;
  final Map<String, List<Point>> pointsByRun;
  Completer<void>? listGate;
  int failListRemaining = 0;
  int failSaveRemaining = 0;

  _StubRunRepository({
    List<Run>? runs,
    Map<String, List<Point>>? pointsByRun,
    this.listGate,
    this.failListRemaining = 0,
    this.failSaveRemaining = 0,
  }) : runs = runs ?? [],
       pointsByRun = pointsByRun ?? {};

  @override
  Future<void> saveFromFile(String runId, String filePath) async {
    if (failSaveRemaining > 0) {
      failSaveRemaining--;
      throw StateError('Simulated save failure');
    }
    final bool exists = runs.any((r) => r.id == runId);
    if (!exists) {
      runs.add(
        Run(
          id: runId,
          startedAtUtcMs: 1700200000000,
          endedAtUtcMs: 1700200600000,
          movingMs: 600000,
          distanceM: 2000.0,
          avgPaceSecPerKm: 300.0,
        ),
      );
    }
  }

  @override
  Future<List<Run>> list() async {
    if (listGate != null && !listGate!.isCompleted) {
      await listGate!.future;
    }
    if (failListRemaining > 0) {
      failListRemaining--;
      throw StateError('Simulated list failure');
    }
    return List<Run>.from(runs);
  }

  @override
  Future<Run?> get(String runId) async {
    for (final run in runs) {
      if (run.id == runId) return run;
    }
    return null;
  }

  @override
  Future<List<Point>> getPoints(String runId) async =>
      pointsByRun[runId] ?? const [];

  @override
  Future<void> delete(String runId) async {
    runs.removeWhere((r) => r.id == runId);
    pointsByRun.remove(runId);
  }

  @override
  Future<String?> getUnfinishedRunPath() async => null;
}

class _StubPermissionGateway implements PermissionGateway {
  PermissionSnapshot snapshot;

  _StubPermissionGateway({
    this.snapshot = const PermissionSnapshot(
      location: PermissionAccess.granted,
      notification: PermissionAccess.granted,
      locationServicesEnabled: true,
    ),
  });

  @override
  Future<PermissionSnapshot> check() async => snapshot;

  @override
  Future<PermissionAccess> requestLocation() async => snapshot.location;

  @override
  Future<PermissionAccess> requestNotification() async => snapshot.notification;

  @override
  Future<bool> openAppSettings() async => true;
}

void _usePhoneViewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = const Size(412, 915) * 3.0;
  addTearDown(tester.view.reset);
}

Future<void> _slideToStart(WidgetTester tester) async {
  final double travel =
      tester.getRect(find.byKey(HomeScreen.startRunButtonKey)).width -
      SlideToStart.handleSize -
      2 * SlideToStart.inset;
  await tester.drag(
    find.byKey(SlideToStart.handleKey),
    Offset(travel * 0.8, 0),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('RoadRunnerApp shows SplashScreen until startup completes', (
    WidgetTester tester,
  ) async {
    _usePhoneViewport(tester);
    final bridge = _StubTrackingBridge();
    final listGate = Completer<void>();
    final repo = _StubRunRepository(
      listGate: listGate,
      runs: [
        const Run(
          id: 'run-1',
          startedAtUtcMs: 1700000000000,
          endedAtUtcMs: 1700001800000,
          movingMs: 1800000,
          distanceM: 5000.0,
          avgPaceSecPerKm: 360.0,
        ),
      ],
    );
    final permissions = _StubPermissionGateway();

    await tester.pumpWidget(
      RoadRunnerApp(
        bridge: bridge,
        repository: repo,
        permissionGateway: permissions,
      ),
    );
    await tester.pump();

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);

    listGate.complete();
    await tester.pumpAndSettle();

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('5.00 km'), findsOneWidget);
    bridge.dispose();
  });

  testWidgets(
    'Home shows full recent runs sorted newest-first and opens Summary with partial split',
    (WidgetTester tester) async {
      _usePhoneViewport(tester);
      final bridge = _StubTrackingBridge();
      final repo = _StubRunRepository(
        runs: [
          const Run(
            id: 'run-old',
            startedAtUtcMs: 1700000000000,
            endedAtUtcMs: 1700001800000,
            movingMs: 1800000,
            distanceM: 5000.0,
            avgPaceSecPerKm: 360.0,
          ),
          const Run(
            id: 'run-new',
            startedAtUtcMs: 1700100000000,
            endedAtUtcMs: 1700100450000,
            movingMs: 450000,
            distanceM: 1500.0,
            avgPaceSecPerKm: 300.0,
          ),
        ],
        pointsByRun: {
          'run-new': const [
            Point(
              tUtcMs: 1700100000000,
              lat: 6.9271,
              lon: 79.8612,
              speedMps: 3.3,
            ),
            Point(
              tUtcMs: 1700100450000,
              lat: 6.9406,
              lon: 79.8612,
              speedMps: 3.3,
            ),
          ],
        },
      );
      final permissions = _StubPermissionGateway();

      await tester.pumpWidget(
        RoadRunnerApp(
          bridge: bridge,
          repository: repo,
          permissionGateway: permissions,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(RecentRunsCard.rowKey(0)), findsOneWidget);
      expect(find.byKey(RecentRunsCard.rowKey(1)), findsOneWidget);
      expect(find.text('1.50 km'), findsOneWidget);
      expect(find.text('5.00 km'), findsOneWidget);

      await tester.tap(find.byKey(RecentRunsCard.rowKey(0)));
      await tester.pumpAndSettle();

      expect(find.byType(SummaryScreen), findsOneWidget);
      expect(find.byKey(SummaryScreen.splitRowKey(1)), findsOneWidget);
      expect(find.byKey(SummaryScreen.partialSplitKey), findsOneWidget);
      bridge.dispose();
    },
  );

  testWidgets(
    'SettingsScreen is reachable from Home and History drawer without stacking',
    (WidgetTester tester) async {
      _usePhoneViewport(tester);
      final bridge = _StubTrackingBridge();
      final repo = _StubRunRepository();
      final permissions = _StubPermissionGateway();

      await tester.pumpWidget(
        RoadRunnerApp(
          bridge: bridge,
          repository: repo,
          permissionGateway: permissions,
        ),
      );
      await tester.pumpAndSettle();

      // From Home header Settings button.
      await tester.tap(find.byKey(HomeScreen.settingsButtonKey));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);

      await tester.tap(find.byKey(SettingsScreen.backButtonKey));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);

      // From Home drawer -> History -> History drawer -> Settings.
      await tester.tap(find.byKey(HomeScreen.menuButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(AppNavigationDrawer.destinationKey(AppDestination.history)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HistoryScreen), findsOneWidget);

      await tester.tap(find.byKey(HistoryScreen.menuButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(AppNavigationDrawer.destinationKey(AppDestination.settings)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.byType(HistoryScreen), findsNothing);

      // Back from Settings returns directly to Home.
      await tester.tap(find.byKey(SettingsScreen.backButtonKey));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      bridge.dispose();
    },
  );

  testWidgets(
    'History -> Summary preserves Back stack, avoids duplicate History, and supports run deletion',
    (WidgetTester tester) async {
      _usePhoneViewport(tester);
      final bridge = _StubTrackingBridge();
      final repo = _StubRunRepository(
        runs: [
          const Run(
            id: 'run-1',
            startedAtUtcMs: 1700000000000,
            endedAtUtcMs: 1700000600000,
            movingMs: 600000,
            distanceM: 2000.0,
            avgPaceSecPerKm: 300.0,
          ),
          const Run(
            id: 'run-42',
            startedAtUtcMs: 1700100000000,
            endedAtUtcMs: 1700100600000,
            movingMs: 600000,
            distanceM: 2100.0,
            avgPaceSecPerKm: 285.0,
          ),
        ],
        pointsByRun: {
          'run-42': const [
            Point(
              tUtcMs: 1700100000000,
              lat: 6.9271,
              lon: 79.8612,
              speedMps: 3.5,
            ),
            Point(
              tUtcMs: 1700100600000,
              lat: 6.9460,
              lon: 79.8612,
              speedMps: 3.5,
            ),
          ],
        },
      );
      final permissions = _StubPermissionGateway();

      await tester.pumpWidget(
        RoadRunnerApp(
          bridge: bridge,
          repository: repo,
          permissionGateway: permissions,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(HomeScreen.menuButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(AppNavigationDrawer.destinationKey(AppDestination.history)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HistoryScreen), findsOneWidget);

      // History -> Summary -> Back returns to History.
      await tester.tap(find.byKey(HistoryScreen.runTileKey('run-42')));
      await tester.pumpAndSettle();
      expect(find.byType(SummaryScreen), findsOneWidget);

      await tester.tap(find.byKey(SummaryScreen.backButtonKey));
      await tester.pumpAndSettle();
      expect(find.byType(HistoryScreen), findsOneWidget);
      expect(find.byType(SummaryScreen), findsNothing);

      // History -> Summary -> "View History" returns without stacking duplicate History.
      await tester.tap(find.byKey(HistoryScreen.runTileKey('run-42')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(SummaryScreen.historyButtonKey));
      await tester.tap(find.byKey(SummaryScreen.historyButtonKey));
      await tester.pumpAndSettle();
      expect(find.byType(HistoryScreen), findsOneWidget);

      await tester.tap(find.byKey(HistoryScreen.backButtonKey));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(HistoryScreen), findsNothing);

      // Delete a run from Summary -> returns to History and refreshes list.
      await tester.tap(find.byKey(RecentRunsCard.viewAllKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(HistoryScreen.runTileKey('run-42')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('summary.delete')));
      await tester.pumpAndSettle();
      expect(find.text('Delete run?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('summary.confirmDelete')));
      await tester.pumpAndSettle();

      expect(find.byType(HistoryScreen), findsOneWidget);
      expect(find.byKey(HistoryScreen.runTileKey('run-42')), findsNothing);
      expect(find.byKey(HistoryScreen.runTileKey('run-1')), findsOneWidget);
      bridge.dispose();
    },
  );

  testWidgets(
    'Crash recovery cleans up unfinished run file after import and skips already-saved runs',
    (WidgetTester tester) async {
      _usePhoneViewport(tester);
      final bridge = _StubTrackingBridge()
        ..unfinishedRun = const RunResult(
          runId: 'run-crash',
          filePath: '/tmp/run-crash.jsonl',
        );
      final repo = _StubRunRepository();
      final permissions = _StubPermissionGateway();

      await tester.pumpWidget(
        RoadRunnerApp(
          bridge: bridge,
          repository: repo,
          permissionGateway: permissions,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Recover unfinished run?'), findsOneWidget);
      await tester.tap(find.text('Recover run'));
      await tester.pumpAndSettle();

      expect(find.byType(SummaryScreen), findsOneWidget);
      expect(bridge.discardedRunIds, contains('run-crash'));
      expect(await repo.get('run-crash'), isNotNull);

      // Relaunching when an already-saved runId still exists in recovery skips the prompt.
      final bridge2 = _StubTrackingBridge()
        ..unfinishedRun = const RunResult(
          runId: 'run-crash',
          filePath: '/tmp/run-crash.jsonl',
        );
      await tester.pumpWidget(
        RoadRunnerApp(
          key: const Key('app.relaunch'),
          bridge: bridge2,
          repository: repo,
          permissionGateway: permissions,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Recover unfinished run?'), findsNothing);
      expect(bridge2.discardedRunIds, contains('run-crash'));

      bridge.dispose();
      bridge2.dispose();
    },
  );

  testWidgets('Error states for History loading and saving runs offer Retry', (
    WidgetTester tester,
  ) async {
    _usePhoneViewport(tester);
    final bridge = _StubTrackingBridge();
    final repo = _StubRunRepository(
      failListRemaining: 2,
      failSaveRemaining: 1,
    );
    final permissions = _StubPermissionGateway();

    await tester.pumpWidget(
      RoadRunnerApp(
        bridge: bridge,
        repository: repo,
        permissionGateway: permissions,
      ),
    );
    await tester.pumpAndSettle();

    // Home list load failed once -> shows Retry card.
    expect(find.byKey(RecentRunsCard.errorKey), findsOneWidget);
    expect(find.byKey(RecentRunsCard.retryKey), findsOneWidget);

    // Open History while failListRemaining is still 1 -> shows error + retry.
    await tester.tap(find.byKey(HomeScreen.menuButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(AppNavigationDrawer.destinationKey(AppDestination.history)),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.historyErrorTitle), findsOneWidget);
    await tester.tap(find.text(AppStrings.historyRetry));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.historyEmptyTitle), findsOneWidget);

    await tester.tap(find.byKey(HistoryScreen.backButtonKey));
    await tester.pumpAndSettle();

    // Start and finish a run when saveFromFile fails once -> shows Retry dialog.
    await _slideToStart(tester);
    expect(find.byType(ActiveRunScreen), findsOneWidget);

    await tester.tap(find.byKey(ActiveRunScreen.stopButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(StopRunDialog.finishButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('Could not save run'), findsOneWidget);
    await tester.tap(find.byKey(const Key('saveRun.retry')));
    await tester.pumpAndSettle();

    expect(find.byType(SummaryScreen), findsOneWidget);
    bridge.dispose();
  });

  testWidgets('Start Run routes to Permissions when location is denied', (
    WidgetTester tester,
  ) async {
    _usePhoneViewport(tester);
    final bridge = _StubTrackingBridge();
    final repo = _StubRunRepository();
    final permissions = _StubPermissionGateway(
      snapshot: const PermissionSnapshot(
        location: PermissionAccess.denied,
        notification: PermissionAccess.denied,
        locationServicesEnabled: true,
      ),
    );

    await tester.pumpWidget(
      RoadRunnerApp(
        bridge: bridge,
        repository: repo,
        permissionGateway: permissions,
      ),
    );
    await tester.pumpAndSettle();

    await _slideToStart(tester);
    expect(find.byType(PermissionsScreen), findsOneWidget);
    bridge.dispose();
  });

  testWidgets('Start Run routes directly to ActiveRunScreen when granted', (
    WidgetTester tester,
  ) async {
    _usePhoneViewport(tester);
    final bridge = _StubTrackingBridge();
    final repo = _StubRunRepository();
    final permissions = _StubPermissionGateway();

    await tester.pumpWidget(
      RoadRunnerApp(
        bridge: bridge,
        repository: repo,
        permissionGateway: permissions,
      ),
    );
    await tester.pumpAndSettle();

    await _slideToStart(tester);
    expect(find.byType(ActiveRunScreen), findsOneWidget);
    bridge.dispose();
  });
}
