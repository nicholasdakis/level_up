import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../globals.dart';
import '../utility/responsive.dart';
import '../utility/food_logging_helper.dart';

// initialDate opens the screen on the same date the user was viewing in Food Logging
// onDateChanged is optional so Food Logging can stay in sync when dates are changed here
class FoodLoggingChartsScreen extends StatefulWidget {
  final DateTime initialDate;
  final void Function(DateTime)? onDateChanged;

  const FoodLoggingChartsScreen({
    super.key,
    required this.initialDate,
    this.onDateChanged,
  });

  @override
  State<FoodLoggingChartsScreen> createState() =>
      _FoodLoggingChartsScreenState();
}

class _FoodLoggingChartsScreenState extends State<FoodLoggingChartsScreen> {
  late DateTime currentDate;

  // Meal lists for the currently selected date
  List<Map<String, dynamic>> breakfastFoods = [];
  List<Map<String, dynamic>> lunchFoods = [];
  List<Map<String, dynamic>> dinnerFoods = [];
  List<Map<String, dynamic>> snacksFoods = [];

  // Which slice is currently tapped (-1 means none)
  int _touchedCalorieIndex = -1;
  int _touchedMacroIndex = -1;

  @override
  void initState() {
    super.initState();
    currentDate = widget.initialDate;
    _loadForDate(currentDate);
  }

  // Reads directly from the in-memory cache
  void _loadForDate(DateTime date) {
    final foodDataByDate = currentUserData?.foodDataByDate ?? {};
    // formatDateKey converts DateTime to the string key used in the map (eg "2026-04-23")
    final dayData = foodDataByDate[FoodLoggingHelper.formatDateKey(date)];
    setState(() {
      // castFoodList safely casts the raw dynamic list to the typed meal list format
      breakfastFoods = FoodLoggingHelper.castFoodList(dayData?['breakfast']);
      lunchFoods = FoodLoggingHelper.castFoodList(dayData?['lunch']);
      dinnerFoods = FoodLoggingHelper.castFoodList(dayData?['dinner']);
      snacksFoods = FoodLoggingHelper.castFoodList(dayData?['snacks']);
      // Clear any tapped slice so a stale highlight doesn't carry over to a new date
      _touchedCalorieIndex = -1;
      _touchedMacroIndex = -1;
    });
  }

  // Notifies Food Logging via callback so both screens stay on the same date
  void _changeDate(DateTime date) {
    currentDate = date;
    _loadForDate(date);
    widget.onDateChanged?.call(date);
  }

  // Sums the calories stored directly on each food map for a given meal list
  double _mealCalories(List<Map<String, dynamic>> foods) {
    double total = 0;
    for (var food in foods) {
      // toString() before parsing handles cases where calories were stored as int or double
      total += (num.tryParse(food['calories'].toString()) ?? 0).toDouble();
    }
    return total;
  }

  // Totals protein, carbs, and fat across all meals for the selected day
  Map<String, double> _totalMacros() {
    double protein = 0, carbs = 0, fat = 0;
    // Spread operator combines all four meal lists into one so they can be looped over once
    for (var food in [
      ...breakfastFoods,
      ...lunchFoods,
      ...dinnerFoods,
      ...snacksFoods,
    ]) {
      // Macros are stored inside the food_description string and parsed out via regex
      final macros = FoodLoggingHelper.extractMacros(
        food['food_description'] as String? ?? '',
      );
      protein += macros['protein'] ?? 0;
      carbs += macros['carbs'] ?? 0;
      fat += macros['fat'] ?? 0;
    }
    return {'protein': protein, 'carbs': carbs, 'fat': fat};
  }

