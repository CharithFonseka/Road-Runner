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

class _Calls {
  final List<String> selected = [];
  int back = 0;
}

Future<_Calls> _pump(
  WidgetTester tester,
  List<HistoryRun> runs, {
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
        child: HistoryScreen(
          runs: runs,
          onRunSelected: calls.selected.add,
          onBackToHome: () => calls.back++,
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
  });

  group('Runs', () {
    testWidgets('one saved run shows date, distance, duration and pace', (
      tester,
    ) async {
      await _pump(tester, [_newest]);
      expect(find.text('Nov 14, 2026'), findsOneWidget);
      expect(find.text('7:42 AM'), findsOneWidget);
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
            AppStrings.historyDateTime('Nov 14, 2026', '7:42 AM'),
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
  });
}
