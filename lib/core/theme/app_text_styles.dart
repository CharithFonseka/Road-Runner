// Road Runner — typography tokens.
// Owner: Tharushi
// SRS reference: Section 8.4, NFR-09
//
// Uses the bundled Gotham family across light and dark themes.
// Sizes are in sp, so they grow when the user increases system font size.

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_palette.dart';

/// Text styles for the Road Runner design system.
class AppTextStyles {
  AppTextStyles._();

  static const String fontFamily = 'Gotham';

  /// Smallest size allowed for main running statistics (NFR-09).
  static const double minStatFontSize = 32.0;

  /// Screen titles, e.g. "History".
  static const TextStyle heading = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.25,
    color: AppColors.canyonBrown,
  );

  /// Section and card titles, e.g. "Splits", "Last Run" (UI kit: 20 bold).
  static const TextStyle sectionHeading = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: AppColors.canyonBrown,
  );

  /// Normal paragraph and list text.
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.canyonBrown,
  );

  /// Small helper text, e.g. stat labels and dates.
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppColors.canyonBrownMuted,
  );

  /// Button labels — larger and bold for outdoor reading (UI kit: 18 bold).
  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
  );

  /// The most important live number on the Run screen (elapsed time).
  ///
  /// Tabular figures give every digit the same width, so the number does
  /// not shift left and right as it changes every second.
  static const TextStyle statLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 48,
    fontWeight: FontWeight.w700,
    height: 1.1,
    color: AppColors.tealDeep,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Other live numbers (distance, speed, pace). Exactly the NFR-09 minimum.
  static const TextStyle statMedium = TextStyle(
    fontFamily: fontFamily,
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
    fontFamily: fontFamily,
    fontSize: 62,
    fontWeight: FontWeight.w700,
    height: 1.0,
    letterSpacing: -1,
    color: AppColors.liveBlue,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Current pace on the Run screen. Exactly the NFR-09 minimum.
  static const TextStyle livePace = TextStyle(
    fontFamily: fontFamily,
    fontSize: minStatFontSize,
    fontWeight: FontWeight.w700,
    height: 1.0,
    color: AppColors.liveBlue,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Saved-run numbers on cards (Home "Last Run", History list, Summary).
  /// Not a live running statistic, so NFR-09's 32sp rule does not apply.
  static const TextStyle statValue = TextStyle(
    fontFamily: fontFamily,
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

  /// [textTheme] recoloured for [palette], so the same sizes and weights
  /// read correctly on the day or night background.
  ///
  /// Role mapping: headings and body → `textPrimary`, caption →
  /// `textSecondary`, statLarge / statMedium → `stat`. `labelLarge` keeps no
  /// colour so buttons supply their own foreground. For the light palette
  /// the result equals [textTheme].
  static TextTheme textThemeFor(AppPalette palette) => TextTheme(
    displayLarge: statLarge.copyWith(color: palette.stat),
    displayMedium: statMedium.copyWith(color: palette.stat),
    headlineMedium: heading.copyWith(color: palette.textPrimary),
    titleLarge: sectionHeading.copyWith(color: palette.textPrimary),
    bodyLarge: body.copyWith(color: palette.textPrimary),
    bodyMedium: body.copyWith(color: palette.textPrimary),
    bodySmall: caption.copyWith(color: palette.textSecondary),
    labelLarge: button,
  );

  /// The UI kit's named styles recoloured for [palette]. Screens migrating
  /// from the `const` styles above can swap `AppTextStyles.caption` for
  /// `AppTextStyles.of(context).caption` without changing sizes.
  static AppThemedTextStyles of(BuildContext context) =>
      AppThemedTextStyles(AppPalette.of(context));
}

/// The [AppTextStyles] set with colours taken from an [AppPalette].
///
/// Live styles use `statLive`, saved stats use `stat`, text uses
/// `textPrimary` / `textSecondary`.
@immutable
class AppThemedTextStyles {
  const AppThemedTextStyles(this.palette);

  final AppPalette palette;

  TextStyle get heading =>
      AppTextStyles.heading.copyWith(color: palette.textPrimary);
  TextStyle get sectionHeading =>
      AppTextStyles.sectionHeading.copyWith(color: palette.textPrimary);
  TextStyle get body => AppTextStyles.body.copyWith(color: palette.textPrimary);
  TextStyle get caption =>
      AppTextStyles.caption.copyWith(color: palette.textSecondary);
  TextStyle get button => AppTextStyles.button;
  TextStyle get statLarge =>
      AppTextStyles.statLarge.copyWith(color: palette.stat);
  TextStyle get statMedium =>
      AppTextStyles.statMedium.copyWith(color: palette.stat);
  TextStyle get liveTimer =>
      AppTextStyles.liveTimer.copyWith(color: palette.statLive);
  TextStyle get livePace =>
      AppTextStyles.livePace.copyWith(color: palette.statLive);
  TextStyle get statValue =>
      AppTextStyles.statValue.copyWith(color: palette.stat);
}
