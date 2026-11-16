// Road Runner — sky header with theme-aware desert artwork.
// Owner: Tharushi
// SRS reference: Section 8.4, FR-70

import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

/// Brand header: runner icon, title and subtitle on a sky gradient, with a
/// desert landscape drawn underneath.
///
/// Text and artwork use the active [AppPalette] for either sky.
class SkyHeader extends StatelessWidget {
  const SkyHeader({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  /// Height of the landscape strip (UI kit "tall" variant).
  static const double landscapeHeight = 110;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final double topInset = MediaQuery.paddingOf(context).top;
    return DecoratedBox(
      decoration: BoxDecoration(gradient: palette.skyGradient),
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
                ExcludeSemantics(
                  child: Icon(
                    Icons.directions_run_rounded,
                    size: 40,
                    color: palette.accent,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          title,
                          style: AppTextStyles.of(context).heading,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: AppTextStyles.of(context).body
                            .copyWith(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Decorative only — hidden from screen readers.
          ExcludeSemantics(
            child: SizedBox(
              height: landscapeHeight,
              width: double.infinity,
              child: CustomPaint(
                painter: DesertLandscapePainter(palette: palette),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Desert landscape: daytime clouds and sun or nighttime stars and moon,
/// followed by mesas, hills and dunes.
///
/// Drawn on a 360 × 110 design grid (from the UI kit) and stretched to the
/// available size. Illustration colours are private: they are artwork, not
/// reusable theme tokens.
class DesertLandscapePainter extends CustomPainter {
  const DesertLandscapePainter({this.palette});

  final AppPalette? palette;

  static const double _designWidth = 360;
  static const double _designHeight = 110;

  @override
  void paint(Canvas canvas, Size size) {
    final AppPalette p = palette ?? AppPalette.light;
    canvas.save();
    canvas.scale(size.width / _designWidth, size.height / _designHeight);

    if (p.isDark) {
      _paintNightSky(canvas, p);
    } else {
      _paintClouds(canvas);
      _paintSun(canvas, p);
    }

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
      _fill(p.mesa),
    );

    canvas.drawPath(
      _smoothCurve(const Offset(0, 78), const Offset(50, 66), const [
        Offset(100, 76),
        Offset(200, 78),
        Offset(300, 72),
        Offset(360, 70),
      ]),
      _fill(p.hills),
    );
    canvas.drawPath(
      _smoothCurve(const Offset(0, 92), const Offset(80, 80), const [
        Offset(170, 90),
        Offset(360, 88),
      ]),
      _fill(p.dunes),
    );
    canvas.drawPath(
      _smoothCurve(const Offset(0, 102), const Offset(120, 94), const [
        Offset(240, 102),
        Offset(360, 100),
      ]),
      _fill(p.sandDune),
    );

    canvas.restore();
  }

  void _paintSun(Canvas canvas, AppPalette palette) {
    const Offset centre = Offset(296, 38);
    canvas.drawCircle(
      centre,
      32,
      _fill(palette.celestial.withValues(alpha: 0.18)),
    );
    canvas.drawCircle(
      centre,
      22,
      _fill(palette.celestial.withValues(alpha: 0.30)),
    );
    canvas.drawCircle(centre, 16, _fill(palette.celestial));
  }

  void _paintNightSky(Canvas canvas, AppPalette palette) {
    const List<(Offset, double, double)> stars = [
      (Offset(210, 10), 1.2, 0.7),
      (Offset(250, 28), 1, 0.5),
      (Offset(340, 8), 1.3, 0.7),
      (Offset(168, 22), 1, 0.4),
      (Offset(60, 14), 1, 0.5),
    ];
    for (final (Offset centre, double radius, double opacity) in stars) {
      canvas.drawCircle(
        centre,
        radius,
        _fill(palette.skyDecoration.withValues(alpha: opacity)),
      );
    }
    const Offset moon = Offset(296, 38);
    canvas.drawCircle(moon, 32, _fill(palette.celestialGlow));
    canvas.drawCircle(moon, 22, _fill(palette.celestial));
    canvas.drawCircle(const Offset(288, 33), 3, _fill(palette.celestialDetail));
  }

  void _paintClouds(Canvas canvas) {
    void cloud(double left, double base, double width, double alpha) {
      final Paint paint = _fill(Colors.white.withValues(alpha: alpha));
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
  bool shouldRepaint(covariant DesertLandscapePainter oldDelegate) =>
      palette != oldDelegate.palette;
}

// ─── Compact header (UI kit Revision 5, Home) ───────────────────────────────

/// Compact brand header: optional 48dp buttons either side of the title and
/// subtitle on the sky gradient, above the 72dp desert strip.
class CompactSkyHeader extends StatelessWidget {
  const CompactSkyHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.showLandscape = true,
    this.landscapeHeight = compactLandscapeHeight,
    this.landscapePainter = const CompactLandscapePainter(),
  });

  final String title;

  /// Optional second line under the title.
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;

  /// False leaves out the desert strip (very short screens).
  final bool showLandscape;

  /// Strip height: 72 (compact, Home) or 40 (slim, inner screens).
  final double landscapeHeight;

  /// Strip artwork; the slim variant uses DrawerLandscapePainter.
  final CustomPainter landscapePainter;

  /// Height of the compact landscape strip (UI kit "compact" variant).
  static const double compactLandscapeHeight = 72;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final CustomPainter requestedPainter = landscapePainter;
    final CustomPainter painter =
        requestedPainter is CompactLandscapePainter &&
            requestedPainter.palette == null
        ? CompactLandscapePainter(palette: palette)
        : requestedPainter;
    final double topInset = MediaQuery.paddingOf(context).top;
    return DecoratedBox(
      decoration: BoxDecoration(gradient: palette.skyGradient),
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
                          style: AppTextStyles.of(context).heading
                              .copyWith(fontSize: 24, height: 1.15),
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.of(context).body.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                          ),
                        ),
                      ],
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
            ExcludeSemantics(
              child: SizedBox(
                height: landscapeHeight,
                width: double.infinity,
                child: CustomPaint(painter: painter),
              ),
            )
          else
            const SizedBox(height: AppSpacing.small),
        ],
      ),
    );
  }
}

/// 48dp round icon button on a translucent surface fill, for the sky header.
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
    final AppPalette palette = AppPalette.of(context);
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon),
      iconSize: 24,
      style: IconButton.styleFrom(
        fixedSize: const Size.square(size),
        minimumSize: const Size.square(size),
        backgroundColor: palette.iconButtonFill,
        foregroundColor: palette.textPrimary,
      ),
    );
  }
}