  @override
  Widget build(BuildContext context) {
    // Calorie totals per meal, used for the calorie breakdown chart
    final breakfastCal = _mealCalories(breakfastFoods);
    final lunchCal = _mealCalories(lunchFoods);
    final dinnerCal = _mealCalories(dinnerFoods);
    final snacksCal = _mealCalories(snacksFoods);
    final totalCal = breakfastCal + lunchCal + dinnerCal + snacksCal;

    final macros = _totalMacros();
    // Protein and carbs are 4 kcal/g, fat is 9 kcal/g
    // These convert grams to calories so each macro's slice reflects its actual contribution
    final proteinCal = macros['protein']! * 4;
    final carbsCal = macros['carbs']! * 4;
    final fatCal = macros['fat']! * 9;
    final totalMacroCal = proteinCal + carbsCal + fatCal;

    // Meal colors
    const breakfastColor = Color(0xFFF59E0B);
    const lunchColor = Color(0xFF10B981);
    const dinnerColor = Color(0xFF6366F1);
    const snacksColor = Color(0xFFF43F5E);

    // Macro colors
    const proteinColor = Color(0xFF3B82F6);
    const carbsColor = Color(0xFFF59E0B);
    const fatColor = Color(0xFFF43F5E);

    return Container(
      decoration: BoxDecoration(gradient: buildThemeGradient()),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: darkenColor(appColorNotifier.value, 0.025),
          centerTitle: true,
          toolbarHeight: Responsive.height(context, 100),
          // Down arrow icon
          leading: IconButton(
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white,
              size: Responsive.font(context, 28),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: createTitle("Food Analytics", context),
          // Thin divider line
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(Responsive.height(context, 1)),
            child: Container(
              height: Responsive.height(context, 1),
              color: Colors.white.withAlpha(25),
            ),
          ),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.width(context, 50),
              vertical: Responsive.height(context, 24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Date navigation shared with Food Logging via DateNavigationRow in globals.dart
                DateNavigationRow(
                  currentDate: currentDate,
                  onDateChanged: _changeDate,
                ),

                SizedBox(height: Responsive.height(context, 16)),

                // Calorie breakdown section
                sectionHeader("CALORIE BREAKDOWN", context),
                frostedGlassCard(
                  context,
                  padding: EdgeInsets.all(Responsive.scale(context, 20)),
                  child: totalCal == 0
                      ? _emptyState(context, "No calories logged for this day")
                      : Column(
                          children: [
                            SizedBox(
                              height: Responsive.height(context, 280),
                              child: PieChart(
                                PieChartData(
                                  centerSpaceRadius: 0,
                                  sectionsSpace: 2,
                                  pieTouchData: PieTouchData(
                                    touchCallback:
                                        (
                                          FlTouchEvent event,
                                          PieTouchResponse? response,
                                        ) {
                                          setState(() {
                                            if (!event
                                                    .isInterestedForInteractions ||
                                                response?.touchedSection ==
                                                    null) {
                                              _touchedCalorieIndex = -1;
                                              return;
                                            }
                                            _touchedCalorieIndex = response!
                                                .touchedSection!
                                                .touchedSectionIndex;
                                          });
                                        },
                                  ),
                                  // Pre-built with index so isTouched maps correctly to the filtered list
                                  sections:
                                      <(double, Color)>[
                                            if (breakfastCal > 0)
                                              (breakfastCal, breakfastColor),
                                            if (lunchCal > 0)
                                              (lunchCal, lunchColor),
                                            if (dinnerCal > 0)
                                              (dinnerCal, dinnerColor),
                                            if (snacksCal > 0)
                                              (snacksCal, snacksColor),
                                          ]
                                          .asMap()
                                          .entries
                                          .map(
                                            (e) => _section(
                                              e.value.$1,
                                              totalCal,
                                              e.value.$2,
                                              context,
                                              isTouched:
                                                  _touchedCalorieIndex == e.key,
                                            ),
                                          )
                                          .toList(),
                                ),
                              ),
                            ),
                            SizedBox(height: Responsive.height(context, 16)),
                            // Color coded legend showing each meal's calorie count
                            _legend(context, [
                              if (breakfastCal > 0)
                                _LegendItem(
                                  "Breakfast",
                                  breakfastCal.round(),
                                  breakfastColor,
                                ),
                              if (lunchCal > 0)
                                _LegendItem(
                                  "Lunch",
                                  lunchCal.round(),
                                  lunchColor,
                                ),
                              if (dinnerCal > 0)
                                _LegendItem(
                                  "Dinner",
                                  dinnerCal.round(),
                                  dinnerColor,
                                ),
                              if (snacksCal > 0)
                                _LegendItem(
                                  "Snacks",
                                  snacksCal.round(),
                                  snacksColor,
                                ),
                            ]),
                          ],
                        ),
                ),

                SizedBox(height: Responsive.height(context, 24)),

                // Macro breakdown: slices sized by calorie equivalent
                sectionHeader("MACRO BREAKDOWN", context),
                frostedGlassCard(
                  context,
                  padding: EdgeInsets.all(Responsive.scale(context, 20)),
                  child: totalMacroCal == 0
                      ? _emptyState(context, "No macro data for this day")
                      : Column(
                          children: [
                            SizedBox(
                              height: Responsive.height(context, 280),
                              child: PieChart(
                                PieChartData(
                                  centerSpaceRadius: 0,
                                  sectionsSpace: 2,
                                  pieTouchData: PieTouchData(
                                    touchCallback:
                                        (
                                          FlTouchEvent event,
                                          PieTouchResponse? response,
                                        ) {
                                          setState(() {
                                            if (!event
                                                    .isInterestedForInteractions ||
                                                response?.touchedSection ==
                                                    null) {
                                              _touchedMacroIndex = -1;
                                              return;
                                            }
                                            _touchedMacroIndex = response!
                                                .touchedSection!
                                                .touchedSectionIndex;
                                          });
                                        },
                                  ),
                                  sections:
                                      <(double, Color)>[
                                            if (proteinCal > 0)
                                              (proteinCal, proteinColor),
                                            if (carbsCal > 0)
                                              (carbsCal, carbsColor),
                                            if (fatCal > 0) (fatCal, fatColor),
                                          ]
                                          .asMap()
                                          .entries
                                          .map(
                                            (e) => _section(
                                              e.value.$1,
                                              totalMacroCal,
                                              e.value.$2,
                                              context,
                                              isTouched:
                                                  _touchedMacroIndex == e.key,
                                            ),
                                          )
                                          .toList(),
                                ),
                              ),
                            ),
                            SizedBox(height: Responsive.height(context, 16)),
                            // Legend shows grams instead of kcal since macros are tracked in grams
                            _legend(context, [
                              if (proteinCal > 0)
                                _LegendItem(
                                  "Protein",
                                  macros['protein']!.round(),
                                  proteinColor,
                                  unit: "g",
                                ),
                              if (carbsCal > 0)
                                _LegendItem(
                                  "Carbs",
                                  macros['carbs']!.round(),
                                  carbsColor,
                                  unit: "g",
                                ),
                              if (fatCal > 0)
                                _LegendItem(
                                  "Fat",
                                  macros['fat']!.round(),
                                  fatColor,
                                  unit: "g",
                                ),
                            ]),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Builds a single pie chart slice showing its percentage of the total
  // Tapped slices grow outward and show a larger label to confirm the interaction
  PieChartSectionData _section(
    double value,
    double total,
    Color color,
    BuildContext context, {
    bool isTouched = false,
  }) {
    final percent = (value / total * 100).round();
    return PieChartSectionData(
      value: value,
      // Dim untouched slices slightly so the tapped one stands out
      color: isTouched ? color : color.withAlpha(210),
      radius: isTouched
          ? Responsive.scale(context, 125)
          : Responsive.scale(context, 110),
      title: "$percent%",
      titleStyle: GoogleFonts.manrope(
        fontSize: isTouched
            ? Responsive.font(context, 15)
            : Responsive.font(context, 13),
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    );
  }

  // Builds a row of colored dot and label pairs below each chart
  // Wrap is used instead of Row so items reflow onto a new line on smaller screens
  Widget _legend(BuildContext context, List<_LegendItem> items) {
    return Wrap(
      spacing: Responsive.width(context, 16),
      runSpacing: Responsive.height(context, 8),
      alignment: WrapAlignment.center,
      children: items.map((item) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Colored dot matching the slice color
            Container(
              width: Responsive.scale(context, 10),
              height: Responsive.scale(context, 10),
              decoration: BoxDecoration(
                color: item.color,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: Responsive.width(context, 6)),
            Text(
              "${item.label}: ${item.value}${item.unit}",
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 13),
                color: Colors.white70,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  // Shown in place of the chart when no data is logged for the selected day
  Widget _emptyState(BuildContext context, String message) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: Responsive.height(context, 24)),
      child: Center(
        child: Text(
          message,
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 14),
            color: Colors.white38,
          ),
        ),
      ),
    );
  }
}

// Data class for a single legend entry
// unit defaults to kcal for calorie breakdown, overridden to "g" for macro breakdown
class _LegendItem {
  final String label;
  final int value;
  final Color color;
  final String unit;
  const _LegendItem(this.label, this.value, this.color, {this.unit = " kcal"});
}
