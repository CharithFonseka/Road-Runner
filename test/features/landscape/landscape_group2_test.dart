// Road Runner — Landscape Orientation Widget Tests: Group 2.
// Phase 4B.3B: History screen and Run Summary screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/core/theme/app_palette.dart';
import 'package:road_runner/core/theme/app_theme.dart';
import 'package:road_runner/features/app_strings.dart';
import 'package:road_runner/features/history/history_run.dart';
import 'package:road_runner/features/history/history_screen.dart';
import 'package:road_runner/features/summary/run_summary.dart';
import 'package:road_runner/features/summary/summary_screen.dart';

// ─── Fixtures ───────────────────────────────────────────────────────────────

final _run1 = HistoryRun(
  runId: 'r1',
  startedAt: DateTime(2026, 11, 14, 7, 30),
  distanceM: 5020,
  movingMs: (32 * 60 + 15) * 1000,
  averagePaceSecPerKm: 385,
);
final _run2 = HistoryRun(
  runId: 'r2',
  startedAt: DateTime(2026, 11, 8, 18, 5),
  distanceM: 7120,
  movingMs: (41 * 60 + 52) * 1000,
  averagePaceSecPerKm: 352,
);

const _monthlySummary = HistoryMonthlySummary(
  monthLabel: 'Nov 2026',
  totalRuns: 2,
  totalDistanceM: 12140,
  totalMovingMs: (74 * 60 + 7) * 1000,
  averagePaceSecPerKm: 366,
);

const List<RoutePoint> _route = [
  RoutePoint(lat: 0.000, lon: 0.000, speedMps: 2.5),
  RoutePoint(lat: 0.002, lon: 0.003, speedMps: 3.0),
  RoutePoint(lat: 0.004, lon: 0.002, speedMps: 3.5),
];

final RunSummary _summary = RunSummary(
  runId: 's1',
  startedAt: DateTime(2026, 11, 14, 6, 42),
  distanceM: 5020,
  movingMs: (32 * 60 + 15) * 1000,
  averagePaceSecPerKm: 385,
  averageSpeedMps: 2.594,
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

final RunSummary _summaryNoRoute = RunSummary(
  runId: 's2',
  startedAt: DateTime(2026, 11, 14, 6, 42),
  distanceM: 500,
  movingMs: 180000,
);

// ─── History pump helpers ────────────────────────────────────────────────────

class _HistCalls {
  final List<String> selected = [];
  int back = 0;
}

Future<_HistCalls> _pumpHistory(
  WidgetTester tester,
  List<HistoryRun> runs, {
  Size size = const Size(800, 360),
  double textScale = 1.0,
  ThemeData? theme,
  HistoryRunFilter initialFilter = HistoryRunFilter.allRuns,
  HistoryMonthlySummary? thisMonthSummary,
  bool isLoading = false,
  bool hasError = false,
}) async {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = size * 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final calls = _HistCalls();
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light(),
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: HistoryScreen(
          runs: runs,
          onRunSelected: calls.selected.add,
          onBackToHome: () => calls.back++,
          initialFilter: initialFilter,
          thisMonthSummary: thisMonthSummary,
          isLoading: isLoading,
          hasError: hasError,
        ),
      ),
    ),
  );
  if (isLoading) {
    await tester.pump();
  } else {
    await tester.pumpAndSettle();
  }
  return calls;
}

// ─── Summary pump helpers ────────────────────────────────────────────────────

class _SumCalls {
  int home = 0;
  int history = 0;
  int back = 0;
}

