import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/providers/user_data_provider.dart';
import '/providers/workout_provider.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '/globals.dart';
import '/utility/responsive.dart';
import '/services/user_data_manager.dart';

// Equipment options matching the seeded exercises
const _equipmentOptions = [
  'Barbell',
  'Dumbbell',
  'Body Only',
  'Machine',
  'Cable',
  'Kettlebells',
  'Bands',
  'Medicine Ball',
  'Exercise Ball',
  'Foam Roll',
  'E-Z Curl Bar',
  'Other',
];

const _levelOptions = ['Beginner', 'Intermediate', 'Expert'];

// Muscle group options matching the seeded muscle_groups table
const _muscleOptions = [
  'Abdominals',
  'Abductors',
  'Adductors',
  'Biceps',
  'Calves',
  'Chest',
  'Forearms',
  'Glutes',
  'Hamstrings',
  'Lats',
  'Lower Back',
  'Middle Back',
  'Neck',
  'Quadriceps',
  'Shoulders',
  'Traps',
  'Triceps',
];

class ExercisePickerScreen extends ConsumerStatefulWidget {
  final void Function(Map<String, dynamic> exercise) onExerciseSelected;
  final String? replacingExercisePrimaryMuscle;

  const ExercisePickerScreen({
    super.key,
    required this.onExerciseSelected,
    this.replacingExercisePrimaryMuscle,
  });

  @override
  ConsumerState<ExercisePickerScreen> createState() =>
      _ExercisePickerScreenState();
}

class _ExercisePickerScreenState extends ConsumerState<ExercisePickerScreen> {
  Color get appColor => ref.watch(
    userDataProvider.select((s) => s.value?.appColor ?? defaultAppColor),
  );

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> _recentExercises = [];
  List<Map<String, dynamic>> _recommendedExercises = [];
  bool _isLoading = false;
  bool _loadingRecents = true;
  bool _hasSearched = false;
  Set<String> _selectedEquipment = {};
  Set<String> _selectedMuscle = {};
  Set<String> _selectedLevel = {};

  @override
  void initState() {
    super.initState();
    if (!isGuest) {
      _fetchRecentExercises();
      final muscle = widget.replacingExercisePrimaryMuscle;
      if (muscle != null && muscle.isNotEmpty) _fetchRecommended(muscle);
    }
  }

  Future<void> _fetchRecommended(String muscle) async {
    try {
      final response = await authenticatedGet(
        'search_exercises?q=&muscle=${Uri.encodeComponent(muscle.toLowerCase())}&limit=5',
      );
      if (response.statusCode == 200 && mounted) {
        final data = (jsonDecode(response.body) as List<dynamic>)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .take(5)
            .toList();
        setState(() => _recommendedExercises = data);
      }
    } catch (_) {}
  }

