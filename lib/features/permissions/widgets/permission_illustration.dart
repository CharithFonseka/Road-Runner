// Road Runner — Permissions illustration (UI kit Revision 5).
// Owner: Tharushi
// SRS reference: Section 8.4
//
// The kit's 328 × 160 scene: dunes, a phone showing the permission's state,
// a cactus, and the original female and male runner artwork
// (assets/illustrations/, 1x–4x). Running figures on the explanation scene,
// standing figures when location is denied or Location Services are off.
//
// Decorative only: the whole scene is hidden from screen readers, because
// the screen text carries the meaning. It scales down (never up) to fit
// narrow screens, so both figures always stay fully visible.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../app_strings.dart';

/// Which scene to draw.
enum PermissionScene {
  /// Explanation before asking: running figures, phone with route and pin.
  explain,

  /// Location permission denied: standing figures, phone with crossed pin.
  locationDenied,

  /// Device Location Services off: standing figures, phone with OFF switch.
  servicesOff,
}

/// Asset paths of the four runner illustrations. Flutter picks the 2.0x,
/// 3.0x or 4.0x variant from the same folder automatically.
class RunnerAssets {
  RunnerAssets._();

  static const String folder = 'assets/illustrations';
  static const String maleRunning = '$folder/runner_male_running.png';
  static const String femaleRunning = '$folder/runner_female_running.png';
  static const String maleStanding = '$folder/runner_male_standing.png';
  static const String femaleStanding = '$folder/runner_female_standing.png';

  static const List<String> all = [
    maleRunning,
    femaleRunning,
    maleStanding,
    femaleStanding,
  ];

  /// Resolution folders shipped next to the 1x files.
  static const List<String> densities = ['2.0x', '3.0x', '4.0x'];
}

class PermissionIllustration extends StatelessWidget {
  const PermissionIllustration({super.key, required this.scene});

  final PermissionScene scene;

  /// Design size from the UI kit, in dp.
  static const Size designSize = Size(328, 160);

  /// Display height of each figure (the 1x files are 128 px tall).
  static const double figureHeight = 128;

  static const Key femaleKey = Key('permissions.figure.female');
  static const Key maleKey = Key('permissions.figure.male');

  bool get _running => scene == PermissionScene.explain;

