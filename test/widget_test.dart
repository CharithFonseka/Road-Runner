// Road Runner — integration shell smoke & flow tests.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/bridge/tracking_bridge.dart';
import 'package:road_runner/core/contract/contract.dart';
import 'package:road_runner/data/run.dart';
import 'package:road_runner/data/run_repository.dart';
import 'package:road_runner/domain/stats/stats.dart';
import 'package:road_runner/features/history/history_screen.dart';
import 'package:road_runner/features/home/widgets/slide_to_start.dart';
import 'package:road_runner/features/home/home_screen.dart';
import 'package:road_runner/features/permissions/permission_gateway.dart';
import 'package:road_runner/features/permissions/permissions_screen.dart';
import 'package:road_runner/features/run/active_run_screen.dart';
import 'package:road_runner/features/shared/app_navigation_drawer.dart';
import 'package:road_runner/features/summary/summary_screen.dart';
import 'package:road_runner/main.dart';

class _StubTrackingBridge implements TrackingBridge {
  final StreamController<TrackingEvent> _controller =
      StreamController<TrackingEvent>.broadcast();

  TrackingStatus currentStatus = const TrackingStatus(state: kStateIdle);
  RunResult? unfinishedRun;

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
    unfinishedRun = null;
  }

  @override
  void dispose() {
    _controller.close();
  }
}

class _StubRunRepository implements RunRepository {
  final List<Run> runs;
  final Map<String, List<Point>> pointsByRun;

  _StubRunRepository({List<Run>? runs, Map<String, List<Point>>? pointsByRun})
    : runs = runs ?? [],
      pointsByRun = pointsByRun ?? {};

  @override
  Future<void> saveFromFile(String runId, String filePath) async {}

  @override
  Future<List<Run>> list() async => List<Run>.from(runs);

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

void main() {
  testWidgets('RoadRunnerApp renders HomeScreen with last run', (
    WidgetTester tester,
  ) async {
    final bridge = _StubTrackingBridge();
    final repo = _StubRunRepository(
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
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('5.00 km'), findsOneWidget);
    expect(find.byType(ErrorWidget), findsNothing);
    bridge.dispose();
  });

  testWidgets('RoadRunnerApp opens History and Summary from Home', (
    WidgetTester tester,
  ) async {
    final bridge = _StubTrackingBridge();
    final repo = _StubRunRepository(
      runs: [
        const Run(
          id: 'run-42',
          startedAtUtcMs: 1700000000000,
          endedAtUtcMs: 1700000600000,
          movingMs: 600000,
          distanceM: 2000.0,
          avgPaceSecPerKm: 300.0,
        ),
      ],
      pointsByRun: {
        'run-42': const [
          Point(
            tUtcMs: 1700000000000,
            lat: 6.9271,
            lon: 79.8612,
            speedMps: 3.3,
          ),
          Point(
            tUtcMs: 1700000600000,
            lat: 6.9451,
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

    await tester.tap(find.byKey(HomeScreen.menuButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(AppNavigationDrawer.destinationKey(AppDestination.history)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(HistoryScreen), findsOneWidget);

    await tester.tap(find.byKey(HistoryScreen.runTileKey('run-42')));
    await tester.pumpAndSettle();
    expect(find.byType(SummaryScreen), findsOneWidget);
    bridge.dispose();
  });

  testWidgets('Start Run routes to Permissions when location is denied', (
    WidgetTester tester,
  ) async {
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

    final double travel =
        tester.getRect(find.byKey(HomeScreen.startRunButtonKey)).width -
        SlideToStart.handleSize -
        2 * SlideToStart.inset;
    await tester.drag(
      find.byKey(SlideToStart.handleKey),
      Offset(travel * 0.8, 0),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PermissionsScreen), findsOneWidget);
    bridge.dispose();
  });

  testWidgets('Start Run routes directly to ActiveRunScreen when granted', (
    WidgetTester tester,
  ) async {
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

    final double travel =
        tester.getRect(find.byKey(HomeScreen.startRunButtonKey)).width -
        SlideToStart.handleSize -
        2 * SlideToStart.inset;
    await tester.drag(
      find.byKey(SlideToStart.handleKey),
      Offset(travel * 0.8, 0),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ActiveRunScreen), findsOneWidget);
    bridge.dispose();
  });
}
