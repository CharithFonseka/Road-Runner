// Road Runner — Home screen widget tests.
// Owner: Tharushi
// SRS reference: Section 8.4, FR-71, NFR-09, NFR-14

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/core/theme/app_spacing.dart';
import 'package:road_runner/core/theme/app_theme.dart';
import 'package:road_runner/features/app_strings.dart';
import 'package:road_runner/features/home/home_screen.dart';
import 'package:road_runner/features/home/last_run_summary.dart';

/// Sample display values for tests only — not real application data.
const LastRunSummary _sampleRun = LastRunSummary(
  dateLabel: 'Test date',
  distance: '1.23 km',
  duration: '9:87',
  averagePace: '7:65/km',
);

class _Taps {
  int start = 0;
  int history = 0;
  int permissions = 0;
}

/// Pumps Home at a logical [size] (default 360 × 800dp, the UI kit frame).
Future<_Taps> _pumpHome(
  WidgetTester tester, {
  LastRunSummary? lastRun,
  Size size = const Size(360, 800),
  double textScale = 1.0,
}) async {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = size * 3.0;
  addTearDown(tester.view.reset);

  final _Taps taps = _Taps();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: HomeScreen(
          lastRun: lastRun,
          onStartRun: () => taps.start++,
          onOpenHistory: () => taps.history++,
          onOpenPermissions: () => taps.permissions++,
        ),
      ),
    ),
  );
  return taps;
}

void main() {
  group('Rendering', () {
    testWidgets('without last-run data shows the empty state', (tester) async {
      await _pumpHome(tester);

      expect(find.text(AppStrings.appName), findsOneWidget);
      expect(find.text(AppStrings.homeTagline), findsOneWidget);
      expect(find.text(AppStrings.startRun), findsOneWidget);
      expect(find.text(AppStrings.lastRunTitle), findsOneWidget);
      expect(find.text(AppStrings.noRunsTitle), findsOneWidget);
      expect(find.text(AppStrings.noRunsMessage), findsOneWidget);
      expect(find.text(AppStrings.historyTitle), findsOneWidget);
      expect(find.text(AppStrings.permissionsTitle), findsOneWidget);

      // No stat labels and no UI-kit sample numbers leak into the empty state.
      expect(find.text(AppStrings.statDistance), findsNothing);
      expect(find.text(AppStrings.statAveragePace), findsNothing);
      expect(find.text('5.02 km'), findsNothing);
    });

    testWidgets('with last-run data shows the supplied values', (tester) async {
      await _pumpHome(tester, lastRun: _sampleRun);

      expect(find.text('Test date'), findsOneWidget);
      expect(find.text('1.23 km'), findsOneWidget);
      expect(find.text('9:87'), findsOneWidget);
      expect(find.text('7:65/km'), findsOneWidget);
      expect(find.text(AppStrings.statDistance), findsOneWidget);
      expect(find.text(AppStrings.statDuration), findsOneWidget);
      expect(find.text(AppStrings.statAveragePace), findsOneWidget);
      expect(find.text(AppStrings.noRunsTitle), findsNothing);
    });
  });

  group('Callbacks', () {
    testWidgets('Start Run calls onStartRun only', (tester) async {
      final _Taps taps = await _pumpHome(tester);
      await tester.tap(find.byKey(HomeScreen.startRunButtonKey));
      await tester.pump();
      expect((taps.start, taps.history, taps.permissions), (1, 0, 0));
    });

    testWidgets('History row calls onOpenHistory only', (tester) async {
      final _Taps taps = await _pumpHome(tester);
      await tester.tap(find.text(AppStrings.historyTitle));
      await tester.pump();
      expect((taps.start, taps.history, taps.permissions), (0, 1, 0));
    });

    testWidgets('Permissions row calls onOpenPermissions only', (tester) async {
      final _Taps taps = await _pumpHome(tester);
      await tester.ensureVisible(find.text(AppStrings.permissionsTitle));
      await tester.tap(find.text(AppStrings.permissionsTitle));
      await tester.pump();
      expect((taps.start, taps.history, taps.permissions), (0, 0, 1));
    });
  });

  group('NFR-09: sizes and tap targets', () {
    testWidgets('Start Run is 64dp tall and full width', (tester) async {
      await _pumpHome(tester);
      final Size size = tester.getSize(
        find.byKey(HomeScreen.startRunButtonKey),
      );
      expect(size.height, AppSpacing.heroButtonHeight);
      expect(size.height, greaterThanOrEqualTo(AppSpacing.minTouchTarget));
      expect(size.width, 360 - 2 * AppSpacing.medium);
    });

    testWidgets('navigation rows are at least 48dp tall', (tester) async {
      await _pumpHome(tester);
      for (final String title in [
        AppStrings.historyTitle,
        AppStrings.permissionsTitle,
      ]) {
        final Size row = tester.getSize(
          find.ancestor(of: find.text(title), matching: find.byType(InkWell)),
        );
        expect(row.height, greaterThanOrEqualTo(AppSpacing.minTouchTarget));
      }
    });

    testWidgets('meets Android tap-target guideline', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pumpHome(tester, lastRun: _sampleRun);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });
  });

  group('Layout: no overflow', () {
    final Map<String, (Size, double)> cases = {
      '360x800 (UI kit frame)': (const Size(360, 800), 1.0),
      '320x568 (small phone)': (const Size(320, 568), 1.0),
      '360x800 at 1.5x text size': (const Size(360, 800), 1.5),
    };

    for (final MapEntry<String, (Size, double)> c in cases.entries) {
      for (final LastRunSummary? run in [null, _sampleRun]) {
        testWidgets('${c.key}, ${run == null ? 'empty' : 'with data'}', (
          tester,
        ) async {
          await _pumpHome(
            tester,
            lastRun: run,
            size: c.value.$1,
            textScale: c.value.$2,
          );
          // RenderFlex overflow errors are reported as exceptions in tests.
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('Semantics for screen readers', () {
    testWidgets('title is a header', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pumpHome(tester);
      expect(
        tester.getSemantics(find.text(AppStrings.appName)),
        containsSemantics(label: AppStrings.appName, isHeader: true),
      );
      handle.dispose();
    });

    testWidgets('Start Run is an enabled, tappable button', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pumpHome(tester);
      expect(
        tester.getSemantics(find.byKey(HomeScreen.startRunButtonKey)),
        containsSemantics(
          label: AppStrings.startRun,
          isButton: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('navigation rows are single buttons with title and subtitle', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pumpHome(tester);
      expect(
        tester.getSemantics(find.text(AppStrings.historyTitle)),
        containsSemantics(
          label: '${AppStrings.historyTitle}\n${AppStrings.historySubtitle}',
          isButton: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.text(AppStrings.permissionsTitle)),
        containsSemantics(
          label:
              '${AppStrings.permissionsTitle}\n'
              '${AppStrings.permissionsSubtitle}',
          isButton: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('last-run card is read as one item with values and labels', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pumpHome(tester, lastRun: _sampleRun);
      final String label = tester.getSemantics(find.text('1.23 km')).label;
      for (final String part in [
        AppStrings.lastRunTitle,
        'Test date',
        '1.23 km',
        AppStrings.statDistance,
        '9:87',
        AppStrings.statDuration,
        '7:65/km',
        AppStrings.statAveragePace,
      ]) {
        expect(label, contains(part));
      }
      handle.dispose();
    });

    testWidgets('every tappable element has a label', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pumpHome(tester, lastRun: _sampleRun);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });
}
