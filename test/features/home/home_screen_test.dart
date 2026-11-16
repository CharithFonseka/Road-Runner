// Road Runner — Home screen widget tests (UI kit Revision 5).
// Owner: Tharushi
// SRS reference: Section 8.4, FR-61, FR-71, NFR-09, NFR-14

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/core/theme/app_palette.dart';
import 'package:road_runner/core/theme/app_spacing.dart';
import 'package:road_runner/core/theme/app_theme.dart';
import 'package:road_runner/features/app_strings.dart';
import 'package:road_runner/features/history/history_run.dart';
import 'package:road_runner/features/home/home_screen.dart';
import 'package:road_runner/features/home/last_run_summary.dart';
import 'package:road_runner/features/home/widgets/recent_runs_card.dart';
import 'package:road_runner/features/home/widgets/sky_header.dart';
import 'package:road_runner/features/home/widgets/slide_to_start.dart';
import 'package:road_runner/features/shared/app_navigation_drawer.dart';

/// Test data only — not real application data.
final List<HistoryRun> _runs = [
  HistoryRun(
    runId: 'older',
    startedAt: DateTime(2026, 11, 8, 7),
    distanceM: 7100,
    movingMs: 2812000,
    averagePaceSecPerKm: 396,
  ),
  HistoryRun(
    runId: 'newest',
    startedAt: DateTime(2026, 11, 14, 6, 42),
    distanceM: 5020,
    movingMs: 1935000,
    averagePaceSecPerKm: 385,
  ),
  HistoryRun(
    runId: 'middle',
    startedAt: DateTime(2026, 11, 11, 18),
    distanceM: 3480,
    movingMs: 1265000,
    averagePaceSecPerKm: 363,
  ),
];

List<HistoryRun> _manyRuns(int n) => [
  for (int i = 0; i < n; i++)
    HistoryRun(
      runId: 'r$i',
      startedAt: DateTime(2026, 1, 1).add(Duration(days: i)),
      distanceM: 1000.0 + i,
      movingMs: 300000,
      averagePaceSecPerKm: 300,
    ),
];

class _Calls {
  int start = 0;
  int history = 0;
  int permissions = 0;
  int settings = 0;
  int retry = 0;
  final List<String> selected = [];
}

