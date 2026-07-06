import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/providers/user_data_provider.dart';
import '/services/user_data_manager.dart' show defaultAppColor;
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../authentication/auth_services.dart';
import '../../globals.dart';
import '../../utility/responsive.dart';
import '../../utility/unit_converter.dart';
import '../../utility/food_logging_helper.dart' show FoodLoggingHelper;

String _todayDateKey() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

// Calculates total calories logged today
int _todayCalories() {
  final key = _todayDateKey();
  final logs = currentUserData?.foodLogs.where((f) => f['date'] == key) ?? [];
  int total = 0;
  for (final food in logs) {
    total += (num.tryParse(food['calories'].toString()) ?? 0).toInt();
  }
  return total;
}

// Returns today's total protein/carbs/fat in grams
({int protein, int carbs, int fat}) _todayMacros() {
  final key = _todayDateKey();
  final logs = currentUserData?.foodLogs.where((f) => f['date'] == key) ?? [];
  int protein = 0, carbs = 0, fat = 0;
  for (final food in logs) {
    final macros = FoodLoggingHelper.extractMacrosFromFood(food);
    protein += (macros['protein'] ?? 0.0).toInt();
    carbs += (macros['carbs'] ?? 0.0).toInt();
    fat += (macros['fat'] ?? 0.0).toInt();
  }
  return (protein: protein, carbs: carbs, fat: fat);
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
  Color get appColor =>
      ref.read(userDataProvider).value?.appColor ?? defaultAppColor;

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
                      'onFoodLogged': () {},
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
    final accentColor = lightenColor(appColor, 0.45);
    final dimColor = lightenColor(appColor, 0.35);
    final macros = isGuest ? (protein: 0, carbs: 0, fat: 0) : _todayMacros();

    Widget macroRow(String label, IconData icon, int value, int? goal) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // label left
          Text(
            label,
            style: GoogleFonts.manrope(
              color: dimColor,
              fontSize: Responsive.font(context, 11),
              fontWeight: FontWeight.w600,
            ),
          ),
          // value center
          Expanded(
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: "${value}g",
                    style: GoogleFonts.manrope(
                      color: accentColor,
                      fontSize: Responsive.font(context, 15),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (goal != null)
                    TextSpan(
                      text: " /${goal}g",
                      style: GoogleFonts.manrope(
                        color: dimColor,
                        fontSize: Responsive.font(context, 11),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // icon right
          HugeIcon(
            icon: icon,
            color: dimColor,
            size: Responsive.scale(context, 13),
          ),
        ],
      );
    }

    return frostedGlassCard(
      context,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.width(context, 16),
        vertical: Responsive.height(context, 10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedAppleStocks,
                color: accentColor,
                size: Responsive.scale(context, 14),
              ),
              SizedBox(width: Responsive.width(context, 5)),
              Text(
                "Today's Macros",
                style: GoogleFonts.manrope(
                  color: accentColor,
                  fontSize: Responsive.font(context, 11),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.height(context, 6)),
          macroRow(
            "P",
            HugeIcons.strokeRoundedBodyPartMuscle,
            macros.protein,
            currentUserData?.proteinGoal,
          ),
          SizedBox(height: Responsive.height(context, 2)),
          macroRow(
            "C",
            HugeIcons.strokeRoundedFire,
            macros.carbs,
            currentUserData?.carbsGoal,
          ),
          SizedBox(height: Responsive.height(context, 2)),
          macroRow(
            "F",
            HugeIcons.strokeRoundedDroplet,
            macros.fat,
            currentUserData?.fatGoal,
          ),
        ],
      ),
    );
  }

  Widget _buildGuestLoggingCard(BuildContext context) {
    final accent = lightenColor(appColor, 0.45);
    return GestureDetector(
      onTap: () async => authService.value.signOut(),
      child: Stack(
        children: [
          IgnorePointer(
            child: Opacity(opacity: 0.35, child: _buildLoggingCards(context)),
          ),
          Positioned.fill(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedLockPassword,
                    color: accent,
                    size: Responsive.scale(context, 28),
                  ),
                  SizedBox(height: Responsive.height(context, 6)),
                  Text(
                    "Sign up to unlock",
                    style: GoogleFonts.manrope(
                      color: accent,
                      fontSize: Responsive.font(context, 14),
                      fontWeight: FontWeight.w700,
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

  Widget _buildLoggingCards(BuildContext context) {
    final isImperial = UnitConverter.isImperial;
    final calories = _todayCalories();
    final goal = currentUserData?.caloriesGoal ?? 0;
    final progress = goal > 0 ? (calories / goal).clamp(0.0, 1.0) : 0.0;

    // water progress
    final totalWaterMl =
        (currentUserData?.waterEntriesByDate[_todayDateKey()] ?? []).fold(
          0,
          (s, e) => s + e,
        );
    final waterGoalMl = currentUserData?.waterMlGoal ?? 0;
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
                  child: _buildLoggingCard(
                    context,
                    icon: HugeIcons.strokeRoundedFire,
                    label: "Today's Calories",
                    value: isGuest ? "--" : "$calories",
                    subtext: goal > 0 ? "/ $goal goal" : "kcal",
                    progressBar: progressBar,
                    showButtons: !isGuest,
                    onAdd: () => _showMealPicker(context),
                    onAddIcon: Icons.add,
                    onChart: () => context.push(
                      '/food-logging/analytics',
                      extra: {
                        'initialDate': DateTime.now(),
                        'onDateChanged': null,
                        'noAnimation': true,
                      },
                    ),
                  ),
                ),
                SizedBox(height: Responsive.height(context, 12)),
                Expanded(
                  child: _buildLoggingCard(
                    context,
                    icon: HugeIcons.strokeRoundedDroplet,
                    label: "Water",
                    value: isGuest
                        ? "--"
                        : isImperial
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
                    showButtons: !isGuest,
                    onAdd: onShowWaterSheet,
                    onChart: () => context.push('/water/analytics'),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: Responsive.width(context, 12)),
          Expanded(
            child: Column(
              children: [
                Expanded(child: _buildMacrosCard(context)),
                SizedBox(height: Responsive.height(context, 12)),
                Expanded(
                  child: _buildLoggingCard(
                    context,
                    icon: HugeIcons.strokeRoundedWeightScale,
                    label: "Weight",
                    value: () {
                      // use today's entry, or fall back to the most recent logged weight
                      final byDate = currentUserData?.weightByDate ?? {};
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
                      final byDate = currentUserData?.weightByDate ?? {};
                      // same fallback logic as the value above
                      final currentKg =
                          byDate[_todayDateKey()] ??
                          (byDate.entries.toList()
                                ..sort((a, b) => b.key.compareTo(a.key)))
                              .firstOrNull
                              ?.value;
                      final goalKg = currentUserData?.weightKgGoal;
                      final type = currentUserData?.weightGoalType;
                      // no goal at all
                      if (goalKg == null && type == null) {
                        return "No weight goal set";
                      }
                      // goal type set but missing either a logged weight or a target weight
                      if (currentKg == null || goalKg == null) {
                        final label = UnitConverter.weightUnit(
                          imperial: isImperial,
                        );
                        return type != null
                            ? "${type[0].toUpperCase()}${type.substring(1)} · $label"
                            : label;
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
                    showButtons: !isGuest,
                    onAdd: onShowWeightSheet,
                    onChart: () => context.push('/weight/analytics'),
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
    return isGuest
        ? _buildGuestLoggingCard(context)
        : _buildLoggingCards(context);
  }
}
