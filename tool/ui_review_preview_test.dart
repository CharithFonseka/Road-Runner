// Run explicitly with: flutter test tool/ui_review_preview_test.dart
// Writes sample-data phone previews to build/ui-review/ for local UI review.

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:latlong2/latlong.dart';
import 'package:road_runner/bridge/mock_tracking_bridge.dart';
import 'package:road_runner/core/theme/app_theme.dart';
import 'package:road_runner/core/theme/app_text_styles.dart';
import 'package:road_runner/data/planned_route.dart';
import 'package:road_runner/data/current_weather_client.dart';
import 'package:road_runner/data/planned_route_repository.dart';
import 'package:road_runner/data/run_weather_client.dart';
import 'package:road_runner/domain/achievements/achievements.dart';
import 'package:road_runner/domain/achievements/goals_summary.dart';
import 'package:road_runner/features/history/history_run.dart';
import 'package:road_runner/features/home/home_screen.dart';
import 'package:road_runner/features/profile/profile_screen.dart';
import 'package:road_runner/features/route_planning/ors_directions_client.dart';
import 'package:road_runner/features/route_planning/route_planning_screen.dart';
import 'package:road_runner/features/route_planning/saved_routes_screen.dart';
import 'package:road_runner/features/run/active_run_screen.dart';
import 'package:road_runner/features/run/run_start_sheet.dart';
import 'package:road_runner/features/summary/run_summary.dart';
import 'package:road_runner/features/summary/summary_screen.dart';

const Key previewKey = Key('ui-review.preview');

String flutterFontsPath() {
  final configuredRoot = Platform.environment['FLUTTER_ROOT'];
  if (configuredRoot != null) {
    return '$configuredRoot/bin/cache/artifacts/material_fonts';
  }
  var directory = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 10; i++) {
    final fonts = Directory(
      '${directory.path}/bin/cache/artifacts/material_fonts',
    );
    if (fonts.existsSync()) return fonts.path;
    directory = directory.parent;
  }
  throw StateError('Flutter material fonts not found');
}

class _PreviewRoutes extends PlannedRouteRepository {
  @override
  Future<void> save(PlannedRoute route) async {}

  @override
  Future<List<PlannedRoute>> list() async => const [
    PlannedRoute(
      id: 'park',
      name: 'Park loop',
      createdAtUtcMs: 1794873600000,
      points: [
        PlannedRoutePoint(lat: 6.9271, lon: 79.8612),
        PlannedRoutePoint(lat: 6.93, lon: 79.864),
      ],
    ),
    PlannedRoute(
      id: 'coast',
      name: 'Coast ride',
      createdAtUtcMs: 1794787200000,
      activity: RouteActivity.cycle,
      points: [
        PlannedRoutePoint(lat: 6.93, lon: 79.864),
        PlannedRoutePoint(lat: 6.96, lon: 79.87),
      ],
    ),
  ];
}

