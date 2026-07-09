import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/providers/user_data_provider.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart' hide ShimmerEffect;
import 'package:skeletonizer/skeletonizer.dart'
    show Skeletonizer, ShimmerEffect;
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import '/globals.dart';
import '/guest.dart';
import '/utility/responsive.dart';
import '/utility/unit_converter.dart';
import '/services/user_data_manager.dart';
import '/models/workout_session.dart';
import '/providers/workout_provider.dart';
import 'exercise_picker_screen.dart';
import 'level_up_overlay.dart';

class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>?
  routine; // null = empty session, non-null = from routine

  const ActiveWorkoutScreen({super.key, this.routine});

  @override
  ConsumerState<ActiveWorkoutScreen> createState() =>
      _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen> {
  Color get appColor => ref.watch(
    userDataProvider.select((s) => s.value?.appColor ?? defaultAppColor),
  );

  bool get isImperial =>
      ref.watch(userDataProvider.select((s) => s.value?.units == 'imperial'));

  // controllers keyed by "exIndex_setIndex_field" so they survive rebuilds
  final Map<String, TextEditingController> _controllers = {};

  // exercise stats keyed by exercise_name, loaded on screen open for PREVIOUS column and PR detection
  Map<String, Map<String, dynamic>> _exerciseStats = {};

  // per-set previous data keyed by exercise_name -> set_number -> {weight_kg, reps}
  Map<String, Map<int, Map<String, dynamic>>> _prevSets = {};
  bool _prevSetsLoading = true;

  // PR details per exercise hit this session: name -> {weightPR, repsPR, oldWeight, newWeight, oldReps, newReps}
  final Map<String, Map<String, dynamic>> _prDetails = {};

  bool _reordering = false;
  WorkoutSession?
  _localSession; // holds the session before the provider updates

  // rest timer state (UI-only, not persisted)
  int? _restSeconds;
  Timer? _restTimer;

  // convenience getters into the global session, falls back to local session during the 500ms provider delay
  WorkoutSession get _s =>
      ref.read(workoutProvider).value?.activeSession ?? _localSession!;
  List<Map<String, dynamic>> get _exercises => _s.exercises;
  Map<String, bool> get _checked => _s.checked;
  String? get _workoutName => _s.workoutName;
  int get _restDuration => _s.restDuration;

  TextEditingController _ctrl(int ex, int set, String field) {
    final key = '${ex}_${set}_$field';
    if (!_controllers.containsKey(key)) {
      // prefer restored session value, fall back to set map default
      final sessionVal = field == 'reps' ? _s.reps[key] : _s.weights[key];
      String initial = sessionVal ?? '';
      if (initial.isEmpty) {
        final setMap = (_exercises[ex]['sets'] as List)[set] as Map;
        initial = field == 'reps'
            ? (setMap['reps']?.toString() ?? '')
            : (setMap['weight_kg']?.toString() ?? '');
      }
      _controllers[key] = TextEditingController(text: initial);
    }
    return _controllers[key]!;
  }

  bool _isChecked(int ex, int set) => _checked['${ex}_$set'] ?? false;

  int _checkedCount(int exIndex) {
    final total = (_exercises[exIndex]['sets'] as List).length;
    int n = 0;
    for (int s = 0; s < total; s++) {
      if (_isChecked(exIndex, s)) n++;
    }
    return n;
  }

  void _startRestTimer() {
    _restTimer?.cancel();
    setState(() => _restSeconds = _restDuration);
    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_restSeconds != null && _restSeconds! > 0) {
          _restSeconds = _restSeconds! - 1;
        } else {
          _restSeconds = null;
          t.cancel();
        }
      });
    });
  }

  void _dismissRestTimer() {
    _restTimer?.cancel();
    setState(() => _restSeconds = null);
  }

  @override
  void initState() {
    super.initState();
    // use existing session if one is already active (restored), otherwise build one now
    final existingSession = ref.read(workoutProvider).value?.activeSession;
    WorkoutSession session;
    if (existingSession != null) {
      session = existingSession;
      _localSession = session;
    } else {
      final exercises = <Map<String, dynamic>>[];
      if (widget.routine != null) {
        final templateExercises =
            widget.routine!['exercises'] as List<dynamic>? ?? [];
        for (final exercise in templateExercises) {
          final ex = Map<String, dynamic>.from(exercise as Map);
          final defaultSets = ex['default_sets'] as int? ?? 3;
          exercises.add({
            ...ex,
            // normalize exercise_name to name so the card header renders correctly
            'name': ex['name'] ?? ex['exercise_name'] ?? '',
            'sets': List.generate(
              defaultSets,
              (_) => <String, dynamic>{
                'reps': ex['default_reps'],
                'weight_kg': ex['default_weight_kg'],
              },
            ),
          });
        }
      }
      session = WorkoutSession(
        exercises: exercises,
        startedAtMs: DateTime.now().millisecondsSinceEpoch,
        routineName: widget.routine?['name'] as String?,
        routineId: widget.routine?['id']?.toString(),
      );
      _localSession = session;
      // schedule after mount — Riverpod forbids state changes during widget build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(workoutProvider.notifier).startSession(session);
      });
      logAnalyticsEvent(
        'workout_started',
        parameters: {
          'source': widget.routine != null ? 'routine' : 'blank',
          'routine_name': widget.routine?['name'] as String? ?? '',
          'exercise_count': exercises.length,
        },
      );
    }

    // pre-populate controllers from restored session values
    for (final entry in session.weights.entries) {
      _controllers[entry.key] = TextEditingController(text: entry.value);
    }
    for (final entry in session.reps.entries) {
      _controllers[entry.key] = TextEditingController(text: entry.value);
    }

    if (!isGuest) {
      ref.read(workoutProvider.notifier).fetchExerciseStats().then((stats) {
        if (mounted) setState(() => _exerciseStats = stats);
      });
      final exerciseNames = session.exercises
          .map((exercise) => _cleanName(exercise['name'] as String? ?? ''))
          .where((name) => name.isNotEmpty)
          .toList();
      if (exerciseNames.isNotEmpty) {
        ref
            .read(workoutProvider.notifier)
            .fetchEveryPrevSet(exerciseNames)
            .then((prevSets) {
              if (mounted) {
                setState(() {
                  _prevSets = prevSets;
                  _prevSetsLoading = false;
                });
              }
            });
      } else {
        _prevSetsLoading = false;
      }
    }
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _removeExercise(int exIndex) {
    final toRemove = _controllers.keys
        .where((k) => k.startsWith('${exIndex}_'))
        .toList();
    for (final k in toRemove) {
      _controllers[k]!.dispose();
      _controllers.remove(k);
    }
    final checkedKeys = _checked.keys
        .where((k) => k.startsWith('${exIndex}_'))
        .toList();
    for (final k in checkedKeys) {
      _checked.remove(k);
    }
    setState(() => _exercises.removeAt(exIndex));
    ref.read(workoutProvider.notifier).persist();
  }

  String get _durationLabel {
    final s = _s.elapsed;
    final h = s.inHours;
    final m = s.inMinutes % 60;
    final sec = s.inSeconds % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  int get _totalSets {
    int n = 0;
    for (final ex in _exercises) {
      n += (ex['sets'] as List).length;
    }
    return n;
  }

  int get _completedSets {
    int n = 0;
    for (int i = 0; i < _exercises.length; i++) {
      n += _checkedCount(i);
    }
    return n;
  }

  double get _totalVolumeKg {
    double vol = 0;
    for (final ex in _exercises) {
      for (final set in ex['sets'] as List) {
        final rawWeight = set['weight_kg'] as double? ?? 0.0;
        // weight_kg field holds lbs when in imperial mode until converted at save time
        final weightKg = isImperial
            ? UnitConverter.lbsToKg(rawWeight)
            : rawWeight;
        vol += (set['reps'] as int? ?? 0) * weightKg;
      }
    }
    return vol;
  }

  Future<bool> _confirmDiscard() async {
    final result = await showFrostedAlertDialog<bool>(
      context: context,
      appColor: appColor,
      title: 'Discard workout?',
      content: Text(
        'All progress will be lost.',
        style: GoogleFonts.manrope(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(false),
          child: Text('Cancel', style: dialogButtonStyle()),
        ),
        TextButton(
          onPressed: () {
            logAnalyticsEvent('workout_minimized');
            Navigator.of(context, rootNavigator: true).pop(false);
            Navigator.of(context).pop();
          },
          child: Text('Minimize', style: dialogButtonStyle()),
        ),
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
          child: Text('Discard', style: dialogButtonStyle(confirm: true)),
        ),
      ],
    );
    return result == true;
  }

  Future<void> _finishWorkout() async {
    // require at least one checked set before saving
    if (_completedSets == 0) {
      showFrostedAlertDialog<void>(
        context: context,
        appColor: appColor,
        title: 'No sets logged',
        content: Text(
          'Check off at least one set before finishing.',
          style: GoogleFonts.manrope(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            child: Text('OK', style: dialogButtonStyle(confirm: true)),
          ),
        ],
      );
      return;
    }

    if (isGuest) {
      Guest.block(context);
      return;
    }

    // prompt for a name before saving
    final nameCtrl = TextEditingController(
      text: _workoutName ?? _s.routineName ?? '',
    );
    final confirmedName = await showFrostedDialog<String>(
      context: context,
      appColor: appColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Name this workout',
            style: GoogleFonts.manrope(
              color: lightenColor(appColor, 0.45),
              fontSize: Responsive.font(context, 16),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: Responsive.height(context, 16)),
          TextField(
            controller: nameCtrl,
            autofocus: true,
            maxLength: 40,
            style: GoogleFonts.manrope(
              color: lightenColor(appColor, 0.45),
              fontSize: Responsive.font(context, 15),
            ),
            decoration: InputDecoration(
              hintText: 'e.g. Push Day',
              hintStyle: GoogleFonts.manrope(color: Colors.white38),
              counterStyle: GoogleFonts.manrope(
                color: Colors.white38,
                fontSize: Responsive.font(context, 10),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: appColor.withAlpha(200)),
              ),
            ),
            cursorColor: lightenColor(appColor, 0.45),
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
                ).pop(nameCtrl.text.trim()),
                child: Text('Save', style: dialogButtonStyle(confirm: true)),
              ),
            ],
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => nameCtrl.dispose());
    if (confirmedName == null) return; // user tapped Cancel
    _s.workoutName = confirmedName.isEmpty ? null : confirmedName;
    ref.read(workoutProvider.notifier).persist();

    final durationSeconds = _s.elapsed.inSeconds;
    final date = DateTime.now();
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    // build the exercises list with only checked sets that have real values
    final exercises = <Map<String, dynamic>>[];
    for (int i = 0; i < _exercises.length; i++) {
      final ex = _exercises[i];
      final checkedSets = <Map<String, dynamic>>[];
      final sets = ex['sets'] as List;
      for (int s = 0; s < sets.length; s++) {
        if (!_isChecked(i, s)) continue;
        // read from controllers in case onChanged never fired (e.g. user typed then tapped check)
        final reps =
            int.tryParse(_ctrl(i, s, 'reps').text) ??
            (sets[s] as Map)['reps'] as int?;
        final weight =
            double.tryParse(_ctrl(i, s, 'weight').text) ??
            ((sets[s] as Map)['weight_kg'] as num?)?.toDouble();
        // skip sets with no meaningful data
        if ((reps == null || reps == 0) && (weight == null || weight == 0)) {
          continue;
        }
        // convert to kg before storing if user is in imperial mode
        final weightKg = (weight != null && isImperial)
            ? UnitConverter.lbsToKg(weight)
            : weight;
        checkedSets.add({
          'set_number': s + 1,
          'reps': reps,
          'weight_kg': weightKg,
        });
      }
      if (checkedSets.isEmpty) continue;
      exercises.add({
        'exercise_id': ex['id'],
        'exercise_name': _cleanName(ex['name'] as String? ?? ''),
        'primary_muscle': ex['primary_muscle'] as String? ?? '',
        'secondary_muscles': ex['secondary_muscles'] as List<dynamic>? ?? [],
        'sets': checkedSets,
      });
    }

    if (exercises.isEmpty) {
      showFrostedAlertDialog<void>(
        context: context,
        appColor: appColor,
        title: 'No valid sets',
        content: Text(
          'Enter reps or weight for at least one checked set.',
          style: GoogleFonts.manrope(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            child: Text('OK', style: dialogButtonStyle(confirm: true)),
          ),
        ],
      );
      return;
    }

    try {
      final response = await authenticatedPost(
        'log_workout',
        body: {
          'name': _workoutName ?? _s.routineName,
          'date': dateStr,
          'duration_seconds': durationSeconds,
          'exercises': exercises,
        },
        timeout: const Duration(seconds: 10),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ref.read(workoutProvider.notifier).refreshAfterWorkout();
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        logAnalyticsEvent(
          'workout_completed',
          parameters: {
            'duration_seconds': durationSeconds,
            'exercise_count': exercises.length,
            'xp_gained': data['xp_gained'] as int? ?? 0,
          },
        );
        const streakMilestones = [3, 7, 14, 30, 60, 100];
        final workoutStreak =
            ref.read(userDataProvider).value?.workoutStreak ?? 0;
        if (streakMilestones.contains(workoutStreak)) {
          logAnalyticsEvent(
            'streak_milestone',
            parameters: {'streak_type': 'workout', 'streak': workoutStreak},
          );
        }
        // update XP, level, and streak from the response immediately
        final levelBefore = ref.read(userDataProvider).value?.level ?? 1;
        ref
            .read(userDataProvider.notifier)
            .patch(
              (u) => u.copyWith(
                level: data['new_level'] as int? ?? u.level,
                expPoints: data['new_exp'] as int? ?? u.expPoints,
                workoutStreak: data['new_streak'] as int? ?? u.workoutStreak,
                workoutStreakLastDate:
                    data['streak_last_date'] as String? ??
                    u.workoutStreakLastDate,
                workoutStreakBest: data['best_streak'] != null
                    ? ((data['best_streak'] as int) > u.workoutStreakBest
                          ? data['best_streak'] as int
                          : u.workoutStreakBest)
                    : u.workoutStreakBest,
              ),
            );
        // compute volume from the clean exercises list since the in-memory set maps
        // may not have been updated if onChanged never fired before the user tapped check
        double totalVolumeKg = 0;
        int totalSets = 0;
        for (final ex in exercises) {
          for (final s in ex['sets'] as List) {
            totalVolumeKg +=
                ((s['reps'] as int? ?? 0) * (s['weight_kg'] as double? ?? 0.0));
            totalSets++;
          }
        }
        // Time-based workout achievements, client knows local time
        final hour = DateTime.now().hour;
        if (hour < 8) trackTrivialAchievement('early_workout');
        if (hour >= 22) trackTrivialAchievement('late_workout');

        if (mounted) {
          await handleLevelUpOverlay(context, levelBefore, appColor, ref);
        }
        if (!mounted) return;
        ref.read(workoutProvider.notifier).clearSession();
        context.pushReplacement(
          '/workout/finish',
          extra: <String, dynamic>{
            'workout_id': data['workout_id'] as String,
            'duration_seconds': durationSeconds,
            'total_volume_kg': totalVolumeKg,
            'completed_sets': totalSets,
            'exercises': exercises,
            'xp_gained': data['xp_gained'] as int? ?? 0,
            'pr_details': _prDetails,
          },
        );
      } else {
        _showSnackbar('Failed to save workout. Try again.');
      }
    } catch (_) {
      if (mounted) _showSnackbar('No connection. Workout not saved.');
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.manrope()),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _replaceExercise(int exIndex) {
    final primaryMuscle =
        _exercises[exIndex]['primary_muscle'] as String? ?? '';
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ExercisePickerScreen(
              replacingExercisePrimaryMuscle: primaryMuscle,
              onExerciseSelected: (ex) {
                setState(() {
                  final existingSets = _exercises[exIndex]['sets'];
                  _exercises[exIndex] = {
                    ...ex,
                    'name': ex['name'] ?? ex['exercise_name'] ?? '',
                    'sets': existingSets,
                  };
                });
              },
            ),
        transitionsBuilder: (_, animation, secondaryAnimation, child) =>
            SlideTransition(
              position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                  .chain(CurveTween(curve: Curves.easeOutCubic))
                  .animate(animation),
              child: child,
            ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  void _showExerciseMenu(
    BuildContext context,
    int exIndex,
    Color accent,
    Color dim,
  ) async {
    final name = _cleanName(_exercises[exIndex]['name'] as String? ?? '');

    Widget menuItem(IconData icon, String label, String value, {Color? color}) {
      final c = color ?? accent;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context, rootNavigator: true).pop(value),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: Responsive.height(context, 14),
          ),
          child: Row(
            children: [
              Icon(icon, color: c, size: Responsive.scale(context, 20)),
              SizedBox(width: Responsive.width(context, 14)),
              Text(
                label,
                style: GoogleFonts.manrope(
                  color: c,
                  fontSize: Responsive.font(context, 14),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final result = await showFrostedDialog<String>(
      context: context,
      appColor: appColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: GoogleFonts.manrope(
              color: accent,
              fontSize: Responsive.font(context, 15),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: Responsive.height(context, 12)),
          Divider(color: Colors.white.withAlpha(15), height: 1),
          menuItem(Icons.swap_horiz_rounded, 'Replace', 'replace'),
          Divider(color: Colors.white.withAlpha(15), height: 1),
          menuItem(Icons.swap_vert_rounded, 'Reorder', 'reorder'),
          Divider(color: Colors.white.withAlpha(15), height: 1),
          menuItem(
            Icons.delete_outline_rounded,
            'Remove',
            'remove',
            color: accent,
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (result == 'replace') {
      _replaceExercise(exIndex);
    } else if (result == 'reorder') {
      HapticFeedback.mediumImpact();
      setState(() => _reordering = true);
    } else if (result == 'remove') {
      _removeExercise(exIndex);
    }
  }

  void _openWorkoutSettings() {
    final accent = lightenColor(appColor, 0.45);
    final dim = lightenColor(appColor, 0.35);
    showFrostedDialog<void>(
      context: context,
      appColor: appColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Workout Settings',
            style: GoogleFonts.manrope(
              color: accent,
              fontSize: Responsive.font(context, 16),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: Responsive.height(context, 20)),
          Text(
            'Rest Timer',
            style: GoogleFonts.manrope(
              color: dim,
              fontSize: Responsive.font(context, 13),
            ),
          ),
          SizedBox(height: Responsive.height(context, 10)),
          StatefulBuilder(
            builder: (context, setDialogState) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    if (_restDuration > 15) {
                      setDialogState(() {
                        _s.restDuration -= 15;
                        ref.read(workoutProvider.notifier).persist();
                      });
                      setState(() {});
                    }
                  },
                  child: Icon(
                    Icons.remove_rounded,
                    color: dim,
                    size: Responsive.scale(context, 22),
                  ),
                ),
                SizedBox(width: Responsive.width(context, 16)),
                Text(
                  '${_restDuration}s',
                  style: GoogleFonts.manrope(
                    color: accent,
                    fontSize: Responsive.font(context, 22),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: Responsive.width(context, 16)),
                GestureDetector(
                  onTap: () {
                    if (_restDuration < 300) {
                      setDialogState(() {
                        _s.restDuration += 15;
                        ref.read(workoutProvider.notifier).persist();
                      });
                      setState(() {});
                    }
                  },
                  child: Icon(
                    Icons.add_rounded,
                    color: dim,
                    size: Responsive.scale(context, 22),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: Responsive.height(context, 20)),
          GestureDetector(
            onTap: () => Navigator.of(context, rootNavigator: true).pop(),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                vertical: Responsive.height(context, 12),
              ),
              decoration: BoxDecoration(
                color: lightenColor(appColor, 0.1).withAlpha(40),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: lightenColor(appColor, 0.35).withAlpha(120),
                  width: 1.5,
                ),
              ),
              child: Text(
                'Done',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  color: accent,
                  fontSize: Responsive.font(context, 14),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openExercisePicker() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ExercisePickerScreen(
              onExerciseSelected: (ex) {
                setState(() {
                  _exercises.add({
                    ...ex,
                    'name': ex['name'] ?? ex['exercise_name'] ?? '',
                    'sets': [
                      <String, dynamic>{'reps': null, 'weight_kg': null},
                    ],
                  });
                });
                ref.read(workoutProvider.notifier).persist();
              },
            ),
        transitionsBuilder: (_, animation, secondaryAnimation, child) =>
            SlideTransition(
              position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                  .chain(CurveTween(curve: Curves.easeOutCubic))
                  .animate(animation),
              child: child,
            ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  // strip trailing parenthetical suffixes from seeded data e.g. "Box Jump (Multiple Response)" -> "Box Jump"
  String _cleanName(String raw) =>
      raw.replaceAll(RegExp(r'\s*\(.*?\)\s*$'), '').trim();

  // compares current weight/reps in the controllers against stored lifetime PRs.
  // returns a detail map if either is a new PR, null if not.
  Map<String, dynamic>? _detectPR(
    String exerciseName,
    int exIndex,
    int setIndex,
  ) {
    final stats = _exerciseStats[exerciseName];

    final wRaw = double.tryParse(_ctrl(exIndex, setIndex, 'weight').text);
    // controller value is in display units; convert to kg for comparison against stored pr_weight_kg
    final w = wRaw == null
        ? null
        : (isImperial ? UnitConverter.lbsToKg(wRaw) : wRaw);
    final r = int.tryParse(_ctrl(exIndex, setIndex, 'reps').text);
    var oldWeight = (stats?['pr_weight_kg'] as num?)?.toDouble();
    var oldReps = stats?['pr_reps'] as int?;
    // pr_weight_kg/pr_reps can be null for bodyweight exercises that were never stored with weight.
    // fall back to the best value seen in _prevSets so we don't false-positive on a "first ever" PR
    if (oldWeight == null || oldReps == null) {
      final prevSetsForExercise = _prevSets[exerciseName];
      if (prevSetsForExercise != null) {
        for (final ps in prevSetsForExercise.values) {
          final pw = (ps['weight_kg'] as num?)?.toDouble();
          final pr = ps['reps'] as int?;
          if (pw != null && (oldWeight == null || pw > oldWeight)) {
            oldWeight = pw;
          }
          if (pr != null && (oldReps == null || pr > oldReps)) oldReps = pr;
        }
      }
    }
    final isWeightPR =
        w != null && w > 0 && (oldWeight == null || w > oldWeight);
    final isRepsPR = r != null && r > 0 && (oldReps == null || r > oldReps);
    if (!isWeightPR && !isRepsPR) return null;
    return {
      'weightPR': isWeightPR,
      'repsPR': isRepsPR,
      'oldWeight': oldWeight,
      'newWeight': w,
      'oldReps': oldReps,
      'newReps': r,
    };
  }

  // shows a snackbar describing what kind of PR was hit and by how much
  void _showPRSnackbar(String exerciseName, Map<String, dynamic> pr) {
    final parts = <String>[];
    if (pr['weightPR'] as bool) {
      final oldW = pr['oldWeight'] as double?;
      final newW = pr['newWeight'] as double;
      final newDisplay = UnitConverter.displayWeightCompact(
        newW,
        imperial: isImperial,
      );
      final unit = isImperial ? 'lbs' : 'kg';
      if (oldW != null) {
        final oldDisplay = UnitConverter.displayWeightCompact(
          oldW,
          imperial: isImperial,
        );
        parts.add('Weight PR: $oldDisplay -> $newDisplay $unit');
      } else {
        parts.add('First weight logged: $newDisplay $unit');
      }
    }
    if (pr['repsPR'] as bool) {
      final oldR = pr['oldReps'] as int?;
      final newR = pr['newReps'] as int;
      if (oldR != null) {
        parts.add('Reps PR: $oldR -> $newR');
      } else {
        parts.add('First reps logged: $newR');
      }
    }
    if (parts.isEmpty || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$exerciseName: ${parts.join(' | ')}',
          style: GoogleFonts.manrope(),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // borderless bare input, no fill, no border, just the number
  InputDecoration _fieldDec(String hint) {
    final onCard = cardColors(appColor).onCard;
    return InputDecoration(
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      hintText: hint,
      hintStyle: GoogleFonts.manrope(
        color: onCard.withAlpha(60),
        fontSize: Responsive.font(context, 15),
      ),
      isDense: true,
      contentPadding: EdgeInsets.zero,
    );
  }

  @override
  Widget build(BuildContext context) {
    // session is cleared just before pushReplacement to finish screen;
    // guard here so the brief rebuild during the transition doesn't crash
    final sessionReady =
        ref.watch(workoutProvider).value?.activeSession != null;
    if (_localSession == null) return const SizedBox.shrink();

    final double vol = _totalVolumeKg;
    final String volDisplay = isImperial
        ? UnitConverter.displayWeight(vol, imperial: true)
        : vol.toStringAsFixed(0);
    final String volUnit = isImperial ? 'lbs' : 'kg';

    final accent = lightenColor(appColor, 0.45);
    final dim = lightenColor(appColor, 0.35);
    return Skeletonizer(
      enabled: !sessionReady,
      effect: ShimmerEffect(
        baseColor: lightenColor(appColor, 0.10),
        highlightColor: lightenColor(appColor, 0.22),
        duration: const Duration(milliseconds: 1200),
      ),
      child: Container(
        decoration: BoxDecoration(gradient: buildThemeGradient(appColor)),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Material(
            color: Colors.transparent,
            child: SafeArea(
              child: Column(
                children: [
                  _buildHeader(context, accent, dim, volDisplay, volUnit),
                  Container(height: 1, color: Colors.white.withAlpha(15)),
                  if (_exercises.isEmpty && !_reordering)
                    Expanded(
                      child: Center(
                        child: _buildEmptyState(context, accent, dim),
                      ),
                    ),
                  if (_exercises.isNotEmpty || _reordering)
                    Expanded(
                      child: ScrollConfiguration(
                        behavior: NoGlowScrollBehavior(),
                        child: ReorderableListView(
                          padding: EdgeInsets.only(
                            bottom: Responsive.height(context, 8),
                          ),
                          buildDefaultDragHandles: false,
                          proxyDecorator: (child, index, animation) => child,
                          onReorder: _reordering
                              ? (oldIndex, newIndex) {
                                  setState(() {
                                    if (newIndex > oldIndex) newIndex--;
                                    final oldOrder = List.of(_exercises);
                                    final ex = _exercises.removeAt(oldIndex);
                                    _exercises.insert(newIndex, ex);
                                    final newControllers =
                                        <String, TextEditingController>{};
                                    final newChecked = <String, bool>{};
                                    for (
                                      int newI = 0;
                                      newI < _exercises.length;
                                      newI++
                                    ) {
                                      final oldI = oldOrder.indexOf(
                                        _exercises[newI],
                                      );
                                      final sets =
                                          (_exercises[newI]['sets'] as List)
                                              .length;
                                      for (int s = 0; s < sets; s++) {
                                        for (final field in [
                                          'reps',
                                          'weight',
                                        ]) {
                                          final oldKey = '${oldI}_${s}_$field';
                                          final newKey = '${newI}_${s}_$field';
                                          if (_controllers.containsKey(
                                            oldKey,
                                          )) {
                                            newControllers[newKey] =
                                                _controllers[oldKey]!;
                                          }
                                        }
                                        final oldCheckedKey = '${oldI}_$s';
                                        if (_checked.containsKey(
                                          oldCheckedKey,
                                        )) {
                                          newChecked['${newI}_$s'] =
                                              _checked[oldCheckedKey]!;
                                        }
                                      }
                                    }
                                    _controllers
                                      ..clear()
                                      ..addAll(newControllers);
                                    _checked
                                      ..clear()
                                      ..addAll(newChecked);
                                  });
                                  ref.read(workoutProvider.notifier).persist();
                                }
                              : (oldI, newI) {},
                          children: [
                            for (int i = 0; i < _exercises.length; i++)
                              _buildExerciseSection(
                                context,
                                i,
                                accent,
                                dim,
                                isImperial,
                                key: ValueKey(i),
                              ),
                          ],
                        ),
                      ),
                    ),
                  if (_reordering)
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _reordering = false);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          vertical: Responsive.height(context, 12),
                        ),
                        color: appColor.withAlpha(60),
                        child: Text(
                          'Done Reordering',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            color: lightenColor(appColor, 0.45),
                            fontSize: Responsive.font(context, 14),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  _buildBottomBar(context, accent, dim),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _renameWorkout() async {
    final ctrl = TextEditingController(text: _workoutName);
    final result = await showFrostedDialog<String>(
      context: context,
      appColor: appColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Name this workout',
            style: GoogleFonts.manrope(
              color: lightenColor(appColor, 0.45),
              fontSize: Responsive.font(context, 16),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: Responsive.height(context, 16)),
          TextField(
            controller: ctrl,
            autofocus: true,
            maxLength: 40,
            style: GoogleFonts.manrope(
              color: lightenColor(appColor, 0.45),
              fontSize: Responsive.font(context, 15),
            ),
            decoration: InputDecoration(
              hintText: 'e.g. Push Day',
              hintStyle: GoogleFonts.manrope(color: Colors.white38),
              counterStyle: GoogleFonts.manrope(
                color: Colors.white38,
                fontSize: Responsive.font(context, 10),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: appColor.withAlpha(200)),
              ),
            ),
            cursorColor: lightenColor(appColor, 0.45),
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
                ).pop(ctrl.text.trim()),
                child: Text('Save', style: dialogButtonStyle(confirm: true)),
              ),
            ],
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    if (result != null && mounted) {
      setState(() {
        _s.workoutName = result.isEmpty ? null : result;
        ref.read(workoutProvider.notifier).persist();
      });
    }
  }

  Widget _buildHeader(
    BuildContext context,
    Color accent,
    Color dim,
    String volDisplay,
    String volUnit,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.centeredHorizontalPadding(context, 20),
        vertical: Responsive.height(context, 14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              logAnalyticsEvent('workout_minimized');
              Navigator.of(context).pop();
            },
            child: Padding(
              padding: EdgeInsets.only(right: Responsive.width(context, 12)),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: lightenColor(appColor, 0.35),
                size: Responsive.scale(context, 28),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: _renameWorkout,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _durationLabel,
                    style: GoogleFonts.manrope(
                      color: accent,
                      fontSize: Responsive.font(context, 28),
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          _workoutName ?? _s.routineName ?? 'Tap to name',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            color:
                                _workoutName != null || _s.routineName != null
                                ? dim
                                : lightenColor(appColor, 0.35),
                            fontSize: Responsive.font(context, 13),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(width: Responsive.width(context, 3)),
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: Responsive.padding(context, 1),
                        ),
                        child: Icon(
                          Icons.edit_rounded,
                          color: lightenColor(appColor, 0.35),
                          size: Responsive.scale(context, 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // stats column, rest timer appears as a third line when active
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$volDisplay $volUnit',
                style: GoogleFonts.manrope(
                  color: accent,
                  fontSize: Responsive.font(context, 13),
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '$_completedSets / $_totalSets sets',
                style: GoogleFonts.manrope(
                  color: dim,
                  fontSize: Responsive.font(context, 11),
                ),
              ),
              if (_restSeconds != null)
                GestureDetector(
                  onTap: _dismissRestTimer,
                  child: Text(
                    () {
                      final m = (_restSeconds! ~/ 60).toString().padLeft(
                        2,
                        '0',
                      );
                      final s = (_restSeconds! % 60).toString().padLeft(2, '0');
                      return 'rest $m:$s';
                    }(),
                    style: GoogleFonts.manrope(
                      color: accent,
                      fontSize: Responsive.font(context, 11),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(width: Responsive.width(context, 12)),
          GestureDetector(
            onTap: _finishWorkout,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.width(context, 18),
                vertical: Responsive.height(context, 10),
              ),
              decoration: BoxDecoration(
                color: appColor.withAlpha(70),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: appColor.withAlpha(150), width: 1.5),
              ),
              child: Text(
                'Finish',
                style: GoogleFonts.manrope(
                  color: accent,
                  fontSize: Responsive.font(context, 14),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, Color accent, Color dim) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        HugeIcon(
          icon: HugeIcons.strokeRoundedDumbbell01,
          color: Colors.white.withAlpha(35),
          size: Responsive.scale(context, 44),
        ),
        SizedBox(height: Responsive.height(context, 14)),
        Text(
          'No exercises yet',
          style: GoogleFonts.manrope(
            color: accent,
            fontSize: Responsive.font(context, 15),
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: Responsive.height(context, 4)),
        Text(
          'Tap Add Exercise below to get started',
          style: GoogleFonts.manrope(
            color: dim,
            fontSize: Responsive.font(context, 12),
          ),
        ),
      ],
    );
  }

  Widget _buildExerciseSection(
    BuildContext context,
    int exIndex,
    Color accent,
    Color dim,
    bool isImperial, {
    Key? key,
  }) {
    final ex = _exercises[exIndex];
    final sets = ex['sets'] as List;
    final name = _cleanName(ex['name'] as String? ?? '');
    final weightUnit = isImperial ? 'lbs' : 'kg';
    final checkedCount = _checkedCount(exIndex);
    final totalCount = sets.length;
    final hPad = Responsive.centeredHorizontalPadding(context, 20);

    // bar encodes completion: none=muted, partial=dim accent, full=full accent
    final Color barColor = checkedCount == 0
        ? Colors.white.withAlpha(50)
        : checkedCount < totalCount
        ? accent.withAlpha(160)
        : accent;

    final card = Padding(
      padding: EdgeInsets.only(
        left: hPad,
        right: hPad,
        top: Responsive.height(context, 12),
        bottom: Responsive.height(context, 4),
      ),
      child: frostedGlassCard(
        context,
        color: appColor,
        padding: EdgeInsets.zero,
        border: Border.all(
          color: lightenColor(appColor, 0.3).withAlpha(80),
          width: 1.5,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // header row — long press enters reorder mode
            GestureDetector(
              onLongPress: () {
                HapticFeedback.mediumImpact();
                setState(() => _reordering = true);
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.only(
                  left: Responsive.width(context, 16),
                  right: Responsive.width(context, 16),
                  top: Responsive.height(context, 10),
                  bottom: Responsive.height(context, 8),
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: Responsive.width(context, 3),
                      height: Responsive.height(context, 22),
                      margin: EdgeInsets.only(
                        right: Responsive.width(context, 10),
                      ),
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        name,
                        style: GoogleFonts.manrope(
                          color: accent,
                          fontSize: Responsive.font(context, 16),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (_prDetails.containsKey(name)) ...[
                      SizedBox(width: Responsive.width(context, 8)),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.width(context, 7),
                          vertical: Responsive.height(context, 3),
                        ),
                        decoration: BoxDecoration(
                          color: appColor.withAlpha(60),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: accent.withAlpha(120),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'PR',
                          style: GoogleFonts.manrope(
                            color: accent,
                            fontSize: Responsive.font(context, 10),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _reordering
                          ? Icon(
                              Icons.drag_handle_rounded,
                              key: const ValueKey('drag'),
                              color: cardColors(appColor).onCard.withAlpha(120),
                              size: Responsive.scale(context, 20),
                            )
                          : Builder(
                              key: const ValueKey('menu'),
                              builder: (btnContext) => GestureDetector(
                                onTap: () => _showExerciseMenu(
                                  btnContext,
                                  exIndex,
                                  accent,
                                  dim,
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(
                                    Responsive.scale(context, 4),
                                  ),
                                  child: Icon(
                                    Icons.more_vert_rounded,
                                    color: cardColors(
                                      appColor,
                                    ).onCard.withAlpha(120),
                                    size: Responsive.scale(context, 18),
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),

            // body collapses in reorder mode
            Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // column headers
                    Padding(
                      padding: EdgeInsets.only(
                        left: Responsive.width(context, 16),
                        right: Responsive.width(context, 16),
                        bottom: Responsive.height(context, 6),
                      ),
                      child: Row(
                        children: [
                          _headerCell(
                            context,
                            'SET',
                            width: Responsive.width(context, 28),
                          ),
                          SizedBox(width: Responsive.width(context, 12)),
                          _headerExpanded(context, 'PREVIOUS'),
                          SizedBox(width: Responsive.width(context, 12)),
                          _headerExpanded(context, weightUnit.toUpperCase()),
                          SizedBox(width: Responsive.width(context, 12)),
                          _headerExpanded(context, 'REPS'),
                          SizedBox(width: Responsive.width(context, 12)),
                          SizedBox(width: Responsive.scale(context, 28)),
                        ],
                      ),
                    ),

                    Container(height: 1, color: Colors.white.withAlpha(8)),

                    // set rows
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: Responsive.height(context, 36) * 5,
                      ),
                      child: ScrollConfiguration(
                        behavior: NoGlowScrollBehavior(),
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              for (int s = 0; s < sets.length; s++)
                                _buildSetRow(
                                  context,
                                  exIndex,
                                  s,
                                  accent,
                                  dim,
                                  isImperial,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // add set
                    GestureDetector(
                      onTap: () {
                        setState(
                          () => sets.add(<String, dynamic>{
                            'reps': null,
                            'weight_kg': null,
                          }),
                        );
                        ref.read(workoutProvider.notifier).persist();
                      },
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          vertical: Responsive.height(context, 9),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              color: dim,
                              size: Responsive.scale(context, 16),
                            ),
                            SizedBox(width: Responsive.width(context, 4)),
                            Text(
                              'Add Set',
                              style: GoogleFonts.manrope(
                                color: dim,
                                fontSize: Responsive.font(context, 13),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
                .animate(target: _reordering ? 1 : 0)
                .fadeOut(duration: 250.ms, curve: Curves.easeOutCubic)
                .custom(
                  duration: 250.ms,
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) => ClipRect(
                    child: Align(
                      alignment: Alignment.topCenter,
                      heightFactor: 1 - value,
                      child: child,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );

    if (_reordering) {
      return ReorderableDragStartListener(
        key: key,
        index: exIndex,
        child: card,
      );
    }
    return KeyedSubtree(key: key, child: card);
  }

  Widget _headerCell(
    BuildContext context,
    String label, {
    required double width,
  }) {
    final subtle = cardColors(appColor).onCard.withAlpha(120);
    return SizedBox(
      width: width,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: GoogleFonts.manrope(
          color: subtle,
          fontSize: Responsive.font(context, 10),
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _headerExpanded(BuildContext context, String label) {
    final subtle = cardColors(appColor).onCard.withAlpha(120);
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: GoogleFonts.manrope(
          color: subtle,
          fontSize: Responsive.font(context, 10),
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildSetRow(
    BuildContext context,
    int exIndex,
    int setIndex,
    Color accent,
    Color dim,
    bool isImperial,
  ) {
    final set = (_exercises[exIndex]['sets'] as List)[setIndex] as Map;
    final checked = _isChecked(exIndex, setIndex);
    final c = cardColors(appColor);
    final onCard = c.onCard;

    final rowBg = checked
        ? appColor.withAlpha(28)
        : setIndex.isOdd
        ? onCard.withAlpha(8)
        : Colors.transparent;

    final numColor = onCard.withAlpha(checked ? 255 : 180);
    final numWeight = checked ? FontWeight.w700 : FontWeight.w500;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      color: rowBg,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.width(context, 16),
        vertical: Responsive.height(context, 5),
      ),
      child: Row(
        children: [
          // set number
          SizedBox(
            width: Responsive.width(context, 28),
            child: Text(
              '${setIndex + 1}',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: checked ? onCard : onCard.withAlpha(140),
                fontSize: Responsive.font(context, 13),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: Responsive.width(context, 12)),
          // per-set previous: exact match from the previous session by set number.
          // set 1 falls back to exercise summary stats so first-time users see something useful.
          // set 2+ shows - if the previous session had fewer sets.
          Expanded(
            child: Builder(
              builder: (context) {
                final exerciseName = _cleanName(
                  _exercises[exIndex]['name'] as String? ?? '',
                );
                final prevSet = _prevSets[exerciseName]?[setIndex + 1];
                var prevWeight = prevSet?['weight_kg'];
                var prevReps = prevSet?['reps'];
                if (prevWeight == null && prevReps == null && setIndex == 0) {
                  final stats = _exerciseStats[exerciseName];
                  prevWeight = stats?['last_weight_kg'];
                  prevReps = stats?['last_reps'];
                }
                final label = (prevWeight != null && prevReps != null)
                    ? '${UnitConverter.displayWeightCompact((prevWeight as num).toDouble(), imperial: isImperial)} x $prevReps'
                    : '—';
                return AnimatedOpacity(
                  opacity: _prevSetsLoading ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      color: onCard.withAlpha(160),
                      fontSize: Responsive.font(context, 11),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(width: Responsive.width(context, 12)),
          // weight field
          Expanded(
            child: TextField(
              controller: _ctrl(exIndex, setIndex, 'weight'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.center,
              cursorColor: onCard,
              style: GoogleFonts.manrope(
                color: numColor,
                fontSize: Responsive.font(context, 15),
                fontWeight: numWeight,
              ),
              decoration: _fieldDec('0'),
              onChanged: (v) {
                set['weight_kg'] = double.tryParse(v);
                _s.weights['${exIndex}_${setIndex}_weight'] = v;
                ref.read(workoutProvider.notifier).persist();
                // re-evaluate PR silently if this set is already checked
                if (checked) {
                  final name = _cleanName(
                    _exercises[exIndex]['name'] as String? ?? '',
                  );
                  final pr = _detectPR(name, exIndex, setIndex);
                  setState(() {
                    if (pr != null) {
                      _prDetails[name] = pr;
                    } else {
                      _prDetails.remove(name);
                    }
                  });
                }
              },
            ),
          ),
          SizedBox(width: Responsive.width(context, 12)),
          // reps field
          Expanded(
            child: TextField(
              controller: _ctrl(exIndex, setIndex, 'reps'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              cursorColor: onCard,
              style: GoogleFonts.manrope(
                color: numColor,
                fontSize: Responsive.font(context, 15),
                fontWeight: numWeight,
              ),
              decoration: _fieldDec('0'),
              onChanged: (v) {
                set['reps'] = int.tryParse(v);
                _s.reps['${exIndex}_${setIndex}_reps'] = v;
                ref.read(workoutProvider.notifier).persist();
                // re-evaluate PR silently if this set is already checked
                if (checked) {
                  final name = _cleanName(
                    _exercises[exIndex]['name'] as String? ?? '',
                  );
                  final pr = _detectPR(name, exIndex, setIndex);
                  setState(() {
                    if (pr != null) {
                      _prDetails[name] = pr;
                    } else {
                      _prDetails.remove(name);
                    }
                  });
                }
              },
            ),
          ),
          SizedBox(width: Responsive.width(context, 12)),
          // check button
          GestureDetector(
            onTap: () {
              final nowChecked = !checked;
              // block checking a set with no weight and no reps entered
              if (nowChecked) {
                final w =
                    double.tryParse(_ctrl(exIndex, setIndex, 'weight').text) ??
                    0.0;
                final r =
                    int.tryParse(_ctrl(exIndex, setIndex, 'reps').text) ?? 0;
                if (w == 0 && r == 0) return;
              }
              HapticFeedback.lightImpact();
              final exerciseName = _cleanName(
                _exercises[exIndex]['name'] as String? ?? '',
              );
              if (nowChecked) {
                final pr = _detectPR(exerciseName, exIndex, setIndex);
                if (pr != null) {
                  setState(() => _prDetails[exerciseName] = pr);
                  _showPRSnackbar(exerciseName, pr);
                }
              } else {
                // re-evaluate PR across all remaining checked sets for this exercise;
                // if none still hold a PR, remove the badge
                final sets = (_exercises[exIndex]['sets'] as List);
                Map<String, dynamic>? bestPR;
                for (int s = 0; s < sets.length; s++) {
                  if (s == setIndex) continue; // this set is being unchecked
                  if (!(_checked['${exIndex}_$s'] ?? false)) continue;
                  final pr = _detectPR(exerciseName, exIndex, s);
                  if (pr != null) bestPR = pr;
                }
                setState(() {
                  if (bestPR != null) {
                    _prDetails[exerciseName] = bestPR;
                  } else {
                    _prDetails.remove(exerciseName);
                  }
                });
              }
              setState(() => _checked['${exIndex}_$setIndex'] = nowChecked);
              ref.read(workoutProvider.notifier).persist();
              if (nowChecked) _startRestTimer();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: Responsive.scale(context, 28),
              height: Responsive.scale(context, 28),
              decoration: BoxDecoration(
                color: checked ? onCard.withAlpha(220) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: checked
                    ? null
                    : Border.all(color: onCard.withAlpha(80), width: 1.5),
              ),
              child: Icon(
                Icons.check_rounded,
                size: Responsive.scale(context, 16),
                color: checked ? appColor : onCard.withAlpha(80),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, Color accent, Color dim) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withAlpha(15), width: 1),
        ),
      ),
      padding: EdgeInsets.only(
        left: Responsive.centeredHorizontalPadding(context, 20),
        right: Responsive.centeredHorizontalPadding(context, 20),
        top: Responsive.height(context, 14),
        bottom: Responsive.height(context, 22),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _openExercisePicker,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                vertical: Responsive.height(context, 15),
              ),
              decoration: BoxDecoration(
                color: lightenColor(appColor, 0.1).withAlpha(40),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: lightenColor(appColor, 0.35).withAlpha(120),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_rounded,
                    color: accent,
                    size: Responsive.scale(context, 20),
                  ),
                  SizedBox(width: Responsive.width(context, 6)),
                  Text(
                    'Add Exercise',
                    style: GoogleFonts.manrope(
                      color: accent,
                      fontSize: Responsive.font(context, 15),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: Responsive.height(context, 12)),
          IntrinsicHeight(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      if (await _confirmDiscard()) {
                        logAnalyticsEvent(
                          'workout_discarded',
                          parameters: {
                            'duration_seconds': _s.elapsed.inSeconds,
                            'exercise_count': _exercises.length,
                          },
                        );
                        ref.read(workoutProvider.notifier).clearSession();
                        if (context.mounted) Navigator.of(context).pop();
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        vertical: Responsive.height(context, 12),
                      ),
                      decoration: BoxDecoration(
                        color: lightenColor(appColor, 0.1).withAlpha(40),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: lightenColor(appColor, 0.35).withAlpha(120),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        'Discard',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          color: lightenColor(appColor, 0.45),
                          fontSize: Responsive.font(context, 13),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: Responsive.width(context, 10)),
                Expanded(
                  child: GestureDetector(
                    onTap: _openWorkoutSettings,
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        vertical: Responsive.height(context, 12),
                      ),
                      decoration: BoxDecoration(
                        color: lightenColor(appColor, 0.1).withAlpha(40),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: lightenColor(appColor, 0.35).withAlpha(120),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        'Settings',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          color: lightenColor(appColor, 0.45),
                          fontSize: Responsive.font(context, 13),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
