// Road Runner — Run Summary Revision 5 (Phase 2B.1) widget tests: header,
// four-stat strip, splits, loading and empty states, layout.
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

const List<RoutePoint> _route = [
  RoutePoint(lat: 0.000, lon: 0.000, speedMps: 2.5),
  RoutePoint(lat: 0.002, lon: 0.003, speedMps: 3.0),
  RoutePoint(lat: 0.004, lon: 0.002, speedMps: 3.5),
];

final RunSummary _run = RunSummary(
  runId: 'r1',
  startedAt: DateTime(2026, 11, 14, 6, 42),
  distanceM: 5020,
  movingMs: (32 * 60 + 15) * 1000,
  averagePaceSecPerKm: 385,
  averageSpeedMps: 2.594, // 9.3 km/h, as supplied by the integrator
  route: _route,
  splits: const [
    SplitSummary(km: 1, durationMs: 380000),
    SplitSummary(km: 2, durationMs: 391000),
    SplitSummary(km: 3, durationMs: 378000, isFastest: true),
    SplitSummary(km: 4, durationMs: 387000),
    SplitSummary(km: 5, durationMs: 389000),
  ],
  partialSplit: const PartialSplitSummary(distanceM: 20, durationMs: 8000),
);

class _Calls {
  int home = 0;
  int history = 0;
  int back = 0;
}

Future<_Calls> _pump(
  WidgetTester tester,
  RunSummary summary, {
  bool loading = false,
  bool withBack = true,
  bool reduceMotion = false,
  Size size = const Size(360, 800),
  double textScale = 1.0,
}) async {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = size * 3.0;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(disableAnimations: reduceMotion);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  final _Calls c = _Calls();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: SummaryScreen(
          summary: summary,
          isLoading: loading,
          onBackToHome: () => c.home++,
          onOpenHistory: () => c.history++,
          onBack: withBack ? () => c.back++ : null,
        ),
      ),
    ),
  );
  return c;
}

String _speech(WidgetTester tester, SummaryStat s) =>
    tester.getSemantics(find.byKey(SummaryScreen.statKey(s))).label;

Finder _inSplit(Key row, String text) =>
    find.descendant(of: find.byKey(row), matching: find.text(text));

