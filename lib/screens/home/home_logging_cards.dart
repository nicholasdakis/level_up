import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/providers/user_data_provider.dart';
import '/services/user_data_manager.dart' show defaultAppColor;
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../guest.dart';
import '../../globals.dart';
import '../../utility/responsive.dart';
import '../../utility/unit_converter.dart';
import '../../utility/food_logging_helper.dart' show FoodLoggingHelper;
import '../../providers/food_logs_provider.dart';
import '../../models/food_log.dart';
import '../../providers/water_logs_provider.dart';
import '../../providers/weight_logs_provider.dart';
import 'package:skeletonizer/skeletonizer.dart';

String _todayDateKey() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

class HomeLoggingCards extends ConsumerStatefulWidget {
  // sheet methods live on the home screen state, so they're passed in as callbacks
  final VoidCallback onShowWaterSheet;
  final VoidCallback onShowWeightSheet;

  const HomeLoggingCards({
    super.key,
    required this.onShowWaterSheet,
    required this.onShowWeightSheet,
  });

  @override
  ConsumerState<HomeLoggingCards> createState() => _HomeLoggingCardsState();
}

class _HomeLoggingCardsState extends ConsumerState<HomeLoggingCards> {
  Color get appColor => ref.watch(
    userDataProvider.select((s) => s.value?.appColor ?? defaultAppColor),
  );

  bool get isImperial =>
      ref.watch(userDataProvider.select((s) => s.value?.units == 'imperial'));

  bool _showMicros = false;

  // Calculates total calories logged today
  int _todayCalories(List<FoodLog> logs) {
    final key = _todayDateKey();
    int total = 0;
    for (final food in logs.where((f) => f.date == key)) {
      total += food.calories ?? 0;
    }
    return total;
  }

  // Returns today's total protein/carbs/fat in grams
  ({int protein, int carbs, int fat}) _todayMacros(List<FoodLog> logs) {
    final key = _todayDateKey();
    int protein = 0, carbs = 0, fat = 0;
    for (final food in logs.where((f) => f.date == key)) {
      final macros = FoodLoggingHelper.extractMacrosFromFood(food);
      protein += (macros['protein'] ?? 0.0).toInt();
      carbs += (macros['carbs'] ?? 0.0).toInt();
      fat += (macros['fat'] ?? 0.0).toInt();
    }
    return (protein: protein, carbs: carbs, fat: fat);
  }

  // Returns today's total fiber/sugar/sodium
  ({double fiber, double sugar, double sodium}) _todayMicros(
    List<FoodLog> logs,
  ) {
    final key = _todayDateKey();
    double fiber = 0, sugar = 0, sodium = 0;
    for (final food in logs.where((f) => f.date == key)) {
      final macros = FoodLoggingHelper.extractMacrosFromFood(food);
      fiber += macros['fiber'] ?? 0.0;
      sugar += macros['sugar'] ?? 0.0;
      sodium += macros['sodium'] ?? 0.0;
    }
    return (fiber: fiber, sugar: sugar, sodium: sodium);
  }

  VoidCallback get onShowWaterSheet => widget.onShowWaterSheet;
  VoidCallback get onShowWeightSheet => widget.onShowWeightSheet;

