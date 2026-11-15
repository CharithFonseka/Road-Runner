// Road Runner — large Pause / Resume / Stop buttons.
// Owner: Tharushi
// SRS reference: Section 8.4, NFR-09
//
// The button fills the space it is given (never smaller than 48dp). When it
// is tall, the icon sits above the label; when it is short, beside it.

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

/// Height from which the icon is placed above the label.
const double _stackedLayoutMinHeight = 96;

/// A large rounded control. [filled] buttons are the strong action (Stop);
/// outlined ones are the calm action (Pause / Resume).
class RunControlButton extends StatelessWidget {
  const RunControlButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool filled;

  static const OutlinedBorder _shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppSpacing.radiusLarge)),
  );

  static const Size _minSize = Size(
    AppSpacing.minTouchTarget,
    AppSpacing.minTouchTarget,
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool stacked = constraints.maxHeight >= _stackedLayoutMinHeight;
        final Widget content = _content(stacked);
        final Widget button = filled
            ? FilledButton(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.burntOrangeDeep,
                  foregroundColor: AppColors.white,
                  minimumSize: _minSize,
                  shape: _shape,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: content,
              )
            : OutlinedButton(
                onPressed: onPressed,
                style: OutlinedButton.styleFrom(
                  minimumSize: _minSize,
                  shape: _shape,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  side: BorderSide(
                    color: onPressed == null
                        ? AppColors.canyonBrown.withValues(alpha: 0.24)
                        : AppColors.burntOrangeDeep,
                    width: 2,
                  ),
                ),
                child: content,
              );
        return SizedBox.expand(child: button);
      },
    );
  }

  Widget _content(bool stacked) {
    final Text text = Text(
      label,
      textAlign: TextAlign.center,
      style: AppTextStyles.button.copyWith(fontSize: 20),
    );
    if (stacked) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 36), const SizedBox(height: 4), text],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 28),
        const SizedBox(width: AppSpacing.small),
        Flexible(child: text),
      ],
    );
  }
}
