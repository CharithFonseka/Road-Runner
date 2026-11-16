// Road Runner — small rounded tile behind an icon.
// Owner: Tharushi
// SRS reference: Section 8.4

import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_spacing.dart';

/// 40dp rounded square in the palette's `iconTile` holding a decorative
/// `accent` icon.
///
/// Icons need 3:1: day burnt orange on the tile is 4.19:1; night accent on
/// the tile over a card is 4.16:1. The icon is decorative and hidden from
/// screen readers.
class IconTile extends StatelessWidget {
  const IconTile({super.key, required this.icon});

  final IconData icon;

  static const double size = 40;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: palette.iconTile,
          borderRadius: const BorderRadius.all(
            Radius.circular(AppSpacing.radiusTile),
          ),
        ),
        child: Icon(icon, size: 22, color: palette.accent),
      ),
    );
  }
}
