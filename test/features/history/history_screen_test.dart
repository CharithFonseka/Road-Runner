// Road Runner — History screen widget tests.
// Owner: Tharushi
// SRS reference: FR-61, FR-62, NFR-09, NFR-14

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/core/theme/app_spacing.dart';
import 'package:road_runner/core/theme/app_theme.dart';
import 'package:road_runner/features/app_strings.dart';
import 'package:road_runner/features/history/history_run.dart';
import 'package:road_runner/features/history/history_screen.dart';
import 'package:road_runner/features/shared/app_navigation_drawer.dart';
import 'package:road_runner/features/shared/skeleton_shimmer.dart';

// Test fixtures only — not real application data. Deliberately out of
// order to exercise sorting.
final HistoryRun _older = HistoryRun(
  runId: 'run-a',
  startedAt: DateTime(2026, 11, 8, 18, 5),
  distanceM: 7120,
  movingMs: (41 * 60 + 52) * 1000,
  averagePaceSecPerKm: 352.8,
);
final HistoryRun _newest = HistoryRun(
  runId: 'run-c',
  startedAt: DateTime(2026, 11, 14, 7, 42),
  distanceM: 5020,
  movingMs: (32 * 60 + 15) * 1000,
  averagePaceSecPerKm: 385,
);
final HistoryRun _middle = HistoryRun(
  runId: 'run-b',
  startedAt: DateTime(2026, 11, 11, 6, 30),
  distanceM: 3480,
  movingMs: (21 * 60 + 5) * 1000,
  averagePaceSecPerKm: 363,
);
final HistoryRun _october = HistoryRun(
  runId: 'run-october',
  startedAt: DateTime(2026, 10, 31, 23, 59),
  distanceM: 2400,
  movingMs: 900000,
  averagePaceSecPerKm: 375,
);
final HistoryRun _december = HistoryRun(
  runId: 'run-december',
  startedAt: DateTime(2026, 12, 31, 23, 59),
  distanceM: 3100,
  movingMs: 1200000,
  averagePaceSecPerKm: 390,
);
final HistoryRun _january = HistoryRun(
  runId: 'run-january',
  startedAt: DateTime(2027, 1, 1),
  distanceM: 1800,
  movingMs: 600000,
  averagePaceSecPerKm: 400,
);

class _Calls {
  final List<String> selected = [];
  int back = 0;
  int start = 0;
  int retry = 0;
  int home = 0;
  int settings = 0;
}

Future<_Calls> _pump(
  WidgetTester tester,
  List<HistoryRun> runs, {
  Size size = const Size(360, 800),
  double textScale = 1.0,
  DateTime? referenceDate,
  HistoryRunFilter initialFilter = HistoryRunFilter.allRuns,
  HistoryMonthlySummary? thisMonthSummary,
  HistoryMonthlySummary? lastMonthSummary,
  bool isLoading = false,
  bool hasError = false,
  bool withRetryAction = false,
  bool withStartRunAction = false,
  bool reduceMotion = false,
  VoidCallback? onRetry,
  VoidCallback? onStartRun,
  VoidCallback? onOpenHome,
  VoidCallback? onOpenSettings,
}) async {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = size * 3.0;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(disableAnimations: reduceMotion);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

  final _Calls calls = _Calls();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: HistoryScreen(
          runs: runs,
          onRunSelected: calls.selected.add,
          onBackToHome: () => calls.back++,
          referenceDate: referenceDate,
          initialFilter: initialFilter,
          thisMonthSummary: thisMonthSummary,
          lastMonthSummary: lastMonthSummary,
          isLoading: isLoading,
          hasError: hasError,
          onRetry: onRetry ?? (withRetryAction ? () => calls.retry++ : null),
          onStartRun:
              onStartRun ?? (withStartRunAction ? () => calls.start++ : null),
          onOpenHome: onOpenHome ?? () => calls.home++,
          onOpenSettings: onOpenSettings ?? () => calls.settings++,
        ),
      ),
    ),
  );
  return calls;
}

Finder _tile(String id) => find.byKey(HistoryScreen.runTileKey(id));

