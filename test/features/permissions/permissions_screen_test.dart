// Road Runner — Permissions screen widget tests.
// Owner: Tharushi
// SRS reference: FR-40, FR-41, NFR-09, NFR-14

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/core/theme/app_palette.dart';
import 'package:road_runner/core/theme/app_spacing.dart';
import 'package:road_runner/core/theme/app_theme.dart';
import 'package:road_runner/features/app_strings.dart';
import 'package:road_runner/features/permissions/permission_gateway.dart';
import 'package:road_runner/features/permissions/permissions_screen.dart';
import 'package:road_runner/features/permissions/widgets/permission_illustration.dart';

import 'fake_permission_gateway.dart';

class _Calls {
  int continued = 0;
  int notNow = 0;
  int back = 0;
}

Future<_Calls> _pump(
  WidgetTester tester,
  FakePermissionGateway gateway, {
  Size size = const Size(360, 800),
  double textScale = 1.0,
  bool withBack = false,
  bool dark = false,
}) async {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = size * 3.0;
  addTearDown(tester.view.reset);

  final _Calls calls = _Calls();
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: PermissionsScreen(
          gateway: gateway,
          onContinue: () => calls.continued++,
          onNotNow: () => calls.notNow++,
          onBack: withBack ? () => calls.back++ : null,
        ),
      ),
    ),
  );
  await tester.pump();
  return calls;
}

Finder get _primary => find.byKey(PermissionsScreen.primaryButtonKey);

Future<void> _tapPrimary(WidgetTester tester) async {
  await tester.ensureVisible(_primary);
  await tester.tap(_primary);
  await tester.pump();
}

void _expectPrimary(String label) {
  expect(
    find.descendant(of: _primary, matching: find.text(label)),
    findsOneWidget,
  );
}

