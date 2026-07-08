import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../globals.dart';
import '../utility/responsive.dart';
import '../models/workout_session.dart';

// Expanded mini bar shown above the nav bar while a workout is in progress
class MiniWorkoutBar extends StatefulWidget {
  final WorkoutSession session;
  final String
  elapsedLabel; // pre-formatted elapsed time string, updated every second by AppShell
  final Color appColor;
  final VoidCallback onTap; // navigates back to the full workout screen
  final VoidCallback onCollapse; // shrinks to CollapsedWorkoutDot

  const MiniWorkoutBar({
    super.key,
    required this.session,
    required this.elapsedLabel,
    required this.appColor,
    required this.onTap,
    required this.onCollapse,
  });

  @override
  State<MiniWorkoutBar> createState() => _MiniWorkoutBarState();
}

class _MiniWorkoutBarState extends State<MiniWorkoutBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    // slow heartbeat loop, drives both the scale pulse on the whole bar and opacity on the icon
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.75,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appColor = widget.appColor;
    final accent = lightenColor(appColor, 0.45);
    final dim = lightenColor(appColor, 0.35);
    final exerciseCount = widget.session.exercises.length;
    final isLight = appColor.computeLuminance() > 0.18;

    // subtle scale breath on the whole bar to signal an active session
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) => Transform.scale(
        scale: 0.97 + (_pulseAnim.value * 0.03),
        child: child,
      ),
      // whole bar is tappable to navigate to the active workout screen
      child: GestureDetector(
        onTap: widget.onTap,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: frostedGlassCard(
            context,
            color: appColor,
            baseRadius: 20,
            // lighter surface on light themes so the bar pops against the page
            backgroundColor: isLight
                ? Colors.white.withAlpha(65)
                : Colors.white.withAlpha(25),
            border: Border.all(
              color: isLight
                  ? Colors.white.withAlpha(90)
                  : Colors.white.withAlpha(50),
              width: Responsive.width(context, 1.5),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.padding(context, 14),
              vertical: Responsive.padding(context, 7),
            ),
            child: Row(
              children: [
                // dumbbell fades in opacity to signal an active session
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (context, _) => Opacity(
                    opacity: _pulseAnim.value,
                    child: Icon(
                      Icons.fitness_center_rounded,
                      color: accent,
                      size: Responsive.scale(context, 18),
                    ),
                  ),
                ),
                SizedBox(width: Responsive.width(context, 10)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        (widget.session.workoutName ??
                                    widget.session.routineName) !=
                                null
                            ? '${widget.session.workoutName ?? widget.session.routineName} in progress'
                            : 'Workout in progress',
                        style: TextStyle(
                          color: accent,
                          fontSize: Responsive.font(context, 13),
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '$exerciseCount exercise${exerciseCount == 1 ? '' : 's'}',
                        style: TextStyle(
                          color: dim,
                          fontSize: Responsive.font(context, 11),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  widget.elapsedLabel,
                  style: TextStyle(
                    color: accent,
                    fontSize: Responsive.font(context, 14),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: Responsive.width(context, 8)),
                // collapse button â€” tap target is large, visually separated from the rest
                GestureDetector(
                  onTap: widget.onCollapse,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.padding(context, 8),
                      vertical: Responsive.padding(context, 6),
                    ),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedMenuCollapse,
                      color: dim,
                      size: Responsive.scale(context, 22),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Circular collapsed state of the mini bar, anchored to the left above the nav bar
// tapping it expands back to MiniWorkoutBar
class CollapsedWorkoutDot extends StatefulWidget {
  final Color appColor;
  final VoidCallback onTap; // expands back to MiniWorkoutBar

  const CollapsedWorkoutDot({
    super.key,
    required this.appColor,
    required this.onTap,
  });

  @override
  State<CollapsedWorkoutDot> createState() => _CollapsedWorkoutDotState();
}

class _CollapsedWorkoutDotState extends State<CollapsedWorkoutDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    // wider scale range than the bar (0.88 to 1.0) so the dot reads as more alive
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.75,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appColor = widget.appColor;
    final accent = lightenColor(appColor, 0.45);
    final isLight = appColor.computeLuminance() > 0.18;
    final size = Responsive.scale(context, 48); // diameter of the circle

    // scale pulse, wider range than the bar so it reads clearly at small size
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) => Transform.scale(
        scale: 0.88 + (_pulseAnim.value * 0.12),
        child: child,
      ),
      child: GestureDetector(
        onTap: widget.onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: frostedGlassCard(
              context,
              color: appColor,
              baseRadius: size,
              backgroundColor: isLight
                  ? Colors.white.withAlpha(65)
                  : Colors.white.withAlpha(25),
              border: Border.all(
                color: isLight
                    ? Colors.white.withAlpha(90)
                    : Colors.white.withAlpha(50),
                width: Responsive.width(context, 1.5),
              ),
              padding: EdgeInsets.all(Responsive.scale(context, 12)),
              child: AnimatedBuilder(
                animation: _pulseAnim,
                builder: (context, _) => Opacity(
                  opacity: _pulseAnim.value,
                  child: Icon(
                    Icons.fitness_center_rounded,
                    color: accent,
                    size: Responsive.scale(context, 22),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
