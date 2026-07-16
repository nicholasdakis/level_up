import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/providers/user_data_provider.dart';
import '/providers/user_data_loaded_provider.dart';
import '../providers/food_logs_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'dart:math' as math;
import '../globals.dart';
import '../guest.dart';
import '../models/food_log.dart';
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

class FoodLogging extends ConsumerStatefulWidget {
  const FoodLogging({super.key});

  @override
  ConsumerState<FoodLogging> createState() => _FoodLoggingState();
}

class _FoodLoggingState extends ConsumerState<FoodLogging> {
  Color get appColor => ref.watch(
    userDataProvider.select((s) => s.value?.appColor ?? defaultAppColor),
  );

  DateTime currentDate = DateTime.now();

  List<FoodLog> breakfastFoods = const [];
  List<FoodLog> lunchFoods = const [];
  List<FoodLog> dinnerFoods = const [];
  List<FoodLog> snacksFoods = const [];

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

  Future<void> _loadMicrosExpanded() async {
    final val = await _prefs.getBool(SharedPreferencesKey.microsExpanded);
    if (val != null && mounted) setState(() => _microsExpanded = val);
  }

  void _saveMicrosExpanded(bool val) {
    _prefs.setBool(SharedPreferencesKey.microsExpanded, val);
  }

  // getters for nutrition goals
  double get _goalCalories =>
      (ref.watch(userDataProvider.select((s) => s.value?.caloriesGoal)) ?? 0)
          .toDouble();
  double get _goalProtein =>
      (ref.watch(userDataProvider.select((s) => s.value?.proteinGoal)) ?? 0)
          .toDouble();
  double get _goalCarbs =>
      (ref.watch(userDataProvider.select((s) => s.value?.carbsGoal)) ?? 0)
          .toDouble();
  double get _goalFat =>
      (ref.watch(userDataProvider.select((s) => s.value?.fatGoal)) ?? 0)
          .toDouble();
  double get _goalFiber =>
      (ref.watch(userDataProvider.select((s) => s.value?.fiberGoal)) ?? 0)
          .toDouble();
  double get _goalSugar =>
      (ref.watch(userDataProvider.select((s) => s.value?.sugarGoal)) ?? 0)
          .toDouble();
  double get _goalSodium =>
      (ref.watch(userDataProvider.select((s) => s.value?.sodiumGoal)) ?? 0)
          .toDouble();
  bool get _goalsSet =>
      ref.watch(userDataProvider.select((s) => s.value?.caloriesGoal)) != null;
  bool _microsExpanded = false; // overridden to true for guests in initState

