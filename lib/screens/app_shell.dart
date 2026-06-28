import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'floating_nav_bar.dart' show FloatingNavBar, kTabExplore;
import '../utility/responsive.dart';
import '../globals.dart';

class AppShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  Widget build(BuildContext context) {
    final selectedIndex = widget.navigationShell.currentIndex;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Tab content, each branch keeps its own navigator alive
          widget.navigationShell,
          // Floating nav bar, hidden on Explore since it covers the map
          if (selectedIndex != kTabExplore)
            Positioned(
              bottom: Responsive.padding(context, 16),
              left: Responsive.padding(context, 24),
              right: Responsive.padding(context, 24),
              child: FloatingNavBar(
                selectedIndex: selectedIndex,
                onTap: (index) {
                  if (onboardingHintNotifier.value != null) return;
                  widget.navigationShell.goBranch(
                    index,
                    initialLocation: index == selectedIndex,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
