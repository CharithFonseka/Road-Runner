import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';

enum MainDestination { home, routes, run, history, profile }

/// The five destinations a runner needs from the main areas of the app.
class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.selected,
    required this.onHome,
    required this.onRoutes,
    required this.onRun,
    required this.onHistory,
    required this.onProfile,
  });

  final MainDestination selected;
  final VoidCallback onHome;
  final VoidCallback onRoutes;
  final VoidCallback onRun;
  final VoidCallback onHistory;
  final VoidCallback onProfile;

  static Key destinationKey(MainDestination destination) =>
      Key('bottomNav.${destination.name}');

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.hairline)),
        boxShadow: [
          BoxShadow(
            color: palette.cardShadow.isEmpty
                ? Colors.transparent
                : palette.cardShadow.first.color.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: NavigationBarTheme(
        data: NavigationBarThemeData(
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              size: 23,
              color: states.contains(WidgetState.selected)
                  ? palette.accent
                  : palette.textSecondary,
            ),
          ),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 11,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: states.contains(WidgetState.selected)
                  ? palette.textPrimary
                  : palette.textSecondary,
            ),
          ),
        ),
        child: NavigationBar(
          height: 68,
          backgroundColor: palette.surface,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          indicatorColor: palette.iconTile,
          indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          animationDuration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 230),
          selectedIndex: selected.index,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (index) {
            final destination = MainDestination.values[index];
            if (destination == selected) return;
            switch (destination) {
              case MainDestination.home:
                onHome();
              case MainDestination.routes:
                onRoutes();
              case MainDestination.run:
                onRun();
              case MainDestination.history:
                onHistory();
              case MainDestination.profile:
                onProfile();
            }
          },
          destinations: [
            NavigationDestination(
              key: destinationKey(MainDestination.home),
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              key: destinationKey(MainDestination.routes),
              icon: const Icon(Icons.route_outlined),
              selectedIcon: const Icon(Icons.route_rounded),
              label: 'Routes',
            ),
            NavigationDestination(
              key: destinationKey(MainDestination.run),
              icon: _RunNavigationIcon(palette: palette),
              selectedIcon: _RunNavigationIcon(
                palette: palette,
                selected: true,
              ),
              label: 'Run',
            ),
            NavigationDestination(
              key: destinationKey(MainDestination.history),
              icon: const Icon(Icons.history_rounded),
              selectedIcon: const Icon(Icons.history_rounded),
              label: 'History',
            ),
            NavigationDestination(
              key: destinationKey(MainDestination.profile),
              icon: const Icon(Icons.person_outline_rounded),
              selectedIcon: const Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class _RunNavigationIcon extends StatelessWidget {
  const _RunNavigationIcon({required this.palette, this.selected = false});

  final AppPalette palette;
  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
    width: 32,
    height: 32,
    decoration: BoxDecoration(
      color: palette.primaryFill,
      borderRadius: BorderRadius.circular(11),
      border: selected ? Border.all(color: palette.surface, width: 2) : null,
    ),
    child: Icon(
      Icons.directions_run_rounded,
      size: 20,
      color: palette.onPrimaryFill,
    ),
  );
}
