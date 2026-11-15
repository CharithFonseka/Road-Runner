// Road Runner — Permissions Revision 5: runner illustrations, scenes,
// Back, and system insets.
// Owner: Tharushi
// SRS reference: Section 8.4, FR-40, FR-41, NFR-09

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/core/theme/app_spacing.dart';
import 'package:road_runner/core/theme/app_theme.dart';
import 'package:road_runner/features/app_strings.dart';
import 'package:road_runner/features/permissions/permission_gateway.dart';
import 'package:road_runner/features/permissions/permissions_controller.dart';
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
  bool withBack = true,
  Size size = const Size(360, 800),
}) async {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = size * 3.0;
  addTearDown(tester.view.reset);
  final _Calls c = _Calls();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: PermissionsScreen(
        gateway: gateway,
        onContinue: () => c.continued++,
        onNotNow: () => c.notNow++,
        onBack: withBack ? () => c.back++ : null,
      ),
    ),
  );
  await tester.pump();
  return c;
}

/// Asset name drawn by a figure.
String _assetOf(WidgetTester tester, Key key) {
  final Image image = tester.widget<Image>(
    find.descendant(of: find.byKey(key), matching: find.byType(Image)),
  );
  return (image.image as AssetImage).assetName;
}

/// Pixel size from a PNG header.
(int, int) _pngSize(Uint8List bytes) {
  final ByteData d = ByteData.sublistView(bytes);
  return (d.getUint32(16), d.getUint32(20));
}

Map<String, FakePermissionGateway Function()> _scenes = {
  'explain': FakePermissionGateway.new,
  'location denied (ordinary)': () =>
      FakePermissionGateway()..locationAnswer = PermissionAccess.denied,
  'location blocked': () =>
      FakePermissionGateway(location: PermissionAccess.permanentlyDenied),
  'services off': () => FakePermissionGateway(
    location: PermissionAccess.granted,
    notification: PermissionAccess.granted,
    servicesEnabled: false,
  ),
};

PermissionScene _expectedScene(String name) => switch (name) {
  'explain' => PermissionScene.explain,
  'services off' => PermissionScene.servicesOff,
  _ => PermissionScene.locationDenied,
};

Future<void> _enterScene(
  WidgetTester tester,
  String name,
  FakePermissionGateway g,
) async {
  if (name == 'location denied (ordinary)') {
    await tester.tap(find.byKey(PermissionsScreen.primaryButtonKey));
    await tester.pump();
  }
}

