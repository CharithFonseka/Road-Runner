// Road Runner — Permissions screen widget tests.
// Owner: Tharushi
// SRS reference: FR-40, FR-41, NFR-09, NFR-14

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/core/theme/app_spacing.dart';
import 'package:road_runner/core/theme/app_theme.dart';
import 'package:road_runner/features/app_strings.dart';
import 'package:road_runner/features/permissions/permission_gateway.dart';
import 'package:road_runner/features/permissions/permissions_screen.dart';

import 'fake_permission_gateway.dart';

class _Calls {
  int continued = 0;
  int notNow = 0;
}

Future<_Calls> _pump(
  WidgetTester tester,
  FakePermissionGateway gateway, {
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
        child: PermissionsScreen(
          gateway: gateway,
          onContinue: () => calls.continued++,
          onNotNow: () => calls.notNow++,
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

      expect(find.text(AppStrings.permissionsScreenTitle), findsOneWidget);
      expect(find.text(AppStrings.permissionsIntro), findsOneWidget);
      expect(find.text(AppStrings.permissionLocationTitle), findsOneWidget);
      expect(find.text(AppStrings.permissionNotificationTitle), findsOneWidget);
      expect(
        find.text(AppStrings.permissionNotificationReason),
        findsOneWidget,
      );
      expect(find.text(AppStrings.permissionsFooter), findsOneWidget);
      _expectPrimary(AppStrings.allowLocationAccess);
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

      expect(find.text(AppStrings.locationDeniedMessage), findsOneWidget);
      expect(find.text(AppStrings.permissionStatusNotAllowed), findsWidgets);
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
      final FakePermissionGateway gateway = FakePermissionGateway()
        ..notificationAnswer = PermissionAccess.denied;
      await _pump(tester, gateway);
      await _tapPrimary(tester);
      expect(find.text(AppStrings.notificationDeniedMessage), findsOneWidget);
      _expectPrimary(AppStrings.allowNotifications);
    });
  });

  group('Permanently denied', () {
    testWidgets('location blocked offers Open Settings', (tester) async {
      final FakePermissionGateway gateway = FakePermissionGateway(
        location: PermissionAccess.permanentlyDenied,
      );
      await _pump(tester, gateway);
      expect(find.text(AppStrings.locationBlockedMessage), findsOneWidget);
      expect(find.text(AppStrings.permissionStatusBlocked), findsOneWidget);
      _expectPrimary(AppStrings.openSettings);

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
      expect(find.text(AppStrings.locationBlockedMessage), findsOneWidget);
      _expectPrimary(AppStrings.openSettings);
    });

    testWidgets('notifications blocked offers Open Settings', (tester) async {
      final FakePermissionGateway gateway = FakePermissionGateway(
        location: PermissionAccess.granted,
        notification: PermissionAccess.permanentlyDenied,
      );
      await _pump(tester, gateway);
      expect(find.text(AppStrings.notificationBlockedMessage), findsOneWidget);
      _expectPrimary(AppStrings.openSettings);
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

      expect(find.text(AppStrings.locationBlockedMessage), findsNothing);
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

      expect(find.text(AppStrings.locationServicesOffMessage), findsOneWidget);
      expect(find.text(AppStrings.locationServicesTitle), findsOneWidget);
      expect(find.text(AppStrings.permissionStatusOff), findsOneWidget);
      expect(find.text(AppStrings.locationBlockedMessage), findsNothing);
      expect(find.text(AppStrings.locationDeniedMessage), findsNothing);
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
      _expectPrimary(AppStrings.allowLocationAccess);
    });

    testWidgets('request failure shows a message and allows retry', (
      tester,
    ) async {
      final FakePermissionGateway gateway = FakePermissionGateway()
        ..requestError = StateError('x');
      await _pump(tester, gateway);
      await _tapPrimary(tester);
      expect(find.text(AppStrings.permissionRequestFailed), findsOneWidget);
      _expectPrimary(AppStrings.allowLocationAccess);
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

  group('Accessibility', () {
    testWidgets('title is a header and rows read title, status and reason', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, FakePermissionGateway());
      expect(
        tester.getSemantics(find.text(AppStrings.permissionsScreenTitle)),
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
          label: AppStrings.allowLocationAccess,
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
      ]) {
        expect(
          tester.getSize(find.byKey(key)).height,
          greaterThanOrEqualTo(AppSpacing.minTouchTarget),
        );
      }
    });
  });

  group('Layout: no overflow', () {
    final Map<String, (Size, double)> sizes = {
      '360x800': (const Size(360, 800), 1.0),
      '320x568': (const Size(320, 568), 1.0),
      '320x568 at 1.3x text': (const Size(320, 568), 1.3),
    };
    final Map<String, FakePermissionGateway Function()> states = {
      'initial': FakePermissionGateway.new,
      'blocked': () =>
          FakePermissionGateway(location: PermissionAccess.permanentlyDenied),
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
          await tester.ensureVisible(_primary);
          expect(_primary.hitTestable(), findsOneWidget);
        });
      }
    }
  });
}
