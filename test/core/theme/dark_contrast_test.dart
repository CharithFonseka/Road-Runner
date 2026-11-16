// Road Runner — WCAG contrast tests for the dark ("moonlit desert") theme.
// Owner: Tharushi
// SRS reference: Section 8.4, NFR-09 ("Text contrast 4.5:1 or better")
//
// Text pairs need 4.5:1. Graphics and component boundaries (route lines,
// markers, button borders, icons) need 3:1 (WCAG 1.4.11). Translucent tokens
// are flattened onto the surface they sit on before measuring.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/core/theme/app_colors.dart';
import 'package:road_runner/core/theme/app_palette.dart';
import 'package:road_runner/core/theme/app_theme.dart';

import 'contrast_test.dart'
    show contrastRatio, expectReadable, kMinTextContrast;

/// WCAG 1.4.11 minimum for graphics and UI component boundaries.
const double kMinGraphicContrast = 3.0;

void expectVisibleGraphic(Color fg, Color bg, String pair) {
  final double ratio = contrastRatio(fg, bg);
  expect(
    ratio,
    greaterThanOrEqualTo(kMinGraphicContrast),
    reason: '$pair is ${ratio.toStringAsFixed(2)}:1, needs 3:1 (graphics)',
  );
}

/// Flattens a translucent [top] onto an opaque [bottom].
Color over(Color top, Color bottom) => Color.alphaBlend(top, bottom);

