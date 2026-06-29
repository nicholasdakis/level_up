import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import '/globals.dart';
import '/utility/responsive.dart';
import '/utility/unit_converter.dart';
import 'exercise_picker_screen.dart';

class ActiveWorkoutScreen extends StatefulWidget {
  final Map<String, dynamic>?
  routine; // null = empty session, non-null = from routine

  const ActiveWorkoutScreen({super.key, this.routine});

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  late final VoidCallback _colorListener;
  late final Stopwatch _stopwatch;
  late final Timer _timer;

  late final List<Map<String, dynamic>> _exercises;

  // controllers keyed by "exIndex_setIndex_field" so they survive rebuilds
  final Map<String, TextEditingController> _controllers = {};

  // which sets are checked off
  final Map<String, bool> _checked = {};

  // rest timer state
  int? _restSeconds;
  Timer? _restTimer;
  static const int _restDuration = 90;

  TextEditingController _ctrl(int ex, int set, String field) {
    final key = '${ex}_${set}_$field';
    if (!_controllers.containsKey(key)) {
      final setMap = (_exercises[ex]['sets'] as List)[set] as Map;
      final initial = field == 'reps'
          ? (setMap['reps']?.toString() ?? '')
          : (setMap['weight_kg']?.toString() ?? '');
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
    _colorListener = () {
      if (mounted) setState(() {});
    };
    appColorNotifier.addListener(_colorListener);
    // pre-fill exercises from routine if provided
    if (widget.routine != null) {
      final templateExercises =
          widget.routine!['exercises'] as List<dynamic>? ?? [];
      _exercises = templateExercises.map((e) {
        final ex = Map<String, dynamic>.from(e as Map);
        final defaultSets = ex['default_sets'] as int? ?? 3;
        return {
          ...ex,
          'sets': List.generate(
            defaultSets,
            (_) => {
              'reps': ex['default_reps'],
              'weight_kg': ex['default_weight_kg'],
            },
          ),
        };
      }).toList();
    } else {
      _exercises = [];
    }
    _stopwatch = Stopwatch()..start();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    appColorNotifier.removeListener(_colorListener);
    _timer.cancel();
    _restTimer?.cancel();
    _stopwatch.stop();
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
        vol +=
            (set['reps'] as int? ?? 0) * (set['weight_kg'] as double? ?? 0.0);
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

  void _openExercisePicker() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ExercisePickerScreen(
              onExerciseSelected: (ex) {
                setState(() {
                  _exercises.add({
                    ...ex,
                    'sets': [
                      {'reps': null, 'weight_kg': null},
                    ],
                  });
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

  // strip trailing parenthetical suffixes from seeded data e.g. "Box Jump (Multiple Response)" -> "Box Jump"
  String _cleanName(String raw) =>
      raw.replaceAll(RegExp(r'\s*\(.*?\)\s*$'), '').trim();

  // borderless bare input, no fill, no border, just the number
  InputDecoration _fieldDec(String hint) => InputDecoration(
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    hintText: hint,
    hintStyle: GoogleFonts.manrope(
      color: Colors.white.withAlpha(40),
      fontSize: Responsive.font(context, 15),
    ),
    isDense: true,
    contentPadding: EdgeInsets.zero,
  );

  @override
  Widget build(BuildContext context) {
    final bool isImperial = UnitConverter.isImperial;
    final double vol = _totalVolumeKg;
    final String volDisplay = isImperial
        ? UnitConverter.displayWeight(vol, imperial: true)
        : vol.toStringAsFixed(0);
    final String volUnit = isImperial ? 'lbs' : 'kg';

    // ensure background is dark enough for readable text, only darken if the color is mid/light
    final hsl = HSLColor.fromColor(appColorNotifier.value);
    final bg = hsl.lightness > 0.25
        ? darkenColor(
            appColorNotifier.value,
            (hsl.lightness - 0.22).clamp(0.0, 0.3),
          )
        : appColorNotifier.value;

    // derive text colors from bg so they're always readable above the actual background
    final accent = lightenColor(bg, 0.45);
    final dim = lightenColor(bg, 0.35);
    return Container(
      decoration: BoxDecoration(color: bg),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(context, accent, dim, volDisplay, volUnit),
              Container(height: 1, color: Colors.white.withAlpha(15)),
              Expanded(
                child: ScrollConfiguration(
                  behavior: NoGlowScrollBehavior(),
                  child: ListView(
                    padding: EdgeInsets.only(
                      bottom: Responsive.height(context, 8),
                    ),
                    children: [
                      if (_exercises.isEmpty)
                        _buildEmptyState(context, accent, dim)
                      else
                        for (int i = 0; i < _exercises.length; i++)
                          _buildExerciseSection(
                            context,
                            i,
                            accent,
                            dim,
                            isImperial,
                          ),
                    ],
                  ),
                ),
              ),
              _buildBottomBar(context, accent, dim),
            ],
          ),
        ),
      ),
    );
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
          Expanded(
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
                if (widget.routine != null)
                  Text(
                    widget.routine!['name'] as String? ?? '',
                    style: GoogleFonts.manrope(
                      color: dim,
                      fontSize: Responsive.font(context, 11),
                    ),
                  ),
              ],
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
            onTap: () {
              /* TODO: finish and save workout */
            },
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.width(context, 18),
                vertical: Responsive.height(context, 10),
              ),
              decoration: BoxDecoration(
                color: appColorNotifier.value.withAlpha(70),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: appColorNotifier.value.withAlpha(150),
                  width: 1.5,
                ),
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
    return Padding(
      padding: EdgeInsets.only(top: Responsive.height(context, 80)),
      child: Column(
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
      ),
    );
  }

  Widget _buildExerciseSection(
    BuildContext context,
    int exIndex,
    Color accent,
    Color dim,
    bool isImperial,
  ) {
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

    return Padding(
      padding: EdgeInsets.only(
        left: hPad,
        right: hPad,
        top: Responsive.height(context, 12),
        bottom: Responsive.height(context, 4),
      ),
      child: frostedGlassCard(
        context,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // exercise name, long press to remove
            GestureDetector(
              onLongPress: () {
                HapticFeedback.mediumImpact();
                showFrostedAlertDialog<bool>(
                  context: context,
                  title: 'Remove "$name"?',
                  content: Text(
                    'This exercise and all its sets will be removed.',
                    style: GoogleFonts.manrope(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context, rootNavigator: true).pop(false),
                      child: Text('Cancel', style: dialogButtonStyle()),
                    ),
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context, rootNavigator: true).pop(true),
                      child: Text(
                        'Remove',
                        style: dialogButtonStyle(confirm: true),
                      ),
                    ),
                  ],
                ).then((confirmed) {
                  if (confirmed == true) _removeExercise(exIndex);
                });
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
                    Icon(
                      Icons.more_vert_rounded,
                      color: Colors.white.withAlpha(40),
                      size: Responsive.scale(context, 18),
                    ),
                  ],
                ),
              ),
            ),

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

            // set rows, capped at ~5 visible rows, scrollable beyond that
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
              onTap: () =>
                  setState(() => sets.add({'reps': null, 'weight_kg': null})),
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
        ),
      ),
    );
  }

  Widget _headerCell(
    BuildContext context,
    String label, {
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: GoogleFonts.manrope(
          color: Colors.white.withAlpha(40),
          fontSize: Responsive.font(context, 10),
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _headerExpanded(BuildContext context, String label) {
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: GoogleFonts.manrope(
          color: Colors.white.withAlpha(40),
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

    final rowBg = checked
        ? appColorNotifier.value.withAlpha(28)
        : setIndex.isOdd
        ? Colors.white.withAlpha(4)
        : Colors.transparent;

    final numColor = checked ? accent : Colors.white.withAlpha(220);
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
                color: checked ? accent : Colors.white.withAlpha(50),
                fontSize: Responsive.font(context, 13),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: Responsive.width(context, 12)),
          // previous, dash until history is wired
          Expanded(
            child: Text(
              '—',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: Colors.white.withAlpha(30),
                fontSize: Responsive.font(context, 13),
              ),
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
              cursorColor: accent,
              style: GoogleFonts.manrope(
                color: numColor,
                fontSize: Responsive.font(context, 15),
                fontWeight: numWeight,
              ),
              decoration: _fieldDec('0'),
              onChanged: (v) => set['weight_kg'] = double.tryParse(v),
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
              cursorColor: accent,
              style: GoogleFonts.manrope(
                color: numColor,
                fontSize: Responsive.font(context, 15),
                fontWeight: numWeight,
              ),
              decoration: _fieldDec('0'),
              onChanged: (v) => set['reps'] = int.tryParse(v),
            ),
          ),
          SizedBox(width: Responsive.width(context, 12)),
          // check button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              final nowChecked = !checked;
              setState(() => _checked['${exIndex}_$setIndex'] = nowChecked);
              if (nowChecked) _startRestTimer();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: Responsive.scale(context, 28),
              height: Responsive.scale(context, 28),
              decoration: BoxDecoration(
                color: checked
                    ? appColorNotifier.value.withAlpha(100)
                    : Colors.white.withAlpha(12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.check_rounded,
                size: Responsive.scale(context, 16),
                color: checked ? accent : Colors.white.withAlpha(50),
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
                color: appColorNotifier.value.withAlpha(55),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: appColorNotifier.value.withAlpha(130),
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
          GestureDetector(
            onTap: () async {
              if (await _confirmDiscard()) Navigator.of(context).pop();
            },
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: Responsive.height(context, 4),
              ),
              child: Text(
                'Discard Workout',
                style: GoogleFonts.manrope(
                  color: dim,
                  fontSize: Responsive.font(context, 13),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
