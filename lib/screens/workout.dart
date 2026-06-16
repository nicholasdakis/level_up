import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:google_fonts/google_fonts.dart';
import '/globals.dart';
import '/utility/responsive.dart';

class Workout extends StatefulWidget {
  const Workout({super.key});

  @override
  State<Workout> createState() => _WorkoutState();
}

class _WorkoutState extends State<Workout> {
  late final VoidCallback _colorListener;

  @override
  void initState() {
    super.initState();
    FirebaseAnalytics.instance.logScreenView(
      screenName: '/workout',
      screenClass: 'Workout',
    );
    _colorListener = () {
      if (mounted) setState(() {});
    };
    appColorNotifier.addListener(_colorListener);
  }

  @override
  void dispose() {
    appColorNotifier.removeListener(_colorListener);
    super.dispose();
  }

  Widget _buildGoalCard(BuildContext context) {
    final accent = lightenColor(appColorNotifier.value, 0.45);
    final dim = lightenColor(appColorNotifier.value, 0.35);
    const int? weeklyGoal = null; // TODO: load from backend
    const int workoutsThisWeek = 0; // TODO: load from backend

    if (weeklyGoal == null) {
      return GestureDetector(
        onTap: () {
          // TODO: open set goal dialog
        },
        child: frostedGlassCard(
          context,
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.width(context, 20),
            vertical: Responsive.height(context, 16),
          ),
          child: Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedTarget01,
                color: dim,
                size: Responsive.scale(context, 24),
              ),
              SizedBox(width: Responsive.width(context, 14)),
              Expanded(
                child: Text(
                  "Set a weekly workout goal",
                  style: GoogleFonts.manrope(
                    color: dim,
                    fontSize: Responsive.font(context, 13),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                color: Colors.white24,
                size: Responsive.scale(context, 20),
              ),
            ],
          ),
        ),
      );
    }

    final fraction = (workoutsThisWeek / weeklyGoal).clamp(0.0, 1.0);
    return frostedGlassCard(
      context,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.width(context, 20),
        vertical: Responsive.height(context, 16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Weekly Goal",
                style: GoogleFonts.manrope(
                  color: accent,
                  fontSize: Responsive.font(context, 13),
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                "$workoutsThisWeek / $weeklyGoal workouts",
                style: GoogleFonts.manrope(
                  color: dim,
                  fontSize: Responsive.font(context, 12),
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.height(context, 10)),
          ClipRRect(
            borderRadius: BorderRadius.circular(Responsive.scale(context, 4)),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: Responsive.height(context, 6),
              backgroundColor: Colors.white.withAlpha(20),
              valueColor: AlwaysStoppedAnimation<Color>(
                lightenColor(appColorNotifier.value, 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onStartWorkout() {
    // TODO: open start workout modal
  }

  void _onCreateRoutine() {
    // TODO: open create routine screen
  }

  @override
  Widget build(BuildContext context) {
    final accent = lightenColor(appColorNotifier.value, 0.45);
    final dim = lightenColor(appColorNotifier.value, 0.35);

    return Container(
      decoration: BoxDecoration(gradient: buildThemeGradient()),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: ScrollConfiguration(
          behavior: NoGlowScrollBehavior(),
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.centeredHorizontalPadding(context, 20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height:
                        MediaQuery.paddingOf(context).top +
                        Responsive.height(context, 24),
                  ),
                  sectionHeader("WORKOUT", context),
                  SizedBox(height: Responsive.height(context, 16)),
                  // Weekly goal progress, prompts user to set a goal if none is set
                  _buildGoalCard(context),
                  SizedBox(height: Responsive.height(context, 20)),
                  sectionHeader("ACTIONS", context),
                  SizedBox(height: Responsive.height(context, 12)),
                  // Start Workout card
                  GestureDetector(
                    onTap: _onStartWorkout,
                    child: frostedGlassCard(
                      context,
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.width(context, 20),
                        vertical: Responsive.height(context, 20),
                      ),
                      child: Row(
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedDumbbell01,
                            color: accent,
                            size: Responsive.scale(context, 24),
                          ),
                          SizedBox(width: Responsive.width(context, 14)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Start Workout",
                                  style: GoogleFonts.manrope(
                                    color: accent,
                                    fontSize: Responsive.font(context, 14),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  "Start a new session or pick a routine",
                                  style: GoogleFonts.manrope(
                                    color: dim,
                                    fontSize: Responsive.font(context, 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedArrowRight01,
                            color: Colors.white24,
                            size: Responsive.scale(context, 20),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: Responsive.height(context, 12)),

                  // Create Routine card
                  GestureDetector(
                    onTap: _onCreateRoutine,
                    child: frostedGlassCard(
                      context,
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.width(context, 20),
                        vertical: Responsive.height(context, 20),
                      ),
                      child: Row(
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedAddSquare,
                            color: accent,
                            size: Responsive.scale(context, 24),
                          ),
                          SizedBox(width: Responsive.width(context, 14)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Create Routine",
                                  style: GoogleFonts.manrope(
                                    color: accent,
                                    fontSize: Responsive.font(context, 14),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  "Save a set of exercises to reuse later",
                                  style: GoogleFonts.manrope(
                                    color: dim,
                                    fontSize: Responsive.font(context, 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedArrowRight01,
                            color: Colors.white24,
                            size: Responsive.scale(context, 20),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: Responsive.height(context, 120)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
