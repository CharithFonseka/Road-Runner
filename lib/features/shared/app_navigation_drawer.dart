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

import '../../core/theme/app_colors.dart';
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
    return Drawer(
      width: AppNavigationDrawer.width,
      backgroundColor: AppColors.sandLight,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      semanticLabel: AppStrings.navMenuLabel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DrawerHeader(onClose: _close),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              children: [
                for (final AppDestination d in AppDestination.values) ...[
                  _DestinationTile(
                    key: AppNavigationDrawer.destinationKey(d),
                    destination: d,
                    selected: d == widget.selected,
                    onTap: () => _onDestination(d),
                  ),
                  const SizedBox(height: 4),
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Text(AppStrings.navRunNote, style: AppTextStyles.caption),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Header ─────────────────────────────────────────────────────────────────

/// Sky header: runner icon, name, tagline, close button and a slim desert
/// strip. Text on the sky uses [AppColors.canyonBrown] (5.56:1 or better;
/// the muted caption colour is too faint there).
class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.onClose});

  final VoidCallback onClose;

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
            padding: EdgeInsets.fromLTRB(20, topInset + 16, 8, 0),
            child: Row(
              children: [
                const ExcludeSemantics(
                  child: Icon(
                    Icons.directions_run_rounded,
                    size: 34,
                    color: AppColors.burntOrangeDeep,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: const Text(
                          AppStrings.appName,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            color: AppColors.canyonBrown,
                          ),
                        ),
                      ),
                      const Text(
                        AppStrings.navTagline,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                          color: AppColors.canyonBrown,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: AppNavigationDrawer.closeButtonKey,
                  onPressed: onClose,
                  tooltip: AppStrings.navCloseMenu,
                  color: AppColors.canyonBrown,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const ExcludeSemantics(
            child: SizedBox(
              height: 40,
              child: CustomPaint(painter: DrawerLandscapePainter()),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Destination ────────────────────────────────────────────────────────────

/// One 56dp stadium-shaped row.
///
/// Selected: [AppColors.iconTile] fill, bold [AppColors.canyonBrownDeep]
/// text (9.88:1) and a filled icon in [AppColors.burntOrangeDeep] (4.19:1,
/// icons need 3:1). The UI kit's orange label text on that fill is only
/// 4.19:1, so it is not used. Unselected: [AppColors.canyonBrown] on
/// [AppColors.sandLight]. Selection is also exposed to screen readers.
class _DestinationTile extends StatelessWidget {
  const _DestinationTile({
    super.key,
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final AppDestination destination;
  final bool selected;
  final VoidCallback onTap;

  static const double height = 56;

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
    final (String label, IconData filled, IconData outlined) = _content;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? AppColors.iconTile : Colors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: height),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    selected ? filled : outlined,
                    size: 24,
                    color: selected
                        ? AppColors.burntOrangeDeep
                        : AppColors.canyonBrown,
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
                            ? AppColors.canyonBrownDeep
                            : AppColors.canyonBrown,
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

/// The UI kit's slim (40dp) desert strip: sun, a small bird, mesa and dunes.
/// Drawn on a 360 × 40 grid and stretched to the available size, as in the
/// kit; the sun is drawn as a true circle.
class DrawerLandscapePainter extends CustomPainter {
  const DrawerLandscapePainter();

  static const double _w = 360;
  static const double _h = 40;

  static const Color _sun = Color(0xFFFFD762);
  static const Color _mesa = Color(0xFFC07358);
  static const Color _dunes = Color(0xFFFFCF91);

  @override
  void paint(Canvas canvas, Size size) {
    final double sx = size.width / _w;
    final double sy = size.height / _h;
    canvas.drawCircle(Offset(300 * sx, 14 * sy), 11 * sy, _fill(_sun));

    canvas.save();
    canvas.scale(sx, sy);
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
    canvas.drawPath(Path()..addPolygon(mesa, true), _fill(_mesa));
    canvas.drawPath(
      Path()
        ..moveTo(0, 32)
        ..quadraticBezierTo(90, 25, 180, 32)
        ..quadraticBezierTo(270, 39, 360, 31) // SVG "T": reflected control
        ..lineTo(360, 40)
        ..lineTo(0, 40)
        ..close(),
      _fill(_dunes),
    );
    canvas.restore();
  }

  static Paint _fill(Color color) => Paint()
    ..color = color
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  @override
  bool shouldRepaint(covariant DrawerLandscapePainter oldDelegate) => false;
}
