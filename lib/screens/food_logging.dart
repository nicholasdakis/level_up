import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'dart:math' as math;
import '../globals.dart';
import '../utility/responsive.dart';
import '../utility/food_logging_helper.dart';
import '../services/user_data_manager.dart';

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

  // getters that read from currentUserData so goals are always up to date
  double get _goalCalories => (currentUserData?.caloriesGoal ?? 0).toDouble();
  double get _goalProtein => (currentUserData?.proteinGoal ?? 0).toDouble();
  double get _goalCarbs => (currentUserData?.carbsGoal ?? 0).toDouble();
  double get _goalFat => (currentUserData?.fatGoal ?? 0).toDouble();
  bool get _goalsSet =>
      currentUserData?.caloriesGoal !=
      null; // true only if the user has set at least a calorie goal

  @override
  void initState() {
    super.initState();
    _loadUserDataFuture = _loadUserDataAndInit();
    // Track that the user opened food logging
    trackTrivialAchievement("open_food_logging");
  }

  Future<void> _loadUserDataAndInit() async {
    if (currentUserData != null &&
        currentUserData!.uid == FirebaseAuth.instance.currentUser?.uid) {
      await userManager.refreshUserData();
      await _syncFoodData();
      return;
    }
    await userManager.loadUserData();
    await _syncFoodData();
  }

  Future<void> _syncFoodData() async {
    await userManager.refreshUserData();
    loadFoodForDate(currentDate);
  }

  void loadFoodForDate(DateTime date) {
    final dayData =
        currentUserData?.foodDataByDate[FoodLoggingHelper.formatDateKey(date)];
    setState(() {
      breakfastFoods = FoodLoggingHelper.castFoodList(dayData?['breakfast']);
      lunchFoods = FoodLoggingHelper.castFoodList(dayData?['lunch']);
      dinnerFoods = FoodLoggingHelper.castFoodList(dayData?['dinner']);
      snacksFoods = FoodLoggingHelper.castFoodList(dayData?['snacks']);
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
      final macros = FoodLoggingHelper.extractMacros(
        food['food_description'] as String? ?? '',
      );
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Delete food?",
          style: GoogleFonts.manrope(color: Colors.white),
        ),
        content: Text(
          "Are you sure you want to remove ${foods[idx]['food_name'] ?? 'this food'}?",
          style: GoogleFonts.manrope(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Delete",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      foods.removeAt(idx);
      final dateKey = FoodLoggingHelper.formatDateKey(currentDate);
      currentUserData?.foodDataByDate[dateKey]![mealKey] = foods;
    });
    await _saveFoodData("delete");
  }

  // Opens a dialog letting the user change the serving amount for a logged food
  // Scales all macros proportionally and saves the updated entry
  Future<void> _editServingSize(
    String mealKey,
    List<Map<String, dynamic>> foods,
    Map<String, dynamic> food,
  ) async {
    // Pull the current serving amount and unit out of food_description
    final serving = FoodLoggingHelper.parseServing(
      food['food_description'] as String? ?? '',
    );
    final currentAmt = serving['amount'] as double;
    final unit = serving['unit'] as String;

    // Pre-fill with the current amount, dropping the decimal if it's a whole number
    final controller = TextEditingController(
      text: currentAmt % 1 == 0
          ? currentAmt.toInt().toString()
          : currentAmt.toString(),
    );

    // Show the dialog and wait for the user to type a new amount and hit Save
    final newAmtStr = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          "Edit serving size",
          style: GoogleFonts.manrope(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Food name shown as subtitle so the user knows what they're editing
            Text(
              food['food_name'] as String? ?? '',
              style: GoogleFonts.manrope(color: Colors.white70, fontSize: 13),
            ),
            SizedBox(height: Responsive.height(context, 12)),
            // Numeric input with the unit (e.g. "g", "oz") shown as a suffix
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: GoogleFonts.manrope(color: Colors.white),
              decoration: InputDecoration(
                suffixText: unit,
                suffixStyle: GoogleFonts.manrope(color: Colors.white54),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white38),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text("Save", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    controller.dispose();
    // the user cancelled or typed something invalid
    if (newAmtStr == null || newAmtStr.isEmpty) return;
    final newAmt = double.tryParse(newAmtStr);
    if (newAmt == null || newAmt <= 0) return;
    // No change, skip the write
    if (newAmt == currentAmt) return;

    // Scale every macro by the ratio of new amount to old amount
    final baseMacros = FoodLoggingHelper.extractMacros(
      food['food_description'] as String? ?? '',
    );
    final scaled = FoodLoggingHelper.scaleFood(baseMacros, currentAmt, newAmt);
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
      final dateKey = FoodLoggingHelper.formatDateKey(currentDate);
      currentUserData?.foodDataByDate[dateKey]![mealKey] = foods;
    });
    await _saveFoodData("edit"); // store the changes
  }

  Future<void> _saveFoodData(String addOrDelete) async {
    if (currentUserData == null) return;
    final dateKey = FoodLoggingHelper.formatDateKey(currentDate);
    final currentDateData = {
      dateKey: currentUserData!.foodDataByDate[dateKey]!,
    };
    await userManager.updateFoodDataByDate(
      currentDateData,
      context: context,
      isBeingDeleted: addOrDelete == "delete",
      isBeingEdited: addOrDelete == "edit",
    );
  }

  Widget _buildMacroText(Map<String, dynamic> food) {
    final macros = FoodLoggingHelper.extractMacros(
      food['food_description'] as String? ?? '',
    );
    final serving = FoodLoggingHelper.parseServing(
      food['food_description'] as String? ?? '',
    );
    final servingAmt = serving['amount'] as double;
    final servingStr = servingAmt % 1 == 0
        ? servingAmt.toInt().toString()
        : servingAmt.toString();
    final cal = num.tryParse(food['calories'].toString()) ?? 0;
    final parts = <String>['$servingStr ${serving['unit']} - $cal kcal'];
    if ((macros['protein'] ?? 0) > 0) {
      parts.add('P: ${macros['protein']!.toStringAsFixed(1)}g');
    }
    if ((macros['carbs'] ?? 0) > 0) {
      parts.add('C: ${macros['carbs']!.toStringAsFixed(1)}g');
    }
    if ((macros['fat'] ?? 0) > 0) {
      parts.add('F: ${macros['fat']!.toStringAsFixed(1)}g');
    }
    return Text(
      parts.join(' - '),
      style: GoogleFonts.manrope(
        fontSize: Responsive.font(context, 12),
        color: Colors.white54,
      ),
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
              // waits for the user to come back from preferences tab to update the user data with the new data
              await context.push('/settings/preferences');
              await userManager.refreshUserData();
              await _syncFoodData();
            },
            icon: Icon(
              Icons.track_changes_outlined,
              color: lightenColor(appColor, 0.30),
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
    final barColor = lightenColor(appColor, 0.30);
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
                  color: Colors.white,
                  height: 1,
                ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: Responsive.height(context, 4)),
                child: Text(
                  " / ${_goalCalories.round()} kcal",
                  style: GoogleFonts.manrope(
                    fontSize: Responsive.font(context, 13),
                    color: Colors.white38,
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
                      color: isOver ? Colors.redAccent : barColor,
                    ),
                  ),
                  Text(
                    "daily goal",
                    style: GoogleFonts.manrope(
                      fontSize: Responsive.font(context, 11),
                      color: Colors.white24,
                    ),
                  ),
                ],
              ),
            ],
          ),

          SizedBox(height: Responsive.height(context, 14)),

          // Progress bar
          ClipRRect(
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
                      color: isOver ? Colors.redAccent : barColor,
                      borderRadius: BorderRadius.circular(
                        Responsive.scale(context, 6),
                      ),
                    ),
                  ),
                ),
              ],
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
              icon: Icon(
                Icons.bar_chart_rounded,
                color: barColor,
                size: Responsive.font(context, 16),
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
                backgroundColor: barColor.withAlpha(25),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    Responsive.scale(context, 12),
                  ),
                  side: BorderSide(
                    color: barColor.withAlpha(60),
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: gaugeSize,
          height: gaugeSize * 0.6,
          child: ClipRect(
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
        ),
        SizedBox(height: Responsive.height(context, 6)),
        Text(
          "${current.toStringAsFixed(1)}g",
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 13),
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 11),
            color: Colors.white38,
          ),
        ),
        Text(
          "/ ${goal.toStringAsFixed(0)}g",
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 10),
            color: Colors.white24,
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
          await context.push('/settings/preferences');
          await userManager.refreshUserData();
          await _syncFoodData();
        },
        icon: Icon(
          Icons.add_circle_outline,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tapping anywhere on the header row toggles collapse
        GestureDetector(
          onTap: () => setState(() => _collapsed[mealKey] = !isCollapsed),
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
                    color: Colors.white54,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                // Calorie count only shows when something is logged
                if (mealCal > 0) ...[
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
                          text: " kcal",
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 11),
                            color: Colors.white38,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: Responsive.width(context, 8)),
                ],
                AnimatedRotation(
                  turns: isCollapsed ? -0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.white38,
                    size: Responsive.scale(context, 20),
                  ),
                ),
                SizedBox(width: Responsive.width(context, 4)),
              ],
            ),
          ),
        ),

        // Only the food tiles collapse, Log Food always stays below
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
                      color: Colors.white24,
                    ),
                  ),
                )
              else
                ...foods.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final food = entry.value;
                  return Dismissible(
                    key: ValueKey("${mealKey}_$idx${food['food_name']}"),
                    background: Container(
                      decoration: BoxDecoration(
                        color: Colors.red.withAlpha(180),
                        borderRadius: BorderRadius.circular(
                          Responsive.scale(context, 16),
                        ),
                      ),
                      alignment: Alignment.centerRight,
                      padding: EdgeInsets.only(
                        right: Responsive.width(context, 20),
                      ),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) async {
                      await _deleteFood(mealKey, idx, foods);
                      return false;
                    },
                    child: Padding(
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
                            Icon(
                              Icons.restaurant_outlined,
                              color: accentColor,
                              size: Responsive.scale(context, 20),
                            ),
                            SizedBox(width: Responsive.width(context, 12)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    food['brand_name'] != null
                                        ? '${food['brand_name']} - ${food['food_name'] ?? ''}'
                                        : (food['food_name'] ?? ''),
                                    style: GoogleFonts.manrope(
                                      fontSize: Responsive.font(context, 14),
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(
                                    height: Responsive.height(context, 4),
                                  ),
                                  _buildMacroText(food),
                                ],
                              ),
                            ),
                            IconButton(
                              // Edit serving size button
                              icon: Icon(
                                Icons.edit_outlined,
                                color: Colors.white54,
                                size: Responsive.scale(context, 18),
                              ),
                              onPressed: () =>
                                  _editServingSize(mealKey, foods, food),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            SizedBox(width: Responsive.width(context, 8)),
                            // Delete food button
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent.withAlpha(180),
                                size: Responsive.scale(context, 18),
                              ),
                              onPressed: () => _deleteFood(mealKey, idx, foods),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
          secondChild: const SizedBox.shrink(),
        ),

        // Log Food is outside AnimatedCrossFade so collapsing never hides it
        Padding(
          padding: EdgeInsets.only(bottom: Responsive.height(context, 4)),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                context.push(
                  '/food-logging/log',
                  extra: {
                    'meal': mealKey,
                    'currentDate': currentDate,
                    'onFoodLogged': () async => await _syncFoodData(),
                    // passed to LogFoodScreen so it knows which achievement to update on log
                    'achievementId': 'food_search',
                  },
                );
              },
              icon: Icon(
                Icons.add,
                color: accentColor,
                size: Responsive.font(context, 17),
              ),
              label: Text(
                "Log Food",
                style: GoogleFonts.manrope(
                  fontSize: Responsive.font(context, 14),
                  color: accentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: accentColor.withAlpha(80), width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    Responsive.scale(context, 14),
                  ),
                ),
                padding: EdgeInsets.symmetric(
                  vertical: Responsive.height(context, 12),
                ),
              ),
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
            appBar: AppBar(
              scrolledUnderElevation: 0,
              backgroundColor: darkenColor(appColor, 0.025),
              centerTitle: true,
              toolbarHeight: Responsive.buttonHeight(context, 120),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => context.pop(),
              ),
              title: createTitle("Food Logging", context),
              bottom: PreferredSize(
                preferredSize: Size.fromHeight(Responsive.height(context, 1)),
                child: Container(
                  height: Responsive.height(context, 1),
                  color: Colors.white.withAlpha(25),
                ),
              ),
            ),
            body: Skeletonizer(
              enabled: isLoading,
              effect: ShimmerEffect(
                baseColor: lightenColor(appColor, 0.3),
                highlightColor: lightenColor(appColor, 0.1),
                duration: const Duration(milliseconds: 1200),
              ),
              child: ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.width(context, 16),
                  vertical: Responsive.height(context, 12),
                ),
                children: [
                  DateNavigationRow(
                    currentDate: currentDate,
                    onDateChanged: (date) {
                      setState(() => currentDate = date);
                      loadFoodForDate(date);
                    },
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
