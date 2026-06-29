import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart' hide ShimmerEffect;
import 'package:hugeicons/hugeicons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '/globals.dart';
import '/utility/responsive.dart';
import '/utility/unit_converter.dart';

class _WorkoutAnimationState {
  static bool animated = false;
}

class Workout extends StatefulWidget {
  const Workout({super.key});

  @override
  State<Workout> createState() => _WorkoutState();
}

class _WorkoutState extends State<Workout> {
  late final VoidCallback _colorListener;
  bool _loading = false;
  List<Map<String, dynamic>> _recentWorkouts = [];

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
    userDataNotifier.addListener(_colorListener);
    workoutLogNotifier.addListener(_onWorkoutLogged);
    if (!isGuest && currentUserData == null) {
      _loading = true;
      userManager.loadUserData().then((_) {
        if (mounted) setState(() => _loading = false);
      });
    }
    if (!isGuest) _fetchRecentWorkouts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _WorkoutAnimationState.animated = true;
    });
  }

  void _onWorkoutLogged() {
    if (!isGuest) _fetchRecentWorkouts();
  }

  Future<void> _fetchRecentWorkouts() async {
    final workouts = await userManager.fetchRecentWorkouts();
    if (mounted) setState(() => _recentWorkouts = workouts);
  }

  Widget _animate(Widget child, Duration delay) {
    if (_WorkoutAnimationState.animated) return child;
    return child
        .animate()
        .fadeIn(delay: delay, duration: 400.ms)
        .slideY(begin: 0.15, duration: 400.ms, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    appColorNotifier.removeListener(_colorListener);
    userDataNotifier.removeListener(_colorListener);
    workoutLogNotifier.removeListener(_onWorkoutLogged);
    super.dispose();
  }

  Widget _buildGoalCard(BuildContext context) {
    final accent = lightenColor(appColorNotifier.value, 0.45);
    final dim = lightenColor(appColorNotifier.value, 0.35);
    final int weeklyGoal = currentUserData?.weeklyWorkoutsGoal ?? 5;
    const int workoutsThisWeek =
        0; // TODO: load from backend once workout logging is implemented

    final fraction = (workoutsThisWeek / weeklyGoal).clamp(0.0, 1.0);
    return GestureDetector(
      onTap: () => _onSetWeeklyGoal(context),
      child: frostedGlassCard(
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
                Row(
                  children: [
                    Text(
                      "$workoutsThisWeek / $weeklyGoal workouts",
                      style: GoogleFonts.manrope(
                        color: dim,
                        fontSize: Responsive.font(context, 12),
                      ),
                    ),
                    SizedBox(width: Responsive.width(context, 8)),
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedPencilEdit01,
                      color: Colors.white24,
                      size: Responsive.scale(context, 14),
                    ),
                  ],
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
      ),
    );
  }

  Future<void> _onSetWeeklyGoal(BuildContext context) async {
    final current = currentUserData?.weeklyWorkoutsGoal;
    int selected = current ?? 3;

    final result = await showFrostedDialog<int>(
      context: context,
      child: StatefulBuilder(
        builder: (context, setDialogState) {
          final accent = lightenColor(appColorNotifier.value, 0.45);
          final dim = lightenColor(appColorNotifier.value, 0.35);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Weekly Workout Amount',
                style: GoogleFonts.manrope(
                  color: accent,
                  fontSize: Responsive.font(context, 16),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: Responsive.height(context, 6)),
              Text(
                'How many workouts are you planning to do per week?',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  color: dim,
                  fontSize: Responsive.font(context, 12),
                ),
              ),
              SizedBox(height: Responsive.height(context, 20)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: selected > 1
                        ? () => setDialogState(() => selected--)
                        : null,
                    icon: Icon(
                      Icons.remove_circle_outline,
                      color: selected > 1 ? accent : Colors.white24,
                    ),
                  ),
                  SizedBox(width: Responsive.width(context, 12)),
                  Text(
                    '$selected',
                    style: GoogleFonts.manrope(
                      color: accent,
                      fontSize: Responsive.font(context, 32),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: Responsive.width(context, 12)),
                  IconButton(
                    onPressed: selected < 7
                        ? () => setDialogState(() => selected++)
                        : null,
                    icon: Icon(
                      Icons.add_circle_outline,
                      color: selected < 7 ? accent : Colors.white24,
                    ),
                  ),
                ],
              ),
              SizedBox(height: Responsive.height(context, 4)),
              Text(
                'days per week',
                style: GoogleFonts.manrope(
                  color: dim,
                  fontSize: Responsive.font(context, 13),
                ),
              ),
              SizedBox(height: Responsive.height(context, 8)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context, rootNavigator: true).pop(null),
                    child: Text('Cancel', style: dialogButtonStyle()),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(
                      context,
                      rootNavigator: true,
                    ).pop(selected),
                    child: Text(
                      'Save',
                      style: dialogButtonStyle(confirm: true),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    if (result != null) {
      await userManager.updateGoals(
        weeklyWorkoutsGoal: result,
        context: context,
      );
      if (mounted) setState(() {});
    }
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  Widget _buildRecentWorkoutsCard(BuildContext context) {
    final accent = lightenColor(appColorNotifier.value, 0.45);
    final dim = lightenColor(appColorNotifier.value, 0.35);
    final recentWorkouts = _recentWorkouts;

    return frostedGlassCard(
      context,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.width(context, 16),
        vertical: Responsive.height(context, 16),
      ),
      child: recentWorkouts.isEmpty
          ? SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: Responsive.height(context, 8)),
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedClock01,
                    color: dim,
                    size: Responsive.scale(context, 32),
                  ),
                  SizedBox(height: Responsive.height(context, 10)),
                  Text(
                    'No workouts yet',
                    style: GoogleFonts.manrope(
                      color: accent,
                      fontSize: Responsive.font(context, 13),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: Responsive.height(context, 4)),
                  Text(
                    'Your completed sessions will appear here',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      color: dim,
                      fontSize: Responsive.font(context, 11),
                    ),
                  ),
                  SizedBox(height: Responsive.height(context, 8)),
                ],
              ),
            )
          : Column(
              children: [
                for (final w in recentWorkouts)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: Responsive.height(context, 6),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                w['name'] as String? ?? 'Workout',
                                style: GoogleFonts.manrope(
                                  color: accent,
                                  fontSize: Responsive.font(context, 13),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                w['date'] as String? ?? '',
                                style: GoogleFonts.manrope(
                                  color: dim,
                                  fontSize: Responsive.font(context, 11),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _formatDuration(w['duration_seconds'] as int? ?? 0),
                          style: GoogleFonts.manrope(
                            color: dim,
                            fontSize: Responsive.font(context, 11),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  void _onStartWorkout() {
    context.push('/workout/active');
  }

  void _onNewRoutine() {
    // TODO: open create routine screen
  }

  void _onExploreRoutines() {
    // TODO: open explore routines screen
  }

  Widget _buildStartWorkoutCard(BuildContext context) {
    final accent = lightenColor(appColorNotifier.value, 0.45);
    final dim = lightenColor(appColorNotifier.value, 0.35);
    return GestureDetector(
      onTap: _onStartWorkout,
      child: frostedGlassCard(
        context,
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.width(context, 20),
          vertical: Responsive.height(context, 22),
        ),
        child: Row(
          children: [
            Container(
              width: Responsive.scale(context, 44),
              height: Responsive.scale(context, 44),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(18),
                borderRadius: BorderRadius.circular(
                  Responsive.scale(context, 12),
                ),
                border: Border.all(color: Colors.white.withAlpha(30)),
              ),
              child: Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedDumbbell01,
                  color: accent,
                  size: Responsive.scale(context, 24),
                ),
              ),
            ),
            SizedBox(width: Responsive.width(context, 16)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Start Workout",
                    style: GoogleFonts.manrope(
                      color: accent,
                      fontSize: Responsive.font(context, 15),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    "Begin an empty session",
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
              color: dim,
              size: Responsive.scale(context, 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutineActionCards(BuildContext context) {
    final accent = lightenColor(appColorNotifier.value, 0.45);
    final dim = lightenColor(appColorNotifier.value, 0.35);

    Widget card(
      IconData icon,
      String label,
      String subtitle,
      VoidCallback onTap,
    ) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: frostedGlassCard(
            context,
            padding: EdgeInsets.symmetric(
              vertical: Responsive.height(context, 20),
              horizontal: Responsive.width(context, 8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                HugeIcon(
                  icon: icon,
                  color: accent,
                  size: Responsive.scale(context, 26),
                ),
                SizedBox(height: Responsive.height(context, 8)),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    color: accent,
                    fontSize: Responsive.font(context, 12),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: Responsive.height(context, 2)),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    color: dim,
                    fontSize: Responsive.font(context, 10),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        card(
          HugeIcons.strokeRoundedAddSquare,
          "New Routine",
          "Build your own",
          _onNewRoutine,
        ),
        SizedBox(width: Responsive.width(context, 12)),
        card(
          HugeIcons.strokeRoundedCompass,
          "Explore Routines",
          "Find & follow plans",
          _onExploreRoutines,
        ),
      ],
    );
  }

  Widget _buildMyRoutinesCard(BuildContext context) {
    final accent = lightenColor(appColorNotifier.value, 0.45);
    final dim = lightenColor(appColorNotifier.value, 0.35);
    // TODO: replace with real routines list
    const List<Map<String, dynamic>> routines = [];

    return frostedGlassCard(
      context,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.width(context, 16),
        vertical: Responsive.height(context, 16),
      ),
      child: routines.isEmpty
          ? SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: Responsive.height(context, 8)),
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedFileNotFound,
                    color: dim,
                    size: Responsive.scale(context, 32),
                  ),
                  SizedBox(height: Responsive.height(context, 10)),
                  Text(
                    "No routines yet",
                    style: GoogleFonts.manrope(
                      color: accent,
                      fontSize: Responsive.font(context, 13),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: Responsive.height(context, 4)),
                  Text(
                    "Create your first routine to stay on track",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      color: dim,
                      fontSize: Responsive.font(context, 11),
                    ),
                  ),
                  SizedBox(height: Responsive.height(context, 8)),
                ],
              ),
            )
          : Column(
              children: [
                for (final r in routines)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: Responsive.height(context, 6),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            r['name'] as String,
                            style: GoogleFonts.manrope(
                              color: accent,
                              fontSize: Responsive.font(context, 13),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          "${r['exercise_count']} exercises",
                          style: GoogleFonts.manrope(
                            color: dim,
                            fontSize: Responsive.font(context, 11),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildLiftsCard(BuildContext context) {
    final accent = lightenColor(appColorNotifier.value, 0.45);
    final dim = lightenColor(appColorNotifier.value, 0.35);
    // TODO: load from backend
    const double volumeTodayKg = 0;
    final bool isImperial = UnitConverter.isImperial;
    final String volumeDisplay = isImperial
        ? "${UnitConverter.displayWeight(volumeTodayKg, imperial: true)} lbs"
        : "${volumeTodayKg.toStringAsFixed(0)} kg";
    final List<String> musclesWorked = []; // TODO: load from backend

    Widget actionButton(IconData icon, VoidCallback? onTap) => GestureDetector(
      onTap: onTap,
      child: Container(
        width: Responsive.scale(context, 42),
        height: Responsive.scale(context, 42),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withAlpha(18),
          border: Border.all(color: Colors.white.withAlpha(40), width: 1),
        ),
        child: Icon(
          HugeIcons.strokeRoundedAnalyticsUp,
          color: accent,
          size: Responsive.scale(context, 20),
        ),
      ),
    );

    return frostedGlassCard(
      context,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.width(context, 16),
        vertical: Responsive.height(context, 14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedWeightScale,
                      color: accent,
                      size: Responsive.scale(context, 14),
                    ),
                    SizedBox(width: Responsive.width(context, 5)),
                    Text(
                      "Lifts",
                      style: GoogleFonts.manrope(
                        color: accent,
                        fontSize: Responsive.font(context, 11),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: Responsive.height(context, 6)),
                Text(
                  volumeDisplay,
                  style: GoogleFonts.manrope(
                    color: accent,
                    fontSize: Responsive.font(context, 22),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  "volume today",
                  style: GoogleFonts.manrope(
                    color: dim,
                    fontSize: Responsive.font(context, 11),
                  ),
                ),
                if (musclesWorked.isNotEmpty) ...[
                  SizedBox(height: Responsive.height(context, 8)),
                  Wrap(
                    spacing: Responsive.width(context, 6),
                    runSpacing: Responsive.height(context, 4),
                    children: [
                      for (final muscle in musclesWorked)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: Responsive.width(context, 8),
                            vertical: Responsive.height(context, 3),
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(18),
                            borderRadius: BorderRadius.circular(
                              Responsive.scale(context, 20),
                            ),
                            border: Border.all(
                              color: Colors.white.withAlpha(30),
                            ),
                          ),
                          child: Text(
                            muscle,
                            style: GoogleFonts.manrope(
                              color: accent,
                              fontSize: Responsive.font(context, 10),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actionButton(
            HugeIcons.strokeRoundedAnalyticsUp,
            null,
          ), // TODO: analytics
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: buildThemeGradient()),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Skeletonizer(
          enabled: _loading,
          effect: ShimmerEffect(
            baseColor: lightenColor(appColorNotifier.value, 0.3),
            highlightColor: lightenColor(appColorNotifier.value, 0.1),
            duration: const Duration(milliseconds: 1200),
          ),
          child: ScrollConfiguration(
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
                    _animate(_buildGoalCard(context), 0.ms),
                    SizedBox(height: Responsive.height(context, 20)),
                    sectionHeader("START", context),
                    _animate(_buildStartWorkoutCard(context), 60.ms),
                    SizedBox(height: Responsive.height(context, 12)),
                    _animate(_buildRoutineActionCards(context), 120.ms),
                    SizedBox(height: Responsive.height(context, 20)),
                    sectionHeader("MY ROUTINES", context),
                    _animate(_buildMyRoutinesCard(context), 180.ms),
                    SizedBox(height: Responsive.height(context, 20)),
                    sectionHeader("RECENT WORKOUTS", context),
                    _animate(_buildRecentWorkoutsCard(context), 240.ms),
                    SizedBox(height: Responsive.height(context, 20)),
                    sectionHeader("LOGGING", context),
                    _animate(_buildLiftsCard(context), 300.ms),
                    SizedBox(height: Responsive.height(context, 120)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
