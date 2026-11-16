// Road Runner — colour tokens.
// Owner: Tharushi
// SRS reference: Section 8.4, FR-70, NFR-09
//
// Two groups of colours:
//
// 1. Brand colours — the five SRS §8.4 palette values, unchanged.
//    Use them for large fills and decoration (backgrounds, the path
//    painter, illustrations). Except for sand and canyon brown, do NOT
//    use them as text colours: they fail the 4.5:1 contrast rule.
//
// 2. Text-safe variants — darker versions of the same hues. Each one
//    exists for one clear purpose, written next to it. Contrast ratios
//    are verified in test/core/theme/contrast_test.dart.

import 'package:flutter/material.dart';

/// Colour tokens for the Road Runner design system.
class AppColors {
  AppColors._();

  // ─── Brand colours (SRS §8.4 — keep unchanged) ──────────────────────────────

  /// Main background.
  static const Color sand = Color(0xFFF4E4C8);

  /// Brand primary. Fill/decoration only — white text on it is 3.66:1.
  static const Color burntOrange = Color(0xFFD9622B);

  /// Brand secondary. Used as a container fill with [canyonBrownDeep] text.
  static const Color duskPink = Color(0xFFE58C8A);

  /// Main text colour. 8.06:1 on [sand].
  static const Color canyonBrown = Color(0xFF5B3A29);

  /// Brand live-data highlight. Decoration only — 2.66:1 on [sand].
  static const Color accentTeal = Color(0xFF2A9D8F);

  // ─── Text-safe variants (each has one purpose) ──────────────────────────────

  /// Primary actions (Start button fill, text buttons).
  /// White on it: 5.90:1. As text on [sand]: 4.72:1.
  static const Color burntOrangeDeep = Color(0xFFA34A20);

  /// Secondary actions. White on it: 6.08:1. As text on [sand]: 4.85:1.
  static const Color duskPinkDeep = Color(0xFF895453);

  /// Live running statistics (time, distance, pace, speed).
  /// On [sand]: 4.84:1. White on it: 6.06:1.
  static const Color tealDeep = Color(0xFF1D6E64);

  /// Text on [duskPink] fills. 5.60:1.
  static const Color canyonBrownDeep = Color(0xFF3E2719);

  /// Captions and secondary text, and outlines. On [sand]: 5.89:1.
  static const Color canyonBrownMuted = Color(0xFF6E4F3E);

  /// Card background, slightly lighter than [sand] so cards stand out.
  static const Color sandLight = Color(0xFFFBF3E6);

  /// Error messages and error fills. White on it: 6.54:1. On [sand]: 5.22:1.
  static const Color error = Color(0xFFB3261E);

  /// Text and icons on dark fills ([burntOrangeDeep], [tealDeep], [error],
  /// [liveBlue]).
  static const Color white = Color(0xFFFFFFFF);

  // ─── UI kit additions (approved Road Runner UI kit) ─────────────────────────
  //
  // Colour meaning: BLUE = live running information (Run screen timer, pace,
  // speed, GPS "good", Live pill). TEAL ([tealDeep]) = saved running
  // statistics (Home, History, Summary).

  /// Live running information on the Run screen.
  /// On [sand]: 5.26:1. On [sandLight]: 5.98:1. White on it: 6.58:1.
  /// Its own 10% tint over [sandLight] (Live / GPS pill): 5.18:1.
  static const Color liveBlue = Color(0xFF2E5AAE);

  /// Fill of the small rounded square behind icons.
  /// Icons in [burntOrangeDeep] on it: 4.19:1 (icons need 3:1).
  /// Text on it (e.g. step numbers) must use [canyonBrownDeep]: 9.88:1 —
  /// [burntOrangeDeep] text fails 4.5:1 here.
  static const Color iconTile = Color(0xFFF6D2C2);

  /// Top of the header sky gradient (fades through [skyMid] into [sand]).
  /// Text on the sky must use [canyonBrown]: 5.56:1 here —
  /// [canyonBrownMuted] is only 4.06:1 and fails.
  static const Color skyTop = Color(0xFFA6C0FD);

  /// Middle of the header sky gradient. [canyonBrown] on it: 6.41:1.
  static const Color skyMid = Color(0xFFCCCCE5);

  /// Hairline dividers inside cards and lists: [canyonBrown] at 12% opacity.
  /// Decoration only — never a text colour.
  static const Color divider = Color(0x1F5B3A29);
}

/// Raw "moonlit desert" (night) colour tokens from the Road Runner UI kit
/// Revision 5 (Components and tokens sheet, night column, and the dark
/// screens).
///
/// Screens should not read these directly. Use the semantic roles in
/// `AppPalette` (app_palette.dart) through `context.palette`, which picks the
/// day or night value for the current theme. These constants exist so every
/// night value has one named, tested source.
///
/// Values marked "a11y" are deliberate deviations from the kit; the reason is
/// written next to each and checked in test/core/theme/dark_contrast_test.dart.
class AppDarkColors {
  AppDarkColors._();

  // ─── Surfaces ───────────────────────────────────────────────────────────────

  /// Screen background (kit `bg`).
  static const Color background = Color(0xFF171D2B);

  /// Cards, drawer, dialogs (kit `surface`).
  static const Color surface = Color(0xFF293247);

