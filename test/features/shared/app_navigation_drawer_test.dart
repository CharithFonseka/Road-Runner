// Road Runner — shared navigation drawer widget tests.
// Owner: Tharushi
// SRS reference: Section 8.4, NFR-09, NFR-14

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/core/theme/app_colors.dart';
import 'package:road_runner/core/theme/app_palette.dart';
import 'package:road_runner/core/theme/app_spacing.dart';
import 'package:road_runner/core/theme/app_theme.dart';
import 'package:road_runner/features/app_strings.dart';
import 'package:road_runner/features/shared/app_navigation_drawer.dart';

class _Calls {
  int home = 0;
  int history = 0;
  int settings = 0;
  int get total => home + history + settings;
}

final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

/// A parent screen that owns its Scaffold and the drawer, pushed on top of
/// a base page so Back has somewhere to go.
Future<_Calls> _pump(
  WidgetTester tester, {
  AppDestination selected = AppDestination.home,
  ThemeData? theme,
  Size size = const Size(360, 800),
  double textScale = 1.0,
}) async {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = size * 3.0;
  addTearDown(tester.view.reset);

  final _Calls calls = _Calls();
  final Widget host = MediaQuery.withClampedTextScaling(
    minScaleFactor: textScale,
    maxScaleFactor: textScale,
    child: Scaffold(
      key: _scaffoldKey,
      drawer: AppNavigationDrawer(
        selected: selected,
        onOpenHome: () => calls.home++,
        onOpenHistory: () => calls.history++,
        onOpenSettings: () => calls.settings++,
      ),
      body: const Center(child: Text('host page')),
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () =>
                  Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => host)),
              child: const Text('base page'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('base page'));
  await tester.pumpAndSettle();
  await _open(tester);
  return calls;
}

Future<void> _open(WidgetTester tester) async {
  _scaffoldKey.currentState!.openDrawer();
  await tester.pumpAndSettle();
}

bool _isOpen() => _scaffoldKey.currentState!.isDrawerOpen;

Finder _tile(AppDestination d) =>
    find.byKey(AppNavigationDrawer.destinationKey(d));

