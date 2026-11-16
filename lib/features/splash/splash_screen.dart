// Road Runner — Splash (start-up) screen.
// Owner: Tharushi
// SRS reference: Section 8.4, FR-70, FR-71, NFR-09, NFR-14
//
// Purely presentational. It shows the brand and a progress indicator while
// the app shell does its REAL start-up work (opening the database, reading
// the tracking state, checking for an unfinished run). It has no timer, no
// fixed delay and never navigates: the parent decides when start-up is done
// and replaces it. See lib/features/splash/README.md.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text_styles.dart';
import '../app_strings.dart';

/// Sunrise or moonlit desert splash: runner tile, "Road Runner" and a spinner.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  static const Key brandKey = Key('splash.brand');
  static const Key progressKey = Key('splash.progress');
  static const Key spinnerKey = Key('splash.spinner');
  static const Key landscapeKey = Key('splash.landscape');

  static const Duration normalSpinDuration = Duration(seconds: 1);
  static const Duration reducedMotionSpinDuration = Duration(
    milliseconds: 2400,
  );

  /// Largest share of the screen height the landscape may take, so the
  /// brand always has room on short phones.
  static const double _maxLandscapeShare = 0.45;
  static const Key skyKey = Key('splash.sky');

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: palette.splashGradient),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isLandscape =
                constraints.maxWidth > constraints.maxHeight &&
                constraints.maxWidth >= 500;
            final double share = isLandscape
                ? (constraints.maxHeight < 340 ? 0.20 : 0.24)
                : _maxLandscapeShare;
            final double landscapeHeight = math.min(
              SplashLandscapePainter.designHeight *
                  constraints.maxWidth /
                  SplashLandscapePainter.designWidth,
              constraints.maxHeight * share,
            );
            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: ExcludeSemantics(
                    child: CustomPaint(
                      key: skyKey,
                      painter: SplashSkyPainter(palette: palette),
                    ),
                  ),
                ),
                // Decorative; drawn first so it stays behind the brand.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: landscapeHeight,
                  child: ExcludeSemantics(
                    child: CustomPaint(
                      key: landscapeKey,
                      painter: SplashLandscapePainter(palette: palette),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  bottom: landscapeHeight,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: LayoutBuilder(
                        builder: (context, area) => Center(
                          // Never overflows: a long name wraps within the
                          // width; only if the height still runs out (tiny
                          // screen, very large text) does the brand shrink.
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: area.maxWidth,
                              ),
                              child: const _Brand(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  static const double _tileSize = 116;
  static const double _iconSize = 70;
  static const double _nameSize = 34;
  static const double _progressSize = 40;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Column(
      key: SplashScreen.brandKey,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Container(
            width: _tileSize,
            height: _tileSize,
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.all(Radius.circular(34)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x2E000000),
                  blurRadius: 34,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: Icon(
              Icons.directions_run_rounded,
              size: _iconSize,
              color: palette.accent,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: Text(
            AppStrings.appName,
            textAlign: TextAlign.center,
            style: AppTextStyles.of(context).heading.copyWith(
              fontSize: _nameSize,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 28),
        // One spoken label; the indicator's own (percentage) semantics are
        // hidden so a still reduced-motion arc is never read as "25%".
        Semantics(
          key: SplashScreen.progressKey,
          container: true,
          label: AppStrings.splashLoading,
          child: const ExcludeSemantics(child: _SplashSpinner()),
        ),
      ],
    );
  }
}

class _SplashSpinner extends StatefulWidget {
  const _SplashSpinner();

  @override
  State<_SplashSpinner> createState() => _SplashSpinnerState();
}

class _SplashSpinnerState extends State<_SplashSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotation = AnimationController(
    vsync: this,
    duration: SplashScreen.normalSpinDuration,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Duration duration = MediaQuery.disableAnimationsOf(context)
        ? SplashScreen.reducedMotionSpinDuration
        : SplashScreen.normalSpinDuration;
    if (_rotation.duration == duration && _rotation.isAnimating) return;
    _rotation
      ..stop()
      ..duration = duration
      ..repeat();
  }

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return RotationTransition(
      key: SplashScreen.spinnerKey,
      turns: _rotation,
      child: SizedBox.square(
        dimension: _Brand._progressSize,
        child: CircularProgressIndicator(
          value: 0.25,
          strokeWidth: 4,
          strokeCap: StrokeCap.round,
          color: palette.accent,
          backgroundColor: palette.isDark
              ? palette.hairline
              : const Color(0x295B3A29),
        ),
      ),
    );
  }
}

/// Stars across the full dark splash sky.
class SplashSkyPainter extends CustomPainter {
  const SplashSkyPainter({required this.palette});

  final AppPalette palette;

  static const List<(Offset, double, double)> _stars = [
    (Offset(40, 80), 1.4, 0.8),
    (Offset(120, 140), 1, 0.6),
    (Offset(300, 96), 1.5, 0.8),
    (Offset(250, 190), 1, 0.5),
    (Offset(70, 240), 1.2, 0.6),
    (Offset(330, 300), 1, 0.5),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (!palette.isDark) return;
    canvas.save();
    canvas.scale(size.width / 360, size.height / 800);
    for (final (Offset centre, double radius, double opacity) in _stars) {
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..color = palette.skyDecoration.withValues(alpha: opacity)
          ..isAntiAlias = true,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SplashSkyPainter oldDelegate) =>
      palette != oldDelegate.palette;
}

/// Sunrise desert from the UI kit splash: a low sun behind mesas, hills and
/// dunes, or the matching moonlit landscape.
///
/// Drawn on the kit's 360 × 800 grid, using only its lower part (from
/// [designTop] down), scaled uniformly by width and anchored to the bottom
/// edge so it never stretches.
class SplashLandscapePainter extends CustomPainter {
  const SplashLandscapePainter({this.palette});

  final AppPalette? palette;

  static const double designWidth = 360;
  static const double designTop = 424; // top of the sun's glow
  static const double designBottom = 800;
  static const double designHeight = designBottom - designTop;

  @override
  void paint(Canvas canvas, Size size) {
    final AppPalette p = palette ?? AppPalette.light;
    final double scale = size.width / designWidth;
    canvas.save();
    canvas.translate(0, size.height);
    canvas.scale(scale);
    canvas.translate(0, -designBottom);

    const Offset sunCentre = Offset(180, 520);
    if (p.isDark) {
      canvas.drawCircle(sunCentre, 80, _fill(p.celestialGlow));
      canvas.drawCircle(sunCentre, 46, _fill(p.celestial));
      canvas.drawCircle(const Offset(168, 510), 7, _fill(p.celestialDetail));
      canvas.drawCircle(const Offset(194, 534), 5, _fill(p.celestialDetail));
    } else {
      canvas.drawCircle(sunCentre, 96, _fill(p.celestialGlow));
      canvas.drawCircle(sunCentre, 64, _fill(p.celestial));
    }

    const List<Offset> mesa = [
      Offset(0, 560),
      Offset(60, 560),
      Offset(74, 572),
      Offset(86, 600),
      Offset(130, 608),
      Offset(176, 600),
      Offset(220, 610),
      Offset(262, 604),
      Offset(290, 588),
      Offset(304, 566),
      Offset(360, 566),
    ];
    canvas.drawPath(
      _closedToBottom(Path()..addPolygon(mesa, false)),
      _fill(p.mesa),
    );
    canvas.drawPath(
      _smoothCurve(const Offset(0, 628), const Offset(60, 604), const [
        Offset(130, 622),
        Offset(260, 626),
        Offset(360, 612),
      ]),
      _fill(p.hills),
    );
    canvas.drawPath(
      _smoothCurve(const Offset(0, 672), const Offset(90, 650), const [
        Offset(180, 668),
        Offset(360, 662),
      ]),
      _fill(p.dunes),
    );
    canvas.drawPath(
      _smoothCurve(const Offset(0, 716), const Offset(120, 700), const [
        Offset(240, 716),
        Offset(360, 712),
      ]),
      _fill(p.sandDune),
    );
    canvas.restore();
  }

  /// Quadratic curve through [ends], each later control point reflected
  /// from the previous one (SVG "T"), then closed down to the bottom edge.
  static Path _smoothCurve(Offset start, Offset control, List<Offset> ends) {
    final Path path = Path()..moveTo(start.dx, start.dy);
    Offset c = control;
    Offset previousEnd = start;
    for (int i = 0; i < ends.length; i++) {
      if (i > 0) c = previousEnd * 2 - c;
      path.quadraticBezierTo(c.dx, c.dy, ends[i].dx, ends[i].dy);
      previousEnd = ends[i];
    }
    return _closedToBottom(path);
  }

  static Path _closedToBottom(Path path) => path
    ..lineTo(designWidth, designBottom)
    ..lineTo(0, designBottom)
    ..close();

  static Paint _fill(Color color) => Paint()
    ..color = color
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  @override
  bool shouldRepaint(covariant SplashLandscapePainter oldDelegate) =>
      palette != oldDelegate.palette;
}
