import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart' hide ShimmerEffect;
import 'package:hugeicons/hugeicons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '/globals.dart';
import '/guest.dart';
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
  List<Map<String, dynamic>> _myRoutines = [];
  int _weeklyWorkoutCount = 0;
  Map<String, int> _heatmap = {};
  OverlayEntry? _heatmapTooltip;
  Map<String, dynamic> _todayOverview = {
    'volume_kg': 0.0,
    'exercises': 0,
    'sets': 0,
    'reps': 0,
    'duration_seconds': 0,
    'primary_muscles': [],
    'secondary_muscles': [],
  };

  late final VoidCallback _sessionListener;

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

    _sessionListener = () {
      if (mounted) setState(() {});
    };
    workoutSessionService.addListener(_sessionListener);

    appColorNotifier.addListener(_colorListener);
    userDataNotifier.addListener(_colorListener);
    workoutLogNotifier.addListener(_onWorkoutLogged);
    if (!isGuest && currentUserData == null) {
      _loading = true;
      userManager.loadUserData().then((_) {
        if (mounted) setState(() => _loading = false);
      });
    }
    if (!isGuest) _fetchData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _WorkoutAnimationState.animated = true;
    });
  }

  void _dismissHeatmapTooltip() {
    _heatmapTooltip?.remove();
    _heatmapTooltip = null;
  }

  void _showCellTooltip(
    BuildContext cellContext,
    String title, {
    String? subtitle,
  }) {
    _dismissHeatmapTooltip();
    final box = cellContext.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);
    final accent = lightenColor(appColorNotifier.value, 0.45);
    final dim = lightenColor(appColorNotifier.value, 0.35);
    _heatmapTooltip = OverlayEntry(
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _dismissHeatmapTooltip,
        child: Stack(
          children: [
            Positioned(
              left: (offset.dx - 40).clamp(
                8.0,
                MediaQuery.of(context).size.width - 130,
              ),
              top: offset.dy - 52,
              child: Material(
                color: Colors.transparent,
                child: frostedGlassCard(
                  context,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.manrope(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: GoogleFonts.manrope(color: dim, fontSize: 10),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    Overlay.of(cellContext).insert(_heatmapTooltip!);
  }

  void _showHeatmapTooltip(
    BuildContext cellContext,
    String dateStr,
    int count,
  ) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final parts = dateStr.split('-');
    final dt = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    final dateLabel = '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    final countLabel = count == 0
        ? 'No workouts'
        : count == 1
        ? '1 workout'
        : '$count workouts';
    _showCellTooltip(cellContext, dateLabel, subtitle: countLabel);
  }

  void _onWorkoutLogged() {
    if (!isGuest) _fetchData();
  }

  Future<void> _fetchData() async {
    final results = await Future.wait([
      userManager.fetchRecentWorkouts(),
      userManager.fetchWeeklyWorkoutCount(),
      userManager.fetchTodayOverview(),
      userManager.fetchWorkoutHeatmap(),
      userManager.fetchMyRoutines(),
    ]);
    if (mounted) {
      setState(() {
        _recentWorkouts = results[0] as List<Map<String, dynamic>>;
        _weeklyWorkoutCount = results[1] as int;
        _todayOverview = results[2] as Map<String, dynamic>;
        _heatmap = results[3] as Map<String, int>;
        _myRoutines = results[4] as List<Map<String, dynamic>>;
      });
    }
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
    workoutSessionService.removeListener(_sessionListener);
    super.dispose();
  }

  Widget _buildGoalCard(BuildContext context) {
    final accent = lightenColor(appColorNotifier.value, 0.45);
    final dim = lightenColor(appColorNotifier.value, 0.35);
    final int weeklyGoal = currentUserData?.weeklyWorkoutsGoal ?? 5;
    final int workoutsThisWeek = _weeklyWorkoutCount;

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
            SizedBox(height: Responsive.height(context, 6)),
            Text(
              'Resets every Monday',
              style: GoogleFonts.manrope(
                color: Colors.white.withAlpha(50),
                fontSize: Responsive.font(context, 10),
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
          : ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.30,
              ),
              child: ScrollConfiguration(
                behavior: NoGlowScrollBehavior(),
                child: SingleChildScrollView(
                  child: Column(
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
                                _formatDuration(
                                  w['duration_seconds'] as int? ?? 0,
                                ),
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
                ),
              ),
            ),
    );
  }

  Future<void> _deleteRoutine(
    BuildContext context,
    Map<String, dynamic> routine,
  ) async {
    final accent = lightenColor(appColorNotifier.value, 0.45);
    final dim = lightenColor(appColorNotifier.value, 0.35);
    final confirmed = await showFrostedAlertDialog<bool>(
      context: context,
      title: 'Delete Routine',
      content: Text(
        'Remove "${routine['name']}" from your routines?',
        textAlign: TextAlign.center,
        style: GoogleFonts.manrope(
          color: dim,
          fontSize: Responsive.font(context, 13),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(false),
          child: Text('Cancel', style: GoogleFonts.manrope(color: dim)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
          child: Text(
            'Delete',
            style: GoogleFonts.manrope(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
    if (confirmed != true) return;
    final ok = await userManager.deleteRoutine(
      templateId: routine['template_id'] as String,
    );
    if (!mounted) return;
    if (ok) {
      setState(
        () => _myRoutines.removeWhere(
          (r) => r['template_id'] == routine['template_id'],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to delete routine.',
            style: GoogleFonts.manrope(),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showNoRoutinesDialog(BuildContext context, Color accent, Color dim) {
    showFrostedDialog(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Get started',
            style: GoogleFonts.manrope(
              color: accent,
              fontSize: Responsive.font(context, 18),
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: Responsive.height(context, 16)),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Navigator.of(context, rootNavigator: true).pop();
              _onNewRoutine();
            },
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: Responsive.height(context, 12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.add_circle_outline_rounded,
                    color: accent,
                    size: Responsive.scale(context, 20),
                  ),
                  SizedBox(width: Responsive.width(context, 12)),
                  Text(
                    'Create my own',
                    style: GoogleFonts.manrope(
                      color: accent,
                      fontSize: Responsive.font(context, 14),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(color: Colors.white.withAlpha(12), height: 1),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Navigator.of(context, rootNavigator: true).pop();
              _onExploreRoutines();
            },
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: Responsive.height(context, 12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.explore_outlined,
                    color: accent,
                    size: Responsive.scale(context, 20),
                  ),
                  SizedBox(width: Responsive.width(context, 12)),
                  Text(
                    'Browse routines',
                    style: GoogleFonts.manrope(
                      color: accent,
                      fontSize: Responsive.font(context, 14),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
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
    context.push('/workout/create_routine');
  }

  void _onExploreRoutines() {
    context.push('/workout/browse_routines');
  }

  Widget _buildStartWorkoutCard(BuildContext context) {
    final accent = lightenColor(appColorNotifier.value, 0.45);
    final dim = lightenColor(appColorNotifier.value, 0.35);
    final bool inProgress = workoutSessionService.isActive;

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
                  icon: inProgress
                      ? HugeIcons.strokeRoundedPlay
                      : HugeIcons.strokeRoundedDumbbell01,
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
                    inProgress ? "Continue Workout" : "Start Workout",
                    style: GoogleFonts.manrope(
                      color: accent,
                      fontSize: Responsive.font(context, 15),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    inProgress
                        ? (workoutSessionService.session!.workoutName ??
                              workoutSessionService.session!.routineName ??
                              "Resume your session")
                        : "Begin an empty session",
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
    final List<Map<String, dynamic>> routines = _myRoutines;

    return frostedGlassCard(
      context,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.width(context, 16),
        vertical: Responsive.height(context, 16),
      ),
      child: routines.isEmpty
          ? GestureDetector(
              onTap: () => _showNoRoutinesDialog(context, accent, dim),
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
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
                      "Tap to get started",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        color: dim,
                        fontSize: Responsive.font(context, 11),
                      ),
                    ),
                    SizedBox(height: Responsive.height(context, 8)),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                for (int i = 0; i < routines.length; i++) ...[
                  if (i > 0)
                    Divider(color: Colors.white.withAlpha(12), height: 1),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: Responsive.height(context, 10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                routines[i]['name'] as String,
                                style: GoogleFonts.manrope(
                                  color: accent,
                                  fontSize: Responsive.font(context, 13),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                "${routines[i]['exercise_count']} exercises",
                                style: GoogleFonts.manrope(
                                  color: dim,
                                  fontSize: Responsive.font(context, 11),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Delete icon in My Routines
                        GestureDetector(
                          onTap: () => _deleteRoutine(context, routines[i]),
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedDelete02,
                            color: dim,
                            size: Responsive.scale(context, 18),
                          ),
                        ),
                        SizedBox(width: Responsive.width(context, 10)),

                        // Start icon in My Routines
                        GestureDetector(
                          onTap: () {
                            if (workoutSessionService.isActive) {
                              showFrostedAlertDialog<void>(
                                context: context,
                                title: 'Workout in progress',
                                content: Text(
                                  'Finish or discard your current workout before starting a new one.',
                                  style: GoogleFonts.manrope(
                                    color: Colors.white70,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(
                                      context,
                                      rootNavigator: true,
                                    ).pop(),
                                    child: Text(
                                      'OK',
                                      style: dialogButtonStyle(confirm: true),
                                    ),
                                  ),
                                ],
                              );
                              return;
                            }
                            context.push('/workout/active', extra: routines[i]);
                          },
                          child: Icon(
                            Icons.play_circle_outline_rounded,
                            color: workoutSessionService.isActive
                                ? dim.withAlpha(100)
                                : accent,
                            size: Responsive.scale(context, 22),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildLiftsCard(BuildContext context) {
    final c = cardColors(appColorNotifier.value);
    final accent = c.onCard;
    final dim = c.onCard.withAlpha(180);
    final subtle = c.onCard.withAlpha(120);
    final bool isImperial = UnitConverter.isImperial;
    final double volumeKg = (_todayOverview['volume_kg'] as num).toDouble();
    final int exercises = _todayOverview['exercises'] as int? ?? 0;
    final int sets = _todayOverview['sets'] as int? ?? 0;
    final int reps = _todayOverview['reps'] as int? ?? 0;
    final int durationSec = _todayOverview['duration_seconds'] as int? ?? 0;
    final List<String> primaryMuscles = List<String>.from(
      _todayOverview['primary_muscles'] as List? ?? [],
    );
    final List<String> secondaryMuscles = List<String>.from(
      _todayOverview['secondary_muscles'] as List? ?? [],
    );
    final String volumeUnit = isImperial ? 'lbs' : 'kg';
    String formatVolume(double kg) {
      final double val = isImperial
          ? double.parse(UnitConverter.displayWeight(kg, imperial: true))
          : kg;
      if (val >= 1000) return '${(val / 1000).toStringAsFixed(1)}k';
      return val.toStringAsFixed(0);
    }

    final String volumeDisplay = formatVolume(volumeKg);
    final String durationDisplay = durationSec == 0
        ? '0m'
        : durationSec < 3600
        ? '${durationSec ~/ 60}m'
        : '${durationSec ~/ 3600}h ${(durationSec % 3600) ~/ 60}m';

    Widget stat(String value, String label) => Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.manrope(
              color: accent,
              fontSize: Responsive.font(context, 18),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: Responsive.height(context, 2)),
          Text(
            label,
            style: GoogleFonts.manrope(
              color: dim,
              fontSize: Responsive.font(context, 10),
            ),
          ),
        ],
      ),
    );

    return frostedGlassCard(
      context,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.width(context, 16),
        vertical: Responsive.height(context, 16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    volumeDisplay,
                    style: GoogleFonts.manrope(
                      color: accent,
                      fontSize: Responsive.font(context, 26),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'volume ($volumeUnit)',
                    style: GoogleFonts.manrope(
                      color: dim,
                      fontSize: Responsive.font(context, 11),
                    ),
                  ),
                ],
              ),
              SizedBox(width: Responsive.width(context, 32)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    durationDisplay,
                    style: GoogleFonts.manrope(
                      color: accent,
                      fontSize: Responsive.font(context, 26),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'duration',
                    style: GoogleFonts.manrope(
                      color: dim,
                      fontSize: Responsive.font(context, 11),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: Responsive.height(context, 14)),
          Divider(
            color: c.onCard.withAlpha(30),
            height: Responsive.height(context, 1),
            thickness: Responsive.height(context, 1.5),
          ),
          SizedBox(height: Responsive.height(context, 14)),
          Row(
            children: [
              stat('$exercises', 'exercises'),
              stat('$sets', 'sets'),
              stat('$reps', 'reps'),
            ],
          ),
          if (primaryMuscles.isNotEmpty || secondaryMuscles.isNotEmpty) ...[
            SizedBox(height: Responsive.height(context, 12)),
            Divider(
              color: c.onCard.withAlpha(30),
              height: Responsive.height(context, 1),
              thickness: Responsive.height(context, 1.5),
            ),
            SizedBox(height: Responsive.height(context, 12)),
            for (final entry in [
              if (primaryMuscles.isNotEmpty)
                ('PRIMARY MUSCLES WORKED', primaryMuscles),
              if (secondaryMuscles.isNotEmpty)
                ('SECONDARY MUSCLES WORKED', secondaryMuscles),
            ]) ...[
              SizedBox(
                width: double.infinity,
                child: Text(
                  entry.$1,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    color: subtle,
                    fontSize: Responsive.font(context, 10),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              SizedBox(height: Responsive.height(context, 6)),
              Center(
                child: Wrap(
                  spacing: Responsive.width(context, 6),
                  runSpacing: Responsive.height(context, 4),
                  children: [
                    for (final muscle in entry.$2)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.width(context, 8),
                          vertical: Responsive.height(context, 3),
                        ),
                        decoration: BoxDecoration(
                          color: c.onCard.withAlpha(45),
                          borderRadius: BorderRadius.circular(
                            Responsive.scale(context, 20),
                          ),
                          border: Border.all(color: c.onCard.withAlpha(40)),
                        ),
                        child: Text(
                          muscle.isEmpty
                              ? muscle
                              : '${muscle[0].toUpperCase()}${muscle.substring(1)}',
                          style: GoogleFonts.manrope(
                            color: accent,
                            fontSize: Responsive.font(context, 10),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: Responsive.height(context, 8)),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildHeatmapCard(BuildContext context) {
    final c = cardColors(appColorNotifier.value);
    final accent = c.onCard;
    const int weeks = 16;
    const int daysPerWeek = 7;
    final today = DateTime.now();
    final startDate = today.subtract(
      Duration(days: today.weekday - 1 + (weeks - 1) * 7),
    );

    const double cellGap = 4;
    const double dayLabelWidth = 16;
    const List<String> dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    const List<String> monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    Color cellColor(int count, bool isFuture) {
      if (isFuture || count == 0) return c.onCard.withAlpha(45);
      if (count == 1) return accent.withAlpha(80);
      if (count == 2) return accent.withAlpha(150);
      return accent.withAlpha(230);
    }

    return frostedGlassCard(
      context,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.width(context, 16),
        vertical: Responsive.height(context, 16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double gridWidth =
              constraints.maxWidth - dayLabelWidth - cellGap;
          final double cellSize = (gridWidth - cellGap * (weeks - 1)) / weeks;

          Widget legendCell(int alpha, String label) => Builder(
            builder: (cellContext) => MouseRegion(
              onEnter: (_) => _showCellTooltip(cellContext, label),
              onExit: (_) => _dismissHeatmapTooltip(),
              child: GestureDetector(
                onTap: () => _showCellTooltip(cellContext, label),
                child: Container(
                  width: Responsive.scale(context, 12),
                  height: Responsive.scale(context, 12),
                  decoration: BoxDecoration(
                    color: alpha == 0
                        ? c.onCard.withAlpha(45)
                        : accent.withAlpha(alpha),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          );

          // build month labels, show month name at the first week of each new month
          final List<Widget> monthLabels = [];
          for (int w = 0; w < weeks; w++) {
            final date = startDate.add(Duration(days: w * 7));
            final isFirstWeekOfMonth = date.day <= 7;
            monthLabels.add(
              SizedBox(
                width: cellSize + (w < weeks - 1 ? cellGap : 0),
                child: isFirstWeekOfMonth
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          monthNames[date.month - 1],
                          softWrap: false,
                          overflow: TextOverflow.visible,
                          style: GoogleFonts.manrope(
                            color: Colors.white,
                            fontSize: Responsive.font(context, 10),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    : null,
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // month labels row
              Row(
                children: [
                  SizedBox(width: dayLabelWidth + cellGap),
                  ...monthLabels,
                ],
              ),
              SizedBox(height: 2),
              // grid
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // day labels
                  Column(
                    children: [
                      for (int d = 0; d < daysPerWeek; d++)
                        SizedBox(
                          height: cellSize + cellGap,
                          width: dayLabelWidth,
                          child: Text(
                            dayLabels[d],
                            style: GoogleFonts.manrope(
                              color: Colors.white,
                              fontSize: Responsive.font(context, 10),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(width: cellGap),
                  // week columns
                  for (int w = 0; w < weeks; w++)
                    Padding(
                      padding: EdgeInsets.only(
                        right: w < weeks - 1 ? cellGap : 0,
                      ),
                      child: Column(
                        children: [
                          for (int d = 0; d < daysPerWeek; d++)
                            Builder(
                              builder: (context) {
                                final date = startDate.add(
                                  Duration(days: w * 7 + d),
                                );
                                final dateStr =
                                    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                                final count = _heatmap[dateStr] ?? 0;
                                final isFuture = date.isAfter(today);
                                return Padding(
                                  padding: EdgeInsets.only(
                                    bottom: d < daysPerWeek - 1 ? cellGap : 0,
                                  ),
                                  child: MouseRegion(
                                    onEnter: (_) => _showHeatmapTooltip(
                                      context,
                                      dateStr,
                                      count,
                                    ),
                                    onExit: (_) => _dismissHeatmapTooltip(),
                                    child: GestureDetector(
                                      onTap: () => _showHeatmapTooltip(
                                        context,
                                        dateStr,
                                        count,
                                      ),
                                      child: Container(
                                        width: cellSize,
                                        height: cellSize,
                                        decoration: BoxDecoration(
                                          color: cellColor(count, isFuture),
                                          borderRadius: BorderRadius.circular(
                                            2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                ],
              ),
              SizedBox(height: Responsive.height(context, 8)),
              Row(
                children: [
                  SizedBox(width: dayLabelWidth + cellGap),
                  Text(
                    'Less',
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontSize: Responsive.font(context, 10),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(width: cellGap * 2),
                  legendCell(0, '0 workouts'),
                  SizedBox(width: cellGap),
                  legendCell(80, '1 workout'),
                  SizedBox(width: cellGap),
                  legendCell(150, '2 workouts'),
                  SizedBox(width: cellGap),
                  legendCell(230, '3+ workouts'),
                  SizedBox(width: cellGap * 2),
                  Text(
                    'More',
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontSize: Responsive.font(context, 10),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: buildThemeGradient()),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            if (isGuest)
              _buildWorkoutContent(context)
            else ...[
              Skeletonizer(
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
                        horizontal: Responsive.centeredHorizontalPadding(
                          context,
                          20,
                        ),
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
                          sectionHeader("TODAY'S OVERVIEW", context),
                          _animate(_buildLiftsCard(context), 240.ms),
                          SizedBox(height: Responsive.height(context, 20)),
                          sectionHeader("ACTIVITY HEATMAP", context),
                          _animate(_buildHeatmapCard(context), 300.ms),
                          SizedBox(height: Responsive.height(context, 20)),
                          sectionHeader("RECENT WORKOUTS", context),
                          _animate(_buildRecentWorkoutsCard(context), 360.ms),
                          SizedBox(height: Responsive.height(context, 120)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              OnboardingHint(
                hintKey: 'workout',
                title: 'Start your first workout',
                description:
                    'Tap Start Workout to begin, or browse routines to follow a plan',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _guestLock(BuildContext context, Widget child) {
    if (!isGuest) return child;
    final accent = lightenColor(appColorNotifier.value, 0.45);
    return GestureDetector(
      onTap: Guest.exit,
      child: Stack(
        children: [
          IgnorePointer(child: Opacity(opacity: 0.35, child: child)),
          Positioned.fill(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedLockPassword,
                    color: accent,
                    size: Responsive.scale(context, 22),
                  ),
                  SizedBox(height: Responsive.height(context, 4)),
                  Text(
                    'Sign up to unlock',
                    style: GoogleFonts.manrope(
                      color: accent,
                      fontSize: Responsive.font(context, 12),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutContent(BuildContext context) {
    return ScrollConfiguration(
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
              _guestLock(context, _buildGoalCard(context)),
              SizedBox(height: Responsive.height(context, 20)),
              sectionHeader("START", context),
              _guestLock(
                context,
                Column(
                  children: [
                    _buildStartWorkoutCard(context),
                    SizedBox(height: Responsive.height(context, 12)),
                    _buildRoutineActionCards(context),
                  ],
                ),
              ),
              SizedBox(height: Responsive.height(context, 20)),
              sectionHeader("MY ROUTINES", context),
              _guestLock(context, _buildMyRoutinesCard(context)),
              SizedBox(height: Responsive.height(context, 20)),
              sectionHeader("TODAY'S OVERVIEW", context),
              _guestLock(context, _buildLiftsCard(context)),
              SizedBox(height: Responsive.height(context, 20)),
              sectionHeader("ACTIVITY HEATMAP", context),
              _guestLock(context, _buildHeatmapCard(context)),
              SizedBox(height: Responsive.height(context, 20)),
              sectionHeader("RECENT WORKOUTS", context),
              _guestLock(context, _buildRecentWorkoutsCard(context)),
              SizedBox(height: Responsive.height(context, 120)),
            ],
          ),
        ),
      ),
    );
  }
}
