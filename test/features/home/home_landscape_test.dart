// Road Runner — Home landscape orientation widget tests.
// Phase 4B.2: Home Landscape Layout verification.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/core/theme/app_palette.dart';
import 'package:road_runner/core/theme/app_spacing.dart';
import 'package:road_runner/core/theme/app_theme.dart';
import 'package:road_runner/features/app_strings.dart';
import 'package:road_runner/features/history/history_run.dart';
import 'package:road_runner/features/home/home_screen.dart';
import 'package:road_runner/features/home/widgets/recent_runs_card.dart';
import 'package:road_runner/features/home/widgets/sky_header.dart';
import 'package:road_runner/features/home/widgets/slide_to_start.dart';
import 'package:road_runner/features/shared/app_navigation_drawer.dart';

final List<HistoryRun> _testRuns = [
  HistoryRun(
    runId: 'run-3',
    startedAt: DateTime(2026, 11, 14, 6, 42),
    distanceM: 5020,
    movingMs: 1935000,
    averagePaceSecPerKm: 385,
  ),
  HistoryRun(
    runId: 'run-2',
    startedAt: DateTime(2026, 11, 11, 18),
    distanceM: 3480,
    movingMs: 1265000,
    averagePaceSecPerKm: 363,
  ),
  HistoryRun(
    runId: 'run-1',
    startedAt: DateTime(2026, 11, 8, 7),
    distanceM: 7100,
    movingMs: 2812000,
    averagePaceSecPerKm: 396,
  ),
];

class _TestCalls {
  int start = 0;
  int history = 0;
  int permissions = 0;
  int settings = 0;
  int retry = 0;
  final List<String> selected = [];
}

Future<_TestCalls> _pumpLandscapeHome(
  WidgetTester tester, {
  List<HistoryRun> runs = const [],
  RecentRunsStatus status = RecentRunsStatus.ready,
  Size size = const Size(800, 360),
  double textScale = 1.0,
  ThemeData? theme,
  bool isStartingRun = false,
  bool startRunEnabled = true,
  FakeViewPadding? padding,
}) async {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = size * 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  if (padding != null) {
    tester.view.padding = padding;
    addTearDown(tester.view.resetPadding);
  }

  final _TestCalls c = _TestCalls();
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light(),
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: HomeScreen(
          recentRuns: runs,
          recentRunsStatus: status,
          onStartRun: () => c.start++,
          onOpenHistory: () => c.history++,
          onOpenPermissions: () => c.permissions++,
          onOpenSettings: () => c.settings++,
          onRetry: () => c.retry++,
          onRunSelected: c.selected.add,
          isStartingRun: isStartingRun,
          startRunEnabled: startRunEnabled,
        ),
      ),
    ),
  );
  return c;
}

Finder get _slider => find.byKey(HomeScreen.startRunButtonKey);
Finder get _handle => find.byKey(SlideToStart.handleKey);
Finder get _card => find.byKey(HomeScreen.recentRunsKey);

