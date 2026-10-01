import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  final StatefulNavigationShell shell;
  const AppShell({super.key, required this.shell});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: shell,
    bottomNavigationBar: NavigationBar(
      selectedIndex: shell.currentIndex,
      // Tapping the active tab returns to that tab's root screen.
      onDestinationSelected: (i) =>
          shell.goBranch(i, initialLocation: i == shell.currentIndex),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
        NavigationDestination(
          icon: Icon(Icons.fitness_center),
          label: 'Training',
        ),
        NavigationDestination(icon: Icon(Icons.restaurant), label: 'Nutrition'),
        NavigationDestination(
          icon: Icon(Icons.refresh_rounded),
          label: 'Recovery',
        ),
      ],
    ),
  );
}
