import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/providers/user_data_provider.dart';
import '../providers/workout_provider.dart';
import '/services/user_data_manager.dart' show defaultAppColor;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart' hide ShimmerEffect;
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import '/globals.dart';
import '/utility/responsive.dart';
import 'exercise_picker_screen.dart';
import 'starfield_background.dart';

class CreateRoutineScreen extends ConsumerStatefulWidget {
  const CreateRoutineScreen({super.key});

  @override
  ConsumerState<CreateRoutineScreen> createState() =>
      _CreateRoutineScreenState();
}

class _CreateRoutineScreenState extends ConsumerState<CreateRoutineScreen>
    with SingleTickerProviderStateMixin {
  Color get appColor => ref.watch(
    userDataProvider.select((s) => s.value?.appColor ?? defaultAppColor),
  );

  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final List<Map<String, dynamic>> _exercises = [];
  bool _reordering = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseScale = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
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
          Divider(
            color: Colors.white.withAlpha(120),
            height: 1,
            thickness: 1.5,
          ),
          menuItem(Icons.swap_vert_rounded, 'Reorder', 'reorder'),
          Divider(
            color: Colors.white.withAlpha(120),
            height: 1,
            thickness: 1.5,
          ),
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
        appColor: appColor,
        title: 'Name required',
        content: Text(
          'Give your routine a name before saving.',
          style: GoogleFonts.manrope(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            child: Text('Dismiss', style: dialogButtonStyle()),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              _openRoutineDetails();
            },
            child: Text('Set Name', style: dialogButtonStyle(confirm: true)),
          ),
        ],
      );
      return;
    }
    if (_exercises.isEmpty) {
      showFrostedAlertDialog<void>(
        context: context,
        appColor: appColor,
        title: 'No exercises',
        content: Text(
          'Add at least one exercise before saving.',
          style: GoogleFonts.manrope(color: Colors.white),
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

      final templateId = await ref
          .read(workoutProvider.notifier)
          .createRoutine(
            name: name,
            exercises: exercises,
            estimatedDurationMinutes: estimatedMinutes,
          );
      if (!mounted) return;
      if (templateId != null) {
        logAnalyticsEvent(
          'routine_created',
          parameters: {'exercise_count': exercises.length},
        );
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
    final accent = onTheme(appColor);
    final dim = onTheme(appColor);

    return Container(
      decoration: BoxDecoration(gradient: buildThemeGradient(appColor)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Material(
          color: Colors.transparent,
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(context, accent, dim),
                if (_exercises.isEmpty && !_reordering)
                  Expanded(
                    child: StarfieldBackground(
                      color: onTheme(appColor),
                      child: Center(
                        child: _buildEmptyState(context, accent, dim),
                      ),
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
                      color: appColor.withAlpha(60),
                      child: Text(
                        'Done Reordering',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          color: onTheme(appColor),
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

  Future<void> _openRoutineDetails() async {
    final tempName = TextEditingController(text: _nameController.text);
    final tempDuration = TextEditingController(text: _durationController.text);
    await showFrostedDialog<void>(
      context: context,
      appColor: appColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Routine Details',
            style: GoogleFonts.manrope(
              color: Colors.white,
              fontSize: Responsive.font(context, 17),
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: Responsive.height(context, 20)),
          TextField(
            controller: tempName,
            autofocus: true,
            maxLength: 40,
            style: GoogleFonts.manrope(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Routine Name',
              labelStyle: GoogleFonts.manrope(color: Colors.white),
              counterStyle: GoogleFonts.manrope(
                color: Colors.white,
                fontSize: Responsive.font(context, 10),
              ),
              hintText: 'e.g. Push Day',
              hintStyle: GoogleFonts.manrope(color: Colors.white),
              filled: true,
              fillColor: Colors.white.withAlpha(15),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  Responsive.scale(context, 14),
                ),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  Responsive.scale(context, 14),
                ),
                borderSide: BorderSide(color: Colors.white.withAlpha(60)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  Responsive.scale(context, 14),
                ),
                borderSide: const BorderSide(color: Colors.white, width: 1.5),
              ),
              contentPadding: EdgeInsets.symmetric(
                vertical: Responsive.height(context, 16),
                horizontal: Responsive.width(context, 16),
              ),
            ),
            cursorColor: Colors.white,
          ),
          SizedBox(height: Responsive.height(context, 12)),
          TextField(
            controller: tempDuration,
            keyboardType: TextInputType.number,
            maxLength: 3,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: GoogleFonts.manrope(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Est. Duration (min)',
              labelStyle: GoogleFonts.manrope(color: Colors.white),
              counterText: '',
              hintText: '0',
              hintStyle: GoogleFonts.manrope(color: Colors.white),
              filled: true,
              fillColor: Colors.white.withAlpha(15),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  Responsive.scale(context, 14),
                ),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  Responsive.scale(context, 14),
                ),
                borderSide: BorderSide(color: Colors.white.withAlpha(60)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  Responsive.scale(context, 14),
                ),
                borderSide: const BorderSide(color: Colors.white, width: 1.5),
              ),
              contentPadding: EdgeInsets.symmetric(
                vertical: Responsive.height(context, 16),
                horizontal: Responsive.width(context, 16),
              ),
            ),
            cursorColor: Colors.white,
          ),
          SizedBox(height: Responsive.height(context, 24)),
          gradientButton(
            context,
            label: 'Done',
            color: appColor,
            onTap: () {
              _nameController.text = tempName.text;
              _durationController.text = tempDuration.text;
              Navigator.of(context, rootNavigator: true).pop();
            },
          ),
          SizedBox(height: Responsive.height(context, 10)),
          GestureDetector(
            onTap: () => Navigator.of(context, rootNavigator: true).pop(),
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: Responsive.height(context, 6),
              ),
              child: Text(
                'Cancel',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  color: Colors.white,
                  fontSize: Responsive.font(context, 13),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    tempName.dispose();
    tempDuration.dispose();
    if (mounted) setState(() {});
  }

  Widget _buildHeader(BuildContext context, Color accent, Color dim) {
    final hPad = Responsive.centeredHorizontalPadding(context, 20);
    return Padding(
      padding: EdgeInsets.only(
        left: hPad,
        right: hPad,
        top: Responsive.height(context, 14),
        bottom: Responsive.height(context, 14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // back chevron
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              padding: EdgeInsets.all(Responsive.scale(context, 10)),
              margin: EdgeInsets.only(right: Responsive.width(context, 10)),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cardColors(appColor).iconBox,
                border: Border.all(
                  color: cardColors(appColor).iconBorder,
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: cardColors(appColor).onCard,
                size: Responsive.font(context, 16),
              ),
            ),
          ),
          const Spacer(),
          // save button
          gradientButton(
            context,
            label: 'Save',
            color: appColor,
            icon: Icons.check,
            fullWidth: false,
            loading: _saving,
            onTap: _saveRoutine,
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
        ShimmerWidget(
          accent: onTheme(appColor),
          child: AnimatedBuilder(
            animation: _pulseScale,
            builder: (context, child) =>
                Transform.scale(scale: _pulseScale.value, child: child),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedNote02,
              color: onTheme(appColor),
              size: Responsive.scale(context, 54),
            ),
          ),
        ),
        SizedBox(height: Responsive.height(context, 16)),
        Text(
          'Add an Exercise',
          style: GoogleFonts.manrope(
            color: onTheme(appColor),
            fontSize: Responsive.font(context, 16),
            fontWeight: FontWeight.w600,
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
                color: appColor,
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
                                color: accent,
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
    final hPad = Responsive.centeredHorizontalPadding(context, 20);
    final gradDeco = BoxDecoration(
      borderRadius: BorderRadius.circular(Responsive.scale(context, 14)),
      gradient: LinearGradient(
        colors: [
          lightenColor(appColor, 0.40),
          lightenColor(appColor, 0.25),
          lightenColor(appColor, 0.08),
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
      border: Border.all(color: cardColors(appColor).iconBorder, width: 1.5),
    );

    Widget pill(Widget child, VoidCallback onTap) => Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: Responsive.height(context, 15),
          ),
          decoration: gradDeco,
          child: child,
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(
        left: hPad,
        right: hPad,
        top: Responsive.height(context, 14),
        bottom: Responsive.height(context, 22),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                pill(
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        color: onTheme(appColor),
                        size: Responsive.scale(context, 16),
                      ),
                      SizedBox(width: Responsive.width(context, 6)),
                      Text(
                        'Details',
                        style: GoogleFonts.manrope(
                          color: onTheme(appColor),
                          fontSize: Responsive.font(context, 14),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  _openRoutineDetails,
                ),
                SizedBox(width: Responsive.width(context, 10)),
                pill(
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_rounded,
                        color: onTheme(appColor),
                        size: Responsive.scale(context, 20),
                      ),
                      SizedBox(width: Responsive.width(context, 6)),
                      Text(
                        'Add Exercise',
                        style: GoogleFonts.manrope(
                          color: onTheme(appColor),
                          fontSize: Responsive.font(context, 14),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  _openExercisePicker,
                ),
              ],
            ),
          ),
          SizedBox(height: Responsive.height(context, 12)),
          GestureDetector(
            onTap: () async {
              final confirmed = await showFrostedAlertDialog<bool>(
                context: context,
                appColor: appColor,
                title: 'Discard routine?',
                content: Text(
                  'You will lose all progress on this routine.',
                  style: GoogleFonts.manrope(color: Colors.white),
                ),
                actions: [
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context, rootNavigator: true).pop(false),
                    child: Text('Keep editing', style: dialogButtonStyle()),
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context, rootNavigator: true).pop(true),
                    child: Text(
                      'Discard',
                      style: dialogButtonStyle(confirm: true),
                    ),
                  ),
                ],
              );
              if ((confirmed ?? false) && context.mounted) context.pop();
            },
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                vertical: Responsive.height(context, 12),
              ),
              decoration: BoxDecoration(
                color: cardColors(appColor).iconBox,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: cardColors(appColor).border,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.delete_outline_rounded,
                    color: onTheme(appColor),
                    size: Responsive.scale(context, 15),
                  ),
                  SizedBox(width: Responsive.width(context, 5)),
                  Text(
                    'Discard',
                    style: GoogleFonts.manrope(
                      color: onTheme(appColor),
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
    );
  }
}