void main() {
  group('Header', () {
    testWidgets('title, date and start time; no drawer', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, _run);
      expect(find.text(AppStrings.summaryTitle), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(SummaryScreen.dateKey)).data,
        AppStrings.summaryDateTime('14 Nov 2026', '6:42 AM'),
      );
      expect(
        tester.getSemantics(find.text(AppStrings.summaryTitle)),
        containsSemantics(isHeader: true),
      );
      final ScaffoldState scaffold = tester.state(find.byType(Scaffold));
      expect(scaffold.hasDrawer, isFalse);
      handle.dispose();
    });

    testWidgets('no timestamp: says the date is unavailable', (tester) async {
      await _pump(tester, const RunSummary(runId: 'x'));
      expect(
        tester.widget<Text>(find.byKey(SummaryScreen.dateKey)).data,
        AppStrings.summaryDateUnavailable,
      );
    });

    testWidgets('Back calls onBack only', (tester) async {
      final _Calls c = await _pump(tester, _run);
      await tester.tap(find.byKey(SummaryScreen.backButtonKey));
      await tester.pump();
      expect((c.back, c.home, c.history), (1, 0, 0));
    });

    testWidgets('without onBack, Back uses onBackToHome (existing exit)', (
      tester,
    ) async {
      final _Calls c = await _pump(tester, _run, withBack: false);
      await tester.tap(find.byKey(SummaryScreen.backButtonKey));
      await tester.pump();
      expect((c.back, c.home, c.history), (0, 1, 0));
    });

    testWidgets('Back is a labelled 48dp button', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, _run);
      expect(
        tester.getSemantics(find.byKey(SummaryScreen.backButtonKey)),
        containsSemantics(
          tooltip: AppStrings.summaryBack,
          isButton: true,
          hasTapAction: true,
        ),
      );
      final Size s = tester.getSize(find.byKey(SummaryScreen.backButtonKey));
      expect(s.width, greaterThanOrEqualTo(AppSpacing.minTouchTarget));
      expect(s.height, greaterThanOrEqualTo(AppSpacing.minTouchTarget));
      handle.dispose();
    });
  });

  group('Four statistics', () {
    testWidgets('one row of four on a 360dp phone, values as supplied', (
      tester,
    ) async {
      await _pump(tester, _run);
      final Map<SummaryStat, String> expected = {
        SummaryStat.distance: '5.02 km',
        SummaryStat.movingTime: '32:15',
        SummaryStat.averagePace: '6:25/km',
        SummaryStat.averageSpeed: '9.3 km/h',
      };
      for (final MapEntry<SummaryStat, String> e in expected.entries) {
        expect(
          find.descendant(
            of: find.byKey(SummaryScreen.statKey(e.key)),
            matching: find.text(e.value),
          ),
          findsOneWidget,
          reason: e.key.name,
        );
      }
      // Test font is wider than Roboto; on device all four share one row.
      // Here we only require the order: distance first, speed last.
      final Rect distance = tester.getRect(
        find.byKey(SummaryScreen.statKey(SummaryStat.distance)),
      );
      final Rect speed = tester.getRect(
        find.byKey(SummaryScreen.statKey(SummaryStat.averageSpeed)),
      );
      expect(
        speed.top > distance.top ||
            (speed.top == distance.top && speed.left > distance.left),
        isTrue,
      );
    });

    testWidgets('when there is room, all four share one row (kit layout)', (
      tester,
    ) async {
      // The test font is ~1.8x wider than Roboto, so a wide view stands in
      // for the 360dp phone here.
      await _pump(tester, _run, size: const Size(800, 900));
      final List<Rect> rects = [
        for (final SummaryStat s in SummaryStat.values)
          tester.getRect(find.byKey(SummaryScreen.statKey(s))),
      ];
      for (final Rect r in rects) {
        expect(r.top, rects.first.top);
      }
      for (int i = 1; i < rects.length; i++) {
        expect(rects[i].left, greaterThan(rects[i - 1].left));
      }
    });

    testWidgets('moving time over an hour uses h:mm:ss', (tester) async {
      await _pump(
        tester,
        const RunSummary(runId: 'x', movingMs: (1 * 3600 + 2 * 60 + 3) * 1000),
      );
      expect(
        find.descendant(
          of: find.byKey(SummaryScreen.statKey(SummaryStat.movingTime)),
          matching: find.text('1:02:03'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('valid average speed is spoken with its value', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, _run);
      expect(
        _speech(tester, SummaryStat.averageSpeed),
        AppStrings.statSemantics(AppStrings.statAverageSpeed, '9.3 km/h'),
      );
      expect(
        _speech(tester, SummaryStat.movingTime),
        AppStrings.statSemantics(AppStrings.statMovingTime, '32:15'),
      );
      handle.dispose();
    });

    testWidgets('missing average speed shows a placeholder, never 0', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(
        tester,
        const RunSummary(runId: 'x', distanceM: 5020, movingMs: 1935000),
      );
      expect(find.text('--.- km/h'), findsOneWidget);
      expect(find.textContaining('9.3'), findsNothing); // not derived here
      expect(
        _speech(tester, SummaryStat.averageSpeed),
        AppStrings.statSemantics(
          AppStrings.statAverageSpeed,
          AppStrings.statUnavailable,
        ),
      );
      handle.dispose();
    });

    testWidgets('every unavailable stat is spoken as "not available"', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, const RunSummary(runId: 'x'));
      for (final SummaryStat s in SummaryStat.values) {
        expect(
          _speech(tester, s),
          endsWith(AppStrings.statUnavailable),
          reason: s.name,
        );
        expect(_speech(tester, s), isNot(contains('-')), reason: s.name);
      }
      handle.dispose();
    });

    testWidgets('invalid values are not shown as numbers', (tester) async {
      await _pump(
        tester,
        const RunSummary(
          runId: 'x',
          distanceM: double.nan,
          averagePaceSecPerKm: -1,
          averageSpeedMps: double.infinity,
        ),
      );
      expect(find.text('-.-- km'), findsOneWidget);
      expect(find.text('--:--/km'), findsOneWidget);
      expect(find.text('--.- km/h'), findsOneWidget);
    });
  });

  group('Splits', () {
    testWidgets('full kilometres show their time', (tester) async {
      await _pump(tester, _run);
      await tester.ensureVisible(find.byKey(SummaryScreen.splitsCardKey));
      expect(_inSplit(SummaryScreen.splitRowKey(1), '6:20'), findsOneWidget);
      expect(_inSplit(SummaryScreen.splitRowKey(2), '6:31'), findsOneWidget);
      expect(_inSplit(SummaryScreen.splitRowKey(5), '6:29'), findsOneWidget);
    });

    testWidgets('a very slow kilometre still shows its real time', (
      tester,
    ) async {
      await _pump(
        tester,
        const RunSummary(
          runId: 'x',
          splits: [SplitSummary(km: 1, durationMs: (42 * 60 + 7) * 1000)],
        ),
      );
      expect(_inSplit(SummaryScreen.splitRowKey(1), '42:07'), findsOneWidget);
    });

    testWidgets('only the flagged full kilometre is FASTEST', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, _run);
      expect(find.text(AppStrings.splitFastest), findsOneWidget);
      expect(
        _inSplit(SummaryScreen.splitRowKey(3), AppStrings.splitFastest),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(find.byKey(SummaryScreen.splitRowKey(3))),
        containsSemantics(label: AppStrings.splitSemantics(3, '6:18', true)),
      );
      handle.dispose();
    });

    testWidgets('partial split: distance, time, "partial", never fastest', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, _run);
      await tester.ensureVisible(find.byKey(SummaryScreen.partialSplitKey));
      expect(
        _inSplit(SummaryScreen.partialSplitKey, '0.02 km'),
        findsOneWidget,
      );
      expect(
        _inSplit(SummaryScreen.partialSplitKey, AppStrings.splitPartial),
        findsOneWidget,
      );
      expect(_inSplit(SummaryScreen.partialSplitKey, '0:08'), findsOneWidget);
      expect(
        _inSplit(SummaryScreen.partialSplitKey, AppStrings.splitFastest),
        findsNothing,
      );
      expect(
        tester.getSemantics(find.byKey(SummaryScreen.partialSplitKey)),
        containsSemantics(
          label: AppStrings.splitPartialSemantics('0.02', '0:08'),
        ),
      );
      // It comes after the last full kilometre.
      expect(
        tester.getRect(find.byKey(SummaryScreen.partialSplitKey)).top,
        greaterThan(
          tester.getRect(find.byKey(SummaryScreen.splitRowKey(5))).bottom - 1,
        ),
      );
      handle.dispose();
    });

    testWidgets('a short partial (faster pace) is still not fastest', (
      tester,
    ) async {
      await _pump(
        tester,
        const RunSummary(
          runId: 'x',
          splits: [SplitSummary(km: 1, durationMs: 400000, isFastest: true)],
          partialSplit: PartialSplitSummary(distanceM: 500, durationMs: 90000),
        ),
      );
      expect(find.text(AppStrings.splitFastest), findsOneWidget);
      expect(
        _inSplit(SummaryScreen.partialSplitKey, AppStrings.splitFastest),
        findsNothing,
      );
    });

    testWidgets('no partial supplied: no partial row', (tester) async {
      await _pump(
        tester,
        const RunSummary(
          runId: 'x',
          splits: [SplitSummary(km: 1, durationMs: 300000)],
        ),
      );
      expect(find.byKey(SummaryScreen.partialSplitKey), findsNothing);
    });

    testWidgets('under 1 km with only a partial split shows that row', (
      tester,
    ) async {
      await _pump(
        tester,
        const RunSummary(
          runId: 'x',
          distanceM: 640,
          partialSplit: PartialSplitSummary(distanceM: 640, durationMs: 250000),
        ),
      );
      expect(find.byKey(SummaryScreen.partialSplitKey), findsOneWidget);
      expect(find.text(AppStrings.splitsUnderOneKm), findsNothing);
    });

    testWidgets(
      'no splits and no distance: "not available", not "under 1 km"',
      (tester) async {
        await _pump(tester, const RunSummary(runId: 'x', distanceM: 4200));
        expect(find.text(AppStrings.splitsUnavailable), findsOneWidget);
        expect(find.text(AppStrings.splitsUnderOneKm), findsNothing);
      },
    );
  });

  group('Loading', () {
    testWidgets('skeletons shimmer and replace stats, route and splits', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, _run, loading: true);
      expect(find.byKey(SummaryScreen.loadingKey), findsOneWidget);
      expect(find.byKey(SummaryScreen.statsCardKey), findsNothing);
      expect(find.byKey(SummaryScreen.routeAreaKey), findsNothing);
      expect(find.byKey(SummaryScreen.splitsCardKey), findsNothing);
      expect(find.text('5.02 km'), findsNothing); // nothing shown early
      expect(
        tester.getSemantics(find.byKey(SummaryScreen.loadingKey)),
        containsSemantics(label: AppStrings.summaryLoading),
      );
      expect(find.byType(ShaderMask), findsWidgets);
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.binding.hasScheduledFrame, isTrue);
      handle.dispose();
    });

    testWidgets('reduced motion leaves Summary skeletons visible and static', (
      tester,
    ) async {
      await _pump(tester, _run, loading: true, reduceMotion: true);
      expect(find.byKey(SummaryScreen.loadingKey), findsOneWidget);
      expect(find.byType(ShaderMask), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(SummaryScreen.loadingKey), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('header and navigation still work while loading', (
      tester,
    ) async {
      final _Calls c = await _pump(tester, _run, loading: true);
      expect(find.text(AppStrings.summaryTitle), findsOneWidget);
      await tester.tap(find.byKey(SummaryScreen.backButtonKey));
      await tester.ensureVisible(find.byKey(SummaryScreen.historyButtonKey));
      await tester.tap(find.byKey(SummaryScreen.historyButtonKey));
      await tester.pump();
      expect((c.back, c.history), (1, 1));
    });
  });

  group('Route states (renderer unchanged)', () {
    testWidgets('a real route is still drawn by RoutePainter', (tester) async {
      await _pump(tester, _run);
      final Iterable<CustomPaint> paints = tester.widgetList<CustomPaint>(
        find.descendant(
          of: find.byKey(SummaryScreen.routeAreaKey),
          matching: find.byType(CustomPaint),
        ),
      );
      expect(
        paints.where((p) => p.painter is RoutePainter).single.painter,
        isA<RoutePainter>().having((p) => p.points, 'points', same(_route)),
      );
    });

    for (final MapEntry<String, List<RoutePoint>> e in {
      'no route': const <RoutePoint>[],
      'one point': const [RoutePoint(lat: 6.9, lon: 79.8)],
      'same point twice': const [
        RoutePoint(lat: 6.9, lon: 79.8),
        RoutePoint(lat: 6.9, lon: 79.8),
      ],
    }.entries) {
      testWidgets('${e.key}: too short to map, with the reason', (
        tester,
      ) async {
        await _pump(tester, RunSummary(runId: 'x', route: e.value));
        for (final String t in [
          AppStrings.routeTooShort,
          AppStrings.routeTooShortDetail,
        ]) {
          expect(
            find.descendant(
              of: find.byKey(SummaryScreen.routeAreaKey),
              matching: find.text(t),
            ),
            findsOneWidget,
          );
        }
        expect(
          find.descendant(
            of: find.byKey(SummaryScreen.routeAreaKey),
            matching: find.byWidgetPredicate(
              (w) => w is CustomPaint && w.painter is RoutePainter,
            ),
          ),
          findsNothing,
        );
      });
    }
  });

  group('Layout', () {
    final Map<String, (Size, double)> sizes = {
      '360x800': (const Size(360, 800), 1.0),
      '320x568': (const Size(320, 568), 1.0),
      '412x915 (Galaxy A33)': (const Size(412, 915), 1.0),
      '360x800 at 1.3x text': (const Size(360, 800), 1.3),
      '320x568 at 1.3x text': (const Size(320, 568), 1.3),
    };
    final Map<String, (RunSummary, bool)> states = {
      'full run': (_run, false),
      'empty run': (const RunSummary(runId: 'x'), false),
      'loading': (_run, true),
    };
    for (final MapEntry<String, (Size, double)> s in sizes.entries) {
      for (final MapEntry<String, (RunSummary, bool)> st in states.entries) {
        testWidgets('${s.key}, ${st.key}: no overflow', (tester) async {
          await _pump(
            tester,
            st.value.$1,
            loading: st.value.$2,
            size: s.value.$1,
            textScale: s.value.$2,
          );
          expect(tester.takeException(), isNull);
          // Header stays fixed and fully on screen.
          final Rect back = tester.getRect(
            find.byKey(SummaryScreen.backButtonKey),
          );
          expect(back.top, greaterThanOrEqualTo(0));
          expect(back.right, lessThanOrEqualTo(s.value.$1.width));
          // Every stat stays within the card (none clipped off-screen).
          if (!st.value.$2) {
            for (final SummaryStat stat in SummaryStat.values) {
              final Rect r = tester.getRect(
                find.byKey(SummaryScreen.statKey(stat)),
              );
              expect(r.left, greaterThanOrEqualTo(0), reason: stat.name);
              expect(
                r.right,
                lessThanOrEqualTo(s.value.$1.width),
                reason: stat.name,
              );
            }
          }
          await tester.ensureVisible(
            find.byKey(SummaryScreen.historyButtonKey),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('respects the status and navigation bars', (tester) async {
      const double statusBar = 32, navBar = 48;
      tester.view.padding = const FakeViewPadding(
        top: statusBar * 3,
        bottom: navBar * 3,
      );
      addTearDown(tester.view.resetPadding);
      await _pump(tester, _run);
      expect(
        tester.getRect(find.byKey(SummaryScreen.backButtonKey)).top,
        greaterThanOrEqualTo(statusBar),
      );
      await tester.scrollUntilVisible(
        find.byKey(SummaryScreen.historyButtonKey),
        300,
      );
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(SummaryScreen.historyButtonKey)).bottom,
        lessThanOrEqualTo(800 - navBar),
      );
    });

    testWidgets('meets tap-target and label guidelines', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, _run);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });
}
