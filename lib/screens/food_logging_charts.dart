import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
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

    // Ordered meal data parallel to the sections list so the center label can
    // look up the tapped slice by index without re-filtering
    final calorieSections = <(String, double, Color, IconData)>[
      if (breakfastCal > 0)
        ("Breakfast", breakfastCal, breakfastColor, Icons.wb_sunny_rounded),
      if (lunchCal > 0)
        ("Lunch", lunchCal, lunchColor, Icons.lunch_dining_rounded),
      if (dinnerCal > 0)
        ("Dinner", dinnerCal, dinnerColor, Icons.dinner_dining_rounded),
      if (snacksCal > 0)
        ("Snacks", snacksCal, snacksColor, Icons.cookie_rounded),
    ];

    // gramString is pre-formatted here so _DonutCenterLabelMacro doesn't need macro access
    final macroSections = <(String, double, Color, IconData, String)>[
      if (proteinCal > 0)
        (
          "Protein",
          proteinCal,
          proteinColor,
          Icons.fitness_center_rounded,
          "${macros['protein']!.round()}",
        ),
      if (carbsCal > 0)
        (
          "Carbs",
          carbsCal,
          carbsColor,
          Icons.grain_rounded,
          "${macros['carbs']!.round()}",
        ),
      if (fatCal > 0)
        (
          "Fat",
          fatCal,
          fatColor,
          Icons.water_drop_rounded,
          "${macros['fat']!.round()}",
        ),
    ];

    return Container(
      decoration: BoxDecoration(gradient: buildThemeGradient()),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          scrolledUnderElevation: 0,
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

                // Summary stat tiles: calories, protein, carbs, fat at a glance
                _statTilesRow(
                  context: context,
                  totalCal: totalCal,
                  macros: macros,
                  proteinColor: proteinColor,
                  carbsColor: carbsColor,
                  fatColor: fatColor,
                ),

                SizedBox(height: Responsive.height(context, 24)),

                // Calorie breakdown section
                sectionHeader("CALORIE BREAKDOWN", context)
                    .animate()
                    .fadeIn(duration: 300.ms)
                    .slideY(
                      begin: 0.08,
                      duration: 300.ms,
                      curve: Curves.easeOut,
                    ),
                frostedGlassCard(
                      context,
                      padding: EdgeInsets.all(Responsive.scale(context, 20)),
                      child: totalCal == 0
                          ? _emptyState(
                              context,
                              "No calories logged for this day",
                            )
                          : Column(
                              children: [
                                SizedBox(
                                  height: Responsive.height(context, 280),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      PieChart(
                                        PieChartData(
                                          // Donut hole center label lives inside this space
                                          centerSpaceRadius: Responsive.scale(
                                            context,
                                            62,
                                          ),
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
                                                    // Pre-built with index so isTouched maps correctly to the filtered list
                                                    _touchedCalorieIndex =
                                                        response!
                                                            .touchedSection!
                                                            .touchedSectionIndex;
                                                  });
                                                },
                                          ),
                                          sections: calorieSections
                                              .asMap()
                                              .entries
                                              .map((e) {
                                                final (_, value, color, icon) =
                                                    e.value;
                                                return _section(
                                                  value,
                                                  totalCal,
                                                  color,
                                                  icon,
                                                  context,
                                                  isTouched:
                                                      _touchedCalorieIndex ==
                                                      e.key,
                                                );
                                              })
                                              .toList(),
                                        ),
                                      ),
                                      // Shows tapped meal name + kcal; falls back to day total when nothing is tapped
                                      _DonutCenterLabel(
                                        context: context,
                                        touchedIndex: _touchedCalorieIndex,
                                        sections: calorieSections
                                            .map((s) => (s.$1, s.$2, s.$3))
                                            .toList(),
                                        fallbackLabel: "Total",
                                        fallbackValue: "${totalCal.round()}",
                                        fallbackUnit: "kcal",
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  height: Responsive.height(context, 16),
                                ),
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
                    )
                    .animate()
                    .fadeIn(delay: 50.ms, duration: 300.ms)
                    .slideY(
                      begin: 0.08,
                      delay: 50.ms,
                      duration: 300.ms,
                      curve: Curves.easeOut,
                    ),

                SizedBox(height: Responsive.height(context, 24)),

                // Macro breakdown: slices sized by calorie equivalent
                sectionHeader("MACRO BREAKDOWN", context)
                    .animate()
                    .fadeIn(delay: 150.ms, duration: 300.ms)
                    .slideY(
                      begin: 0.08,
                      delay: 150.ms,
                      duration: 300.ms,
                      curve: Curves.easeOut,
                    ),
                frostedGlassCard(
                      context,
                      padding: EdgeInsets.all(Responsive.scale(context, 20)),
                      child: totalMacroCal == 0
                          ? _emptyState(context, "No macro data for this day")
                          : Column(
                              children: [
                                SizedBox(
                                  height: Responsive.height(context, 280),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      PieChart(
                                        PieChartData(
                                          centerSpaceRadius: Responsive.scale(
                                            context,
                                            62,
                                          ),
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
                                                    _touchedMacroIndex =
                                                        response!
                                                            .touchedSection!
                                                            .touchedSectionIndex;
                                                  });
                                                },
                                          ),
                                          sections: macroSections
                                              .asMap()
                                              .entries
                                              .map((e) {
                                                final (
                                                  _,
                                                  value,
                                                  color,
                                                  icon,
                                                  _g,
                                                ) = e.value;
                                                return _section(
                                                  value,
                                                  totalMacroCal,
                                                  color,
                                                  icon,
                                                  context,
                                                  isTouched:
                                                      _touchedMacroIndex ==
                                                      e.key,
                                                );
                                              })
                                              .toList(),
                                        ),
                                      ),
                                      // Shows tapped macro name + grams; falls back to total grams when nothing is tapped
                                      _DonutCenterLabelMacro(
                                        context: context,
                                        touchedIndex: _touchedMacroIndex,
                                        sections: macroSections
                                            .map((s) => (s.$1, s.$3, s.$5))
                                            .toList(),
                                        fallbackLabel: "Total",
                                        fallbackValue:
                                            "${(macros['protein']! + macros['carbs']! + macros['fat']!).round()}",
                                        fallbackUnit: "g",
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  height: Responsive.height(context, 16),
                                ),
                                // Legend shows the grams per macro
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
                    )
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 300.ms)
                    .slideY(
                      begin: 0.08,
                      delay: 200.ms,
                      duration: 300.ms,
                      curve: Curves.easeOut,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Builds a single pie chart slice showing its percentage on the slice face
  // The icon badge sits near the outer rim using badgeWidget and badgePositionPercentageOffset
  // Tapped slices grow outward and show a larger label to confirm the interaction
  PieChartSectionData _section(
    double value,
    double total,
    Color color,
    IconData icon,
    BuildContext context, {
    bool isTouched = false,
  }) {
    final percent = (value / total * 100).round();
    return PieChartSectionData(
      value: value,
      // Dim untouched slices slightly so the tapped one stands out
      color: isTouched ? color : color.withAlpha(210),
      radius: isTouched
          ? Responsive.scale(context, 85)
          : Responsive.scale(context, 72),
      title: "$percent%",
      titleStyle: GoogleFonts.manrope(
        fontSize: isTouched
            ? Responsive.font(context, 15)
            : Responsive.font(context, 12),
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
      badgeWidget: Icon(
        icon,
        color: Colors.white.withAlpha(isTouched ? 255 : 180),
        size: Responsive.font(context, isTouched ? 18 : 14),
      ),
      // 0.85 places the badge near the outer rim rather than the midpoint of the slice radius
      badgePositionPercentageOffset: 0.85,
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

// Center label for the calorie donut chart
// Shows tapped meal name and kcal and falls back to total when nothing is tapped
class _DonutCenterLabel extends StatelessWidget {
  final BuildContext context;
  final int touchedIndex;
  final List<(String, double, Color)> sections;
  final String fallbackLabel;
  final String fallbackValue;
  final String fallbackUnit;

  const _DonutCenterLabel({
    required this.context,
    required this.touchedIndex,
    required this.sections,
    required this.fallbackLabel,
    required this.fallbackValue,
    required this.fallbackUnit,
  });

  @override
  Widget build(BuildContext ctx) {
    final isTouched = touchedIndex >= 0 && touchedIndex < sections.length;
    final label = isTouched ? sections[touchedIndex].$1 : fallbackLabel;
    final value = isTouched
        ? "${sections[touchedIndex].$2.round()}"
        : fallbackValue;
    final unit = isTouched ? "kcal" : fallbackUnit;
    final color = isTouched ? sections[touchedIndex].$3 : Colors.white;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 22),
            fontWeight: FontWeight.w800,
            color: color,
            height: 1,
          ),
        ),
        SizedBox(height: Responsive.height(context, 2)),
        Text(
          unit,
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 10),
            fontWeight: FontWeight.w500,
            color: Colors.white38,
          ),
        ),
        SizedBox(height: Responsive.height(context, 4)),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 11),
            fontWeight: FontWeight.w600,
            color: color.withAlpha(180),
          ),
        ),
      ],
    );
  }
}

