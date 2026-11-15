// Road Runner — Material theme.
// Owner: Tharushi
// SRS reference: Section 8.4, FR-70, NFR-09
//
// Builds one ThemeData from the tokens in app_colors.dart,
// app_text_styles.dart and app_spacing.dart. Screens should read colours
// and styles from Theme.of(context) or the token classes — never hardcode
// hex values or font sizes.

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';

/// The Road Runner Material 3 theme.
class AppTheme {
  AppTheme._();

  /// Every foreground/background pair here is checked by
  /// test/core/theme/contrast_test.dart.
  static const ColorScheme colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.burntOrangeDeep,
    onPrimary: AppColors.white,
    secondary: AppColors.duskPinkDeep,
    onSecondary: AppColors.white,
    secondaryContainer: AppColors.duskPink,
    onSecondaryContainer: AppColors.canyonBrownDeep,
    tertiary: AppColors.tealDeep,
    onTertiary: AppColors.white,
    error: AppColors.error,
    onError: AppColors.white,
    surface: AppColors.sand,
    onSurface: AppColors.canyonBrown,
    onSurfaceVariant: AppColors.canyonBrownMuted,
    surfaceContainerLow: AppColors.sandLight,
    outline: AppColors.canyonBrownMuted,
  );

  /// Minimum size for every button (NFR-09: 48dp tap targets).
  static const Size _minButtonSize = Size.square(AppSpacing.minTouchTarget);

  /// Large rounded buttons from the UI kit: 56dp tall, never under 48dp wide.
  static const Size _minLargeButtonSize = Size(
    AppSpacing.minTouchTarget,
    AppSpacing.buttonHeight,
  );

  static const EdgeInsets _buttonPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.large,
    vertical: AppSpacing.small,
  );

  /// The light theme used by the whole app.
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.sand,
      textTheme: AppTextStyles.textTheme,
      // Keep Material's 48dp invisible tap area around small controls.
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      appBarTheme: const AppBarThemeData(
        backgroundColor: AppColors.sand,
        foregroundColor: AppColors.canyonBrown,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: AppTextStyles.sectionHeading,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.sandLight,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(AppSpacing.radiusCard),
          ),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.sandLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(AppSpacing.radiusLarge),
          ),
        ),
        titleTextStyle: AppTextStyles.sectionHeading,
        contentTextStyle: AppTextStyles.body,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      // Primary action (e.g. "Allow Location Access"): large pill.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: _minLargeButtonSize,
          padding: _buttonPadding,
          textStyle: AppTextStyles.button,
          shape: const StadiumBorder(),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: _minButtonSize,
          padding: _buttonPadding,
          textStyle: AppTextStyles.button,
        ),
      ),
      // Secondary action (e.g. "Not Now", "Cancel"): large outlined pill.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: _minLargeButtonSize,
          padding: _buttonPadding,
          textStyle: AppTextStyles.button,
          shape: const StadiumBorder(),
          foregroundColor: AppColors.canyonBrown,
          backgroundColor: AppColors.sandLight,
          side: const BorderSide(color: AppColors.burntOrangeDeep, width: 1.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: _minButtonSize,
          padding: _buttonPadding,
          textStyle: AppTextStyles.button,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: _minButtonSize),
      ),
    );
  }
}
