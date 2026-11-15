// Road Runner — WCAG contrast tests for the theme.
// Owner: Tharushi
// SRS reference: Section 8.4, NFR-09 ("Text contrast 4.5:1 or better")

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/core/theme/app_colors.dart';
import 'package:road_runner/core/theme/app_text_styles.dart';
import 'package:road_runner/core/theme/app_theme.dart';

/// NFR-09 minimum contrast for all text.
const double kMinTextContrast = 4.5;

/// WCAG 2 contrast ratio: (lighter + 0.05) / (darker + 0.05).
/// Result is between 1.0 (same colour) and 21.0 (black on white).
///
/// Only valid for fully opaque colours. `computeLuminance()` ignores alpha,
/// so a 50%-transparent colour would be measured as if it were solid, and
/// the ratio would be wrong. Throws [ArgumentError] instead of guessing.
double contrastRatio(Color a, Color b) {
  for (final Color c in [a, b]) {
    if (c.a != 1.0) {
      throw ArgumentError.value(
        c,
        'color',
        'contrastRatio needs opaque colours (alpha = 1.0); blend '
            'transparent colours onto their background first',
      );
    }
  }
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void expectReadable(Color foreground, Color background, String pair) {
  final double ratio = contrastRatio(foreground, background);
  expect(
    ratio,
    greaterThanOrEqualTo(kMinTextContrast),
    reason:
        '$pair contrast is ${ratio.toStringAsFixed(2)}:1, '
        'needs $kMinTextContrast:1 (NFR-09)',
  );
}

void main() {
  group('contrastRatio helper', () {
    test('black on white is 21:1', () {
      expect(
        contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
        closeTo(21.0, 0.01),
      );
    });

    test('a colour on itself is 1:1', () {
      expect(
        contrastRatio(AppColors.sand, AppColors.sand),
        closeTo(1.0, 0.001),
      );
    });

    test('order of arguments does not matter', () {
      expect(
        contrastRatio(AppColors.canyonBrown, AppColors.sand),
        contrastRatio(AppColors.sand, AppColors.canyonBrown),
      );
    });

    test('rejects partially transparent colours', () {
      final Color halfSand = AppColors.sand.withValues(alpha: 0.5);
      expect(
        () => contrastRatio(halfSand, AppColors.canyonBrown),
        throwsArgumentError,
      );
      expect(
        () => contrastRatio(AppColors.canyonBrown, halfSand),
        throwsArgumentError,
      );
    });
  });

  group('ColorScheme pairs used by Material widgets', () {
    final ColorScheme scheme = AppTheme.light().colorScheme;

    test('text on main background (surface)', () {
      expectReadable(scheme.onSurface, scheme.surface, 'onSurface/surface');
      expectReadable(
        scheme.onSurfaceVariant,
        scheme.surface,
        'onSurfaceVariant/surface',
      );
    });

    test('text on filled buttons and chips', () {
      expectReadable(scheme.onPrimary, scheme.primary, 'onPrimary/primary');
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
    });

    test('accent colours used as text (TextButton, error messages)', () {
      expectReadable(scheme.primary, scheme.surface, 'primary/surface');
      expectReadable(scheme.secondary, scheme.surface, 'secondary/surface');
      expectReadable(scheme.tertiary, scheme.surface, 'tertiary/surface');
      expectReadable(scheme.error, scheme.surface, 'error/surface');
    });

    test('text on cards', () {
      final Color card = AppTheme.light().cardTheme.color!;
      expectReadable(scheme.onSurface, card, 'onSurface/card');
      expectReadable(scheme.onSurfaceVariant, card, 'onSurfaceVariant/card');
      expectReadable(scheme.primary, card, 'primary/card');
      expectReadable(scheme.tertiary, card, 'tertiary/card');
    });

    test('app bar title', () {
      final AppBarThemeData appBar = AppTheme.light().appBarTheme;
      expectReadable(
        appBar.foregroundColor!,
        appBar.backgroundColor!,
        'appBar foreground/background',
      );
    });
  });

  group('Text styles on the backgrounds they are used on', () {
    const Map<String, TextStyle> styles = {
      'heading': AppTextStyles.heading,
      'sectionHeading': AppTextStyles.sectionHeading,
      'body': AppTextStyles.body,
      'caption': AppTextStyles.caption,
      'statLarge': AppTextStyles.statLarge,
      'statMedium': AppTextStyles.statMedium,
      'liveTimer': AppTextStyles.liveTimer,
      'livePace': AppTextStyles.livePace,
      'statValue': AppTextStyles.statValue,
    };

    for (final MapEntry<String, TextStyle> entry in styles.entries) {
      test('${entry.key} is readable on sand and on cards', () {
        expectReadable(entry.value.color!, AppColors.sand, '${entry.key}/sand');
        expectReadable(
          entry.value.color!,
          AppColors.sandLight,
          '${entry.key}/sandLight',
        );
      });
    }
  });

  group('UI kit: live blue (live running information)', () {
    test('liveBlue text on sand and on cards', () {
      expectReadable(AppColors.liveBlue, AppColors.sand, 'liveBlue/sand');
      expectReadable(
        AppColors.liveBlue,
        AppColors.sandLight,
        'liveBlue/sandLight',
      );
    });

    test('liveBlue text on its own 10% tint (Live / GPS pill on a card)', () {
      final Color pill = Color.alphaBlend(
        AppColors.liveBlue.withValues(alpha: 0.10),
        AppColors.sandLight,
      );
      expectReadable(AppColors.liveBlue, pill, 'liveBlue/liveBlue 10% pill');
    });

    test('white text on a liveBlue fill', () {
      expectReadable(AppColors.white, AppColors.liveBlue, 'white/liveBlue');
    });
  });

  group('UI kit: header sky gradient', () {
    // Gradient stops: skyTop -> skyMid -> sand. Text must be readable at
    // every stop, so check each one.
    for (final MapEntry<String, Color> stop in {
      'skyTop': AppColors.skyTop,
      'skyMid': AppColors.skyMid,
      'sand': AppColors.sand,
    }.entries) {
      test('canyonBrown text is readable on ${stop.key}', () {
        expectReadable(
          AppColors.canyonBrown,
          stop.value,
          'canyonBrown/${stop.key}',
        );
        expectReadable(
          AppTextStyles.heading.color!,
          stop.value,
          'heading/${stop.key}',
        );
      });
    }

    // Records WHY sky text must use canyonBrown and not the muted caption
    // colour: canyonBrownMuted on skyTop is only 4.06:1.
    test('canyonBrownMuted fails on skyTop, so sky text uses canyonBrown', () {
      expect(
        contrastRatio(AppColors.canyonBrownMuted, AppColors.skyTop),
        lessThan(kMinTextContrast),
      );
    });
  });

  group('UI kit: icon tiles and dividers', () {
    test('text on an icon tile uses canyonBrownDeep', () {
      expectReadable(
        AppColors.canyonBrownDeep,
        AppColors.iconTile,
        'canyonBrownDeep/iconTile',
      );
    });

    test('burntOrangeDeep icons on an icon tile meet 3:1 (non-text)', () {
      expect(
        contrastRatio(AppColors.burntOrangeDeep, AppColors.iconTile),
        greaterThanOrEqualTo(3.0),
      );
    });

    // Records WHY step numbers on tiles must not use burntOrangeDeep.
    test('burntOrangeDeep fails as text on an icon tile', () {
      expect(
        contrastRatio(AppColors.burntOrangeDeep, AppColors.iconTile),
        lessThan(kMinTextContrast),
      );
    });

    test('divider is canyonBrown at 12% opacity (decoration only)', () {
      expect(AppColors.divider.withValues(alpha: 1.0), AppColors.canyonBrown);
      expect(AppColors.divider.a, closeTo(0.12, 0.005));
    });
  });

  group('UI kit: component colours', () {
    test('outlined button label is readable on its fill', () {
      final ButtonStyle style = AppTheme.light().outlinedButtonTheme.style!;
      final Color fg = style.foregroundColor!.resolve(<WidgetState>{})!;
      final Color bg = style.backgroundColor!.resolve(<WidgetState>{})!;
      expectReadable(fg, bg, 'outlinedButton foreground/background');
      expectReadable(fg, AppColors.sand, 'outlinedButton foreground/sand');
    });

    test('dialog text is readable on the dialog background', () {
      final DialogThemeData dialog = AppTheme.light().dialogTheme;
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
    });
  });

  group('Why the deep variants exist', () {
    // Records WHY AppColors has darker "text-safe" variants.
    //
    // The SRS §8.4 palette is kept unchanged for brand identity (FR-70),
    // but used directly as text pairs it fails NFR-09's 4.5:1 rule:
    //   white on burntOrange  3.66:1  -> buttons use burntOrangeDeep (5.90:1)
    //   accentTeal on sand    2.66:1  -> live stats use tealDeep     (4.84:1)
    //   canyonBrown on pink   4.06:1  -> pink fills use canyonBrownDeep (5.60:1)
    //
    // Brand colours stay for fills and decoration only. If this test ever
    // fails, a brand colour was changed: check with the team, and re-check
    // whether the deep variants are still needed.
    test('original brand colours fail 4.5:1 as text pairs', () {
      expect(
        contrastRatio(AppColors.white, AppColors.burntOrange),
        lessThan(kMinTextContrast),
      );
      expect(
        contrastRatio(AppColors.accentTeal, AppColors.sand),
        lessThan(kMinTextContrast),
      );
      expect(
        contrastRatio(AppColors.canyonBrown, AppColors.duskPink),
        lessThan(kMinTextContrast),
      );
    });
  });
}
