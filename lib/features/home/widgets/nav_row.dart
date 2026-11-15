// Road Runner — tappable navigation row (icon tile, title, subtitle, chevron).
// Owner: Tharushi
// SRS reference: Section 8.4, NFR-09

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import 'icon_tile.dart';

/// One navigation row, e.g. "History — View your past runs".
///
/// The whole row is the tap target (well over 48dp tall) and is announced to
/// screen readers as a single button: "title, subtitle".
class NavRow extends StatelessWidget {
  const NavRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.minTouchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.medium,
                vertical: 14,
              ),
              child: Row(
                children: [
                  IconTile(icon: icon),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTextStyles.sectionHeading.copyWith(
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(subtitle, style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                  const ExcludeSemantics(
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.canyonBrownMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
