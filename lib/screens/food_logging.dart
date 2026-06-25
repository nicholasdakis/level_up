import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'dart:math' as math;
import '../globals.dart';
import '../guest.dart';
import '../utility/responsive.dart';
import '../utility/food_logging_helper.dart';
import '../services/user_data_manager.dart';
import '../utility/shared_preferences/shared_prefs_async.dart';

List<Color> _mealColors(Color base) {
  return [
    lightenColor(base, 0.30),
    lightenColor(base, 0.30),
    lightenColor(base, 0.30),
    lightenColor(base, 0.30),
  ];
}

class FoodLogging extends StatefulWidget {
  const FoodLogging({super.key});

  @override
  State<FoodLogging> createState() => _FoodLoggingState();
}

class _FoodLoggingState extends State<FoodLogging> {
  DateTime currentDate = DateTime.now();
  late Future<void> _loadUserDataFuture;

  List<Map<String, dynamic>> breakfastFoods = [];
  List<Map<String, dynamic>> lunchFoods = [];
  List<Map<String, dynamic>> dinnerFoods = [];
  List<Map<String, dynamic>> snacksFoods = [];

  final Map<String, bool> _collapsed = {
    'breakfast': false,
    'lunch': false,
    'dinner': false,
    'snacks': false,
  };

  final _prefs = SharedPrefsService(); // for persisting meal collapsed state

  // Restores which meal sections were collapsed from the last session
  Future<void> _loadCollapsedState() async {
    final saved = await _prefs.getJsonMap(
      SharedPreferencesKey.mealCollapsedState,
    );
    if (saved.isEmpty) return;
    setState(() {
      for (final key in _collapsed.keys) {
        if (saved.containsKey(key)) _collapsed[key] = saved[key] as bool;
      }
    });
  }

  // Persists the current collapsed state so it is remembered when the screen re-opens
  void _saveCollapsedState() {
    _prefs.setJsonMap(
      SharedPreferencesKey.mealCollapsedState,
      Map.from(_collapsed),
    );
  }

  // getters that read from currentUserData so goals are always up to date
  double get _goalCalories => (currentUserData?.caloriesGoal ?? 0).toDouble();
  double get _goalProtein => (currentUserData?.proteinGoal ?? 0).toDouble();
  double get _goalCarbs => (currentUserData?.carbsGoal ?? 0).toDouble();
  double get _goalFat => (currentUserData?.fatGoal ?? 0).toDouble();
  bool get _goalsSet =>
      currentUserData?.caloriesGoal !=
      null; // true only if the user has set at least a calorie goal

  late final VoidCallback _colorListener;

  @override
  void initState() {
    super.initState();
    FirebaseAnalytics.instance.logScreenView(
      screenName: '/food-logging',
      screenClass: 'FoodLogging',
    );
    _colorListener = () {
      if (mounted) setState(() {});
    };
    appColorNotifier.addListener(_colorListener);
    _loadCollapsedState();
    _loadUserDataFuture = _loadUserDataAndInit();
    // Track that the user opened food logging
    trackTrivialAchievement("open_food_logging");
  }

  @override
  void dispose() {
    appColorNotifier.removeListener(_colorListener);
    super.dispose();
  }

  Future<void> _loadUserDataAndInit() async {
    if (currentUserData != null &&
        currentUserData!.uid == FirebaseAuth.instance.currentUser?.uid) {
      await _refreshAndLoadFood();
      return;
    }
    await userManager.loadUserData();
    await _refreshAndLoadFood();
  }

  Future<void> _refreshAndLoadFood() async {
    await userManager.refreshUserData();
    loadFoodForDate(currentDate);
  }

  void loadFoodForDate(DateTime date) {
    final dateKey = FoodLoggingHelper.formatDateKey(date);
    final logs = currentUserData?.foodLogs ?? [];
    setState(() {
      breakfastFoods = logs
          .where((f) => f['date'] == dateKey && f['meal'] == 'breakfast')
          .toList();
      lunchFoods = logs
          .where((f) => f['date'] == dateKey && f['meal'] == 'lunch')
          .toList();
      dinnerFoods = logs
          .where((f) => f['date'] == dateKey && f['meal'] == 'dinner')
          .toList();
      snacksFoods = logs
          .where((f) => f['date'] == dateKey && f['meal'] == 'snacks')
          .toList();
    });
  }

