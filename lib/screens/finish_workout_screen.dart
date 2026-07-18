import 'package:confetti/confetti.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/providers/user_data_provider.dart';
import '/providers/workout_provider.dart';
import '/services/user_data_manager.dart' show defaultAppColor;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart' hide ShimmerEffect;
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import '/globals.dart';
import '/utility/responsive.dart';
import '/utility/unit_converter.dart';

class FinishWorkoutScreen extends ConsumerStatefulWidget {
  final String workoutId;
  final int durationSeconds;
  final double totalVolumeKg;
  final int completedSets;
  final List<Map<String, dynamic>> exercises;
  final int xpGained;
  // keyed by exercise_name -> {weightPR, repsPR, oldWeight, newWeight, oldReps, newReps}
  final Map<String, Map<String, dynamic>> prDetails;

  const FinishWorkoutScreen({
    super.key,
    required this.workoutId,
    required this.durationSeconds,
    required this.totalVolumeKg,
    required this.completedSets,
    required this.exercises,
    required this.xpGained,
    required this.prDetails,
  });

  @override
  ConsumerState<FinishWorkoutScreen> createState() =>
      _FinishWorkoutScreenState();
}

class _FinishWorkoutScreenState extends ConsumerState<FinishWorkoutScreen> {
  Color get appColor => ref.watch(
    userDataProvider.select((s) => s.value?.appColor ?? defaultAppColor),
  );

