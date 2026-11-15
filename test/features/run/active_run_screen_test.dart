// Road Runner — Active Run / Paused Run / Stop Confirmation widget tests.
// Owner: Tharushi
// SRS reference: Section 4.2, 8.4, FR-20–23, NFR-09, NFR-14

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/bridge/mock_tracking_bridge.dart';
import 'package:road_runner/bridge/tracking_bridge.dart';
import 'package:road_runner/core/contract/contract.dart';
import 'package:road_runner/core/theme/app_spacing.dart';
import 'package:road_runner/core/theme/app_text_styles.dart';
import 'package:road_runner/core/theme/app_theme.dart';
import 'package:road_runner/features/app_strings.dart';
import 'package:road_runner/features/run/active_run_screen.dart';
import 'package:road_runner/features/run/widgets/stop_run_dialog.dart';

import 'fake_tracking_bridge.dart';

class _Calls {
  final List<RunResult> results = [];
  int exits = 0;
}

Future<_Calls> _pump(
  WidgetTester tester,
  TrackingBridge bridge, {
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

String _text(WidgetTester tester, Key key) {
  final RichText rich = tester.widget<RichText>(
    find.descendant(of: find.byKey(key), matching: find.byType(RichText)),
  );
  return rich.text.toPlainText();
}

/// Font size of the value (first span) inside the stat [key].
double _valueFontSize(WidgetTester tester, Key key) {
  final RichText rich = tester.widget<RichText>(
    find.descendant(of: find.byKey(key), matching: find.byType(RichText)),
  );
  double? size;
  rich.text.visitChildren((span) {
    if (span is TextSpan && span.text != null) {
      size = span.style?.fontSize;
      return false;
    }
    return true;
  });
  return size!;
}

const List<Key> _statKeys = [
  ActiveRunScreen.elapsedValueKey,
  ActiveRunScreen.paceValueKey,
  ActiveRunScreen.distanceValueKey,
  ActiveRunScreen.speedValueKey,
];

Future<void> _back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

void main() {
  late FakeTrackingBridge bridge;

  setUp(() => bridge = FakeTrackingBridge());
  tearDown(() => bridge.close());

  group('Rendering', () {
    testWidgets('before any snapshot shows placeholders, not numbers', (
      tester,
    ) async {
      await _pump(tester, bridge);
      expect(find.text(AppStrings.statElapsedTime), findsOneWidget);
      expect(find.text(AppStrings.statAveragePaceLong), findsOneWidget);
      expect(find.text(AppStrings.statDistance), findsOneWidget);
      expect(find.text(AppStrings.statSpeed), findsOneWidget);
      expect(_text(tester, ActiveRunScreen.elapsedValueKey), '--:--');
      expect(_text(tester, ActiveRunScreen.paceValueKey), '--:-- /km');
      expect(_text(tester, ActiveRunScreen.distanceValueKey), '-.-- km');
      expect(_text(tester, ActiveRunScreen.speedValueKey), '--.- km/h');
      expect(find.text(AppStrings.runStatusLive), findsOneWidget);
    });

    testWidgets('shows bridge values formatted for display', (tester) async {
      await _pump(tester, bridge);
      bridge.emitSnapshot(
        elapsedMs: (18 * 60 + 42) * 1000,
        movingMs: 1,
        distanceM: 3420,
        speedMps: 3.0,
        paceSecPerKm: 327,
      );
      await tester.pump();
      expect(_text(tester, ActiveRunScreen.elapsedValueKey), '18:42');
      expect(_text(tester, ActiveRunScreen.paceValueKey), '5:27 /km');
      expect(_text(tester, ActiveRunScreen.distanceValueKey), '3.42 km');
      expect(_text(tester, ActiveRunScreen.speedValueKey), '10.8 km/h');
    });

    testWidgets('unavailable pace shows --:--', (tester) async {
      await _pump(tester, bridge);
      bridge.emitSnapshot(elapsedMs: 5000, distanceM: 20);
      await tester.pump();
      expect(_text(tester, ActiveRunScreen.paceValueKey), '--:-- /km');
    });

    testWidgets('GPS badge shows Searching, Weak and Good with icons', (
      tester,
    ) async {
      await _pump(tester, bridge);
      expect(find.text(AppStrings.gpsSearching), findsNothing);

      final Map<String, (String, IconData)> cases = {
        kGpsSearching: (AppStrings.gpsSearching, Icons.gps_not_fixed),
        kGpsWeak: (AppStrings.gpsWeak, Icons.warning_amber_rounded),
        kGpsGood: (AppStrings.gpsGood, Icons.gps_fixed),
      };
      for (final MapEntry<String, (String, IconData)> c in cases.entries) {
        bridge.emitGps(c.key);
        await tester.pump();
        expect(find.text(c.value.$1), findsOneWidget);
        expect(find.byIcon(c.value.$2), findsOneWidget);
      }
    });
  });

  group('Pause and resume', () {
    testWidgets('pause shows PAUSED, Resume, and keeps the last values', (
      tester,
    ) async {
      await _pump(tester, bridge);
      bridge.emitSnapshot(elapsedMs: 61000, distanceM: 500, speedMps: 2.5);
      await tester.pump();

      await tester.tap(find.byKey(ActiveRunScreen.pauseResumeButtonKey));
      await tester.pump();

      expect(bridge.pauseCalls, 1);
      expect(find.text(AppStrings.pausedBadge), findsOneWidget);
      expect(find.text(AppStrings.runStatusPaused), findsOneWidget);
      expect(find.text(AppStrings.resumeRun), findsOneWidget);
      expect(_text(tester, ActiveRunScreen.elapsedValueKey), '1:01');
      expect(_text(tester, ActiveRunScreen.distanceValueKey), '0.50 km');
      expect(_text(tester, ActiveRunScreen.speedValueKey), '9.0 km/h');

      await tester.tap(find.byKey(ActiveRunScreen.pauseResumeButtonKey));
      await tester.pump();
      expect(bridge.resumeCalls, 1);
      expect(find.text(AppStrings.pausedBadge), findsNothing);
      expect(find.text(AppStrings.pauseRun), findsOneWidget);
    });

    testWidgets('pause failure shows a message with Try Again', (tester) async {
      await _pump(tester, bridge);
      bridge.pauseError = platformError(kErrorServiceFailed);
      await tester.tap(find.byKey(ActiveRunScreen.pauseResumeButtonKey));
      await tester.pump();
      expect(find.text(AppStrings.errorPauseFailed), findsOneWidget);
      expect(find.text(AppStrings.pauseRun), findsOneWidget);

      bridge.pauseError = null;
      await tester.tap(find.byKey(ActiveRunScreen.issueRetryButtonKey));
      await tester.pump();
      expect(bridge.pauseCalls, 2);
      expect(find.text(AppStrings.errorPauseFailed), findsNothing);
      expect(find.text(AppStrings.pausedBadge), findsOneWidget);
    });
  });

  group('Stop confirmation', () {
    testWidgets('Continue Running closes the dialog without stopping', (
      tester,
    ) async {
      final _Calls calls = await _pump(tester, bridge);
      await tester.tap(find.byKey(ActiveRunScreen.stopButtonKey));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.stopDialogTitle), findsOneWidget);
      expect(find.text(AppStrings.finishRun), findsOneWidget);
      expect(find.text(AppStrings.continueRunning), findsOneWidget);

      await tester.tap(find.byKey(StopRunDialog.continueButtonKey));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.stopDialogTitle), findsNothing);
      expect(bridge.stopCalls, 0);
      expect(calls.results, isEmpty);
    });

    testWidgets('Finish Run stops and passes the real RunResult', (
      tester,
    ) async {
      final _Calls calls = await _pump(tester, bridge);
      await tester.tap(find.byKey(ActiveRunScreen.stopButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(StopRunDialog.finishButtonKey));
      await tester.pumpAndSettle();

      expect(bridge.stopCalls, 1);
      expect(calls.results, [same(bridge.stopResult)]);
      expect(find.text(AppStrings.runStatusFinishing), findsOneWidget);
    });

    testWidgets('stop failure keeps the run and allows retry', (tester) async {
      final _Calls calls = await _pump(tester, bridge);
      bridge.stopError = platformError(kErrorServiceFailed);
      await tester.tap(find.byKey(ActiveRunScreen.stopButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(StopRunDialog.finishButtonKey));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.errorStopFailed), findsOneWidget);
      expect(find.text(AppStrings.runStatusLive), findsOneWidget);
      expect(calls.results, isEmpty);

      bridge.stopError = null;
      await tester.tap(find.byKey(ActiveRunScreen.issueRetryButtonKey));
      await tester.pumpAndSettle();
      expect(bridge.stopCalls, 2);
      expect(calls.results, hasLength(1));
    });

    testWidgets('double tap on Stop opens only one dialog', (tester) async {
      await _pump(tester, bridge);
      await tester.tap(find.byKey(ActiveRunScreen.stopButtonKey));
      await tester.tap(
        find.byKey(ActiveRunScreen.stopButtonKey),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(find.byType(StopRunDialog), findsOneWidget);
    });
  });

  group('Android Back', () {
    testWidgets('while running opens the confirmation, never exits', (
      tester,
    ) async {
      final _Calls calls = await _pump(tester, bridge);
      await _back(tester);
      expect(find.byType(StopRunDialog), findsOneWidget);
      expect(find.byType(ActiveRunScreen), findsOneWidget);
      expect(calls.exits, 0);

      // Back on the dialog = Continue Running.
      await _back(tester);
      expect(find.byType(StopRunDialog), findsNothing);
      expect(bridge.stopCalls, 0);
    });

    testWidgets('after a failed start calls onExit', (tester) async {
      bridge.startError = platformError(kErrorPermissionDenied);
      final _Calls calls = await _pump(tester, bridge);
      await _back(tester);
      expect(calls.exits, 1);
    });
  });

  group('Stop from outside while the dialog is open', () {
    Future<void> openDialog(WidgetTester tester) async {
      await tester.tap(find.byKey(ActiveRunScreen.stopButtonKey));
      await tester.pumpAndSettle();
      expect(find.byType(StopRunDialog), findsOneWidget);
    }

    testWidgets('closes the dialog and shows Run stopped, no stopRun', (
      tester,
    ) async {
      final _Calls calls = await _pump(tester, bridge);
      await openDialog(tester);

      bridge.stopFromNotification();
      await tester.pumpAndSettle();

      expect(find.byType(StopRunDialog), findsNothing);
      expect(find.text(AppStrings.stoppedUnresolvedTitle), findsOneWidget);
      expect(bridge.stopCalls, 0);
      expect(calls.results, isEmpty);
    });

    testWidgets('passes on only a result the bridge reports', (tester) async {
      bridge.statusAfterStop = const TrackingStatus(
        state: kStateStopped,
        runId: 'test-run',
        filePath: '/bridge/runs/test-run.jsonl',
      );
      final _Calls calls = await _pump(tester, bridge);
      await openDialog(tester);

      bridge.stopFromNotification();
      await tester.pumpAndSettle();

      expect(find.byType(StopRunDialog), findsNothing);
      expect(bridge.stopCalls, 0);
      expect(calls.results, hasLength(1));
      expect(calls.results.single.runId, 'test-run');
      expect(calls.results.single.filePath, '/bridge/runs/test-run.jsonl');
    });

    testWidgets('a Finish tap racing the stop event does not call stopRun', (
      tester,
    ) async {
      final _Calls calls = await _pump(tester, bridge);
      await openDialog(tester);

      // Press Finish and receive the stop in the same synchronous turn, so
      // the dialog's "true" answer is still in flight when the run ends.
      tester
          .widget<ButtonStyleButton>(find.byKey(StopRunDialog.finishButtonKey))
          .onPressed!();
      bridge.stopFromNotification();
      await tester.pumpAndSettle();

      expect(find.byType(StopRunDialog), findsNothing);
      expect(bridge.stopCalls, 0);
      expect(calls.results, isEmpty);
      expect(find.text(AppStrings.stoppedUnresolvedTitle), findsOneWidget);
    });

    testWidgets('Back after the stop exits instead of reopening', (
      tester,
    ) async {
      final _Calls calls = await _pump(tester, bridge);
      await openDialog(tester);
      bridge.stopFromNotification();
      await tester.pumpAndSettle();

      await _back(tester);
      expect(find.byType(StopRunDialog), findsNothing);
      expect(calls.exits, 1);
      expect(bridge.stopCalls, 0);
    });
  });

  group('Errors', () {
    testWidgets('start failure offers Try Again and Exit', (tester) async {
      bridge.startError = platformError(kErrorLocationOff);
      final _Calls calls = await _pump(tester, bridge);

      expect(find.text(AppStrings.startFailedTitle), findsOneWidget);
      expect(find.text(AppStrings.errorLocationOff), findsOneWidget);

      bridge.startError = null;
      await tester.tap(find.byKey(ActiveRunScreen.tryAgainButtonKey));
      await tester.pump();
      expect(bridge.startCalls, 2);
      expect(find.text(AppStrings.runStatusLive), findsOneWidget);
      expect(calls.exits, 0);
    });

    testWidgets('Exit after start failure calls onExit', (tester) async {
      bridge.startError = platformError(kErrorServiceFailed);
      final _Calls calls = await _pump(tester, bridge);
      expect(find.text(AppStrings.errorServiceFailed), findsOneWidget);
      await tester.tap(find.byKey(ActiveRunScreen.exitButtonKey));
      expect(calls.exits, 1);
    });

    testWidgets('notification stop without a result shows Run stopped', (
      tester,
    ) async {
      final _Calls calls = await _pump(tester, bridge);
      bridge.stopFromNotification();
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.stoppedUnresolvedTitle), findsOneWidget);
      expect(calls.results, isEmpty);
      await tester.tap(find.byKey(ActiveRunScreen.exitButtonKey));
      expect(calls.exits, 1);
    });
  });

  testWidgets('removing the screen never stops or disposes the bridge', (
    tester,
  ) async {
    await _pump(tester, bridge);
    expect(bridge.hasListener, isTrue);
    await tester.pumpWidget(const SizedBox());
    expect(bridge.hasListener, isFalse);
    expect(bridge.stopCalls, 0);
    expect(bridge.disposeCalls, 0);
  });

  group('NFR-09: sizes and tap targets', () {
    testWidgets('all four live statistics are at least 32sp', (tester) async {
      await _pump(tester, bridge, size: const Size(320, 568), textScale: 1.3);
      bridge.emitSnapshot(
        elapsedMs: 3723000,
        distanceM: 12345,
        speedMps: 4,
        paceSecPerKm: 333,
      );
      await tester.pump();
      for (final Key key in _statKeys) {
        expect(
          _valueFontSize(tester, key),
          greaterThanOrEqualTo(AppTextStyles.minStatFontSize),
          reason: '$key',
        );
      }
    });

    testWidgets('Pause and Stop are large (at least 72dp tall)', (
      tester,
    ) async {
      await _pump(tester, bridge, size: const Size(320, 568));
      for (final Key key in [
        ActiveRunScreen.pauseResumeButtonKey,
        ActiveRunScreen.stopButtonKey,
      ]) {
        final Size s = tester.getSize(find.byKey(key));
        expect(s.height, greaterThanOrEqualTo(72));
        expect(s.width, greaterThanOrEqualTo(AppSpacing.minTouchTarget));
      }
    });

    testWidgets('on a tall screen the buttons fill the space below the card', (
      tester,
    ) async {
      // A tall phone (about Galaxy A33 size) with a 24dp gesture-bar inset.
      const Size screen = Size(412, 915);
      const double bottomInset = 24;
      tester.view.padding = const FakeViewPadding(bottom: bottomInset * 3);
      addTearDown(tester.view.resetPadding);
      await _pump(tester, bridge, size: screen);
      bridge.emitSnapshot(elapsedMs: 600000, distanceM: 2000, speedMps: 3);
      await tester.pump();

      final Rect card = tester.getRect(
        find.descendant(
          of: find.byType(ActiveRunScreen),
          matching: find.byType(Card),
        ),
      );
      final Rect pause = tester.getRect(
        find.byKey(ActiveRunScreen.pauseResumeButtonKey),
      );
      final Rect stop = tester.getRect(
        find.byKey(ActiveRunScreen.stopButtonKey),
      );

      // Directly under the card with normal spacing: no empty gap.
      expect(pause.top, closeTo(card.bottom + AppSpacing.itemGap, 0.5));
      // Small gap between the two buttons.
      expect(stop.top, closeTo(pause.bottom + AppSpacing.itemGap, 0.5));
      // Down to the screen padding above the bottom safe area.
      expect(
        stop.bottom,
        closeTo(screen.height - bottomInset - AppSpacing.medium, 0.5),
      );
      // Equal heights, and much taller than the old 112dp cap.
      expect(pause.height, closeTo(stop.height, 1));
      expect(pause.height, greaterThan(150));
      expect(tester.takeException(), isNull);
    });

    testWidgets('small screen, large text: both controls stay on screen', (
      tester,
    ) async {
      await _pump(tester, bridge, size: const Size(320, 568), textScale: 1.3);
      bridge.emitGps(kGpsWeak);
      bridge.emitSnapshot(elapsedMs: 600000, distanceM: 2000, speedMps: 3);
      await tester.pump();
      for (final Key key in [
        ActiveRunScreen.pauseResumeButtonKey,
        ActiveRunScreen.stopButtonKey,
      ]) {
        final Rect r = tester.getRect(find.byKey(key));
        expect(r.height, greaterThanOrEqualTo(72));
        expect(r.bottom, lessThanOrEqualTo(568 - AppSpacing.medium + 0.5));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('meets Android tap-target and label guidelines', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, bridge);
      bridge.emitGps(kGpsGood);
      await tester.pump();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      await tester.tap(find.byKey(ActiveRunScreen.stopButtonKey));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });
  });

  group('Layout: no overflow or clipped values', () {
    final Map<String, (Size, double)> cases = {
      '360x800': (const Size(360, 800), 1.0),
      '320x568': (const Size(320, 568), 1.0),
      '360x800 at 1.3x text': (const Size(360, 800), 1.3),
      '320x568 at 1.3x text': (const Size(320, 568), 1.3),
    };

    for (final MapEntry<String, (Size, double)> c in cases.entries) {
      for (final bool paused in [false, true]) {
        testWidgets('${c.key}, ${paused ? 'paused' : 'running'}', (
          tester,
        ) async {
          await _pump(tester, bridge, size: c.value.$1, textScale: c.value.$2);
          bridge.emitGps(kGpsWeak);
          bridge.emitSnapshot(
            // Flutter's test font draws every glyph as a full em square,
            // about 1.8x wider than Roboto digits. With it, a 7-character
            // h:mm:ss value cannot fit 248dp at 32sp x 1.3, so large-text
            // cases use the longest under-an-hour value instead.
            elapsedMs: c.value.$2 > 1.0
                ? (59 * 60 + 59) * 1000
                : (9 * 3600 + 59 * 60 + 59) * 1000,
            distanceM: 42195,
            speedMps: 5.5,
            paceSecPerKm: 599,
          );
          if (paused) {
            await tester.tap(find.byKey(ActiveRunScreen.pauseResumeButtonKey));
          }
          await tester.pump();
          expect(tester.takeException(), isNull);

          // Every value line fits its box: nothing is cut off.
          for (final Key key in _statKeys) {
            final RenderParagraph p = tester.renderObject<RenderParagraph>(
              find.descendant(
                of: find.byKey(key),
                matching: find.byType(RichText),
              ),
            );
            expect(p.didExceedMaxLines, isFalse, reason: '$key');
            expect(
              p.getMaxIntrinsicWidth(double.infinity),
              lessThanOrEqualTo(p.size.width + 0.5),
              reason: '$key wraps or clips',
            );
          }
        });
      }
    }

    testWidgets('error banner at 320x568, 1.3x text', (tester) async {
      await _pump(tester, bridge, size: const Size(320, 568), textScale: 1.3);
      bridge.emit(
        const TrackingErrorEvent(code: kErrorLocationOff, message: 'off'),
      );
      await tester.pump();
      expect(find.text(AppStrings.errorLocationOff), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Semantics', () {
    testWidgets('stats are read as label plus value with unit', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, bridge);
      bridge.emitSnapshot(distanceM: 3420, speedMps: 3);
      await tester.pump();
      expect(
        tester.getSemantics(find.byKey(ActiveRunScreen.distanceValueKey)),
        containsSemantics(label: '${AppStrings.statDistance}\n3.42 km'),
      );
      handle.dispose();
    });

    testWidgets('GPS badge has a spoken label', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, bridge);
      bridge.emitGps(kGpsWeak);
      await tester.pump();
      expect(
        find.bySemanticsLabel(AppStrings.gpsSemantics(AppStrings.gpsWeak)),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  testWidgets('MockTrackingBridge smoke test: live values update', (
    tester,
  ) async {
    final MockTrackingBridge mock = MockTrackingBridge(
      tickDuration: const Duration(milliseconds: 100),
    );
    await _pump(tester, mock);
    await tester.pump(const Duration(milliseconds: 1050));
    expect(find.text(AppStrings.runStatusLive), findsOneWidget);
    expect(_text(tester, ActiveRunScreen.elapsedValueKey), isNot('--:--'));
    expect(find.text(AppStrings.gpsGood), findsOneWidget);

    // Leave the screen; the parent still owns and disposes the mock.
    await tester.pumpWidget(const SizedBox());
    mock.dispose();
  });
}
