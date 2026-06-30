import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'floating_nav_bar.dart' show FloatingNavBar, kTabExplore;
import 'workout_mini_bar.dart';
import '../utility/responsive.dart';
import '../globals.dart';
import '../services/workout_session_service.dart';

class AppShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final VoidCallback _sessionListener;
  late final VoidCallback _colorListener;
  late final Timer _timer;
  bool _miniCollapsed = false;

  @override
  void initState() {
    super.initState();
    _sessionListener = () {
      if (mounted) setState(() {});
    };
    _colorListener = () {
      if (mounted) setState(() {});
    };
    workoutSessionService.addListener(_sessionListener);
    appColorNotifier.addListener(_colorListener);
    // tick every second so the elapsed time in the mini bar updates
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && workoutSessionService.isActive) setState(() {});
    });
  }

  @override
  void dispose() {
    workoutSessionService.removeListener(_sessionListener);
    appColorNotifier.removeListener(_colorListener);
    _timer.cancel();
    super.dispose();
  }

  String _elapsedLabel(WorkoutSession s) {
    final elapsed = s.elapsed;
    final h = elapsed.inHours;
    final m = elapsed.inMinutes % 60;
    final sec = elapsed.inSeconds % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = widget.navigationShell.currentIndex;
    final appColor = appColorNotifier.value;
    final session = workoutSessionService.session;
    final showMiniBar = session != null;

    final navBarBottomPad = Responsive.padding(context, 16);
    final navBarHeight = Responsive.scale(context, 72);
    final miniBarBottom =
        navBarBottomPad + navBarHeight + Responsive.height(context, 20);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Tab content
          widget.navigationShell,

          // Mini workout bar / collapsed dot, shown above nav bar while a session is active
          if (showMiniBar && selectedIndex != kTabExplore)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeInOutCubic,
              bottom: miniBarBottom,
              left: Responsive.padding(context, 40),
              right: _miniCollapsed ? null : Responsive.padding(context, 40),
              child: _miniCollapsed
                  ? CollapsedWorkoutDot(
                      appColor: appColor,
                      onTap: () => setState(() => _miniCollapsed = false),
                    )
                  : AnimatedSize(
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeInOutCubic,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: Responsive.scale(context, 320),
                        ),
                        child: MiniWorkoutBar(
                          session: session,
                          elapsedLabel: _elapsedLabel(session),
                          appColor: appColor,
                          onTap: () => context.push('/workout/active'),
                          onCollapse: () =>
                              setState(() => _miniCollapsed = true),
                        ),
                      ),
                    ),
            ),

          // Floating nav bar, hidden on Explore since it covers the map
          if (selectedIndex != kTabExplore)
            Positioned(
              bottom: navBarBottomPad,
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
