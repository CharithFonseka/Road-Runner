// Road Runner — Run Summary screen widget tests.
// Owner: Tharushi
// SRS reference: FR-50–52, NFR-09, NFR-14

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/core/theme/app_spacing.dart';
import 'package:road_runner/core/theme/app_theme.dart';
import 'package:road_runner/features/app_strings.dart';
import 'package:road_runner/features/summary/run_summary.dart';
import 'package:road_runner/features/summary/summary_screen.dart';
import 'package:road_runner/features/summary/widgets/route_painter.dart';

// Test fixtures only — not real application data.

const List<RoutePoint> _routeWithSpeed = [
  RoutePoint(lat: 0.000, lon: 0.000, speedMps: 2.5),
  RoutePoint(lat: 0.002, lon: 0.003, speedMps: 3.0),
  RoutePoint(lat: 0.004, lon: 0.002, speedMps: 3.5),
  RoutePoint(lat: 0.006, lon: 0.006, speedMps: 2.8),
];

const List<RoutePoint> _routeNoSpeed = [
  RoutePoint(lat: 0.000, lon: 0.000),
  RoutePoint(lat: 0.003, lon: 0.004),
];

const List<SplitSummary> _splits = [
  SplitSummary(km: 1, durationMs: 380000),
  SplitSummary(km: 2, durationMs: 391000),
  SplitSummary(km: 3, durationMs: 378000, isFastest: true),
  SplitSummary(km: 4, durationMs: 387000),
];

final RunSummary _fullRun = RunSummary(
  runId: 'test-run',
  startedAt: DateTime(2026, 11, 14, 7, 42),
  distanceM: 4210,
  movingMs: (26 * 60 + 5) * 1000,
  averagePaceSecPerKm: 371.5,
  averageSpeedMps: 2.69,
  route: _routeWithSpeed,
  splits: _splits,
);

class _Calls {
  int home = 0;
  int history = 0;
}

Future<_Calls> _pump(
  WidgetTester tester,
  RunSummary summary, {
  Size size = const Size(360, 800),
  double textScale = 1.0,
}) async {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = size * 3.0;
  addTearDown(tester.view.reset);

  final _Calls calls = _Calls();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: SummaryScreen(
          summary: summary,
          onBackToHome: () => calls.home++,
          onOpenHistory: () => calls.history++,
        ),
      ),
    ),
  );
  return calls;
}

Finder _inRoute(Finder f) =>
    find.descendant(of: find.byKey(SummaryScreen.routeAreaKey), matching: f);

RoutePainter? _routePainter(WidgetTester tester) {
  final Iterable<CustomPaint> paints = tester.widgetList<CustomPaint>(
    _inRoute(find.byType(CustomPaint)),
  );
  for (final CustomPaint p in paints) {
    if (p.painter is RoutePainter) return p.painter! as RoutePainter;
  }
  return null;
}

