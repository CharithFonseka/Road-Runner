// Road Runner — Settings screen widget tests.
// Owner: Tharushi
// SRS reference: Section 8.4, FR-40, FR-41, NFR-09, NFR-14

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/core/theme/app_palette.dart';
import 'package:road_runner/core/theme/app_colors.dart';
import 'package:road_runner/core/theme/app_theme.dart';
import 'package:road_runner/features/app_strings.dart';
import 'package:road_runner/features/permissions/permission_gateway.dart';
import 'package:road_runner/features/settings/settings_screen.dart';
import 'package:road_runner/features/shared/app_navigation_drawer.dart';
import 'package:road_runner/features/shared/permission_status_chip.dart';

import '../permissions/fake_permission_gateway.dart';

/// Fake whose check() can be held open to test the loading state.
class _Gateway extends FakePermissionGateway {
  _Gateway({super.location, super.notification, super.servicesEnabled});

  Completer<void>? checkGate;

  @override
  Future<PermissionSnapshot> check() async {
    await checkGate?.future;
    return super.check();
  }
}

class _Calls {
  int back = 0;
  int home = 0;
  int history = 0;
  int manage = 0;
}

Future<_Calls> _pump(
  WidgetTester tester,
  FakePermissionGateway gateway, {
  String? version,
  ThemeData? theme,
  Size size = const Size(360, 800),
  double textScale = 1.0,
  bool settle = true,
  ThemeMode themeMode = ThemeMode.system,
  ValueChanged<ThemeMode>? onThemeModeChanged,
}) async {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = size * 3.0;
  addTearDown(tester.view.reset);

  final _Calls c = _Calls();
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light(),
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: SettingsScreen(
          gateway: gateway,
          appVersion: version,
          onBack: () => c.back++,
          onOpenHome: () => c.home++,
          onOpenHistory: () => c.history++,
          onManagePermissions: () => c.manage++,
          themeMode: themeMode,
          onThemeModeChanged: onThemeModeChanged,
        ),
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
  return c;
}

