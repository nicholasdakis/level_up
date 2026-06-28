import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import '/globals.dart';
import '/utility/responsive.dart';
import '/utility/unit_converter.dart';

class ActiveWorkoutScreen extends StatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  late final VoidCallback _colorListener;
  late final Stopwatch _stopwatch;
  late final Timer _timer;

  // placeholder exercise list until exercise picker is wired up
  final List<Map<String, dynamic>> _exercises = [];

  @override
  void initState() {
    super.initState();
    _colorListener = () {
      if (mounted) setState(() {});
    };
    appColorNotifier.addListener(_colorListener);
    _stopwatch = Stopwatch()..start();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    appColorNotifier.removeListener(_colorListener);
    _timer.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  String get _durationLabel {
    final s = _stopwatch.elapsed;
    final h = s.inHours;
    final m = s.inMinutes % 60;
    final sec = s.inSeconds % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  int get _totalSets {
    int count = 0;
    for (final ex in _exercises) {
      count += (ex['sets'] as List).length as int;
    }
    return count;
  }

  double get _totalVolumeKg {
    double vol = 0;
    for (final ex in _exercises) {
      for (final set in ex['sets'] as List) {
        final reps = (set['reps'] as int? ?? 0);
        final weight = (set['weight_kg'] as double? ?? 0.0);
        vol += reps * weight;
      }
    }
    return vol;
  }

  Future<bool> _confirmDiscard() async {
    final result = await showFrostedAlertDialog<bool>(
      context: context,
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
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
          child: Text('Discard', style: dialogButtonStyle(confirm: true)),
        ),
      ],
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final accent = lightenColor(appColorNotifier.value, 0.45);
    final dim = lightenColor(appColorNotifier.value, 0.35);
    final bool isImperial = UnitConverter.isImperial;
    final double vol = _totalVolumeKg;
    final String volDisplay = isImperial
        ? '${UnitConverter.displayWeight(vol, imperial: true)} lbs'
        : '${vol.toStringAsFixed(0)} kg';

    return Container(
      decoration: BoxDecoration(gradient: buildThemeGradient()),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // header
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.centeredHorizontalPadding(context, 20),
                  vertical: Responsive.height(context, 16),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        if (await _confirmDiscard())
                          Navigator.of(context).pop();
                      },
                      child: Text(
                        'Discard',
                        style: GoogleFonts.manrope(
                          color: lightenColor(appColorNotifier.value, 0.35),
                          fontSize: Responsive.font(context, 14),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _durationLabel,
                      style: GoogleFonts.manrope(
                        color: accent,
                        fontSize: Responsive.font(context, 16),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        // TODO: finish and save workout
                      },
                      child: Text(
                        'Finish',
                        style: GoogleFonts.manrope(
                          color: accent,
                          fontSize: Responsive.font(context, 14),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // stats row
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.centeredHorizontalPadding(context, 20),
                ),
                child: frostedGlassCard(
                  context,
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.width(context, 16),
                    vertical: Responsive.height(context, 14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statCell(accent, dim, volDisplay, 'Volume'),
                      _divider(),
                      _statCell(accent, dim, '$_totalSets', 'Sets'),
                    ],
                  ),
                ),
              ),

              SizedBox(height: Responsive.height(context, 16)),

              // exercise list
              Expanded(
                child: ScrollConfiguration(
                  behavior: NoGlowScrollBehavior(),
                  child: ListView(
                    padding: EdgeInsets.only(
                      left: Responsive.centeredHorizontalPadding(context, 20),
                      right: Responsive.centeredHorizontalPadding(context, 20),
                      bottom: Responsive.height(context, 24),
                    ),
                    children: [
                      if (_exercises.isEmpty) ...[
                        SizedBox(height: Responsive.height(context, 40)),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              HugeIcon(
                                icon: HugeIcons.strokeRoundedDumbbell01,
                                color: Colors.white24,
                                size: Responsive.scale(context, 40),
                              ),
                              SizedBox(height: Responsive.height(context, 12)),
                              Text(
                                'No exercises yet',
                                style: GoogleFonts.manrope(
                                  color: accent,
                                  fontSize: Responsive.font(context, 14),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: Responsive.height(context, 4)),
                              Text(
                                'Tap "Add Exercise" to get started',
                                style: GoogleFonts.manrope(
                                  color: dim,
                                  fontSize: Responsive.font(context, 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: Responsive.height(context, 32)),
                      ] else ...[
                        for (int i = 0; i < _exercises.length; i++) ...[
                          frostedGlassCard(
                            context,
                            padding: EdgeInsets.symmetric(
                              horizontal: Responsive.width(context, 16),
                              vertical: Responsive.height(context, 14),
                            ),
                            child: Text(
                              _exercises[i]['name'] as String,
                              style: GoogleFonts.manrope(
                                color: accent,
                                fontSize: Responsive.font(context, 14),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(height: Responsive.height(context, 12)),
                        ],
                      ],
                      // add exercise button always visible at bottom of list
                      GestureDetector(
                        onTap: () {
                          // TODO: open exercise picker
                        },
                        child: frostedGlassCard(
                          context,
                          padding: EdgeInsets.symmetric(
                            vertical: Responsive.height(context, 16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              HugeIcon(
                                icon: HugeIcons.strokeRoundedAddCircle,
                                color: accent,
                                size: Responsive.scale(context, 20),
                              ),
                              SizedBox(width: Responsive.width(context, 8)),
                              Text(
                                'Add Exercise',
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCell(Color accent, Color dim, String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.manrope(
            color: accent,
            fontSize: Responsive.font(context, 18),
            fontWeight: FontWeight.w700,
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

  Widget _divider() => Container(
    width: 1,
    height: Responsive.height(context, 30),
    color: Colors.white12,
  );
}