/// The UI kit's compact (72dp) desert strip, drawn on a 360 × 72 grid and
/// stretched to fit; the sun and moon stay round.
class CompactLandscapePainter extends CustomPainter {
  const CompactLandscapePainter({this.palette});

  final AppPalette? palette;

  static const double _w = 360;
  static const double _h = 72;

  @override
  void paint(Canvas canvas, Size size) {
    final AppPalette p = palette ?? AppPalette.light;
    final double sx = size.width / _w;
    final double sy = size.height / _h;
    if (p.isDark) {
      _paintNightSky(canvas, sx, sy, p);
    } else {
      canvas.drawCircle(Offset(296 * sx, 22 * sy), 18 * sy, _fill(p.celestial));
    }

    canvas.save();
    canvas.scale(sx, sy);
    if (!p.isDark) {
      // Cloud.
      final Paint cloud = _fill(Colors.white.withValues(alpha: 0.8));
      canvas.drawRRect(
        RRect.fromLTRBR(34, 28, 80, 34, const Radius.circular(3)),
        cloud,
      );
      canvas.drawCircle(const Offset(55, 28), 10, cloud);
      canvas.drawCircle(const Offset(68, 29), 7, cloud);
      canvas.drawCircle(const Offset(42, 31), 5, cloud);
    }

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
    canvas.drawPath(_toBottom(Path()..addPolygon(mesa, false)), _fill(p.mesa));
    canvas.drawPath(
      _curve(const Offset(0, 50), const Offset(50, 40), const [
        Offset(100, 50),
        Offset(200, 52),
        Offset(300, 48),
        Offset(360, 46),
      ]),
      _fill(p.hills),
    );
    canvas.drawPath(
      _curve(const Offset(0, 60), const Offset(80, 50), const [
        Offset(170, 60),
        Offset(360, 58),
      ]),
      _fill(p.dunes),
    );
    canvas.drawPath(
      _curve(const Offset(0, 68), const Offset(120, 62), const [
        Offset(240, 68),
        Offset(360, 66),
      ]),
      _fill(p.sandDune),
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

  void _paintNightSky(Canvas canvas, double sx, double sy, AppPalette p) {
    const List<(Offset, double, double)> stars = [
      (Offset(210, 10), 1.2, 0.7),
      (Offset(250, 28), 1, 0.5),
      (Offset(340, 8), 1.3, 0.7),
      (Offset(168, 22), 1, 0.4),
      (Offset(60, 14), 1, 0.5),
    ];
    for (final (Offset point, double radius, double opacity) in stars) {
      canvas.drawCircle(
        Offset(point.dx * sx, point.dy * sy),
        radius * sy,
        _fill(p.skyDecoration.withValues(alpha: opacity)),
      );
    }
    final Offset moon = Offset(296 * sx, 22 * sy);
    canvas.drawCircle(moon, 24 * sy, _fill(p.celestialGlow));
    canvas.drawCircle(moon, 14 * sy, _fill(p.celestial));
    canvas.drawCircle(
      Offset(292 * sx, 19 * sy),
      2.5 * sy,
      _fill(p.celestialDetail),
    );
  }

  @override
  bool shouldRepaint(covariant CompactLandscapePainter oldDelegate) =>
      palette != oldDelegate.palette;
}