// Center label for the macro donut chart
// sections is (label, color, gramString)
// Shows tapped macro name + grams; falls back to total kcal when nothing is tapped
class _DonutCenterLabelMacro extends StatelessWidget {
  final BuildContext context;
  final int touchedIndex;
  final List<(String, Color, String)> sections;
  final String fallbackLabel;
  final String fallbackValue;
  final String fallbackUnit;

  const _DonutCenterLabelMacro({
    required this.context,
    required this.touchedIndex,
    required this.sections,
    required this.fallbackLabel,
    required this.fallbackValue,
    required this.fallbackUnit,
  });

  @override
  Widget build(BuildContext ctx) {
    final isTouched = touchedIndex >= 0 && touchedIndex < sections.length;
    final label = isTouched ? sections[touchedIndex].$1 : fallbackLabel;
    final value = isTouched ? sections[touchedIndex].$3 : fallbackValue;
    // value is always a plain number. "g" unit label always shown separately to match the kcal style
    final unit = fallbackUnit;
    final color = isTouched ? sections[touchedIndex].$2 : Colors.white;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 22),
            fontWeight: FontWeight.w800,
            color: color,
            height: 1,
          ),
        ),
        if (unit.isNotEmpty) ...[
          SizedBox(height: Responsive.height(context, 2)),
          Text(
            unit,
            style: GoogleFonts.manrope(
              fontSize: Responsive.font(context, 10),
              fontWeight: FontWeight.w500,
              color: Colors.white38,
            ),
          ),
        ],
        SizedBox(height: Responsive.height(context, 4)),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 11),
            fontWeight: FontWeight.w600,
            color: color.withAlpha(180),
          ),
        ),
      ],
    );
  }
}