  /// 1px card border so cards separate from the background (kit `--border`).
  static const Color cardBorder = Color(0x0FF3E7D6); // textPrimary 6%

  /// Hairline dividers in lists and stat grids (kit `--hair`).
  static const Color hairline = Color(0x24D4C5B7); // textSecondary 14%

  /// Modal scrim behind the drawer and dialogs (kit dark screens: .76).
  static const Color scrim = Color(0xC2080A12);

  /// Round header icon-button fill (kit `.iconbtn`).
  static const Color iconButtonFill = Color(0xB8293247); // surface 72%

  // ─── Text ───────────────────────────────────────────────────────────────────

  /// Main text (kit `text.primary`). 13.80:1 on [background].
  static const Color textPrimary = Color(0xFFF3E7D6);

  /// Captions, labels, paused timer (kit `text.secondary`). 7.60:1 on
  /// [surface].
  static const Color textSecondary = Color(0xFFD4C5B7);

  // ─── Accents ────────────────────────────────────────────────────────────────

  /// Icons, links ("View all"), selected drawer icon, Pause border
  /// (kit `icon`). 5.49:1 on [surface].
  static const Color accent = Color(0xFFE8957A);

  /// a11y: text on an [iconTile] (selected drawer label, numbered steps).
  /// The kit uses [accent] there, which is only 4.16:1 on the tile over
  /// [surface]. This slightly lighter tint of the same hue is 4.83:1.
  static const Color accentOnTile = Color(0xFFF0A58D);

  /// Rounded square behind icons (kit `tile`: [accent] at 16%).
  static const Color iconTile = Color(0x29E8957A);

  /// Outlined (secondary) button border and inactive chip border
  /// (kit `outline`). Non-text: 3.02:1 on [surface], 3.97:1 on [background].
  static const Color outline = Color(0xFF8C7768);

  /// Saved-run statistics (kit `stat`, mint). 8.36:1 on [surface].
  static const Color stat = Color(0xFF8FE0CF);

  /// Live running information (kit `stat.live`). 6.19:1 on [surface].
  static const Color statLive = Color(0xFF91B4FE);

  /// Fastest-split row highlight (kit `highlight`: mint 12%).
  static const Color highlight = Color(0x1F8FE0CF);

  /// Weak GPS badge text and icon (kit `gps.weak`).
  static const Color gpsWeak = Color(0xFFFFCE29);

  /// a11y: error text and icons. The kit has no night error colour; the
  /// light [AppColors.error] is unreadable on navy, so this is Material 3's
  /// dark-scheme error. 7.53:1 on [surface].
  static const Color error = Color(0xFFFFB4AB);

  /// Text on an [error] fill (Material 3 dark `onError`).
  static const Color onError = Color(0xFF690005);

  // ─── Route map (Summary) ────────────────────────────────────────────────────

  /// Slower-pace band (kit `route.slow`). 7.30:1 on [mapBackground].
  static const Color routeSlow = Color(0xFF91B4FE);

  /// Steady-pace band (kit `route.steady`). 10.13:1 on [mapBackground].
  static const Color routeSteady = Color(0xFFFFCE29);

  /// Faster-pace band (kit `route.fast`). 5.35:1 on [mapBackground].
  static const Color routeFast = Color(0xFFFF6D0F);

  /// Neutral map background (kit `map.parchment`).
  static const Color mapBackground = Color(0xFF1F2638);

  /// Scale grid lines (kit `--grid`: textPrimary 6%).
  static const Color mapGrid = Color(0x0FF3E7D6);

  /// a11y: finish marker. The kit draws it in the primary fill `#A34A20`,
  /// which is only 2.55:1 on [mapBackground] (graphics need 3:1). The night
  /// [accent] (same hue family) is used instead.
  static const Color routeFinish = accent;

  // ─── Loading ────────────────────────────────────────────────────────────────

  /// Skeleton block fill (kit `skeleton`: textPrimary 9%).
  static const Color skeleton = Color(0x17F3E7D6);

  /// Shimmer sweep highlight (kit `.sk::after`: white 7%).
  static const Color shimmerHighlight = Color(0x12FFFFFF);

  // ─── Moonlit desert artwork ─────────────────────────────────────────────────

  /// Header sky gradient: [skyTop] → [skyMid] (55%) → [background].
  static const Color skyTop = Color(0xFF0E1430);
  static const Color skyMid = Color(0xFF1D2546);

  /// Splash sky: [splashTop] → [skyMid] → [mesa] → [background].
  static const Color splashTop = Color(0xFF0B1028);

  /// Moon disc and its crater shading.
  static const Color moon = Color(0xFFEEE1CB);
  static const Color moonCrater = Color(0xFFD8C9B2);

  /// Moon glow and stars ([textPrimary] at low opacity).
  static const Color moonGlow = Color(0x12F3E7D6); // 7%
  static const Color star = Color(0xB3F3E7D6); // 70%

  /// Landscape layers, back to front.
  static const Color mesa = Color(0xFF3E3B66);
  static const Color hills = Color(0xFF5C3E36);
  static const Color dunes = Color(0xFF2C3347);
  static const Color sandDune = Color(0xFF232A3B);

  /// Permission illustration: phone body and its map grid.
  static const Color phone = Color(0xFF222A3D);
  static const Color phoneGrid = Color(0xFF303A52);
}