void main() {
  group('Initial explanation', () {
    testWidgets('explains location and notifications before asking', (
      tester,
    ) async {
      final FakePermissionGateway gateway = FakePermissionGateway();
      await _pump(tester, gateway);

      expect(find.text(AppStrings.permissionsIntroTitle), findsOneWidget);
      expect(find.text(AppStrings.permissionsIntroHeading), findsOneWidget);
      expect(find.text(AppStrings.permissionsIntroBody), findsOneWidget);
      expect(find.text(AppStrings.permissionLocationTitle), findsOneWidget);
      expect(find.text(AppStrings.permissionNotificationTitle), findsOneWidget);
      expect(
        find.text(AppStrings.permissionNotificationReason),
        findsOneWidget,
      );
      expect(find.text(AppStrings.permissionsFooter), findsOneWidget);
      _expectPrimary(AppStrings.continueAction);
      expect(find.text(AppStrings.notNow), findsOneWidget);

      // Opening the screen reads state but never shows a system prompt.
      expect(gateway.checkCalls, 1);
      expect(gateway.locationRequests, 0);
      expect(gateway.notificationRequests, 0);
    });

    testWidgets('shows a checking state until the state is read', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 3.0;
      tester.view.physicalSize = const Size(360, 800) * 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: PermissionsScreen(
            gateway: FakePermissionGateway(),
            onContinue: () {},
            onNotNow: () {},
          ),
        ),
      );
      expect(find.text(AppStrings.permissionsChecking), findsOneWidget);
      expect(_primary, findsNothing);
      await tester.pump();
    });

    testWidgets('Not Now calls onNotNow', (tester) async {
      final _Calls calls = await _pump(tester, FakePermissionGateway());
      await tester.ensureVisible(find.byKey(PermissionsScreen.notNowButtonKey));
      await tester.tap(find.byKey(PermissionsScreen.notNowButtonKey));
      expect(calls.notNow, 1);
    });
  });

  group('Granted', () {
    testWidgets('allowing both permissions shows Continue', (tester) async {
      final FakePermissionGateway gateway = FakePermissionGateway();
      final _Calls calls = await _pump(tester, gateway);

      await _tapPrimary(tester);
      expect(gateway.locationRequests, 1);
      expect(gateway.notificationRequests, 1);
      expect(find.text(AppStrings.permissionsReady), findsOneWidget);
      expect(find.text(AppStrings.permissionStatusAllowed), findsNWidgets(2));
      expect(find.text(AppStrings.notNow), findsNothing);
      _expectPrimary(AppStrings.continueAction);

      await _tapPrimary(tester);
      expect(calls.continued, 1);
    });

    testWidgets('already granted: ready without asking again', (tester) async {
      final FakePermissionGateway gateway = FakePermissionGateway(
        location: PermissionAccess.granted,
        notification: PermissionAccess.granted,
      );
      await _pump(tester, gateway);
      expect(find.text(AppStrings.permissionsReady), findsOneWidget);
      await _tapPrimary(tester);
      expect(gateway.locationRequests, 0);
      expect(gateway.notificationRequests, 0);
    });

    testWidgets('location already granted asks only for notifications', (
      tester,
    ) async {
      final FakePermissionGateway gateway = FakePermissionGateway(
        location: PermissionAccess.granted,
      );
      await _pump(tester, gateway);
      expect(find.text(AppStrings.notificationNeededMessage), findsOneWidget);
      _expectPrimary(AppStrings.allowNotifications);
      await _tapPrimary(tester);
      expect(gateway.locationRequests, 0);
      expect(gateway.notificationRequests, 1);
    });
  });

  group('Denied', () {
    testWidgets('location denied explains and allows asking again', (
      tester,
    ) async {
      final FakePermissionGateway gateway = FakePermissionGateway()
        ..locationAnswer = PermissionAccess.denied;
      await _pump(tester, gateway);
      await _tapPrimary(tester);

      expect(find.text(AppStrings.locationDeniedHeading), findsOneWidget);
      expect(find.text(AppStrings.locationDeniedBody), findsOneWidget);
      expect(find.text(AppStrings.permissionStatusNotAllowed), findsWidgets);
      // Ordinary denial: no "blocked" steps, no app-settings detour.
      expect(find.byKey(PermissionsScreen.stepKey(1)), findsNothing);
      expect(gateway.settingsCalls, 0);
      _expectPrimary(AppStrings.allowLocationAccess);
      expect(gateway.notificationRequests, 0);

      gateway.locationAnswer = null;
      await _tapPrimary(tester);
      expect(gateway.locationRequests, 2);
      expect(find.text(AppStrings.permissionsReady), findsOneWidget);
    });

    testWidgets('notification denied explains and allows asking again', (
      tester,
    ) async {
      final FakePermissionGateway gateway = FakePermissionGateway(
        location: PermissionAccess.granted,
      )..notificationAnswer = PermissionAccess.denied;
      final _Calls calls = await _pump(tester, gateway);
      await _tapPrimary(tester);
      expect(find.text(AppStrings.notificationDeniedMessage), findsOneWidget);
      _expectPrimary(AppStrings.allowNotifications);
      expect(
        find.byKey(PermissionsScreen.continueWithoutNotificationsButtonKey),
        findsOneWidget,
      );
      expect(gateway.notificationRequests, 1);
      await tester.tap(
        find.byKey(PermissionsScreen.continueWithoutNotificationsButtonKey),
      );
      expect(calls.continued, 1);
      expect(gateway.notificationRequests, 1);
    });
  });

  group('Permanently denied', () {
    testWidgets('location blocked offers Open Settings', (tester) async {
      final FakePermissionGateway gateway = FakePermissionGateway(
        location: PermissionAccess.permanentlyDenied,
      );
      await _pump(tester, gateway);
      expect(find.text(AppStrings.locationDeniedHeading), findsOneWidget);
      expect(find.text(AppStrings.locationBlockedBody), findsOneWidget);
      for (final (int n, String step) in [
        (1, AppStrings.locationBlockedStep1),
        (2, AppStrings.locationBlockedStep2),
        (3, AppStrings.locationBlockedStep3),
      ]) {
        expect(
          find.descendant(
            of: find.byKey(PermissionsScreen.stepKey(n)),
            matching: find.text(step),
          ),
          findsOneWidget,
        );
      }
      _expectPrimary(AppStrings.openAppSettings);

      await _tapPrimary(tester);
      expect(gateway.settingsCalls, 1);
      expect(gateway.locationRequests, 0);
    });

    testWidgets('denial that becomes permanent switches to Open Settings', (
      tester,
    ) async {
      final FakePermissionGateway gateway = FakePermissionGateway()
        ..locationAnswer = PermissionAccess.permanentlyDenied;
      await _pump(tester, gateway);
      await _tapPrimary(tester);
      expect(find.text(AppStrings.locationBlockedBody), findsOneWidget);
      _expectPrimary(AppStrings.openAppSettings);
    });

    testWidgets('notifications blocked offers Settings or GPS continuation', (
      tester,
    ) async {
      final FakePermissionGateway gateway = FakePermissionGateway(
        location: PermissionAccess.granted,
        notification: PermissionAccess.permanentlyDenied,
      );
      final _Calls calls = await _pump(tester, gateway);
      expect(find.text(AppStrings.notificationBlockedMessage), findsOneWidget);
      _expectPrimary(AppStrings.openAppSettings);
      expect(
        find.byKey(PermissionsScreen.continueWithoutNotificationsButtonKey),
        findsOneWidget,
      );
      await _tapPrimary(tester);
      expect(gateway.settingsCalls, 1);
      await tester.tap(
        find.byKey(PermissionsScreen.continueWithoutNotificationsButtonKey),
      );
      expect(calls.continued, 1);
      expect(gateway.notificationRequests, 0);
    });

    testWidgets('returning from Settings re-reads the state', (tester) async {
      final FakePermissionGateway gateway = FakePermissionGateway(
        location: PermissionAccess.permanentlyDenied,
      );
      await _pump(tester, gateway);
      await _tapPrimary(tester);

      // The user allows location in Settings, then comes back.
      gateway.location = PermissionAccess.granted;
      for (final AppLifecycleState state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump();

      expect(find.text(AppStrings.locationDeniedHeading), findsNothing);
      expect(find.text(AppStrings.permissionsIntroHeading), findsOneWidget);
      _expectPrimary(AppStrings.allowNotifications);
    });
  });

  group('Location services off', () {
    testWidgets('is shown as a phone setting, not a permission denial', (
      tester,
    ) async {
      final FakePermissionGateway gateway = FakePermissionGateway(
        location: PermissionAccess.granted,
        notification: PermissionAccess.granted,
        servicesEnabled: false,
      );
      await _pump(tester, gateway);

      expect(find.text(AppStrings.servicesOffHeader), findsOneWidget);
      expect(find.text(AppStrings.servicesOffHeading), findsOneWidget);
      expect(find.text(AppStrings.servicesOffBody), findsOneWidget);
      expect(find.text(AppStrings.servicesOffStepTitle), findsOneWidget);
      expect(find.text(AppStrings.permissionStatusOff), findsOneWidget);
      expect(find.text(AppStrings.locationDeniedHeading), findsNothing);
      // No invented "open Location settings" action: the gateway cannot.
      expect(find.text(AppStrings.openAppSettings), findsNothing);
      _expectPrimary(AppStrings.checkAgain);

      gateway.servicesEnabled = true;
      await _tapPrimary(tester);
      expect(find.text(AppStrings.permissionsReady), findsOneWidget);
      expect(gateway.locationRequests, 0);
    });
  });

  group('Duplicate requests', () {
    testWidgets('double tap asks the system only once', (tester) async {
      final FakePermissionGateway gateway = FakePermissionGateway()
        ..locationGate = Completer<void>();
      await _pump(tester, gateway);

      await tester.ensureVisible(_primary);
      await tester.tap(_primary);
      await tester.pump();
      // Disabled while the system prompt is open.
      expect(tester.widget<ButtonStyleButton>(_primary).enabled, isFalse);
      await tester.tap(_primary, warnIfMissed: false);
      await tester.pump();

      gateway.locationGate!.complete();
      await tester.pump();
      expect(gateway.locationRequests, 1);
      expect(gateway.notificationRequests, 1);
    });
  });

  group('Errors', () {
    testWidgets('check failure offers Check Again', (tester) async {
      final FakePermissionGateway gateway = FakePermissionGateway()
        ..checkError = StateError('x');
      await _pump(tester, gateway);
      expect(find.text(AppStrings.permissionsCheckFailed), findsOneWidget);
      _expectPrimary(AppStrings.checkAgain);

      gateway.checkError = null;
      await _tapPrimary(tester);
      _expectPrimary(AppStrings.continueAction);
    });

    testWidgets('request failure shows a message and allows retry', (
      tester,
    ) async {
      final FakePermissionGateway gateway = FakePermissionGateway()
        ..requestError = StateError('x');
      await _pump(tester, gateway);
      await _tapPrimary(tester);
      expect(find.text(AppStrings.permissionRequestFailed), findsOneWidget);
      _expectPrimary(AppStrings.continueAction);
    });

    testWidgets('Settings that cannot open give manual instructions', (
      tester,
    ) async {
      final FakePermissionGateway gateway = FakePermissionGateway(
        location: PermissionAccess.permanentlyDenied,
      )..settingsOpens = false;
      await _pump(tester, gateway);
      await _tapPrimary(tester);
      expect(find.text(AppStrings.settingsOpenFailed), findsOneWidget);
    });
  });

  group('Dark theme', () {
    testWidgets(
      'denied notifications retain lock-screen guidance and run access',
      (tester) async {
        final FakePermissionGateway gateway = FakePermissionGateway(
          location: PermissionAccess.granted,
        )..notificationAnswer = PermissionAccess.denied;
        final _Calls calls = await _pump(tester, gateway, dark: true);
        final AppPalette palette = AppPalette.dark;

        expect(
          tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
          palette.background,
        );
        expect(
          tester
              .widget<Text>(find.byKey(PermissionsScreen.headingKey))
              .style!
              .color,
          palette.textPrimary,
        );
        expect(
          Theme.of(tester.element(_primary)).cardTheme.color,
          palette.surface,
        );

        await _tapPrimary(tester);
        expect(find.text(AppStrings.notificationDeniedMessage), findsOneWidget);
        expect(
          find.byKey(PermissionsScreen.continueWithoutNotificationsButtonKey),
          findsOneWidget,
        );
        expect(gateway.notificationRequests, 1);
        await tester.tap(
          find.byKey(PermissionsScreen.continueWithoutNotificationsButtonKey),
        );
        expect(calls.continued, 1);
      },
    );

    testWidgets(
      'blocked location uses night styling and still opens Settings',
      (tester) async {
        final FakePermissionGateway gateway = FakePermissionGateway(
          location: PermissionAccess.permanentlyDenied,
        );
        await _pump(tester, gateway, dark: true);

        expect(find.text(AppStrings.locationBlockedBody), findsOneWidget);
        expect(find.byKey(PermissionsScreen.stepKey(1)), findsOneWidget);
        _expectPrimary(AppStrings.openAppSettings);
        await _tapPrimary(tester);
        expect(gateway.settingsCalls, 1);
      },
    );

    testWidgets('dark layout fits narrow and large-text screens', (
      tester,
    ) async {
      for (final (Size size, double scale) in [
        (const Size(320, 568), 1.0),
        (const Size(360, 800), 1.3),
      ]) {
        await _pump(
          tester,
          FakePermissionGateway(location: PermissionAccess.permanentlyDenied),
          size: size,
          textScale: scale,
          dark: true,
        );
        expect(tester.takeException(), isNull);
        expect(_primary.hitTestable(), findsOneWidget);
      }
    });
  });

  group('Accessibility', () {
    testWidgets('title is a header and rows read title, status and reason', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, FakePermissionGateway());
      expect(
        tester.getSemantics(find.text(AppStrings.permissionsIntroTitle)),
        containsSemantics(isHeader: true),
      );
      expect(
        tester.getSemantics(find.text(AppStrings.permissionsIntroHeading)),
        containsSemantics(isHeader: true),
      );
      final String row = tester
          .getSemantics(find.text(AppStrings.permissionLocationTitle))
          .label;
      expect(row, contains(AppStrings.permissionLocationTitle));
      expect(row, contains(AppStrings.permissionStatusNotAllowed));
      expect(row, contains(AppStrings.permissionLocationReason));
      handle.dispose();
    });

    testWidgets('primary action is a labelled, enabled button', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, FakePermissionGateway());
      expect(
        tester.getSemantics(_primary),
        containsSemantics(
          label: AppStrings.continueAction,
          isButton: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('meets tap-target and label guidelines', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, FakePermissionGateway());
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('buttons are at least 48dp tall', (tester) async {
      await _pump(tester, FakePermissionGateway());
      for (final Key key in [
        PermissionsScreen.primaryButtonKey,
        PermissionsScreen.notNowButtonKey,
        PermissionsScreen.backButtonKey,
      ]) {
        final Size size = tester.getSize(find.byKey(key));
        expect(size.height, greaterThanOrEqualTo(AppSpacing.minTouchTarget));
        expect(size.width, greaterThanOrEqualTo(AppSpacing.minTouchTarget));
      }
    });
  });

  group('Layout: no overflow', () {
    final Map<String, (Size, double)> sizes = {
      '360x800': (const Size(360, 800), 1.0),
      '320x568': (const Size(320, 568), 1.0),
      '412x915 (Galaxy A33)': (const Size(412, 915), 1.0),
      '360x800 at 1.3x text': (const Size(360, 800), 1.3),
      '320x568 at 1.3x text': (const Size(320, 568), 1.3),
    };
    final Map<String, FakePermissionGateway Function()> states = {
      'initial': FakePermissionGateway.new,
      'blocked': () =>
          FakePermissionGateway(location: PermissionAccess.permanentlyDenied),
      'notifications blocked': () => FakePermissionGateway(
        location: PermissionAccess.granted,
        notification: PermissionAccess.permanentlyDenied,
      ),
      'services off': () => FakePermissionGateway(
        location: PermissionAccess.granted,
        servicesEnabled: false,
      ),
      'ready': () => FakePermissionGateway(
        location: PermissionAccess.granted,
        notification: PermissionAccess.granted,
      ),
    };
    for (final MapEntry<String, (Size, double)> s in sizes.entries) {
      for (final MapEntry<String, FakePermissionGateway Function()> st
          in states.entries) {
        testWidgets('${s.key}, ${st.key}', (tester) async {
          await _pump(
            tester,
            st.value(),
            size: s.value.$1,
            textScale: s.value.$2,
          );
          expect(tester.takeException(), isNull);
          // Actions are fixed at the bottom: visible without scrolling.
          expect(_primary.hitTestable(), findsOneWidget);
          final Size screen = s.value.$1;
          expect(
            tester.getRect(_primary).bottom,
            lessThanOrEqualTo(screen.height - AppSpacing.medium + 0.5),
          );
          // Both runner figures fully on screen.
          for (final Key k in [
            PermissionIllustration.femaleKey,
            PermissionIllustration.maleKey,
          ]) {
            final Rect r = tester.getRect(find.byKey(k));
            expect(r.left, greaterThanOrEqualTo(0));
            expect(r.right, lessThanOrEqualTo(screen.width));
            expect(r.height, greaterThan(0));
          }
        });
      }
    }
  });
}
