// Road Runner — semantic colour roles for light ("sunrise desert") and dark
// ("moonlit desert") themes.
// Owner: Tharushi
// SRS reference: Section 8.4, FR-70, NFR-09
// Design reference: UI kit Revision 5 (Components and tokens sheet + screens)
//
// AppColors / AppDarkColors hold raw values. AppPalette names what each
// colour is FOR (background, saved stat, live stat, route band, ...) and is
// registered on both ThemeData objects as a ThemeExtension, so a widget
// written once against `context.palette` renders correctly in both modes:
//
//   final AppPalette p = context.palette;
//   Text('5.02 km', style: AppTextStyles.statValue.copyWith(color: p.stat));
//
// Material widgets (buttons, dialogs, text) already follow ColorScheme and
// TextTheme. Use AppPalette for the colours Material has no slot for.

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Semantic Road Runner colours, resolved for the active theme.
///
/// Read with [AppPalette.of] or `context.palette`. Both fall back to
/// [AppPalette.light] when the theme has no palette (e.g. a test that pumps a
/// bare `MaterialApp`), so existing widgets keep their current look.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.iconButtonFill,
    required this.cardBorder,
    required this.cardShadow,
    required this.hairline,
    required this.scrim,
    required this.textPrimary,
    required this.textSecondary,
    required this.onIconTile,
    required this.primaryFill,
    required this.onPrimaryFill,
    required this.primaryFillActive,
    required this.buttonOutline,
    required this.accent,
    required this.iconTile,
    required this.stat,
    required this.statLive,
    required this.statLiveTint,
    required this.highlight,
    required this.gpsWeak,
    required this.gpsWeakTint,
    required this.error,
    required this.onError,
    required this.errorTint,
    required this.routeSlow,
    required this.routeSteady,
    required this.routeFast,
    required this.routePlain,
    required this.routeNoSpeed,
    required this.mapBackground,
    required this.mapGrid,
    required this.routeCasing,
    required this.routeStart,
    required this.routeFinish,
    required this.skeleton,
    required this.shimmerHighlight,
    required this.skyTop,
    required this.skyMid,
    required this.skyMidStop,
    required this.skyBottom,
    required this.splashColors,
    required this.splashStops,
    required this.celestial,
    required this.celestialDetail,
    required this.celestialGlow,
    required this.skyDecoration,
    required this.mesa,
    required this.hills,
    required this.dunes,
    required this.sandDune,
    required this.illustrationPhone,
    required this.illustrationOutline,
    required this.illustrationGrid,
    required this.illustrationMuted,
    required this.illustrationShadow,
    required this.illustrationCactus,
    required this.illustrationBadgeRing,
    required this.illustrationBadgeIcon,
    required this.illustrationBrightness,
    required this.illustrationSaturation,
  });

  /// Which mode these values belong to.
  final Brightness brightness;

  // ─── Surfaces ───────────────────────────────────────────────────────────────

  /// Screen background (Scaffold).
  final Color background;

  /// Cards, drawer, dialogs, Pause/Resume button fill.
  final Color surface;

  /// Translucent fill behind round header icon buttons (menu, settings).
  final Color iconButtonFill;

  /// 1px card outline. Transparent by day; a faint light line at night.
  final Color cardBorder;

  /// Card drop shadow.
  final List<BoxShadow> cardShadow;

  /// Hairline dividers inside cards, lists and stat grids.
  final Color hairline;

  /// Modal scrim behind the navigation drawer and dialogs.
  final Color scrim;

  // ─── Text ───────────────────────────────────────────────────────────────────

  /// Headings and body text.
  final Color textPrimary;

  /// Captions, stat labels, paused timer, GPS "Searching".
  final Color textSecondary;

  /// Text drawn on an [iconTile] (selected drawer label, numbered steps).
  final Color onIconTile;

  // ─── Actions & accents ──────────────────────────────────────────────────────

  /// Primary button / Stop / Slide-to-Start track fill. Same in both modes.
  final Color primaryFill;

  /// Text and icons on [primaryFill].
  final Color onPrimaryFill;

  /// Slide-to-Start track once it locks in the "Starting run" state.
  final Color primaryFillActive;

  /// Border of outlined (secondary) buttons and unselected filter chips.
  final Color buttonOutline;

  /// Icons, text links, selected drawer icon, Pause/Resume border, Paused
  /// pill. Readable as text on [background] and [surface].
  final Color accent;

  /// Rounded square behind icons; selected drawer row; Paused pill fill.
  final Color iconTile;

  // ─── Statistics & status ────────────────────────────────────────────────────

  /// Saved running statistics (Home, History, Summary).
  final Color stat;

  /// Live running information (Run screen numbers, GPS "Good",
  /// Recording pill, "Allowed" permission chip, route start marker).
  final Color statLive;

  /// Pill fill behind [statLive] text.
  final Color statLiveTint;

  /// Fastest-split row background.
  final Color highlight;

  /// Weak GPS badge foreground.
  final Color gpsWeak;

  /// Weak GPS badge fill.
  final Color gpsWeakTint;

  /// Error text and icons; also an error fill under [onError].
  final Color error;

  /// Text on an [error] fill.
  final Color onError;

  /// Pill fill behind [error] text ("Denied" permission chip).
  final Color errorTint;

  // ─── Route map ──────────────────────────────────────────────────────────────

  /// Pace bands: slower / steady / faster.
  final Color routeSlow;
  final Color routeSteady;
  final Color routeFast;

  /// Route line when no speed was recorded at all.
  final Color routePlain;

  /// Segments without speed inside a coloured route, and GPS gaps.
  final Color routeNoSpeed;

  /// Map "parchment" background and its scale grid.
  final Color mapBackground;
  final Color mapGrid;

  /// Underlay drawn beneath the route line and as the marker ring.
  final Color routeCasing;

  /// Start and finish markers.
  final Color routeStart;
  final Color routeFinish;

  // ─── Loading ────────────────────────────────────────────────────────────────

  /// Skeleton block fill and the shimmer sweep highlight.
  final Color skeleton;
  final Color shimmerHighlight;

  // ─── Desert artwork ─────────────────────────────────────────────────────────

  /// Header sky gradient stops (see [skyGradient]).
  final Color skyTop;
  final Color skyMid;
  final double skyMidStop;
  final Color skyBottom;

  /// Splash full-screen sky (see [splashGradient]). Same length as
  /// [splashStops].
  final List<Color> splashColors;
  final List<double> splashStops;

  /// Sun by day, moon at night; [celestialDetail] is the moon crater (equal
  /// to [celestial] by day); [celestialGlow] is the halo.
  final Color celestial;
  final Color celestialDetail;
  final Color celestialGlow;

  /// Clouds by day, stars at night.
  final Color skyDecoration;

  /// Landscape layers, back to front.
  final Color mesa;
  final Color hills;
  final Color dunes;
  final Color sandDune;

  // ─── Permission illustration ────────────────────────────────────────────────

  final Color illustrationPhone;
  final Color illustrationOutline;
  final Color illustrationGrid;
  final Color illustrationMuted;
  final Color illustrationShadow;
  final Color illustrationCactus;
  final Color illustrationBadgeRing;
  final Color illustrationBadgeIcon;

  /// Brightness / saturation multipliers for the raster runner
  /// illustrations (kit: `filter: brightness(.9) saturate(.92)` at night).
  final double illustrationBrightness;
  final double illustrationSaturation;

  // ─── Derived helpers ────────────────────────────────────────────────────────

  bool get isDark => brightness == Brightness.dark;

  /// Header sky behind titles: [skyTop] → [skyMid] → [skyBottom].
  LinearGradient get skyGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [skyTop, skyMid, skyBottom],
    stops: [0.0, skyMidStop, 1.0],
  );

  /// Full-screen splash sky.
  LinearGradient get splashGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: splashColors,
    stops: splashStops,
  );

  /// Pace-band colours in slower → steady → faster order.
  List<Color> get routeBands => [routeSlow, routeSteady, routeFast];

  // ─── Instances ──────────────────────────────────────────────────────────────

  /// Sunrise desert. Every value matches what the light screens draw today.
  static final AppPalette light = AppPalette(
    brightness: Brightness.light,
    background: AppColors.sand,
    surface: AppColors.sandLight,
    iconButtonFill: AppColors.sandLight.withValues(alpha: 0.72),
    cardBorder: const Color(0x00000000),
    cardShadow: const [
      BoxShadow(
        color: Color(0x145B3A29), // canyonBrown 8%
        offset: Offset(0, 6),
        blurRadius: 18,
      ),
    ],
    hairline: AppColors.divider,
    scrim: const Color(0x6B3C281E), // kit light screens: rgba(60,40,30,.42)
    textPrimary: AppColors.canyonBrown,
    textSecondary: AppColors.canyonBrownMuted,
    onIconTile: AppColors.canyonBrownDeep,
    primaryFill: AppColors.burntOrangeDeep,
    onPrimaryFill: AppColors.white,
    primaryFillActive: const Color(0xFF7E3A19),
    buttonOutline: AppColors.burntOrangeDeep,
    accent: AppColors.burntOrangeDeep,
    iconTile: AppColors.iconTile,
    stat: AppColors.tealDeep,
    statLive: AppColors.liveBlue,
    statLiveTint: AppColors.liveBlue.withValues(alpha: 0.10),
    highlight: AppColors.tealDeep.withValues(alpha: 0.12),
    gpsWeak: const Color(0xFF8A5200),
    gpsWeakTint: const Color(0xFFFFCE29).withValues(alpha: 0.24),
    error: AppColors.error,
    onError: AppColors.white,
    errorTint: AppColors.error.withValues(alpha: 0.10),
    routeSlow: const Color(0xFF5182D5),
    // a11y: kit #EB6621 is 2.7:1 on the map; this deeper orange is ≥ 3:1.
    routeSteady: const Color(0xFFD9581A),
    routeFast: const Color(0xFF87211C),
    routePlain: AppColors.canyonBrown,
    routeNoSpeed: AppColors.canyonBrownMuted,
    mapBackground: const Color(0xFFF3E6CF),
    mapGrid: const Color(0x145B3A29),
    routeCasing: AppColors.white,
    routeStart: AppColors.liveBlue,
    routeFinish: AppColors.burntOrangeDeep,
    skeleton: AppColors.canyonBrown.withValues(alpha: 0.10),
    shimmerHighlight: AppColors.white.withValues(alpha: 0.45),
    skyTop: AppColors.skyTop,
    skyMid: AppColors.skyMid,
    skyMidStop: 0.52,
    skyBottom: AppColors.sand,
    splashColors: const [
      Color(0xFF8FB1F9),
      Color(0xFFBFC9EE),
      Color(0xFFFFCF91),
      AppColors.sand,
    ],
    splashStops: const [0.0, 0.38, 0.66, 1.0],
    celestial: const Color(0xFFFFD762),
    celestialDetail: const Color(0xFFFFD762),
    celestialGlow: const Color(0xFFFFD762).withValues(alpha: 0.35),
    skyDecoration: AppColors.white.withValues(alpha: 0.8),
    mesa: const Color(0xFFC07358),
    hills: const Color(0xFFDF8583),
    dunes: const Color(0xFFFFCF91),
    sandDune: const Color(0xFFF2D6A6),
    illustrationPhone: AppColors.sandLight,
    illustrationOutline: AppColors.canyonBrown,
    illustrationGrid: const Color(0xFFEBDAC0),
    illustrationMuted: const Color(0xFFB49A86),
    illustrationShadow: const Color(0x245B3A29),
    illustrationCactus: const Color(0xFFC07358),
    illustrationBadgeRing: AppColors.sand,
    illustrationBadgeIcon: AppColors.white,
    illustrationBrightness: 1.0,
    illustrationSaturation: 1.0,
  );

  /// Moonlit desert (UI kit Revision 5 night column).
  static final AppPalette dark = AppPalette(
    brightness: Brightness.dark,
    background: AppDarkColors.background,
    surface: AppDarkColors.surface,
    iconButtonFill: AppDarkColors.iconButtonFill,
    cardBorder: AppDarkColors.cardBorder,
    cardShadow: const [
      BoxShadow(
        color: Color(0x47000000), // black 28%
        offset: Offset(0, 8),
        blurRadius: 24,
      ),
    ],
    hairline: AppDarkColors.hairline,
    scrim: AppDarkColors.scrim,
    textPrimary: AppDarkColors.textPrimary,
    textSecondary: AppDarkColors.textSecondary,
    onIconTile: AppDarkColors.accentOnTile,
    primaryFill: AppColors.burntOrangeDeep,
    onPrimaryFill: AppColors.white,
    primaryFillActive: const Color(0xFF7E3A19),
    buttonOutline: AppDarkColors.outline,
    accent: AppDarkColors.accent,
    iconTile: AppDarkColors.iconTile,
    stat: AppDarkColors.stat,
    statLive: AppDarkColors.statLive,
    statLiveTint: AppDarkColors.statLive.withValues(alpha: 0.14),
    highlight: AppDarkColors.highlight,
    gpsWeak: AppDarkColors.gpsWeak,
    gpsWeakTint: AppDarkColors.gpsWeak.withValues(alpha: 0.14),
    error: AppDarkColors.error,
    onError: AppDarkColors.onError,
    errorTint: AppDarkColors.error.withValues(alpha: 0.12),
    routeSlow: AppDarkColors.routeSlow,
    routeSteady: AppDarkColors.routeSteady,
    routeFast: AppDarkColors.routeFast,
    routePlain: AppDarkColors.textPrimary,
    routeNoSpeed: AppDarkColors.textSecondary,
    mapBackground: AppDarkColors.mapBackground,
    mapGrid: AppDarkColors.mapGrid,
    routeCasing: AppDarkColors.background,
    routeStart: AppDarkColors.statLive,
    routeFinish: AppDarkColors.routeFinish,
    skeleton: AppDarkColors.skeleton,
    shimmerHighlight: AppDarkColors.shimmerHighlight,
    skyTop: AppDarkColors.skyTop,
    skyMid: AppDarkColors.skyMid,
    skyMidStop: 0.55,
    skyBottom: AppDarkColors.background,
    splashColors: const [
      AppDarkColors.splashTop,
      AppDarkColors.skyMid,
      AppDarkColors.mesa,
      AppDarkColors.background,
    ],
    splashStops: const [0.0, 0.50, 0.72, 1.0],
    celestial: AppDarkColors.moon,
    celestialDetail: AppDarkColors.moonCrater,
    celestialGlow: AppDarkColors.moonGlow,
    skyDecoration: AppDarkColors.star,
    mesa: AppDarkColors.mesa,
    hills: AppDarkColors.hills,
    dunes: AppDarkColors.dunes,
    sandDune: AppDarkColors.sandDune,
    illustrationPhone: AppDarkColors.phone,
    illustrationOutline: AppDarkColors.textPrimary,
    illustrationGrid: AppDarkColors.phoneGrid,
    illustrationMuted: AppDarkColors.outline,
    illustrationShadow: const Color(0x52000000), // black 32%
    illustrationCactus: AppDarkColors.hills,
    illustrationBadgeRing: AppDarkColors.background,
    illustrationBadgeIcon: AppDarkColors.background,
    illustrationBrightness: 0.9,
    illustrationSaturation: 0.92,
  );

  /// The palette for [brightness].
  static AppPalette forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// The palette of the nearest [Theme], or [light] if none is registered.
  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>() ?? light;

  // ─── ThemeExtension ─────────────────────────────────────────────────────────

  @override
  AppPalette copyWith({
    Brightness? brightness,
    Color? background,
    Color? surface,
    Color? iconButtonFill,
    Color? cardBorder,
    List<BoxShadow>? cardShadow,
    Color? hairline,
    Color? scrim,
    Color? textPrimary,
    Color? textSecondary,
    Color? onIconTile,
    Color? primaryFill,
    Color? onPrimaryFill,
    Color? primaryFillActive,
    Color? buttonOutline,
    Color? accent,
    Color? iconTile,
    Color? stat,
    Color? statLive,
    Color? statLiveTint,
    Color? highlight,
    Color? gpsWeak,
    Color? gpsWeakTint,
    Color? error,
    Color? onError,
    Color? errorTint,
    Color? routeSlow,
    Color? routeSteady,
    Color? routeFast,
    Color? routePlain,
    Color? routeNoSpeed,
    Color? mapBackground,
    Color? mapGrid,
    Color? routeCasing,
    Color? routeStart,
    Color? routeFinish,
    Color? skeleton,
    Color? shimmerHighlight,
    Color? skyTop,
    Color? skyMid,
    double? skyMidStop,
    Color? skyBottom,
    List<Color>? splashColors,
    List<double>? splashStops,
    Color? celestial,
    Color? celestialDetail,
    Color? celestialGlow,
    Color? skyDecoration,
    Color? mesa,
    Color? hills,
    Color? dunes,
    Color? sandDune,
    Color? illustrationPhone,
    Color? illustrationOutline,
    Color? illustrationGrid,
    Color? illustrationMuted,
    Color? illustrationShadow,
    Color? illustrationCactus,
    Color? illustrationBadgeRing,
    Color? illustrationBadgeIcon,
    double? illustrationBrightness,
    double? illustrationSaturation,
  }) {
    return AppPalette(
      brightness: brightness ?? this.brightness,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      iconButtonFill: iconButtonFill ?? this.iconButtonFill,
      cardBorder: cardBorder ?? this.cardBorder,
      cardShadow: cardShadow ?? this.cardShadow,
      hairline: hairline ?? this.hairline,
      scrim: scrim ?? this.scrim,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      onIconTile: onIconTile ?? this.onIconTile,
      primaryFill: primaryFill ?? this.primaryFill,
      onPrimaryFill: onPrimaryFill ?? this.onPrimaryFill,
      primaryFillActive: primaryFillActive ?? this.primaryFillActive,
      buttonOutline: buttonOutline ?? this.buttonOutline,
      accent: accent ?? this.accent,
      iconTile: iconTile ?? this.iconTile,
      stat: stat ?? this.stat,
      statLive: statLive ?? this.statLive,
      statLiveTint: statLiveTint ?? this.statLiveTint,
      highlight: highlight ?? this.highlight,
      gpsWeak: gpsWeak ?? this.gpsWeak,
      gpsWeakTint: gpsWeakTint ?? this.gpsWeakTint,
      error: error ?? this.error,
      onError: onError ?? this.onError,
      errorTint: errorTint ?? this.errorTint,
      routeSlow: routeSlow ?? this.routeSlow,
      routeSteady: routeSteady ?? this.routeSteady,
      routeFast: routeFast ?? this.routeFast,
      routePlain: routePlain ?? this.routePlain,
      routeNoSpeed: routeNoSpeed ?? this.routeNoSpeed,
      mapBackground: mapBackground ?? this.mapBackground,
      mapGrid: mapGrid ?? this.mapGrid,
      routeCasing: routeCasing ?? this.routeCasing,
      routeStart: routeStart ?? this.routeStart,
      routeFinish: routeFinish ?? this.routeFinish,
      skeleton: skeleton ?? this.skeleton,
      shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
      skyTop: skyTop ?? this.skyTop,
      skyMid: skyMid ?? this.skyMid,
      skyMidStop: skyMidStop ?? this.skyMidStop,
      skyBottom: skyBottom ?? this.skyBottom,
      splashColors: splashColors ?? this.splashColors,
      splashStops: splashStops ?? this.splashStops,
      celestial: celestial ?? this.celestial,
      celestialDetail: celestialDetail ?? this.celestialDetail,
      celestialGlow: celestialGlow ?? this.celestialGlow,
      skyDecoration: skyDecoration ?? this.skyDecoration,
      mesa: mesa ?? this.mesa,
      hills: hills ?? this.hills,
      dunes: dunes ?? this.dunes,
      sandDune: sandDune ?? this.sandDune,
      illustrationPhone: illustrationPhone ?? this.illustrationPhone,
      illustrationOutline: illustrationOutline ?? this.illustrationOutline,
      illustrationGrid: illustrationGrid ?? this.illustrationGrid,
      illustrationMuted: illustrationMuted ?? this.illustrationMuted,
      illustrationShadow: illustrationShadow ?? this.illustrationShadow,
      illustrationCactus: illustrationCactus ?? this.illustrationCactus,
      illustrationBadgeRing:
          illustrationBadgeRing ?? this.illustrationBadgeRing,
      illustrationBadgeIcon:
          illustrationBadgeIcon ?? this.illustrationBadgeIcon,
      illustrationBrightness:
          illustrationBrightness ?? this.illustrationBrightness,
      illustrationSaturation:
          illustrationSaturation ?? this.illustrationSaturation,
    );
  }

  /// Smoothly blends every colour when the theme changes (AnimatedTheme),
  /// so a system light/dark switch cross-fades instead of snapping.
  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    double d(double a, double b) => lerpDouble(a, b, t)!;
    return AppPalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: c(background, other.background),
      surface: c(surface, other.surface),
      iconButtonFill: c(iconButtonFill, other.iconButtonFill),
      cardBorder: c(cardBorder, other.cardBorder),
      cardShadow: BoxShadow.lerpList(cardShadow, other.cardShadow, t)!,
      hairline: c(hairline, other.hairline),
      scrim: c(scrim, other.scrim),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      onIconTile: c(onIconTile, other.onIconTile),
      primaryFill: c(primaryFill, other.primaryFill),
      onPrimaryFill: c(onPrimaryFill, other.onPrimaryFill),
      primaryFillActive: c(primaryFillActive, other.primaryFillActive),
      buttonOutline: c(buttonOutline, other.buttonOutline),
      accent: c(accent, other.accent),
      iconTile: c(iconTile, other.iconTile),
      stat: c(stat, other.stat),
      statLive: c(statLive, other.statLive),
      statLiveTint: c(statLiveTint, other.statLiveTint),
      highlight: c(highlight, other.highlight),
      gpsWeak: c(gpsWeak, other.gpsWeak),
      gpsWeakTint: c(gpsWeakTint, other.gpsWeakTint),
      error: c(error, other.error),
      onError: c(onError, other.onError),
      errorTint: c(errorTint, other.errorTint),
      routeSlow: c(routeSlow, other.routeSlow),
      routeSteady: c(routeSteady, other.routeSteady),
      routeFast: c(routeFast, other.routeFast),
      routePlain: c(routePlain, other.routePlain),
      routeNoSpeed: c(routeNoSpeed, other.routeNoSpeed),
      mapBackground: c(mapBackground, other.mapBackground),
      mapGrid: c(mapGrid, other.mapGrid),
      routeCasing: c(routeCasing, other.routeCasing),
      routeStart: c(routeStart, other.routeStart),
      routeFinish: c(routeFinish, other.routeFinish),
      skeleton: c(skeleton, other.skeleton),
      shimmerHighlight: c(shimmerHighlight, other.shimmerHighlight),
      skyTop: c(skyTop, other.skyTop),
      skyMid: c(skyMid, other.skyMid),
      skyMidStop: d(skyMidStop, other.skyMidStop),
      skyBottom: c(skyBottom, other.skyBottom),
      splashColors: _lerpColors(splashColors, other.splashColors, t),
      splashStops: _lerpDoubles(splashStops, other.splashStops, t),
      celestial: c(celestial, other.celestial),
      celestialDetail: c(celestialDetail, other.celestialDetail),
      celestialGlow: c(celestialGlow, other.celestialGlow),
      skyDecoration: c(skyDecoration, other.skyDecoration),
      mesa: c(mesa, other.mesa),
      hills: c(hills, other.hills),
      dunes: c(dunes, other.dunes),
      sandDune: c(sandDune, other.sandDune),
      illustrationPhone: c(illustrationPhone, other.illustrationPhone),
      illustrationOutline: c(illustrationOutline, other.illustrationOutline),
      illustrationGrid: c(illustrationGrid, other.illustrationGrid),
      illustrationMuted: c(illustrationMuted, other.illustrationMuted),
      illustrationShadow: c(illustrationShadow, other.illustrationShadow),
      illustrationCactus: c(illustrationCactus, other.illustrationCactus),
      illustrationBadgeRing: c(
        illustrationBadgeRing,
        other.illustrationBadgeRing,
      ),
      illustrationBadgeIcon: c(
        illustrationBadgeIcon,
        other.illustrationBadgeIcon,
      ),
      illustrationBrightness: d(
        illustrationBrightness,
        other.illustrationBrightness,
      ),
      illustrationSaturation: d(
        illustrationSaturation,
        other.illustrationSaturation,
      ),
    );
  }

  /// Gradient lists of different length cannot blend stop-by-stop, so snap
  /// at the midpoint instead.
  static List<Color> _lerpColors(List<Color> a, List<Color> b, double t) {
    if (a.length != b.length) return t < 0.5 ? a : b;
    return [for (int i = 0; i < a.length; i++) Color.lerp(a[i], b[i], t)!];
  }

  static List<double> _lerpDoubles(List<double> a, List<double> b, double t) {
    if (a.length != b.length) return t < 0.5 ? a : b;
    return [for (int i = 0; i < a.length; i++) lerpDouble(a[i], b[i], t)!];
  }
}

/// `context.palette` — shorthand for [AppPalette.of].
extension AppPaletteContext on BuildContext {
  AppPalette get palette => AppPalette.of(this);
}