  @override
  void initState() {
    super.initState();
    FirebaseAnalytics.instance.logScreenView(
      screenName: '/food-logging',
      screenClass: 'FoodLogging',
    );
    if (isGuest) {
      _microsExpanded = true;
    } else {
      _loadCollapsedState();
      _loadMicrosExpanded();
    }
    // Track that the user opened food logging
    trackTrivialAchievement("open_food_logging");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isGuest) ref.read(foodLogsProvider.notifier).refresh();
    });
  }

  Future<void> _refreshAndLoadFood() async {
    await ref.read(foodLogsProvider.notifier).refresh();
    loadFoodForDate(currentDate);
  }

  void loadFoodForDate(DateTime date) {
    setState(() => currentDate = date);
  }

  // Helper method for getting calories per meal type
  double _mealCalories(List<FoodLog> foods) {
    double total = 0;
    for (var food in foods) {
      total += (food.calories ?? 0).toDouble();
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

  Future<void> _deleteFood(String mealKey, int idx, List<FoodLog> foods) async {
    if (isGuest) {
      Guest.block(
        context,
        title: 'Sign up to log food',
        description:
            'Create a free account to track calories, macros, and build your nutrition history.',
      );
      return;
    } // For guest users
    final confirmed = await showFrostedAlertDialog<bool>(
      context: context,
      appColor: appColor,
      title: "Delete food?",
      content: Text(
        "Are you sure you want to remove ${foods[idx].foodName.isNotEmpty ? foods[idx].foodName : 'this food'}?",
        style: GoogleFonts.manrope(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(false),
          child: Text("Cancel", style: dialogButtonStyle()),
        ),
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
          child: Text("Delete", style: dialogButtonStyle(confirm: true)),
        ),
      ],
    );
    if (confirmed != true) return;

    final food = foods[idx];
    setState(() => foods.removeAt(idx));
    final success = await ref
        .read(foodLogsProvider.notifier)
        .deleteFoodLog(food);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? "Food deleted successfully."
              : (isConnected
                    ? "Error deleting food."
                    : "No connection. Please try again when online."),
        ),
        duration: snackBarDuration,
      ),
    );
  }

  Future<void> _moveFood(String fromMeal, FoodLog food) async {
    const meals = ['breakfast', 'lunch', 'dinner', 'snacks'];
    const labels = ['Breakfast', 'Lunch', 'Dinner', 'Snacks'];
    final accent = lightenColor(appColor, 0.45);
    final dim = lightenColor(appColor, 0.35);

    final toMeal = await showFrostedDialog<String>(
      context: context,
      appColor: appColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Move to',
            style: GoogleFonts.manrope(
              color: accent,
              fontSize: Responsive.font(context, 15),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: Responsive.height(context, 12)),
          for (int i = 0; i < meals.length; i++)
            if (meals[i] != fromMeal)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () =>
                    Navigator.of(context, rootNavigator: true).pop(meals[i]),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: Responsive.height(context, 12),
                  ),
                  child: Text(
                    labels[i],
                    style: GoogleFonts.manrope(
                      color: dim,
                      fontSize: Responsive.font(context, 14),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
    if (toMeal == null || !mounted) return;

    final mealList = _mealList(fromMeal);
    final toList = _mealList(toMeal);
    setState(() {
      mealList.remove(food);
      toList.add(food.copyWith(meal: toMeal));
    });
    await _saveFoodData('move');
  }

  List<FoodLog> _mealList(String meal) {
    switch (meal) {
      case 'breakfast':
        return breakfastFoods;
      case 'lunch':
        return lunchFoods;
      case 'dinner':
        return dinnerFoods;
      default:
        return snacksFoods;
    }
  }

  void _showFoodMenu(
    BuildContext btnContext,
    String mealKey,
    List<FoodLog> foods,
    FoodLog food,
    int idx,
  ) async {
    final accent = lightenColor(appColor, 0.45);

    Widget menuItem(IconData icon, String label, String value) =>
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(btnContext, rootNavigator: true).pop(value),
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: Responsive.height(context, 14),
            ),
            child: Row(
              children: [
                HugeIcon(
                  icon: icon,
                  color: accent,
                  size: Responsive.scale(context, 20),
                ),
                SizedBox(width: Responsive.width(context, 14)),
                Text(
                  label,
                  style: GoogleFonts.manrope(
                    color: accent,
                    fontSize: Responsive.font(context, 14),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );

    final result = await showFrostedDialog<String>(
      context: btnContext,
      appColor: appColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            food.foodName,
            style: GoogleFonts.manrope(
              color: accent,
              fontSize: Responsive.font(context, 15),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: Responsive.height(context, 4)),
          Divider(color: Colors.white12),
          menuItem(HugeIcons.strokeRoundedEdit03, 'Edit Serving', 'edit'),
          menuItem(HugeIcons.strokeRoundedArrowRight01, 'Move Food', 'move'),
        ],
      ),
    );

    if (!mounted) return;
    if (result == 'edit') await _editServingSize(mealKey, foods, food);
    if (result == 'move') await _moveFood(mealKey, food);
  }

  // Opens a dialog letting the user change the serving amount for a logged food
  // Scales all macros proportionally and saves the updated entry
  Future<void> _editServingSize(
    String mealKey,
    List<FoodLog> foods,
    FoodLog food,
  ) async {
    if (isGuest) {
      Guest.block(
        context,
        title: 'Sign up to log food',
        description:
            'Create a free account to track calories, macros, and build your nutrition history.',
      );
      return;
    }
    final serving = FoodLoggingHelper.parseServingFromLog(food);
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
      appColor: appColor,
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

    final updated = FoodLog(
      id: food.id,
      date: food.date,
      meal: food.meal,
      foodName: food.foodName,
      brandName: food.brandName,
      foodDescription: newDescription,
      calories: scaled['calories']!.round(),
      protein: scaled['protein'],
      carbs: scaled['carbs'],
      fat: scaled['fat'],
      fiber:
          result.macroOverrides?['fiber'] ??
          (food.fiber != null ? food.fiber! * (newAmt / currentAmt) : null),
      sugar:
          result.macroOverrides?['sugar'] ??
          (food.sugar != null ? food.sugar! * (newAmt / currentAmt) : null),
      sodium:
          result.macroOverrides?['sodium'] ??
          (food.sodium != null ? food.sodium! * (newAmt / currentAmt) : null),
      servingSize: '$newAmt $unit',
      loggedAt: food.loggedAt,
    );
    setState(() {
      final idx = foods.indexOf(food);
      if (idx != -1) foods[idx] = updated;
    });
    await _saveFoodData("edit"); // store the changes
  }

  Future<void> _saveFoodData(String action) async {
    final dateKey = FoodLoggingHelper.formatDateKey(currentDate);
    final mealMap = {
      'breakfast': breakfastFoods,
      'lunch': lunchFoods,
      'dinner': dinnerFoods,
      'snacks': snacksFoods,
    };
    final success = await ref
        .read(foodLogsProvider.notifier)
        .upsertForDate(dateKey, mealMap);
    if (!mounted) return;
    final msg = success
        ? (action == "delete"
              ? "Food deleted successfully."
              : action == "move"
              ? "Food moved successfully."
              : action == "edit"
              ? "Food edited successfully."
              : "Food logged successfully.")
        : (isConnected
              ? "Error updating food data."
              : "No connection. Please try again when online.");
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), duration: snackBarDuration));
  }

  String _formatLoggedAt(String loggedAt) {
    try {
      final dt = DateTime.parse(loggedAt).toLocal();
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour < 12 ? 'AM' : 'PM';
      return '$hour:$minute $period';
    } catch (_) {
      return '';
    }
  }

  Widget _buildNutritionChips(FoodLog food, Color appColor) {
    final macros = FoodLoggingHelper.extractMacrosFromFood(food);
    final serving = FoodLoggingHelper.parseServingFromLog(food);
    final servingAmt = serving['amount'] as double;
    final servingStr = servingAmt % 1 == 0
        ? servingAmt.toInt().toString()
        : servingAmt.toString();
    final cal = food.calories ?? 0;
    final base = appColor;
    final dim = lightenColor(base, 0.35);

    Widget chip(String label, double value, {String unit = 'g'}) {
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
          '$label ${value.toStringAsFixed(1)}$unit',
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
            if (food.fiber != null && food.fiber! > 0)
              chip('Fiber', food.fiber!),
            if (food.sugar != null && food.sugar! > 0)
              chip('Sugar', food.sugar!),
            if (food.sodium != null && food.sodium! > 0)
              chip('Na', food.sodium!, unit: 'mg'),
          ],
        ),
      ],
    );
  }

  Future<void> _editGoal(BuildContext context, String type) async {
    if (isGuest) {
      Guest.block(
        context,
        title: 'Sign up to log food',
        description:
            'Create a free account to track calories, macros, and build your nutrition history.',
      );
      return;
    }
    final current = switch (type) {
      'calories' => ref.read(userDataProvider).value?.caloriesGoal,
      'protein' => ref.read(userDataProvider).value?.proteinGoal,
      'carbs' => ref.read(userDataProvider).value?.carbsGoal,
      'fat' => ref.read(userDataProvider).value?.fatGoal,
      _ => null,
    };
    final label = switch (type) {
      'calories' => 'Calorie Goal',
      'protein' => 'Protein Goal',
      'carbs' => 'Carbs Goal',
      'fat' => 'Fat Goal',
      _ => 'Goal',
    };
    final unit = type == 'calories' ? 'kcal' : 'g';
    final ctrl = TextEditingController(text: current?.toString() ?? '');

    final result = await showFrostedDialog<int>(
      context: context,
      appColor: appColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.manrope(
              color: lightenColor(appColor, 0.45),
              fontSize: Responsive.font(context, 16),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: Responsive.height(context, 16)),
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              color: lightenColor(appColor, 0.45),
              fontSize: Responsive.font(context, 24),
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              suffixText: unit,
              suffixStyle: GoogleFonts.manrope(
                color: lightenColor(appColor, 0.35),
                fontSize: Responsive.font(context, 14),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: lightenColor(appColor, 0.45)),
              ),
            ),
          ),
          SizedBox(height: Responsive.height(context, 8)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).pop(null),
                child: Text('Cancel', style: dialogButtonStyle()),
              ),
              TextButton(
                onPressed: () {
                  final val = int.tryParse(ctrl.text.trim());
                  Navigator.of(context, rootNavigator: true).pop(val);
                },
                child: Text('Save', style: dialogButtonStyle(confirm: true)),
              ),
            ],
          ),
        ],
      ),
    );

    if (result != null) {
      await ref
          .read(userDataProvider.notifier)
          .updateNutritionGoals(
            caloriesGoal: type == 'calories' ? result : null,
            proteinGoal: type == 'protein' ? result : null,
            carbsGoal: type == 'carbs' ? result : null,
            fatGoal: type == 'fat' ? result : null,
            context: context,
          );
      if (mounted) setState(() {});
    }
  }

  Widget _buildAnalyticsButton(Color appColor, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          vertical: Responsive.height(context, 14),
          horizontal: Responsive.width(context, 24),
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Responsive.scale(context, 14)),
          color: lightenColor(appColor, 0.1).withAlpha(40),
          border: Border.all(
            color: lightenColor(appColor, 0.35).withAlpha(160),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedAnalytics01,
              color: lightenColor(appColor, 0.45),
              size: Responsive.font(context, 20),
            ),
            SizedBox(width: Responsive.width(context, 8)),
            Text(
              "View Analytics",
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 15),
                fontWeight: FontWeight.w800,
                color: lightenColor(appColor, 0.45),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Calories bar which also has a "View Analytics button
  Widget _buildCaloriesBar(Color appColor) {
    if (isGuest) {
      return GestureDetector(
        onTap: () => Guest.block(
          context,
          title: 'Sign up to log food',
          description:
              'Create a free account to track calories, macros, and build your nutrition history.',
        ),
        child: Stack(
          children: [
            IgnorePointer(
              child: Opacity(
                opacity: 0.35,
                child: frostedGlassCard(
                  context,
                  color: appColor,
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
                          Text(
                            '1589',
                            style: GoogleFonts.manrope(
                              fontSize: Responsive.font(context, 36),
                              fontWeight: FontWeight.w800,
                              color: lightenColor(appColor, 0.45),
                              height: 1,
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: Responsive.height(context, 4),
                            ),
                            child: Text(
                              ' / 2000 kcal',
                              style: GoogleFonts.manrope(
                                fontSize: Responsive.font(context, 13),
                                color: lightenColor(appColor, 0.45),
                              ),
                            ),
                          ),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '411 left',
                                style: GoogleFonts.manrope(
                                  fontSize: Responsive.font(context, 13),
                                  fontWeight: FontWeight.w600,
                                  color: lightenColor(appColor, 0.45),
                                ),
                              ),
                              Text(
                                'daily goal',
                                style: GoogleFonts.manrope(
                                  fontSize: Responsive.font(context, 11),
                                  color: lightenColor(appColor, 0.45),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: Responsive.height(context, 14)),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          Responsive.scale(context, 6),
                        ),
                        child: Stack(
                          children: [
                            Container(
                              height: Responsive.height(context, 8),
                              width: double.infinity,
                              color: Colors.white.withAlpha(18),
                            ),
                            FractionallySizedBox(
                              widthFactor: 0.79,
                              child: Container(
                                height: Responsive.height(context, 8),
                                color: lightenColor(appColor, 0.45),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: Responsive.height(context, 16)),
                      _buildAnalyticsButton(
                        appColor,
                        () => Guest.block(
                          context,
                          title: 'Sign up to track nutrition',
                          description:
                              'Create a free account to view your calorie and macro trends over time.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            guestLockOverlay(context, appColor),
          ],
        ),
      );
    }

    // if no goals set, show a prompt to open the goals dialog
    if (!_goalsSet) {
      return frostedGlassCard(
        context,
        color: appColor,
        baseRadius: 20,
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.width(context, 20),
          vertical: Responsive.height(context, 18),
        ),
        child: SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: () async {
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
      color: appColor,
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
                  color: lightenColor(appColor, 0.45),
                  height: 1,
                ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: Responsive.height(context, 4)),
                child: Row(
                  children: [
                    Text(
                      " / ${_goalCalories.round()} kcal",
                      style: GoogleFonts.manrope(
                        fontSize: Responsive.font(context, 13),
                        color: lightenColor(appColor, 0.45),
                      ),
                    ),
                    SizedBox(width: Responsive.width(context, 4)),
                    GestureDetector(
                      onTap: () => _editGoal(context, 'calories'),
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedPencilEdit01,
                        color: Colors.white24,
                        size: Responsive.scale(context, 13),
                      ),
                    ),
                  ],
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
                      color: isOver ? lightenColor(appColor, 0.45) : barColor,
                    ),
                  ),
                  Text(
                    "daily goal",
                    style: GoogleFonts.manrope(
                      fontSize: Responsive.font(context, 11),
                      color: lightenColor(appColor, 0.45),
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
                        color: isOver ? lightenColor(appColor, 0.45) : barColor,
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
          _buildAnalyticsButton(appColor, () {
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
          }),
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
            color: lightenColor(appColor, 0.45),
          ),
        ),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 11),
            color: lightenColor(appColor, 0.45),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "/ ${goal.toStringAsFixed(0)}g",
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 10),
                color: lightenColor(appColor, 0.45),
              ),
            ),
            SizedBox(width: Responsive.width(context, 3)),
            GestureDetector(
              onTap: () => _editGoal(context, label.toLowerCase()),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedPencilEdit01,
                color: Colors.white24,
                size: Responsive.scale(context, 10),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Builds the 3 macro goal gauges
  Widget _buildMacroGauges(Color appColor) {
    if (isGuest) {
      final color = lightenColor(appColor, 0.30);
      return GestureDetector(
        onTap: () => Guest.block(
          context,
          title: 'Sign up to track macros',
          description:
              'Create a free account to track calories, macros, and build your nutrition history.',
        ),
        child: Stack(
          children: [
            IgnorePointer(
              child: Opacity(
                opacity: 0.35,
                child: Row(
                  children: [
                    Expanded(
                      child: _buildMacroGauge(
                        label: 'Protein',
                        current: 115,
                        goal: 160,
                        color: color,
                      ),
                    ),
                    SizedBox(width: Responsive.width(context, 8)),
                    Expanded(
                      child: _buildMacroGauge(
                        label: 'Carbs',
                        current: 146,
                        goal: 200,
                        color: color,
                      ),
                    ),
                    SizedBox(width: Responsive.width(context, 8)),
                    Expanded(
                      child: _buildMacroGauge(
                        label: 'Fat',
                        current: 55,
                        goal: 55,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            guestLockOverlay(context, appColor),
          ],
        ),
      );
    }
    // hide gauges entirely if no goals set since the calories bar already shows the prompt
    if (!_goalsSet) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: _goalProtein > 0
              ? _buildMacroGauge(
                  label: "Protein",
                  current: _totalMacro('protein'),
                  goal: _goalProtein,
                  color: lightenColor(appColor, 0.30),
                )
              : _buildMacroPlaceholder("Protein", appColor),
        ),
        SizedBox(width: Responsive.width(context, 8)),
        Expanded(
          child: _goalCarbs > 0
              ? _buildMacroGauge(
                  label: "Carbs",
                  current: _totalMacro('carbs'),
                  goal: _goalCarbs,
                  color: lightenColor(appColor, 0.30),
                )
              : _buildMacroPlaceholder("Carbs", appColor),
        ),
        SizedBox(width: Responsive.width(context, 8)),
        Expanded(
          child: _goalFat > 0
              ? _buildMacroGauge(
                  label: "Fat",
                  current: _totalMacro('fat'),
                  goal: _goalFat,
                  color: lightenColor(appColor, 0.30),
                )
              : _buildMacroPlaceholder("Fat", appColor),
        ),
      ],
    );
  }

  // Helper method that appears when the user has no chosen macro
  Widget _buildMacroPlaceholder(String label, Color appColor) {
    return frostedGlassCard(
      context,
      color: appColor,
      baseRadius: 16,
      child: TextButton.icon(
        onPressed: () async {
          // For guest users
          if (isGuest) {
            Guest.block(
              context,
              title: 'Sign up to log food',
              description:
                  'Create a free account to track calories, macros, and build your nutrition history.',
            );
            return;
          }
          await context.push('/settings/preferences');
          if (mounted) setState(() {});
        },
        icon: HugeIcon(
          icon: HugeIcons.strokeRoundedAddCircle,
          color: lightenColor(appColor, 0.30),
          size: Responsive.scale(context, 14),
        ),
        label: Text(
          "Set $label",
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 11),
            color: lightenColor(appColor, 0.30),
          ),
        ),
      ),
    );
  }

  Future<void> _editMicroGoals() async {
    final fiberCtrl = TextEditingController(
      text: _goalFiber > 0 ? _goalFiber.toInt().toString() : '',
    );
    final sugarCtrl = TextEditingController(
      text: _goalSugar > 0 ? _goalSugar.toInt().toString() : '',
    );
    final sodiumCtrl = TextEditingController(
      text: _goalSodium > 0 ? _goalSodium.toInt().toString() : '',
    );

    Widget field(TextEditingController ctrl, String label, String unit) =>
        Padding(
          padding: EdgeInsets.symmetric(
            vertical: Responsive.height(context, 6),
          ),
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(5),
            ],
            style: GoogleFonts.manrope(
              color: lightenColor(appColor, 0.45),
              fontSize: Responsive.font(context, 20),
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              labelText: '$label ($unit)',
              labelStyle: TextStyle(color: Colors.white54),
              floatingLabelStyle: TextStyle(color: Colors.white70),
              suffixText: unit,
              suffixStyle: GoogleFonts.manrope(
                color: lightenColor(appColor, 0.35),
                fontSize: Responsive.font(context, 14),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: lightenColor(appColor, 0.45)),
              ),
            ),
          ),
        );

    // capture values before pop so controllers are not read after dispose
    int? savedFiber, savedSugar, savedSodium;
    bool didSave = false;

    await showFrostedAlertDialog(
      context: context,
      appColor: appColor,
      title: 'Micro Goals',
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            field(fiberCtrl, 'Fiber', 'g'),
            field(sugarCtrl, 'Sugar', 'g'),
            field(sodiumCtrl, 'Sodium', 'mg'),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: Text('Cancel', style: dialogButtonStyle()),
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
        ),
        TextButton(
          child: Text('Save', style: dialogButtonStyle(confirm: true)),
          onPressed: () {
            savedFiber = int.tryParse(fiberCtrl.text.trim());
            savedSugar = int.tryParse(sugarCtrl.text.trim());
            savedSodium = int.tryParse(sodiumCtrl.text.trim());
            didSave = true;
            Navigator.of(context, rootNavigator: true).pop();
          },
        ),
      ],
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      fiberCtrl.dispose();
      sugarCtrl.dispose();
      sodiumCtrl.dispose();
    });

    if (!didSave) return;
    await ref
        .read(userDataProvider.notifier)
        .updateNutritionGoals(
          fiberGoal: savedFiber,
          sugarGoal: savedSugar,
          sodiumGoal: savedSodium,
          context: mounted ? context : null,
        );
    if (mounted) setState(() {});
  }

  // Expandable card showing fiber/sugar/sodium progress against goals
  Widget _buildMicroGoalsRow() {
    if (!_goalsSet) return const SizedBox.shrink();

    final accent = lightenColor(appColor, 0.45);
    final dim = lightenColor(appColor, 0.35);
    final color = lightenColor(appColor, 0.30);

    Widget microBar(String label, double current, double goal, String unit) {
      final progress = (current / goal).clamp(0.0, 1.0);
      final isOver = current > goal;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: Responsive.font(context, 12),
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
              Text(
                '${current.toStringAsFixed(unit == 'mg' ? 0 : 1)}$unit / ${goal.toStringAsFixed(0)}$unit',
                style: GoogleFonts.manrope(
                  fontSize: Responsive.font(context, 11),
                  color: dim,
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.height(context, 4)),
          ClipRRect(
            borderRadius: BorderRadius.circular(Responsive.scale(context, 4)),
            child: Stack(
              children: [
                Container(
                  height: Responsive.height(context, 3),
                  width: double.infinity,
                  color: Colors.white.withAlpha(18),
                ),
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    height: Responsive.height(context, 3),
                    color: isOver ? accent : color,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final totalFiber = _totalMacro('fiber');
    final totalSugar = _totalMacro('sugar');
    final totalSodium = _totalMacro('sodium');
    final noGoals = _goalFiber == 0 && _goalSugar == 0 && _goalSodium == 0;

    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 220),
      crossFadeState: _microsExpanded
          ? CrossFadeState.showFirst
          : CrossFadeState.showSecond,
      firstChild: Padding(
        padding: EdgeInsets.only(top: Responsive.height(context, 8)),
        child: Stack(
          children: [
            IgnorePointer(
              ignoring: isGuest,
              child: Opacity(
                opacity: isGuest ? 0.35 : 1.0,
                child: frostedGlassCard(
                  context,
                  color: appColor,
                  baseRadius: 16,
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.width(context, 16),
                    vertical: Responsive.height(context, 14),
                  ),
                  child: noGoals
                      ? SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            onPressed: _editMicroGoals,
                            icon: HugeIcon(
                              icon: HugeIcons.strokeRoundedAddCircle,
                              color: color,
                              size: Responsive.scale(context, 14),
                            ),
                            label: Text(
                              'Set micro goals',
                              style: GoogleFonts.manrope(
                                fontSize: Responsive.font(context, 12),
                                color: color,
                              ),
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                GestureDetector(
                                  onTap: _editMicroGoals,
                                  child: HugeIcon(
                                    icon: HugeIcons.strokeRoundedPencilEdit01,
                                    color: Colors.white24,
                                    size: Responsive.scale(context, 13),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: Responsive.height(context, 4)),
                            if (_goalFiber > 0) ...[
                              microBar('Fiber', totalFiber, _goalFiber, 'g'),
                              SizedBox(height: Responsive.height(context, 12)),
                            ],
                            if (_goalSugar > 0) ...[
                              microBar('Sugar', totalSugar, _goalSugar, 'g'),
                              SizedBox(height: Responsive.height(context, 12)),
                            ],
                            if (_goalSodium > 0)
                              microBar(
                                'Sodium',
                                totalSodium,
                                _goalSodium,
                                'mg',
                              ),
                          ],
                        ),
                ),
              ),
            ),
            if (isGuest)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => Guest.block(
                    context,
                    title: 'Sign up to track micros',
                    description:
                        'Create a free account to set micro goals and track fiber, sugar, and sodium.',
                  ),
                  child: Center(
                    child: PulsingLockBadge(
                      accent: lightenColor(appColor, 0.45),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      secondChild: const SizedBox.shrink(),
    );
  }

  Widget _buildMealSection(
    String mealKey,
    String title,
    List<FoodLog> foods,
    Color accentColor,
  ) {
    final isCollapsed = _collapsed[mealKey] ?? false;
    final mealCal = _mealCalories(foods).round();
    double mealProtein = 0, mealCarbs = 0, mealFat = 0;
    double mealFiber = 0, mealSugar = 0, mealSodium = 0;
    for (var food in foods) {
      final m = FoodLoggingHelper.extractMacrosFromFood(food);
      mealProtein += m['protein'] ?? 0;
      mealCarbs += m['carbs'] ?? 0;
      mealFat += m['fat'] ?? 0;
      mealFiber += food.fiber ?? 0;
      mealSugar += food.sugar ?? 0;
      mealSodium += food.sodium ?? 0;
    }
    final hasMicros = mealFiber > 0 || mealSugar > 0 || mealSodium > 0;

    final content = Column(
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
                Expanded(
                  child: Text(
                    "${title.toUpperCase()} (${foods.length})",
                    style: GoogleFonts.manrope(
                      fontSize: Responsive.font(context, 14),
                      color: lightenColor(appColor, 0.45),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
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
                                color: lightenColor(appColor, 0.45),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'P ${mealProtein.round()}g · C ${mealCarbs.round()}g · F ${mealFat.round()}g',
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 10),
                          color: lightenColor(appColor, 0.35),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (hasMicros)
                        Text(
                          [
                            if (mealFiber > 0)
                              'Fiber ${mealFiber.toStringAsFixed(1)}g',
                            if (mealSugar > 0)
                              'Sugar ${mealSugar.toStringAsFixed(1)}g',
                            if (mealSodium > 0)
                              'Na ${mealSodium.toStringAsFixed(0)}mg',
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 10),
                            color: lightenColor(appColor, 0.30),
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
                    color: lightenColor(appColor, 0.45),
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
                      color: lightenColor(appColor, 0.45),
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
                      color: appColor,
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
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        food.brandName != null
                                            ? '${food.brandName} - ${food.foodName}'
                                            : food.foodName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.manrope(
                                          fontSize: Responsive.font(
                                            context,
                                            14,
                                          ),
                                          color: lightenColor(appColor, 0.45),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    // hide logged_at for entries before June 25 2026, logged_at didn't exist yet so it won't be accurate
                                    if (food.loggedAt != null &&
                                        !DateTime.parse(
                                          food.loggedAt!,
                                        ).isBefore(DateTime(2026, 6, 25)))
                                      Text(
                                        _formatLoggedAt(food.loggedAt!),
                                        style: GoogleFonts.manrope(
                                          fontSize: Responsive.font(
                                            context,
                                            13,
                                          ),
                                          color: lightenColor(appColor, 0.35),
                                        ),
                                      ),
                                  ],
                                ),
                                SizedBox(height: Responsive.height(context, 6)),
                                _buildNutritionChips(food, appColor),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _deleteFood(mealKey, idx, foods),
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedDelete02,
                              color: lightenColor(appColor, 0.45),
                              size: Responsive.scale(context, 24),
                            ),
                          ),
                          SizedBox(width: Responsive.width(context, 10)),
                          Builder(
                            builder: (btnContext) => GestureDetector(
                              onTap: () => _showFoodMenu(
                                btnContext,
                                mealKey,
                                foods,
                                food,
                                idx,
                              ),
                              child: HugeIcon(
                                icon: HugeIcons.strokeRoundedMoreVertical,
                                color: lightenColor(appColor, 0.45),
                                size: Responsive.scale(context, 24),
                              ),
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
              Guest.block(
                context,
                title: 'Sign up to log food',
                description:
                    'Create a free account to track calories, macros, and build your nutrition history.',
              );
              return;
            }
            context.push(
              '/food-logging/log',
              extra: {
                'meal': mealKey,
                'currentDate': currentDate,
                'onFoodLogged': () => loadFoodForDate(currentDate),
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
              border: Border.all(color: accentColor.withAlpha(160), width: 1.5),
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

    if (isGuest) {
      return GestureDetector(
        onTap: () => Guest.block(
          context,
          title: 'Sign up to log food',
          description:
              'Create a free account to track calories, macros, and build your nutrition history.',
        ),
        child: Stack(
          children: [
            IgnorePointer(child: Opacity(opacity: 0.35, child: content)),
            guestLockOverlay(context, appColor),
          ],
        ),
      );
    }
    return content;
  }

  @override
  Widget build(BuildContext context) {
    final isLoading =
        !ref.watch(userDataLoadedProvider) ||
        ref.watch(foodLogsProvider).isLoading;
    final dateKey = FoodLoggingHelper.formatDateKey(currentDate);
    final foodLogsState = ref.watch(foodLogsProvider);
    final logs = isGuest
        ? Guest.fakeFoodLogs(dateKey)
        : (foodLogsState.value ?? []);
    // sort by logged_at so moved foods stay in chronological order within the meal
    breakfastFoods =
        logs.where((f) => f.date == dateKey && f.meal == 'breakfast').toList()
          ..sort((a, b) => (a.loggedAt ?? '').compareTo(b.loggedAt ?? ''));
    lunchFoods =
        logs.where((f) => f.date == dateKey && f.meal == 'lunch').toList()
          ..sort((a, b) => (a.loggedAt ?? '').compareTo(b.loggedAt ?? ''));
    dinnerFoods =
        logs.where((f) => f.date == dateKey && f.meal == 'dinner').toList()
          ..sort((a, b) => (a.loggedAt ?? '').compareTo(b.loggedAt ?? ''));
    snacksFoods =
        logs.where((f) => f.date == dateKey && f.meal == 'snacks').toList()
          ..sort((a, b) => (a.loggedAt ?? '').compareTo(b.loggedAt ?? ''));
    final colors = _mealColors(appColor);

    return Container(
      decoration: BoxDecoration(gradient: buildThemeGradient(appColor)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Skeletonizer(
              enabled:
                  !isGuest && (isLoading || !ref.watch(userDataLoadedProvider)),
              effect: ShimmerEffect(
                baseColor: lightenColor(appColor, 0.3),
                highlightColor: lightenColor(appColor, 0.1),
                duration: const Duration(milliseconds: 1200),
              ),
              child: AppRefreshIndicator(
                onRefresh: _refreshAndLoadFood,
                appColor: appColor,
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
                            appColor: appColor,
                            currentDate: currentDate,
                            onDateChanged: (date) {
                              setState(() => currentDate = date);
                              loadFoodForDate(date);
                            },
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() {
                            _refreshAndLoadFood();
                          }),
                          child: Container(
                            padding: EdgeInsets.all(
                              Responsive.scale(context, 12),
                            ),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: lightenColor(appColor, 0.1).withAlpha(20),
                              border: Border.all(
                                color: lightenColor(
                                  appColor,
                                  0.3,
                                ).withAlpha(180),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              Icons.refresh,
                              color: lightenColor(appColor, 0.3).withAlpha(180),
                              size: Responsive.font(context, 13),
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: Responsive.height(context, 16)),
                    _buildCaloriesBar(appColor),

                    SizedBox(height: Responsive.height(context, 20)),
                    Stack(
                      children: [
                        _buildMacroGauges(appColor),
                        if (_goalsSet)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: GestureDetector(
                              onTap: () {
                                setState(
                                  () => _microsExpanded = !_microsExpanded,
                                );
                                _saveMicrosExpanded(_microsExpanded);
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: EdgeInsets.all(
                                  Responsive.scale(context, 4),
                                ),
                                child: AnimatedRotation(
                                  turns: _microsExpanded ? -0.5 : 0,
                                  duration: const Duration(milliseconds: 200),
                                  child: HugeIcon(
                                    icon: HugeIcons.strokeRoundedArrowDown01,
                                    color: lightenColor(appColor, 0.45),
                                    size: Responsive.scale(context, 20),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (_goalsSet) _buildMicroGoalsRow(),

                    SizedBox(height: Responsive.height(context, 8)),

                    _buildMealSection(
                      "breakfast",
                      "Breakfast",
                      breakfastFoods,
                      colors[0],
                    ),
                    _buildMealSection("lunch", "Lunch", lunchFoods, colors[1]),
                    _buildMealSection(
                      "dinner",
                      "Dinner",
                      dinnerFoods,
                      colors[2],
                    ),
                    _buildMealSection(
                      "snacks",
                      "Snacks",
                      snacksFoods,
                      colors[3],
                    ),

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
            OnboardingHint(
              appColor: appColor,
              hintKey: 'food',
              title: 'Search for a food to get started',
              description:
                  'Tap the + button to search, scan a barcode, or enter manually',
            ),
          ],
        ),
      ),
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
