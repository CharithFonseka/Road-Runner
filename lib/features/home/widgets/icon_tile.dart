// Road Runner — small rounded tile behind an icon.
// Owner: Tharushi
// SRS reference: Section 8.4

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// 40dp rounded square in [AppColors.iconTile] holding a decorative icon.
///
/// Icons in [AppColors.burntOrangeDeep] on the tile are 4.19:1 (icons need
/// 3:1). The icon is decorative and hidden from screen readers.
class IconTile extends StatelessWidget {
  const IconTile({super.key, required this.icon});

  final IconData icon;

  static const double size = 40;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: AppColors.iconTile,
          borderRadius: BorderRadius.all(
            Radius.circular(AppSpacing.radiusTile),
          ),
        ),
        child: Icon(icon, size: 22, color: AppColors.burntOrangeDeep),
      ),
    );
  }
}