void main() {
  group('Asset files', () {
    test('all four illustrations exist at 1x, 2x, 3x and 4x', () {
      for (final String path in RunnerAssets.all) {
        final File base = File(path);
        expect(base.existsSync(), isTrue, reason: path);
        final (int w1, int h1) = _pngSize(base.readAsBytesSync());
        expect(h1, 128, reason: path);
        for (final (int i, String density) in RunnerAssets.densities.indexed) {
          final String file = path.replaceFirst(
            '${RunnerAssets.folder}/',
            '${RunnerAssets.folder}/$density/',
          );
          final File f = File(file);
          expect(f.existsSync(), isTrue, reason: file);
          final (int w, int h) = _pngSize(f.readAsBytesSync());
          expect(h, 128 * (i + 2), reason: file);
          // Same artwork at a higher density: aspect ratio preserved.
          expect(w / h, closeTo(w1 / h1, 0.02), reason: file);
        }
      }
    });

    testWidgets('every variant is bundled and loads', (tester) async {
      await tester.runAsync(() async {
        for (final String path in RunnerAssets.all) {
          for (final String p in [
            path,
            for (final String d in RunnerAssets.densities)
              path.replaceFirst(
                '${RunnerAssets.folder}/',
                '${RunnerAssets.folder}/$d/',
              ),
          ]) {
            final ByteData data = await rootBundle.load(p);
            expect(data.lengthInBytes, greaterThan(0), reason: p);
          }
        }
      });
    });

    testWidgets('a 3x phone resolves the 3.0x files', (tester) async {
      await tester.runAsync(() async {
        for (final String path in RunnerAssets.all) {
          final AssetBundleImageKey key = await AssetImage(path).obtainKey(
            ImageConfiguration(bundle: rootBundle, devicePixelRatio: 3),
          );
          expect(key.name, contains('/3.0x/'), reason: path);
          expect(key.scale, 3);
        }
      });
    });
  });

  group('Scenes and figures', () {
    for (final MapEntry<String, FakePermissionGateway Function()> e
        in _scenes.entries) {
      testWidgets('${e.key}: both figures, correct pose', (tester) async {
        final FakePermissionGateway g = e.value();
        await _pump(tester, g);
        await _enterScene(tester, e.key, g);

        final PermissionScene scene = _expectedScene(e.key);
        expect(
          tester
              .widget<PermissionIllustration>(
                find.byKey(PermissionsScreen.illustrationKey),
              )
              .scene,
          scene,
        );
        final bool running = scene == PermissionScene.explain;
        expect(
          _assetOf(tester, PermissionIllustration.femaleKey),
          running ? RunnerAssets.femaleRunning : RunnerAssets.femaleStanding,
        );
        expect(
          _assetOf(tester, PermissionIllustration.maleKey),
          running ? RunnerAssets.maleRunning : RunnerAssets.maleStanding,
        );
        // Both visible, side by side, female first as in the kit.
        final Rect f = tester.getRect(
          find.byKey(PermissionIllustration.femaleKey),
        );
        final Rect m = tester.getRect(
          find.byKey(PermissionIllustration.maleKey),
        );
        expect(f.left, lessThan(m.left));
        expect(f.height, closeTo(PermissionIllustration.figureHeight, 0.5));
        expect(m.height, closeTo(PermissionIllustration.figureHeight, 0.5));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('artwork is hidden from screen readers', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, FakePermissionGateway());
      for (final Key k in [
        PermissionIllustration.femaleKey,
        PermissionIllustration.maleKey,
      ]) {
        final Image image = tester.widget<Image>(
          find.descendant(of: find.byKey(k), matching: find.byType(Image)),
        );
        expect(image.excludeFromSemantics, isTrue);
        expect(
          find.ancestor(
            of: find.byKey(k),
            matching: find.byWidgetPredicate(
              (w) => w is ExcludeSemantics && w.excluding,
            ),
          ),
          findsWidgets,
        );
      }
      expect(find.bySemanticsLabel(RegExp('runner')), findsNothing);
      handle.dispose();
    });

    test('scene mapping follows the controller state', () {
      expect(
        PermissionsScreen.sceneFor(PermissionStep.needsLocation, null),
        PermissionScene.explain,
      );
      expect(
        PermissionsScreen.sceneFor(
          PermissionStep.needsLocation,
          PermissionIssue.locationDenied,
        ),
        PermissionScene.locationDenied,
      );
      expect(
        PermissionsScreen.sceneFor(PermissionStep.locationBlocked, null),
        PermissionScene.locationDenied,
      );
      expect(
        PermissionsScreen.sceneFor(PermissionStep.locationServicesOff, null),
        PermissionScene.servicesOff,
      );
      for (final PermissionStep s in [
        PermissionStep.checking,
        PermissionStep.checkFailed,
        PermissionStep.needsNotification,
        PermissionStep.notificationBlocked,
        PermissionStep.ready,
      ]) {
        expect(PermissionsScreen.sceneFor(s, null), PermissionScene.explain);
      }
    });
  });

  group('Explanation first', () {
    testWidgets('no system prompt until Continue is tapped', (tester) async {
      final FakePermissionGateway g = FakePermissionGateway();
      await _pump(tester, g);
      await _backgroundAndResume(tester);
      await tester.pump(const Duration(seconds: 5));
      expect(g.locationRequests + g.notificationRequests, 0);
      expect(find.text(AppStrings.permissionsIntroHeading), findsOneWidget);

      await tester.tap(find.byKey(PermissionsScreen.primaryButtonKey));
      await tester.pump();
      expect(g.locationRequests, 1);
    });
  });

  group('Navigation', () {
    testWidgets('Back calls onBack', (tester) async {
      final _Calls c = await _pump(tester, FakePermissionGateway());
      await tester.tap(find.byKey(PermissionsScreen.backButtonKey));
      await tester.pump();
      expect((c.back, c.notNow, c.continued), (1, 0, 0));
    });

    testWidgets('without onBack, Back falls back to onNotNow', (tester) async {
      final _Calls c = await _pump(
        tester,
        FakePermissionGateway(),
        withBack: false,
      );
      await tester.tap(find.byKey(PermissionsScreen.backButtonKey));
      await tester.pump();
      expect((c.back, c.notNow), (0, 1));
    });

    testWidgets('Not now calls onNotNow only', (tester) async {
      final _Calls c = await _pump(tester, FakePermissionGateway());
      await tester.tap(find.byKey(PermissionsScreen.notNowButtonKey));
      await tester.pump();
      expect((c.back, c.notNow, c.continued), (0, 1, 0));
    });

    testWidgets('no navigation drawer on Permissions', (tester) async {
      await _pump(tester, FakePermissionGateway());
      final ScaffoldState scaffold = tester.state(find.byType(Scaffold));
      expect(scaffold.hasDrawer, isFalse);
    });

    testWidgets('Back is a labelled 48dp button', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, FakePermissionGateway());
      expect(
        tester.getSemantics(find.byKey(PermissionsScreen.backButtonKey)),
        containsSemantics(
          tooltip: AppStrings.permissionsBack,
          isButton: true,
          hasTapAction: true,
        ),
      );
      final Size s = tester.getSize(
        find.byKey(PermissionsScreen.backButtonKey),
      );
      expect(s.width, greaterThanOrEqualTo(AppSpacing.minTouchTarget));
      expect(s.height, greaterThanOrEqualTo(AppSpacing.minTouchTarget));
      handle.dispose();
    });
  });

  group('System insets', () {
    for (final MapEntry<String, FakePermissionGateway Function()> e
        in _scenes.entries) {
      testWidgets('${e.key}: clear of status and navigation bars', (
        tester,
      ) async {
        const double statusBar = 32, navBar = 48;
        tester.view.padding = const FakeViewPadding(
          top: statusBar * 3,
          bottom: navBar * 3,
        );
        addTearDown(tester.view.resetPadding);
        final FakePermissionGateway g = e.value();
        await _pump(tester, g, size: const Size(320, 568));
        await _enterScene(tester, e.key, g);
        expect(tester.takeException(), isNull);
        expect(
          tester.getRect(find.byKey(PermissionsScreen.backButtonKey)).top,
          greaterThanOrEqualTo(statusBar),
        );
        expect(
          tester.getRect(find.byKey(PermissionsScreen.notNowButtonKey)).bottom,
          lessThanOrEqualTo(568 - navBar),
        );
      });
    }
  });

  group('Ordinary vs permanent denial', () {
    testWidgets('ordinary denial asks again; blocked opens app settings', (
      tester,
    ) async {
      final FakePermissionGateway g = FakePermissionGateway()
        ..locationAnswer = PermissionAccess.denied;
      await _pump(tester, g);
      await tester.tap(find.byKey(PermissionsScreen.primaryButtonKey));
      await tester.pump();
      expect(find.text(AppStrings.allowLocationAccess), findsOneWidget);
      expect(find.byKey(PermissionsScreen.stepKey(1)), findsNothing);

      // Second "Don't allow" makes it permanent on Android.
      g.locationAnswer = PermissionAccess.permanentlyDenied;
      await tester.tap(find.byKey(PermissionsScreen.primaryButtonKey));
      await tester.pump();
      expect(
        find.descendant(
          of: find.byKey(PermissionsScreen.primaryButtonKey),
          matching: find.text(AppStrings.openAppSettings),
        ),
        findsOneWidget,
      );
      for (final int n in [1, 2, 3]) {
        expect(find.byKey(PermissionsScreen.stepKey(n)), findsOneWidget);
      }
      await tester.tap(find.byKey(PermissionsScreen.primaryButtonKey));
      await tester.pump();
      expect(g.settingsCalls, 1);
      expect(g.locationRequests, 2); // never asked again once blocked
    });

    testWidgets('blocked steps are read as numbered steps', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(
        tester,
        FakePermissionGateway(location: PermissionAccess.permanentlyDenied),
      );
      expect(
        tester.getSemantics(find.byKey(PermissionsScreen.stepKey(2))),
        containsSemantics(
          label: AppStrings.stepSemantics(2, AppStrings.locationBlockedStep2),
        ),
      );
      handle.dispose();
    });
  });
}

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
  await tester.pump();
}
