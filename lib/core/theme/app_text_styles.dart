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

  /// Section and card titles, e.g. "Splits", "Last Run" (UI kit: 20 bold).
  static const TextStyle sectionHeading = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
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

  /// Button labels — larger and bold for outdoor reading (UI kit: 18 bold).
  static const TextStyle button = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
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

  // ─── UI kit live/saved stat styles ──────────────────────────────────────────
  //
  // statLarge / statMedium above are kept unchanged for compatibility.
  //
  // UNRESOLVED DESIGN CONFLICT (NFR-09): the approved UI kit shows the Run
  // screen's distance and speed at 18sp. NFR-09 requires main running
  // statistics to be at least 32sp. Do NOT add an 18sp live-stat style here.
  // The Run screen must show distance and speed at [minStatFontSize] or
  // larger; if that cannot fit beside the large Pause/Stop buttons on small
  // screens, the trade-off goes to the team for a decision.

  /// Elapsed time on the Run screen — the biggest live number (UI kit: 62).
  static const TextStyle liveTimer = TextStyle(
    fontSize: 62,
    fontWeight: FontWeight.w700,
    height: 1.0,
    letterSpacing: -1,
    color: AppColors.liveBlue,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Current pace on the Run screen. Exactly the NFR-09 minimum.
  static const TextStyle livePace = TextStyle(
    fontSize: minStatFontSize,
    fontWeight: FontWeight.w700,
    height: 1.0,
    color: AppColors.liveBlue,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Saved-run numbers on cards (Home "Last Run", History list, Summary).
  /// Not a live running statistic, so NFR-09's 32sp rule does not apply.
  static const TextStyle statValue = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.2,
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
