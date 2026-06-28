import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart' hide ShimmerEffect;
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:go_router/go_router.dart';
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

class ExercisePickerScreen extends StatefulWidget {
  final void Function(Map<String, dynamic> exercise) onExerciseSelected;

  const ExercisePickerScreen({super.key, required this.onExerciseSelected});

  @override
  State<ExercisePickerScreen> createState() => _ExercisePickerScreenState();
}

class _ExercisePickerScreenState extends State<ExercisePickerScreen> {
  late final VoidCallback _colorListener;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  Timer? _searchHintTimer;

  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  bool _showSearchHint = false;
  Set<String> _selectedEquipment = {};
  Set<String> _selectedMuscle = {};
  Set<String> _selectedLevel = {};

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
    _searchController.dispose();
    _debounce?.cancel();
    _searchHintTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _searchHintTimer?.cancel();
    if (_showSearchHint) setState(() => _showSearchHint = false);
    if (value.trim().isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), _search);
    _searchHintTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_isLoading) setState(() => _showSearchHint = true);
    });
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
    Set<String> selected = Set.from(current);
    await showFrostedDialog(
      context: context,
      child: StatefulBuilder(
        builder: (context, setDialogState) {
          final accent = lightenColor(appColorNotifier.value, 0.45);
          final dim = lightenColor(appColorNotifier.value, 0.35);
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
                        Navigator.of(context, rootNavigator: true).pop(),
                    child: Text('Cancel', style: dialogButtonStyle()),
                  ),
                  TextButton(
                    onPressed: () {
                      onSelect(selected);
                      Navigator.of(context, rootNavigator: true).pop();
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
    _search();
  }

  Widget _filterButton(String label, Set<String> selected, VoidCallback onTap) {
    final accent = lightenColor(appColorNotifier.value, 0.45);
    final dim = lightenColor(appColorNotifier.value, 0.35);
    final active = selected.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: Responsive.height(context, 10)),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(18),
          borderRadius: BorderRadius.circular(Responsive.scale(context, 20)),
          border: Border.all(color: Colors.white.withAlpha(30), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: dim,
                fontSize: Responsive.font(context, 9),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
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
                color: active
                    ? accent
                    : lightenColor(appColorNotifier.value, 0.45),
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
    final appColor = appColorNotifier.value;
    final accent = lightenColor(appColor, 0.45);
    final dim = lightenColor(appColor, 0.35);
    final c = cardColors(appColor);

    return Container(
      decoration: BoxDecoration(gradient: buildThemeGradient()),
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
                            Responsive.scale(context, 12),
                          ),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: lightenColor(appColor, 0.1).withAlpha(20),
                            border: Border.all(
                              color: lightenColor(appColor, 0.3).withAlpha(180),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new,
                            color: lightenColor(appColor, 0.3).withAlpha(180),
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
                            color: accent,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          // TODO: open create custom exercise screen
                        },
                        child: Text(
                          'Create',
                          style: GoogleFonts.manrope(
                            color: accent,
                            fontSize: Responsive.font(context, 14),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // search bar
                frostedGlassCard(
                  context,
                  baseRadius: 14,
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.width(context, 14),
                    vertical: Responsive.height(context, 8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search,
                        color: c.onCard.withAlpha(120),
                        size: Responsive.font(context, 20),
                      ),
                      SizedBox(width: Responsive.width(context, 10)),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          keyboardType: TextInputType.text,
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 15),
                            color: accent,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Search exercise...',
                            hintStyle: GoogleFonts.manrope(
                              fontSize: Responsive.font(context, 15),
                              color: c.onCard.withAlpha(100),
                            ),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              vertical: Responsive.height(context, 16),
                              horizontal: Responsive.width(context, 4),
                            ),
                          ),
                          onChanged: _onSearchChanged,
                          onSubmitted: (_) => _search(),
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOut,
                        child: _searchController.text.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  _searchHintTimer?.cancel();
                                  setState(() => _showSearchHint = false);
                                  _search();
                                },
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: Responsive.width(context, 10),
                                    vertical: Responsive.height(context, 8),
                                  ),
                                  child: _showSearchHint
                                      ? Text(
                                              'Search',
                                              style: GoogleFonts.manrope(
                                                color: accent,
                                                fontSize: Responsive.font(
                                                  context,
                                                  13,
                                                ),
                                                fontWeight: FontWeight.w700,
                                              ),
                                            )
                                            .animate(onPlay: (c) => c.repeat())
                                            .shimmer(
                                              duration: 2000.ms,
                                              color:
                                                  accent.computeLuminance() >
                                                      0.5
                                                  ? darkenColor(
                                                      accent,
                                                      0.35,
                                                    ).withAlpha(200)
                                                  : lightenColor(
                                                      accent,
                                                      0.4,
                                                    ).withAlpha(200),
                                            )
                                      : Text(
                                          'Search',
                                          style: GoogleFonts.manrope(
                                            color: accent,
                                            fontSize: Responsive.font(
                                              context,
                                              13,
                                            ),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        child: _searchController.text.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  _searchHintTimer?.cancel();
                                  _searchController.clear();
                                  setState(() {
                                    _results = [];
                                    _hasSearched = false;
                                    _showSearchHint = false;
                                  });
                                },
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: Responsive.width(context, 8),
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    color: c.onCard.withAlpha(140),
                                    size: Responsive.font(context, 20),
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
                      ? Center(
                          child: CircularProgressIndicator(
                            color: accent,
                            strokeWidth: 2,
                          ),
                        )
                      : !_hasSearched
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              HugeIcon(
                                icon: HugeIcons.strokeRoundedSearch01,
                                color: Colors.white24,
                                size: Responsive.scale(context, 40),
                              ),
                              SizedBox(height: Responsive.height(context, 12)),
                              Text(
                                'Search for an exercise',
                                style: GoogleFonts.manrope(
                                  color: dim,
                                  fontSize: Responsive.font(context, 13),
                                ),
                              ),
                            ],
                          ),
                        )
                      : _results.isEmpty
                      ? Center(
                          child: Text(
                            'No exercises found',
                            style: GoogleFonts.manrope(
                              color: dim,
                              fontSize: Responsive.font(context, 13),
                            ),
                          ),
                        )
                      : ScrollConfiguration(
                          behavior: NoGlowScrollBehavior(),
                          child: ListView.separated(
                            itemCount: _results.length,
                            separatorBuilder: (_, index) =>
                                SizedBox(height: Responsive.height(context, 8)),
                            itemBuilder: (context, i) {
                              final ex = _results[i];
                              final name = ex['name'] as String? ?? '';
                              final category = ex['category'] as String? ?? '';
                              final muscle =
                                  ex['primary_muscle'] as String? ?? '';
                              return GestureDetector(
                                onTap: () {
                                  widget.onExerciseSelected(ex);
                                  context.pop();
                                },
                                child: frostedGlassCard(
                                  context,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: Responsive.width(context, 16),
                                    vertical: Responsive.height(context, 14),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: GoogleFonts.manrope(
                                                color: accent,
                                                fontSize: Responsive.font(
                                                  context,
                                                  13,
                                                ),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (muscle.isNotEmpty ||
                                                category.isNotEmpty)
                                              Text(
                                                [
                                                  if (muscle.isNotEmpty) muscle,
                                                  if (category.isNotEmpty)
                                                    category,
                                                ].join(' · '),
                                                style: GoogleFonts.manrope(
                                                  color: dim,
                                                  fontSize: Responsive.font(
                                                    context,
                                                    11,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      HugeIcon(
                                        icon: HugeIcons.strokeRoundedAddCircle,
                                        color: Colors.white24,
                                        size: Responsive.scale(context, 20),
                                      ),
                                    ],
                                  ),
                                ),
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
}