  bool get isImperial =>
      ref.watch(userDataProvider.select((s) => s.value?.units == 'imperial'));

  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(milliseconds: 600));
    if (widget.xpGained > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _confetti.play());
    }
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  String get _durationLabel {
    final h = widget.durationSeconds ~/ 3600;
    final m = (widget.durationSeconds % 3600) ~/ 60;
    final s = widget.durationSeconds % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    if (m > 0) return '${m}m ${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final accent = onTheme(appColor);
    final dim = onTheme(appColor);
    final dimmer = onTheme(appColor);

    final hPad = Responsive.centeredHorizontalPadding(context, 20);
    final prCount = widget.prDetails.length;

    final volDisplay = isImperial
        ? '${UnitConverter.displayWeight(widget.totalVolumeKg, imperial: true)} lbs'
        : '${widget.totalVolumeKg.toStringAsFixed(0)} kg';

    final exp =
        ref.watch(userDataProvider.select((u) => u.value?.expPoints)) ?? 0;
    final expNeeded = ref.read(userDataProvider.notifier).experienceNeeded ?? 1;
    final barFraction = (exp / expNeeded).clamp(0.0, 1.0);

    // collect unique primary and secondary muscles across all exercises
    final primaryMuscles = <String>{};
    final secondaryMuscles = <String>{};
    for (final ex in widget.exercises) {
      final m = ex['primary_muscle'] as String? ?? '';
      if (m.isNotEmpty) primaryMuscles.add(m[0].toUpperCase() + m.substring(1));
      for (final s in ex['secondary_muscles'] as List<dynamic>? ?? []) {
        final sm = s.toString();
        if (sm.isNotEmpty) {
          final cap = sm[0].toUpperCase() + sm.substring(1);
          // only add to secondary if not already a primary
          if (!primaryMuscles.contains(cap)) secondaryMuscles.add(cap);
        }
      }
    }

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(gradient: buildThemeGradient(appColor)),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ScrollConfiguration(
                      behavior: NoGlowScrollBehavior(),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: hPad,
                          vertical: Responsive.height(context, 20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // centered header: icon, title, XP, bar
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                ShaderMask(
                                      shaderCallback: (bounds) =>
                                          LinearGradient(
                                            colors: [
                                              lightenColor(appColor, 0.38),
                                              lightenColor(appColor, 0.22),
                                              lightenColor(appColor, 0.06),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ).createShader(bounds),
                                      child: HugeIcon(
                                        icon: HugeIcons
                                            .strokeRoundedCheckmarkCircle02,
                                        color: onTheme(appColor),
                                        size: Responsive.scale(context, 52),
                                      ),
                                    )
                                    .animate()
                                    .fadeIn(duration: 300.ms)
                                    .slideY(begin: -0.2, curve: Curves.easeOut),

                                SizedBox(
                                  height: Responsive.height(context, 12),
                                ),

                                Text(
                                      'Workout Complete',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.manrope(
                                        color: onTheme(appColor),
                                        fontSize: Responsive.font(context, 30),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    )
                                    .animate()
                                    .fadeIn(delay: 80.ms, duration: 300.ms)
                                    .slideY(begin: 0.15, curve: Curves.easeOut),

                                SizedBox(height: Responsive.height(context, 8)),

                                if (widget.xpGained > 0)
                                  ShimmerWidget(
                                    accent: lightenColor(appColor, 0.48),
                                    child: Text(
                                      '+${widget.xpGained} XP',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.manrope(
                                        color: onTheme(appColor),
                                        fontSize: Responsive.font(context, 28),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ).animate().fadeIn(
                                    delay: 140.ms,
                                    duration: 300.ms,
                                  )
                                else
                                  Text(
                                    'XP already earned from a workout today',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.manrope(
                                      color: onTheme(appColor),
                                      fontSize: Responsive.font(context, 13),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ).animate().fadeIn(
                                    delay: 140.ms,
                                    duration: 300.ms,
                                  ),

                                if (widget.xpGained > 0) ...[
                                  SizedBox(
                                    height: Responsive.height(context, 16),
                                  ),

                                  _buildMiniXpBar(
                                    context,
                                    accent,
                                    dim,
                                    dimmer,
                                    barFraction,
                                    exp,
                                    expNeeded,
                                  ).animate().fadeIn(
                                    delay: 180.ms,
                                    duration: 300.ms,
                                  ),
                                ],
                              ],
                            ),

                            SizedBox(height: Responsive.height(context, 24)),

                            // stat row
                            Text(
                              'SUMMARY',
                              style: GoogleFonts.manrope(
                                color: onTheme(appColor),
                                fontSize: Responsive.font(context, 13),
                                fontWeight: FontWeight.w700,
                              ),
                            ).animate().fadeIn(delay: 220.ms, duration: 300.ms),
                            SizedBox(height: Responsive.height(context, 10)),
                            frostedGlassCard(
                                  context,
                                  color: appColor,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: Responsive.width(context, 20),
                                    vertical: Responsive.height(context, 18),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      _statCell(
                                        context,
                                        accent,
                                        dim,
                                        _durationLabel,
                                        'Duration',
                                      ),
                                      _divider(context),
                                      _statCell(
                                        context,
                                        accent,
                                        dim,
                                        volDisplay,
                                        'Volume',
                                      ),
                                      _divider(context),
                                      _statCell(
                                        context,
                                        accent,
                                        dim,
                                        '${widget.completedSets}',
                                        'Sets',
                                      ),
                                    ],
                                  ),
                                )
                                .animate()
                                .fadeIn(delay: 240.ms, duration: 300.ms)
                                .slideY(begin: 0.1, curve: Curves.easeOut),

                            // PR detail card
                            if (prCount > 0) ...[
                              SizedBox(height: Responsive.height(context, 20)),
                              Text(
                                'PERSONAL RECORDS',
                                style: GoogleFonts.manrope(
                                  color: onTheme(appColor),
                                  fontSize: Responsive.font(context, 13),
                                  fontWeight: FontWeight.w700,
                                ),
                              ).animate().fadeIn(
                                delay: 220.ms,
                                duration: 300.ms,
                              ),
                              SizedBox(height: Responsive.height(context, 10)),
                              _buildPRCard(context, accent, dim, isImperial)
                                  .animate()
                                  .fadeIn(delay: 220.ms, duration: 300.ms)
                                  .slideY(begin: 0.1, curve: Curves.easeOut),
                            ],

                            // muscles worked
                            if (primaryMuscles.isNotEmpty ||
                                secondaryMuscles.isNotEmpty) ...[
                              SizedBox(height: Responsive.height(context, 20)),
                              Text(
                                'MUSCLES WORKED',
                                style: GoogleFonts.manrope(
                                  color: onTheme(appColor),
                                  fontSize: Responsive.font(context, 13),
                                  fontWeight: FontWeight.w700,
                                ),
                              ).animate().fadeIn(
                                delay: 240.ms,
                                duration: 300.ms,
                              ),
                              SizedBox(height: Responsive.height(context, 8)),
                              Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          lightenColor(appColor, 0.38),
                                          lightenColor(appColor, 0.06),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  SizedBox(width: Responsive.width(context, 6)),
                                  Text(
                                    'Primary',
                                    style: GoogleFonts.manrope(
                                      color: onTheme(appColor),
                                      fontSize: Responsive.font(context, 11),
                                    ),
                                  ),
                                  SizedBox(
                                    width: Responsive.width(context, 16),
                                  ),
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: cardColors(appColor).iconBox,
                                      borderRadius: BorderRadius.circular(3),
                                      border: Border.all(
                                        color: cardColors(appColor).border,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: Responsive.width(context, 6)),
                                  Text(
                                    'Secondary',
                                    style: GoogleFonts.manrope(
                                      color: onTheme(appColor),
                                      fontSize: Responsive.font(context, 11),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: Responsive.height(context, 8)),
                              Wrap(
                                spacing: Responsive.width(context, 8),
                                runSpacing: Responsive.height(context, 8),
                                children: [
                                  for (final muscle in primaryMuscles)
                                    _muscleChip(
                                      context,
                                      muscle,
                                      accent,
                                      appColor,
                                      primary: true,
                                    ),
                                  for (final muscle in secondaryMuscles)
                                    _muscleChip(
                                      context,
                                      muscle,
                                      accent,
                                      appColor,
                                      primary: false,
                                    ),
                                ],
                              ).animate().fadeIn(
                                delay: 240.ms,
                                duration: 300.ms,
                              ),
                              SizedBox(height: Responsive.height(context, 20)),
                            ],

                            Text(
                              'EXERCISES',
                              style: GoogleFonts.manrope(
                                color: onTheme(appColor),
                                fontSize: Responsive.font(context, 13),
                                fontWeight: FontWeight.w700,
                              ),
                            ).animate().fadeIn(delay: 300.ms, duration: 300.ms),

                            SizedBox(height: Responsive.height(context, 10)),

                            for (
                              int i = 0;
                              i < widget.exercises.length;
                              i++
                            ) ...[
                              _buildExerciseCard(
                                    context,
                                    widget.exercises[i],
                                    accent,
                                    dim,
                                    isImperial,
                                  )
                                  .animate()
                                  .fadeIn(
                                    delay: (340 + i * 60).ms,
                                    duration: 300.ms,
                                  )
                                  .slideY(begin: 0.1, curve: Curves.easeOut),
                              SizedBox(height: Responsive.height(context, 10)),
                            ],

                            SizedBox(height: Responsive.height(context, 8)),
                          ],
                        ),
                      ),
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      hPad,
                      Responsive.height(context, 10),
                      hPad,
                      Responsive.height(context, 24),
                    ),
                    child: GestureDetector(
                      onTap: () {
                        ref.read(workoutProvider.notifier).loadWorkoutData();
                        context.go('/workout');
                      },
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          vertical: Responsive.height(context, 16),
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              lightenColor(appColor, 0.38),
                              lightenColor(appColor, 0.22),
                              lightenColor(appColor, 0.06),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: cardColors(appColor).iconBorder,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          'Done',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            color: onTheme(appColor),
                            fontSize: Responsive.font(context, 15),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 400.ms, duration: 300.ms),
                ],
              ),
            ),
          ),
        ),

        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 30,
            gravity: 0.35,
            emissionFrequency: 0.04,
            shouldLoop: false,
            maxBlastForce: 25,
            minBlastForce: 12,
            colors: const [
              Colors.yellow,
              Colors.green,
              Colors.blue,
              Colors.purple,
              Colors.orange,
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniXpBar(
    BuildContext context,
    Color accent,
    Color dim,
    Color dimmer,
    double fraction,
    int exp,
    int expNeeded,
  ) {
    final barWidth =
        MediaQuery.of(context).size.width -
        (Responsive.centeredHorizontalPadding(context, 20) * 2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Level ${ref.watch(userDataProvider).value?.level ?? 1}',
              style: GoogleFonts.manrope(
                color: onTheme(appColor),
                fontSize: Responsive.font(context, 11),
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '$exp / $expNeeded XP',
              style: GoogleFonts.manrope(
                color: onTheme(appColor),
                fontSize: Responsive.font(context, 11),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        SizedBox(height: Responsive.height(context, 6)),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: barWidth,
            height: Responsive.height(context, 8),
            color: Colors.white.withAlpha(18),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: fraction),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOut,
              builder: (context, value, _) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: value,
                child: Container(
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPRCard(
    BuildContext context,
    Color accent,
    Color dim,
    bool isImperial,
  ) {
    final unit = isImperial ? 'lbs' : 'kg';

    Widget statChip(String label, String? oldVal, String newVal) {
      return Container(
        decoration: BoxDecoration(
          color: cardColors(appColor).iconBox,
          borderRadius: BorderRadius.circular(Responsive.scale(context, 20)),
          border: Border.all(color: cardColors(appColor).border, width: 1),
        ),
        child: IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.width(context, 10),
                  vertical: Responsive.height(context, 5),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.manrope(
                    color: onTheme(appColor),
                    fontSize: Responsive.font(context, 11),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              VerticalDivider(
                color: onTheme(appColor).withAlpha(120),
                width: 1,
                thickness: 1,
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.width(context, 10),
                  vertical: Responsive.height(context, 5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (oldVal != null) ...[
                      Text(
                        oldVal,
                        style: GoogleFonts.manrope(
                          color: onTheme(appColor).withAlpha(140),
                          fontSize: Responsive.font(context, 11),
                          decoration: TextDecoration.lineThrough,
                          decorationColor: onTheme(appColor).withAlpha(140),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.width(context, 4),
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: onTheme(appColor).withAlpha(140),
                          size: Responsive.scale(context, 10),
                        ),
                      ),
                    ],
                    Text(
                      newVal,
                      style: GoogleFonts.manrope(
                        color: onTheme(appColor),
                        fontSize: Responsive.font(context, 11),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return frostedGlassCard(
      context,
      color: appColor,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.width(context, 16),
        vertical: Responsive.height(context, 16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedMedal01,
                color: onTheme(appColor),
                size: Responsive.scale(context, 20),
              ),
              SizedBox(width: Responsive.width(context, 10)),
              Text(
                widget.prDetails.length == 1
                    ? '1 Personal Record'
                    : '${widget.prDetails.length} Personal Records',
                style: GoogleFonts.manrope(
                  color: onTheme(appColor),
                  fontSize: Responsive.font(context, 15),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.height(context, 12)),
          for (final entry in widget.prDetails.entries) ...[
            Builder(
              builder: (context) {
                final pr = entry.value;
                final weightPR = pr['weightPR'] as bool;
                final repsPR = pr['repsPR'] as bool;
                return Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.width(context, 12),
                    vertical: Responsive.height(context, 10),
                  ),
                  decoration: BoxDecoration(
                    color: cardColors(appColor).iconBox,
                    borderRadius: BorderRadius.circular(
                      Responsive.scale(context, 10),
                    ),
                    border: Border.all(
                      color: cardColors(appColor).iconBorder,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        style: GoogleFonts.manrope(
                          color: onTheme(appColor),
                          fontSize: Responsive.font(context, 13),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: Responsive.height(context, 8)),
                      Divider(
                        color: onTheme(appColor).withAlpha(120),
                        thickness: 1.5,
                        height: 1,
                      ),
                      SizedBox(height: Responsive.height(context, 8)),
                      Wrap(
                        spacing: Responsive.width(context, 6),
                        runSpacing: Responsive.height(context, 6),
                        children: [
                          if (weightPR)
                            statChip(
                              'Weight',
                              pr['oldWeight'] != null
                                  ? '${UnitConverter.displayWeightCompact(pr['oldWeight'] as double, imperial: isImperial)} $unit'
                                  : null,
                              '${UnitConverter.displayWeightCompact(pr['newWeight'] as double, imperial: isImperial)} $unit',
                            ),
                          if (repsPR)
                            statChip(
                              'Reps',
                              pr['oldReps'] != null ? '${pr['oldReps']}' : null,
                              '${pr['newReps']}',
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            SizedBox(height: Responsive.height(context, 8)),
          ],
        ],
      ),
    );
  }

  Widget _buildExerciseCard(
    BuildContext context,
    Map<String, dynamic> ex,
    Color accent,
    Color dim,
    bool isImperial,
  ) {
    final exerciseName = ex['exercise_name'] as String? ?? '';
    final pr = widget.prDetails[exerciseName];
    return frostedGlassCard(
      context,
      color: appColor,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.width(context, 16),
        vertical: Responsive.height(context, 14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  exerciseName,
                  style: GoogleFonts.manrope(
                    color: onTheme(appColor),
                    fontSize: Responsive.font(context, 14),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (pr != null) ...[
                SizedBox(width: Responsive.width(context, 8)),
                Builder(
                  builder: (context) {
                    final weightPR = pr['weightPR'] as bool;
                    final repsPR = pr['repsPR'] as bool;
                    // label describes exactly what kind of PR was hit
                    final label = (weightPR && repsPR)
                        ? 'Weight + Reps PR'
                        : weightPR
                        ? 'Weight PR'
                        : 'Reps PR';
                    return Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.width(context, 7),
                        vertical: Responsive.height(context, 3),
                      ),
                      decoration: BoxDecoration(
                        color: appColor.withAlpha(60),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: cardColors(appColor).border,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        label,
                        style: GoogleFonts.manrope(
                          color: onTheme(appColor),
                          fontSize: Responsive.font(context, 10),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
          SizedBox(height: Responsive.height(context, 8)),
          for (final s in ex['sets'] as List) ...[
            _buildSetRow(context, s as Map, accent, dim, isImperial),
            SizedBox(height: Responsive.height(context, 4)),
          ],
        ],
      ),
    );
  }

  Widget _buildSetRow(
    BuildContext context,
    Map set,
    Color accent,
    Color dim,
    bool isImperial,
  ) {
    final setNum = set['set_number'] as int? ?? 0;
    final reps = set['reps'] as int?;
    final weightKg = (set['weight_kg'] as num?)?.toDouble();
    final weightDisplay = weightKg != null
        ? isImperial
              ? '${UnitConverter.displayWeight(weightKg, imperial: true)} lbs'
              : '${weightKg.toStringAsFixed(1)} kg'
        : null;
    return Row(
      children: [
        SizedBox(
          width: Responsive.width(context, 28),
          child: Text(
            '$setNum',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              color: onTheme(appColor).withAlpha(140),
              fontSize: Responsive.font(context, 12),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(width: Responsive.width(context, 12)),
        if (reps != null)
          Text(
            '$reps reps',
            style: GoogleFonts.manrope(
              color: onTheme(appColor),
              fontSize: Responsive.font(context, 13),
              fontWeight: FontWeight.w600,
            ),
          ),
        if (reps != null && weightDisplay != null)
          Text(
            ' x ',
            style: GoogleFonts.manrope(
              color: onTheme(appColor).withAlpha(140),
              fontSize: Responsive.font(context, 13),
            ),
          ),
        if (weightDisplay != null)
          Text(
            weightDisplay,
            style: GoogleFonts.manrope(
              color: onTheme(appColor),
              fontSize: Responsive.font(context, 13),
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }

  Widget _muscleChip(
    BuildContext context,
    String label,
    Color accent,
    Color appColor, {
    required bool primary,
  }) {
    if (primary) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.width(context, 12),
          vertical: Responsive.height(context, 6),
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              lightenColor(appColor, 0.38),
              lightenColor(appColor, 0.22),
              lightenColor(appColor, 0.06),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            color: onTheme(appColor),
            fontSize: Responsive.font(context, 12),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.width(context, 12),
        vertical: Responsive.height(context, 6),
      ),
      decoration: BoxDecoration(
        color: cardColors(appColor).iconBox,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardColors(appColor).border, width: 1),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          color: onTheme(appColor),
          fontSize: Responsive.font(context, 12),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _statCell(
    BuildContext context,
    Color accent,
    Color dim,
    String value,
    String label,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.manrope(
            color: onTheme(appColor),
            fontSize: Responsive.font(context, 18),
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.manrope(
            color: onTheme(appColor).withAlpha(140),
            fontSize: Responsive.font(context, 11),
          ),
        ),
      ],
    );
  }

  Widget _divider(BuildContext context) => Container(
    width: 1,
    height: Responsive.height(context, 32),
    color: onTheme(appColor).withAlpha(120),
  );
}