void main() {
  group('Empty history', () {
    testWidgets('shows a helpful empty state and no run cards', (tester) async {
      await _pump(tester, const []);
      expect(find.text(AppStrings.historyEmptyTitle), findsOneWidget);
      expect(find.text(AppStrings.historyEmptyMessage), findsOneWidget);
      expect(find.byType(Card), findsNothing);
      expect(find.byKey(HistoryScreen.backButtonKey), findsOneWidget);
    });

    testWidgets('offers Start a run only when a callback is supplied', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final _Calls calls = await _pump(
        tester,
        const [],
        withStartRunAction: true,
      );
      final Finder action = find.widgetWithText(
        FilledButton,
        AppStrings.historyStartRun,
      );
      expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
      expect(
        tester.getSemantics(action),
        containsSemantics(
          label: AppStrings.historyStartRun,
          isButton: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      await tester.tap(action);
      expect(calls.start, 1);
      handle.dispose();
    });

    testWidgets('shows an empty state for a month with no runs', (
      tester,
    ) async {
      await _pump(
        tester,
        [_newest],
        referenceDate: DateTime(2026, 11, 15),
        initialFilter: HistoryRunFilter.lastMonth,
      );
      expect(find.text(AppStrings.historyEmptyLastMonthTitle), findsOneWidget);
      expect(find.byType(Card), findsNothing);
      expect(_tile('run-c'), findsNothing);
    });
  });

  group('Month filtering', () {
    testWidgets('All Runs includes every run and omits month totals', (
      tester,
    ) async {
      await _pump(
        tester,
        [_october, _newest, _december],
        referenceDate: DateTime(2026, 11, 15),
        thisMonthSummary: const HistoryMonthlySummary(
          monthLabel: 'Nov 2026',
          totalRuns: 3,
          totalDistanceM: 15600,
          totalMovingMs: 6012000,
        ),
      );
      expect(_tile('run-october'), findsOneWidget);
      expect(_tile('run-c'), findsOneWidget);
      expect(_tile('run-december'), findsOneWidget);
      expect(find.byKey(HistoryScreen.summaryCardKey), findsNothing);
      expect(find.text(AppStrings.historyAllRuns), findsOneWidget);
    });

    testWidgets('This Month uses local calendar dates', (tester) async {
      await _pump(
        tester,
        [_october, _older, _middle, _newest, _december],
        referenceDate: DateTime(2026, 11, 15),
        initialFilter: HistoryRunFilter.thisMonth,
      );
      expect(_tile('run-a'), findsOneWidget);
      expect(_tile('run-b'), findsOneWidget);
      expect(_tile('run-c'), findsOneWidget);
      expect(_tile('run-october'), findsNothing);
      expect(_tile('run-december'), findsNothing);
    });

    testWidgets('Last Month selects the preceding calendar month', (
      tester,
    ) async {
      await _pump(
        tester,
        [_october, _older, _newest],
        referenceDate: DateTime(2026, 11, 15),
        initialFilter: HistoryRunFilter.lastMonth,
      );
      expect(_tile('run-october'), findsOneWidget);
      expect(_tile('run-a'), findsNothing);
      expect(_tile('run-c'), findsNothing);
    });

    testWidgets('month bounds are inclusive/exclusive without mutating input', (
      tester,
    ) async {
      final List<HistoryRun> input = [
        HistoryRun(runId: 'december-start', startedAt: DateTime(2026, 12, 1)),
        HistoryRun(runId: 'november-start', startedAt: DateTime(2026, 11, 1)),
        HistoryRun(
          runId: 'november-end',
          startedAt: DateTime(2026, 11, 30, 23, 59, 59),
        ),
      ];
      await _pump(
        tester,
        input,
        referenceDate: DateTime(2026, 11, 15),
        initialFilter: HistoryRunFilter.thisMonth,
        size: const Size(360, 2000),
      );
      expect(_tile('november-start'), findsOneWidget);
      expect(_tile('november-end'), findsOneWidget);
      expect(_tile('december-start'), findsNothing);
      expect(input.map((run) => run.runId), [
        'december-start',
        'november-start',
        'november-end',
      ]);
      expect(
        tester.getTopLeft(_tile('november-end')).dy,
        lessThan(tester.getTopLeft(_tile('november-start')).dy),
      );
    });

    testWidgets(
      'January Last Month correctly includes December of prior year',
      (tester) async {
        await _pump(
          tester,
          [_december, _january, _october],
          referenceDate: DateTime(2027, 1, 1),
          initialFilter: HistoryRunFilter.lastMonth,
        );
        expect(_tile('run-december'), findsOneWidget);
        expect(_tile('run-january'), findsNothing);
        expect(_tile('run-october'), findsNothing);
      },
    );

    testWidgets('filter chips switch the visible period', (tester) async {
      await _pump(tester, [
        _october,
        _newest,
      ], referenceDate: DateTime(2026, 11, 15));
      await tester.tap(
        find.byKey(HistoryScreen.filterChipKey(HistoryRunFilter.thisMonth)),
      );
      await tester.pumpAndSettle();
      expect(_tile('run-c'), findsOneWidget);
      expect(_tile('run-october'), findsNothing);

      await tester.tap(
        find.byKey(HistoryScreen.filterChipKey(HistoryRunFilter.lastMonth)),
      );
      await tester.pumpAndSettle();
      expect(_tile('run-october'), findsOneWidget);
      expect(_tile('run-c'), findsNothing);

      await tester.tap(
        find.byKey(HistoryScreen.filterChipKey(HistoryRunFilter.allRuns)),
      );
      await tester.pumpAndSettle();
      expect(_tile('run-october'), findsOneWidget);
      expect(_tile('run-c'), findsOneWidget);
    });
  });

  group('Monthly summary', () {
    testWidgets('displays supplied totals for the selected month only', (
      tester,
    ) async {
      await _pump(
        tester,
        [_newest],
        referenceDate: DateTime(2026, 11, 15),
        initialFilter: HistoryRunFilter.thisMonth,
        thisMonthSummary: const HistoryMonthlySummary(
          monthLabel: 'Nov 2026',
          totalRuns: 3,
          totalDistanceM: 15600,
          totalMovingMs: 6012000,
        ),
      );
      expect(find.byKey(HistoryScreen.summaryCardKey), findsOneWidget);
      expect(find.text('Nov 2026'), findsOneWidget);
      expect(find.text('3 runs · 15.60 km'), findsOneWidget);
      expect(find.text('1:40:12'), findsOneWidget);
      expect(find.text(AppStrings.historyTotalTime), findsOneWidget);
    });

    testWidgets('displays average pace in monthly summary when provided', (
      tester,
    ) async {
      await _pump(
        tester,
        [_newest],
        referenceDate: DateTime(2026, 11, 15),
        initialFilter: HistoryRunFilter.thisMonth,
        thisMonthSummary: const HistoryMonthlySummary(
          monthLabel: 'Nov 2026',
          totalRuns: 2,
          totalDistanceM: 8000,
          totalMovingMs: 2400000,
          averagePaceSecPerKm: 300.0,
        ),
      );
      expect(find.byKey(HistoryScreen.summaryCardKey), findsOneWidget);
      expect(find.text('Nov 2026'), findsOneWidget);
      expect(find.text('2 runs · 8.00 km'), findsOneWidget);
      expect(
        find.text('${AppStrings.statAveragePace} 5:00/km'),
        findsOneWidget,
      );
      expect(find.text('40:00'), findsOneWidget);
    });

    testWidgets('omits summary when monthly totals are not supplied', (
      tester,
    ) async {
      await _pump(
        tester,
        [_newest],
        referenceDate: DateTime(2026, 11, 15),
        initialFilter: HistoryRunFilter.thisMonth,
      );
      expect(find.byKey(HistoryScreen.summaryCardKey), findsNothing);
      expect(find.text(AppStrings.historyTotalTime), findsNothing);
    });
  });

  group('Load states', () {
    testWidgets('loading skeletons shimmer', (tester) async {
      await _pump(tester, [_newest], isLoading: true);
      expect(find.byKey(HistoryScreen.loadingStateKey), findsOneWidget);
      expect(find.byType(Card), findsNWidgets(4));
      expect(_tile('run-c'), findsNothing);
      expect(find.byType(SkeletonShimmer), findsOneWidget);
      expect(find.byType(ShaderMask), findsWidgets);
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.binding.hasScheduledFrame, isTrue);
    });

    testWidgets('reduced motion leaves History skeletons visible and static', (
      tester,
    ) async {
      await _pump(tester, [_newest], isLoading: true, reduceMotion: true);
      expect(find.byKey(HistoryScreen.loadingStateKey), findsOneWidget);
      expect(find.byType(Card), findsNWidgets(4));
      expect(find.byType(ShaderMask), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(HistoryScreen.loadingStateKey), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('error offers retry when a callback is provided', (
      tester,
    ) async {
      final _Calls calls = await _pump(
        tester,
        const [],
        hasError: true,
        withRetryAction: true,
      );
      expect(find.text(AppStrings.historyErrorTitle), findsOneWidget);
      await tester.tap(find.text(AppStrings.historyRetry));
      expect(calls.retry, 1);
    });
  });

  group('Runs', () {
    testWidgets('one saved run shows date, distance, duration and pace', (
      tester,
    ) async {
      await _pump(tester, [_newest]);
      expect(find.text('14 Nov 2026'), findsOneWidget);
      expect(find.text('7:42 AM'), findsNothing);
      expect(find.text('5.02 km'), findsOneWidget);
      expect(find.text('32:15'), findsOneWidget);
      expect(find.text('6:25/km'), findsOneWidget);
      expect(find.text(AppStrings.historyRunCount(1)), findsOneWidget);
      expect(find.text(AppStrings.historyEmptyTitle), findsNothing);
    });

    testWidgets('multiple runs are all listed', (tester) async {
      await _pump(tester, [_older, _newest, _middle]);
      expect(find.text(AppStrings.historyRunCount(3)), findsOneWidget);
      for (final HistoryRun r in [_older, _newest, _middle]) {
        await tester.scrollUntilVisible(_tile(r.runId), 200);
        expect(_tile(r.runId), findsOneWidget);
      }
    });

    testWidgets('runs supplied out of order are shown newest first', (
      tester,
    ) async {
      await _pump(tester, [
        _older,
        _newest,
        _middle,
      ], size: const Size(360, 2000));
      final double c = tester.getTopLeft(_tile('run-c')).dy;
      final double b = tester.getTopLeft(_tile('run-b')).dy;
      final double a = tester.getTopLeft(_tile('run-a')).dy;
      expect(c, lessThan(b));
      expect(b, lessThan(a));
    });

    testWidgets('missing values show placeholders', (tester) async {
      await _pump(tester, [
        HistoryRun(runId: 'x', startedAt: DateTime(2026, 1, 2, 9)),
      ]);
      expect(find.text('-.-- km'), findsOneWidget);
      expect(find.text('--:--'), findsOneWidget);
      expect(find.text('--:--/km'), findsOneWidget);
    });
  });

  group('Sorting', () {
    test('newestFirst orders by start time, newest first', () {
      final List<HistoryRun> sorted = HistoryScreen.newestFirst([
        _older,
        _newest,
        _middle,
      ]);
      expect(sorted.map((r) => r.runId), ['run-c', 'run-b', 'run-a']);
    });

    test('equal start times are ordered by run ID, input untouched', () {
      final DateTime t = DateTime(2026, 5, 5);
      final List<HistoryRun> input = [
        HistoryRun(runId: 'z', startedAt: t),
        HistoryRun(runId: 'm', startedAt: t),
      ];
      expect(HistoryScreen.newestFirst(input).map((r) => r.runId), ['m', 'z']);
      expect(input.first.runId, 'z');
    });

    test('UTC and local times are compared as the same instant', () {
      final HistoryRun utc = HistoryRun(
        runId: 'utc',
        startedAt: DateTime.utc(2026, 3, 1, 12),
      );
      final HistoryRun later = HistoryRun(
        runId: 'later',
        startedAt: DateTime.utc(2026, 3, 1, 12, 1).toLocal(),
      );
      expect(HistoryScreen.newestFirst([utc, later]).first.runId, 'later');
    });
  });

  group('Navigation', () {
    testWidgets('tapping a run passes exactly that run ID', (tester) async {
      final _Calls calls = await _pump(tester, [_older, _newest, _middle]);
      await tester.scrollUntilVisible(_tile('run-b'), 200);
      await tester.tap(_tile('run-b'));
      expect(calls.selected, ['run-b']);
      expect(calls.back, 0);
    });

    testWidgets('Back to Home calls onBackToHome', (tester) async {
      final _Calls calls = await _pump(tester, [_newest]);
      await tester.tap(find.byKey(HistoryScreen.backButtonKey));
      expect(calls.back, 1);
      expect(calls.selected, isEmpty);
    });

    testWidgets('drawer marks History selected and does not open it twice', (
      tester,
    ) async {
      final _Calls calls = await _pump(tester, [_newest]);
      await tester.tap(find.byKey(HistoryScreen.menuButtonKey));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AppNavigationDrawer>(find.byType(AppNavigationDrawer))
            .selected,
        AppDestination.history,
      );
      await tester.tap(
        find.byKey(AppNavigationDrawer.destinationKey(AppDestination.history)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AppNavigationDrawer), findsNothing);
      expect(calls.back, 0);
      expect(calls.home, 0);
      expect(calls.settings, 0);
    });

    testWidgets('drawer Home uses onOpenHome', (tester) async {
      final _Calls calls = await _pump(tester, [_newest]);
      await tester.tap(find.byKey(HistoryScreen.menuButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(AppNavigationDrawer.destinationKey(AppDestination.home)),
      );
      await tester.pumpAndSettle();
      expect(calls.home, 1);
      expect(calls.back, 0);
    });

    testWidgets('drawer Settings uses onOpenSettings', (tester) async {
      final _Calls calls = await _pump(tester, [_newest]);
      await tester.tap(find.byKey(HistoryScreen.menuButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(AppNavigationDrawer.destinationKey(AppDestination.settings)),
      );
      await tester.pumpAndSettle();
      expect(calls.settings, 1);
      expect(calls.home, 0);
    });
  });

  group('Accessibility', () {
    testWidgets('each run is one button with a descriptive label', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, [_newest]);
      expect(
        tester.getSemantics(_tile('run-c')),
        containsSemantics(
          label: AppStrings.historyRunSemantics(
            AppStrings.historyDateTime('14 Nov 2026', '7:42 AM'),
            '5.02 km',
            '32:15',
            '6:25/km',
          ),
          isButton: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('meets tap-target and label guidelines', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, [_newest, _middle]);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('filter chips expose selected state and 48dp targets', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, [_newest]);
      for (final HistoryRunFilter filter in HistoryRunFilter.values) {
        final Finder chip = find.byKey(HistoryScreen.filterChipKey(filter));
        expect(
          tester.getSize(chip).height,
          greaterThanOrEqualTo(AppSpacing.minTouchTarget),
        );
        expect(
          tester.getSemantics(chip),
          containsSemantics(
            label: switch (filter) {
              HistoryRunFilter.allRuns => AppStrings.historyAllRuns,
              HistoryRunFilter.thisMonth => AppStrings.historyThisMonth,
              HistoryRunFilter.lastMonth => AppStrings.historyLastMonth,
            },
            isButton: true,
            isSelected: filter == HistoryRunFilter.allRuns,
            hasTapAction: true,
          ),
        );
      }
      handle.dispose();
    });

    testWidgets('run cards and Back button are at least 48dp tall', (
      tester,
    ) async {
      await _pump(tester, [_newest]);
      for (final Finder f in [
        _tile('run-c'),
        find.byKey(HistoryScreen.backButtonKey),
      ]) {
        expect(
          tester.getSize(f).height,
          greaterThanOrEqualTo(AppSpacing.minTouchTarget),
        );
      }
    });
  });

  group('Layout: no overflow', () {
    final Map<String, (Size, double)> sizes = {
      '360x800': (const Size(360, 800), 1.0),
      '320x568': (const Size(320, 568), 1.0),
      '360x800 at 1.3x text': (const Size(360, 800), 1.3),
      '320x568 at 1.3x text': (const Size(320, 568), 1.3),
    };
    for (final MapEntry<String, (Size, double)> s in sizes.entries) {
      for (final bool empty in [true, false]) {
        testWidgets('${s.key}, ${empty ? 'empty' : 'three runs'}', (
          tester,
        ) async {
          await _pump(
            tester,
            empty ? const [] : [_older, _newest, _middle],
            size: s.value.$1,
            textScale: s.value.$2,
          );
          expect(tester.takeException(), isNull);
          if (!empty) {
            await tester.scrollUntilVisible(_tile('run-a'), 200);
            await tester.pump();
            expect(tester.takeException(), isNull);
          }
        });
      }
    }

    // Phase 2B.3: every non-list state at the same sizes.
    final HistoryMonthlySummary longSummary = const HistoryMonthlySummary(
      monthLabel: 'November 2026',
      totalRuns: 23,
      totalDistanceM: 187450,
      totalMovingMs: (19 * 3600 + 42 * 60 + 7) * 1000,
    );
    final Map<String, Future<void> Function(WidgetTester, Size, double)>
    states = {
      'month summary': (t, size, scale) => _pump(
        t,
        [_older, _newest, _middle],
        size: size,
        textScale: scale,
        referenceDate: DateTime(2026, 11, 16),
        initialFilter: HistoryRunFilter.thisMonth,
        thisMonthSummary: longSummary,
      ),
      'loading': (t, size, scale) => _pump(
        t,
        const [],
        size: size,
        textScale: scale,
        isLoading: true,
        reduceMotion: true,
      ),
      'error': (t, size, scale) => _pump(
        t,
        const [],
        size: size,
        textScale: scale,
        hasError: true,
        withRetryAction: true,
      ),
      'empty month with start': (t, size, scale) => _pump(
        t,
        [_october],
        size: size,
        textScale: scale,
        referenceDate: DateTime(2026, 11, 16),
        initialFilter: HistoryRunFilter.thisMonth,
        withStartRunAction: true,
      ),
    };
    for (final MapEntry<String, (Size, double)> s in sizes.entries) {
      for (final MapEntry<
            String,
            Future<void> Function(WidgetTester, Size, double)
          >
          st
          in states.entries) {
        testWidgets('${s.key}, ${st.key}', (tester) async {
          await st.value(tester, s.value.$1, s.value.$2);
          expect(tester.takeException(), isNull);
          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, -600),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
