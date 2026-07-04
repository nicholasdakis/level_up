import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import '/globals.dart';
import '/utility/responsive.dart';
import '/utility/unit_converter.dart';

class FinishWorkoutScreen extends StatefulWidget {
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
  State<FinishWorkoutScreen> createState() => _FinishWorkoutScreenState();
}

class _FinishWorkoutScreenState extends State<FinishWorkoutScreen> {
  late final VoidCallback _colorListener;

  @override
  void initState() {
    super.initState();
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
    final accent = lightenColor(appColorNotifier.value, 0.45);
    final dim = lightenColor(appColorNotifier.value, 0.35);
    final dimmer = lightenColor(appColorNotifier.value, 0.30);
    final bool isImperial = UnitConverter.isImperial;
    final hPad = Responsive.centeredHorizontalPadding(context, 20);

    final volDisplay = isImperial
        ? '${UnitConverter.displayWeight(widget.totalVolumeKg, imperial: true)} lbs'
        : '${widget.totalVolumeKg.toStringAsFixed(0)} kg';

    return Container(
      decoration: BoxDecoration(gradient: buildThemeGradient()),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // header
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                          color: accent,
                          size: Responsive.scale(context, 44),
                        ),
                        SizedBox(height: Responsive.height(context, 10)),
                        Text(
                          'Workout Complete',
                          style: GoogleFonts.manrope(
                            color: accent,
                            fontSize: Responsive.font(context, 26),
                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        SizedBox(height: Responsive.height(context, 10)),
                        if (widget.xpGained > 0)
                          Text(
                            '+${widget.xpGained} XP',
                            style: GoogleFonts.manrope(
                              color: dim,
                              fontSize: Responsive.font(context, 16),
                              fontWeight: FontWeight.w700,
                            ),
                          ),

                        SizedBox(height: Responsive.height(context, 20)),

                        // stat row
                        frostedGlassCard(
                          context,
                          padding: EdgeInsets.symmetric(
                            horizontal: Responsive.width(context, 20),
                            vertical: Responsive.height(context, 18),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
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
                        ),

                        SizedBox(height: Responsive.height(context, 24)),

                        // exercise breakdown
                        Text(
                          'EXERCISES',
                          style: GoogleFonts.manrope(
                            color: dimmer,
                            fontSize: Responsive.font(context, 11),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(height: Responsive.height(context, 10)),

                        for (final ex in widget.exercises) ...[
                          frostedGlassCard(
                            context,
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
                                        ex['exercise_name'] as String? ?? '',
                                        style: GoogleFonts.manrope(
                                          color: accent,
                                          fontSize: Responsive.font(
                                            context,
                                            14,
                                          ),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    if (widget.prDetails.containsKey(
                                      ex['exercise_name'] as String? ?? '',
                                    )) ...[
                                      SizedBox(
                                        width: Responsive.width(context, 8),
                                      ),
                                      Builder(
                                        builder: (context) {
                                          final pr =
                                              widget
                                                  .prDetails[ex['exercise_name']
                                                      as String? ??
                                                  '']!;
                                          final weightPR =
                                              pr['weightPR'] as bool;
                                          final repsPR = pr['repsPR'] as bool;
                                          // label describes exactly what kind of PR was hit
                                          final label = (weightPR && repsPR)
                                              ? 'Weight + Reps PR'
                                              : weightPR
                                              ? 'Weight PR'
                                              : 'Reps PR';
                                          return Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: Responsive.width(
                                                context,
                                                7,
                                              ),
                                              vertical: Responsive.height(
                                                context,
                                                3,
                                              ),
                                            ),
                                            decoration: BoxDecoration(
                                              color: appColorNotifier.value
                                                  .withAlpha(60),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: accent.withAlpha(120),
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              label,
                                              style: GoogleFonts.manrope(
                                                color: accent,
                                                fontSize: Responsive.font(
                                                  context,
                                                  10,
                                                ),
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
                                  _buildSetRow(
                                    context,
                                    s as Map,
                                    accent,
                                    dim,
                                    isImperial,
                                  ),
                                  SizedBox(
                                    height: Responsive.height(context, 4),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          SizedBox(height: Responsive.height(context, 10)),
                        ],

                        SizedBox(height: Responsive.height(context, 8)),
                      ],
                    ),
                  ),
                ),
              ),
              // done button pinned to bottom
              Padding(
                padding: EdgeInsets.fromLTRB(
                  hPad,
                  Responsive.height(context, 10),
                  hPad,
                  Responsive.height(context, 24),
                ),
                child: GestureDetector(
                  onTap: () => context.go('/workout'),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      vertical: Responsive.height(context, 16),
                    ),
                    decoration: BoxDecoration(
                      color: appColorNotifier.value.withAlpha(100),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: appColorNotifier.value.withAlpha(180),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      'Done',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        color: accent,
                        fontSize: Responsive.font(context, 15),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
              color: Colors.white38,
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
              color: accent,
              fontSize: Responsive.font(context, 13),
              fontWeight: FontWeight.w600,
            ),
          ),
        if (reps != null && weightDisplay != null)
          Text(
            ' × ',
            style: GoogleFonts.manrope(
              color: Colors.white24,
              fontSize: Responsive.font(context, 13),
            ),
          ),
        if (weightDisplay != null)
          Text(
            weightDisplay,
            style: GoogleFonts.manrope(
              color: accent,
              fontSize: Responsive.font(context, 13),
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
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
            color: accent,
            fontSize: Responsive.font(context, 16),
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.manrope(
            color: dim,
            fontSize: Responsive.font(context, 11),
          ),
        ),
      ],
    );
  }

  Widget _divider(BuildContext context) => Container(
    width: 1,
    height: Responsive.height(context, 32),
    color: Colors.white.withAlpha(15),
  );
}
