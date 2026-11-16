// Road Runner — Landscape Orientation Widget Tests: Group 1.
// Phase 4B.3A: Splash, Permissions, Settings, and Navigation Drawer.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/core/theme/app_palette.dart';
import 'package:road_runner/core/theme/app_theme.dart';
import 'package:road_runner/features/app_strings.dart';
import 'package:road_runner/features/permissions/permission_gateway.dart';
import 'package:road_runner/features/permissions/permissions_screen.dart';
import 'package:road_runner/features/settings/settings_screen.dart';
import 'package:road_runner/features/shared/app_navigation_drawer.dart';
import 'package:road_runner/features/splash/splash_screen.dart';

import '../permissions/fake_permission_gateway.dart';

class _DrawerCalls {
  int home = 0;
  int history = 0;
  int settings = 0;
}

final GlobalKey<ScaffoldState> _drawerScaffoldKey = GlobalKey<ScaffoldState>();

Future<_DrawerCalls> _pumpDrawer(
  WidgetTester tester, {
  Size size = const Size(800, 360),
  double textScale = 1.0,
  ThemeData? theme,
  AppDestination selected = AppDestination.home,
}) async {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = size * 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final _DrawerCalls calls = _DrawerCalls();
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light(),
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: Scaffold(
          key: _drawerScaffoldKey,
          drawer: AppNavigationDrawer(
            selected: selected,
            onOpenHome: () => calls.home++,
            onOpenHistory: () => calls.history++,
            onOpenSettings: () => calls.settings++,
          ),
          body: const Center(child: Text('host')),
        ),
      ),
    ),
  );
  _drawerScaffoldKey.currentState!.openDrawer();
  await tester.pumpAndSettle();
  return calls;
}

Future<void> _pumpSplash(
  WidgetTester tester, {
  Size size = const Size(800, 360),
  double textScale = 1.0,
  ThemeData? theme,
  bool reduceMotion = false,
}) async {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = size * 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(disableAnimations: reduceMotion);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light(),
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: const SplashScreen(),
      ),
    ),
  );
  await tester.pump();
}

class _PermissionsCalls {
  int continued = 0;
  int notNow = 0;
  int back = 0;
}

