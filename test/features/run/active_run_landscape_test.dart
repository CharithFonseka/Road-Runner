// Road Runner — Active Run Landscape Layout widget tests (Phase 4B.1).
// Owner: Tharushi
// SRS reference: Section 4.2, 8.4, FR-20–23, NFR-09, NFR-14

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/bridge/tracking_bridge.dart';
import 'package:road_runner/core/contract/contract.dart';
import 'package:road_runner/core/theme/app_spacing.dart';
import 'package:road_runner/core/theme/app_theme.dart';
import 'package:road_runner/features/app_strings.dart';
import 'package:road_runner/features/run/active_run_screen.dart';
import 'package:road_runner/features/run/widgets/stop_run_dialog.dart';

import 'fake_tracking_bridge.dart';

class _TestCalls {
  final List<RunResult> results = [];
  int exits = 0;
}

Future<_TestCalls> _pumpScreen(
  WidgetTester tester,
  TrackingBridge bridge, {
  Size size = const Size(800, 360),
  double textScale = 1.0,
  bool dark = false,
}) async {
  tester.view.devicePixelRatio = 2.0;
  tester.view.physicalSize = size * 2.0;
  addTearDown(tester.view.reset);

  final _TestCalls calls = _TestCalls();
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: ActiveRunScreen(
          bridge: bridge,
          onRunFinished: calls.results.add,
          onExit: () => calls.exits++,
        ),
      ),
    ),
  );
  await tester.pump();
  return calls;
}