  void _showMealPicker(BuildContext context) {
    final accent = lightenColor(appColor, 0.45);
    final dim = lightenColor(appColor, 0.35);
    final meals = [
      (
        label: 'Breakfast',
        meal: 'breakfast',
        icon: HugeIcons.strokeRoundedSunrise,
      ),
      (label: 'Lunch', meal: 'lunch', icon: HugeIcons.strokeRoundedSun01),
      (label: 'Dinner', meal: 'dinner', icon: HugeIcons.strokeRoundedMoon02),
      (label: 'Snacks', meal: 'snacks', icon: HugeIcons.strokeRoundedCookie),
    ];

    showFrostedAlertDialog(
      context: context,
      appColor: appColor,
      title: 'Choose Meal Type',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Select the meal you want to log food to',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: Responsive.font(context, 13),
              color: Colors.white60,
            ),
          ),
          SizedBox(height: Responsive.height(context, 16)),
          for (final m in meals)
            Padding(
              padding: EdgeInsets.only(bottom: Responsive.height(context, 8)),
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context, rootNavigator: true).pop();
                  context.push(
                    '/food-logging/log',
                    extra: {
                      'meal': m.meal,
                      'currentDate': DateTime.now(),
                      'onFoodLogged': () =>
                          ref.read(foodLogsProvider.notifier).refresh(),
                      'achievementId': null,
                    },
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.width(context, 16),
                    vertical: Responsive.height(context, 12),
                  ),
                  decoration: BoxDecoration(
                    color: accent.withAlpha(12),
                    borderRadius: BorderRadius.circular(
                      Responsive.scale(context, 12),
                    ),
                    border: Border.all(color: accent.withAlpha(40), width: 1),
                  ),
                  child: Row(
                    children: [
                      HugeIcon(
                        icon: m.icon,
                        color: accent,
                        size: Responsive.scale(context, 20),
                      ),
                      SizedBox(width: Responsive.width(context, 12)),
                      Text(
                        m.label,
                        style: GoogleFonts.manrope(
                          color: accent,
                          fontSize: Responsive.font(context, 14),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.chevron_right,
                        color: dim,
                        size: Responsive.scale(context, 18),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          child: Text('Cancel', style: dialogButtonStyle()),
        ),
      ],
    );
  }

