// Road Runner — dark ("moonlit desert") theme architecture tests.
// Owner: Tharushi
// SRS reference: Section 8.4, FR-70, NFR-09
// Design reference: UI kit Revision 5
//
// Covers: kit token values, dark ThemeData properties, light-mode
// compatibility, semantic palette resolution, system light/dark selection
// at the theme layer, and shared components rendering under both themes.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/core/theme/app_colors.dart';
import 'package:road_runner/core/theme/app_palette.dart';
import 'package:road_runner/core/theme/app_spacing.dart';
import 'package:road_runner/core/theme/app_text_styles.dart';
import 'package:road_runner/core/theme/app_theme.dart';
import 'package:road_runner/features/run/widgets/status_chips.dart';
import 'package:road_runner/features/shared/app_navigation_drawer.dart';
import 'package:road_runner/features/shared/permission_status_chip.dart';
import 'package:road_runner/features/shared/skeleton_shimmer.dart';
import 'package:road_runner/features/summary/widgets/route_painter.dart';

void main() {
  group('Night tokens match UI kit Revision 5', () {
    test('surfaces and text', () {
      expect(AppDarkColors.background, const Color(0xFF171D2B));
      expect(AppDarkColors.surface, const Color(0xFF293247));
      expect(AppDarkColors.textPrimary, const Color(0xFFF3E7D6));
      expect(AppDarkColors.textSecondary, const Color(0xFFD4C5B7));
    });

    test('accents and statistics', () {
      expect(AppDarkColors.accent, const Color(0xFFE8957A));
      expect(AppDarkColors.outline, const Color(0xFF8C7768));
      expect(AppDarkColors.stat, const Color(0xFF8FE0CF));
      expect(AppDarkColors.statLive, const Color(0xFF91B4FE));
      expect(AppDarkColors.gpsWeak, const Color(0xFFFFCE29));
    });

    test('route bands and map', () {
      expect(AppDarkColors.routeSlow, const Color(0xFF91B4FE));
      expect(AppDarkColors.routeSteady, const Color(0xFFFFCE29));
      expect(AppDarkColors.routeFast, const Color(0xFFFF6D0F));
      expect(AppDarkColors.mapBackground, const Color(0xFF1F2638));
    });

    test('moonlit desert artwork', () {
      expect(AppDarkColors.skyTop, const Color(0xFF0E1430));
      expect(AppDarkColors.skyMid, const Color(0xFF1D2546));
      expect(AppDarkColors.splashTop, const Color(0xFF0B1028));
      expect(AppDarkColors.moon, const Color(0xFFEEE1CB));
      expect(AppDarkColors.mesa, const Color(0xFF3E3B66));
      expect(AppDarkColors.hills, const Color(0xFF5C3E36));
      expect(AppDarkColors.dunes, const Color(0xFF2C3347));
      expect(AppDarkColors.sandDune, const Color(0xFF232A3B));
    });

    test('translucent tokens keep the kit opacity', () {
      void expectAlpha(Color c, Color opaque, double alpha) {
        expect(c.withValues(alpha: 1), opaque);
        expect(c.a, closeTo(alpha, 0.005));
      }

      expectAlpha(AppDarkColors.iconTile, AppDarkColors.accent, 0.16);
      expectAlpha(AppDarkColors.hairline, AppDarkColors.textSecondary, 0.14);
      expectAlpha(AppDarkColors.cardBorder, AppDarkColors.textPrimary, 0.06);
      expectAlpha(AppDarkColors.skeleton, AppDarkColors.textPrimary, 0.09);
      expectAlpha(AppDarkColors.highlight, AppDarkColors.stat, 0.12);
      expectAlpha(AppDarkColors.scrim, const Color(0xFF080A12), 0.76);
      expectAlpha(AppDarkColors.iconButtonFill, AppDarkColors.surface, 0.72);
    });

    test('documented a11y deviations from the kit', () {
      // Text on tiles: lighter tint of the accent (kit accent fails 4.5:1).
      expect(AppDarkColors.accentOnTile, isNot(AppDarkColors.accent));
      // Finish marker: accent instead of #A34A20 (fails 3:1 on the map).
      expect(AppDarkColors.routeFinish, AppDarkColors.accent);
      expect(AppDarkColors.routeFinish, isNot(AppColors.burntOrangeDeep));
    });
  });

  group('Dark ThemeData', () {
    final ThemeData theme = AppTheme.dark();

    test('is a Material 3 dark theme on the night background', () {
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, AppDarkColors.background);
      expect(theme.colorScheme.surface, AppDarkColors.background);
      expect(theme.colorScheme.onSurface, AppDarkColors.textPrimary);
    });

    test('registers the dark palette', () {
      expect(theme.extension<AppPalette>(), same(AppPalette.dark));
    });

    test('cards, dialogs and drawer use the night surface', () {
      expect(theme.cardTheme.color, AppDarkColors.surface);
      expect(theme.dialogTheme.backgroundColor, AppDarkColors.surface);
      expect(theme.drawerTheme.backgroundColor, AppDarkColors.surface);
      expect(theme.colorScheme.surfaceContainerLow, AppDarkColors.surface);
    });

    test('cards and dialogs keep kit radii and gain the faint border', () {
      final card = theme.cardTheme.shape! as RoundedRectangleBorder;
      final dialog = theme.dialogTheme.shape! as RoundedRectangleBorder;
      expect(
        card.borderRadius,
        const BorderRadius.all(Radius.circular(AppSpacing.radiusCard)),
      );
      expect(
        dialog.borderRadius,
        const BorderRadius.all(Radius.circular(AppSpacing.radiusLarge)),
      );
      expect(card.side.color, AppDarkColors.cardBorder);
      expect(dialog.side.color, AppDarkColors.cardBorder);
    });

    test('snack bars are floating and carry card radius with faint border', () {
      expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
      final shape = theme.snackBarTheme.shape! as RoundedRectangleBorder;
      expect(
        shape.borderRadius,
        const BorderRadius.all(Radius.circular(AppSpacing.radiusCard)),
      );
      expect(shape.side.color, AppDarkColors.cardBorder);
    });

    test(
      'systemUiOverlayStyleFor produces readable status and nav bars (dark)',
      () {
        final SystemUiOverlayStyle overlay = AppTheme.systemUiOverlayStyleFor(
          AppPalette.dark,
        );
        expect(overlay.statusBarColor, Colors.transparent);
        expect(overlay.statusBarIconBrightness, Brightness.light);
        expect(overlay.systemNavigationBarColor, AppDarkColors.background);
        expect(overlay.systemNavigationBarIconBrightness, Brightness.light);
        expect(overlay.systemNavigationBarDividerColor, AppDarkColors.hairline);
      },
    );

    testWidgets('AppSystemUiOverlay wraps child with theme overlay', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: const AppSystemUiOverlay(
            child: Scaffold(body: Text('Running')),
          ),
        ),
      );
      final AnnotatedRegion<SystemUiOverlayStyle> region = tester
          .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
            find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
          );
      expect(region.value.statusBarIconBrightness, Brightness.light);
      expect(region.value.systemNavigationBarColor, AppDarkColors.background);
    });

    test('drawer and dialog scrims use the kit night scrim', () {
      expect(theme.drawerTheme.scrimColor, AppDarkColors.scrim);
      expect(theme.dialogTheme.barrierColor, AppDarkColors.scrim);
    });

    test('filled buttons keep the burnt-orange fill with white text', () {
      final ButtonStyle style = theme.filledButtonTheme.style!;
      expect(
        style.backgroundColor!.resolve(<WidgetState>{}),
        AppColors.burntOrangeDeep,
      );
      expect(style.foregroundColor!.resolve(<WidgetState>{}), AppColors.white);
      expect(style.shape!.resolve(<WidgetState>{}), isA<StadiumBorder>());
    });

    test('outlined buttons are transparent pills with a taupe border', () {
      final ButtonStyle style = theme.outlinedButtonTheme.style!;
      expect(
        style.backgroundColor!.resolve(<WidgetState>{}),
        Colors.transparent,
      );
      expect(
        style.foregroundColor!.resolve(<WidgetState>{}),
        AppDarkColors.textPrimary,
      );
      expect(
        style.side!.resolve(<WidgetState>{})!.color,
        AppDarkColors.outline,
      );
    });

    test('text links use the readable night accent (ColorScheme.primary)', () {
      expect(theme.colorScheme.primary, AppDarkColors.accent);
      expect(theme.colorScheme.primaryContainer, AppColors.burntOrangeDeep);
    });

    test('text theme keeps sizes and recolours by role', () {
      final TextTheme t = theme.textTheme;
      expect(t.headlineMedium!.fontSize, AppTextStyles.heading.fontSize);
      expect(t.headlineMedium!.color, AppDarkColors.textPrimary);
      expect(t.bodyLarge!.color, AppDarkColors.textPrimary);
      expect(t.bodySmall!.color, AppDarkColors.textSecondary);
      expect(t.displayMedium!.fontSize, AppTextStyles.minStatFontSize);
      expect(t.displayMedium!.color, AppDarkColors.stat);
      expect(
        theme.appBarTheme.titleTextStyle!.color,
        AppDarkColors.textPrimary,
      );
      expect(
        theme.dialogTheme.contentTextStyle!.color,
        AppDarkColors.textPrimary,
      );
    });

    test('divider uses the night hairline', () {
      expect(theme.dividerTheme.color, AppDarkColors.hairline);
    });

    test('keeps padded tap targets', () {
      expect(theme.materialTapTargetSize, MaterialTapTargetSize.padded);
    });
  });

  group('Light compatibility', () {
    final ThemeData light = AppTheme.light();

    test('light theme keeps its palette and uses shared Gotham typography', () {
      expect(light.brightness, Brightness.light);
      expect(light.colorScheme, AppTheme.colorScheme);
      expect(light.scaffoldBackgroundColor, AppColors.sand);
      // ThemeData merges the supplied TextTheme onto its typography base, so
      // compare against a plain ThemeData using the same font and text theme.
      expect(
        light.textTheme,
        ThemeData(
          useMaterial3: true,
          colorScheme: AppTheme.colorScheme,
          fontFamily: AppTextStyles.fontFamily,
          textTheme: AppTextStyles.textTheme,
        ).textTheme,
      );
      expect(light.appBarTheme.backgroundColor, AppColors.sand);
      expect(light.appBarTheme.foregroundColor, AppColors.canyonBrown);
      expect(light.appBarTheme.titleTextStyle, AppTextStyles.sectionHeading);
      expect(light.cardTheme.color, AppColors.sandLight);
      expect(
        (light.cardTheme.shape! as RoundedRectangleBorder).side,
        BorderSide.none,
      );
      expect(light.dialogTheme.backgroundColor, AppColors.sandLight);
      expect(light.dialogTheme.contentTextStyle, AppTextStyles.body);
      expect(light.dialogTheme.barrierColor, isNull);
      expect(light.drawerTheme, const DrawerThemeData());
      expect(light.dividerTheme.color, AppColors.divider);
      final ButtonStyle outlined = light.outlinedButtonTheme.style!;
      expect(
        outlined.backgroundColor!.resolve(<WidgetState>{}),
        AppColors.sandLight,
      );
      expect(
        outlined.foregroundColor!.resolve(<WidgetState>{}),
        AppColors.canyonBrown,
      );
      // Filled buttons still take their fill from ColorScheme.primary.
      expect(
        light.filledButtonTheme.style!.backgroundColor?.resolve(
          <WidgetState>{},
        ),
        isNull,
      );
    });

    test('textThemeFor(light) equals the original text theme', () {
      expect(
        AppTextStyles.textThemeFor(AppPalette.light),
        AppTextStyles.textTheme,
      );
    });

    test('light palette matches the colours light widgets draw today', () {
      final AppPalette p = AppPalette.light;
      expect(p.background, AppColors.sand);
      expect(p.surface, AppColors.sandLight);
      expect(p.textPrimary, AppColors.canyonBrown);
      expect(p.textSecondary, AppColors.canyonBrownMuted);
      expect(p.onIconTile, AppColors.canyonBrownDeep);
      expect(p.accent, AppColors.burntOrangeDeep);
      expect(p.iconTile, AppColors.iconTile);
      expect(p.stat, AppColors.tealDeep);
      expect(p.statLive, AppColors.liveBlue);
      expect(p.hairline, AppColors.divider);
      expect(p.skyTop, AppColors.skyTop);
      expect(p.skyMid, AppColors.skyMid);
      expect(p.error, AppColors.error);
      // Route map parity with RouteGeometry (summary widget).
      expect(p.routeSlow, RouteGeometry.slowColor);
      expect(p.routeSteady, RouteGeometry.steadyColor);
      expect(p.routeFast, RouteGeometry.fastColor);
      expect(p.routePlain, RouteGeometry.plainColor);
      expect(p.routeNoSpeed, RouteGeometry.noSpeedColor);
      expect(p.mapBackground, RouteGeometry.mapColor);
      expect(p.mapGrid, RouteGeometry.gridColor);
      expect(p.routeStart, RouteGeometry.startColor);
      expect(p.routeFinish, RouteGeometry.finishColor);
    });

    test('light sky gradient reproduces the existing header gradient', () {
      final LinearGradient g = AppPalette.light.skyGradient;
      expect(g.colors, [AppColors.skyTop, AppColors.skyMid, AppColors.sand]);
      expect(g.stops, [0.0, 0.52, 1.0]);
    });
  });

  group('Semantic palette resolution', () {
    test('forBrightness picks the matching palette and theme', () {
      expect(
        AppPalette.forBrightness(Brightness.light),
        same(AppPalette.light),
      );
      expect(AppPalette.forBrightness(Brightness.dark), same(AppPalette.dark));
      expect(
        AppTheme.forBrightness(Brightness.dark).brightness,
        Brightness.dark,
      );
      expect(
        AppTheme.forBrightness(Brightness.light).brightness,
        Brightness.light,
      );
    });

    test('palettes report their brightness', () {
      expect(AppPalette.light.isDark, isFalse);
      expect(AppPalette.dark.isDark, isTrue);
    });

    test('every role differs between day and night except shared fills', () {
      final AppPalette d = AppPalette.dark;
      final AppPalette l = AppPalette.light;
      expect(d.background, isNot(l.background));
      expect(d.surface, isNot(l.surface));
      expect(d.textPrimary, isNot(l.textPrimary));
      expect(d.stat, isNot(l.stat));
      expect(d.statLive, isNot(l.statLive));
      expect(d.routeBands, isNot(l.routeBands));
      // The kit keeps the primary button fill the same in both modes.
      expect(d.primaryFill, l.primaryFill);
      expect(d.onPrimaryFill, l.onPrimaryFill);
    });

    test('gradients are built from the palette', () {
      final LinearGradient sky = AppPalette.dark.skyGradient;
      expect(sky.colors, [
        AppDarkColors.skyTop,
        AppDarkColors.skyMid,
        AppDarkColors.background,
      ]);
      expect(sky.stops, [0.0, 0.55, 1.0]);
      final LinearGradient splash = AppPalette.dark.splashGradient;
      expect(splash.colors.length, splash.stops!.length);
      expect(splash.colors.first, AppDarkColors.splashTop);
      expect(splash.colors.last, AppDarkColors.background);
      expect(
        AppPalette.light.splashGradient.colors.length,
        AppPalette.light.splashGradient.stops!.length,
      );
    });

    test('lerp blends between palettes and snaps brightness at midpoint', () {
      final AppPalette mid = AppPalette.light.lerp(AppPalette.dark, 0.5);
      expect(
        mid.background,
        Color.lerp(AppColors.sand, AppDarkColors.background, 0.5),
      );
      expect(mid.splashColors.length, 4);
      expect(
        AppPalette.light.lerp(AppPalette.dark, 0).background,
        AppColors.sand,
      );
      expect(
        AppPalette.light.lerp(AppPalette.dark, 1).background,
        AppDarkColors.background,
      );
      expect(AppPalette.light.lerp(null, 0.5), same(AppPalette.light));
    });

    test('copyWith overrides only the given role', () {
      final AppPalette p = AppPalette.dark.copyWith(stat: Colors.red);
      expect(p.stat, Colors.red);
      expect(p.background, AppDarkColors.background);
    });

    Future<AppPalette> resolve(WidgetTester tester, ThemeData? theme) async {
      late AppPalette palette;
      late AppThemedTextStyles styles;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) {
              palette = context.palette;
              styles = AppTextStyles.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(styles.palette, same(palette));
      return palette;
    }

    testWidgets('context.palette resolves the dark palette', (tester) async {
      expect(await resolve(tester, AppTheme.dark()), same(AppPalette.dark));
    });

    testWidgets('context.palette resolves the light palette', (tester) async {
      expect(await resolve(tester, AppTheme.light()), same(AppPalette.light));
    });

    testWidgets('context.palette falls back to light without an AppTheme', (
      tester,
    ) async {
      expect(await resolve(tester, ThemeData()), same(AppPalette.light));
    });

    test('themed text styles keep sizes and use role colours', () {
      final AppThemedTextStyles s = AppThemedTextStyles(AppPalette.dark);
      expect(s.liveTimer.fontSize, AppTextStyles.liveTimer.fontSize);
      expect(s.liveTimer.color, AppDarkColors.statLive);
      expect(s.livePace.color, AppDarkColors.statLive);
      expect(s.statValue.color, AppDarkColors.stat);
      expect(s.caption.color, AppDarkColors.textSecondary);
      expect(s.heading.color, AppDarkColors.textPrimary);
      expect(s.livePace.fontSize, greaterThanOrEqualTo(32));
      final AppThemedTextStyles l = AppThemedTextStyles(AppPalette.light);
      expect(l.liveTimer, AppTextStyles.liveTimer);
      expect(l.statValue, AppTextStyles.statValue);
      expect(l.caption, AppTextStyles.caption);
    });
  });

  group('System light/dark selection (theme layer)', () {
    Widget app() => MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: AppTheme.themeMode,
      home: Builder(
        builder: (context) => Text(
          context.palette.isDark ? 'night' : 'day',
          textDirection: TextDirection.ltr,
        ),
      ),
    );

    test('default mode follows the system', () {
      expect(AppTheme.themeMode, ThemeMode.system);
    });

    testWidgets('system dark selects the moonlit theme', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('night'), findsOneWidget);
      final BuildContext ctx = tester.element(find.text('night'));
      expect(Theme.of(ctx).scaffoldBackgroundColor, AppDarkColors.background);
    });

    testWidgets('system light selects the sunrise theme', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('day'), findsOneWidget);
    });

    testWidgets('switching system brightness animates to the new palette', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(app());
      expect(find.text('day'), findsOneWidget);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(find.text('night'), findsOneWidget);
    });
  });

  group('Shared components render under both themes', () {
    for (final Brightness b in Brightness.values) {
      testWidgets('shared widgets build without errors (${b.name})', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.forBrightness(b),
            home: Scaffold(
              drawer: AppNavigationDrawer(
                selected: AppDestination.home,
                onOpenHome: () {},
                onOpenHistory: () {},
                onOpenSettings: () {},
              ),
              body: ListView(
                children: [
                  const PermissionStatusChip(
                    status: PermissionChipStatus.allowed,
                  ),
                  const PermissionStatusChip(
                    status: PermissionChipStatus.blocked,
                  ),
                  const GpsStatusBadge(quality: 'Weak'),
                  const SkeletonShimmer(
                    child: SkeletonShimmerBlock(
                      child: SizedBox(width: 40, height: 10),
                    ),
                  ),
                  const Card(child: Text('card')),
                  FilledButton(onPressed: () {}, child: const Text('Go')),
                  OutlinedButton(
                    onPressed: () {},
                    child: const Text('Not now'),
                  ),
                  TextButton(onPressed: () {}, child: const Text('View all')),
                ],
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        final ScaffoldState scaffold = tester.state(find.byType(Scaffold));
        scaffold.openDrawer();
        // The shimmer repeats forever, so pump fixed frames instead of
        // pumpAndSettle while the drawer slides in.
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(AppNavigationDrawer), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('dark Material buttons use the kit colours when rendered', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: Column(
              children: [
                FilledButton(onPressed: () {}, child: const Text('Go')),
                TextButton(onPressed: () {}, child: const Text('Link')),
              ],
            ),
          ),
        ),
      );
      Color textColor(String s) => tester
          .widget<RichText>(
            find.descendant(of: find.text(s), matching: find.byType(RichText)),
          )
          .text
          .style!
          .color!;
      expect(textColor('Go'), AppColors.white);
      expect(textColor('Link'), AppDarkColors.accent);
      final Material fill = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(FilledButton),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(fill.color, AppColors.burntOrangeDeep);
    });

    testWidgets('dark buttons still meet 48dp tap targets', (tester) async {
      final Map<String, Widget> buttons = {
        'filled': FilledButton(onPressed: () {}, child: const Text('Go')),
        'outlined': OutlinedButton(onPressed: () {}, child: const Text('Go')),
        'text': TextButton(onPressed: () {}, child: const Text('Go')),
        'icon': IconButton(onPressed: () {}, icon: const Icon(Icons.pause)),
      };
      for (final Widget button in buttons.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark().copyWith(
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            home: Scaffold(body: Center(child: button)),
          ),
        );
        final Size size = tester.getSize(find.byWidget(button));
        expect(size.width, greaterThanOrEqualTo(AppSpacing.minTouchTarget));
        expect(size.height, greaterThanOrEqualTo(AppSpacing.minTouchTarget));
      }
    });
  });
}
