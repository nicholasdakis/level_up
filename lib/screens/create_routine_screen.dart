import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart' hide ShimmerEffect;
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import '/globals.dart';
import '/utility/responsive.dart';
import 'exercise_picker_screen.dart';

class CreateRoutineScreen extends StatefulWidget {
  const CreateRoutineScreen({super.key});

  @override
  State<CreateRoutineScreen> createState() => _CreateRoutineScreenState();
}

class _CreateRoutineScreenState extends State<CreateRoutineScreen> {
  late final VoidCallback _colorListener;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final List<Map<String, dynamic>> _exercises = [];
  bool _reordering = false;
  bool _saving = false;

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
    _nameController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  // strips trailing parenthetical suffixes from built-in exercise names e.g. "Box Jump (Multiple Response)" -> "Box Jump"
  String _cleanName(String raw) =>
      raw.replaceAll(RegExp(r'\s*\(.*?\)\s*$'), '').trim();

  void _removeExercise(int exIndex) {
    setState(() => _exercises.removeAt(exIndex));
  }

  // three-dot menu per exercise card, returns a string action key
  void _showExerciseMenu(
    BuildContext context,
    int exIndex,
    Color accent,
    Color dim,
  ) async {
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

    final name = _cleanName(_exercises[exIndex]['name'] as String? ?? '');
    final result = await showFrostedDialog<String>(
      context: context,
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
          Divider(color: dim.withAlpha(40), height: 1),
          menuItem(Icons.swap_vert_rounded, 'Reorder', 'reorder'),
          Divider(color: dim.withAlpha(40), height: 1),
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
    if (result == 'reorder') {
      HapticFeedback.mediumImpact();
      setState(() => _reordering = true);
    } else if (result == 'remove') {
      _removeExercise(exIndex);
    }
  }

  // slides up the exercise picker as a full-screen page so the user can search and tap to add
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
                    'default_sets': 3,
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

  // validates name and exercise list then posts to /create_routine
  Future<void> _saveRoutine() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showFrostedAlertDialog<void>(
        context: context,
        title: 'Name required',
        content: Text(
          'Give your routine a name before saving.',
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
    if (_exercises.isEmpty) {
      showFrostedAlertDialog<void>(
        context: context,
        title: 'No exercises',
        content: Text(
          'Add at least one exercise before saving.',
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

    setState(() => _saving = true);
    try {
      final exercises = _exercises
          .map(
            (ex) => {
              'exercise_id': ex['id'],
              'exercise_name': _cleanName(ex['name'] as String? ?? ''),
              'exercise_order': _exercises.indexOf(ex),
              'default_sets': ex['default_sets'] as int? ?? 3,
            },
          )
          .toList();
      final estimatedMinutes = int.tryParse(_durationController.text.trim());

      final ok = await userManager.createRoutine(
        name: name,
        exercises: exercises,
        estimatedDurationMinutes: estimatedMinutes,
      );
      if (!mounted) return;
      if (ok) {
        // bump notifier so the workout dashboard refreshes its routines list
        workoutLogNotifier.value++;
        context.pop();
      } else {
        setState(() => _saving = false);
        _showSnackbar('Failed to save routine. Try again.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        _showSnackbar('No connection. Routine not saved.');
      }
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

  @override
  Widget build(BuildContext context) {
    final accent = lightenColor(appColorNotifier.value, 0.45);
    final dim = lightenColor(appColorNotifier.value, 0.35);

    return Container(
      decoration: BoxDecoration(gradient: buildThemeGradient()),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Material(
          color: Colors.transparent,
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(context, accent, dim),
                Container(height: 1, color: dim.withAlpha(40)),
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
                                  final ex = _exercises.removeAt(oldIndex);
                                  _exercises.insert(newIndex, ex);
                                });
                              }
                            : (oldI, newI) {},
                        children: [
                          for (int i = 0; i < _exercises.length; i++)
                            _buildExerciseCard(
                              context,
                              i,
                              accent,
                              dim,
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
                      color: appColorNotifier.value.withAlpha(60),
                      child: Text(
                        'Done Reordering',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          color: lightenColor(appColorNotifier.value, 0.45),
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
    );
  }

  Widget _buildHeader(BuildContext context, Color accent, Color dim) {
    final hPad = Responsive.centeredHorizontalPadding(context, 20);
    final dimmer = lightenColor(appColorNotifier.value, 0.30);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: hPad,
        vertical: Responsive.height(context, 16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _nameController,
                  maxLength: 40,
                  style: GoogleFonts.manrope(
                    color: accent,
                    fontSize: Responsive.font(context, 24),
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: 'Routine Name',
                    hintStyle: GoogleFonts.manrope(
                      color: accent.withAlpha(50),
                      fontSize: Responsive.font(context, 24),
                      fontWeight: FontWeight.w800,
                    ),
                    counterText: '',
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  cursorColor: accent,
                  onChanged: (_) => setState(() {}),
                ),
                SizedBox(height: Responsive.height(context, 6)),
                Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedClock01,
                      color: dimmer,
                      size: Responsive.scale(context, 13),
                    ),
                    SizedBox(width: Responsive.width(context, 5)),
                    IntrinsicWidth(
                      child: TextField(
                        controller: _durationController,
                        keyboardType: TextInputType.number,
                        maxLength: 3,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: GoogleFonts.manrope(
                          color: dim,
                          fontSize: Responsive.font(context, 13),
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          hintText: '0',
                          hintStyle: GoogleFonts.manrope(
                            color: dimmer,
                            fontSize: Responsive.font(context, 13),
                          ),
                          counterText: '',
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        cursorColor: accent,
                      ),
                    ),
                    Text(
                      ' min',
                      style: GoogleFonts.manrope(
                        color: dimmer,
                        fontSize: Responsive.font(context, 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: Responsive.width(context, 12)),
          GestureDetector(
            onTap: _saving ? null : _saveRoutine,
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
              child: _saving
                  ? SizedBox(
                      width: Responsive.scale(context, 14),
                      height: Responsive.scale(context, 14),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: accent,
                      ),
                    )
                  : Text(
                      'Save',
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
          color: dim.withAlpha(80),
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

  Widget _buildExerciseCard(
    BuildContext context,
    int exIndex,
    Color accent,
    Color dim, {
    Key? key,
  }) {
    final ex = _exercises[exIndex];
    final name = _cleanName(ex['name'] as String? ?? '');
    final hPad = Responsive.centeredHorizontalPadding(context, 20);

    final card =
        Padding(
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
                    GestureDetector(
                      onLongPress: () {
                        HapticFeedback.mediumImpact();
                        setState(() => _reordering = true);
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.width(context, 16),
                          vertical: Responsive.height(context, 14),
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
                                color: accent.withAlpha(160),
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
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: _reordering
                                  ? Icon(
                                      Icons.drag_handle_rounded,
                                      key: const ValueKey('drag'),
                                      color: dim,
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
                                            color: dim,
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
                    // show primary muscle below the name if the exercise has one
                    if ((ex['primary_muscle'] as String? ?? '').isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(
                          left: Responsive.width(context, 29),
                          right: Responsive.width(context, 16),
                          bottom: Responsive.height(context, 6),
                        ),
                        child: Text(
                          _capitalize(ex['primary_muscle'] as String),
                          style: GoogleFonts.manrope(
                            color: dim,
                            fontSize: Responsive.font(context, 11),
                          ),
                        ),
                      ),
                    // set count stepper
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: Responsive.height(context, 14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Sets',
                            style: GoogleFonts.manrope(
                              color: dim,
                              fontSize: Responsive.font(context, 13),
                            ),
                          ),
                          SizedBox(width: Responsive.width(context, 12)),
                          GestureDetector(
                            onTap: () {
                              final current = ex['default_sets'] as int? ?? 3;
                              if (current > 1) {
                                setState(
                                  () => ex['default_sets'] = current - 1,
                                );
                              }
                            },
                            child: Icon(
                              Icons.remove_rounded,
                              color: dim,
                              size: Responsive.scale(context, 20),
                            ),
                          ),
                          SizedBox(width: Responsive.width(context, 12)),
                          Text(
                            '${ex['default_sets'] as int? ?? 3}',
                            style: GoogleFonts.manrope(
                              color: accent,
                              fontSize: Responsive.font(context, 18),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: Responsive.width(context, 12)),
                          GestureDetector(
                            onTap: () {
                              final current = ex['default_sets'] as int? ?? 3;
                              if (current < 10) {
                                setState(
                                  () => ex['default_sets'] = current + 1,
                                );
                              }
                            },
                            child: Icon(
                              Icons.add_rounded,
                              color: dim,
                              size: Responsive.scale(context, 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Widget _buildBottomBar(BuildContext context, Color accent, Color dim) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: dim.withAlpha(40), width: 1)),
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
                color: lightenColor(appColorNotifier.value, 0.1).withAlpha(40),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: lightenColor(
                    appColorNotifier.value,
                    0.35,
                  ).withAlpha(120),
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
            onTap: () => context.pop(),
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: Responsive.height(context, 4),
              ),
              child: Text(
                'Cancel',
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
