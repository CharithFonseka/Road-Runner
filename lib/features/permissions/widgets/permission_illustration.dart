// Road Runner — Permissions illustration: one runner on a desert trail
// heading to a location pin.
// Owner: Tharushi
// SRS reference: Section 8.4
//
// One neutral runner figure (no gendered variants). Decorative only, so it
// is hidden from screen readers. Reuses the Home desert landscape.

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../home/widgets/sky_header.dart';

class PermissionIllustration extends StatelessWidget {
  const PermissionIllustration({super.key});

  static const double height = 112;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: const BorderRadius.all(
          Radius.circular(AppSpacing.radiusTile),
        ),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const CustomPaint(painter: DesertLandscapePainter()),
              const CustomPaint(painter: _TrailPainter()),
              LayoutBuilder(
                builder: (context, c) => Stack(
                  children: [
                    Positioned(
                      left: c.maxWidth * 0.26,
                      bottom: 18,
                      child: const Icon(
                        Icons.directions_run_rounded,
                        size: 44,
                        color: AppColors.burntOrangeDeep,
                      ),
                    ),
                    Positioned(
                      left: c.maxWidth * 0.64,
                      bottom: 40,
                      child: const Icon(
                        Icons.location_on_outlined,
                        size: 40,
                        color: AppColors.burntOrangeDeep,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dashed teal trail from the runner to the pin.
class _TrailPainter extends CustomPainter {
  const _TrailPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Path path = Path()
      ..moveTo(w * 0.30, h * 0.86)
      ..cubicTo(w * 0.62, h * 0.98, w * 0.62, h * 0.70, w * 0.48, h * 0.66)
      ..cubicTo(w * 0.40, h * 0.62, w * 0.50, h * 0.48, w * 0.68, h * 0.56);
    final Paint paint = Paint()
      ..color = AppColors.tealDeep
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 8), paint);
        d += 14;
      }
    }
  }

  @override
  bool shouldRepaint(_TrailPainter oldDelegate) => false;
}
