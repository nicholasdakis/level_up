import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'floating_nav_bar.dart' show FloatingNavBar, kTabExplore;
import 'workout_mini_bar.dart';
import '../utility/responsive.dart';
import '../globals.dart';
import '../services/workout_session_service.dart';
import '/providers/user_data_provider.dart';
import '/services/user_data_manager.dart' show defaultAppColor;

class AppShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  Color get appColor => ref.watch(
    userDataProvider.select((s) => s.value?.appColor ?? defaultAppColor),
  );

  late final VoidCallback _sessionListener;
  late final Timer _timer;
  bool _miniCollapsed = false;

  @override
  void initState() {
    super.initState();
    _sessionListener = () {
      if (mounted) setState(() {});
    };
    workoutSessionService.addListener(_sessionListener);
    // tick every second so the elapsed time in the mini bar updates
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && workoutSessionService.isActive) setState(() {});
    });
  }

  @override
  void dispose() {
    workoutSessionService.removeListener(_sessionListener);
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
    final session = workoutSessionService.session;
    final showMiniBar = session != null;

    final navBarBottomPad = Responsive.padding(context, 16);
    final navBarHeight = Responsive.scale(context, 72);
    final systemBottomPad = MediaQuery.of(context).padding.bottom;
    final miniBarBottom =
        navBarBottomPad +
        navBarHeight +
        Responsive.height(context, 10) +
        systemBottomPad;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final navHPad = Responsive.centeredHorizontalPadding(context, 24);
    final navBarWidth = screenWidth - navHPad * 2;
    // cap the mini bar so it stays visibly shorter than the nav bar on all screen sizes
    final miniBarMaxWidth = Responsive.scale(context, 300);
    // left offset that centers the bar within the nav bar bounds
    final miniBarLeft =
        navHPad +
        ((navBarWidth - miniBarMaxWidth) / 2).clamp(0, double.infinity);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Tab content
          widget.navigationShell,

          // Floating nav bar, hidden on Explore since it covers the map
          if (selectedIndex != kTabExplore)
            Positioned(
              bottom: navBarBottomPad,
              left: Responsive.centeredHorizontalPadding(context, 24),
              right: Responsive.centeredHorizontalPadding(context, 24),
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

          // Mini workout bar / collapsed dot, shown above nav bar while a session is active
          if (showMiniBar && selectedIndex != kTabExplore)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeInOutCubic,
              bottom: miniBarBottom,
              left: miniBarLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: miniBarMaxWidth),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    Responsive.scale(context, 21),
                  ),
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeInOutCubic,
                    alignment: Alignment.centerLeft,
                    child: _miniCollapsed
                        ? CollapsedWorkoutDot(
                            appColor: appColor,
                            onTap: () => setState(() => _miniCollapsed = false),
                          )
                        : MiniWorkoutBar(
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
            ),
        ],
      ),
    );
  }
}
