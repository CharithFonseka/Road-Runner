// Road Runner — shared navigation drawer (Home, History, Settings).
// Owner: Tharushi
// SRS reference: Section 8.4, NFR-09, NFR-14
//
// The three main destinations only. Workflow screens (Active Run, Stop
// confirmation, Permissions requests, Summary) are reached from inside a
// flow and must NOT attach this drawer: a recording run must never be left
// through the menu.
//
// The parent owns its Scaffold and all navigation. Use it as:
//
//   Scaffold(
//     drawer: AppNavigationDrawer(
//       selected: AppDestination.home,
//       onOpenHome: ..., onOpenHistory: ..., onOpenSettings: ...,
//     ),
//     ...
//   )
//
// Tapping a destination closes the drawer, then calls that destination's
// callback once. Tapping the current destination only closes the drawer.

import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text_styles.dart';
import '../app_strings.dart';

/// The app's three main destinations.
enum AppDestination { home, history, settings }

/// Side drawer with Road Runner branding and the three main destinations.
class AppNavigationDrawer extends StatefulWidget {
  const AppNavigationDrawer({
    super.key,
    required this.selected,
    required this.onOpenHome,
    required this.onOpenHistory,
    required this.onOpenSettings,
  });

  /// The screen this drawer is attached to. Highlighted, and tapping it
  /// only closes the drawer.
  final AppDestination selected;

  final VoidCallback onOpenHome;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenSettings;

  /// Drawer width from the UI kit.
  static const double width = 300;

  static const Key closeButtonKey = Key('drawer.close');
  static Key destinationKey(AppDestination d) => Key('drawer.${d.name}');

  @override
  State<AppNavigationDrawer> createState() => _AppNavigationDrawerState();
}

class _AppNavigationDrawerState extends State<AppNavigationDrawer> {
  /// True once a destination callback has run. A drawer instance navigates
  /// at most once: a touch during the close animation can re-open it
  /// (Flutter settles a touched drawer), and its further taps must not
  /// navigate again. Closing is always allowed, so the drawer never gets
  /// stuck. A newly opened drawer is a fresh instance.
  bool _navigated = false;

  /// Closes the drawer through the parent's Scaffold. Never pops a route.
  void _close() {
    final ScaffoldState? scaffold = Scaffold.maybeOf(context);
    if (scaffold == null) return;
    if (scaffold.isDrawerOpen) {
      scaffold.closeDrawer();
    } else if (scaffold.isEndDrawerOpen) {
      scaffold.closeEndDrawer();
    }
  }