  // Helper method for getting calories per meal type
  double _mealCalories(List<Map<String, dynamic>> foods) {
    double total = 0;
    for (var food in foods) {
      total += (num.tryParse(food['calories'].toString()) ?? 0).toDouble();
    }
    return total;
  }

  double _totalCalories() {
    return _mealCalories(breakfastFoods) +
        _mealCalories(lunchFoods) +
        _mealCalories(dinnerFoods) +
        _mealCalories(snacksFoods);
  }

  double _totalMacro(String macroKey) {
    // flatten all the foods into one list
    final allFoods = [
      ...breakfastFoods,
      ...lunchFoods,
      ...dinnerFoods,
      ...snacksFoods,
    ];
    double total = 0;
    for (var food in allFoods) {
      final macros = FoodLoggingHelper.extractMacrosFromFood(food);
      // Add onto the macro based on the macro type
      total += macros[macroKey] ?? 0;
    }
    return total;
  }

  Future<void> _deleteFood(
    String mealKey,
    int idx,
    List<Map<String, dynamic>> foods,
  ) async {
    if (isGuest) {
      Guest.block(context);
      return;
    } // For guest users
    final confirmed = await showFrostedAlertDialog<bool>(
      context: context,
      title: "Delete food?",
      content: Text(
        "Are you sure you want to remove ${foods[idx]['food_name'] ?? 'this food'}?",
        style: GoogleFonts.manrope(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(false),
          child: Text(
            "Cancel",
            style: GoogleFonts.manrope(
              color: lightenColor(appColorNotifier.value, 0.45),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
          child: Text(
            "Delete",
            style: GoogleFonts.manrope(
              color: lightenColor(appColorNotifier.value, 0.45),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
    if (confirmed != true) return;

    final dateKey = FoodLoggingHelper.formatDateKey(currentDate);
    final removed = foods[idx];
    setState(() {
      foods.removeAt(idx);
      currentUserData?.foodLogs.removeWhere(
        (f) =>
            f['date'] == dateKey &&
            f['meal'] == mealKey &&
            f['id'] == removed['id'],
      );
    });
    await _saveFoodData("delete");
    foodLogNotifier.value++;
  }

  // Opens a dialog letting the user change the serving amount for a logged food
  // Scales all macros proportionally and saves the updated entry
  Future<void> _editServingSize(
    String mealKey,
    List<Map<String, dynamic>> foods,
    Map<String, dynamic> food,
  ) async {
    if (isGuest) {
      Guest.block(context);
      return;
    }
    final serving = FoodLoggingHelper.parseServing(
      food['food_description'] as String? ?? '',
    );
    final currentAmt = serving['amount'] as double;
    final unit = serving['unit'] as String;
    final controller = TextEditingController(
      text: currentAmt % 1 == 0
          ? currentAmt.toInt().toString()
          : currentAmt.toString(),
    );

    final result = await showServingAmountDialog(
      context: context,
      food: food,
      controller: controller,
      confirmLabel: 'Save',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    // the user cancelled or typed something invalid
    if (result == null || result.amt.isEmpty) return;
    final newAmt = double.tryParse(result.amt);
    if (newAmt == null || newAmt <= 0) return;
    // No change, skip the write
    if (newAmt == currentAmt && result.macroOverrides == null) return;

    // Scale every macro by the ratio of new amount to old amount, then apply any user overrides
    final baseMacros = FoodLoggingHelper.extractMacrosFromFood(food);
    final scaledBase = FoodLoggingHelper.scaleFood(
      baseMacros,
      currentAmt,
      newAmt,
    );
    final scaled = result.macroOverrides != null
        ? {
            'calories':
                (result.macroOverrides!['calories'] ?? scaledBase['calories']!)
                    .toDouble(),
            'protein':
                result.macroOverrides!['protein'] ?? scaledBase['protein']!,
            'carbs': result.macroOverrides!['carbs'] ?? scaledBase['carbs']!,
            'fat': result.macroOverrides!['fat'] ?? scaledBase['fat']!,
          }
        : scaledBase;
    // Rebuild food_description
    final newDescription = FoodLoggingHelper.buildDescription(
      scaled,
      newAmt,
      unit,
    );

    // Update the food map in place
    setState(() {
      food['food_description'] = newDescription;
      food['calories'] = scaled['calories']!.round();
      food['protein'] = scaled['protein'];
      food['carbs'] = scaled['carbs'];
      food['fat'] = scaled['fat'];
      food['serving_size'] = '$newAmt $unit';
      // Update the same item in foodLogs by id
      final idx = currentUserData?.foodLogs.indexWhere(
        (f) => f['id'] == food['id'],
      );
      if (idx != null && idx >= 0) currentUserData?.foodLogs[idx] = food;
    });
    await _saveFoodData("edit"); // store the changes
    foodLogNotifier.value++;
  }

  Future<void> _saveFoodData(String addOrDelete) async {
    if (currentUserData == null) return;
    final dateKey = FoodLoggingHelper.formatDateKey(currentDate);
    final logs = currentUserData!.foodLogs
        .where((f) => f['date'] == dateKey)
        .toList();
    final currentDateData = {
      dateKey: {
        'breakfast': logs.where((f) => f['meal'] == 'breakfast').toList(),
        'lunch': logs.where((f) => f['meal'] == 'lunch').toList(),
        'dinner': logs.where((f) => f['meal'] == 'dinner').toList(),
        'snacks': logs.where((f) => f['meal'] == 'snacks').toList(),
      },
    };
    await userManager.updateFoodDataByDateV2(
      currentDateData,
      context: context,
      isBeingDeleted: addOrDelete == "delete",
      isBeingEdited: addOrDelete == "edit",
    );
  }

  Widget _buildMacroText(Map<String, dynamic> food) {
    final macros = FoodLoggingHelper.extractMacrosFromFood(food);
    final serving = FoodLoggingHelper.parseServing(
      food['food_description'] as String? ?? '',
    );
    final servingAmt = serving['amount'] as double;
    final servingStr = servingAmt % 1 == 0
        ? servingAmt.toInt().toString()
        : servingAmt.toString();
    final cal = num.tryParse(food['calories'].toString()) ?? 0;
    final base = appColorNotifier.value;
    final dim = lightenColor(base, 0.35);

    Widget chip(String label, double value) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.width(context, 7),
          vertical: Responsive.height(context, 3),
        ),
        decoration: BoxDecoration(
          color: lightenColor(base, 0.3).withAlpha(40),
          borderRadius: BorderRadius.circular(Responsive.scale(context, 20)),
          border: Border.all(
            color: lightenColor(base, 0.3).withAlpha(80),
            width: 1,
          ),
        ),
        child: Text(
          '$label ${value.toStringAsFixed(1)}g',
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 11),
            fontWeight: FontWeight.w600,
            color: lightenColor(base, 0.45),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$servingStr ${serving['unit']} · $cal kcal',
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 12),
            color: dim,
          ),
        ),
        SizedBox(height: Responsive.height(context, 5)),
        Wrap(
          spacing: Responsive.width(context, 5),
          runSpacing: Responsive.height(context, 4),
          children: [
            chip('P', macros['protein'] ?? 0),
            chip('C', macros['carbs'] ?? 0),
            chip('F', macros['fat'] ?? 0),
          ],
        ),
      ],
    );
  }

  // Calories bar which also has a "View Analytics button
  Widget _buildCaloriesBar(Color appColor) {
    // if no goals set, show a prompt to open the goals dialog
    if (!_goalsSet) {
      return frostedGlassCard(
        context,
        baseRadius: 20,
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.width(context, 20),
          vertical: Responsive.height(context, 18),
        ),
        child: SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: () async {
              // For guest users
              if (isGuest) {
                Guest.block(context);
                return;
              }
              await context.push('/settings/preferences');
              if (mounted) setState(() {});
            },
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedTarget01,
              color: lightenColor(appColor, 0.30),
              size: Responsive.scale(context, 24),
            ),
            label: Text(
              "Set your nutrition goals",
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 14),
                fontWeight: FontWeight.w600,
                color: lightenColor(appColor, 0.30),
              ),
            ),
          ),
        ),
      );
    }

    final total = _totalCalories();
    final progress = (total / _goalCalories).clamp(0.0, 1.0);
    final remaining = (_goalCalories - total).round();
    final barColor = lightenColor(appColor, 0.45);
    final isOver = total > _goalCalories;

    return frostedGlassCard(
      context,
      baseRadius: 20,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.width(context, 20),
        vertical: Responsive.height(context, 18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Big calorie number
              Text(
                total.round().toString(),
                style: GoogleFonts.manrope(
                  fontSize: Responsive.font(context, 36),
                  fontWeight: FontWeight.w800,
                  color: lightenColor(appColorNotifier.value, 0.45),
                  height: 1,
                ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: Responsive.height(context, 4)),
                child: Text(
                  " / ${_goalCalories.round()} kcal",
                  style: GoogleFonts.manrope(
                    fontSize: Responsive.font(context, 13),
                    color: lightenColor(appColorNotifier.value, 0.45),
                  ),
                ),
              ),
              const Spacer(),
              // Info label for the calories
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isOver
                        ? "${(total - _goalCalories).round()} over"
                        : "$remaining left",
                    style: GoogleFonts.manrope(
                      fontSize: Responsive.font(context, 13),
                      fontWeight: FontWeight.w600,
                      color: isOver
                          ? lightenColor(appColorNotifier.value, 0.45)
                          : barColor,
                    ),
                  ),
                  Text(
                    "daily goal",
                    style: GoogleFonts.manrope(
                      fontSize: Responsive.font(context, 11),
                      color: lightenColor(appColorNotifier.value, 0.45),
                    ),
                  ),
                ],
              ),
            ],
          ),

          SizedBox(height: Responsive.height(context, 14)),

          // Progress bar
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Responsive.scale(context, 7)),
              border: Border.all(
                color: Colors.white.withAlpha(45),
                width: Responsive.scale(context, 1),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Responsive.scale(context, 6)),
              child: Stack(
                children: [
                  // Track
                  Container(
                    height: Responsive.height(context, 8),
                    width: double.infinity,
                    color: Colors.white.withAlpha(18),
                  ),
                  // Fill
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      height: Responsive.height(context, 8),
                      decoration: BoxDecoration(
                        color: isOver
                            ? lightenColor(appColorNotifier.value, 0.45)
                            : barColor,
                        borderRadius: BorderRadius.circular(
                          Responsive.scale(context, 6),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: Responsive.height(context, 16)),

          // View Analytics button
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () {
                context.push(
                  '/food-logging/analytics',
                  extra: {
                    'initialDate': currentDate,
                    'onDateChanged': (DateTime date) {
                      setState(() => currentDate = date);
                      loadFoodForDate(date);
                    },
                  },
                );
              },
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedAnalytics01,
                color: barColor,
                size: Responsive.font(context, 26),
              ),
              label: Text(
                "View Analytics",
                style: GoogleFonts.manrope(
                  fontSize: Responsive.font(context, 14),
                  fontWeight: FontWeight.w600,
                  color: barColor,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: barColor.withAlpha(
                  appColor.computeLuminance() < 0.2 ? 60 : 30,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    Responsive.scale(context, 12),
                  ),
                  side: BorderSide(
                    color: barColor.withAlpha(
                      appColor.computeLuminance() < 0.2 ? 140 : 80,
                    ),
                    width: Responsive.scale(context, 1),
                  ),
                ),
                padding: EdgeInsets.symmetric(
                  vertical: Responsive.height(context, 10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Single semi-donut gauge for macros (one per macro)
  Widget _buildMacroGauge({
    required String label,
    required double current,
    required double goal,
    required Color color,
  }) {
    final progress = (current / goal).clamp(0.0, 1.0);
    final gaugeSize = Responsive.scale(context, 90);

    final pct = (progress * 100).round();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: gaugeSize,
          height: gaugeSize * 0.6,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: 0.65,
                  child: SizedBox(
                    width: gaugeSize,
                    height: gaugeSize,
                    child: CustomPaint(
                      painter: _SemiDonutPainter(
                        progress: progress,
                        trackColor: Colors.white.withAlpha(18),
                        fillColor: color,
                        strokeWidth: Responsive.scale(context, 10),
                      ),
                    ),
                  ),
                ),
              ),
              Text(
                "$pct%",
                style: GoogleFonts.manrope(
                  fontSize: Responsive.font(context, 12),
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: Responsive.height(context, 6)),
        Text(
          "${current.toStringAsFixed(1)}g",
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 13),
            fontWeight: FontWeight.w700,
            color: lightenColor(appColorNotifier.value, 0.45),
          ),
        ),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 11),
            color: lightenColor(appColorNotifier.value, 0.45),
          ),
        ),
        Text(
          "/ ${goal.toStringAsFixed(0)}g",
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 10),
            color: lightenColor(appColorNotifier.value, 0.45),
          ),
        ),
      ],
    );
  }

  // Builds the 3 macro goal gauges
  Widget _buildMacroGauges(Color appColor) {
    // hide gauges entirely if no goals set since the calories bar already shows the prompt
    if (!_goalsSet) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _goalProtein > 0
            ? _buildMacroGauge(
                label: "Protein",
                current: _totalMacro('protein'),
                goal: _goalProtein,
                color: lightenColor(appColor, 0.30),
              )
            : _buildMacroPlaceholder("Protein", appColor),
        _goalCarbs > 0
            ? _buildMacroGauge(
                label: "Carbs",
                current: _totalMacro('carbs'),
                goal: _goalCarbs,
                color: lightenColor(appColor, 0.30),
              )
            : _buildMacroPlaceholder("Carbs", appColor),
        _goalFat > 0
            ? _buildMacroGauge(
                label: "Fat",
                current: _totalMacro('fat'),
                goal: _goalFat,
                color: lightenColor(appColor, 0.30),
              )
            : _buildMacroPlaceholder("Fat", appColor),
      ],
    );
  }

  // Helper method that appears when the user has no chosen macro
  Widget _buildMacroPlaceholder(String label, Color appColor) {
    return frostedGlassCard(
      context,
      baseRadius: 16,
      child: TextButton.icon(
        onPressed: () async {
          // For guest users
          if (isGuest) {
            Guest.block(context);
            return;
          }
          await context.push('/settings/preferences');
          if (mounted) setState(() {});
        },
        icon: HugeIcon(
          icon: HugeIcons.strokeRoundedAddCircle,
          color: lightenColor(appColor, 0.30),
          size: Responsive.scale(context, 18),
        ),
        label: Text(
          "Set $label goal",
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 12),
            color: lightenColor(appColor, 0.30),
          ),
        ),
      ),
    );
  }

  Widget _buildMealSection(
    String mealKey,
    String title,
    List<Map<String, dynamic>> foods,
    Color accentColor,
  ) {
    final isCollapsed = _collapsed[mealKey] ?? false;
    final mealCal = _mealCalories(foods).round();
    double mealProtein = 0, mealCarbs = 0, mealFat = 0;
    for (var food in foods) {
      final m = FoodLoggingHelper.extractMacrosFromFood(food);
      mealProtein += m['protein'] ?? 0;
      mealCarbs += m['carbs'] ?? 0;
      mealFat += m['fat'] ?? 0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tapping anywhere on the header row toggles collapse
        GestureDetector(
          onTap: () {
            setState(() => _collapsed[mealKey] = !isCollapsed);
            _saveCollapsedState();
          },
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: EdgeInsets.only(
              top: Responsive.height(context, 18),
              bottom: Responsive.height(context, 10),
              left: Responsive.width(context, 4),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: Responsive.scale(context, 10),
                  height: Responsive.scale(context, 10),
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: Responsive.width(context, 8)),
                Text(
                  "${title.toUpperCase()} (${foods.length})",
                  style: GoogleFonts.manrope(
                    fontSize: Responsive.font(context, 14),
                    color: lightenColor(appColorNotifier.value, 0.45),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                // Calorie count only shows when something is logged
                if (mealCal > 0) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: "$mealCal",
                              style: GoogleFonts.manrope(
                                fontSize: Responsive.font(context, 18),
                                fontWeight: FontWeight.w800,
                                color: accentColor,
                                height: 1,
                              ),
                            ),
                            TextSpan(
                              text: " cal",
                              style: GoogleFonts.manrope(
                                fontSize: Responsive.font(context, 11),
                                color: lightenColor(
                                  appColorNotifier.value,
                                  0.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'P ${mealProtein.round()}g · C ${mealCarbs.round()}g · F ${mealFat.round()}g',
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 10),
                          color: lightenColor(appColorNotifier.value, 0.35),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: Responsive.width(context, 8)),
                ],
                AnimatedRotation(
                  turns: isCollapsed ? -0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowDown01,
                    color: lightenColor(appColorNotifier.value, 0.45),
                    size: Responsive.scale(context, 20),
                  ),
                ),
                SizedBox(width: Responsive.width(context, 4)),
              ],
            ),
          ),
        ),

        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          crossFadeState: isCollapsed
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (foods.isEmpty)
                Padding(
                  padding: EdgeInsets.only(
                    left: Responsive.width(context, 4),
                    bottom: Responsive.height(context, 6),
                  ),
                  child: Text(
                    "No foods logged",
                    style: GoogleFonts.manrope(
                      fontSize: Responsive.font(context, 13),
                      color: lightenColor(appColorNotifier.value, 0.45),
                    ),
                  ),
                )
              else
                ...foods.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final food = entry.value;
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: Responsive.height(context, 10),
                    ),
                    child: frostedGlassCard(
                      context,
                      baseRadius: 16,
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.width(context, 16),
                        vertical: Responsive.height(context, 14),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  food['brand_name'] != null
                                      ? '${food['brand_name']} - ${food['food_name'] ?? ''}'
                                      : (food['food_name'] ?? ''),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.manrope(
                                    fontSize: Responsive.font(context, 14),
                                    color: lightenColor(
                                      appColorNotifier.value,
                                      0.45,
                                    ),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: Responsive.height(context, 6)),
                                _buildMacroText(food),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _editServingSize(mealKey, foods, food),
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedEdit03,
                              color: lightenColor(appColorNotifier.value, 0.45),
                              size: Responsive.scale(context, 26),
                            ),
                          ),
                          SizedBox(width: Responsive.width(context, 10)),
                          GestureDetector(
                            onTap: () => _deleteFood(mealKey, idx, foods),
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedDelete02,
                              color: lightenColor(appColorNotifier.value, 0.45),
                              size: Responsive.scale(context, 26),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
          secondChild: const SizedBox.shrink(),
        ),

        SizedBox(height: Responsive.height(context, 8)),
        GestureDetector(
          onTap: () {
            if (isGuest) {
              Guest.block(context);
              return;
            }
            context.push(
              '/food-logging/log',
              extra: {
                'meal': mealKey,
                'currentDate': currentDate,
                'onFoodLogged': () async => await _refreshAndLoadFood(),
                'achievementId': 'food_search',
              },
            );
          },
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              vertical: Responsive.height(context, 13),
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                Responsive.scale(context, 14),
              ),
              border: Border.all(color: accentColor.withAlpha(80), width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedAdd01,
                  color: accentColor,
                  size: Responsive.font(context, 16),
                ),
                SizedBox(width: Responsive.width(context, 8)),
                Text(
                  "Log Food",
                  style: GoogleFonts.manrope(
                    fontSize: Responsive.font(context, 15),
                    color: accentColor,
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _loadUserDataFuture,
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState != ConnectionState.done;
        final appColor = appColorNotifier.value;
        final colors = _mealColors(appColor);

        return Container(
          decoration: BoxDecoration(gradient: buildThemeGradient()),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Skeletonizer(
              enabled: isLoading,
              effect: ShimmerEffect(
                baseColor: lightenColor(appColor, 0.3),
                highlightColor: lightenColor(appColor, 0.1),
                duration: const Duration(milliseconds: 1200),
              ),
              child: ListView(
                padding: EdgeInsets.only(
                  left: Responsive.centeredHorizontalPadding(context, 20),
                  right: Responsive.centeredHorizontalPadding(context, 20),
                  top:
                      MediaQuery.paddingOf(context).top +
                      Responsive.height(context, 16),
                  bottom: Responsive.height(context, 12),
                ),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DateNavigationRow(
                          currentDate: currentDate,
                          onDateChanged: (date) {
                            setState(() => currentDate = date);
                            loadFoodForDate(date);
                          },
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() {
                          _loadUserDataFuture = _refreshAndLoadFood();
                        }),
                        child: Container(
                          padding: EdgeInsets.all(
                            Responsive.scale(context, 12),
                          ),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: lightenColor(
                              appColorNotifier.value,
                              0.1,
                            ).withAlpha(20),
                            border: Border.all(
                              color: lightenColor(
                                appColorNotifier.value,
                                0.3,
                              ).withAlpha(180),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            Icons.refresh,
                            color: lightenColor(
                              appColorNotifier.value,
                              0.3,
                            ).withAlpha(180),
                            size: Responsive.font(context, 13),
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: Responsive.height(context, 16)),
                  _buildCaloriesBar(appColor),

                  SizedBox(height: Responsive.height(context, 20)),
                  _buildMacroGauges(appColor),

                  SizedBox(height: Responsive.height(context, 8)),

                  _buildMealSection(
                    "breakfast",
                    "Breakfast",
                    breakfastFoods,
                    colors[0],
                  ),
                  _buildMealSection("lunch", "Lunch", lunchFoods, colors[1]),
                  _buildMealSection("dinner", "Dinner", dinnerFoods, colors[2]),
                  _buildMealSection("snacks", "Snacks", snacksFoods, colors[3]),

                  SizedBox(height: Responsive.height(context, 24)),

                  // FatSecret terms require attribution to be visible without login
                  if (isGuest)
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () => launchUrl(
                              Uri.parse("https://platform.fatsecret.com"),
                            ),
                            child: Text(
                              "Powered by FatSecret",
                              style: GoogleFonts.manrope(
                                fontSize: Responsive.font(context, 11),
                                color: Colors.white24,
                                decoration: TextDecoration.underline,
                                decorationColor: Colors.white24,
                              ),
                            ),
                          ),
                          Text(
                            "  ·  ",
                            style: GoogleFonts.manrope(
                              fontSize: Responsive.font(context, 11),
                              color: Colors.white24,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => launchUrl(
                              Uri.parse("https://openfoodfacts.org"),
                            ),
                            child: Text(
                              "Open Food Facts (ODbL)",
                              style: GoogleFonts.manrope(
                                fontSize: Responsive.font(context, 11),
                                color: Colors.white24,
                                decoration: TextDecoration.underline,
                                decorationColor: Colors.white24,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Extra space so content clears the floating nav bar
                  SizedBox(height: Responsive.height(context, 100)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Renders a semi-circular progress indicator
class _SemiDonutPainter extends CustomPainter {
  final double progress; // completion percentage
  final Color trackColor; // background color
  final Color fillColor; // foreground color
  final double strokeWidth; // thickness of the line

  const _SemiDonutPainter({
    required this.progress,
    required this.trackColor,
    required this.fillColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Center point of the semi-circle (slightly lowered for visual balance)
    final center = Offset(size.width / 2, size.height * 0.85);

    // Radius adjusted so stroke doesn't overflow bounds
    final radius = (size.width - strokeWidth) / 2;

    // Paint for the background
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Paint for the progress
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Draw the full semi-circle background
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi, // start angle (180 degrees)
      math.pi, // sweep angle (another 180 degrees)
      false,
      trackPaint,
    );

    // Draw progress only if it exists
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        math.pi, // start from left side of semi-circle
        math.pi * progress, // scale fill based on progress
        false,
        fillPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_SemiDonutPainter old) =>
      // Only repaint if visual properties change
      old.progress != progress ||
      old.fillColor != fillColor ||
      old.trackColor != trackColor;
}