  Widget _buildLoggingCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required String subtext,
    bool showButtons = false,
    VoidCallback? onAdd,
    IconData onAddIcon = Icons.add, // icon for the primary action button
    VoidCallback? onChart,
    Widget? progressBar,
  }) {
    final accentColor = lightenColor(appColor, 0.45);

    Widget actionButton(IconData btnIcon, VoidCallback? onTap) =>
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: Responsive.scale(context, 34),
            height: Responsive.scale(context, 34),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withAlpha(18),
              border: Border.all(color: Colors.white.withAlpha(40), width: 1),
            ),
            child: Icon(
              btnIcon,
              color: accentColor,
              size: Responsive.scale(context, 16),
            ),
          ),
        );

    return frostedGlassCard(
      context,
      color: appColor,
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
                    HugeIcon(
                      icon: icon,
                      color: accentColor,
                      size: Responsive.scale(context, 14),
                    ),
                    SizedBox(width: Responsive.width(context, 5)),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          label,
                          style: GoogleFonts.manrope(
                            color: accentColor,
                            fontSize: Responsive.font(context, 11),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: Responsive.height(context, 6)),
                Text(
                  value,
                  style: GoogleFonts.manrope(
                    color: accentColor,
                    fontSize: Responsive.font(context, 22),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtext,
                  style: GoogleFonts.manrope(
                    color: accentColor,
                    fontSize: Responsive.font(context, 11),
                  ),
                ),
                if (progressBar != null) ...[
                  SizedBox(height: Responsive.height(context, 8)),
                  progressBar,
                ],
              ],
            ),
          ),
          if (showButtons) ...[
            SizedBox(width: Responsive.width(context, 8)),
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                actionButton(onAddIcon, onAdd),
                if (onChart != null) ...[
                  SizedBox(height: Responsive.height(context, 6)),
                  actionButton(HugeIcons.strokeRoundedAnalyticsUp, onChart),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMacrosCard(BuildContext context) {
    final userData = ref.watch(userDataProvider).value;
    final foodLogs = ref.watch(foodLogsProvider).value ?? [];
    final accentColor = lightenColor(appColor, 0.45);
    final dimColor = lightenColor(appColor, 0.35);
    final logs = isGuest ? Guest.fakeFoodLogs(_todayDateKey()) : foodLogs;
    final macros = _todayMacros(logs);
    final micros = _todayMicros(logs);

    Widget row(String label, IconData icon, String value, String? goal) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: Responsive.width(context, 46),
            child: Text(
              label,
              style: GoogleFonts.manrope(
                color: dimColor,
                fontSize: Responsive.font(context, 11),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // value center
          Expanded(
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: GoogleFonts.manrope(
                      color: accentColor,
                      fontSize: Responsive.font(context, 15),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (goal != null)
                    TextSpan(
                      text: " /$goal",
                      style: GoogleFonts.manrope(
                        color: dimColor,
                        fontSize: Responsive.font(context, 11),
                      ),
                    ),
                ],
              ),
            ),
          ),
          HugeIcon(
            icon: icon,
            color: dimColor,
            size: Responsive.scale(context, 13),
          ),
        ],
      );
    }

    Widget header(String title, IconData arrow, VoidCallback onArrow) => Row(
      children: [
        HugeIcon(
          icon: HugeIcons.strokeRoundedAppleStocks,
          color: accentColor,
          size: Responsive.scale(context, 14),
        ),
        SizedBox(width: Responsive.width(context, 5)),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.manrope(
              color: accentColor,
              fontSize: Responsive.font(context, 11),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        GestureDetector(
          onTap: onArrow,
          child: HugeIcon(
            icon: arrow,
            color: dimColor,
            size: Responsive.scale(context, 18),
          ),
        ),
      ],
    );

    final cardContent = _showMicros
        ? Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header(
                "Today's Micros",
                HugeIcons.strokeRoundedArrowLeft01,
                () => setState(() => _showMicros = false),
              ),
              SizedBox(height: Responsive.height(context, 6)),
              row(
                "Fiber",
                HugeIcons.strokeRoundedLeaf01,
                "${micros.fiber.toStringAsFixed(1)}g",
                userData?.fiberGoal != null ? "${userData!.fiberGoal}g" : null,
              ),
              SizedBox(height: Responsive.height(context, 2)),
              row(
                "Sugar",
                HugeIcons.strokeRoundedCube,
                "${micros.sugar.toStringAsFixed(1)}g",
                userData?.sugarGoal != null ? "${userData!.sugarGoal}g" : null,
              ),
              SizedBox(height: Responsive.height(context, 2)),
              row(
                "Sodium",
                HugeIcons.strokeRoundedDroplet,
                "${micros.sodium.toStringAsFixed(0)}mg",
                userData?.sodiumGoal != null
                    ? "${userData!.sodiumGoal}mg"
                    : null,
              ),
              const Spacer(),
              Center(child: _pageIndicator()),
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header(
                "Today's Macros",
                HugeIcons.strokeRoundedArrowRight01,
                () => setState(() => _showMicros = true),
              ),
              SizedBox(height: Responsive.height(context, 6)),
              row(
                "Protein",
                HugeIcons.strokeRoundedBodyPartMuscle,
                "${macros.protein}g",
                userData?.proteinGoal != null
                    ? "${userData!.proteinGoal}g"
                    : null,
              ),
              SizedBox(height: Responsive.height(context, 2)),
              row(
                "Carbs",
                HugeIcons.strokeRoundedFire,
                "${macros.carbs}g",
                userData?.carbsGoal != null ? "${userData!.carbsGoal}g" : null,
              ),
              SizedBox(height: Responsive.height(context, 2)),
              row(
                "Fat",
                HugeIcons.strokeRoundedDroplet,
                "${macros.fat}g",
                userData?.fatGoal != null ? "${userData!.fatGoal}g" : null,
              ),
              const Spacer(),
              Center(child: _pageIndicator()),
            ],
          );

    return frostedGlassCard(
      context,
      color: appColor,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.width(context, 16),
        vertical: Responsive.height(context, 10),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: KeyedSubtree(key: ValueKey(_showMicros), child: cardContent),
      ),
    );
  }

  Widget _pageIndicator() {
    final active = lightenColor(appColor, 0.45);
    final inactive = lightenColor(appColor, 0.20);
    dot(bool filled) => Container(
      width: Responsive.scale(context, 5),
      height: Responsive.scale(context, 5),
      margin: EdgeInsets.symmetric(horizontal: Responsive.width(context, 3)),
      decoration: BoxDecoration(
        color: filled ? active : inactive,
        shape: BoxShape.circle,
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [dot(!_showMicros), dot(_showMicros)],
    );
  }

  // Wraps a card with a lock overlay when guest, otherwise returns child as-is
  Widget _guestLock(
    BuildContext context,
    Widget child, {
    required String title,
    required String description,
  }) {
    if (!isGuest) return child;
    return GestureDetector(
      onTap: () => Guest.block(context, title: title, description: description),
      child: Stack(
        children: [
          IgnorePointer(child: Opacity(opacity: 0.35, child: child)),
          guestLockOverlay(context, appColor),
        ],
      ),
    );
  }

  Widget _buildLoggingCards(BuildContext context) {
    final userData = ref.watch(userDataProvider).value;
    final foodLogs = ref.watch(foodLogsProvider).value ?? [];

    final calories = isGuest
        ? _todayCalories(Guest.fakeFoodLogs(_todayDateKey()))
        : _todayCalories(foodLogs);
    final goal = userData?.caloriesGoal ?? 0;
    final progress = goal > 0 ? (calories / goal).clamp(0.0, 1.0) : 0.0;

    // water progress
    final totalWaterMl =
        (ref.watch(waterLogsProvider).value?[_todayDateKey()] ?? []).fold(
          0,
          (total, entryMl) => total + entryMl,
        );
    final waterGoalMl = userData?.waterMlGoal ?? 0;
    final waterProgress = waterGoalMl > 0
        ? (totalWaterMl / waterGoalMl).clamp(0.0, 1.0)
        : 0.0;

    Widget buildProgressBar(double fraction, {bool overIsRed = true}) =>
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
                Container(
                  height: Responsive.height(context, 8),
                  width: double.infinity,
                  color: Colors.white.withAlpha(18),
                ),
                FractionallySizedBox(
                  widthFactor: fraction,
                  child: Container(
                    height: Responsive.height(context, 8),
                    decoration: BoxDecoration(
                      color: overIsRed && fraction >= 1.0
                          ? lightenColor(appColor, 0.45)
                          : lightenColor(appColor, 0.3),
                      borderRadius: BorderRadius.circular(
                        Responsive.scale(context, 6),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

    final progressBar = goal > 0
        ? buildProgressBar(progress, overIsRed: true)
        : Text(
            "No calorie goal set",
            style: GoogleFonts.manrope(
              fontSize: Responsive.font(context, 10),
              color: lightenColor(appColor, 0.35),
            ),
          );
    final waterProgressBar = waterGoalMl > 0
        ? buildProgressBar(waterProgress, overIsRed: false)
        : null;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _guestLock(
                    context,
                    _buildLoggingCard(
                      context,
                      icon: HugeIcons.strokeRoundedFire,
                      label: "Today's Calories",
                      value: "$calories",
                      subtext: goal > 0 ? "/ $goal goal" : "kcal",
                      progressBar: progressBar,
                      showButtons: true,
                      onAdd: isGuest
                          ? () => Guest.block(
                              context,
                              title: 'Sign up to log food',
                              description:
                                  'Create a free account to track calories, macros, and build your nutrition history.',
                            )
                          : () => _showMealPicker(context),
                      onAddIcon: Icons.add,
                      onChart: isGuest
                          ? () => Guest.block(
                              context,
                              title: 'Sign up to see your nutrition',
                              description:
                                  'Create a free account to track calories and macros and see how you are hitting your daily goals.',
                            )
                          : () => context.push(
                              '/food-logging/analytics',
                              extra: {
                                'initialDate': DateTime.now(),
                                'onDateChanged': null,
                                'noAnimation': true,
                              },
                            ),
                    ),
                    title: 'Sign up to see your nutrition',
                    description:
                        'Create a free account to track calories and macros and see how you are hitting your daily goals.',
                  ),
                ),
                SizedBox(height: Responsive.height(context, 12)),
                Expanded(
                  child: Skeletonizer(
                    enabled: !isGuest && ref.watch(waterLogsProvider).isLoading,
                    effect: ShimmerEffect(
                      baseColor: lightenColor(appColor, 0.10),
                      highlightColor: lightenColor(appColor, 0.22),
                    ),
                    child: _guestLock(
                      context,
                      _buildLoggingCard(
                        context,
                        icon: HugeIcons.strokeRoundedDroplet,
                        label: "Water",
                        value: isImperial
                            ? UnitConverter.displayWater(
                                totalWaterMl,
                                imperial: isImperial,
                              )
                            : "$totalWaterMl",
                        subtext: () {
                          if (waterGoalMl <= 0) {
                            return isImperial ? "oz today" : "ml today";
                          }
                          final goalDisplay = isImperial
                              ? "${UnitConverter.displayWater(waterGoalMl, imperial: isImperial, decimals: 0)} oz"
                              : "$waterGoalMl ml";
                          return "/ $goalDisplay goal";
                        }(),
                        progressBar: waterProgressBar,
                        showButtons: true,
                        onAdd: isGuest
                            ? () => Guest.block(
                                context,
                                title: 'Sign up to track water',
                                description:
                                    'Create a free account to log your daily water intake and hit your hydration goal.',
                              )
                            : onShowWaterSheet,
                        onChart: isGuest
                            ? () => Guest.block(
                                context,
                                title: 'Sign up to track water',
                                description:
                                    'Create a free account to log your daily water intake and hit your hydration goal.',
                              )
                            : () => context.push('/water/analytics'),
                      ),
                      title: 'Sign up to track water',
                      description:
                          'Create a free account to log your daily water intake and hit your hydration goal.',
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: Responsive.width(context, 12)),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _guestLock(
                    context,
                    _buildMacrosCard(context),
                    title: 'Sign up to track nutrients',
                    description:
                        'Create a free account to monitor your protein, carbs, and fat intake.',
                  ),
                ),
                SizedBox(height: Responsive.height(context, 12)),
                Expanded(
                  child: _guestLock(
                    context,
                    _buildLoggingCard(
                      context,
                      icon: HugeIcons.strokeRoundedWeightScale,
                      label: "Weight",
                      value: () {
                        // use today's entry, or fall back to the most recent logged weight
                        final byDate =
                            ref.watch(weightLogsProvider).value ?? {};
                        final kg =
                            byDate[_todayDateKey()] ??
                            (byDate.entries.toList()
                                  ..sort((a, b) => b.key.compareTo(a.key)))
                                .firstOrNull
                                ?.value;
                        if (kg == null) return "--";
                        return isImperial
                            ? UnitConverter.displayWeight(
                                kg,
                                imperial: isImperial,
                              )
                            : kg.toStringAsFixed(1);
                      }(),
                      subtext: () {
                        final byDate =
                            ref.watch(weightLogsProvider).value ?? {};
                        // same fallback logic as the value above
                        final currentKg =
                            byDate[_todayDateKey()] ??
                            (byDate.entries.toList()
                                  ..sort((a, b) => b.key.compareTo(a.key)))
                                .firstOrNull
                                ?.value;
                        final goalKg = userData?.weightKgGoal;
                        final type = userData?.weightGoalType;
                        // no goal at all
                        if (goalKg == null && type == null) {
                          return "No weight goal set";
                        }
                        // goal type set but missing either a logged weight or a target weight
                        if (currentKg == null || goalKg == null) {
                          return type != null
                              ? "${type[0].toUpperCase()}${type.substring(1)}"
                              : "";
                        }
                        // how far the current weight is from the target, always positive
                        final delta = (currentKg - goalKg).abs();
                        final deltaDisplay = isImperial
                            ? "${UnitConverter.displayWeight(delta, imperial: isImperial)} lbs"
                            : "${delta.toStringAsFixed(1)} kg";
                        // direction-aware check: losing means at/under target, gaining means at/over, maintain is exact
                        final bool atOrPastGoal = type == 'lose'
                            ? currentKg <= goalKg
                            : type == 'gain'
                            ? currentKg >= goalKg
                            : currentKg == goalKg;
                        if (atOrPastGoal) return "You're at your goal weight!";
                        return "You're $deltaDisplay away from your goal";
                      }(),
                      showButtons: true,
                      onAdd: isGuest
                          ? () => Guest.block(
                              context,
                              title: 'Sign up to track weight',
                              description:
                                  'Create a free account to log your weight and track progress toward your goal.',
                            )
                          : onShowWeightSheet,
                      onChart: isGuest
                          ? () => Guest.block(
                              context,
                              title: 'Sign up to track weight',
                              description:
                                  'Create a free account to log your weight and track progress toward your goal.',
                            )
                          : () => context.push('/weight/analytics'),
                    ),
                    title: 'Sign up to track weight',
                    description:
                        'Create a free account to log your weight and track progress toward your goal.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading =
        !isGuest &&
        (ref.watch(userDataProvider).value == null ||
            ref.watch(foodLogsProvider).isLoading);
    return Skeletonizer(
      enabled: isLoading,
      effect: ShimmerEffect(
        baseColor: lightenColor(appColor, 0.10),
        highlightColor: lightenColor(appColor, 0.22),
      ),
      child: _buildLoggingCards(context),
    );
  }
}
