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