  void _onDestination(AppDestination destination) {
    _close();
    if (destination == widget.selected || _navigated) return;
    _navigated = true;
    switch (destination) {
      case AppDestination.home:
        widget.onOpenHome();
      case AppDestination.history:
        widget.onOpenHistory();
      case AppDestination.settings:
        widget.onOpenSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Drawer(
      width: AppNavigationDrawer.width,
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      semanticLabel: AppStrings.navMenuLabel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isShort = constraints.maxHeight < 480;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DrawerHeader(onClose: _close, isShort: isShort),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    isShort ? 4 : 12,
                    12,
                    isShort ? 4 : 12,
                  ),
                  children: [
                    for (final AppDestination d in AppDestination.values) ...[
                      _DestinationTile(
                        key: AppNavigationDrawer.destinationKey(d),
                        destination: d,
                        selected: d == widget.selected,
                        onTap: () => _onDestination(d),
                        isShort: isShort,
                      ),
                      SizedBox(height: isShort ? 2 : 4),
                    ],
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    isShort ? 4 : 8,
                    24,
                    isShort ? 8 : 24,
                  ),
                  child: Text(
                    AppStrings.navRunNote,
                    style: AppTextStyles.of(context).caption,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Header ─────────────────────────────────────────────────────────────────

/// Sky header: runner icon, name, tagline, close button and a slim desert
/// strip. Text and artwork use the active [AppPalette] for either sky.
class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.onClose, this.isShort = false});

  final VoidCallback onClose;
  final bool isShort;

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
              20,
              topInset + (isShort ? 8 : 16),
              8,
              0,
            ),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.directions_run_rounded,
                    size: isShort ? 28 : 34,
                    color: palette.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          AppStrings.appName,
                          style: AppTextStyles.of(context).heading.copyWith(
                            fontSize: isShort ? 20 : 22,
                            height: 1.2,
                          ),
                        ),
                      ),
                      Text(
                        AppStrings.navTagline,
                        style: AppTextStyles.of(context).body.copyWith(
                          fontSize: isShort ? 12 : 13,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: AppNavigationDrawer.closeButtonKey,
                  onPressed: onClose,
                  tooltip: AppStrings.navCloseMenu,
                  color: palette.textPrimary,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          SizedBox(height: isShort ? 4 : 10),
          ExcludeSemantics(
            child: SizedBox(
              height: isShort ? 24 : 40,
              child: CustomPaint(
                painter: DrawerLandscapePainter(palette: palette),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Destination ────────────────────────────────────────────────────────────

/// One 56dp (or 48dp on short screens) stadium-shaped row.
///
/// Selected and unselected states use the corresponding palette roles.
/// Selection is also exposed to screen readers.
class _DestinationTile extends StatelessWidget {
  const _DestinationTile({
    super.key,
    required this.destination,
    required this.selected,
    required this.onTap,
    this.isShort = false,
  });

  final AppDestination destination;
  final bool selected;
  final VoidCallback onTap;
  final bool isShort;

  static const double height = 56;
  static const double shortHeight = 48;

  (String, IconData, IconData) get _content {
    switch (destination) {
      case AppDestination.home:
        return (AppStrings.navHome, Icons.home_rounded, Icons.home_outlined);
      case AppDestination.history:
        return (
          AppStrings.navHistory,
          Icons.watch_later_rounded,
          Icons.schedule_rounded,
        );
      case AppDestination.settings:
        return (
          AppStrings.navSettings,
          Icons.settings_rounded,
          Icons.settings_outlined,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final (String label, IconData filled, IconData outlined) = _content;
    final double minH = isShort ? shortHeight : height;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? palette.iconTile : Colors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minH),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 18,
                vertical: isShort ? 4 : 8,
              ),
              child: Row(
                children: [
                  Icon(
                    selected ? filled : outlined,
                    size: 24,
                    color: selected ? palette.accent : palette.textPrimary,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.3,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: selected
                            ? palette.onIconTile
                            : palette.textPrimary,
                      ),
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

// ─── Artwork ────────────────────────────────────────────────────────────────

/// The UI kit's slim (40dp) desert strip on a 360 × 40 grid.
class DrawerLandscapePainter extends CustomPainter {
  const DrawerLandscapePainter({this.palette});

  final AppPalette? palette;

  static const double _w = 360;
  static const double _h = 40;

  @override
  void paint(Canvas canvas, Size size) {
    final AppPalette p = palette ?? AppPalette.light;
    final double sx = size.width / _w;
    final double sy = size.height / _h;
    if (p.isDark) {
      _paintNightSky(canvas, sx, sy, p);
    } else {
      canvas.drawCircle(Offset(300 * sx, 14 * sy), 11 * sy, _fill(p.celestial));
    }

    canvas.save();
    canvas.scale(sx, sy);
    if (!p.isDark) {
      canvas.drawPath(
        Path()
          ..moveTo(206, 12)
          ..relativeQuadraticBezierTo(6, -5, 12, 0)
          ..relativeQuadraticBezierTo(5, -4, 10, 0),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round,
      );
    }
    const List<Offset> mesa = [
      Offset(0, 20),
      Offset(30, 20),
      Offset(38, 24),
      Offset(44, 32),
      Offset(80, 34),
      Offset(130, 36),
      Offset(180, 33),
      Offset(230, 35),
      Offset(254, 28),
      Offset(266, 20),
      Offset(318, 20),
      Offset(326, 24),
      Offset(332, 20),
      Offset(360, 20),
      Offset(360, 40),
      Offset(0, 40),
    ];
    canvas.drawPath(Path()..addPolygon(mesa, true), _fill(p.mesa));
    canvas.drawPath(
      Path()
        ..moveTo(0, 32)
        ..quadraticBezierTo(90, 25, 180, 32)
        ..quadraticBezierTo(270, 39, 360, 31) // SVG "T": reflected control
        ..lineTo(360, 40)
        ..lineTo(0, 40)
        ..close(),
      _fill(p.dunes),
    );
    canvas.restore();
  }

  static Paint _fill(Color color) => Paint()
    ..color = color
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  void _paintNightSky(Canvas canvas, double sx, double sy, AppPalette p) {
    const List<(Offset, double, double)> stars = [
      (Offset(40, 8), 1, 0.7),
      (Offset(150, 6), 1.2, 0.8),
      (Offset(232, 10), 1, 0.6),
    ];
    for (final (Offset point, double radius, double opacity) in stars) {
      canvas.drawCircle(
        Offset(point.dx * sx, point.dy * sy),
        radius * sy,
        _fill(p.skyDecoration.withValues(alpha: opacity)),
      );
    }
    final Offset moon = Offset(300 * sx, 14 * sy);
    canvas.drawCircle(moon, 16 * sy, _fill(p.celestialGlow));
    canvas.drawCircle(moon, 10 * sy, _fill(p.celestial));
  }

  @override
  bool shouldRepaint(covariant DrawerLandscapePainter oldDelegate) =>
      palette != oldDelegate.palette;
}