Future<_Calls> _pumpHome(
  WidgetTester tester, {
  List<HistoryRun> runs = const [],
  RecentRunsStatus status = RecentRunsStatus.ready,
  LastRunSummary? lastRun,
  bool withSettings = true,
  bool withRunSelected = true,
  bool withRetry = true,
  bool isStartingRun = false,
  bool startRunEnabled = true,
  bool reduceMotion = false,
  ThemeData? theme,
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
      theme: theme ?? AppTheme.light(),
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: HomeScreen(
          // ignore: deprecated_member_use_from_same_package
          lastRun: lastRun,
          recentRuns: runs,
          recentRunsStatus: status,
          onStartRun: () => c.start++,
          onOpenHistory: () => c.history++,
          onOpenPermissions: () => c.permissions++,
          onOpenSettings: withSettings ? () => c.settings++ : null,
          onRetry: withRetry ? () => c.retry++ : null,
          onRunSelected: withRunSelected ? c.selected.add : null,
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

/// Text inside run row [i].
Finder _inRow(int i, String text) => find.descendant(
  of: find.byKey(RecentRunsCard.rowKey(i)),
  matching: find.text(text),
);

void main() {
  group('Theme', () {
    testWidgets('dark Home uses the palette for sky, runs and Slide to Start', (
      tester,
    ) async {
      await _pumpHome(tester, theme: AppTheme.dark(), runs: _runs);
      final AppPalette palette = AppPalette.dark;

      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
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
      final CustomPaint landscape = tester.widget<CustomPaint>(
        find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint &&
              widget.painter is CompactLandscapePainter,
        ),
      );
      expect(
        (landscape.painter as CompactLandscapePainter).palette,
        same(palette),
      );
      expect(
        tester.widget<Text>(find.text(AppStrings.appName)).style!.color,
        palette.textPrimary,
      );
      expect(
        tester.widget<Text>(find.text('5.02 km')).style!.color,
        palette.stat,
      );

      final Material cardMaterial = tester.widget<Material>(
        find
            .descendant(
              of: find.byKey(HomeScreen.recentRunsKey),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(cardMaterial.color, palette.surface);

      final DecoratedBox track = tester.widget<DecoratedBox>(
        find.descendant(of: _slider, matching: find.byType(DecoratedBox)).first,
      );
      expect((track.decoration as BoxDecoration).color, palette.primaryFill);
    });

    for (final RecentRunsStatus status in RecentRunsStatus.values) {
      testWidgets('dark ${status.name} state fits compact large text', (
        tester,
      ) async {
        await _pumpHome(
          tester,
          theme: AppTheme.dark(),
          runs: status == RecentRunsStatus.ready ? _runs : const [],
          status: status,
          size: const Size(320, 568),
          textScale: 1.3,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Header', () {
    testWidgets('shows the name, tagline, menu and Settings buttons', (
      tester,
    ) async {
      await _pumpHome(tester);
      expect(find.text(AppStrings.appName), findsOneWidget);
      expect(find.text(AppStrings.homeTagline), findsOneWidget);
      expect(find.byKey(HomeScreen.menuButtonKey), findsOneWidget);
      expect(find.byKey(HomeScreen.settingsButtonKey), findsOneWidget);
      expect(find.byType(Image), findsNothing); // no image assets
    });

    testWidgets('Settings shortcut calls onOpenSettings only', (tester) async {
      final _Calls c = await _pumpHome(tester);
      await tester.tap(find.byKey(HomeScreen.settingsButtonKey));
      await tester.pump();
      expect((c.settings, c.permissions, c.history, c.start), (1, 0, 0, 0));
    });

    testWidgets('without onOpenSettings the shortcut opens Permissions', (
      tester,
    ) async {
      final _Calls c = await _pumpHome(tester, withSettings: false);
      await tester.tap(find.byKey(HomeScreen.settingsButtonKey));
      await tester.pump();
      expect((c.settings, c.permissions), (0, 1));
    });
  });

  group('Navigation drawer', () {
    testWidgets('menu opens the drawer with Home selected; close closes', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pumpHome(tester);
      expect(find.byType(AppNavigationDrawer), findsNothing);

      await tester.tap(find.byKey(HomeScreen.menuButtonKey));
      await tester.pumpAndSettle();
      expect(find.byType(AppNavigationDrawer), findsOneWidget);
      expect(
        tester
            .widget<AppNavigationDrawer>(find.byType(AppNavigationDrawer))
            .selected,
        AppDestination.home,
      );
      expect(
        tester.getSemantics(
          find.byKey(AppNavigationDrawer.destinationKey(AppDestination.home)),
        ),
        containsSemantics(isSelected: true),
      );

      await tester.tap(find.byKey(AppNavigationDrawer.closeButtonKey));
      await tester.pumpAndSettle();
      expect(find.byType(AppNavigationDrawer), findsNothing);
      handle.dispose();
    });

    testWidgets('Home entry only closes the drawer', (tester) async {
      final _Calls c = await _pumpHome(tester);
      await tester.tap(find.byKey(HomeScreen.menuButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(AppNavigationDrawer.destinationKey(AppDestination.home)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AppNavigationDrawer), findsNothing);
      expect((c.history, c.settings, c.permissions, c.start), (0, 0, 0, 0));
    });

    for (final (AppDestination d, String name) in [
      (AppDestination.history, 'History'),
      (AppDestination.settings, 'Settings'),
    ]) {
      testWidgets('$name entry closes the drawer and navigates once', (
        tester,
      ) async {
        final _Calls c = await _pumpHome(tester);
        await tester.tap(find.byKey(HomeScreen.menuButtonKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(AppNavigationDrawer.destinationKey(d)));
        await tester.pumpAndSettle();
        expect(find.byType(AppNavigationDrawer), findsNothing);
        expect(
          (c.history, c.settings),
          switch (d) {
            AppDestination.history => (1, 0),
            _ => (0, 1),
          },
        );
        expect(c.start, 0);
      });
    }

    testWidgets('drawer Settings falls back to onOpenPermissions', (
      tester,
    ) async {
      final _Calls c = await _pumpHome(tester, withSettings: false);
      await tester.tap(find.byKey(HomeScreen.menuButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(AppNavigationDrawer.destinationKey(AppDestination.settings)),
      );
      await tester.pumpAndSettle();
      expect(c.permissions, 1);
    });

    testWidgets('Back closes the open drawer first', (tester) async {
      await _pumpHome(tester);
      await tester.tap(find.byKey(HomeScreen.menuButtonKey));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AppNavigationDrawer), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  group('Recent runs: loaded', () {
    testWidgets('rows are newest first with formatted values', (tester) async {
      await _pumpHome(tester, runs: _runs);
      expect(find.text(AppStrings.recentRunsTitle), findsOneWidget);
      expect(_inRow(0, '14 Nov 2026'), findsOneWidget);
      expect(_inRow(1, '11 Nov 2026'), findsOneWidget);
      expect(_inRow(2, '08 Nov 2026'), findsOneWidget);
      expect(_inRow(0, '5.02 km'), findsOneWidget);
      expect(_inRow(0, '32:15'), findsOneWidget);
      expect(_inRow(0, '6:25/km'), findsOneWidget);
      expect(_inRow(0, AppStrings.statPace), findsOneWidget);
      expect(find.byKey(RecentRunsCard.viewAllKey), findsOneWidget);
    });

    testWidgets('tapping a row reports its run ID', (tester) async {
      final _Calls c = await _pumpHome(tester, runs: _runs);
      await tester.tap(find.byKey(RecentRunsCard.rowKey(1)));
      await tester.pump();
      expect(c.selected, ['middle']);
      expect((c.history, c.start), (0, 0));
    });

    testWidgets('without onRunSelected a row opens History', (tester) async {
      final _Calls c = await _pumpHome(
        tester,
        runs: _runs,
        withRunSelected: false,
      );
      await tester.tap(find.byKey(RecentRunsCard.rowKey(0)));
      await tester.pump();
      expect(c.history, 1);
    });

    testWidgets('View all opens History', (tester) async {
      final _Calls c = await _pumpHome(tester, runs: _runs);
      await tester.tap(find.byKey(RecentRunsCard.viewAllKey));
      await tester.pump();
      expect((c.history, c.start), (1, 0));
    });

    testWidgets('a row is read as one button with date and values', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pumpHome(tester, runs: _runs);
      expect(
        tester.getSemantics(find.byKey(RecentRunsCard.rowKey(0))),
        containsSemantics(
          label: AppStrings.recentRunSemantics(
            '14 Nov 2026',
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

    testWidgets('missing values show placeholders, never invented numbers', (
      tester,
    ) async {
      await _pumpHome(
        tester,
        runs: [HistoryRun(runId: 'x', startedAt: DateTime(2026, 11, 1))],
      );
      expect(_inRow(0, '-.-- km'), findsOneWidget);
      expect(_inRow(0, '--:--'), findsOneWidget);
      expect(_inRow(0, '--:--/km'), findsOneWidget);
    });

    testWidgets('legacy lastRun input still shows as a row', (tester) async {
      final _Calls c = await _pumpHome(
        tester,
        lastRun: const LastRunSummary(
          dateLabel: 'Test date',
          distance: '1.23 km',
          duration: '9:87',
          averagePace: '7:65/km',
        ),
      );
      expect(_inRow(0, 'Test date'), findsOneWidget);
      expect(_inRow(0, '7:65/km'), findsOneWidget);
      await tester.tap(find.byKey(RecentRunsCard.rowKey(0)));
      await tester.pump();
      expect(c.history, 1);
      expect(c.selected, isEmpty);
    });
  });

  group('Recent runs: other states', () {
    testWidgets('loading skeletons shimmer and are announced as loading', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pumpHome(tester, status: RecentRunsStatus.loading, runs: _runs);
      expect(find.byKey(RecentRunsCard.loadingKey), findsOneWidget);
      expect(find.byKey(RecentRunsCard.rowKey(0)), findsNothing);
      expect(find.text('5.02 km'), findsNothing); // nothing fabricated
      expect(
        tester.getSemantics(find.byKey(RecentRunsCard.loadingKey)),
        containsSemantics(label: AppStrings.recentRunsLoading),
      );
      expect(find.byType(ShaderMask), findsWidgets);
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.binding.hasScheduledFrame, isTrue);
      handle.dispose();
    });

    testWidgets('reduced motion keeps loading skeletons visible and static', (
      tester,
    ) async {
      await _pumpHome(
        tester,
        status: RecentRunsStatus.loading,
        reduceMotion: true,
      );
      expect(find.byKey(RecentRunsCard.loadingKey), findsOneWidget);
      expect(find.byType(ShaderMask), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(RecentRunsCard.loadingKey), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('empty shows the empty message and no View all', (
      tester,
    ) async {
      await _pumpHome(tester);
      expect(find.byKey(RecentRunsCard.emptyKey), findsOneWidget);
      expect(find.text(AppStrings.noRunsTitle), findsOneWidget);
      expect(find.text(AppStrings.recentRunsEmptyMessage), findsOneWidget);
      expect(find.byKey(RecentRunsCard.viewAllKey), findsNothing);
    });

    testWidgets('error shows the message and Try again calls onRetry', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final _Calls c = await _pumpHome(tester, status: RecentRunsStatus.error);
      expect(find.text(AppStrings.recentRunsErrorTitle), findsOneWidget);
      expect(find.text(AppStrings.recentRunsErrorMessage), findsOneWidget);
      expect(find.byKey(RecentRunsCard.viewAllKey), findsNothing);
      expect(
        tester.getSemantics(find.text(AppStrings.recentRunsErrorTitle)),
        containsSemantics(isLiveRegion: true),
      );
      await tester.tap(find.byKey(RecentRunsCard.retryKey));
      await tester.pump();
      expect((c.retry, c.start, c.history), (1, 0, 0));
      handle.dispose();
    });

    testWidgets('error without onRetry has no button', (tester) async {
      await _pumpHome(tester, status: RecentRunsStatus.error, withRetry: false);
      expect(find.byKey(RecentRunsCard.retryKey), findsNothing);
    });
  });

  group('Slide to Start on Home', () {
    testWidgets('sliding past 70% calls onStartRun once', (tester) async {
      final _Calls c = await _pumpHome(tester, runs: _runs);
      await tester.drag(_handle, const Offset(230, 0));
      await tester.pumpAndSettle();
      expect((c.start, c.history, c.permissions), (1, 0, 0));
      expect(find.text(AppStrings.slideStarting), findsOneWidget);
    });

    testWidgets('a tap does not start', (tester) async {
      final _Calls c = await _pumpHome(tester);
      await tester.tap(_slider);
      await tester.pump(const Duration(seconds: 2));
      expect(c.start, 0);
    });

    testWidgets('works while Recent runs is still loading', (tester) async {
      final _Calls c = await _pumpHome(
        tester,
        status: RecentRunsStatus.loading,
      );
      await tester.drag(_handle, const Offset(230, 0));
      await tester.pump(const Duration(milliseconds: 250));
      expect(c.start, 1);
    });

    testWidgets('isStartingRun shows Starting and blocks a new start', (
      tester,
    ) async {
      final _Calls c = await _pumpHome(tester, isStartingRun: true);
      expect(find.text(AppStrings.slideStarting), findsOneWidget);
      await tester.drag(_handle, const Offset(-230, 0));
      await tester.pumpAndSettle();
      expect(c.start, 0);
    });

    testWidgets('startRunEnabled false disables the control', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final _Calls c = await _pumpHome(tester, startRunEnabled: false);
      await tester.drag(_handle, const Offset(230, 0));
      await tester.pumpAndSettle();
      expect(c.start, 0);
      expect(
        tester.getSemantics(_slider),
        containsSemantics(isEnabled: false, hasTapAction: false),
      );
      handle.dispose();
    });

    testWidgets('stays fixed while the Recent runs list scrolls', (
      tester,
    ) async {
      await _pumpHome(tester, runs: _manyRuns(30));
      final Rect sliderBefore = tester.getRect(_slider);
      final Rect headerBefore = tester.getRect(find.text(AppStrings.appName));
      final Rect firstRow = tester.getRect(
        find.byKey(RecentRunsCard.rowKey(0)),
      );

      await tester.drag(
        find.byKey(RecentRunsCard.listKey),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();

      expect(tester.getRect(_slider), sliderBefore);
      expect(tester.getRect(find.text(AppStrings.appName)), headerBefore);
      // The list itself moved.
      final Finder row0 = find.byKey(RecentRunsCard.rowKey(0));
      expect(
        row0.evaluate().isEmpty || tester.getRect(row0).top < firstRow.top,
        isTrue,
      );
      // The list stays inside the card, above the slider.
      final Rect card = tester.getRect(find.byKey(HomeScreen.recentRunsKey));
      expect(card.bottom, lessThanOrEqualTo(sliderBefore.top));
    });
  });

  group('Layout', () {
    final Map<String, (Size, double)> sizes = {
      '360x800': (const Size(360, 800), 1.0),
      '320x568': (const Size(320, 568), 1.0),
      '412x915 (Galaxy A33)': (const Size(412, 915), 1.0),
      '360x800 at 1.3x text': (const Size(360, 800), 1.3),
      '320x568 at 1.3x text': (const Size(320, 568), 1.3),
      '412x915 at 1.3x text': (const Size(412, 915), 1.3),
      '800x360 (landscape)': (const Size(800, 360), 1.0),
    };
    for (final MapEntry<String, (Size, double)> e in sizes.entries) {
      for (final RecentRunsStatus status in RecentRunsStatus.values) {
        for (final bool withRuns in [false, true]) {
          if (status != RecentRunsStatus.ready && withRuns) continue;
          final String state = status == RecentRunsStatus.ready
              ? (withRuns ? 'loaded' : 'empty')
              : status.name;
          testWidgets('${e.key}, $state: no overflow; slider fixed at bottom', (
            tester,
          ) async {
            final Size size = e.value.$1;
            await _pumpHome(
              tester,
              runs: withRuns ? _manyRuns(10) : const [],
              status: status,
              size: size,
              textScale: e.value.$2,
            );
            expect(tester.takeException(), isNull);

            final Rect slider = tester.getRect(_slider);
            expect(slider.height, AppSpacing.heroButtonHeight);
            expect(slider.width, size.width - 2 * AppSpacing.medium);
            expect(
              slider.bottom,
              closeTo(size.height - AppSpacing.medium, 0.5),
            );
            final Rect card = tester.getRect(
              find.byKey(HomeScreen.recentRunsKey),
            );
            expect(card.height, greaterThan(0));
            expect(card.bottom, lessThanOrEqualTo(slider.top));
          });
        }
      }
    }

    testWidgets('A33 at 1x: the card gets most of the screen', (tester) async {
      await _pumpHome(tester, runs: _runs, size: const Size(412, 915));
      final Rect card = tester.getRect(find.byKey(HomeScreen.recentRunsKey));
      expect(card.height, greaterThan(915 * 0.5));
    });

    testWidgets('respects the status bar and Android navigation bar', (
      tester,
    ) async {
      const double statusBar = 32;
      const double navBar = 48;
      tester.view.padding = const FakeViewPadding(
        top: statusBar * 3,
        bottom: navBar * 3,
      );
      addTearDown(tester.view.resetPadding);
      await _pumpHome(tester, runs: _runs);
      expect(tester.takeException(), isNull);
      final Rect slider = tester.getRect(_slider);
      expect(slider.bottom, closeTo(800 - navBar - AppSpacing.medium, 0.5));
      expect(
        tester.getRect(find.byKey(HomeScreen.menuButtonKey)).top,
        greaterThanOrEqualTo(statusBar),
      );
    });
  });

  group('NFR-09 targets and screen readers', () {
    testWidgets('menu, Settings, View all and rows are at least 48dp', (
      tester,
    ) async {
      await _pumpHome(tester, runs: _runs);
      for (final Key key in [
        HomeScreen.menuButtonKey,
        HomeScreen.settingsButtonKey,
        RecentRunsCard.viewAllKey,
        RecentRunsCard.rowKey(0),
      ]) {
        final Size s = tester.getSize(find.byKey(key));
        expect(s.height, greaterThanOrEqualTo(48), reason: '$key');
        expect(s.width, greaterThanOrEqualTo(48), reason: '$key');
      }
    });

    testWidgets('Try again is at least 48dp', (tester) async {
      await _pumpHome(tester, status: RecentRunsStatus.error);
      expect(
        tester.getSize(find.byKey(RecentRunsCard.retryKey)).height,
        greaterThanOrEqualTo(48),
      );
    });

    for (final RecentRunsStatus status in RecentRunsStatus.values) {
      testWidgets('${status.name}: tap-target and label guidelines', (
        tester,
      ) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await _pumpHome(tester, runs: _runs, status: status);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });
    }

    testWidgets('header buttons, title and slider have spoken names', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pumpHome(tester, runs: _runs);
      expect(
        tester.getSemantics(find.text(AppStrings.appName)),
        containsSemantics(label: AppStrings.appName, isHeader: true),
      );
      expect(
        tester.getSemantics(find.text(AppStrings.recentRunsTitle)),
        containsSemantics(isHeader: true),
      );
      for (final (Key key, String name) in [
        (HomeScreen.menuButtonKey, AppStrings.homeOpenMenu),
        (HomeScreen.settingsButtonKey, AppStrings.homeSettings),
      ]) {
        expect(
          tester.getSemantics(find.byKey(key)),
          containsSemantics(tooltip: name, isButton: true, hasTapAction: true),
        );
      }
      expect(
        tester.getSemantics(_slider),
        containsSemantics(
          label: AppStrings.startRunSemanticsLabel,
          isButton: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });
  });
}
