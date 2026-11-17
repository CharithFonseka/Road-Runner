import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';

/// A quiet progress fill that animates updates and honors reduced motion.
class SmoothProgressBar extends StatelessWidget {
  const SmoothProgressBar({
    super.key,
    required this.value,
    this.height = 11,
    this.label,
  });

  final double value;
  final double height;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final progress = value.clamp(0.0, 1.0);
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Semantics(
      label: label,
      value: '${(progress * 100).round()}%',
      child: LayoutBuilder(
        builder: (context, constraints) => Container(
          height: height,
          decoration: BoxDecoration(
            color: palette.iconTile,
            borderRadius: BorderRadius.circular(height),
          ),
          clipBehavior: Clip.antiAlias,
          alignment: Alignment.centerLeft,
          child: AnimatedContainer(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            width: constraints.maxWidth * progress,
            height: height,
            decoration: BoxDecoration(
              color: palette.primaryFill,
              borderRadius: BorderRadius.circular(height),
            ),
          ),
        ),
      ),
    );
  }
}