Future<_SumCalls> _pumpSummary(
  WidgetTester tester,
  RunSummary summary, {
  Size size = const Size(800, 360),
  double textScale = 1.0,
  ThemeData? theme,
  bool isLoading = false,
}) async {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = size * 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final calls = _SumCalls();
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light(),
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: SummaryScreen(
          summary: summary,
          isLoading: isLoading,
          onBackToHome: () => calls.home++,
          onOpenHistory: () => calls.history++,
          onBack: () => calls.back++,
        ),
      ),
    ),
  );
  if (isLoading) {
    await tester.pump();
  } else {
    await tester.pumpAndSettle();
  }
  return calls;
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  // ── History Landscape ──────────────────────────────────────────────────────
  group('History Landscape (Phase 4B.3B)', () {
    testWidgets(
      '800x360 filter chips are visible and runs list is accessible',
      (tester) async {
        await _pumpHistory(tester, [_run1, _run2]);
        expect(tester.takeException(), isNull);

        // All 3 filter chips must be present.
        for (final f in HistoryRunFilter.values) {
          expect(find.byKey(HistoryScreen.filterChipKey(f)), findsOneWidget);
        }

        // Both run cards should be present.
        expect(
          find.byKey(HistoryScreen.runTileKey(_run1.runId)),
          findsOneWidget,
        );
        expect(
          find.byKey(HistoryScreen.runTileKey(_run2.runId)),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '800x360 filter chips appear to the left of the run cards in landscape',
      (tester) async {
        await _pumpHistory(tester, [_run1, _run2]);

        final Rect filterChip = tester.getRect(
          find.byKey(HistoryScreen.filterChipKey(HistoryRunFilter.allRuns)),
        );
        final Rect runCard = tester.getRect(
          find.byKey(HistoryScreen.runTileKey(_run1.runId)),
        );

        // In landscape two-column layout the filter must be to the left of runs.
        expect(filterChip.left, lessThan(runCard.left));
      },
    );

    testWidgets(
      '800x360 monthly summary card shows beside filter when filter active',
      (tester) async {
        await _pumpHistory(
          tester,
          [_run1, _run2],
          initialFilter: HistoryRunFilter.thisMonth,
          thisMonthSummary: _monthlySummary,
        );
        expect(tester.takeException(), isNull);
        expect(find.byKey(HistoryScreen.summaryCardKey), findsOneWidget);
      },
    );

    testWidgets('tapping a run card invokes onRunSelected', (tester) async {
      final calls = await _pumpHistory(tester, [_run1, _run2]);
      await tester.tap(find.byKey(HistoryScreen.runTileKey(_run1.runId)));
      await tester.pumpAndSettle();
      expect(calls.selected, contains(_run1.runId));
    });

    testWidgets('915x412 renders cleanly without overflow', (tester) async {
      await _pumpHistory(tester, [_run1, _run2], size: const Size(915, 412));
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(HistoryScreen.filterChipKey(HistoryRunFilter.allRuns)),
        findsOneWidget,
      );
    });

    testWidgets('640x360 renders cleanly without overflow', (tester) async {
      await _pumpHistory(tester, [_run1, _run2], size: const Size(640, 360));
      expect(tester.takeException(), isNull);
    });

    testWidgets('1.3x text scaling in landscape: zero overflow', (
      tester,
    ) async {
      await _pumpHistory(
        tester,
        [_run1, _run2],
        size: const Size(800, 360),
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('loading state renders skeleton in landscape', (tester) async {
      await _pumpHistory(tester, [], isLoading: true);
      expect(tester.takeException(), isNull);
      expect(find.byKey(HistoryScreen.loadingStateKey), findsOneWidget);
    });

    testWidgets('error state renders in landscape', (tester) async {
      await _pumpHistory(tester, [], hasError: true);
      expect(tester.takeException(), isNull);
      expect(find.text(AppStrings.historyErrorTitle), findsOneWidget);
    });

    testWidgets('empty state renders in landscape', (tester) async {
      await _pumpHistory(tester, []);
      expect(tester.takeException(), isNull);
      expect(find.text(AppStrings.historyEmptyTitle), findsOneWidget);
    });

    testWidgets('dark theme renders in landscape', (tester) async {
      await _pumpHistory(tester, [_run1], theme: AppTheme.dark());
      expect(tester.takeException(), isNull);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
        isNull, // Scaffold lets the theme background through for history
      );
    });

    // Portrait regression: same screen at 360x800 must still work.
    testWidgets('portrait 360x800 still works correctly', (tester) async {
      tester.view.devicePixelRatio = 3.0;
      tester.view.physicalSize = const Size(360, 800) * 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final calls = _HistCalls();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: HistoryScreen(
            runs: [_run1, _run2],
            onRunSelected: calls.selected.add,
            onBackToHome: () => calls.back++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(HistoryScreen.runTileKey(_run1.runId)), findsOneWidget);
    });
  });

  // ── Summary Landscape ──────────────────────────────────────────────────────
  group('Summary Landscape (Phase 4B.3B)', () {
    testWidgets(
      '800x360 route map is on the left, stats card is on the right',
      (tester) async {
        await _pumpSummary(tester, _summary);
        expect(tester.takeException(), isNull);

        final Rect route = tester.getRect(
          find.byKey(SummaryScreen.routeAreaKey),
        );
        final Rect stats = tester.getRect(
          find.byKey(SummaryScreen.statsCardKey),
        );

        // Map is to the left of the stats card.
        expect(route.left, lessThan(stats.left));
        // Map right edge does not reach the stats card left edge.
        expect(route.right, lessThanOrEqualTo(stats.left + 1));
      },
    );

    testWidgets('800x360 all four stat tiles are visible', (tester) async {
      await _pumpSummary(tester, _summary);
      expect(tester.takeException(), isNull);
      for (final stat in SummaryStat.values) {
        expect(find.byKey(SummaryScreen.statKey(stat)), findsOneWidget);
      }
    });

    testWidgets('800x360 splits card is visible in landscape', (tester) async {
      await _pumpSummary(tester, _summary);
      expect(tester.takeException(), isNull);
      expect(find.byKey(SummaryScreen.splitsCardKey), findsOneWidget);
    });

    testWidgets('tapping Home button invokes onBackToHome', (tester) async {
      final calls = await _pumpSummary(tester, _summary);
      await tester.ensureVisible(find.byKey(SummaryScreen.homeButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(SummaryScreen.homeButtonKey));
      expect(calls.home, 1);
    });

    testWidgets('tapping History button invokes onOpenHistory', (tester) async {
      final calls = await _pumpSummary(tester, _summary);
      await tester.ensureVisible(find.byKey(SummaryScreen.historyButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(SummaryScreen.historyButtonKey));
      expect(calls.history, 1);
    });

    testWidgets(
      'run with no GPS route shows no-route placeholder in landscape',
      (tester) async {
        await _pumpSummary(tester, _summaryNoRoute);
        expect(tester.takeException(), isNull);
        expect(find.text(AppStrings.routeTooShort), findsOneWidget);
      },
    );

    testWidgets('loading state renders skeletons in landscape', (tester) async {
      await _pumpSummary(tester, _summary, isLoading: true);
      expect(tester.takeException(), isNull);
      expect(find.byKey(SummaryScreen.loadingKey), findsOneWidget);
    });

    testWidgets('915x412 renders cleanly without overflow', (tester) async {
      await _pumpSummary(tester, _summary, size: const Size(915, 412));
      expect(tester.takeException(), isNull);
      expect(find.byKey(SummaryScreen.routeAreaKey), findsOneWidget);
    });

    testWidgets('640x360 renders cleanly without overflow', (tester) async {
      await _pumpSummary(tester, _summary, size: const Size(640, 360));
      expect(tester.takeException(), isNull);
    });

    testWidgets('1.3x text scaling in landscape: zero overflow', (
      tester,
    ) async {
      await _pumpSummary(
        tester,
        _summary,
        size: const Size(800, 360),
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('dark theme renders in landscape', (tester) async {
      await _pumpSummary(tester, _summary, theme: AppTheme.dark());
      expect(tester.takeException(), isNull);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
        AppPalette.dark.background,
      );
    });

    // Portrait regression: same screen at 360x800 must still work.
    testWidgets('portrait 360x800 still works correctly', (tester) async {
      tester.view.devicePixelRatio = 3.0;
      tester.view.physicalSize = const Size(360, 800) * 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final calls = _SumCalls();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: SummaryScreen(
            summary: _summary,
            onBackToHome: () => calls.home++,
            onOpenHistory: () => calls.history++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(SummaryScreen.statsCardKey), findsOneWidget);
      expect(find.byKey(SummaryScreen.routeAreaKey), findsOneWidget);
    });
  });
}