void main() {
  group('Completed run', () {
    testWidgets('shows the four statistics formatted from the model', (
      tester,
    ) async {
      await _pump(tester, _fullRun);
      expect(find.text('4.21 km'), findsOneWidget);
      expect(find.text('26:05'), findsOneWidget);
      expect(find.text('6:12/km'), findsOneWidget);
      expect(find.text('9.7 km/h'), findsOneWidget);
      expect(find.text(AppStrings.statDistance), findsOneWidget);
      expect(find.text(AppStrings.statMovingTime), findsOneWidget);
      expect(find.text(AppStrings.statAveragePaceLong), findsOneWidget);
      expect(find.text(AppStrings.statAverageSpeed), findsOneWidget);
      // No unsupported measurements.
      expect(find.textContaining('alorie'), findsNothing);
    });

    testWidgets('shows run date and start time', (tester) async {
      await _pump(tester, _fullRun);
      final String date = tester
          .widget<Text>(find.byKey(SummaryScreen.dateKey))
          .data!;
      // UI kit Revision 5 header format: "14 Nov 2026 · 7:42 AM".
      expect(date, contains('14 Nov 2026'));
      expect(date, contains('7:42 AM'));
      expect(date, AppStrings.summaryDateTime('14 Nov 2026', '7:42 AM'));
    });

    testWidgets('missing date and values show placeholders', (tester) async {
      await _pump(tester, const RunSummary(runId: 'empty'));
      expect(find.text(AppStrings.summaryDateUnavailable), findsOneWidget);
      expect(find.text('-.-- km'), findsOneWidget);
      expect(find.text('--:--'), findsOneWidget);
      expect(find.text('--:--/km'), findsOneWidget);
      expect(find.text('--.- km/h'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Route', () {
    testWidgets('multi-point route is painted from the given points', (
      tester,
    ) async {
      await _pump(tester, _fullRun);
      final RoutePainter painter = _routePainter(tester)!;
      expect(painter.points, same(_routeWithSpeed));
      expect(painter.lastPositions, hasLength(_routeWithSpeed.length));
      expect(find.text(AppStrings.routeStart), findsOneWidget);
      expect(find.text(AppStrings.routeFinish), findsOneWidget);
    });

    testWidgets('speed data shows the slower/faster legend', (tester) async {
      await _pump(tester, _fullRun);
      expect(find.text(AppStrings.routeSlower), findsOneWidget);
      expect(find.text(AppStrings.routeFaster), findsOneWidget);
      expect(find.text(AppStrings.routeNoSpeed), findsNothing);
    });

    testWidgets('missing speed data says colours are unavailable', (
      tester,
    ) async {
      await _pump(tester, RunSummary(runId: 'r', route: _routeNoSpeed));
      expect(_routePainter(tester), isNotNull);
      expect(find.text(AppStrings.routeNoSpeed), findsOneWidget);
      expect(find.text(AppStrings.routeSlower), findsNothing);
    });

    for (final MapEntry<String, List<RoutePoint>> c in {
      'empty route': const <RoutePoint>[],
      'one-point route': const [RoutePoint(lat: 1, lon: 1)],
    }.entries) {
      testWidgets('${c.key} shows "Route too short to map"', (tester) async {
        await _pump(tester, RunSummary(runId: 'r', route: c.value));
        expect(_inRoute(find.text(AppStrings.routeTooShort)), findsOneWidget);
        expect(_routePainter(tester), isNull);
        expect(find.text(AppStrings.routeStart), findsNothing);
      });
    }

    testWidgets('route area is large', (tester) async {
      await _pump(tester, _fullRun);
      final Size s = tester.getSize(find.byKey(SummaryScreen.routeAreaKey));
      expect(s.height, greaterThanOrEqualTo(220));
      expect(s.width, greaterThanOrEqualTo(280));
    });
  });

  group('Splits', () {
    testWidgets('lists every supplied split with its pace', (tester) async {
      await _pump(tester, _fullRun);
      for (final SplitSummary s in _splits) {
        expect(find.text(AppStrings.splitKm(s.km)), findsOneWidget);
      }
      expect(find.text('6:20'), findsOneWidget);
      expect(find.text('6:31'), findsOneWidget);
      expect(find.text('6:18'), findsOneWidget);
      expect(find.text(AppStrings.splitsUnderOneKm), findsNothing);
    });

    testWidgets('highlights only the split flagged as fastest', (tester) async {
      await _pump(tester, _fullRun);
      expect(find.text(AppStrings.splitFastest), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(SummaryScreen.splitRowKey(3)),
          matching: find.text(AppStrings.splitFastest),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(SummaryScreen.splitRowKey(1)),
          matching: find.text(AppStrings.splitFastest),
        ),
        findsNothing,
      );
    });

    testWidgets('no flagged split means no highlight (none is guessed)', (
      tester,
    ) async {
      await _pump(
        tester,
        const RunSummary(
          runId: 'r',
          splits: [
            SplitSummary(km: 1, durationMs: 300000),
            SplitSummary(km: 2, durationMs: 200000),
          ],
        ),
      );
      expect(find.text(AppStrings.splitFastest), findsNothing);
    });

    testWidgets('run under 1 km', (tester) async {
      await _pump(tester, const RunSummary(runId: 'r', distanceM: 640));
      expect(find.text(AppStrings.splitsUnderOneKm), findsOneWidget);
      expect(find.text(AppStrings.splitFastest), findsNothing);
    });
  });

  group('Navigation', () {
    testWidgets('Back to Home and View History call their callbacks', (
      tester,
    ) async {
      final _Calls calls = await _pump(tester, _fullRun);
      await tester.ensureVisible(find.byKey(SummaryScreen.homeButtonKey));
      await tester.tap(find.byKey(SummaryScreen.homeButtonKey));
      expect((calls.home, calls.history), (1, 0));

      await tester.ensureVisible(find.byKey(SummaryScreen.historyButtonKey));
      await tester.tap(find.byKey(SummaryScreen.historyButtonKey));
      expect((calls.home, calls.history), (1, 1));
    });

    testWidgets('buttons are at least 48dp tall', (tester) async {
      await _pump(tester, _fullRun);
      for (final Key k in [
        SummaryScreen.homeButtonKey,
        SummaryScreen.historyButtonKey,
      ]) {
        expect(
          tester.getSize(find.byKey(k)).height,
          greaterThanOrEqualTo(AppSpacing.minTouchTarget),
        );
      }
    });
  });

  group('Accessibility', () {
    testWidgets('stats, route and splits have spoken descriptions', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, _fullRun);
      expect(
        find.bySemanticsLabel(
          AppStrings.statSemantics(AppStrings.statDistance, '4.21 km'),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(RegExp.escape(AppStrings.routeSemantics))),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(AppStrings.splitSemantics(3, '6:18', true)),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(AppStrings.splitSemantics(1, '6:20', false)),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('section titles are headers', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, _fullRun);
      for (final String t in [AppStrings.routeTitle, AppStrings.splitsTitle]) {
        expect(
          tester.getSemantics(find.text(t)),
          containsSemantics(isHeader: true),
        );
      }
      handle.dispose();
    });

    testWidgets('meets tap-target and label guidelines', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, _fullRun);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });

  group('Layout: no overflow', () {
    final Map<String, (Size, double)> sizes = {
      '360x800': (const Size(360, 800), 1.0),
      '320x568': (const Size(320, 568), 1.0),
      '320x568 at 1.3x text': (const Size(320, 568), 1.3),
    };
    final Map<String, RunSummary> runs = {
      'full run': _fullRun,
      'empty run': const RunSummary(runId: 'r'),
    };
    for (final MapEntry<String, (Size, double)> s in sizes.entries) {
      for (final MapEntry<String, RunSummary> r in runs.entries) {
        testWidgets('${s.key}, ${r.key}', (tester) async {
          await _pump(tester, r.value, size: s.value.$1, textScale: s.value.$2);
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(
            find.byKey(SummaryScreen.historyButtonKey),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(
            find.byKey(SummaryScreen.historyButtonKey).hitTestable(),
            findsOneWidget,
          );
        });
      }
    }
  });
}