void main() {
  final ThemeData theme = AppTheme.dark();
  final ColorScheme scheme = theme.colorScheme;
  final AppPalette p = AppPalette.dark;

  group('Dark ColorScheme pairs used by Material widgets', () {
    test('text on background and surfaces', () {
      expectReadable(scheme.onSurface, scheme.surface, 'onSurface/surface');
      expectReadable(
        scheme.onSurfaceVariant,
        scheme.surface,
        'onSurfaceVariant/surface',
      );
      expectReadable(
        scheme.onSurface,
        scheme.surfaceContainerLow,
        'onSurface/surfaceContainerLow',
      );
      expectReadable(
        scheme.onSurfaceVariant,
        scheme.surfaceContainerLow,
        'onSurfaceVariant/surfaceContainerLow',
      );
    });

    test('text on filled colours', () {
      expectReadable(scheme.onPrimary, scheme.primary, 'onPrimary/primary');
      expectReadable(
        scheme.onPrimaryContainer,
        scheme.primaryContainer,
        'onPrimaryContainer/primaryContainer',
      );
      expectReadable(
        scheme.onSecondary,
        scheme.secondary,
        'onSecondary/secondary',
      );
      expectReadable(
        scheme.onSecondaryContainer,
        scheme.secondaryContainer,
        'onSecondaryContainer/secondaryContainer',
      );
      expectReadable(scheme.onTertiary, scheme.tertiary, 'onTertiary/tertiary');
      expectReadable(scheme.onError, scheme.error, 'onError/error');
      expectReadable(
        scheme.onInverseSurface,
        scheme.inverseSurface,
        'onInverseSurface/inverseSurface (SnackBar)',
      );
    });

    test('accent colours used as text on background and cards', () {
      for (final Color bg in [scheme.surface, scheme.surfaceContainerLow]) {
        expectReadable(scheme.primary, bg, 'primary (links)');
        expectReadable(scheme.secondary, bg, 'secondary');
        expectReadable(scheme.tertiary, bg, 'tertiary');
        expectReadable(scheme.error, bg, 'error');
      }
    });

    test('app bar, dialog and outlined button text', () {
      expectReadable(
        theme.appBarTheme.foregroundColor!,
        theme.appBarTheme.backgroundColor!,
        'appBar',
      );
      final DialogThemeData dialog = theme.dialogTheme;
      expectReadable(
        dialog.titleTextStyle!.color!,
        dialog.backgroundColor!,
        'dialog title',
      );
      expectReadable(
        dialog.contentTextStyle!.color!,
        dialog.backgroundColor!,
        'dialog content',
      );
      final ButtonStyle outlined = theme.outlinedButtonTheme.style!;
      final Color fg = outlined.foregroundColor!.resolve(<WidgetState>{})!;
      // Transparent fill: the label sits on whatever is behind the button.
      expectReadable(fg, p.background, 'outlined label/background');
      expectReadable(fg, p.surface, 'outlined label/surface (dialog)');
      final ButtonStyle filled = theme.filledButtonTheme.style!;
      expectReadable(
        filled.foregroundColor!.resolve(<WidgetState>{})!,
        filled.backgroundColor!.resolve(<WidgetState>{})!,
        'filled button label',
      );
    });

    test('text theme colours on background and cards', () {
      final TextTheme t = theme.textTheme;
      final Map<String, TextStyle?> styles = {
        'headlineMedium': t.headlineMedium,
        'titleLarge': t.titleLarge,
        'bodyLarge': t.bodyLarge,
        'bodyMedium': t.bodyMedium,
        'bodySmall': t.bodySmall,
        'displayLarge': t.displayLarge,
        'displayMedium': t.displayMedium,
      };
      for (final MapEntry<String, TextStyle?> e in styles.entries) {
        expectReadable(e.value!.color!, p.background, '${e.key}/background');
        expectReadable(e.value!.color!, p.surface, '${e.key}/surface');
      }
    });
  });

  group('Dark palette text roles', () {
    test('primary and secondary text', () {
      for (final Color bg in [p.background, p.surface, p.skyTop, p.skyMid]) {
        expectReadable(p.textPrimary, bg, 'textPrimary');
        expectReadable(p.textSecondary, bg, 'textSecondary');
      }
    });

    test('statistics on cards', () {
      expectReadable(p.stat, p.surface, 'stat/surface');
      expectReadable(p.statLive, p.surface, 'statLive/surface');
      expectReadable(p.statLive, p.background, 'statLive/background');
      expectReadable(
        p.stat,
        over(p.highlight, p.surface),
        'stat/fastest-split highlight',
      );
    });

    test('accent text (links, Paused pill on the header)', () {
      expectReadable(p.accent, p.surface, 'accent/surface');
      expectReadable(p.accent, p.background, 'accent/background');
      expectReadable(
        p.accent,
        over(p.iconTile, p.background),
        'accent/tile on background (Paused pill)',
      );
    });

    test('text on an icon tile over a card (drawer selected, steps)', () {
      expectReadable(
        p.onIconTile,
        over(p.iconTile, p.surface),
        'onIconTile/tile on surface',
      );
    });

    test('status pills and badges', () {
      expectReadable(
        p.statLive,
        over(p.statLiveTint, p.surface),
        'statLive/statLiveTint (Recording, GPS Good, Allowed)',
      );
      expectReadable(
        p.gpsWeak,
        over(p.gpsWeakTint, p.surface),
        'gpsWeak/gpsWeakTint',
      );
      expectReadable(
        p.error,
        over(p.errorTint, p.surface),
        'error/errorTint (Denied)',
      );
      expectReadable(
        p.textPrimary,
        over(p.hairline, p.surface),
        'textPrimary/hairline (unknown status)',
      );
    });

    test('primary fill labels (Stop, Slide to start, Start Run)', () {
      expectReadable(p.onPrimaryFill, p.primaryFill, 'onPrimaryFill');
      expectReadable(
        p.onPrimaryFill,
        p.primaryFillActive,
        'onPrimaryFill/Starting run',
      );
    });
  });

  group('Dark graphics (3:1)', () {
    test('route bands and markers on the night map', () {
      for (final Color c in [
        ...p.routeBands,
        p.routePlain,
        p.routeNoSpeed,
        p.routeStart,
        p.routeFinish,
      ]) {
        expectVisibleGraphic(c, p.mapBackground, 'route colour $c / map');
        expectVisibleGraphic(c, p.routeCasing, 'route colour $c / casing');
      }
    });

    test('outlined button and chip borders', () {
      expectVisibleGraphic(p.buttonOutline, p.background, 'outline/background');
      expectVisibleGraphic(p.buttonOutline, p.surface, 'outline/surface');
    });

    test('accent icons on icon tiles', () {
      expectVisibleGraphic(
        p.accent,
        over(p.iconTile, p.surface),
        'accent icon/tile',
      );
    });
  });

  group('Why the night deviations exist', () {
    // If any of these start passing, the kit value became accessible and
    // the deviation in AppDarkColors can be reconsidered.
    test('kit accent as text on its tile over a card fails 4.5:1', () {
      expect(
        contrastRatio(AppDarkColors.accent, over(p.iconTile, p.surface)),
        lessThan(kMinTextContrast),
      );
    });

    test('kit #A34A20 finish marker fails 3:1 on the night map', () {
      expect(
        contrastRatio(AppColors.burntOrangeDeep, p.mapBackground),
        lessThan(kMinGraphicContrast),
      );
    });

    test('kit #A34A20 fails as night text, so primary is the accent', () {
      expect(
        contrastRatio(AppColors.burntOrangeDeep, p.surface),
        lessThan(kMinTextContrast),
      );
      expect(
        contrastRatio(AppColors.error, p.surface),
        lessThan(kMinTextContrast),
      );
    });
  });
}
