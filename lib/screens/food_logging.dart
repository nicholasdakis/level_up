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
  return [onTheme(base), onTheme(base), onTheme(base), onTheme(base)];
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
  bool _dateLoading = false;

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
      if (!isGuest) {
        ref
            .read(foodLogsProvider.notifier)
            .loadDate(FoodLoggingHelper.formatDateKey(currentDate));
      }
    });
  }

  Future<void> _refreshAndLoadFood() async {
    await ref
        .read(foodLogsProvider.notifier)
        .refresh(FoodLoggingHelper.formatDateKey(currentDate));
  }

  Future<void> loadFoodForDate(DateTime date) async {
    final dateKey = FoodLoggingHelper.formatDateKey(date);
    final alreadyCached = ref.read(foodLogsProvider.notifier).isCached(dateKey);
    setState(() {
      currentDate = date;
      _dateLoading = !alreadyCached && !isGuest;
    });
    if (!isGuest) {
      await ref.read(foodLogsProvider.notifier).loadDate(dateKey);
    }
    if (mounted) setState(() => _dateLoading = false);
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

  Map<String, double>? _cachedTotalNutrition;

  Map<String, double> _computeTotalNutrition() {
    if (_cachedTotalNutrition != null) return _cachedTotalNutrition!;
    double protein = 0, carbs = 0, fat = 0, fiber = 0, sugar = 0, sodium = 0;
    for (final food in [
      ...breakfastFoods,
      ...lunchFoods,
      ...dinnerFoods,
      ...snacksFoods,
    ]) {
      final m = FoodLoggingHelper.extractMacrosFromFood(food);
      protein += m['protein'] ?? 0;
      carbs += m['carbs'] ?? 0;
      fat += m['fat'] ?? 0;
      fiber += m['fiber'] ?? 0;
      sugar += m['sugar'] ?? 0;
      sodium += m['sodium'] ?? 0;
    }
    _cachedTotalNutrition = {
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'fiber': fiber,
      'sugar': sugar,
      'sodium': sodium,
    };
    return _cachedTotalNutrition!;
  }

  double _totalNutrient(String key) => _computeTotalNutrition()[key] ?? 0;

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
        style: GoogleFonts.manrope(color: Colors.white),
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
    final accent = Colors.white;
    final dim = Colors.white;

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

    final success = await ref
        .read(foodLogsProvider.notifier)
        .moveFoodLog(food, toMeal);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Food moved successfully.'
              : (isConnected
                    ? 'Error moving food.'
                    : 'No connection. Please try again when online.'),
          style: GoogleFonts.manrope(color: Colors.white),
        ),
        duration: snackBarDuration,
      ),
    );
  }

  void _showFoodMenu(
    BuildContext btnContext,
    String mealKey,
    List<FoodLog> foods,
    FoodLog food,
    int idx,
  ) async {
    final accent = Colors.white;

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
          Divider(color: Colors.white.withAlpha(120), thickness: 1.5),
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
    final success = await ref
        .read(foodLogsProvider.notifier)
        .editFoodLog(updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Food edited successfully.'
              : (isConnected
                    ? 'Error editing food.'
                    : 'No connection. Please try again when online.'),
          style: GoogleFonts.manrope(color: Colors.white),
        ),
        duration: snackBarDuration,
      ),
    );
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
    final dim = onTheme(base);

    Widget chip(String label, double value, {String unit = 'g'}) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.width(context, 7),
          vertical: Responsive.height(context, 3),
        ),
        decoration: BoxDecoration(
          color: cardColors(base).iconBox,
          borderRadius: BorderRadius.circular(Responsive.scale(context, 20)),
          border: Border.all(color: cardColors(base).border, width: 1.5),
        ),
        child: Text(
          '$label ${value.toStringAsFixed(1)}$unit',
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 11),
            fontWeight: FontWeight.w600,
            color: onTheme(base),
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
              color: Colors.white,
              fontSize: Responsive.font(context, 16),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: Responsive.height(context, 16)),
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(5),
            ],
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              color: Colors.white,
              fontSize: Responsive.font(context, 24),
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              suffixText: unit,
              suffixStyle: GoogleFonts.manrope(
                color: Colors.white,
                fontSize: Responsive.font(context, 14),
              ),
              filled: true,
              fillColor: Colors.white.withAlpha(12),
              contentPadding: EdgeInsets.symmetric(
                horizontal: Responsive.width(context, 16),
                vertical: Responsive.height(context, 14),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  Responsive.scale(context, 12),
                ),
                borderSide: BorderSide(color: Colors.white.withAlpha(80)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  Responsive.scale(context, 12),
                ),
                borderSide: const BorderSide(color: Colors.white, width: 1.5),
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
          color: cardColors(appColor).iconBox,
          border: Border.all(
            color: cardColors(appColor).iconBorder,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedAnalytics01,
              color: onTheme(appColor),
              size: Responsive.font(context, 20),
            ),
            SizedBox(width: Responsive.width(context, 8)),
            Text(
              "View Analytics",
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 15),
                fontWeight: FontWeight.w800,
                color: onTheme(appColor),
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
                              color: onTheme(appColor),
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
                                color: onTheme(appColor),
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
                                  color: onTheme(appColor),
                                ),
                              ),
                              Text(
                                'daily goal',
                                style: GoogleFonts.manrope(
                                  fontSize: Responsive.font(context, 11),
                                  color: onTheme(appColor),
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
                              color: onTheme(appColor).withAlpha(30),
                            ),
                            FractionallySizedBox(
                              widthFactor: 0.79,
                              child: Container(
                                height: Responsive.height(context, 8),
                                color: onTheme(appColor).withAlpha(120),
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
              color: onTheme(appColor),
              size: Responsive.scale(context, 24),
            ),
            label: Text(
              "Set your nutrition goals",
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 14),
                fontWeight: FontWeight.w600,
                color: onTheme(appColor),
              ),
            ),
          ),
        ),
      );
    }

    final total = _totalCalories();
    final progress = (total / _goalCalories).clamp(0.0, 1.0);
    final remaining = (_goalCalories - total).round();
    final barColor = onTheme(appColor);
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
                  color: onTheme(appColor),
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
                        color: onTheme(appColor),
                      ),
                    ),
                    SizedBox(width: Responsive.width(context, 4)),
                    GestureDetector(
                      onTap: () => _editGoal(context, 'calories'),
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedPencilEdit01,
                        color: onTheme(appColor),
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
                      color: isOver ? onTheme(appColor) : barColor,
                    ),
                  ),
                  Text(
                    "daily goal",
                    style: GoogleFonts.manrope(
                      fontSize: Responsive.font(context, 11),
                      color: onTheme(appColor),
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
                color: cardColors(appColor).border,
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
                    color: onTheme(appColor).withAlpha(30),
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
                        trackColor: onTheme(appColor).withAlpha(30),
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
            color: onTheme(appColor),
          ),
        ),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 11),
            color: onTheme(appColor),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "/ ${goal.toStringAsFixed(0)}g",
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 10),
                color: onTheme(appColor),
              ),
            ),
            SizedBox(width: Responsive.width(context, 3)),
            GestureDetector(
              onTap: () => _editGoal(context, label.toLowerCase()),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedPencilEdit01,
                color: onTheme(appColor),
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
      final color = onTheme(appColor);
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
                  current: _totalNutrient('protein'),
                  goal: _goalProtein,
                  color: onTheme(appColor),
                )
              : _buildMacroPlaceholder("Protein", appColor),
        ),
        SizedBox(width: Responsive.width(context, 8)),
        Expanded(
          child: _goalCarbs > 0
              ? _buildMacroGauge(
                  label: "Carbs",
                  current: _totalNutrient('carbs'),
                  goal: _goalCarbs,
                  color: onTheme(appColor),
                )
              : _buildMacroPlaceholder("Carbs", appColor),
        ),
        SizedBox(width: Responsive.width(context, 8)),
        Expanded(
          child: _goalFat > 0
              ? _buildMacroGauge(
                  label: "Fat",
                  current: _totalNutrient('fat'),
                  goal: _goalFat,
                  color: onTheme(appColor),
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
          color: onTheme(appColor),
          size: Responsive.scale(context, 14),
        ),
        label: Text(
          "Set $label",
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 11),
            color: onTheme(appColor),
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

    Widget field(
      TextEditingController ctrl,
      String label,
      String unit,
    ) => Padding(
      padding: EdgeInsets.symmetric(vertical: Responsive.height(context, 6)),
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(5),
        ],
        style: GoogleFonts.manrope(
          color: Colors.white,
          fontSize: Responsive.font(context, 20),
          fontWeight: FontWeight.w700,
        ),
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          labelText: '$label ($unit)',
          labelStyle: const TextStyle(color: Colors.white),
          floatingLabelStyle: const TextStyle(color: Colors.white),
          suffixText: unit,
          suffixStyle: GoogleFonts.manrope(
            color: Colors.white,
            fontSize: Responsive.font(context, 14),
          ),
          filled: true,
          fillColor: Colors.white.withAlpha(12),
          contentPadding: EdgeInsets.symmetric(
            horizontal: Responsive.width(context, 16),
            vertical: Responsive.height(context, 14),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Responsive.scale(context, 12)),
            borderSide: BorderSide(color: Colors.white.withAlpha(80)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Responsive.scale(context, 12)),
            borderSide: const BorderSide(color: Colors.white, width: 1.5),
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

    final accent = onTheme(appColor);
    final dim = onTheme(appColor);
    final color = onTheme(appColor);

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
                  color: onTheme(appColor).withAlpha(30),
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

    final totalFiber = _totalNutrient('fiber');
    final totalSugar = _totalNutrient('sugar');
    final totalSodium = _totalNutrient('sodium');
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
                                    color: onTheme(appColor),
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
                    child: PulsingLockBadge(accent: onTheme(appColor)),
                  ),
                ),
              ),
          ],
        ),
      ),
      secondChild: const SizedBox.shrink(),
    );
  }

  // Shows the meal-level action sheet for the wand button in the meal header
  Future<void> _showMealActionsSheet(
    String mealKey,
    String title,
    List<FoodLog> foods,
  ) async {
    final action = await showFrostedDialog<String>(
      context: context,
      appColor: appColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              title,
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 18),
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(height: Responsive.height(context, 20)),
          GestureDetector(
            onTap: () => Navigator.of(context, rootNavigator: true).pop('copy'),
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: Responsive.height(context, 12),
              ),
              child: Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedCopy01,
                    color: Colors.white,
                    size: Responsive.scale(context, 22),
                  ),
                  SizedBox(width: Responsive.width(context, 14)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Copy a meal',
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 15),
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Import a meal from any date into $title',
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 12),
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(color: Colors.white.withAlpha(40), thickness: 1),
          GestureDetector(
            onTap: () =>
                Navigator.of(context, rootNavigator: true).pop('delete'),
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: Responsive.height(context, 12),
              ),
              child: Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedDelete02,
                    color: Colors.white,
                    size: Responsive.scale(context, 22),
                  ),
                  SizedBox(width: Responsive.width(context, 14)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delete all foods',
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 15),
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Remove all ${foods.length} food${foods.length == 1 ? '' : 's'} from $title',
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 12),
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: Responsive.height(context, 8)),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
              child: Text('Cancel', style: dialogButtonStyle()),
            ),
          ),
        ],
      ),
    );

    if (action == 'delete') {
      await _deleteAllFoodsInMeal(mealKey, title, foods);
    } else if (action == 'copy') {
      await _copyMealFromDate(mealKey, title);
    }
  }

  // Requires a hold-to-confirm gesture before deleting every food in the meal
  Future<void> _deleteAllFoodsInMeal(
    String mealKey,
    String title,
    List<FoodLog> foods,
  ) async {
    if (foods.isEmpty) return;
    final confirmed = await showHoldToConfirmDialog(
      context: context,
      appColor: appColor,
      title: 'Clear $title?',
      subtitle:
          'This will remove all ${foods.length} food${foods.length == 1 ? '' : 's'} from $title.',
      icon: HugeIcons.strokeRoundedDelete02,
    );
    if (confirmed != true || !mounted) return;
    await ref.read(foodLogsProvider.notifier).bulkDeleteFoodLogs(foods);
    trackTrivialAchievement('food_clear_meal');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Deleted all foods from $title.',
            style: GoogleFonts.manrope(color: Colors.white),
          ),
          duration: snackBarDuration,
        ),
      );
    }
  }

  // Lets the user copy all foods from a meal on any past date into the current meal.
  // Flows: pick date, pick meal, fetch if needed, preview nutrition, confirm, upsert.
  Future<void> _copyMealFromDate(String targetMeal, String title) async {
    // Step 1: pick date with Today / Yesterday / Calendar shortcuts
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    DateTime? pickedDate = await showFrostedDialog<DateTime>(
      context: context,
      appColor: appColor,
      child: StatefulBuilder(
        builder: (ctx, setS) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Pick a date',
                style: GoogleFonts.manrope(
                  fontSize: Responsive.font(ctx, 18),
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: Responsive.height(ctx, 16)),
              Row(
                children: [
                  for (final entry in [
                    ('Today', today),
                    ('Yesterday', yesterday),
                  ]) ...[
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.of(
                          ctx,
                          rootNavigator: true,
                        ).pop(entry.$2),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            vertical: Responsive.height(ctx, 12),
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(18),
                            borderRadius: BorderRadius.circular(
                              Responsive.scale(ctx, 10),
                            ),
                            border: Border.all(
                              color: Colors.white.withAlpha(40),
                            ),
                          ),
                          child: Text(
                            entry.$1,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                              fontSize: Responsive.font(ctx, 14),
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: Responsive.width(ctx, 10)),
                  ],
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final picked = await showThemedDatePicker(
                          context: ctx,
                          initialDate: today,
                          firstDate: DateTime(2025),
                          lastDate: today,
                          appColor: appColor,
                          initialEntryMode: DatePickerEntryMode.calendarOnly,
                        );
                        if (picked != null && ctx.mounted) {
                          Navigator.of(ctx, rootNavigator: true).pop(picked);
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          vertical: Responsive.height(ctx, 12),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(18),
                          borderRadius: BorderRadius.circular(
                            Responsive.scale(ctx, 10),
                          ),
                          border: Border.all(color: Colors.white.withAlpha(40)),
                        ),
                        child: Text(
                          'Calendar',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(ctx, 14),
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: Responsive.height(ctx, 8)),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
                  child: Text('Cancel', style: dialogButtonStyle()),
                ),
              ),
            ],
          );
        },
      ),
    );
    if (pickedDate == null || !mounted) return;

    // Step 2: pick source meal
    final String? pickedMeal = await showFrostedDialog<String>(
      context: context,
      appColor: appColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Which meal?',
            style: GoogleFonts.manrope(
              fontSize: Responsive.font(context, 18),
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          SizedBox(height: Responsive.height(context, 16)),
          for (final meal in ['breakfast', 'lunch', 'dinner', 'snacks']) ...[
            GestureDetector(
              onTap: () => Navigator.of(context, rootNavigator: true).pop(meal),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: Responsive.height(context, 12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        meal[0].toUpperCase() + meal.substring(1),
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 15),
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.white54,
                      size: Responsive.scale(context, 18),
                    ),
                  ],
                ),
              ),
            ),
            if (meal != 'snacks')
              Divider(
                color: Colors.white.withAlpha(40),
                thickness: 1,
                height: 1,
              ),
          ],
          SizedBox(height: Responsive.height(context, 8)),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
              child: Text('Cancel', style: dialogButtonStyle()),
            ),
          ),
        ],
      ),
    );
    if (pickedMeal == null || !mounted) return;

    // Step 3: fetch source date if not already loaded (current date is always in state)
    final sourceDateKey = FoodLoggingHelper.formatDateKey(pickedDate);
    final currentDateKey = FoodLoggingHelper.formatDateKey(currentDate);
    if (sourceDateKey != currentDateKey) {
      await ref.read(foodLogsProvider.notifier).refresh(sourceDateKey);
    }
    if (!mounted) return;

    // filter state client-side since the whole day is loaded per request
    final sourceFoods = (ref.read(foodLogsProvider).value ?? [])
        .where((f) => f.date == sourceDateKey && f.meal == pickedMeal)
        .toList();

    if (sourceFoods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No foods found in that meal.',
            style: GoogleFonts.manrope(color: Colors.white),
          ),
          duration: snackBarDuration,
        ),
      );
      return;
    }

    // Step 4: preview + confirm
    int totalCal = 0;
    double totalProtein = 0, totalCarbs = 0, totalFat = 0;
    double totalFiber = 0, totalSugar = 0, totalSodium = 0;
    for (final food in sourceFoods) {
      totalCal +=
          food.calories ??
          FoodLoggingHelper.extractCalories(food.foodDescription ?? '');
      final m = FoodLoggingHelper.extractMacrosFromFood(food);
      totalProtein += m['protein'] ?? 0;
      totalCarbs += m['carbs'] ?? 0;
      totalFat += m['fat'] ?? 0;
      totalFiber += food.fiber ?? 0;
      totalSugar += food.sugar ?? 0;
      totalSodium += food.sodium ?? 0;
    }
    final hasMicros = totalFiber > 0 || totalSugar > 0 || totalSodium > 0;
    final sourceLabel =
        '${pickedMeal[0].toUpperCase()}${pickedMeal.substring(1)} · $sourceDateKey';

    final confirmed = await showFrostedDialog<bool>(
      context: context,
      appColor: appColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Copy to $title?',
            style: GoogleFonts.manrope(
              fontSize: Responsive.font(context, 18),
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          SizedBox(height: Responsive.height(context, 2)),
          Text(
            sourceLabel,
            style: GoogleFonts.manrope(
              fontSize: Responsive.font(context, 12),
              color: Colors.white60,
            ),
          ),
          SizedBox(height: Responsive.height(context, 16)),
          // Nutrition summary card
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.width(context, 16),
              vertical: Responsive.height(context, 12),
            ),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(15),
              borderRadius: BorderRadius.circular(
                Responsive.scale(context, 12),
              ),
              border: Border.all(color: Colors.white.withAlpha(40)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '$totalCal',
                  style: GoogleFonts.manrope(
                    fontSize: Responsive.font(context, 28),
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
                Text(
                  'calories',
                  style: GoogleFonts.manrope(
                    fontSize: Responsive.font(context, 11),
                    color: Colors.white60,
                  ),
                ),
                SizedBox(height: Responsive.height(context, 8)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final entry in [
                      ('Protein', '${totalProtein.toStringAsFixed(1)}g'),
                      ('Carbs', '${totalCarbs.toStringAsFixed(1)}g'),
                      ('Fat', '${totalFat.toStringAsFixed(1)}g'),
                    ])
                      Column(
                        children: [
                          Text(
                            entry.$2,
                            style: GoogleFonts.manrope(
                              fontSize: Responsive.font(context, 14),
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            entry.$1,
                            style: GoogleFonts.manrope(
                              fontSize: Responsive.font(context, 11),
                              color: Colors.white60,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                if (hasMicros) ...[
                  SizedBox(height: Responsive.height(context, 6)),
                  Text(
                    [
                      if (totalFiber > 0)
                        'Fiber ${totalFiber.toStringAsFixed(1)}g',
                      if (totalSugar > 0)
                        'Sugar ${totalSugar.toStringAsFixed(1)}g',
                      if (totalSodium > 0)
                        'Na ${totalSodium.toStringAsFixed(0)}mg',
                    ].join(' · '),
                    style: GoogleFonts.manrope(
                      fontSize: Responsive.font(context, 11),
                      color: Colors.white54,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: Responsive.height(context, 12)),
          // Food list
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.22,
            ),
            child: SingleChildScrollView(
              child: Column(
                children: List.generate(sourceFoods.length, (i) {
                  final food = sourceFoods[i];
                  final cal =
                      food.calories ??
                      FoodLoggingHelper.extractCalories(
                        food.foodDescription ?? '',
                      );
                  return Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: Responsive.height(context, 8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                food.foodName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.manrope(
                                  fontSize: Responsive.font(context, 13),
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Text(
                              '$cal cal',
                              style: GoogleFonts.manrope(
                                fontSize: Responsive.font(context, 12),
                                color: Colors.white60,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (i < sourceFoods.length - 1)
                        Divider(
                          color: Colors.white.withAlpha(25),
                          thickness: 1,
                          height: 1,
                        ),
                    ],
                  );
                }),
              ),
            ),
          ),
          SizedBox(height: Responsive.height(context, 16)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).pop(false),
                child: Text('Cancel', style: dialogButtonStyle()),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).pop(true),
                child: Text(
                  'Copy ${sourceFoods.length} food${sourceFoods.length == 1 ? '' : 's'}',
                  style: dialogButtonStyle(confirm: true),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    final targetDateKey = FoodLoggingHelper.formatDateKey(currentDate);
    final newFoods = sourceFoods
        .map(
          (food) => FoodLog(
            date: targetDateKey,
            meal: targetMeal,
            foodName: food.foodName,
            brandName: food.brandName,
            foodDescription: food.foodDescription,
            calories: food.calories,
            protein: food.protein,
            carbs: food.carbs,
            fat: food.fat,
            fiber: food.fiber,
            sugar: food.sugar,
            sodium: food.sodium,
            servingSize: food.servingSize,
          ),
        )
        .toList();
    await ref
        .read(foodLogsProvider.notifier)
        .bulkAddFoodLogs(targetDateKey, newFoods);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Copied ${sourceFoods.length} food${sourceFoods.length == 1 ? '' : 's'} to $title.',
            style: GoogleFonts.manrope(color: Colors.white),
          ),
          duration: snackBarDuration,
        ),
      );
    }
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
                      color: onTheme(appColor),
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
                                color: onTheme(appColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'P ${mealProtein.round()}g · C ${mealCarbs.round()}g · F ${mealFat.round()}g',
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 10),
                          color: onTheme(appColor),
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
                            color: onTheme(appColor),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(width: Responsive.width(context, 8)),
                ],
                GestureDetector(
                  onTap: () => _showMealActionsSheet(mealKey, title, foods),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.width(context, 6),
                      vertical: Responsive.height(context, 4),
                    ),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedAiBeautify,
                      color: onTheme(appColor),
                      size: Responsive.scale(context, 18),
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: isCollapsed ? -0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowDown01,
                    color: onTheme(appColor),
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
                      color: onTheme(appColor),
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
                                          color: onTheme(appColor),
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
                                          color: onTheme(appColor),
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
                              color: onTheme(appColor),
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
                                color: onTheme(appColor),
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
        ref.watch(foodLogsProvider).isLoading ||
        _dateLoading;
    final dateKey = FoodLoggingHelper.formatDateKey(currentDate);
    final foodLogsState = ref.watch(foodLogsProvider);
    final logs = isGuest
        ? Guest.fakeFoodLogs(dateKey)
        : (foodLogsState.value ?? []);
    _cachedTotalNutrition = null;
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
                baseColor: cardColors(appColor).iconBox,
                highlightColor: cardColors(appColor).border,
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
                              color: cardColors(appColor).iconBox,
                              border: Border.all(
                                color: cardColors(appColor).iconBorder,
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              Icons.refresh,
                              color: onTheme(appColor),
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
                                    color: onTheme(appColor),
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
                                  color: onTheme(appColor).withAlpha(100),
                                  decoration: TextDecoration.underline,
                                  decorationColor: onTheme(
                                    appColor,
                                  ).withAlpha(100),
                                ),
                              ),
                            ),
                            Text(
                              "  ·  ",
                              style: GoogleFonts.manrope(
                                fontSize: Responsive.font(context, 11),
                                color: onTheme(appColor).withAlpha(100),
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
                                  color: onTheme(appColor).withAlpha(100),
                                  decoration: TextDecoration.underline,
                                  decorationColor: onTheme(
                                    appColor,
                                  ).withAlpha(100),
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