void main() {
  late FakeTrackingBridge bridge;

  setUp(() {
    bridge = FakeTrackingBridge();
  });

  tearDown(() {
    bridge.dispose();
  });

  group('ActiveRunScreen Landscape Layout (Phase 4B.1)', () {
    testWidgets(
      'renders responsive two-column layout on standard landscape (800x360)',
      (tester) async {
        await _pumpScreen(tester, bridge, size: const Size(800, 360));
        bridge.emitState(kStateRunning);
        bridge.emitSnapshot(
          movingMs: 145000,
          distanceM: 520,
          speedMps: 3.6,
          paceSecPerKm: 278,
        );
        await tester.pump();

        expect(tester.takeException(), isNull);

        // Verify all 4 live metrics exist with their exact keys.
        expect(find.byKey(ActiveRunScreen.movingTimeValueKey), findsOneWidget);
        expect(find.byKey(ActiveRunScreen.paceValueKey), findsOneWidget);
        expect(find.byKey(ActiveRunScreen.distanceValueKey), findsOneWidget);
        expect(find.byKey(ActiveRunScreen.speedValueKey), findsOneWidget);

        // Verify Pause and Stop controls are present and side-by-side.
        final Finder pauseFinder = find.byKey(
          ActiveRunScreen.pauseResumeButtonKey,
        );
        final Finder stopFinder = find.byKey(ActiveRunScreen.stopButtonKey);
        expect(pauseFinder, findsOneWidget);
        expect(stopFinder, findsOneWidget);

        final Rect pauseRect = tester.getRect(pauseFinder);
        final Rect stopRect = tester.getRect(stopFinder);

        // Buttons must be side by side (same vertical band, pause to the left of stop).
        expect(pauseRect.top, equals(stopRect.top));
        expect(pauseRect.right, lessThan(stopRect.left));

        // Controls must be compact: neither button stretches across the full screen width.
        expect(pauseRect.width, lessThan(350));
        expect(stopRect.width, lessThan(350));

        // Accessible touch target (>= 48dp).
        expect(
          pauseRect.height,
          greaterThanOrEqualTo(AppSpacing.minTouchTarget),
        );
        expect(
          stopRect.height,
          greaterThanOrEqualTo(AppSpacing.minTouchTarget),
        );
        expect(
          pauseRect.width,
          greaterThanOrEqualTo(AppSpacing.minTouchTarget),
        );
        expect(stopRect.width, greaterThanOrEqualTo(AppSpacing.minTouchTarget));
      },
    );

    testWidgets(
      'renders cleanly on large landscape (915x412) and compact landscape (640x360)',
      (tester) async {
        // Test compact landscape (640x360).
        await _pumpScreen(tester, bridge, size: const Size(640, 360));
        bridge.emitState(kStateRunning);
        bridge.emitSnapshot(
          movingMs: 60000,
          distanceM: 200,
          speedMps: 3.3,
          paceSecPerKm: 300,
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(
          find.byKey(ActiveRunScreen.pauseResumeButtonKey),
          findsOneWidget,
        );
        expect(find.byKey(ActiveRunScreen.stopButtonKey), findsOneWidget);

        // Test large flagship landscape (915x412).
        await _pumpScreen(tester, bridge, size: const Size(915, 412));
        bridge.emitSnapshot(
          movingMs: 120000,
          distanceM: 450,
          speedMps: 3.5,
          paceSecPerKm: 285,
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byKey(ActiveRunScreen.movingTimeValueKey), findsOneWidget);
      },
    );

    testWidgets(
      'handles 1.3x accessibility text scaling without RenderFlex overflow',
      (tester) async {
        await _pumpScreen(
          tester,
          bridge,
          size: const Size(800, 360),
          textScale: 1.3,
        );
        bridge.emitState(kStateRunning);
        bridge.emitGps(kGpsGood);
        bridge.emitSnapshot(
          movingMs: 3723000,
          distanceM: 12345,
          speedMps: 4.2,
          paceSecPerKm: 240,
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byKey(ActiveRunScreen.movingTimeValueKey), findsOneWidget);
        expect(
          find.byKey(ActiveRunScreen.pauseResumeButtonKey),
          findsOneWidget,
        );
        expect(find.byKey(ActiveRunScreen.stopButtonKey), findsOneWidget);
      },
    );

    testWidgets('renders properly in both Light and Dark modes in landscape', (
      tester,
    ) async {
      // Light Mode
      await _pumpScreen(
        tester,
        bridge,
        size: const Size(800, 360),
        dark: false,
      );
      bridge.emitState(kStateRunning);
      await tester.pump();
      expect(tester.takeException(), isNull);

      // Dark Mode
      await _pumpScreen(tester, bridge, size: const Size(800, 360), dark: true);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byKey(ActiveRunScreen.movingTimeValueKey), findsOneWidget);
    });

    testWidgets(
      'displays GPS states (searching, weak, good) in landscape header',
      (tester) async {
        await _pumpScreen(tester, bridge, size: const Size(800, 360));
        bridge.emitState(kStateRunning);

        // 1. GPS Searching
        bridge.emitGps(kGpsSearching);
        await tester.pump();
        expect(find.text(AppStrings.gpsSearching), findsOneWidget);
        // Map searching placeholder is visible when no fix yet.
        expect(
          find.byKey(const Key('activeRun.liveMap.placeholder')),
          findsOneWidget,
        );

        // 2. GPS Weak
        bridge.emitGps(kGpsWeak);
        await tester.pump();
        expect(find.text(AppStrings.gpsWeak), findsOneWidget);

        // 3. GPS Good
        bridge.emitGps(kGpsGood);
        await tester.pump();
        expect(find.text(AppStrings.gpsGood), findsOneWidget);
      },
    );

    testWidgets(
      'handles recording and paused states with PAUSED badge and button toggles',
      (tester) async {
        await _pumpScreen(tester, bridge, size: const Size(800, 360));

        // Initially running
        bridge.emitState(kStateRunning);
        bridge.emitSnapshot(movingMs: 45000);
        await tester.pump();

        expect(find.text(AppStrings.pauseRun), findsOneWidget);
        expect(find.text(AppStrings.stopRun), findsOneWidget);
        expect(find.text(AppStrings.pausedBadge), findsNothing);

        // Transition to paused
        bridge.emitState(kStatePaused);
        await tester.pump();

        expect(find.text(AppStrings.resumeRun), findsOneWidget);
        expect(find.text(AppStrings.pausedBadge), findsOneWidget);
      },
    );

    testWidgets(
      'Pause, Resume, and Stop controls invoke bridge callbacks and open confirmation',
      (tester) async {
        final _TestCalls calls = await _pumpScreen(
          tester,
          bridge,
          size: const Size(800, 360),
        );
        bridge.emitState(kStateRunning);
        await tester.pump();

        // Tap Pause
        await tester.tap(find.byKey(ActiveRunScreen.pauseResumeButtonKey));
        await tester.pump();
        expect(bridge.pauseCalls, equals(1));

        // Emulate paused state
        bridge.emitState(kStatePaused);
        await tester.pump();

        // Tap Resume
        await tester.tap(find.byKey(ActiveRunScreen.pauseResumeButtonKey));
        await tester.pump();
        expect(bridge.resumeCalls, equals(1));

        // Tap Stop -> Dialog appears
        await tester.tap(find.byKey(ActiveRunScreen.stopButtonKey));
        await tester.pumpAndSettle();

        expect(find.text(AppStrings.stopDialogTitle), findsOneWidget);
        expect(find.byKey(StopRunDialog.continueButtonKey), findsOneWidget);
        expect(find.byKey(StopRunDialog.finishButtonKey), findsOneWidget);

        // Dismiss dialog with Continue Running
        await tester.tap(find.byKey(StopRunDialog.continueButtonKey));
        await tester.pumpAndSettle();

        expect(bridge.stopCalls, equals(0));
        expect(calls.results, isEmpty);

        // Tap Stop again -> Confirm Finish Run
        await tester.tap(find.byKey(ActiveRunScreen.stopButtonKey));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(StopRunDialog.finishButtonKey));
        await tester.pumpAndSettle();

        expect(bridge.stopCalls, equals(1));
        expect(calls.results.length, equals(1));
      },
    );

    testWidgets(
      'StopRunDialog renders responsive side-by-side buttons in landscape',
      (tester) async {
        await _pumpScreen(tester, bridge, size: const Size(800, 360));
        bridge.emitState(kStateRunning);
        await tester.pump();

        await tester.tap(find.byKey(ActiveRunScreen.stopButtonKey));
        await tester.pumpAndSettle();

        final Rect continueRect = tester.getRect(
          find.byKey(StopRunDialog.continueButtonKey),
        );
        final Rect finishRect = tester.getRect(
          find.byKey(StopRunDialog.finishButtonKey),
        );

        // In landscape, buttons are arranged side by side in a Row.
        expect(continueRect.top, equals(finishRect.top));
        expect(continueRect.right, lessThan(finishRect.left));
        expect(
          continueRect.height,
          greaterThanOrEqualTo(AppSpacing.minTouchTarget),
        );
        expect(
          finishRect.height,
          greaterThanOrEqualTo(AppSpacing.minTouchTarget),
        );

        await tester.tap(find.byKey(StopRunDialog.continueButtonKey));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'preserves exact portrait layout when screen height > width (360x800)',
      (tester) async {
        await _pumpScreen(tester, bridge, size: const Size(360, 800));
        bridge.emitState(kStateRunning);
        bridge.emitSnapshot(
          movingMs: 30000,
          distanceM: 100,
          speedMps: 3.3,
          paceSecPerKm: 300,
        );
        await tester.pump();

        // In portrait, buttons are vertically stacked (pause top is less than stop top).
        final Rect pauseRect = tester.getRect(
          find.byKey(ActiveRunScreen.pauseResumeButtonKey),
        );
        final Rect stopRect = tester.getRect(
          find.byKey(ActiveRunScreen.stopButtonKey),
        );

        expect(pauseRect.bottom, lessThanOrEqualTo(stopRect.top));
        expect(pauseRect.height, greaterThanOrEqualTo(72));
        expect(stopRect.height, greaterThanOrEqualTo(72));
      },
    );
  });
}