/// WCAG 2 contrast ratio of two opaque colours.
double _contrast(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  final double hi = la > lb ? la : lb;
  final double lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  testWidgets('dark drawer uses night surfaces and selected-state colors', (
    tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final _Calls calls = await _pump(
      tester,
      selected: AppDestination.history,
      theme: AppTheme.dark(),
    );
    final AppPalette palette = AppPalette.dark;
    expect(
      tester.widget<Drawer>(find.byType(Drawer)).backgroundColor,
      palette.surface,
    );

    final Material selected = tester.widget<Material>(
      find.descendant(
        of: _tile(AppDestination.history),
        matching: find.byType(Material),
      ),
    );
    expect(selected.color, palette.iconTile);
    final Text selectedLabel = tester.widget<Text>(
      find.descendant(
        of: _tile(AppDestination.history),
        matching: find.text(AppStrings.navHistory),
      ),
    );
    expect(selectedLabel.style!.color, palette.onIconTile);
    final Text unselectedLabel = tester.widget<Text>(
      find.descendant(
        of: _tile(AppDestination.home),
        matching: find.text(AppStrings.navHome),
      ),
    );
    expect(unselectedLabel.style!.color, palette.textPrimary);

    final CustomPaint artwork = tester.widget<CustomPaint>(
      find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.painter is DrawerLandscapePainter,
      ),
    );
    expect((artwork.painter as DrawerLandscapePainter).palette, same(palette));
    expect(
      tester.getSemantics(_tile(AppDestination.history)),
      containsSemantics(isButton: true, isSelected: true, hasTapAction: true),
    );
    await tester.tap(_tile(AppDestination.settings));
    await tester.pumpAndSettle();
    expect(calls.settings, 1);
    handle.dispose();
  });

  testWidgets('dark drawer fits a narrow screen with larger text', (
    tester,
  ) async {
    await _pump(
      tester,
      selected: AppDestination.settings,
      theme: AppTheme.dark(),
      size: const Size(320, 568),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
    final Rect drawer = tester.getRect(find.byType(Drawer));
    expect(drawer.right, lessThanOrEqualTo(320));
    for (final AppDestination destination in AppDestination.values) {
      expect(tester.getRect(_tile(destination)).bottom, lessThanOrEqualTo(568));
    }
  });

  group('Content', () {
    testWidgets('exactly three destinations: Home, History, Settings', (
      tester,
    ) async {
      await _pump(tester);
      expect(AppDestination.values, hasLength(3));
      for (final (AppDestination d, String label) in [
        (AppDestination.home, AppStrings.navHome),
        (AppDestination.history, AppStrings.navHistory),
        (AppDestination.settings, AppStrings.navSettings),
      ]) {
        expect(_tile(d), findsOneWidget);
        expect(
          find.descendant(of: _tile(d), matching: find.text(label)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: _tile(d), matching: find.byType(Icon)),
          findsOneWidget,
        );
      }
    });

    testWidgets('branding, close button and the recording note', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.text(AppStrings.appName), findsOneWidget);
      expect(find.text(AppStrings.navTagline), findsOneWidget);
      expect(find.byKey(AppNavigationDrawer.closeButtonKey), findsOneWidget);
      expect(find.text(AppStrings.navRunNote), findsOneWidget);
    });
  });

  group('Selected destination', () {
    for (final AppDestination selected in AppDestination.values) {
      testWidgets('${selected.name}: selected in semantics and visually', (
        tester,
      ) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await _pump(tester, selected: selected);
        for (final AppDestination d in AppDestination.values) {
          final bool isSel = d == selected;
          expect(
            tester.getSemantics(_tile(d)),
            containsSemantics(
              isButton: true,
              hasTapAction: true,
              isSelected: isSel,
            ),
            reason: d.name,
          );
          final Material fill = tester.widget<Material>(
            find.descendant(of: _tile(d), matching: find.byType(Material)),
          );
          expect(
            fill.color,
            isSel ? AppColors.iconTile : Colors.transparent,
            reason: d.name,
          );
          // Not colour alone: the selected row is bold too.
          final Text text = tester.widget<Text>(
            find.descendant(of: _tile(d), matching: find.byType(Text)),
          );
          expect(
            text.style!.fontWeight,
            isSel ? FontWeight.w700 : FontWeight.w500,
          );
        }
        handle.dispose();
      });
    }

    testWidgets('screen-reader labels name each destination', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester);
      expect(
        tester.getSemantics(_tile(AppDestination.home)),
        containsSemantics(label: AppStrings.navHome),
      );
      expect(
        tester.getSemantics(_tile(AppDestination.history)),
        containsSemantics(label: AppStrings.navHistory),
      );
      expect(
        tester.getSemantics(_tile(AppDestination.settings)),
        containsSemantics(label: AppStrings.navSettings),
      );
      expect(find.bySemanticsLabel(AppStrings.navMenuLabel), findsOneWidget);
      handle.dispose();
    });
  });

  group('Navigation callbacks', () {
    final Map<AppDestination, int Function(_Calls)> counters = {
      AppDestination.home: (c) => c.home,
      AppDestination.history: (c) => c.history,
      AppDestination.settings: (c) => c.settings,
    };

    for (final AppDestination selected in AppDestination.values) {
      for (final AppDestination target in AppDestination.values) {
        if (target == selected) continue;
        testWidgets('on ${selected.name}, tap ${target.name}: '
            'closes and calls only that callback once', (tester) async {
          final _Calls calls = await _pump(tester, selected: selected);
          await tester.tap(_tile(target));
          await tester.pumpAndSettle();
          expect(_isOpen(), isFalse);
          expect(counters[target]!(calls), 1);
          expect(calls.total, 1);
        });
      }
    }

    testWidgets('tapping the current destination only closes the drawer', (
      tester,
    ) async {
      final _Calls calls = await _pump(
        tester,
        selected: AppDestination.history,
      );
      await tester.tap(_tile(AppDestination.history));
      await tester.pumpAndSettle();
      expect(_isOpen(), isFalse);
      expect(calls.total, 0);
      expect(find.text('host page'), findsOneWidget);
    });

    testWidgets('double tap during the close animation navigates once', (
      tester,
    ) async {
      final _Calls calls = await _pump(tester);
      await tester.tap(_tile(AppDestination.history));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.tap(_tile(AppDestination.history), warnIfMissed: false);
      await tester.tap(_tile(AppDestination.settings), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(calls.history, 1);
      expect(calls.total, 1);
    });

    testWidgets('a touch that re-opens a closing drawer cannot navigate '
        'again, but the drawer can still be closed', (tester) async {
      final _Calls calls = await _pump(tester);
      await tester.tap(_tile(AppDestination.history));
      await tester.pump(const Duration(milliseconds: 16));
      // Touching the drawer mid-close makes Flutter settle it open again.
      await tester.tap(_tile(AppDestination.settings), warnIfMissed: false);
      await tester.pumpAndSettle();
      if (_isOpen()) {
        await tester.tap(_tile(AppDestination.settings));
        await tester.pumpAndSettle();
        expect(_isOpen(), isFalse);
      }
      expect(calls.history, 1);
      expect(calls.total, 1);
    });

    testWidgets('re-opening after a close works normally', (tester) async {
      final _Calls calls = await _pump(tester);
      await tester.tap(find.byKey(AppNavigationDrawer.closeButtonKey));
      await tester.pumpAndSettle();
      await _open(tester);
      await tester.tap(_tile(AppDestination.settings));
      await tester.pumpAndSettle();
      expect(calls.settings, 1);
      expect(calls.total, 1);
    });
  });

  group('Dismissal', () {
    testWidgets('Close button closes without navigating', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final _Calls calls = await _pump(tester);
      expect(
        tester.getSemantics(find.byKey(AppNavigationDrawer.closeButtonKey)),
        containsSemantics(tooltip: AppStrings.navCloseMenu, isButton: true),
      );
      await tester.tap(find.byKey(AppNavigationDrawer.closeButtonKey));
      await tester.pumpAndSettle();
      expect(_isOpen(), isFalse);
      expect(calls.total, 0);
      expect(find.text('host page'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('Back closes the drawer first, then leaves the page', (
      tester,
    ) async {
      final _Calls calls = await _pump(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_isOpen(), isFalse);
      expect(find.text('host page'), findsOneWidget); // still on the page
      expect(calls.total, 0);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('host page'), findsNothing);
      expect(find.text('base page'), findsOneWidget);
      expect(calls.total, 0);
    });

    testWidgets('tapping the scrim closes without navigating', (tester) async {
      final _Calls calls = await _pump(tester);
      await tester.tapAt(const Offset(340, 400)); // right of the drawer
      await tester.pumpAndSettle();
      expect(_isOpen(), isFalse);
      expect(calls.total, 0);
    });
  });

  group('Keyboard', () {
    testWidgets('Tab to a destination and press Enter', (tester) async {
      final _Calls calls = await _pump(tester);
      bool historyFocused() {
        final BuildContext? ctx = FocusManager.instance.primaryFocus?.context;
        if (ctx == null) return false;
        bool found = false;
        ctx.visitAncestorElements((e) {
          if (e.widget.key ==
              AppNavigationDrawer.destinationKey(AppDestination.history)) {
            found = true;
            return false;
          }
          return true;
        });
        return found;
      }

      for (int i = 0; i < 10 && !historyFocused(); i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      expect(historyFocused(), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(calls.history, 1);
      expect(_isOpen(), isFalse);
    });
  });

  group('Accessibility', () {
    testWidgets('meets tap-target and label guidelines', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, size: const Size(320, 568), textScale: 1.3);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('every target is at least 48dp', (tester) async {
      await _pump(tester);
      for (final Finder f in [
        find.byKey(AppNavigationDrawer.closeButtonKey),
        for (final AppDestination d in AppDestination.values) _tile(d),
      ]) {
        final Size s = tester.getSize(f);
        expect(s.height, greaterThanOrEqualTo(AppSpacing.minTouchTarget));
        expect(s.width, greaterThanOrEqualTo(AppSpacing.minTouchTarget));
      }
    });

    test('text and icon colours meet contrast rules', () {
      // Text: 4.5:1. Icons: 3:1.
      expect(
        _contrast(AppColors.canyonBrownDeep, AppColors.iconTile),
        greaterThanOrEqualTo(4.5),
      ); // selected label
      expect(
        _contrast(AppColors.canyonBrown, AppColors.sandLight),
        greaterThanOrEqualTo(4.5),
      ); // unselected label
      expect(
        _contrast(AppColors.canyonBrownMuted, AppColors.sandLight),
        greaterThanOrEqualTo(4.5),
      ); // recording note
      for (final Color sky in [
        AppColors.skyTop,
        AppColors.skyMid,
        AppColors.sand,
      ]) {
        expect(
          _contrast(AppColors.canyonBrown, sky),
          greaterThanOrEqualTo(4.5),
        ); // header name, tagline, close icon
      }
      expect(
        _contrast(AppColors.burntOrangeDeep, AppColors.iconTile),
        greaterThanOrEqualTo(3.0),
      ); // selected icon
    });
  });

  group('Layout: no overflow', () {
    final Map<String, (Size, double)> cases = {
      '360x800': (const Size(360, 800), 1.0),
      '320x568': (const Size(320, 568), 1.0),
      '360x800 at 1.3x text': (const Size(360, 800), 1.3),
      '320x568 at 1.3x text': (const Size(320, 568), 1.3),
    };
    for (final MapEntry<String, (Size, double)> c in cases.entries) {
      testWidgets(c.key, (tester) async {
        final Size size = c.value.$1;
        await _pump(tester, size: size, textScale: c.value.$2);
        expect(tester.takeException(), isNull);
        final Rect drawer = tester.getRect(find.byType(Drawer));
        expect(drawer.right, lessThanOrEqualTo(size.width));
        for (final AppDestination d in AppDestination.values) {
          final Rect r = tester.getRect(_tile(d));
          expect(r.bottom, lessThanOrEqualTo(size.height), reason: d.name);
          expect(r.right, lessThanOrEqualTo(drawer.right), reason: d.name);
        }
        final RenderParagraph note = tester.renderObject<RenderParagraph>(
          find.text(AppStrings.navRunNote),
        );
        expect(note.didExceedMaxLines, isFalse);
      });
    }

    testWidgets('respects status bar and gesture bar insets', (tester) async {
      tester.view.padding = const FakeViewPadding(top: 32 * 3, bottom: 24 * 3);
      addTearDown(tester.view.resetPadding);
      await _pump(tester, size: const Size(360, 800));
      final Rect name = tester.getRect(find.text(AppStrings.appName));
      final Rect note = tester.getRect(find.text(AppStrings.navRunNote));
      expect(name.top, greaterThanOrEqualTo(32));
      expect(note.bottom, lessThanOrEqualTo(800 - 24));
      expect(tester.takeException(), isNull);
    });
  });
}
