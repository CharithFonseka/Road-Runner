// Road Runner — typography tokens.
// Owner: Tharushi
// SRS reference: Section 8.4, NFR-09
//
// Uses the platform default font (Roboto on Android) — no extra packages.
// Sizes are in sp, so they grow when the user increases system font size.

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Text styles for the Road Runner design system.
class AppTextStyles {
  AppTextStyles._();

  /// Smallest size allowed for main running statistics (NFR-09).
  static const double minStatFontSize = 32.0;

  /// Screen titles, e.g. "History".
  static const TextStyle heading = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.25,
    color: AppColors.canyonBrown,
  );

  /// Section titles inside a screen, e.g. "Splits".
  static const TextStyle sectionHeading = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: AppColors.canyonBrown,
  );

  /// Normal paragraph and list text.
  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.canyonBrown,
  );

  /// Small helper text, e.g. stat labels and dates.
  static const TextStyle caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppColors.canyonBrownMuted,
  );

  /// Button labels — slightly larger and bolder for outdoor reading.
  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  /// The most important live number on the Run screen (elapsed time).
  ///
  /// Tabular figures give every digit the same width, so the number does
  /// not shift left and right as it changes every second.
  static const TextStyle statLarge = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w700,
    height: 1.1,
    color: AppColors.tealDeep,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Other live numbers (distance, speed, pace). Exactly the NFR-09 minimum.
  static const TextStyle statMedium = TextStyle(
    fontSize: minStatFontSize,
    fontWeight: FontWeight.w700,
    height: 1.1,
    color: AppColors.tealDeep,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// The styles above mapped onto Material's [TextTheme], so built-in
  /// widgets (AppBar, ListTile, dialogs) pick them up automatically.
  static const TextTheme textTheme = TextTheme(
    displayLarge: statLarge,
    displayMedium: statMedium,
    headlineMedium: heading,
    titleLarge: sectionHeading,
    bodyLarge: body,
    bodyMedium: body,
    bodySmall: caption,
    labelLarge: button,
  );
}