// The four tiles shown between the date picker and the charts
// total calories, protein, carbs, and fat for the selected day
Widget _statTilesRow({
  required BuildContext context,
  required double totalCal,
  required Map<String, double> macros,
  required Color proteinColor,
  required Color carbsColor,
  required Color fatColor,
}) {
  // IntrinsicHeight forces all tiles to match the height of the tallest one
  return IntrinsicHeight(
        child: Row(
          children: [
            // Calories tile is wider since it anchors the whole summary
            Expanded(
              flex: 5,
              child: _statTile(
                context: context,
                icon: Icons.local_fire_department_rounded,
                iconColor: const Color(0xFFF97316),
                label: "Calories",
                value: totalCal == 0 ? "—" : totalCal.round().toString(),
                unit: totalCal == 0 ? "" : "kcal",
              ),
            ),
            SizedBox(width: Responsive.width(context, 10)),
            // Macro tiles share equal remaining space
            Expanded(
              flex: 4,
              child: _statTile(
                context: context,
                icon: Icons.fitness_center_rounded,
                iconColor: proteinColor,
                label: "Protein",
                value: macros['protein'] == 0
                    ? "—"
                    : macros['protein']!.round().toString(),
                unit: macros['protein'] == 0 ? "" : "g",
              ),
            ),
            SizedBox(width: Responsive.width(context, 10)),
            Expanded(
              flex: 4,
              child: _statTile(
                context: context,
                icon: Icons.grain_rounded,
                iconColor: carbsColor,
                label: "Carbs",
                value: macros['carbs'] == 0
                    ? "—"
                    : macros['carbs']!.round().toString(),
                unit: macros['carbs'] == 0 ? "" : "g",
              ),
            ),
            SizedBox(width: Responsive.width(context, 10)),
            Expanded(
              flex: 4,
              child: _statTile(
                context: context,
                icon: Icons.water_drop_rounded,
                iconColor: fatColor,
                label: "Fat",
                value: macros['fat'] == 0
                    ? "—"
                    : macros['fat']!.round().toString(),
                unit: macros['fat'] == 0 ? "" : "g",
              ),
            ),
          ],
        ),
      )
      .animate()
      .fadeIn(duration: 300.ms)
      .slideY(begin: 0.08, duration: 300.ms, curve: Curves.easeOut);
}

// Single frosted-glass stat tile with a colored icon, large value, unit, and pill label
Widget _statTile({
  required BuildContext context,
  required IconData icon,
  required Color iconColor,
  required String label,
  required String value,
  required String unit,
}) {
  return frostedGlassCard(
    context,
    padding: EdgeInsets.symmetric(
      horizontal: Responsive.width(context, 10),
      vertical: Responsive.height(context, 14),
    ),
    // SizedBox.expand fills the height IntrinsicHeight establishes from the tallest sibling tile
    child: SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: Responsive.font(context, 20)),
          SizedBox(height: Responsive.height(context, 6)),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: Responsive.font(context, 18),
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1,
            ),
          ),
          if (unit.isNotEmpty) ...[
            SizedBox(height: Responsive.height(context, 2)),
            Text(
              unit,
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 10),
                fontWeight: FontWeight.w500,
                color: Colors.white38,
              ),
            ),
          ],
          SizedBox(height: Responsive.height(context, 6)),
          // FittedBox shrinks the pill label to fit on one line regardless of available width
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.width(context, 8),
                vertical: Responsive.height(context, 3),
              ),
              decoration: BoxDecoration(
                color: iconColor.withAlpha(40),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                label,
                maxLines: 1,
                style: GoogleFonts.manrope(
                  fontSize: Responsive.font(context, 10),
                  fontWeight: FontWeight.w600,
                  color: iconColor,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
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