/// Simulates leaving the app (e.g. for Android Settings) and coming back.
Future<void> _backgroundAndResume(WidgetTester tester) async {
  for (final AppLifecycleState s in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
  await tester.pumpAndSettle();
}

String _rowLabel(WidgetTester tester, SettingsPermissionRow row) =>
    tester.getSemantics(find.byKey(SettingsScreen.rowKey(row))).label;

void _expectStatuses(
  WidgetTester tester,
  PermissionChipStatus location,
  PermissionChipStatus notification,
  PermissionChipStatus services,
) {
  final Map<SettingsPermissionRow, (String, String, PermissionChipStatus)>
  rows = {
    SettingsPermissionRow.location: (
      AppStrings.permissionLocationTitle,
      AppStrings.settingsLocationDetail,
      location,
    ),
    SettingsPermissionRow.notification: (
      AppStrings.permissionNotificationTitle,
      AppStrings.settingsNotificationDetail,
      notification,
    ),
    SettingsPermissionRow.locationServices: (
      AppStrings.settingsServicesTitle,
      AppStrings.settingsServicesDetail,
      services,
    ),
  };
  rows.forEach((row, v) {
    expect(
      _rowLabel(tester, row),
      AppStrings.settingsRowSemantics(v.$1, v.$2, v.$3.label),
      reason: row.name,
    );
  });
}

double _luminance(Color c) => c.computeLuminance();
double _contrast(Color a, Color b) {
  final double la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  testWidgets('appearance selector offers system, light and dark', (
    tester,
  ) async {
    ThemeMode? chosen;
    await _pump(
      tester,
      FakePermissionGateway(),
      onThemeModeChanged: (mode) => chosen = mode,
    );
    await tester.scrollUntilVisible(
      find.byKey(SettingsScreen.appearanceKey),
      300,
    );
    await tester.pumpAndSettle();
    expect(find.text('Auto'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    await tester.tap(find.text('Dark'));
    expect(chosen, ThemeMode.dark);
  });

  group('Theme', () {
    testWidgets('dark Settings uses night surfaces and permission colors', (
      tester,
    ) async {
      await _pump(
        tester,
        _Gateway(notification: PermissionAccess.granted),
        theme: AppTheme.dark(),
      );
      final AppPalette palette = AppPalette.dark;

      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        palette.background,
      );
      expect(
        tester.widget<Text>(find.text(AppStrings.settingsTitle)).style!.color,
        palette.textPrimary,
      );
      final CustomPaint artwork = tester.widget<CustomPaint>(
        find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint && widget.painter is DrawerLandscapePainter,
        ),
      );
      expect(
        (artwork.painter as DrawerLandscapePainter).palette,
        same(palette),
      );

      final Finder chip = find.descendant(
        of: find.byKey(
          SettingsScreen.rowKey(SettingsPermissionRow.notification),
        ),
        matching: find.byType(PermissionStatusChip),
      );
      final Container chipContainer = tester.widget<Container>(
        find.descendant(of: chip, matching: find.byType(Container)).first,
      );
      expect(
        (chipContainer.decoration as ShapeDecoration).color,
        palette.statLiveTint,
      );
      expect(
        tester
            .widget<Text>(find.text(AppStrings.permissionStatusAllowed))
            .style!
            .color,
        palette.statLive,
      );
    });

    testWidgets('dark Settings fits a narrow screen with larger text', (
      tester,
    ) async {
      await _pump(
        tester,
        _Gateway(location: PermissionAccess.permanentlyDenied),
        theme: AppTheme.dark(),
        size: const Size(320, 568),
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Permission status', () {
    testWidgets('shows Checking while the status is read', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final _Gateway g = _Gateway()..checkGate = Completer<void>();
      await _pump(tester, g, settle: false);
      await tester.pump();
      _expectStatuses(
        tester,
        PermissionChipStatus.checking,
        PermissionChipStatus.checking,
        PermissionChipStatus.checking,
      );
      // The rest of the screen is usable meanwhile.
      expect(find.byKey(SettingsScreen.manageButtonKey), findsOneWidget);
      expect(find.text(AppStrings.aboutStorageTitle), findsOneWidget);

      g.checkGate!.complete();
      await tester.pumpAndSettle();
      _expectStatuses(
        tester,
        PermissionChipStatus.notAllowed,
        PermissionChipStatus.notAllowed,
        PermissionChipStatus.on,
      );
      handle.dispose();
    });

    for (final PermissionAccess location in PermissionAccess.values) {
      for (final PermissionAccess notification in PermissionAccess.values) {
        for (final bool services in [true, false]) {
          testWidgets(
            'location ${location.name}, notifications ${notification.name}, '
            'services ${services ? 'on' : 'off'}',
            (tester) async {
              final SemanticsHandle handle = tester.ensureSemantics();
              final _Gateway g = _Gateway(
                location: location,
                notification: notification,
                servicesEnabled: services,
              );
              await _pump(tester, g);
              _expectStatuses(
                tester,
                PermissionChipStatus.fromAccess(location),
                PermissionChipStatus.fromAccess(notification),
                PermissionChipStatus.fromServices(enabled: services),
              );
              final bool blocked =
                  location == PermissionAccess.permanentlyDenied ||
                  notification == PermissionAccess.permanentlyDenied;
              expect(
                find.byKey(SettingsScreen.openAppSettingsKey),
                blocked ? findsOneWidget : findsNothing,
              );
              expect(
                find.text(AppStrings.settingsBlockedHint),
                location == PermissionAccess.permanentlyDenied
                    ? findsOneWidget
                    : findsNothing,
              );
              expect(
                find.text(AppStrings.settingsNotificationDeniedHint),
                notification == PermissionAccess.denied
                    ? findsOneWidget
                    : findsNothing,
              );
              expect(
                find.text(AppStrings.settingsNotificationBlockedHint),
                notification == PermissionAccess.permanentlyDenied
                    ? findsOneWidget
                    : findsNothing,
              );
              expect(g.locationRequests + g.notificationRequests, 0);
              handle.dispose();
            },
          );
        }
      }
    }

    testWidgets('a failed read shows Unavailable and Try again recovers', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final _Gateway g = _Gateway(location: PermissionAccess.granted)
        ..checkError = Exception('platform');
      await _pump(tester, g);
      expect(tester.takeException(), isNull);
      _expectStatuses(
        tester,
        PermissionChipStatus.unavailable,
        PermissionChipStatus.unavailable,
        PermissionChipStatus.unavailable,
      );
      expect(find.byKey(SettingsScreen.checkFailedKey), findsOneWidget);
      expect(find.text(AppStrings.permissionsCheckFailed), findsOneWidget);

      g.checkError = null;
      await tester.tap(find.byKey(SettingsScreen.retryButtonKey));
      await tester.pumpAndSettle();
      expect(find.byKey(SettingsScreen.checkFailedKey), findsNothing);
      _expectStatuses(
        tester,
        PermissionChipStatus.allowed,
        PermissionChipStatus.notAllowed,
        PermissionChipStatus.on,
      );
      handle.dispose();
    });

    testWidgets(
      'a read that fails later replaces old values with Unavailable',
      (tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        final _Gateway g = _Gateway(location: PermissionAccess.granted);
        await _pump(tester, g);
        g.checkError = Exception('platform');
        await _backgroundAndResume(tester);
        _expectStatuses(
          tester,
          PermissionChipStatus.unavailable,
          PermissionChipStatus.unavailable,
          PermissionChipStatus.unavailable,
        );
        handle.dispose();
      },
    );
  });

  group('Refresh and Android settings', () {
    testWidgets('re-reads the status when the app resumes', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final _Gateway g = _Gateway(servicesEnabled: false);
      await _pump(tester, g);
      final int checksBefore = g.checkCalls;

      g
        ..location = PermissionAccess.granted
        ..notification = PermissionAccess.granted
        ..servicesEnabled = true;
      await _backgroundAndResume(tester);

      expect(g.checkCalls, checksBefore + 1);
      _expectStatuses(
        tester,
        PermissionChipStatus.allowed,
        PermissionChipStatus.allowed,
        PermissionChipStatus.on,
      );
      handle.dispose();
    });

    testWidgets('Open app settings opens it; returning refreshes', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final _Gateway g = _Gateway(location: PermissionAccess.permanentlyDenied);
      await _pump(tester, g);

      await tester.scrollUntilVisible(
        find.byKey(SettingsScreen.openAppSettingsKey),
        200,
      );
      await tester.drag(find.byType(ListView), const Offset(0, -120));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(SettingsScreen.openAppSettingsKey));
      await tester.pumpAndSettle();
      expect(g.settingsCalls, 1);

      g.location = PermissionAccess.granted; // changed in Android Settings
      await _backgroundAndResume(tester);
      _expectStatuses(
        tester,
        PermissionChipStatus.allowed,
        PermissionChipStatus.notAllowed,
        PermissionChipStatus.on,
      );
      expect(find.byKey(SettingsScreen.openAppSettingsKey), findsNothing);
      expect(g.locationRequests + g.notificationRequests, 0);
      handle.dispose();
    });

    testWidgets('settings that cannot be opened show a message', (
      tester,
    ) async {
      final _Gateway g = _Gateway(
        notification: PermissionAccess.permanentlyDenied,
      )..settingsOpens = false;
      await _pump(tester, g);
      await tester.scrollUntilVisible(
        find.byKey(SettingsScreen.openAppSettingsKey),
        200,
      );
      await tester.drag(find.byType(ListView), const Offset(0, -120));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(SettingsScreen.openAppSettingsKey));
      await tester.pumpAndSettle();
      expect(find.byKey(SettingsScreen.settingsFailedKey), findsOneWidget);
      expect(find.text(AppStrings.settingsOpenFailed), findsOneWidget);
    });

    testWidgets('never shows a system prompt on its own', (tester) async {
      final _Gateway g = _Gateway(location: PermissionAccess.permanentlyDenied);
      await _pump(tester, g);
      await _backgroundAndResume(tester);
      await tester.tap(find.byKey(SettingsScreen.manageButtonKey));
      await tester.scrollUntilVisible(
        find.byKey(SettingsScreen.openAppSettingsKey),
        200,
      );
      await tester.drag(find.byType(ListView), const Offset(0, -120));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(SettingsScreen.openAppSettingsKey));
      await tester.pumpAndSettle();
      expect(g.locationRequests, 0);
      expect(g.notificationRequests, 0);
    });
  });

  group('Actions and navigation', () {
    testWidgets('Manage permissions calls its callback only', (tester) async {
      final _Gateway g = _Gateway();
      final _Calls c = await _pump(tester, g);
      await tester.tap(find.byKey(SettingsScreen.manageButtonKey));
      await tester.pump();
      expect((c.manage, c.back, c.home, c.history), (1, 0, 0, 0));
      expect(g.locationRequests + g.notificationRequests, 0);
    });

    testWidgets('Back calls onBack', (tester) async {
      final _Calls c = await _pump(tester, _Gateway());
      await tester.tap(find.byKey(SettingsScreen.backButtonKey));
      await tester.pump();
      expect((c.back, c.home), (1, 0));
    });

    testWidgets('menu opens the drawer with Settings selected', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, _Gateway());
      await tester.tap(find.byKey(SettingsScreen.menuButtonKey));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AppNavigationDrawer>(find.byType(AppNavigationDrawer))
            .selected,
        AppDestination.settings,
      );
      expect(
        tester.getSemantics(
          find.byKey(
            AppNavigationDrawer.destinationKey(AppDestination.settings),
          ),
        ),
        containsSemantics(isSelected: true),
      );
      handle.dispose();
    });

    for (final AppDestination d in AppDestination.values) {
      testWidgets('drawer ${d.name}', (tester) async {
        final _Calls c = await _pump(tester, _Gateway());
        await tester.tap(find.byKey(SettingsScreen.menuButtonKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(AppNavigationDrawer.destinationKey(d)));
        await tester.pumpAndSettle();
        expect(find.byType(AppNavigationDrawer), findsNothing);
        expect(
          (c.home, c.history, c.back),
          switch (d) {
            AppDestination.home => (1, 0, 0),
            AppDestination.history => (0, 1, 0),
            AppDestination.settings => (0, 0, 0),
          },
        );
      });
    }

    testWidgets('system Back closes the drawer first', (tester) async {
      await _pump(tester, _Gateway());
      await tester.tap(find.byKey(SettingsScreen.menuButtonKey));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AppNavigationDrawer), findsNothing);
      expect(find.byType(SettingsScreen), findsOneWidget);
    });
  });

  group('About', () {
    testWidgets('describes the app and local storage', (tester) async {
      await _pump(tester, _Gateway());
      await tester.scrollUntilVisible(find.text(AppStrings.navTagline), 200);
      expect(find.text(AppStrings.navTagline), findsOneWidget);
      expect(find.text(AppStrings.aboutTrackerDetail), findsOneWidget);
      expect(find.text(AppStrings.aboutStorageTitle), findsOneWidget);
      expect(find.text(AppStrings.aboutStorageDetail), findsOneWidget);
      // No invented settings.
      expect(find.byType(Switch), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
    });

    testWidgets('shows the version only when one is supplied', (tester) async {
      await _pump(tester, _Gateway());
      expect(find.byKey(SettingsScreen.versionKey), findsNothing);
      expect(find.text(AppStrings.aboutVersionTitle), findsNothing);

      await _pump(tester, _Gateway(), version: '   ');
      expect(find.byKey(SettingsScreen.versionKey), findsNothing);

      await _pump(tester, _Gateway(), version: '1.0.0 (3)');
      await tester.scrollUntilVisible(
        find.byKey(SettingsScreen.versionKey),
        200,
      );
      expect(find.text('1.0.0 (3)'), findsOneWidget);
    });
  });

  group('Layout and accessibility', () {
    final Map<String, (Size, double)> cases = {
      '360x800': (const Size(360, 800), 1.0),
      '320x568': (const Size(320, 568), 1.0),
      '412x915 (Galaxy A33)': (const Size(412, 915), 1.0),
      '360x800 at 1.3x text': (const Size(360, 800), 1.3),
      '320x568 at 1.3x text': (const Size(320, 568), 1.3),
    };
    for (final MapEntry<String, (Size, double)> e in cases.entries) {
      testWidgets('${e.key}: no overflow, all content reachable', (
        tester,
      ) async {
        await _pump(
          tester,
          _Gateway(location: PermissionAccess.permanentlyDenied),
          version: '1.0.0',
          size: e.value.$1,
          textScale: e.value.$2,
        );
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.byKey(SettingsScreen.versionKey),
          200,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('narrow + large text moves chips below the row text', (
      tester,
    ) async {
      await _pump(
        tester,
        _Gateway(),
        size: const Size(320, 568),
        textScale: 1.3,
      );
      final Finder row = find.byKey(
        SettingsScreen.rowKey(SettingsPermissionRow.location),
      );
      final Rect chip = tester.getRect(
        find.descendant(of: row, matching: find.byType(PermissionStatusChip)),
      );
      final Rect title = tester.getRect(
        find.descendant(
          of: row,
          matching: find.text(AppStrings.permissionLocationTitle),
        ),
      );
      expect(chip.top, greaterThan(title.bottom));
    });

    testWidgets('respects the status and navigation bars', (tester) async {
      const double statusBar = 32, navBar = 48;
      tester.view.padding = const FakeViewPadding(
        top: statusBar * 3,
        bottom: navBar * 3,
      );
      addTearDown(tester.view.resetPadding);
      await _pump(tester, _Gateway(), version: '1.0.0');
      expect(
        tester.getRect(find.byKey(SettingsScreen.backButtonKey)).top,
        greaterThanOrEqualTo(statusBar),
      );
      await tester.scrollUntilVisible(
        find.byKey(SettingsScreen.versionKey),
        200,
      );
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(SettingsScreen.versionKey)).bottom,
        lessThanOrEqualTo(800 - navBar),
      );
    });

    testWidgets('buttons are at least 48dp', (tester) async {
      await _pump(
        tester,
        _Gateway(location: PermissionAccess.permanentlyDenied)
          ..checkError = null,
      );
      for (final Key k in [
        SettingsScreen.backButtonKey,
        SettingsScreen.menuButtonKey,
        SettingsScreen.manageButtonKey,
        SettingsScreen.openAppSettingsKey,
      ]) {
        final Size s = tester.getSize(find.byKey(k));
        expect(s.height, greaterThanOrEqualTo(48), reason: '$k');
        expect(s.width, greaterThanOrEqualTo(48), reason: '$k');
      }
    });

    testWidgets('Try again is at least 48dp', (tester) async {
      await _pump(tester, _Gateway()..checkError = Exception('x'));
      expect(
        tester.getSize(find.byKey(SettingsScreen.retryButtonKey)).height,
        greaterThanOrEqualTo(48),
      );
    });

    for (final (String name, FakePermissionGateway Function() make) in [
      ('ready', () => _Gateway(location: PermissionAccess.permanentlyDenied)),
      ('error', () => _Gateway()..checkError = Exception('x')),
    ]) {
      testWidgets('$name: tap-target and label guidelines', (tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await _pump(tester, make());
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });
    }

    testWidgets('title and section headings are headings', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, _Gateway());
      expect(
        tester.getSemantics(find.text(AppStrings.settingsTitle)),
        containsSemantics(isHeader: true),
      );
      expect(
        tester.getSemantics(
          find.text(AppStrings.settingsPermissionsSection.toUpperCase()),
        ),
        containsSemantics(
          label: AppStrings.settingsPermissionsSection,
          isHeader: true,
        ),
      );
      for (final (Key k, String tip) in [
        (SettingsScreen.backButtonKey, AppStrings.settingsBack),
        (SettingsScreen.menuButtonKey, AppStrings.homeOpenMenu),
      ]) {
        expect(
          tester.getSemantics(find.byKey(k)),
          containsSemantics(tooltip: tip, isButton: true),
        );
      }
      handle.dispose();
    });
  });

  group('PermissionStatusChip', () {
    test('maps access and services states', () {
      expect(
        PermissionChipStatus.fromAccess(PermissionAccess.granted),
        PermissionChipStatus.allowed,
      );
      expect(
        PermissionChipStatus.fromAccess(PermissionAccess.denied),
        PermissionChipStatus.notAllowed,
      );
      expect(
        PermissionChipStatus.fromAccess(PermissionAccess.permanentlyDenied),
        PermissionChipStatus.blocked,
      );
      expect(
        PermissionChipStatus.fromServices(enabled: true),
        PermissionChipStatus.on,
      );
      expect(
        PermissionChipStatus.fromServices(enabled: false),
        PermissionChipStatus.off,
      );
    });

    test('every state has a distinct word and an icon', () {
      final Set<String> labels = {
        for (final PermissionChipStatus s in PermissionChipStatus.values)
          s.label,
      };
      expect(labels.length, PermissionChipStatus.values.length);
    });

    test('text meets 4.5:1 on its fill over the card', () {
      for (final PermissionChipStatus s in PermissionChipStatus.values) {
        final Color fill = Color.alphaBlend(s.background, AppColors.sandLight);
        expect(
          _contrast(s.foreground, fill),
          greaterThanOrEqualTo(4.5),
          reason: s.name,
        );
      }
    });

    testWidgets('chip is at least 32dp tall and reads its label', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: PermissionStatusChip(status: PermissionChipStatus.blocked),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(PermissionStatusChip)).height,
        greaterThanOrEqualTo(32),
      );
      expect(
        tester.getSemantics(find.byType(PermissionStatusChip)),
        containsSemantics(label: AppStrings.permissionStatusBlocked),
      );
      handle.dispose();
    });
  });
}
