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
    return NavigationBar(
      height: 68,
      backgroundColor: palette.surface,
      indicatorColor: palette.iconTile,
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
          icon: const Icon(Icons.play_circle_outline_rounded),
          selectedIcon: const Icon(Icons.play_circle_fill_rounded),
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
    );
  }
}
