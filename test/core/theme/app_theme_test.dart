// Road Runner — theme structure tests (sizes, tap targets, brand palette).
// Owner: Tharushi
// SRS reference: Section 8.4, FR-70, NFR-09

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/core/theme/app_colors.dart';
import 'package:road_runner/core/theme/app_spacing.dart';
import 'package:road_runner/core/theme/app_text_styles.dart';
import 'package:road_runner/core/theme/app_theme.dart';

void main() {
  group('Brand palette (SRS §8.4) is unchanged', () {
    test('five brand colours keep their SRS values', () {
      expect(AppColors.sand, const Color(0xFFF4E4C8));
      expect(AppColors.burntOrange, const Color(0xFFD9622B));
      expect(AppColors.duskPink, const Color(0xFFE58C8A));
      expect(AppColors.canyonBrown, const Color(0xFF5B3A29));
      expect(AppColors.accentTeal, const Color(0xFF2A9D8F));
    });
  });

  group('NFR-09: main stats at least 32sp', () {
    test('stat styles are 32sp or larger', () {
      expect(AppTextStyles.statLarge.fontSize, greaterThanOrEqualTo(32));
      expect(AppTextStyles.statMedium.fontSize, greaterThanOrEqualTo(32));
    });

    test('stat styles use tabular figures so digits do not jump', () {
      expect(
        AppTextStyles.statLarge.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      expect(
        AppTextStyles.statMedium.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    });
  });

  group('UI kit live and saved stat styles', () {
    test('live styles are 32sp or larger and use tabular figures', () {
      expect(AppTextStyles.liveTimer.fontSize, 62);
      for (final TextStyle style in [
        AppTextStyles.liveTimer,
        AppTextStyles.livePace,
      ]) {
        expect(
          style.fontSize,
          greaterThanOrEqualTo(AppTextStyles.minStatFontSize),
        );
        expect(style.fontWeight, FontWeight.w700);
        expect(style.color, AppColors.liveBlue);
        expect(
          style.fontFeatures,
          contains(const FontFeature.tabularFigures()),
        );
      }
    });

    test('saved-run statValue is teal, 20sp bold', () {
      expect(AppTextStyles.statValue.fontSize, 20);
      expect(AppTextStyles.statValue.fontWeight, FontWeight.w700);
      expect(AppTextStyles.statValue.color, AppColors.tealDeep);
    });

    test('existing statLarge / statMedium are kept unchanged', () {
      expect(AppTextStyles.statLarge.fontSize, 48);
      expect(AppTextStyles.statLarge.color, AppColors.tealDeep);
      expect(AppTextStyles.statMedium.fontSize, 32);
      expect(AppTextStyles.statMedium.color, AppColors.tealDeep);
    });
  });

  group('UI kit component shapes', () {
    final ThemeData theme = AppTheme.light();

    test('cards have 20dp rounded corners', () {
      final RoundedRectangleBorder shape =
          theme.cardTheme.shape! as RoundedRectangleBorder;
      expect(
        shape.borderRadius,
        const BorderRadius.all(Radius.circular(AppSpacing.radiusCard)),
      );
    });

    test('dialogs have 28dp corners on the light card colour', () {
      final RoundedRectangleBorder shape =
          theme.dialogTheme.shape! as RoundedRectangleBorder;
      expect(
        shape.borderRadius,
        const BorderRadius.all(Radius.circular(AppSpacing.radiusLarge)),
      );
      expect(theme.dialogTheme.backgroundColor, AppColors.sandLight);
    });

    test('filled and outlined buttons are pills', () {
      expect(
        theme.filledButtonTheme.style!.shape!.resolve(<WidgetState>{}),
        isA<StadiumBorder>(),
      );
      expect(
        theme.outlinedButtonTheme.style!.shape!.resolve(<WidgetState>{}),
        isA<StadiumBorder>(),
      );
    });

    test('outlined buttons have a burntOrangeDeep border', () {
      final BorderSide side = theme.outlinedButtonTheme.style!.side!.resolve(
        <WidgetState>{},
      )!;
      expect(side.color, AppColors.burntOrangeDeep);
    });

    testWidgets('filled and outlined buttons render 56dp tall', (tester) async {
      final Widget filled = FilledButton(
        onPressed: () {},
        child: const Text('Go'),
      );
      final Widget outlined = OutlinedButton(
        onPressed: () {},
        child: const Text('Not Now'),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(body: Column(children: [filled, outlined])),
        ),
      );
      expect(
        tester.getSize(find.byWidget(filled)).height,
        AppSpacing.buttonHeight,
      );
      expect(
        tester.getSize(find.byWidget(outlined)).height,
        AppSpacing.buttonHeight,
      );
    });
  });

  group('Theme configuration', () {
    final ThemeData theme = AppTheme.light();

    test('uses Material 3 and the sand background', () {
      expect(theme.useMaterial3, isTrue);
      expect(theme.scaffoldBackgroundColor, AppColors.sand);
      expect(theme.colorScheme.surface, AppColors.sand);
    });

    test('keeps padded tap targets', () {
      expect(theme.materialTapTargetSize, MaterialTapTargetSize.padded);
    });
  });

  group('NFR-09: tap targets 48dp or larger (rendered size)', () {
    Future<Size> pumpAndMeasure(
      WidgetTester tester,
      Widget button, {
      ThemeData? theme,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme ?? AppTheme.light(),
          home: Scaffold(body: Center(child: button)),
        ),
      );
      return tester.getSize(find.byWidget(button));
    }

    final Map<String, Widget> buttons = {
      'FilledButton': FilledButton(onPressed: () {}, child: const Text('Go')),
      'ElevatedButton': ElevatedButton(
        onPressed: () {},
        child: const Text('Go'),
      ),
      'OutlinedButton': OutlinedButton(
        onPressed: () {},
        child: const Text('Go'),
      ),
      'TextButton': TextButton(onPressed: () {}, child: const Text('Go')),
      'IconButton': IconButton(onPressed: () {}, icon: const Icon(Icons.pause)),
    };

    // 1. The real app: padded tap targets + our button themes.
    for (final MapEntry<String, Widget> entry in buttons.entries) {
      testWidgets('${entry.key} is at least 48x48', (tester) async {
        final Size size = await pumpAndMeasure(tester, entry.value);
        expect(size.width, greaterThanOrEqualTo(AppSpacing.minTouchTarget));
        expect(size.height, greaterThanOrEqualTo(AppSpacing.minTouchTarget));
      });
    }

    // 2. Flutter's padded tap targets alone already give 48x48, so the
    //    tests above would pass even without our minimumSize. Turning the
    //    padding off (shrinkWrap) leaves only AppTheme's minimumSize to keep
    //    each button at 48dp.
    for (final MapEntry<String, Widget> entry in buttons.entries) {
      testWidgets('${entry.key} is at least 48x48 from AppTheme minimumSize '
          'alone (shrinkWrap)', (tester) async {
        final Size size = await pumpAndMeasure(
          tester,
          entry.value,
          theme: AppTheme.light().copyWith(
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        );
        expect(size.width, greaterThanOrEqualTo(AppSpacing.minTouchTarget));
        expect(size.height, greaterThanOrEqualTo(AppSpacing.minTouchTarget));
      });
    }

    // 3. Control: without AppTheme, shrink-wrapped buttons are smaller than
    //    48dp. This proves test 2 can fail — so when it passes, it is our
    //    minimumSize doing the work.
    for (final MapEntry<String, Widget> entry in buttons.entries) {
      testWidgets('control: default ${entry.key} is under 48dp tall '
          'without AppTheme (shrinkWrap)', (tester) async {
        final Size size = await pumpAndMeasure(
          tester,
          entry.value,
          theme: ThemeData(
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        );
        expect(
          size.height,
          lessThan(AppSpacing.minTouchTarget),
          reason:
              'Flutter default ${entry.key} height changed — the '
              'shrinkWrap tests may no longer prove that AppTheme sets the '
              'size. Re-check them.',
        );
      });
    }
  });
}