  // Three-dot menu for custom exercises, shows Edit and Delete options
  Future<void> _showCustomExerciseMenu(
    BuildContext context,
    Map<String, dynamic> ex,
  ) async {
    final accent = lightenColor(appColor, 0.45);
    final dim = lightenColor(appColor, 0.35);
    await showFrostedDialog(
      context: context,
      appColor: appColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (ex['name'] as String? ?? '')
                .replaceAll(RegExp(r'\s*\(.*?\)\s*$'), '')
                .trim(),
            style: GoogleFonts.manrope(
              color: accent,
              fontSize: Responsive.font(context, 16),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: Responsive.height(context, 16)),
          GestureDetector(
            onTap: () {
              Navigator.of(context, rootNavigator: true).pop();
              _showCreateExerciseDialog(existing: ex);
            },
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: Responsive.height(context, 10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.edit_outlined,
                    color: dim,
                    size: Responsive.scale(context, 18),
                  ),
                  SizedBox(width: Responsive.width(context, 12)),
                  Text(
                    'Edit',
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
            onTap: () async {
              Navigator.of(context, rootNavigator: true).pop();
              final confirmed = await showFrostedAlertDialog<bool>(
                context: this.context,
                appColor: appColor,
                title: 'Delete Exercise',
                content: Text(
                  'This will remove the exercise from your library. Past workouts won\'t be affected.',
                  style: GoogleFonts.manrope(
                    color: Colors.white70,
                    fontSize: Responsive.font(this.context, 13),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(
                      this.context,
                      rootNavigator: true,
                    ).pop(false),
                    child: Text('Cancel', style: dialogButtonStyle()),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(
                      this.context,
                      rootNavigator: true,
                    ).pop(true),
                    child: Text(
                      'Delete',
                      style: GoogleFonts.manrope(
                        color: lightenColor(appColor, 0.45),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              );
              if (confirmed == true) {
                final id = ex['id'] as int?;
                if (id != null) {
                  await ref
                      .read(workoutProvider.notifier)
                      .deleteCustomExercise(id);
                  if (mounted) _search();
                }
              }
            },
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: Responsive.height(context, 10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.delete_outline,
                    color: lightenColor(appColor, 0.45),
                    size: Responsive.scale(context, 18),
                  ),
                  SizedBox(width: Responsive.width(context, 12)),
                  Text(
                    'Delete',
                    style: GoogleFonts.manrope(
                      color: lightenColor(appColor, 0.45),
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

  // Create dialog doubles as an edit dialog when [existing] is provided
  // On create: saves and immediately selects the new exercise
  // On edit: saves and re-runs the current search to reflect the updated name
  Future<void> _showCreateExerciseDialog({
    Map<String, dynamic>? existing,
  }) async {
    final nameController = TextEditingController(
      text: existing?['name'] as String? ?? '',
    );
    final rawMuscle = existing?['primary_muscle'] as String?;
    String? selectedMuscle = rawMuscle != null && rawMuscle.isNotEmpty
        ? rawMuscle[0].toUpperCase() + rawMuscle.substring(1)
        : null;
    // secondary_muscles comes back from the search RPC as a List so cast accordingly
    // capitalize each entry to match _muscleOptions
    Set<String> selectedSecondary = existing != null
        ? Set<String>.from(
            (existing['secondary_muscles'] as List<dynamic>? ?? []).map((e) {
              final s = e.toString();
              return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
            }),
          )
        : {};
    final rawEquipment = existing?['equipment'] as String?;
    String? selectedEquipment = rawEquipment != null && rawEquipment.isNotEmpty
        ? rawEquipment[0].toUpperCase() + rawEquipment.substring(1)
        : null;
    final rawLevel = existing?['level'] as String?;
    String? selectedLevel = rawLevel != null && rawLevel.isNotEmpty
        ? rawLevel[0].toUpperCase() + rawLevel.substring(1)
        : null;
    final bool isEditing = existing != null;
    bool saving = false;
    String? errorMsg;

    // gradient matching the rest timer toggle and other app buttons
    final accentGradient = LinearGradient(
      colors: [
        lightenColor(appColor, 0.38),
        lightenColor(appColor, 0.22),
        lightenColor(appColor, 0.06),
      ],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    // one step shown at a time, no growing column, no overflow
    // step 5 = confirm (all chips shown, submit button)
    int step = isEditing ? 5 : 0;

    await showFrostedDialog<void>(
      context: context,
      appColor: appColor,
      child: StatefulBuilder(
        builder: (context, setDialogState) {
          void goTo(int s) => setDialogState(() => step = s);
          void advance() => setDialogState(() => step = (step + 1).clamp(0, 5));

          Widget gradientButton(String label, VoidCallback onTap) =>
              GestureDetector(
                onTap: onTap,
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    vertical: Responsive.height(context, 15),
                  ),
                  decoration: BoxDecoration(
                    gradient: accentGradient,
                    borderRadius: BorderRadius.circular(
                      Responsive.scale(context, 12),
                    ),
                    border: Border.all(
                      color: lightenColor(appColor, 0.25).withAlpha(180),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontSize: Responsive.font(context, 14),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );

          Widget ghostButton(String label, VoidCallback onTap) =>
              GestureDetector(
                onTap: onTap,
                child: Center(
                  child: Text(
                    label,
                    style: GoogleFonts.manrope(
                      color: Colors.white38,
                      fontSize: Responsive.font(context, 13),
                    ),
                  ),
                ),
              );

          // compact summary row at the top showing what's been filled so far
          Widget summaryChips() {
            final secondaryLabel = selectedSecondary.isEmpty
                ? 'No secondary'
                : selectedSecondary.length == 1
                ? selectedSecondary.first
                : '${selectedSecondary.length} muscles';
            final chips = <(String, int)>[];
            if (step > 0) chips.add((nameController.text.trim(), 0));
            if (step > 1 && selectedMuscle != null) {
              chips.add((selectedMuscle!, 1));
            }
            if (step > 2 && selectedSecondary.isNotEmpty) {
              chips.add((secondaryLabel, 2));
            }
            if (step > 3 && selectedEquipment != null) {
              chips.add((selectedEquipment!, 3));
            }
            if (step > 4 && selectedLevel != null) {
              chips.add((selectedLevel!, 4));
            }
            if (chips.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: EdgeInsets.only(bottom: Responsive.height(context, 14)),
              child: Wrap(
                spacing: Responsive.width(context, 6),
                runSpacing: Responsive.height(context, 6),
                children: [
                  for (final (label, s) in chips)
                    GestureDetector(
                      onTap: () => goTo(s),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.width(context, 10),
                          vertical: Responsive.height(context, 6),
                        ),
                        decoration: BoxDecoration(
                          gradient: accentGradient,
                          borderRadius: BorderRadius.circular(
                            Responsive.scale(context, 20),
                          ),
                          border: Border.all(
                            color: lightenColor(appColor, 0.25).withAlpha(120),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              label,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                color: Colors.white,
                                fontSize: Responsive.font(context, 11),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: Responsive.width(context, 4)),
                            Icon(
                              Icons.swap_horiz_rounded,
                              color: Colors.white70,
                              size: Responsive.scale(context, 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          }

          Widget stepLabel(String text) => Padding(
            padding: EdgeInsets.only(bottom: Responsive.height(context, 12)),
            child: Text(
              text,
              style: GoogleFonts.manrope(
                color: Colors.white,
                fontSize: Responsive.font(context, 15),
                fontWeight: FontWeight.w700,
              ),
            ),
          );

          Widget scrollableOptions(
            List<String> options,
            String? selected,
            void Function(String) onPick,
          ) {
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: Responsive.height(context, 240),
              ),
              child: ScrollConfiguration(
                behavior: NoGlowScrollBehavior(),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final opt in options)
                        _dialogOptionRow(
                          context,
                          label: opt,
                          selected: selected == opt,
                          gradient: accentGradient,
                          onTap: () => onPick(opt),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }

          Future<void> submit() async {
            final name = nameController.text.trim();
            setDialogState(() {
              saving = true;
              errorMsg = null;
            });
            if (isEditing) {
              final ok = await ref
                  .read(workoutProvider.notifier)
                  .editCustomExercise(
                    exerciseId: existing['id'] as int,
                    name: name,
                    primaryMuscle: selectedMuscle,
                    secondaryMuscles: selectedSecondary
                        .where((m) => m != selectedMuscle)
                        .toList(),
                    equipment: selectedEquipment,
                    level: selectedLevel,
                  );
              if (!mounted) return;
              if (!ok) {
                setDialogState(() {
                  saving = false;
                  errorMsg = 'Failed to save changes';
                });
                return;
              }
              Navigator.of(context).pop();
              _search();
            } else {
              final result = await ref
                  .read(workoutProvider.notifier)
                  .createCustomExercise(
                    name: name,
                    primaryMuscle: selectedMuscle,
                    secondaryMuscles: selectedSecondary
                        .where((m) => m != selectedMuscle)
                        .toList(),
                    equipment: selectedEquipment,
                    level: selectedLevel,
                  );
              if (!mounted) return;
              if (result == null || result.containsKey('error')) {
                setDialogState(() {
                  saving = false;
                  errorMsg =
                      result?['error'] as String? ??
                      'Failed to create exercise';
                });
                return;
              }
              final newEx = {
                'id': result['exercise_id'],
                'name': name,
                'primary_muscle': selectedMuscle ?? '',
                'secondary_muscles': selectedSecondary.toList(),
                'equipment': selectedEquipment ?? '',
                'level': selectedLevel ?? '',
                'is_custom': true,
                'exercise_name': name,
                'exercise_id': result['exercise_id'],
              };
              // add to recents and search results so it's visible immediately without re-fetching
              setState(() {
                _recentExercises.insert(0, newEx);
                _results.add(newEx);
                _hasSearched = true;
              });
              Navigator.of(context).pop();
              widget.onExerciseSelected(newEx);
              if (mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$name added to your library'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            }
          }

          // single AnimatedSwitcher swaps the whole step, no height animation, no overflow
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            switchInCurve: Curves.easeOutQuart,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.05),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: switch (step) {
              0 => KeyedSubtree(
                key: const ValueKey(0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    stepLabel("What's the exercise called?"),
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontSize: Responsive.font(context, 14),
                      ),
                      decoration: InputDecoration(
                        hintText: 'e.g. Bulgarian Split Squat',
                        hintStyle: GoogleFonts.manrope(
                          color: Colors.white38,
                          fontSize: Responsive.font(context, 14),
                        ),
                        filled: true,
                        fillColor: Colors.white.withAlpha(10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            Responsive.scale(context, 12),
                          ),
                          borderSide: BorderSide(
                            color: Colors.white.withAlpha(30),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            Responsive.scale(context, 12),
                          ),
                          borderSide: BorderSide(
                            color: Colors.white.withAlpha(30),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            Responsive.scale(context, 12),
                          ),
                          borderSide: BorderSide(
                            color: lightenColor(appColor, 0.30).withAlpha(200),
                            width: 1.5,
                          ),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: Responsive.width(context, 16),
                          vertical: Responsive.height(context, 14),
                        ),
                      ),
                      onSubmitted: (_) {
                        if (nameController.text.trim().isNotEmpty) advance();
                      },
                    ),
                    if (errorMsg != null) ...[
                      SizedBox(height: Responsive.height(context, 6)),
                      Text(
                        errorMsg!,
                        style: GoogleFonts.manrope(
                          color: lightenColor(appColor, 0.45),
                          fontSize: Responsive.font(context, 12),
                        ),
                      ),
                    ],
                    SizedBox(height: Responsive.height(context, 14)),
                    gradientButton('Continue', () {
                      if (nameController.text.trim().isEmpty) {
                        setDialogState(() => errorMsg = 'Name is required');
                        return;
                      }
                      setDialogState(() => errorMsg = null);
                      advance();
                    }),
                    SizedBox(height: Responsive.height(context, 10)),
                    ghostButton('Cancel', () => Navigator.of(context).pop()),
                  ],
                ),
              ),
              1 => KeyedSubtree(
                key: const ValueKey(1),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    summaryChips(),
                    stepLabel('Primary muscle?'),
                    scrollableOptions(_muscleOptions, selectedMuscle, (v) {
                      setDialogState(() => selectedMuscle = v);
                      advance();
                    }),
                    SizedBox(height: Responsive.height(context, 10)),
                    ghostButton('Skip', advance),
                  ],
                ),
              ),
              2 => KeyedSubtree(
                key: const ValueKey(2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    summaryChips(),
                    stepLabel('Secondary muscle(s)?'),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: Responsive.height(context, 200),
                      ),
                      child: ScrollConfiguration(
                        behavior: NoGlowScrollBehavior(),
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              for (final opt in _muscleOptions)
                                if (opt != selectedMuscle)
                                  _dialogOptionRow(
                                    context,
                                    label: opt,
                                    selected: selectedSecondary.contains(opt),
                                    gradient: accentGradient,
                                    onTap: () => setDialogState(() {
                                      if (selectedSecondary.contains(opt)) {
                                        selectedSecondary.remove(opt);
                                      } else {
                                        selectedSecondary.add(opt);
                                      }
                                    }),
                                  ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: Responsive.height(context, 10)),
                    gradientButton('Continue', advance),
                  ],
                ),
              ),
              3 => KeyedSubtree(
                key: const ValueKey(3),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    summaryChips(),
                    stepLabel('Equipment?'),
                    scrollableOptions(_equipmentOptions, selectedEquipment, (
                      v,
                    ) {
                      setDialogState(() => selectedEquipment = v);
                      advance();
                    }),
                    SizedBox(height: Responsive.height(context, 10)),
                    ghostButton('Skip', advance),
                  ],
                ),
              ),
              4 => KeyedSubtree(
                key: const ValueKey(4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    summaryChips(),
                    stepLabel('Difficulty?'),
                    for (final opt in _levelOptions)
                      _dialogOptionRow(
                        context,
                        label: opt,
                        selected: selectedLevel == opt,
                        gradient: accentGradient,
                        onTap: () {
                          setDialogState(() => selectedLevel = opt);
                          advance();
                        },
                      ),
                    SizedBox(height: Responsive.height(context, 10)),
                    ghostButton('Skip', advance),
                  ],
                ),
              ),
              _ => KeyedSubtree(
                key: const ValueKey(5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    summaryChips(),
                    if (errorMsg != null) ...[
                      SizedBox(height: Responsive.height(context, 4)),
                      Text(
                        errorMsg!,
                        style: GoogleFonts.manrope(
                          color: lightenColor(appColor, 0.45),
                          fontSize: Responsive.font(context, 12),
                        ),
                      ),
                      SizedBox(height: Responsive.height(context, 8)),
                    ],
                    saving
                        ? Center(
                            child: SizedBox(
                              width: Responsive.scale(context, 20),
                              height: Responsive.scale(context, 20),
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : gradientButton(
                            isEditing ? 'Save Changes' : 'Create Exercise',
                            submit,
                          ),
                    SizedBox(height: Responsive.height(context, 10)),
                    ghostButton('Cancel', () => Navigator.of(context).pop()),
                  ],
                ),
              ),
            },
          );
        },
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => nameController.dispose(),
    );
  }

  Future<void> _fetchRecentExercises() async {
    await ref.read(workoutProvider.notifier).loadRecentExercises();
    if (mounted) {
      setState(() {
        _recentExercises =
            ref.read(workoutProvider).value?.recentExercises ?? [];
        _loadingRecents = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), _search);
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty &&
        _selectedEquipment.isEmpty &&
        _selectedMuscle.isEmpty &&
        _selectedLevel.isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
      });
      return;
    }
    setState(() => _isLoading = true);
    try {
      final eq = _selectedEquipment
          .map((e) => Uri.encodeComponent(e.toLowerCase()))
          .join(',');
      final mu = _selectedMuscle
          .map((e) => Uri.encodeComponent(e.toLowerCase()))
          .join(',');
      final lv = _selectedLevel
          .map((e) => Uri.encodeComponent(e.toLowerCase()))
          .join(',');
      final response = await authenticatedGet(
        'search_exercises'
        '?q=${Uri.encodeComponent(query)}'
        '${eq.isNotEmpty ? '&equipment=$eq' : ''}'
        '${mu.isNotEmpty ? '&muscle=$mu' : ''}'
        '${lv.isNotEmpty ? '&level=$lv' : ''}',
      );
      if (response.statusCode == 200) {
        final data = (jsonDecode(response.body) as List<dynamic>)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        setState(() {
          _results = data;
          _hasSearched = true;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showFilterDialog(
    String title,
    List<String> options,
    Set<String> current,
    void Function(Set<String>) onSelect,
  ) async {
    // copy current so dialog-local state doesn't mutate the parent set until Apply is tapped
    Set<String> selected = Set.from(current);
    await showFrostedDialog(
      context: context,
      appColor: appColor,
      child: StatefulBuilder(
        builder: (context, setDialogState) {
          final accent = lightenColor(appColor, 0.45);
          final dim = lightenColor(appColor, 0.35);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.manrope(
                  color: accent,
                  fontSize: Responsive.font(context, 18),
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: Responsive.height(context, 16)),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: Responsive.height(context, 320),
                ),
                child: ScrollConfiguration(
                  behavior: NoGlowScrollBehavior(),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final opt in options)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: Responsive.height(context, 8),
                            ),
                            child: GestureDetector(
                              onTap: () => setDialogState(() {
                                if (selected.contains(opt)) {
                                  selected.remove(opt);
                                } else {
                                  selected.add(opt);
                                }
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(
                                  horizontal: Responsive.width(context, 16),
                                  vertical: Responsive.height(context, 14),
                                ),
                                decoration: BoxDecoration(
                                  color: selected.contains(opt)
                                      ? accent.withAlpha(30)
                                      : accent.withAlpha(10),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: selected.contains(opt)
                                        ? accent.withAlpha(160)
                                        : accent.withAlpha(40),
                                    width: selected.contains(opt) ? 1.5 : 1,
                                  ),
                                ),
                                child: Text(
                                  opt,
                                  style: GoogleFonts.manrope(
                                    color: selected.contains(opt)
                                        ? accent
                                        : dim,
                                    fontSize: Responsive.font(context, 14),
                                    fontWeight: selected.contains(opt)
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: Responsive.height(context, 8)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context, rootNavigator: true).pop(false),
                    child: Text('Cancel', style: dialogButtonStyle()),
                  ),
                  TextButton(
                    onPressed: () {
                      onSelect(selected);
                      Navigator.of(context, rootNavigator: true).pop(true);
                    },
                    child: Text(
                      'Apply',
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
    // re-run search after dialog closes so new filter selection takes effect
    _search();
  }

  Widget _filterButton(String label, Set<String> selected, VoidCallback onTap) {
    final active = selected.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: Responsive.height(context, 10)),
        decoration: BoxDecoration(
          color: active
              ? Colors.white.withAlpha(30)
              : Colors.white.withAlpha(18),
          borderRadius: BorderRadius.circular(Responsive.scale(context, 10)),
          border: Border.all(
            color: active
                ? Colors.white.withAlpha(80)
                : Colors.white.withAlpha(30),
            width: active ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: Colors.white60,
                fontSize: Responsive.font(context, 9),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
            // show the selected value if one, "Multiple" if several, or "All"
            // if none selected or every option is selected (equivalent to no filter)
            Text(
              selected.isEmpty
                  ? 'All'
                  : selected.length == 1
                  ? selected.first
                  : selected.length >=
                        (label == 'Equipment'
                            ? _equipmentOptions.length
                            : label == 'Muscle'
                            ? _muscleOptions.length
                            : _levelOptions.length)
                  ? 'All'
                  : 'Multiple',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: active ? Colors.white : Colors.white70,
                fontSize: Responsive.font(context, 12),
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: buildThemeGradient(appColor)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.centeredHorizontalPadding(context, 20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // header
                Padding(
                  padding: EdgeInsets.only(
                    top: Responsive.height(context, 8),
                    bottom: Responsive.height(context, 20),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          padding: EdgeInsets.all(
                            Responsive.scale(context, 10),
                          ),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: lightenColor(appColor, 0.1).withAlpha(20),
                            border: Border.all(
                              color: Colors.white.withAlpha(60),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white.withAlpha(160),
                            size: Responsive.font(context, 13),
                          ),
                        ),
                      ),
                      SizedBox(width: Responsive.width(context, 16)),
                      Expanded(
                        child: Text(
                          'Add Exercise',
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 20),
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _showCreateExerciseDialog,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: Responsive.width(context, 14),
                            vertical: Responsive.height(context, 8),
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              Responsive.scale(context, 12),
                            ),
                            gradient: LinearGradient(
                              colors: [
                                lightenColor(appColor, 0.35),
                                lightenColor(appColor, 0.20),
                                lightenColor(appColor, 0.05),
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            border: Border.all(
                              color: lightenColor(
                                appColor,
                                0.25,
                              ).withAlpha(180),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            'Create',
                            style: GoogleFonts.manrope(
                              color: Colors.white,
                              fontSize: Responsive.font(context, 13),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // search bar
                frostedGlassCard(
                  context,
                  color: appColor,
                  baseRadius: 14,
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.width(context, 14),
                    vertical: Responsive.height(context, 4),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search,
                        color: Colors.white38,
                        size: Responsive.font(context, 18),
                      ),
                      SizedBox(width: Responsive.width(context, 10)),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          keyboardType: TextInputType.text,
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 14),
                            color: Colors.white,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Search exercise...',
                            hintStyle: GoogleFonts.manrope(
                              fontSize: Responsive.font(context, 14),
                              color: Colors.white30,
                            ),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              vertical: Responsive.height(context, 12),
                            ),
                          ),
                          onChanged: _onSearchChanged,
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        child: _searchController.text.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  _debounce?.cancel();
                                  _searchController.clear();
                                  setState(() {
                                    _results = [];
                                    _hasSearched = false;
                                  });
                                },
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    left: Responsive.width(context, 8),
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.white38,
                                    size: Responsive.font(context, 16),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: Responsive.height(context, 12)),

                // filter buttons
                Row(
                  children: [
                    Expanded(
                      child: _filterButton(
                        'Equipment',
                        _selectedEquipment,
                        () => _showFilterDialog(
                          'Equipment',
                          _equipmentOptions,
                          _selectedEquipment,
                          (v) => setState(() => _selectedEquipment = v),
                        ),
                      ),
                    ),
                    SizedBox(width: Responsive.width(context, 10)),
                    Expanded(
                      child: _filterButton(
                        'Muscle',
                        _selectedMuscle,
                        () => _showFilterDialog(
                          'Muscle',
                          _muscleOptions,
                          _selectedMuscle,
                          (v) => setState(() => _selectedMuscle = v),
                        ),
                      ),
                    ),
                    SizedBox(width: Responsive.width(context, 10)),
                    Expanded(
                      child: _filterButton(
                        'Level',
                        _selectedLevel,
                        () => _showFilterDialog(
                          'Level',
                          _levelOptions,
                          _selectedLevel,
                          (v) => setState(() => _selectedLevel = v),
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: Responsive.height(context, 16)),

                // results
                Expanded(
                  child: _isLoading
                      ? Skeletonizer(
                          enabled: true,
                          ignoreContainers: false,
                          effect: ShimmerEffect(
                            baseColor: lightenColor(appColor, 0.10),
                            highlightColor: lightenColor(appColor, 0.22),
                            duration: const Duration(milliseconds: 1200),
                          ),
                          child: ListView(
                            physics: const NeverScrollableScrollPhysics(),
                            children: List.generate(
                              8,
                              (i) => Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: Responsive.height(context, 13),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            height: Responsive.height(
                                              context,
                                              14,
                                            ),
                                            width: Responsive.width(
                                              context,
                                              160,
                                            ),
                                            color: Colors.white,
                                          ),
                                          SizedBox(
                                            height: Responsive.height(
                                              context,
                                              4,
                                            ),
                                          ),
                                          Container(
                                            height: Responsive.height(
                                              context,
                                              11,
                                            ),
                                            width: Responsive.width(
                                              context,
                                              100,
                                            ),
                                            color: Colors.white,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: Responsive.scale(context, 16),
                                      height: Responsive.scale(context, 16),
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                      : !_hasSearched
                      ? _loadingRecents
                            ? _buildRecentsSkeleton(context)
                            : _buildRecentExercisesList(context)
                      : _results.isEmpty
                      ? Center(
                          child: Text(
                            'No exercises found',
                            style: GoogleFonts.manrope(
                              color: Colors.white38,
                              fontSize: Responsive.font(context, 13),
                            ),
                          ),
                        )
                      : ScrollConfiguration(
                          behavior: NoGlowScrollBehavior(),
                          child: ListView.separated(
                            itemCount: _results.length,
                            separatorBuilder: (_, idx) => Divider(
                              color: Colors.white.withAlpha(12),
                              height: 1,
                              thickness: 1,
                            ),
                            itemBuilder: (context, i) {
                              final ex = _results[i];
                              // strip trailing parenthetical suffixes from seeded data e.g. "Box Jump (Multiple Response)" -> "Box Jump"
                              final name = (ex['name'] as String? ?? '')
                                  .replaceAll(RegExp(r'\s*\(.*?\)\s*$'), '')
                                  .trim();
                              final muscle =
                                  ex['primary_muscle'] as String? ?? '';
                              final equipment =
                                  ex['equipment'] as String? ?? '';
                              String capitalize(String s) => s.isEmpty
                                  ? s
                                  : s[0].toUpperCase() + s.substring(1);
                              // custom exercises show a three-dot menu instead of a chevron
                              final isCustom = ex['is_custom'] == true;
                              return _buildExerciseRow(
                                context,
                                name: name,
                                subtitle: [
                                  if (muscle.isNotEmpty)
                                    'Muscle: ${capitalize(muscle)}',
                                  if (equipment.isNotEmpty)
                                    'Equipment: ${capitalize(equipment)}',
                                ].join(' · '),
                                isCustom: isCustom,
                                onTap: () {
                                  widget.onExerciseSelected(ex);
                                  Navigator.of(context).pop();
                                },
                                onMenuTap: isCustom
                                    ? () => _showCustomExerciseMenu(context, ex)
                                    : null,
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dialogOptionRow(
    BuildContext context, {
    required String label,
    required bool selected,
    required LinearGradient gradient,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: Responsive.height(context, 6)),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.width(context, 16),
            vertical: Responsive.height(context, 13),
          ),
          decoration: BoxDecoration(
            gradient: selected ? gradient : null,
            color: selected ? null : Colors.white.withAlpha(25),
            borderRadius: BorderRadius.circular(Responsive.scale(context, 10)),
            border: Border.all(
              color: selected
                  ? Colors.white.withAlpha(60)
                  : Colors.white.withAlpha(50),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.manrope(
              color: selected ? Colors.white : Colors.white,
              fontSize: Responsive.font(context, 13),
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExerciseRow(
    BuildContext context, {
    required String name,
    required String subtitle,
    required VoidCallback onTap,
    bool isCustom = false,
    VoidCallback? onMenuTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: Responsive.height(context, 13)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontSize: Responsive.font(context, 14),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        color: Colors.white54,
                        fontSize: Responsive.font(context, 12),
                      ),
                    ),
                ],
              ),
            ),
            if (isCustom && onMenuTap != null)
              GestureDetector(
                onTap: onMenuTap,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: EdgeInsets.only(left: Responsive.width(context, 8)),
                  child: Icon(
                    Icons.more_vert,
                    color: Colors.white38,
                    size: Responsive.scale(context, 20),
                  ),
                ),
              )
            else
              Icon(
                Icons.chevron_right,
                color: Colors.white30,
                size: Responsive.scale(context, 20),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentsSkeleton(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      ignoreContainers: false,
      effect: ShimmerEffect(
        baseColor: lightenColor(appColor, 0.10),
        highlightColor: lightenColor(appColor, 0.22),
        duration: const Duration(milliseconds: 1200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // label placeholder
          Container(
            width: Responsive.width(context, 90),
            height: Responsive.height(context, 10),
            margin: EdgeInsets.only(bottom: Responsive.height(context, 10)),
            color: Colors.white,
          ),
          for (int i = 0; i < 6; i++) ...[
            if (i > 0)
              Divider(
                color: Colors.white.withAlpha(12),
                height: 1,
                thickness: 1,
              ),
            Padding(
              padding: EdgeInsets.symmetric(
                vertical: Responsive.height(context, 13),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: Responsive.height(context, 14),
                          width: Responsive.width(context, 150),
                          color: Colors.white,
                        ),
                        SizedBox(height: Responsive.height(context, 4)),
                        Container(
                          height: Responsive.height(context, 11),
                          width: Responsive.width(context, 100),
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: Responsive.scale(context, 16),
                    height: Responsive.scale(context, 16),
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentExercisesList(BuildContext context) {
    Widget sectionHeader(String label) => Padding(
      padding: EdgeInsets.only(
        bottom: Responsive.height(context, 10),
        top: Responsive.height(context, 4),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          color: Colors.white70,
          fontSize: Responsive.font(context, 13),
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    return ScrollConfiguration(
      behavior: NoGlowScrollBehavior(),
      child: ListView(
        children: [
          if (_recommendedExercises.isNotEmpty) ...[
            sectionHeader('RECOMMENDED'),
            for (int i = 0; i < _recommendedExercises.length; i++) ...[
              if (i > 0)
                Divider(
                  color: Colors.white.withAlpha(12),
                  height: 1,
                  thickness: 1,
                ),
              _buildExerciseRow(
                context,
                name: (_recommendedExercises[i]['name'] as String? ?? '')
                    .replaceAll(RegExp(r'\s*\(.*?\)\s*$'), '')
                    .trim(),
                subtitle:
                    (_recommendedExercises[i]['equipment'] as String?) ?? '',
                onTap: () {
                  widget.onExerciseSelected(_recommendedExercises[i]);
                  Navigator.of(context).pop();
                },
              ),
            ],
            SizedBox(height: Responsive.height(context, 16)),
          ],
          if (_recentExercises.isNotEmpty) ...[
            sectionHeader('RECENTLY LOGGED EXERCISES'),
            for (int i = 0; i < _recentExercises.length; i++) ...[
              if (i > 0)
                Divider(
                  color: Colors.white.withAlpha(12),
                  height: 1,
                  thickness: 1,
                ),
              _buildExerciseRow(
                context,
                name: (_recentExercises[i]['exercise_name'] as String? ?? '')
                    .replaceAll(RegExp(r'\s*\(.*?\)\s*$'), '')
                    .trim(),
                subtitle: '',
                onTap: () {
                  widget.onExerciseSelected(_recentExercises[i]);
                  Navigator.of(context).pop();
                },
              ),
            ],
            SizedBox(height: Responsive.height(context, 20)),
          ],
          Divider(color: Colors.white.withAlpha(40), height: 1),
          SizedBox(height: Responsive.height(context, 16)),
          sectionHeader('BROWSE BY MUSCLE'),
          _buildMuscleGrid(context),
          SizedBox(height: Responsive.height(context, 20)),
          Divider(color: Colors.white.withAlpha(40), height: 1),
          SizedBox(height: Responsive.height(context, 16)),
          sectionHeader('BROWSE BY EQUIPMENT'),
          _buildEquipmentGrid(context),
        ],
      ),
    );
  }

  static const _muscleGridItems = [
    ('Chest', 'Chest', HugeIcons.strokeRoundedEquipmentChestPress),
    ('Back', 'Lats', HugeIcons.strokeRoundedBackMuscleBody),
    ('Shoulders', 'Shoulders', HugeIcons.strokeRoundedShoulder),
    ('Biceps', 'Biceps', HugeIcons.strokeRoundedBodyPartMuscle),
    ('Triceps', 'Triceps', HugeIcons.strokeRoundedDumbbell02),
    ('Legs', 'Quadriceps', HugeIcons.strokeRoundedBodyPartLeg),
    ('Glutes', 'Glutes', HugeIcons.strokeRoundedWorkoutSquats),
    ('Core', 'Abdominals', HugeIcons.strokeRoundedBodyPartSixPack),
  ];

  static const _equipmentGridItems = [
    ('Barbell', 'Barbell', HugeIcons.strokeRoundedEquipmentBenchPress),
    ('Dumbbell', 'Dumbbell', HugeIcons.strokeRoundedDumbbell01),
    ('Body Only', 'Body Only', HugeIcons.strokeRoundedCancel02),
    ('Machine', 'Machine', HugeIcons.strokeRoundedEquipmentChestPress),
    ('Cable', 'Cable', HugeIcons.strokeRoundedPulley),
    ('Kettlebell', 'Kettlebells', HugeIcons.strokeRoundedKettlebell),
    ('Bands', 'Bands', HugeIcons.strokeRoundedWorkoutStretching),
    ('Other', 'Other', HugeIcons.strokeRoundedWorkoutBattleRopes),
  ];

  Widget _buildEquipmentGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: Responsive.height(context, 10),
      crossAxisSpacing: Responsive.width(context, 10),
      childAspectRatio: 1.1,
      children: [
        for (final (label, equipment, icon) in _equipmentGridItems)
          GestureDetector(
            onTap: () {
              setState(() => _selectedEquipment = {equipment});
              _search();
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(14),
                borderRadius: BorderRadius.circular(
                  Responsive.scale(context, 12),
                ),
                border: Border.all(color: Colors.white.withAlpha(22), width: 1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  HugeIcon(
                    icon: icon,
                    color: Colors.white38,
                    size: Responsive.scale(context, 22),
                  ),
                  SizedBox(height: Responsive.height(context, 4)),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      color: Colors.white60,
                      fontSize: Responsive.font(context, 10),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMuscleGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: Responsive.height(context, 10),
      crossAxisSpacing: Responsive.width(context, 10),
      childAspectRatio: 1.1,
      children: [
        for (final (label, muscle, icon) in _muscleGridItems)
          GestureDetector(
            onTap: () {
              setState(() => _selectedMuscle = {muscle});
              _search();
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(14),
                borderRadius: BorderRadius.circular(
                  Responsive.scale(context, 12),
                ),
                border: Border.all(color: Colors.white.withAlpha(22), width: 1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  HugeIcon(
                    icon: icon,
                    color: Colors.white38,
                    size: Responsive.scale(context, 22),
                  ),
                  SizedBox(height: Responsive.height(context, 4)),
                  Text(
                    label,
                    style: GoogleFonts.manrope(
                      color: Colors.white60,
                      fontSize: Responsive.font(context, 10),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