ThemeData reviewTheme({bool dark = false}) {
  final base = dark ? AppTheme.dark() : AppTheme.light();
  final buttonText = WidgetStatePropertyAll<TextStyle>(
    AppTextStyles.button.copyWith(fontFamily: 'Roboto'),
  );
  return base.copyWith(
    appBarTheme: base.appBarTheme.copyWith(
      titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(
        fontFamily: 'Roboto',
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: base.filledButtonTheme.style!.copyWith(textStyle: buttonText),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: base.outlinedButtonTheme.style!.copyWith(textStyle: buttonText),
    ),
    textButtonTheme: TextButtonThemeData(
      style: base.textButtonTheme.style!.copyWith(textStyle: buttonText),
    ),
  );
}

final previewAchievements = AchievementsSnapshot(
  weeklyDistanceKm: 8.5,
  weeklyGoalKm: 15,
  weeklyRuns: 2,
  currentStreakDays: 3,
  longestStreakDays: 5,
  longestRunKm: 5.02,
  earnedBadges: {
    BadgeType.firstRun: const BadgeAward('morning', BadgeType.firstRun),
    BadgeType.first5Km: const BadgeAward('morning', BadgeType.first5Km),
  },
);

Widget previewHome() => HomeScreen(
  recentRuns: [
    HistoryRun(
      runId: 'morning',
      runName: 'Morning run',
      startedAt: DateTime(2026, 11, 17, 7, 10),
      distanceM: 5020,
      movingMs: 1935000,
      averagePaceSecPerKm: 385,
    ),
    HistoryRun(
      runId: 'sunday',
      runName: 'Sunday loop',
      startedAt: DateTime(2026, 11, 15, 6, 55),
      distanceM: 3480,
      movingMs: 1265000,
      averagePaceSecPerKm: 363,
    ),
  ],
  weeklyDistanceKm: 8.5,
  weeklyGoalKm: 15,
  achievements: previewAchievements,
  forecast: LocalForecast(
    current: const RunWeather(28, 8, 2),
    nextHours: [
      HourlyWeather(
        time: DateTime(2026, 11, 17, 10),
        temperatureC: 29,
        code: 2,
        rainChancePercent: 10,
      ),
      HourlyWeather(
        time: DateTime(2026, 11, 17, 11),
        temperatureC: 30,
        code: 3,
        rainChancePercent: 20,
      ),
      HourlyWeather(
        time: DateTime(2026, 11, 17, 12),
        temperatureC: 29,
        code: 61,
        rainChancePercent: 45,
      ),
    ],
  ),
  onStartRun: () {},
  onOpenHistory: () {},
  onOpenPermissions: () {},
  onOpenGoals: () {},
  onOpenProfile: () {},
  onToggleTheme: (_) {},
  onPlanRoute: () {},
);

void phoneSize(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(393, 852);
  addTearDown(tester.view.reset);
}

Future<void> savePreview(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(previewKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final output = File('build/ui-review/$name.png');
    output.parent.createSync(recursive: true);
    await output.writeAsBytes(data!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    final fonts = flutterFontsPath();
    Future<ByteData> font(String path) async =>
        ByteData.sublistView(await File(path).readAsBytes());
    await Future.wait([
      (FontLoader('Roboto')
            ..addFont(font('$fonts/roboto-regular.ttf'))
            ..addFont(font('$fonts/roboto-bold.ttf')))
          .load(),
      (FontLoader('Ahem')..addFont(font('$fonts/roboto-regular.ttf'))).load(),
      (FontLoader(
        'MaterialIcons',
      )..addFont(font('$fonts/materialicons-regular.otf'))).load(),
    ]);
  });

  testWidgets('Routes home preview', (tester) async {
    phoneSize(tester);
    await tester.pumpWidget(
      RepaintBoundary(
        key: previewKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: reviewTheme(),
          home: SavedRoutesScreen(
            repository: _PreviewRoutes(),
            onPlanRoute: () async {},
            onRouteSelected: (_) async {},
            onHome: () {},
            onRun: () {},
            onHistory: () {},
            onProfile: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await savePreview(tester, 'routes-home');
  });

  testWidgets('Run setup preview', (tester) async {
    phoneSize(tester);
    await tester.pumpWidget(
      RepaintBoundary(
        key: previewKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: reviewTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () => showModalBottomSheet<RunStartChoice>(
                    context: context,
                    showDragHandle: true,
                    builder: (_) => const RunStartSheet(),
                  ),
                  child: const Text('Start run'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Start run'));
    await tester.pumpAndSettle();
    await savePreview(tester, 'run-setup');
  });

  testWidgets('Home preview', (tester) async {
    phoneSize(tester);
    await tester.pumpWidget(
      RepaintBoundary(
        key: previewKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: reviewTheme(),
          home: previewHome(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await savePreview(tester, 'home');
  });

  testWidgets('Home dark preview', (tester) async {
    phoneSize(tester);
    await tester.pumpWidget(
      RepaintBoundary(
        key: previewKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: reviewTheme(dark: true),
          home: previewHome(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await savePreview(tester, 'home-dark');
  });

  testWidgets('Profile preview', (tester) async {
    phoneSize(tester);
    await tester.pumpWidget(
      RepaintBoundary(
        key: previewKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: reviewTheme(),
          home: ProfileScreen(
            snapshot: previewAchievements,
            onHome: () {},
            onRoutes: () {},
            onRun: () {},
            onHistory: () {},
            onGoals: () {},
            onSettings: () {},
            onSignIn: () {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await savePreview(tester, 'profile');
  });

  testWidgets('Active Run preview', (tester) async {
    phoneSize(tester);
    final bridge = MockTrackingBridge();
    addTearDown(bridge.dispose);
    await tester.pumpWidget(
      RepaintBoundary(
        key: previewKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: reviewTheme(),
          home: ActiveRunScreen(
            bridge: bridge,
            onRunFinished: (_) {},
            onExit: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 9));
    await tester.pump();
    await savePreview(tester, 'active-run');
    await bridge.stopRun();
    await tester.pump();
  });

  testWidgets('Summary preview', (tester) async {
    phoneSize(tester);
    await tester.pumpWidget(
      RepaintBoundary(
        key: previewKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: reviewTheme(),
          home: SummaryScreen(
            summary: RunSummary(
              runId: 'morning',
              runName: 'Morning run',
              startedAt: DateTime(2026, 11, 17, 7, 10),
              distanceM: 5020,
              movingMs: 1935000,
              averagePaceSecPerKm: 385,
              averageSpeedMps: 2.59,
              route: const [
                RoutePoint(lat: 6.9271, lon: 79.8612, speedMps: 2.5),
                RoutePoint(lat: 6.9321, lon: 79.8652, speedMps: 2.8),
                RoutePoint(lat: 6.9301, lon: 79.8702, speedMps: 2.6),
                RoutePoint(lat: 6.9271, lon: 79.8612, speedMps: 2.7),
              ],
              splits: const [
                SplitSummary(km: 1, durationMs: 380000),
                SplitSummary(km: 2, durationMs: 391000),
                SplitSummary(km: 3, durationMs: 378000, isFastest: true),
              ],
            ),
            onBackToHome: () {},
            onOpenHistory: () {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await savePreview(tester, 'summary');
  });

  testWidgets('Route planner preview', (tester) async {
    phoneSize(tester);
    final style = Completer<vt.Style>();
    await tester.pumpWidget(
      RepaintBoundary(
        key: previewKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: reviewTheme(),
          home: RoutePlanningScreen(
            repository: _PreviewRoutes(),
            directions: OrsDirectionsClient(
              apiKey: 'preview-key',
              post: (_, _, _) async => {
                'features': [
                  {
                    'geometry': {
                      'type': 'LineString',
                      'coordinates': [
                        [79.8612, 6.9271],
                        [79.8652, 6.9321],
                        [79.8702, 6.9301],
                      ],
                    },
                  },
                ],
              },
            ),
            initialCenter: const LatLng(6.9271, 79.8612),
            styleFuture: style.future,
            weatherFetcher: (_) async => const RunWeather(28, 8, 2),
            onStartRun: (_) {},
          ),
        ),
      ),
    );
    final map = find.byKey(RoutePlanningScreen.mapKey);
    final topLeft = tester.getTopLeft(map);
    final panelBottom = tester
        .getBottomLeft(find.byKey(RoutePlanningScreen.inputPanelKey))
        .dy;
    await tester.tapAt(Offset(topLeft.dx + 80, panelBottom + 20));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tapAt(Offset(topLeft.dx + 240, panelBottom + 90));
    await tester.pump(const Duration(milliseconds: 300));
    if (find.byKey(RoutePlanningScreen.findKey).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(RoutePlanningScreen.findKey));
      await tester.pump();
    }
    await savePreview(tester, 'route-planner');
    await tester.tap(find.byKey(RoutePlanningScreen.startPointKey));
    await tester.pumpAndSettle();
    await savePreview(tester, 'route-point-picker');
  });
}
