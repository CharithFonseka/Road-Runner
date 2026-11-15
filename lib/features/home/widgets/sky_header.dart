// Road Runner — sky header with the day desert illustration.
// Owner: Tharushi
// SRS reference: Section 8.4, FR-70

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

/// Brand header: runner icon, title and subtitle on a sky gradient, with a
/// desert landscape drawn underneath.
///
/// Text on the sky uses [AppColors.canyonBrown] (5.56:1 on [AppColors.skyTop]);
/// the muted caption colour is too faint there.
class SkyHeader extends StatelessWidget {
  const SkyHeader({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  /// Height of the landscape strip (UI kit "tall" variant).
  static const double landscapeHeight = 110;

  @override
  Widget build(BuildContext context) {
    final double topInset = MediaQuery.paddingOf(context).top;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.skyTop, AppColors.skyMid, AppColors.sand],
          stops: [0.0, 0.52, 1.0],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.large,
              topInset + AppSpacing.large,
              AppSpacing.large,
              0,
            ),
            child: Row(
              children: [
                const ExcludeSemantics(
                  child: Icon(
                    Icons.directions_run_rounded,
                    size: 40,
                    color: AppColors.burntOrangeDeep,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(title, style: AppTextStyles.heading),
                      ),
                      Text(
                        subtitle,
                        style: AppTextStyles.body.copyWith(
                          fontSize: 14,
                          color: AppColors.canyonBrown,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Decorative only — hidden from screen readers.
          const ExcludeSemantics(
            child: SizedBox(
              height: landscapeHeight,
              width: double.infinity,
              child: CustomPaint(painter: DesertLandscapePainter()),
            ),
          ),
        ],
      ),
    );
  }
}

/// Day desert landscape: clouds, sun, mesas, hills and dunes.
///
/// Drawn on a 360 × 110 design grid (from the UI kit) and stretched to the
/// available size. Illustration colours are private: they are artwork, not
/// reusable theme tokens.
class DesertLandscapePainter extends CustomPainter {
  const DesertLandscapePainter();

  static const double _designWidth = 360;
  static const double _designHeight = 110;

  static const Color _sun = Color(0xFFFFD762);
  static const Color _cloud = Color(0xFFFFFFFF);
  static const Color _mesa = Color(0xFFC07358);
  static const Color _hills = Color(0xFFDF8583);
  static const Color _dunes = Color(0xFFFFCF91);
  static const Color _sandDune = Color(0xFFF2D6A6);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _designWidth, size.height / _designHeight);

    _paintClouds(canvas);
    _paintSun(canvas);

    // Mesas (flat-topped rock formations).
    const List<Offset> mesa = [
      Offset(0, 54),
      Offset(38, 54),
      Offset(48, 60),
      Offset(56, 74),
      Offset(86, 78),
      Offset(110, 74),
      Offset(156, 80),
      Offset(200, 76),
      Offset(240, 78),
      Offset(262, 66),
      Offset(276, 56),
      Offset(330, 56),
      Offset(340, 62),
      Offset(348, 54),
      Offset(360, 54),
    ];
    canvas.drawPath(
      _closedToBottom(Path()..addPolygon(mesa, false)),
      _fill(_mesa),
    );

    canvas.drawPath(
      _smoothCurve(const Offset(0, 78), const Offset(50, 66), const [
        Offset(100, 76),
        Offset(200, 78),
        Offset(300, 72),
        Offset(360, 70),
      ]),
      _fill(_hills),
    );
    canvas.drawPath(
      _smoothCurve(const Offset(0, 92), const Offset(80, 80), const [
        Offset(170, 90),
        Offset(360, 88),
      ]),
      _fill(_dunes),
    );
    canvas.drawPath(
      _smoothCurve(const Offset(0, 102), const Offset(120, 94), const [
        Offset(240, 102),
        Offset(360, 100),
      ]),
      _fill(_sandDune),
    );

    canvas.restore();
  }

  void _paintSun(Canvas canvas) {
    const Offset centre = Offset(296, 38);
    canvas.drawCircle(centre, 32, _fill(_sun.withValues(alpha: 0.18)));
    canvas.drawCircle(centre, 22, _fill(_sun.withValues(alpha: 0.30)));
    canvas.drawCircle(centre, 16, _fill(_sun));
  }

  void _paintClouds(Canvas canvas) {
    void cloud(double left, double base, double width, double alpha) {
      final Paint paint = _fill(_cloud.withValues(alpha: alpha));
      final double h = width * 0.22;
      canvas.drawRRect(
        RRect.fromLTRBR(
          left,
          base - h,
          left + width,
          base,
          Radius.circular(h / 2),
        ),
        paint,
      );
      canvas.drawCircle(Offset(left + width * 0.42, base - h), h, paint);
      canvas.drawCircle(
        Offset(left + width * 0.68, base - h * 0.8),
        h * 0.75,
        paint,
      );
    }

    cloud(34, 34, 46, 0.8);
    cloud(170, 20, 34, 0.7);
  }

  /// A quadratic curve from [start] through [control] to the first point of
  /// [ends], continued smoothly (SVG "T" command) through the remaining
  /// points, then closed down to the bottom edge.
  static Path _smoothCurve(Offset start, Offset control, List<Offset> ends) {
    final Path path = Path()..moveTo(start.dx, start.dy);
    Offset c = control;
    Offset previousEnd = start;
    for (int i = 0; i < ends.length; i++) {
      if (i > 0) {
        // Reflect the previous control point through the previous end.
        c = previousEnd * 2 - c;
      }
      path.quadraticBezierTo(c.dx, c.dy, ends[i].dx, ends[i].dy);
      previousEnd = ends[i];
    }
    return _closedToBottom(path);
  }