  @override
  Widget build(BuildContext context) {
    final String female = _running
        ? RunnerAssets.femaleRunning
        : RunnerAssets.femaleStanding;
    final String male = _running
        ? RunnerAssets.maleRunning
        : RunnerAssets.maleStanding;
    // Kit positions: running pair at x 0 and 88, standing pair at 53 and 104.
    final double femaleX = _running ? 0 : 53;
    final double maleX = _running ? 88 : 104;

    return ExcludeSemantics(
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox.fromSize(
            size: designSize,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _ScenePainter(scene)),
                ),
                if (scene == PermissionScene.explain)
                  // Notification badge on the phone.
                  const Positioned(
                    left: 277,
                    top: 13,
                    width: 18,
                    height: 18,
                    child: Icon(
                      Icons.notifications_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                if (scene == PermissionScene.servicesOff)
                  const Positioned(
                    left: 228,
                    top: 40,
                    child: Icon(
                      Icons.location_on_outlined,
                      size: 28,
                      color: _ScenePainter._muted,
                    ),
                  ),
                Positioned(
                  left: femaleX,
                  top: 12,
                  height: figureHeight,
                  child: _Figure(key: femaleKey, asset: female),
                ),
                Positioned(
                  left: maleX,
                  top: 12,
                  height: figureHeight,
                  child: _Figure(key: maleKey, asset: male),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({super.key, required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      height: PermissionIllustration.figureHeight,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
      filterQuality: FilterQuality.medium,
      // A missing file must never break the permission flow.
      errorBuilder: (context, error, stack) =>
          const SizedBox(height: PermissionIllustration.figureHeight),
    );
  }
}

/// Backdrop drawn on the 328 × 160 kit grid.
class _ScenePainter extends CustomPainter {
  const _ScenePainter(this.scene);

  final PermissionScene scene;

  static const Color _dunes = Color(0xFFFFCF91);
  static const Color _sandDune = Color(0xFFF2D6A6);
  static const Color _pink = Color(0xFFE58C8A);
  static const Color _shadow = Color(0x245B3A29); // canyonBrown 14%
  static const Color _phone = Color(0xFFFBF3E6);
  static const Color _outline = Color(0xFF5B3A29);
  static const Color _grid = Color(0xFFEBDAC0);
  static const Color _blue = Color(0xFF2E5AAE);
  static const Color _orange = Color(0xFFA34A20);
  static const Color _muted = Color(0xFFB49A86);
  static const Color _cactus = Color(0xFFC07358);
  static const Color _label = Color(0xFF6E4F3E);
  static const Color _badgeRing = Color(0xFFF4E4C8);

  bool get _running => scene == PermissionScene.explain;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 328, size.height / 160);

    // Ground.
    canvas.drawPath(
      _curve(const Offset(0, 136), const Offset(82, 124), const [
        Offset(164, 134),
        Offset(328, 130),
      ]),
      _fill(_dunes),
    );
    canvas.drawPath(
      _curve(const Offset(0, 148), const Offset(102, 140), const [
        Offset(204, 148),
        Offset(328, 146),
      ]),
      _fill(_sandDune),
    );
    final Paint sparkle = _fill(_pink.withValues(alpha: 0.85));
    canvas.drawCircle(const Offset(300, 44), 2.4, sparkle);
    canvas.drawCircle(const Offset(316, 22), 1.8, sparkle);
    canvas.drawCircle(const Offset(182, 18), 1.6, sparkle);

    // Figure shadows.
    final Paint shadow = _fill(_shadow);
    if (_running) {
      canvas.drawOval(_oval(44, 142, 30, 3.2), shadow);
      canvas.drawOval(_oval(132, 142, 30, 3.2), shadow);
    } else {
      canvas.drawOval(_oval(76, 142, 21, 3), shadow);
      canvas.drawOval(_oval(127, 142, 21, 3), shadow);
    }

    // Phone.
    final RRect phone = RRect.fromLTRBR(
      194,
      10,
      286,
      142,
      const Radius.circular(16),
    );
    canvas.drawRRect(phone, _fill(_phone));
    canvas.drawRRect(phone, _stroke(_outline, 2.6));
    canvas.drawLine(
      const Offset(228, 20),
      const Offset(252, 20),
      _stroke(_outline, 2.6)..strokeCap = StrokeCap.round,
    );

    switch (scene) {
      case PermissionScene.explain:
        _paintGrid(canvas);
        _paintRoute(canvas, _blue, 1);
        canvas.drawOval(
          _oval(242, 66, 22, 6.5),
          _stroke(_pink.withValues(alpha: 0.5), 2),
        );
        canvas.drawOval(_oval(242, 66, 13, 4), _stroke(_pink, 2));
        _paintPin(canvas, _orange);
        canvas.drawCircle(const Offset(286, 22), 13, _fill(_blue));
        canvas.drawCircle(const Offset(286, 22), 13, _stroke(_badgeRing, 2.5));
      case PermissionScene.locationDenied:
        _paintGrid(canvas);
        _paintRoute(canvas, _muted, 0.7);
        _paintPin(canvas, _muted);
        canvas.drawLine(
          const Offset(222, 16),
          const Offset(264, 62),
          _stroke(_phone, 7)..strokeCap = StrokeCap.round,
        );
        canvas.drawLine(
          const Offset(222, 16),
          const Offset(264, 62),
          _stroke(_orange, 3.5)..strokeCap = StrokeCap.round,
        );
      case PermissionScene.servicesOff:
        canvas.drawRRect(
          RRect.fromLTRBR(216, 84, 268, 112, const Radius.circular(14)),
          _stroke(_muted, 2.5),
        );
        canvas.drawCircle(const Offset(230, 98), 9, _fill(_muted));
        final TextPainter off = TextPainter(
          text: TextSpan(
            text: AppStrings.permissionStatusOff.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _label,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        off.paint(canvas, Offset(242 - off.width / 2, 130 - off.height + 2));
        off.dispose();
    }

    // Cactus.
    final Paint cactus = _stroke(_cactus, 8)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawLine(const Offset(310, 134), const Offset(310, 108), cactus);
    canvas.drawPath(
      Path()
        ..moveTo(310, 122)
        ..lineTo(302, 122)
        ..lineTo(302, 114),
      cactus,
    );
    canvas.drawPath(
      Path()
        ..moveTo(310, 116)
        ..lineTo(318, 116)
        ..lineTo(318, 108),
      cactus,
    );
    canvas.restore();
  }

  void _paintGrid(Canvas canvas) {
    final Paint p = _stroke(_grid, 2);
    for (final double y in [58, 88, 116]) {
      canvas.drawLine(Offset(200, y), Offset(280, y), p);
    }
    for (final double x in [224, 256]) {
      canvas.drawLine(Offset(x, 28), Offset(x, 136), p);
    }
  }

  /// Dotted GPS route (kit: dash 1, gap 7, round caps).
  void _paintRoute(Canvas canvas, Color color, double opacity) {
    final Path route = Path()
      ..moveTo(178, 138)
      ..cubicTo(190, 138, 198, 132, 210, 124)
      ..cubicTo(236, 114, 218, 96, 236, 86)
      ..cubicTo(252, 78, 244, 70, 242, 64);
    final Paint dot = _fill(color.withValues(alpha: opacity));
    for (final ui.PathMetric m in route.computeMetrics()) {
      for (double d = 0; d < m.length; d += 8) {
        final ui.Tangent? t = m.getTangentForOffset(d);
        if (t != null) canvas.drawCircle(t.position, 1.75, dot);
      }
    }
  }

  void _paintPin(Canvas canvas, Color color) {
    final Path pin = Path()
      ..moveTo(242, 64)
      ..cubicTo(242, 64, 225, 49, 225, 36)
      ..arcTo(
        Rect.fromCircle(center: const Offset(242, 36), radius: 17),
        math.pi,
        math.pi,
        false,
      )
      ..cubicTo(259, 49, 242, 64, 242, 64)
      ..close();
    canvas.drawPath(pin, _fill(color));
    canvas.drawCircle(const Offset(242, 36), 6, _fill(_phone));
  }

  static Rect _oval(double cx, double cy, double rx, double ry) =>
      Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2);

  static Path _curve(Offset start, Offset control, List<Offset> ends) {
    final Path path = Path()..moveTo(start.dx, start.dy);
    Offset c = control;
    Offset previous = start;
    for (int i = 0; i < ends.length; i++) {
      if (i > 0) c = previous * 2 - c;
      path.quadraticBezierTo(c.dx, c.dy, ends[i].dx, ends[i].dy);
      previous = ends[i];
    }
    return path
      ..lineTo(328, 160)
      ..lineTo(0, 160)
      ..close();
  }

  static Paint _fill(Color c) => Paint()
    ..color = c
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  static Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..isAntiAlias = true;

  @override
  bool shouldRepaint(_ScenePainter old) => old.scene != scene;
}
