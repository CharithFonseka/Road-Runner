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

import '../../core/theme/app_colors.dart';
import '../app_strings.dart';

/// Sunrise desert splash: runner tile, "Road Runner" and a loading spinner.
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

  // Sky gradient from the UI kit splash. Artwork colours, not theme tokens.
  static const List<Color> _sky = [
    Color(0xFF8FB1F9),
    Color(0xFFBFC9EE),
    Color(0xFFFFCF91),
    AppColors.sand,
  ];
  static const List<double> _skyStops = [0.0, 0.38, 0.66, 1.0];

  /// Largest share of the screen height the landscape may take, so the
  /// brand always has room on short phones.
  static const double _maxLandscapeShare = 0.45;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.sand,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _sky,
            stops: _skyStops,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double landscapeHeight = math.min(
              SplashLandscapePainter.designHeight *
                  constraints.maxWidth /
                  SplashLandscapePainter.designWidth,
              constraints.maxHeight * _maxLandscapeShare,
            );
            return Stack(
              fit: StackFit.expand,
              children: [
                // Decorative; drawn first so it stays behind the brand.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: landscapeHeight,
                  child: const ExcludeSemantics(
                    child: CustomPaint(
                      key: landscapeKey,
                      painter: SplashLandscapePainter(),
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
    return Column(
      key: SplashScreen.brandKey,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Container(
            width: _tileSize,
            height: _tileSize,
            decoration: const BoxDecoration(
              color: AppColors.sandLight,
              borderRadius: BorderRadius.all(Radius.circular(34)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x2E000000),
                  blurRadius: 34,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: const Icon(
              Icons.directions_run_rounded,
              size: _iconSize,
              color: AppColors.burntOrangeDeep,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: const Text(
            AppStrings.appName,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: _nameSize,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              height: 1.2,
              color: AppColors.canyonBrown,
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
    return RotationTransition(
      key: SplashScreen.spinnerKey,
      turns: _rotation,
      child: const SizedBox.square(
        dimension: _Brand._progressSize,
        child: CircularProgressIndicator(
          value: 0.25,
          strokeWidth: 4,
          strokeCap: StrokeCap.round,
          color: AppColors.burntOrangeDeep,
          backgroundColor: Color(0x295B3A29),
        ),
      ),
    );
  }
}

/// Sunrise desert from the UI kit splash: a low sun behind mesas, hills and
/// dunes.
///
/// Drawn on the kit's 360 × 800 grid, using only its lower part (from
/// [designTop] down), scaled uniformly by width and anchored to the bottom
/// edge so it never stretches.
class SplashLandscapePainter extends CustomPainter {
  const SplashLandscapePainter();

  static const double designWidth = 360;
  static const double designTop = 424; // top of the sun's glow
  static const double designBottom = 800;
  static const double designHeight = designBottom - designTop;

  static const Color _sun = Color(0xFFFFD762);
  static const Color _mesa = Color(0xFFC07358);
  static const Color _hills = Color(0xFFDF8583);
  static const Color _dunes = Color(0xFFFFCF91);
  static const Color _sandDune = Color(0xFFF2D6A6);

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / designWidth;
    canvas.save();
    canvas.translate(0, size.height);
    canvas.scale(scale);
    canvas.translate(0, -designBottom);

    const Offset sunCentre = Offset(180, 520);
    canvas.drawCircle(sunCentre, 96, _fill(_sun.withValues(alpha: 0.35)));
    canvas.drawCircle(sunCentre, 64, _fill(_sun));

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
      _fill(_mesa),
    );
    canvas.drawPath(
      _smoothCurve(const Offset(0, 628), const Offset(60, 604), const [
        Offset(130, 622),
        Offset(260, 626),
        Offset(360, 612),
      ]),
      _fill(_hills),
    );
    canvas.drawPath(
      _smoothCurve(const Offset(0, 672), const Offset(90, 650), const [
        Offset(180, 668),
        Offset(360, 662),
      ]),
      _fill(_dunes),
    );
    canvas.drawPath(
      _smoothCurve(const Offset(0, 716), const Offset(120, 700), const [
        Offset(240, 716),
        Offset(360, 712),
      ]),
      _fill(_sandDune),
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
  bool shouldRepaint(covariant SplashLandscapePainter oldDelegate) => false;
}
