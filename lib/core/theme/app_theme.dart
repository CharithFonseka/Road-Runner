// Road Runner — Material theme (light "sunrise desert" + dark "moonlit
// desert").
// Owner: Tharushi
// SRS reference: Section 8.4, FR-70, NFR-09
// Design reference: UI kit Revision 5
//
// Builds ThemeData from the tokens in app_colors.dart, app_palette.dart,
// app_text_styles.dart and app_spacing.dart. Both themes go through the same
// builder, so every component theme exists in both modes and differs only
// in colour.
//
// Screens should read colours from Theme.of(context) (ColorScheme /
// TextTheme) or from `context.palette` (AppPalette) — never hardcode hex
// values. The `AppColors.*` constants remain for backward compatibility while
// screens migrate.
//
// App-shell wiring (owned by main.dart, see README.md in this folder):
//
//   MaterialApp(
//     theme: AppTheme.light(),
//     darkTheme: AppTheme.dark(),
//     themeMode: AppTheme.themeMode, // ThemeMode.system
//   )

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_palette.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';

/// The Road Runner Material 3 themes.
class AppTheme {
  AppTheme._();

  /// Follow the phone's system light/dark setting.
  static const ThemeMode themeMode = ThemeMode.system;

  /// Light colour scheme. Every foreground/background pair here is checked by
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

  /// Dark colour scheme, checked by test/core/theme/dark_contrast_test.dart.
  ///
  /// `primary` is the night accent (#E8957A), NOT the button fill: Material
  /// uses `primary` as a text/indicator colour on the surface (TextButton,
  /// progress indicators, focus rings, switches), and the kit's #A34A20 fill
  /// is only 2.17:1 on the navy surface. The kit's burnt-orange filled
  /// buttons are kept through [primaryContainer] and the filled-button theme.
  static const ColorScheme darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppDarkColors.accent,
    onPrimary: AppDarkColors.background,
    primaryContainer: AppColors.burntOrangeDeep,
    onPrimaryContainer: AppColors.white,
    secondary: AppColors.duskPink,
    onSecondary: AppDarkColors.background,
    // The kit's tile (accent 16%) flattened onto the surface, so it is opaque.
    secondaryContainer: Color(0xFF48424F),
    onSecondaryContainer: AppDarkColors.textPrimary,
    tertiary: AppDarkColors.stat,
    onTertiary: AppDarkColors.background,
    error: AppDarkColors.error,
    onError: AppDarkColors.onError,
    surface: AppDarkColors.background,
    onSurface: AppDarkColors.textPrimary,
    onSurfaceVariant: AppDarkColors.textSecondary,
    surfaceContainerLow: AppDarkColors.surface,
    surfaceContainer: AppDarkColors.surface,
    surfaceContainerHigh: AppDarkColors.surface,
    surfaceContainerHighest: AppDarkColors.surface,
    outline: AppDarkColors.outline,
    inverseSurface: AppDarkColors.textPrimary,
    onInverseSurface: AppDarkColors.background,
    inversePrimary: AppColors.burntOrangeDeep,
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

  /// The light (sunrise desert) theme.
  static ThemeData light() => _build(
    scheme: colorScheme,
    palette: AppPalette.light,
    // Kept as the original const instance so light text is byte-identical.
    textTheme: AppTextStyles.textTheme,
  );

  /// The dark (moonlit desert) theme.
  static ThemeData dark() => _build(
    scheme: darkColorScheme,
    palette: AppPalette.dark,
    textTheme: AppTextStyles.textThemeFor(AppPalette.dark),
  );

  /// The theme for [brightness] — useful for previews and tests.
  static ThemeData forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark() : light();

  /// The [SystemUiOverlayStyle] for the active [palette].
  ///
  /// In both themes, the status bar is transparent because custom sky headers
  /// extend under the status bar.
  ///
  /// Status bar icons:
  /// - Light mode: [Brightness.dark] (dark icons against the light sky / sand).
  /// - Dark mode: [Brightness.light] (light icons against the dark navy sky / background).
  ///
  /// Navigation bar:
  /// - Light mode: [palette.surface] (sandLight) with [Brightness.dark] icons.
  /// - Dark mode: [palette.background] (night navy #171D2B) with [Brightness.light] icons
  ///   and [palette.hairline] divider.
  static SystemUiOverlayStyle systemUiOverlayStyleFor(AppPalette palette) {
    final bool isDark = palette.isDark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: isDark ? palette.background : palette.surface,
      systemNavigationBarDividerColor: isDark
          ? palette.hairline
          : Colors.transparent,
      systemNavigationBarIconBrightness: isDark
          ? Brightness.light
          : Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    );
  }

  static ThemeData _build({
    required ColorScheme scheme,
    required AppPalette palette,
    required TextTheme textTheme,
  }) {
    final bool isDark = palette.isDark;

    // Night cards and dialogs carry the kit's faint 1px border. The light
    // shapes stay exactly as before (no side).
    RoundedRectangleBorder rounded(double radius) => RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(radius)),
      side: isDark ? BorderSide(color: palette.cardBorder) : BorderSide.none,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: AppTextStyles.fontFamily,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.background,
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[palette],
      // Keep Material's 48dp invisible tap area around small controls.
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarThemeData(
        backgroundColor: palette.background,
        foregroundColor: palette.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge,
        systemOverlayStyle: systemUiOverlayStyleFor(palette),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: rounded(AppSpacing.radiusCard),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: rounded(AppSpacing.radiusCard),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: rounded(AppSpacing.radiusLarge),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyLarge,
        // Light keeps Flutter's default barrier (current appearance); night
        // uses the kit scrim. Adopting the light kit scrim is a screen task.
        barrierColor: isDark ? palette.scrim : null,
      ),
      drawerTheme: isDark
          ? DrawerThemeData(
              backgroundColor: palette.surface,
              surfaceTintColor: Colors.transparent,
              scrimColor: palette.scrim,
            )
          : null,
      dividerTheme: DividerThemeData(
        color: palette.hairline,
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
          // At night `primary` is the light accent, so the kit's burnt-orange
          // fill is set explicitly. By day the default (primary) is the same.
          backgroundColor: isDark ? palette.primaryFill : null,
          foregroundColor: isDark ? palette.onPrimaryFill : null,
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
      // Day: sand-light fill, burnt-orange border. Night: transparent fill,
      // taupe border (kit `.btn2`).
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: _minLargeButtonSize,
          padding: _buttonPadding,
          textStyle: AppTextStyles.button,
          shape: const StadiumBorder(),
          foregroundColor: palette.textPrimary,
          backgroundColor: isDark ? Colors.transparent : palette.surface,
          side: BorderSide(color: palette.buttonOutline, width: 1.5),
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

/// Reusable widget wrapping [child] with an [AnnotatedRegion] configured with
/// [AppTheme.systemUiOverlayStyleFor] using the current [context.palette].
///
/// Because Road Runner uses custom sky headers instead of Material AppBars,
/// this widget (or [AppTheme.systemUiOverlayStyleFor] in [MaterialApp.builder])
/// ensures Android status and navigation bars remain readable in both light
/// and dark modes.
class AppSystemUiOverlay extends StatelessWidget {
  const AppSystemUiOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.systemUiOverlayStyleFor(palette),
      child: child,
    );
  }
}