void main() {
  group('Home Landscape — Viewports & Two-Column Layout', () {
    testWidgets(
      '800x360 landscape uses 2 columns and constrains slider to <= 340dp',
      (tester) async {
        await _pumpLandscapeHome(
          tester,
          runs: _testRuns,
          size: const Size(800, 360),
        );
        expect(tester.takeException(), isNull);

        final Rect slider = tester.getRect(_slider);
        final Rect card = tester.getRect(_card);

        // Slider must not stretch across the wide landscape screen.
        expect(
          slider.width,
          lessThanOrEqualTo(HomeScreen.maxLandscapeSliderWidth),
        );
        expect(slider.width, closeTo(308.0, 1.0)); // 340 - 2 * 16

        // Recent runs card must sit to the right of the slider (2-column layout).
        expect(card.left, greaterThan(slider.right));

        // Recent runs card gets generous vertical height in landscape (over 250dp).
        expect(card.height, greaterThan(250));

        // Slider is anchored at the bottom.
        expect(slider.bottom, closeTo(360 - AppSpacing.medium, 1.0));
      },
    );

    testWidgets(
      '915x412 (Samsung Galaxy A33 5G) landscape uses 2 columns without stretching',
      (tester) async {
        await _pumpLandscapeHome(
          tester,
          runs: _testRuns,
          size: const Size(915, 412),
        );
        expect(tester.takeException(), isNull);

        final Rect slider = tester.getRect(_slider);
        final Rect card = tester.getRect(_card);

        expect(
          slider.width,
          lessThanOrEqualTo(HomeScreen.maxLandscapeSliderWidth),
        );
        expect(card.left, greaterThan(slider.right));
        expect(card.width, greaterThan(500));
        expect(card.height, greaterThan(300));
      },
    );

    testWidgets('640x360 compact landscape adapts columns gracefully', (
      tester,
    ) async {
      await _pumpLandscapeHome(
        tester,
        runs: _testRuns,
        size: const Size(640, 360),
      );
      expect(tester.takeException(), isNull);

      final Rect slider = tester.getRect(_slider);
      final Rect card = tester.getRect(_card);

      expect(
        slider.width,
        lessThanOrEqualTo(HomeScreen.maxLandscapeSliderWidth),
      );
      expect(card.left, greaterThan(slider.right));
      expect(card.width, greaterThan(300));
    });

    testWidgets('360x800 portrait baseline preserves single-column layout', (
      tester,
    ) async {
      await _pumpLandscapeHome(
        tester,
        runs: _testRuns,
        size: const Size(360, 800),
      );
      expect(tester.takeException(), isNull);

      final Rect slider = tester.getRect(_slider);
      final Rect card = tester.getRect(_card);

      // In portrait: full width slider (360 - 32 = 328).
      expect(slider.width, closeTo(328.0, 0.5));
      // In portrait: card sits above the slider.
      expect(card.bottom, lessThanOrEqualTo(slider.top));
    });
  });

  group('Home Landscape — Text Scaling (1.3x)', () {
    for (final Size size in [
      const Size(800, 360),
      const Size(915, 412),
      const Size(640, 360),
    ]) {
      testWidgets(
        '${size.width.toInt()}x${size.height.toInt()} at 1.3x text scale: zero overflow',
        (tester) async {
          await _pumpLandscapeHome(
            tester,
            runs: _testRuns,
            size: size,
            textScale: 1.3,
          );
          expect(tester.takeException(), isNull);

          final Rect slider = tester.getRect(_slider);
          expect(
            slider.width,
            lessThanOrEqualTo(HomeScreen.maxLandscapeSliderWidth),
          );
        },
      );
    }
  });

  group('Home Landscape — Themes', () {
    testWidgets('light mode uses light palette in landscape', (tester) async {
      await _pumpLandscapeHome(
        tester,
        theme: AppTheme.light(),
        runs: _testRuns,
        size: const Size(800, 360),
      );
      final AppPalette palette = AppPalette.light;

      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        palette.background,
      );
      final DecoratedBox header = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(CompactSkyHeader),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(
        (header.decoration as BoxDecoration).gradient,
        palette.skyGradient,
      );
    });

    testWidgets('dark mode uses dark palette in landscape', (tester) async {
      await _pumpLandscapeHome(
        tester,
        theme: AppTheme.dark(),
        runs: _testRuns,
        size: const Size(800, 360),
      );
      final AppPalette palette = AppPalette.dark;

      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        palette.background,
      );
      final DecoratedBox header = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(CompactSkyHeader),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(
        (header.decoration as BoxDecoration).gradient,
        palette.skyGradient,
      );
    });
  });

  group('Home Landscape — Slide to Start Gestures & Ergonomics', () {
    testWidgets('dragging past 70% of constrained travel starts run', (
      tester,
    ) async {
      final _TestCalls c = await _pumpLandscapeHome(
        tester,
        runs: _testRuns,
        size: const Size(800, 360),
      );

      final Rect slider = tester.getRect(_slider);
      final double travel =
          slider.width - SlideToStart.handleSize - 2 * SlideToStart.inset;
      // Ergonomic travel distance check (~236dp instead of 728dp!).
      expect(travel, lessThanOrEqualTo(268.0));

      await tester.drag(_handle, Offset(travel * 0.78, 0));
      await tester.pumpAndSettle();

      expect(c.start, 1);
      expect(find.text(AppStrings.slideStarting), findsOneWidget);
    });

    testWidgets('dragging below 70% snaps back without starting', (
      tester,
    ) async {
      final _TestCalls c = await _pumpLandscapeHome(
        tester,
        runs: _testRuns,
        size: const Size(800, 360),
      );

      final Rect slider = tester.getRect(_slider);
      final double travel =
          slider.width - SlideToStart.handleSize - 2 * SlideToStart.inset;

      await tester.drag(_handle, Offset(travel * 0.5, 0));
      await tester.pumpAndSettle();

      expect(c.start, 0);
      expect(find.text(AppStrings.slideStarting), findsNothing);
    });

    testWidgets('1s press and hold starts run in landscape', (tester) async {
      final _TestCalls c = await _pumpLandscapeHome(
        tester,
        runs: _testRuns,
        size: const Size(800, 360),
      );

      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(_slider),
      );
      await tester.pump(); // first frame starts the hold timer
      await tester.pump(const Duration(milliseconds: 500));
      expect(c.start, 0);

      await tester.pump(const Duration(milliseconds: 600));
      expect(c.start, 1);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('accessible activation starts run in landscape', (
      tester,
    ) async {
      final _TestCalls c = await _pumpLandscapeHome(
        tester,
        runs: _testRuns,
        size: const Size(800, 360),
      );

      final SemanticsNode node = tester.getSemantics(_slider);
      tester.binding.pipelineOwner.semanticsOwner!.performAction(
        node.id,
        SemanticsAction.tap,
      );
      await tester.pumpAndSettle();

      expect(c.start, 1);
    });

    testWidgets('disabled slider ignores input in landscape', (tester) async {
      final _TestCalls c = await _pumpLandscapeHome(
        tester,
        runs: _testRuns,
        size: const Size(800, 360),
        startRunEnabled: false,
      );

      await tester.drag(_handle, const Offset(200, 0));
      await tester.pumpAndSettle();

      expect(c.start, 0);
    });
  });

  group('Home Landscape — Recent Runs States', () {
    testWidgets('populated state shows runs and clicking a row reports runId', (
      tester,
    ) async {
      final _TestCalls c = await _pumpLandscapeHome(
        tester,
        runs: _testRuns,
        size: const Size(800, 360),
      );

      expect(find.text(AppStrings.recentRunsTitle), findsOneWidget);
      expect(find.text('5.02 km'), findsOneWidget);
      expect(find.text('3.48 km'), findsOneWidget);

      await tester.tap(find.byKey(RecentRunsCard.rowKey(0)));
      await tester.pump();
      expect(c.selected, ['run-3']);
    });

    testWidgets('View all opens history in landscape', (tester) async {
      final _TestCalls c = await _pumpLandscapeHome(
        tester,
        runs: _testRuns,
        size: const Size(800, 360),
      );

      await tester.tap(find.byKey(RecentRunsCard.viewAllKey));
      await tester.pump();
      expect(c.history, 1);
    });

    testWidgets('empty state displays in landscape', (tester) async {
      await _pumpLandscapeHome(
        tester,
        runs: const [],
        size: const Size(800, 360),
      );

      expect(find.byKey(RecentRunsCard.emptyKey), findsOneWidget);
      expect(find.text(AppStrings.noRunsTitle), findsOneWidget);
    });

    testWidgets('loading state displays shimmer skeleton in landscape', (
      tester,
    ) async {
      await _pumpLandscapeHome(
        tester,
        status: RecentRunsStatus.loading,
        size: const Size(800, 360),
      );

      expect(find.byKey(RecentRunsCard.loadingKey), findsOneWidget);
    });

    testWidgets('error state displays error message and Try again button', (
      tester,
    ) async {
      final _TestCalls c = await _pumpLandscapeHome(
        tester,
        status: RecentRunsStatus.error,
        size: const Size(800, 360),
      );

      expect(find.byKey(RecentRunsCard.errorKey), findsOneWidget);
      await tester.tap(find.byKey(RecentRunsCard.retryKey));
      await tester.pump();
      expect(c.retry, 1);
    });
  });

  group('Home Landscape — Header Controls & Insets', () {
    testWidgets('menu button opens navigation drawer in landscape', (
      tester,
    ) async {
      await _pumpLandscapeHome(tester, size: const Size(800, 360));
      expect(find.byType(AppNavigationDrawer), findsNothing);

      await tester.tap(find.byKey(HomeScreen.menuButtonKey));
      await tester.pumpAndSettle();

      expect(find.byType(AppNavigationDrawer), findsOneWidget);
    });

    testWidgets('settings button invokes onOpenSettings in landscape', (
      tester,
    ) async {
      final _TestCalls c = await _pumpLandscapeHome(
        tester,
        size: const Size(800, 360),
      );

      await tester.tap(find.byKey(HomeScreen.settingsButtonKey));
      await tester.pump();

      expect(c.settings, 1);
    });

    testWidgets(
      'respects horizontal cutouts and bottom navigation bar insets',
      (tester) async {
        const double leftNotch = 28;
        const double rightNav = 40;
        const double bottomNav = 24;

        await _pumpLandscapeHome(
          tester,
          runs: _testRuns,
          size: const Size(800, 360),
          padding: const FakeViewPadding(
            left: leftNotch * 3,
            right: rightNav * 3,
            bottom: bottomNav * 3,
          ),
        );
        expect(tester.takeException(), isNull);

        final Rect slider = tester.getRect(_slider);
        final Rect card = tester.getRect(_card);

        // Slider is inset past the left camera notch.
        expect(slider.left, greaterThanOrEqualTo(leftNotch));

        // Slider and card are padded above the bottom navigation bar.
        expect(
          slider.bottom,
          closeTo(360 - bottomNav - AppSpacing.medium, 1.0),
        );
        expect(card.bottom, closeTo(360 - bottomNav - AppSpacing.medium, 1.0));

        // Card is inset from the right navigation bar.
        expect(card.right, lessThanOrEqualTo(800 - rightNav));
      },
    );
  });
}