Future<_PermissionsCalls> _pumpPermissions(
  WidgetTester tester,
  FakePermissionGateway gateway, {
  Size size = const Size(800, 360),
  double textScale = 1.0,
  ThemeData? theme,
}) async {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = size * 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final _PermissionsCalls calls = _PermissionsCalls();
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light(),
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: PermissionsScreen(
          gateway: gateway,
          onContinue: () => calls.continued++,
          onNotNow: () => calls.notNow++,
          onBack: () => calls.back++,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return calls;
}

class _SettingsCalls {
  int back = 0;
  int home = 0;
  int history = 0;
  int manage = 0;
}

Future<_SettingsCalls> _pumpSettings(
  WidgetTester tester,
  FakePermissionGateway gateway, {
  Size size = const Size(800, 360),
  double textScale = 1.0,
  ThemeData? theme,
  String? version = '1.0.0 (42)',
}) async {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = size * 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final _SettingsCalls calls = _SettingsCalls();
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light(),
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: SettingsScreen(
          gateway: gateway,
          appVersion: version,
          onBack: () => calls.back++,
          onOpenHome: () => calls.home++,
          onOpenHistory: () => calls.history++,
          onManagePermissions: () => calls.manage++,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return calls;
}

void main() {
  group('Splash Landscape (Phase 4B.3A)', () {
    for (final Size size in [
      const Size(800, 360),
      const Size(915, 412),
      const Size(640, 360),
    ]) {
      testWidgets(
        '${size.width.toInt()}x${size.height.toInt()}: brand fits full scale and spinner visible',
        (tester) async {
          await _pumpSplash(tester, size: size);
          expect(tester.takeException(), isNull);

          final Rect brand = tester.getRect(find.byKey(SplashScreen.brandKey));
          final Rect land = tester.getRect(
            find.byKey(SplashScreen.landscapeKey),
          );
          final Rect spinner = tester.getRect(
            find.byKey(SplashScreen.spinnerKey),
          );

          // Artwork is anchored at bottom and does not dominate screen.
          expect(land.bottom, closeTo(size.height, 0.5));
          expect(land.height, lessThanOrEqualTo(size.height * 0.28));

          // Brand sits above artwork with clearance.
          expect(brand.bottom, lessThanOrEqualTo(land.top + 0.5));

          // Spinner is centered and visible below the name.
          expect(spinner.bottom, lessThanOrEqualTo(land.top));
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
        },
      );
    }

    testWidgets('1.3x text scaling on 800x360: zero overflow', (tester) async {
      await _pumpSplash(tester, size: const Size(800, 360), textScale: 1.3);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dark theme renders night sky and celestial artwork', (
      tester,
    ) async {
      await _pumpSplash(tester, theme: AppTheme.dark());
      final AppPalette palette = AppPalette.dark;

      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        palette.background,
      );
      final BoxDecoration sky =
          tester
                  .widget<DecoratedBox>(find.byType(DecoratedBox).first)
                  .decoration
              as BoxDecoration;
      expect(sky.gradient, palette.splashGradient);
    });
  });

  group('Permissions Landscape (Phase 4B.3A)', () {
    testWidgets('800x360 uses two columns with side-by-side buttons', (
      tester,
    ) async {
      final gateway = FakePermissionGateway();
      final calls = await _pumpPermissions(
        tester,
        gateway,
        size: const Size(800, 360),
      );
      expect(tester.takeException(), isNull);

      final Rect illustration = tester.getRect(
        find.byKey(PermissionsScreen.illustrationKey),
      );
      final Rect notNow = tester.getRect(
        find.byKey(PermissionsScreen.notNowButtonKey),
      );
      final Rect primary = tester.getRect(
        find.byKey(PermissionsScreen.primaryButtonKey),
      );

      // Two-column layout: Buttons in right column sit to the right of the illustration.
      expect(notNow.left, greaterThan(illustration.right));
      expect(primary.left, greaterThan(notNow.right - 1.0));

      // Buttons are arranged horizontally side-by-side with constrained width.
      expect(notNow.width, lessThanOrEqualTo(250));
      expect(primary.width, lessThanOrEqualTo(250));
      expect(notNow.height, greaterThanOrEqualTo(48));
      expect(primary.height, greaterThanOrEqualTo(48));

      // Tapping Not now invokes callback.
      await tester.ensureVisible(find.byKey(PermissionsScreen.notNowButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(PermissionsScreen.notNowButtonKey));
      expect(calls.notNow, 1);
    });

    testWidgets('915x412 and 640x360 render cleanly without overflow', (
      tester,
    ) async {
      for (final Size size in [const Size(915, 412), const Size(640, 360)]) {
        final gateway = FakePermissionGateway();
        await _pumpPermissions(tester, gateway, size: size);
        expect(tester.takeException(), isNull);
        expect(find.byKey(PermissionsScreen.primaryButtonKey), findsOneWidget);
        expect(find.byKey(PermissionsScreen.notNowButtonKey), findsOneWidget);
      }
    });

    testWidgets('1.3x text scaling in landscape: zero overflow', (
      tester,
    ) async {
      final gateway = FakePermissionGateway();
      await _pumpPermissions(
        tester,
        gateway,
        size: const Size(800, 360),
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('permanentlyDenied state renders Open Settings in landscape', (
      tester,
    ) async {
      final gateway = FakePermissionGateway(
        location: PermissionAccess.permanentlyDenied,
      );
      await _pumpPermissions(tester, gateway, size: const Size(800, 360));

      expect(find.text(AppStrings.locationDeniedHeading), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(PermissionsScreen.primaryButtonKey),
          matching: find.text(AppStrings.openAppSettings),
        ),
        findsOneWidget,
      );
    });

    testWidgets('servicesOff state renders Check Again in landscape', (
      tester,
    ) async {
      final gateway = FakePermissionGateway(
        location: PermissionAccess.granted,
        servicesEnabled: false,
      );
      await _pumpPermissions(tester, gateway, size: const Size(800, 360));

      expect(find.text(AppStrings.servicesOffHeading), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(PermissionsScreen.primaryButtonKey),
          matching: find.text(AppStrings.checkAgain),
        ),
        findsOneWidget,
      );
    });

    testWidgets('dark theme renders properly in landscape', (tester) async {
      final gateway = FakePermissionGateway();
      await _pumpPermissions(
        tester,
        gateway,
        size: const Size(800, 360),
        theme: AppTheme.dark(),
      );
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        AppPalette.dark.background,
      );
    });
  });

  group('Settings Landscape (Phase 4B.3A)', () {
    testWidgets('800x360 renders Permissions and About cards side-by-side', (
      tester,
    ) async {
      final gateway = FakePermissionGateway();
      await _pumpSettings(tester, gateway, size: const Size(800, 360));
      expect(tester.takeException(), isNull);

      final Rect permCard = tester.getRect(
        find.byKey(SettingsScreen.rowKey(SettingsPermissionRow.location)),
      );
      final Rect aboutCard = tester.getRect(
        find.byKey(SettingsScreen.versionKey),
      );

      // Side-by-side columns: About card sits to the right of the Permissions card.
      expect(aboutCard.left, greaterThan(permCard.right));

      // Manage permissions button does not stretch across 800dp.
      final Rect manageBtn = tester.getRect(
        find.byKey(SettingsScreen.manageButtonKey),
      );
      expect(manageBtn.width, lessThanOrEqualTo(400));
    });

    testWidgets('915x412 and 640x360 render cleanly without overflow', (
      tester,
    ) async {
      for (final Size size in [const Size(915, 412), const Size(640, 360)]) {
        final gateway = FakePermissionGateway();
        await _pumpSettings(tester, gateway, size: size);
        expect(tester.takeException(), isNull);
        expect(find.byKey(SettingsScreen.manageButtonKey), findsOneWidget);
        expect(find.byKey(SettingsScreen.versionKey), findsOneWidget);
      }
    });

    testWidgets('1.3x text scaling in landscape: zero overflow', (
      tester,
    ) async {
      final gateway = FakePermissionGateway();
      await _pumpSettings(
        tester,
        gateway,
        size: const Size(800, 360),
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'tapping manage permissions and back invokes callbacks in landscape',
      (tester) async {
        final gateway = FakePermissionGateway();
        final calls = await _pumpSettings(
          tester,
          gateway,
          size: const Size(800, 360),
        );

        await tester.ensureVisible(find.byKey(SettingsScreen.manageButtonKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(SettingsScreen.manageButtonKey));
        expect(calls.manage, 1);

        await tester.tap(find.byKey(SettingsScreen.backButtonKey));
        expect(calls.back, 1);
      },
    );

    testWidgets('dark theme renders night surfaces in landscape', (
      tester,
    ) async {
      final gateway = FakePermissionGateway();
      await _pumpSettings(
        tester,
        gateway,
        size: const Size(800, 360),
        theme: AppTheme.dark(),
      );
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        AppPalette.dark.background,
      );
    });
  });

  group('Navigation Drawer Landscape (Phase 4B.3A)', () {
    testWidgets('drawer fits 800x360 with all 3 destination items on screen', (
      tester,
    ) async {
      await _pumpDrawer(tester, size: const Size(800, 360));
      expect(tester.takeException(), isNull);

      final Rect drawer = tester.getRect(find.byType(Drawer));
      expect(drawer.width, AppNavigationDrawer.width);

      // All 3 items fit inside 360dp height without scrolling off-screen.
      for (final AppDestination d in AppDestination.values) {
        final Rect tile = tester.getRect(
          find.byKey(AppNavigationDrawer.destinationKey(d)),
        );
        expect(tile.bottom, lessThanOrEqualTo(360));
        expect(tile.height, greaterThanOrEqualTo(48)); // 48dp touch target rule
      }

      // Close button is accessible.
      expect(find.byKey(AppNavigationDrawer.closeButtonKey), findsOneWidget);
      await tester.tap(find.byKey(AppNavigationDrawer.closeButtonKey));
      await tester.pumpAndSettle();
      expect(find.byType(AppNavigationDrawer), findsNothing);
    });

    testWidgets('navigating to history invokes callback', (tester) async {
      final calls = await _pumpDrawer(tester, size: const Size(800, 360));

      await tester.tap(
        find.byKey(AppNavigationDrawer.destinationKey(AppDestination.history)),
      );
      await tester.pumpAndSettle();

      expect(calls.history, 1);
    });

    testWidgets('1.3x text scaling in landscape: zero overflow', (
      tester,
    ) async {
      await _pumpDrawer(tester, size: const Size(800, 360), textScale: 1.3);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dark theme drawer uses night palette in landscape', (
      tester,
    ) async {
      await _pumpDrawer(
        tester,
        size: const Size(800, 360),
        theme: AppTheme.dark(),
      );
      expect(
        tester.widget<Drawer>(find.byType(Drawer)).backgroundColor,
        AppPalette.dark.surface,
      );
    });
  });
}