  static Path _closedToBottom(Path path) => path
    ..lineTo(_designWidth, _designHeight)
    ..lineTo(0, _designHeight)
    ..close();

  static Paint _fill(Color color) => Paint()
    ..color = color
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  @override
  bool shouldRepaint(covariant DesertLandscapePainter oldDelegate) => false;
}

// ─── Compact header (UI kit Revision 5, Home) ───────────────────────────────

/// Compact brand header: optional 48dp buttons either side of the title and
/// subtitle on the sky gradient, above the 72dp desert strip.
class CompactSkyHeader extends StatelessWidget {
  const CompactSkyHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.leading,
    this.trailing,
    this.showLandscape = true,
  });

  final String title;
  final String subtitle;
  final Widget? leading;
  final Widget? trailing;

  /// False leaves out the desert strip (very short screens).
  final bool showLandscape;

  /// Height of the compact landscape strip (UI kit "compact" variant).
  static const double landscapeHeight = 72;

  @override
  Widget build(BuildContext context) {
    final double topInset = MediaQuery.paddingOf(context).top;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.skyTop, AppColors.skyMid, AppColors.sand],
          stops: [0.0, 0.52, 1.0],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.medium,
              topInset + AppSpacing.small,
              AppSpacing.medium,
              0,
            ),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: AppSpacing.itemGap),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                            color: AppColors.canyonBrown,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                          color: AppColors.canyonBrown,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: AppSpacing.itemGap),
                  trailing!,
                ],
              ],
            ),
          ),
          if (showLandscape)
            const ExcludeSemantics(
              child: SizedBox(
                height: landscapeHeight,
                width: double.infinity,
                child: CustomPaint(painter: CompactLandscapePainter()),
              ),
            )
          else
            const SizedBox(height: AppSpacing.small),
        ],
      ),
    );
  }
}

/// 48dp round icon button on a translucent card fill, for the sky header.
/// [AppColors.canyonBrown] icons stay above 3:1 on the sky behind it.
class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  static const double size = AppSpacing.minTouchTarget;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon),
      iconSize: 24,
      style: IconButton.styleFrom(
        fixedSize: const Size.square(size),
        minimumSize: const Size.square(size),
        backgroundColor: AppColors.sandLight.withValues(alpha: 0.72),
        foregroundColor: AppColors.canyonBrown,
      ),
    );
  }
}

/// The UI kit's compact (72dp) desert strip: cloud, sun, mesa, hills and
/// dunes, drawn on a 360 × 72 grid and stretched to fit; the sun stays round.
class CompactLandscapePainter extends CustomPainter {
  const CompactLandscapePainter();

  static const double _w = 360;
  static const double _h = 72;

  static const Color _sun = Color(0xFFFFD762);
  static const Color _mesa = Color(0xFFC07358);
  static const Color _hills = Color(0xFFDF8583);
  static const Color _dunes = Color(0xFFFFCF91);
  static const Color _sandDune = Color(0xFFF2D6A6);

  @override
  void paint(Canvas canvas, Size size) {
    final double sx = size.width / _w;
    final double sy = size.height / _h;
    canvas.drawCircle(Offset(296 * sx, 22 * sy), 18 * sy, _fill(_sun));

    canvas.save();
    canvas.scale(sx, sy);
    // Cloud.
    final Paint cloud = _fill(Colors.white.withValues(alpha: 0.8));
    canvas.drawRRect(
      RRect.fromLTRBR(34, 28, 80, 34, const Radius.circular(3)),
      cloud,
    );
    canvas.drawCircle(const Offset(55, 28), 10, cloud);
    canvas.drawCircle(const Offset(68, 29), 7, cloud);
    canvas.drawCircle(const Offset(42, 31), 5, cloud);

    const List<Offset> mesa = [
      Offset(0, 30),
      Offset(34, 30),
      Offset(44, 36),
      Offset(52, 50),
      Offset(80, 54),
      Offset(104, 50),
      Offset(150, 56),
      Offset(196, 52),
      Offset(238, 54),
      Offset(262, 44),
      Offset(276, 34),
      Offset(326, 34),
      Offset(336, 40),
      Offset(344, 30),
      Offset(360, 30),
    ];
    canvas.drawPath(_toBottom(Path()..addPolygon(mesa, false)), _fill(_mesa));
    canvas.drawPath(
      _curve(const Offset(0, 50), const Offset(50, 40), const [
        Offset(100, 50),
        Offset(200, 52),
        Offset(300, 48),
        Offset(360, 46),
      ]),
      _fill(_hills),
    );
    canvas.drawPath(
      _curve(const Offset(0, 60), const Offset(80, 50), const [
        Offset(170, 60),
        Offset(360, 58),
      ]),
      _fill(_dunes),
    );
    canvas.drawPath(
      _curve(const Offset(0, 68), const Offset(120, 62), const [
        Offset(240, 68),
        Offset(360, 66),
      ]),
      _fill(_sandDune),
    );
    canvas.restore();
  }

  /// Quadratic curve with SVG "T" continuation, closed to the bottom edge.
  static Path _curve(Offset start, Offset control, List<Offset> ends) {
    final Path path = Path()..moveTo(start.dx, start.dy);
    Offset c = control;
    Offset previousEnd = start;
    for (int i = 0; i < ends.length; i++) {
      if (i > 0) c = previousEnd * 2 - c;
      path.quadraticBezierTo(c.dx, c.dy, ends[i].dx, ends[i].dy);
      previousEnd = ends[i];
    }
    return _toBottom(path);
  }

  static Path _toBottom(Path path) => path
    ..lineTo(_w, _h)
    ..lineTo(0, _h)
    ..close();

  static Paint _fill(Color color) => Paint()
    ..color = color
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  @override
  bool shouldRepaint(covariant CompactLandscapePainter oldDelegate) => false;
}
