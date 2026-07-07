import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/providers/user_data_provider.dart';
import '/providers/food_logs_provider.dart';
import '/services/user_data_manager.dart' show defaultAppColor;
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../globals.dart';
import '../../utility/responsive.dart';
import '../../utility/food_logging_helper.dart';
import 'analytics_components.dart';

// initialDate opens the screen on the same date the user was viewing in Food Logging
// onDateChanged is optional so Food Logging can stay in sync when dates are changed here
class FoodAnalyticsScreen extends ConsumerStatefulWidget {
  final DateTime initialDate;
  final void Function(DateTime)? onDateChanged;

  const FoodAnalyticsScreen({
    super.key,
    required this.initialDate,
    this.onDateChanged,
  });

  @override
  ConsumerState<FoodAnalyticsScreen> createState() =>
      _FoodAnalyticsScreenState();
}

class _FoodAnalyticsScreenState extends ConsumerState<FoodAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  Color get appColor => ref.watch(
    userDataProvider.select((s) => s.value?.appColor ?? defaultAppColor),
  );

  late TabController _tabController;
  late DateTime currentDate;

  // Daily tab state
  List<Map<String, dynamic>> breakfastFoods = [];
  List<Map<String, dynamic>> lunchFoods = [];
  List<Map<String, dynamic>> dinnerFoods = [];
  List<Map<String, dynamic>> snacksFoods = [];

  // incrementing this re-triggers all .animate(key: ValueKey(...)) animations on date change
  // flutter_animate only replays when the key changes, not on every rebuild
  int _animationKey = 0;

  // Range tab state
  // default to the last 7 days so the range tab is immediately useful on first open
  DateTime? _rangeStart = DateTime.now().subtract(const Duration(days: 6));
  DateTime? _rangeEnd = DateTime.now();
  bool _rangeSelected = true;
  DateTime _calendarFocused = DateTime.now();

  // same key trick as _animationKey but for the range tab charts
  int _rangeAnimationKey = 0;

  @override
  void initState() {
    super.initState();
    FirebaseAnalytics.instance.logScreenView(
      screenName: '/food-logging/analytics',
      screenClass: 'FoodAnalyticsScreen',
    );
    _tabController = TabController(length: 2, vsync: this);
    currentDate = widget.initialDate;
    _loadForDate(currentDate);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadForDate(DateTime date) {
    final dateKey = FoodLoggingHelper.formatDateKey(date);
    final logs = (ref.read(foodLogsProvider).value ?? [])
        .map((f) => f.toJson())
        .toList();
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
      _animationKey++;
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
      final macros = FoodLoggingHelper.extractMacrosFromFood(food);
      protein += macros['protein'] ?? 0;
      carbs += macros['carbs'] ?? 0;
      fat += macros['fat'] ?? 0;
    }
    return {'protein': protein, 'carbs': carbs, 'fat': fat};
  }

  // Same as _totalMacros but scoped to a single meal list
  Map<String, double> _mealMacros(List<Map<String, dynamic>> foods) {
    double protein = 0, carbs = 0, fat = 0;
    for (var food in foods) {
      final m = FoodLoggingHelper.extractMacrosFromFood(food);
      protein += m['protein'] ?? 0;
      carbs += m['carbs'] ?? 0;
      fat += m['fat'] ?? 0;
    }
    return {'protein': protein, 'carbs': carbs, 'fat': fat};
  }

  // Goes through all days and sums the calories and macros
  // daysWithData is returned to compute averages without using empty days
  _RangeAggregate _aggregateRange(DateTime start, DateTime end) {
    final logs = (ref.read(foodLogsProvider).value ?? [])
        .map((f) => f.toJson())
        .toList();
    final startKey = FoodLoggingHelper.formatDateKey(start);
    final endKey = FoodLoggingHelper.formatDateKey(end);
    final inRange = logs.where((f) {
      final d = f['date'] as String? ?? '';
      return d.compareTo(startKey) >= 0 && d.compareTo(endKey) <= 0;
    }).toList();

    double totalCal = 0;
    double protein = 0, carbs = 0, fat = 0;
    double breakfastCal = 0, lunchCal = 0, dinnerCal = 0, snacksCal = 0;
    double bP = 0, bC = 0, bF = 0;
    double lP = 0, lC = 0, lF = 0;
    double dP = 0, dC = 0, dF = 0;
    double sP = 0, sC = 0, sF = 0;

    final daysWithData = inRange.map((f) => f['date']).toSet().length;

    for (final food in inRange) {
      final cal = (num.tryParse(food['calories'].toString()) ?? 0).toDouble();
      final m = FoodLoggingHelper.extractMacrosFromFood(food);
      totalCal += cal;
      protein += m['protein'] ?? 0;
      carbs += m['carbs'] ?? 0;
      fat += m['fat'] ?? 0;
      switch (food['meal']) {
        case 'breakfast':
          breakfastCal += cal;
          bP += m['protein'] ?? 0;
          bC += m['carbs'] ?? 0;
          bF += m['fat'] ?? 0;
        case 'lunch':
          lunchCal += cal;
          lP += m['protein'] ?? 0;
          lC += m['carbs'] ?? 0;
          lF += m['fat'] ?? 0;
        case 'dinner':
          dinnerCal += cal;
          dP += m['protein'] ?? 0;
          dC += m['carbs'] ?? 0;
          dF += m['fat'] ?? 0;
        case 'snacks':
          snacksCal += cal;
          sP += m['protein'] ?? 0;
          sC += m['carbs'] ?? 0;
          sF += m['fat'] ?? 0;
      }
    }

    return _RangeAggregate(
      totalCal: totalCal,
      breakfastCal: breakfastCal,
      lunchCal: lunchCal,
      dinnerCal: dinnerCal,
      snacksCal: snacksCal,
      protein: protein,
      carbs: carbs,
      fat: fat,
      daysWithData: daysWithData,
      breakfastProtein: bP,
      breakfastCarbs: bC,
      breakfastFat: bF,
      lunchProtein: lP,
      lunchCarbs: lC,
      lunchFat: lF,
      dinnerProtein: dP,
      dinnerCarbs: dC,
      dinnerFat: dF,
      snacksProtein: sP,
      snacksCarbs: sC,
      snacksFat: sF,
    );
  }

  // Returns per-day calorie and macro data for the line charts
  List<_DayPoint> _dailyPoints(DateTime start, DateTime end) {
    final logs = (ref.read(foodLogsProvider).value ?? [])
        .map((f) => f.toJson())
        .toList();
    final startKey = FoodLoggingHelper.formatDateKey(start);
    final endKey = FoodLoggingHelper.formatDateKey(end);
    final inRange = logs.where((f) {
      final d = f['date'] as String? ?? '';
      return d.compareTo(startKey) >= 0 && d.compareTo(endKey) <= 0;
    }).toList();

    final byDate = <String, List<Map<String, dynamic>>>{};
    for (final f in inRange) {
      final d = f['date'] as String;
      byDate.putIfAbsent(d, () => []).add(f);
    }

    final points = <_DayPoint>[];
    for (final entry in byDate.entries) {
      final dayFoods = entry.value;
      double cal = 0, protein = 0, carbs = 0, fat = 0;
      double bCal = 0, lCal = 0, dCal = 0, sCal = 0;
      for (final food in dayFoods) {
        final c = (num.tryParse(food['calories'].toString()) ?? 0).toDouble();
        final m = FoodLoggingHelper.extractMacrosFromFood(food);
        cal += c;
        protein += m['protein'] ?? 0;
        carbs += m['carbs'] ?? 0;
        fat += m['fat'] ?? 0;
        switch (food['meal']) {
          case 'breakfast':
            bCal += c;
          case 'lunch':
            lCal += c;
          case 'dinner':
            dCal += c;
          case 'snacks':
            sCal += c;
        }
      }
      points.add(
        _DayPoint(
          date: DateTime.parse(entry.key),
          cal: cal,
          breakfastCal: bCal,
          lunchCal: lCal,
          dinnerCal: dCal,
          snacksCal: sCal,
          protein: protein,
          carbs: carbs,
          fat: fat,
        ),
      );
    }
    points.sort((a, b) => a.date.compareTo(b.date));
    return points;
  }

  Widget _calorieLineChart(BuildContext context, List<_DayPoint> points) {
    final accent = lightenColor(appColor, 0.45);
    final dim = lightenColor(appColor, 0.35);

    if (points.isEmpty) {
      return frostedGlassCard(
        context,
        color: appColor,
        padding: EdgeInsets.all(Responsive.scale(context, 20)),
        child: _emptyState(context, "No calories logged in this range"),
      );
    }

    final spots = [
      for (int i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].cal),
    ];
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);

    return frostedGlassCard(
      context,
      color: appColor,
      padding: EdgeInsets.all(Responsive.scale(context, 16)),
      child: SizedBox(
        height: Responsive.isDesktop(context)
            ? 420
            : Responsive.height(context, 200),
        child: LineChart(
          LineChartData(
            clipData: const FlClipData.none(),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            minY: 0,
            maxY: maxY * 1.2,
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipColor: (_) =>
                    darkenColor(appColor, 0.1).withAlpha(220),
                getTooltipItems: (touched) => touched.map((s) {
                  final p = points[s.spotIndex];
                  return LineTooltipItem(
                    '${formatDateShort(p.date)}\n',
                    GoogleFonts.manrope(
                      fontSize: Responsive.font(context, 11),
                      color: dim,
                      fontWeight: FontWeight.w500,
                    ),
                    children: [
                      TextSpan(
                        text: '${_fmtCal(p.cal)} kcal',
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 13),
                          color: accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: Responsive.width(context, 44),
                  getTitlesWidget: (val, info) {
                    // fl_chart renders labels at min/max by default; hide them to avoid clipping
                    if (val == info.min || val == info.max) {
                      return const SizedBox.shrink();
                    }
                    return SideTitleWidget(
                      meta: info,
                      child: Text(
                        _fmtCal(val),
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 9),
                          color: dim,
                        ),
                      ),
                    );
                  },
                ),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  // hide x-axis labels for wide ranges to avoid crowding
                  showTitles: points.length <= 10,
                  reservedSize: Responsive.height(context, 28),
                  // skip every other label for ranges of 6+ days
                  interval: points.length <= 5 ? 1 : 2,
                  getTitlesWidget: (val, info) {
                    final i = val.toInt();
                    if (i < 0 || i >= points.length) {
                      return const SizedBox.shrink();
                    }
                    final d = points[i].date;
                    return SideTitleWidget(
                      meta: info,
                      fitInside: SideTitleFitInsideData.fromTitleMeta(info),
                      child: Text(
                        '${d.month}/${d.day}',
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 9),
                          color: dim,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.35,
                color: accent,
                barWidth: 2.5,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
                    radius: Responsive.scale(context, 3.5),
                    color: accent,
                    strokeWidth: 1.5,
                    // slightly darkened stroke separates overlapping dots visually
                    strokeColor: darkenColor(appColor, 0.05).withAlpha(180),
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [accent.withAlpha(50), accent.withAlpha(0)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mealLineChart(BuildContext context, List<_DayPoint> points) {
    if (points.isEmpty) {
      return frostedGlassCard(
        context,
        color: appColor,
        padding: EdgeInsets.all(Responsive.scale(context, 20)),
        child: _emptyState(context, "No meal data in this range"),
      );
    }
    return _MealLineChart(points: points);
  }

  Widget _macroLineChart(BuildContext context, List<_DayPoint> points) {
    if (points.isEmpty) {
      return frostedGlassCard(
        context,
        color: appColor,
        padding: EdgeInsets.all(Responsive.scale(context, 20)),
        child: _emptyState(context, "No macro data in this range"),
      );
    }
    return _MacroLineChart(points: points);
  }

  // Bar chart showing calorie breakdown by meal
  Widget _mealBarChart(
    BuildContext context, {
    required double breakfastCal,
    required double lunchCal,
    required double dinnerCal,
    required double snacksCal,
  }) {
    final labels = ["Breakfast", "Lunch", "Dinner", "Snacks"];
    final values = [breakfastCal, lunchCal, dinnerCal, snacksCal];
    final total = values.fold(0.0, (a, b) => a + b);
    final maxVal = values.fold(0.0, (a, b) => a > b ? a : b);
    // a tiny floor value keeps empty bars visible so the chart always shows all four meals
    final minBarVal = (maxVal * 0.03).clamp(1.0, double.infinity);

    final groups = <BarChartGroupData>[];
    for (int i = 0; i < values.length; i++) {
      final empty = values[i] == 0;
      final barVal = empty ? minBarVal : values[i];
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: barVal,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: empty
                    ? [
                        lightenColor(appColor, 0.2).withAlpha(50),
                        lightenColor(appColor, 0.1).withAlpha(50),
                      ]
                    : [
                        lightenColor(appColor, 0.45),
                        lightenColor(appColor, 0.2),
                      ],
              ),
              width: Responsive.scale(context, 18),
              borderRadius: BorderRadius.circular(4),
              backDrawRodData: BackgroundBarChartRodData(show: false),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: Responsive.isDesktop(context)
          ? 420
          : Responsive.height(context, 220),
      child: BarChart(
        BarChartData(
          maxY: maxVal == 0 ? 1 : maxVal * 1.15,
          barGroups: groups,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: Responsive.height(context, 48),
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= values.length) {
                    return const SizedBox.shrink();
                  }
                  final v = values[i];
                  final pct = total > 0 ? (v / total * 100).round() : 0;
                  final empty = v == 0;
                  final labelColor = empty
                      ? lightenColor(appColor, 0.25)
                      : lightenColor(appColor, 0.45);
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: Responsive.height(context, 4),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          empty ? '' : '$pct%',
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 12),
                            fontWeight: FontWeight.w700,
                            color: labelColor,
                          ),
                        ),
                        Text(
                          empty ? '0 kcal' : '${v.round()} kcal',
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 12),
                            fontWeight: empty
                                ? FontWeight.w400
                                : FontWeight.w700,
                            color: labelColor,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: Responsive.height(context, 32),
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= labels.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: EdgeInsets.only(
                      top: Responsive.height(context, 6),
                    ),
                    child: Text(
                      labels[i],
                      style: GoogleFonts.manrope(
                        fontSize: Responsive.font(context, 12),
                        fontWeight: FontWeight.w600,
                        color: Colors.white54,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Bar chart showing macro breakdown (protein, carbs, fat) in grams
  Widget _macroBarChart(
    BuildContext context, {
    required double proteinG,
    required double carbsG,
    required double fatG,
  }) {
    final labels = ["Protein", "Carbs", "Fat"];
    final values = [proteinG, carbsG, fatG];
    final totalG = values.fold(0.0, (a, b) => a + b);
    final maxVal = values.fold(0.0, (a, b) => a > b ? a : b);

    final groups = <BarChartGroupData>[];
    for (int i = 0; i < values.length; i++) {
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: values[i],
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  lightenColor(appColor, 0.45),
                  lightenColor(appColor, 0.2),
                ],
              ),
              width: Responsive.scale(context, 18),
              borderRadius: BorderRadius.circular(4),
              backDrawRodData: BackgroundBarChartRodData(show: false),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: Responsive.isDesktop(context)
          ? 420
          : Responsive.height(context, 220),
      child: BarChart(
        BarChartData(
          maxY: maxVal == 0 ? 1 : maxVal * 1.15,
          barGroups: groups,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: Responsive.height(context, 48),
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= values.length) {
                    return const SizedBox.shrink();
                  }
                  final v = values[i];
                  final pct = totalG > 0 ? (v / totalG * 100).round() : 0;
                  if (v == 0) return const SizedBox.shrink();
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: Responsive.height(context, 4),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "$pct%",
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 10),
                            fontWeight: FontWeight.w700,
                            color: lightenColor(appColor, 0.45),
                          ),
                        ),
                        Text(
                          "${v.round()}g",
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 10),
                            fontWeight: FontWeight.w700,
                            color: lightenColor(appColor, 0.45),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: Responsive.height(context, 32),
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= labels.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: EdgeInsets.only(
                      top: Responsive.height(context, 6),
                    ),
                    child: Text(
                      labels[i],
                      style: GoogleFonts.manrope(
                        fontSize: Responsive.font(context, 12),
                        fontWeight: FontWeight.w600,
                        color: Colors.white54,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
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

  @override
  Widget build(BuildContext context) {
    // Calorie totals per meal, used for the calorie breakdown chart
    final breakfastCal = _mealCalories(breakfastFoods);
    final lunchCal = _mealCalories(lunchFoods);
    final dinnerCal = _mealCalories(dinnerFoods);
    final snacksCal = _mealCalories(snacksFoods);
    final totalCal = breakfastCal + lunchCal + dinnerCal + snacksCal;

    final macros = _totalMacros();
    // Per-meal macro breakdowns shown in the daily summary card under each meal's calorie line
    final breakfastMacros = _mealMacros(breakfastFoods);
    final lunchMacros = _mealMacros(lunchFoods);
    final dinnerMacros = _mealMacros(dinnerFoods);
    final snacksMacros = _mealMacros(snacksFoods);
    // Protein and carbs are 4 kcal/g, fat is 9 kcal/g
    // These convert grams to calories so the macro bar reflects its actual contribution
    final proteinCal = macros['protein']! * 4;
    final carbsCal = macros['carbs']! * 4;
    final fatCal = macros['fat']! * 9;
    // totalMacroCal guards the macro chart separately from totalCal because
    // calories can be logged without a parseable food_description (no macros)
    final totalMacroCal = proteinCal + carbsCal + fatCal;

    return Container(
      decoration: BoxDecoration(gradient: buildThemeGradient(appColor)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // Back button row sitting directly on the gradient
              Padding(
                padding: EdgeInsets.only(
                  left: Responsive.width(context, 16),
                  top: Responsive.height(context, 8),
                  bottom: Responsive.height(context, 12),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      padding: EdgeInsets.all(Responsive.scale(context, 12)),
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
                ),
              ),
              // Pill-style tab bar sitting on the gradient
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.centeredHorizontalPadding(context, 12),
                  vertical: Responsive.height(context, 8),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: false,
                  tabAlignment: TabAlignment.fill,
                  labelPadding: EdgeInsets.symmetric(
                    horizontal: Responsive.width(context, 16),
                  ),
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: Colors.white.withAlpha(
                      45,
                    ), // frosted pill for selected tab
                    borderRadius: BorderRadius.circular(
                      Responsive.scale(context, 20),
                    ),
                    border: Border.all(
                      color: Colors.white.withAlpha(60),
                      width: Responsive.width(context, 1),
                    ),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  overlayColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.hovered) ||
                        states.contains(WidgetState.pressed)) {
                      return Colors.white.withAlpha(15);
                    }
                    return Colors.transparent;
                  }),
                  splashBorderRadius: BorderRadius.circular(
                    Responsive.scale(context, 20),
                  ), // clips ripple to pill shape
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white38,
                  labelStyle: GoogleFonts.manrope(
                    fontSize: Responsive.font(context, 15),
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelStyle: GoogleFonts.manrope(
                    fontSize: Responsive.font(context, 15),
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: const [
                    Tab(text: "Daily"),
                    Tab(text: "Range"),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Daily tab
                    _DailyTab(
                      context: context,
                      appColor: appColor,
                      totalCal: totalCal,
                      breakfastCal: breakfastCal,
                      lunchCal: lunchCal,
                      dinnerCal: dinnerCal,
                      snacksCal: snacksCal,
                      macros: macros,
                      breakfastMacros: breakfastMacros,
                      lunchMacros: lunchMacros,
                      dinnerMacros: dinnerMacros,
                      snacksMacros: snacksMacros,
                      totalMacroCal: totalMacroCal,
                      currentDate: currentDate,
                      onDateChanged: _changeDate,
                      animationKey: _animationKey,
                      mealBarChart: _mealBarChart,
                      macroBarChart: _macroBarChart,
                      emptyState: _emptyState,
                    ),
                    // Range tab
                    _buildRangeTab(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mostLoggedFoodsCard(
    BuildContext context,
    DateTime start,
    DateTime end,
  ) {
    final accent = lightenColor(appColor, 0.45);
    final dim = lightenColor(appColor, 0.35);
    final startKey = FoodLoggingHelper.formatDateKey(start);
    final endKey = FoodLoggingHelper.formatDateKey(end);
    final logs = (ref.read(foodLogsProvider).value ?? [])
        .map((f) => f.toJson())
        .toList();

    final counts = <String, int>{};
    final displayNames = <String, String>{};
    for (final f in logs) {
      final d = f['date'] as String? ?? '';
      if (d.compareTo(startKey) < 0 || d.compareTo(endKey) > 0) continue;
      final name = (f['food_name'] as String? ?? '').trim();
      if (name.isEmpty) continue;
      final key = name.toLowerCase();
      counts[key] = (counts[key] ?? 0) + 1;
      displayNames.putIfAbsent(key, () => name);
    }

    if (counts.isEmpty) {
      return frostedGlassCard(
        context,
        color: appColor,
        padding: EdgeInsets.all(Responsive.scale(context, 20)),
        child: _emptyState(context, "No foods logged in this range"),
      );
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(5).toList();
    final maxCount = top.first.value;

    return frostedGlassCard(
      context,
      color: appColor,
      padding: EdgeInsets.all(Responsive.scale(context, 16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < top.length; i++) ...[
            if (i > 0) SizedBox(height: Responsive.height(context, 10)),
            Row(
              children: [
                SizedBox(
                  width: Responsive.width(context, 20),
                  child: Text(
                    '${i + 1}',
                    style: GoogleFonts.manrope(
                      fontSize: Responsive.font(context, 12),
                      color: dim,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              displayNames[top[i].key] ?? top[i].key,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.manrope(
                                fontSize: Responsive.font(context, 13),
                                color: accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '${top[i].value}x',
                            style: GoogleFonts.manrope(
                              fontSize: Responsive.font(context, 12),
                              color: dim,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: Responsive.height(context, 4)),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: top[i].value / maxCount,
                          minHeight: Responsive.height(context, 4),
                          backgroundColor: accent.withAlpha(30),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            accent.withAlpha(180),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRangeTab(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.centeredHorizontalPadding(context, 20),
          vertical: Responsive.height(context, 24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RangePickerCard(
              rangeStart: _rangeStart,
              rangeEnd: _rangeEnd,
              rangeSelected: _rangeSelected,
              calendarFocused: _calendarFocused,
              rangeLabel: "nutrition trends",
              onRangeSelected: (start, end, focused) {
                setState(() {
                  _calendarFocused = focused;
                  if (start != null) _rangeStart = start;
                  if (end != null) {
                    // both dates picked, show the charts
                    _rangeEnd = end;
                    _rangeSelected = true;
                    _rangeAnimationKey++; // increment to re-trigger the animation
                  } else {
                    // end is null on the first tap, user picked a start but not an end yet
                    _rangeSelected = false;
                  }
                });
              },
              onPageChanged: (focused) {
                setState(() => _calendarFocused = focused);
              },
              onClearRange: () {
                setState(() {
                  _rangeStart = null;
                  _rangeEnd = null;
                  _rangeSelected = false;
                });
              },
            ),

            if (_rangeSelected) ...[
              SizedBox(height: Responsive.height(context, 24)),
              // Builder gives a fresh context inside the if block to call _aggregateRange
              // only when a range is actually selected, not on every build
              Builder(
                builder: (context) {
                  final agg = _aggregateRange(_rangeStart!, _rangeEnd!);

                  if (agg.daysWithData == 0) {
                    return Center(
                      child: Text(
                        "No data logged in this range",
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 14),
                          color: Colors.white38,
                        ),
                      ),
                    );
                  }

                  final points = _dailyPoints(_rangeStart!, _rangeEnd!);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // CALORIE GRAPH
                      sectionHeader("CALORIE GRAPH", context)
                          .animate(
                            key: ValueKey((
                              'range_cal_graph_title',
                              _rangeAnimationKey,
                            )),
                          )
                          .fadeIn(duration: 300.ms)
                          .slideY(
                            begin: 0.08,
                            duration: 300.ms,
                            curve: Curves.easeOut,
                          ),
                      _calorieLineChart(context, points)
                          .animate(
                            key: ValueKey((
                              'range_cal_graph',
                              _rangeAnimationKey,
                            )),
                          )
                          .fadeIn(delay: 50.ms, duration: 300.ms)
                          .slideY(
                            begin: 0.08,
                            delay: 50.ms,
                            duration: 300.ms,
                            curve: Curves.easeOut,
                          ),

                      SizedBox(height: Responsive.height(context, 24)),

                      // MEAL BREAKDOWN GRAPH
                      sectionHeader("MEAL BREAKDOWN GRAPH", context)
                          .animate(
                            key: ValueKey((
                              'range_meal_graph_title',
                              _rangeAnimationKey,
                            )),
                          )
                          .fadeIn(delay: 75.ms, duration: 300.ms)
                          .slideY(
                            begin: 0.08,
                            delay: 75.ms,
                            duration: 300.ms,
                            curve: Curves.easeOut,
                          ),
                      _mealLineChart(context, points)
                          .animate(
                            key: ValueKey((
                              'range_meal_graph',
                              _rangeAnimationKey,
                            )),
                          )
                          .fadeIn(delay: 100.ms, duration: 300.ms)
                          .slideY(
                            begin: 0.08,
                            delay: 100.ms,
                            duration: 300.ms,
                            curve: Curves.easeOut,
                          ),

                      SizedBox(height: Responsive.height(context, 24)),

                      // MACRO GRAPH
                      sectionHeader("MACRO GRAPH", context)
                          .animate(
                            key: ValueKey((
                              'range_mac_graph_title',
                              _rangeAnimationKey,
                            )),
                          )
                          .fadeIn(delay: 150.ms, duration: 300.ms)
                          .slideY(
                            begin: 0.08,
                            delay: 150.ms,
                            duration: 300.ms,
                            curve: Curves.easeOut,
                          ),
                      _macroLineChart(context, points)
                          .animate(
                            key: ValueKey((
                              'range_mac_graph',
                              _rangeAnimationKey,
                            )),
                          )
                          .fadeIn(delay: 200.ms, duration: 300.ms)
                          .slideY(
                            begin: 0.08,
                            delay: 200.ms,
                            duration: 300.ms,
                            curve: Curves.easeOut,
                          ),

                      SizedBox(height: Responsive.height(context, 24)),

                      // CALORIE SUMMARY
                      sectionHeader("CALORIE SUMMARY", context)
                          .animate(
                            key: ValueKey((
                              'range_cal_sum_title',
                              _rangeAnimationKey,
                            )),
                          )
                          .fadeIn(delay: 250.ms, duration: 300.ms)
                          .slideY(
                            begin: 0.08,
                            delay: 250.ms,
                            duration: 300.ms,
                            curve: Curves.easeOut,
                          ),
                      _calorieSummaryCard(context, agg, appColor)
                          .animate(
                            key: ValueKey((
                              'range_cal_sum',
                              _rangeAnimationKey,
                            )),
                          )
                          .fadeIn(delay: 300.ms, duration: 300.ms)
                          .slideY(
                            begin: 0.08,
                            delay: 300.ms,
                            duration: 300.ms,
                            curve: Curves.easeOut,
                          ),

                      SizedBox(height: Responsive.height(context, 24)),

                      // MACRO SUMMARY
                      sectionHeader("MACRO SUMMARY", context)
                          .animate(
                            key: ValueKey((
                              'range_mac_sum_title',
                              _rangeAnimationKey,
                            )),
                          )
                          .fadeIn(delay: 350.ms, duration: 300.ms)
                          .slideY(
                            begin: 0.08,
                            delay: 350.ms,
                            duration: 300.ms,
                            curve: Curves.easeOut,
                          ),
                      _macroSummaryCard(context, agg, appColor)
                          .animate(
                            key: ValueKey((
                              'range_mac_sum',
                              _rangeAnimationKey,
                            )),
                          )
                          .fadeIn(delay: 400.ms, duration: 300.ms)
                          .slideY(
                            begin: 0.08,
                            delay: 400.ms,
                            duration: 300.ms,
                            curve: Curves.easeOut,
                          ),

                      SizedBox(height: Responsive.height(context, 24)),

                      // MOST LOGGED FOODS
                      sectionHeader("MOST LOGGED FOODS", context)
                          .animate(
                            key: ValueKey((
                              'range_top_foods_title',
                              _rangeAnimationKey,
                            )),
                          )
                          .fadeIn(delay: 450.ms, duration: 300.ms)
                          .slideY(
                            begin: 0.08,
                            delay: 450.ms,
                            duration: 300.ms,
                            curve: Curves.easeOut,
                          ),
                      _mostLoggedFoodsCard(context, _rangeStart!, _rangeEnd!)
                          .animate(
                            key: ValueKey((
                              'range_top_foods',
                              _rangeAnimationKey,
                            )),
                          )
                          .fadeIn(delay: 500.ms, duration: 300.ms)
                          .slideY(
                            begin: 0.08,
                            delay: 500.ms,
                            duration: 300.ms,
                            curve: Curves.easeOut,
                          ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MealLineChart extends ConsumerStatefulWidget {
  final List<_DayPoint> points;
  const _MealLineChart({required this.points});

  @override
  ConsumerState<_MealLineChart> createState() => _MealLineChartState();
}

class _MealLineChartState extends ConsumerState<_MealLineChart> {
  Color get appColor => ref.watch(
    userDataProvider.select((s) => s.value?.appColor ?? defaultAppColor),
  );

  // null = all meals shown
  int? _focus;

  static const _names = ['Breakfast', 'Lunch', 'Dinner', 'Snacks'];

  @override
  Widget build(BuildContext context) {
    final accent = lightenColor(appColor, 0.45);
    final dim = lightenColor(appColor, 0.35);
    final points = widget.points;

    final allSpots = [
      [
        for (int i = 0; i < points.length; i++)
          FlSpot(i.toDouble(), points[i].breakfastCal),
      ],
      [
        for (int i = 0; i < points.length; i++)
          FlSpot(i.toDouble(), points[i].lunchCal),
      ],
      [
        for (int i = 0; i < points.length; i++)
          FlSpot(i.toDouble(), points[i].dinnerCal),
      ],
      [
        for (int i = 0; i < points.length; i++)
          FlSpot(i.toDouble(), points[i].snacksCal),
      ],
    ];
    final colors = [
      accent,
      accent.withAlpha(200),
      accent.withAlpha(130),
      accent.withAlpha(70),
    ];

    final visibleSpots = _focus != null ? [allSpots[_focus!]] : allSpots;
    final visibleColors = _focus != null ? [colors[_focus!]] : colors;
    final allY = visibleSpots.expand((s) => s).map((s) => s.y).toList();
    final maxY = allY.isEmpty ? 1.0 : allY.reduce((a, b) => a > b ? a : b);

    LineChartBarData line(List<FlSpot> spots, Color color) => LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.35,
      color: color,
      barWidth: 2,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
          radius: Responsive.scale(context, 3),
          color: color,
          strokeWidth: 1,
          strokeColor: darkenColor(appColor, 0.05).withAlpha(180),
        ),
      ),
    );

    Widget focusChip(String label, int? index) {
      final selected = _focus == index;
      final chipColor = index != null ? colors[index] : accent;
      return GestureDetector(
        onTap: () => setState(() => _focus = selected ? null : index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.width(context, 10),
            vertical: Responsive.height(context, 5),
          ),
          decoration: BoxDecoration(
            color: selected ? chipColor.withAlpha(50) : chipColor.withAlpha(15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? chipColor.withAlpha(140)
                  : chipColor.withAlpha(30),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: Responsive.font(context, 11),
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? chipColor : dim,
            ),
          ),
        ),
      );
    }

    return frostedGlassCard(
      context,
      color: appColor,
      padding: EdgeInsets.all(Responsive.scale(context, 16)),
      child: Column(
        children: [
          SizedBox(
            height: Responsive.height(context, 200),
            child: LineChart(
              LineChartData(
                clipData: const FlClipData.none(),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                minY: 0,
                maxY: maxY * 1.2,
                lineTouchData: LineTouchData(
                  touchSpotThreshold: 20,
                  touchTooltipData: LineTouchTooltipData(
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipColor: (_) =>
                        darkenColor(appColor, 0.1).withAlpha(220),
                    getTooltipItems: (touched) {
                      // sort by barIndex so the date header always appears on the first line
                      final sorted = [...touched]
                        ..sort((a, b) => a.barIndex.compareTo(b.barIndex));
                      return sorted.asMap().entries.map((entry) {
                        final s = entry.value;
                        final p = points[s.spotIndex];
                        final isFirst = entry.key == 0;
                        // when a meal is focused, barIndex is always 0 so fall back to _focus for the name
                        final idx = _focus ?? s.barIndex;
                        return LineTooltipItem(
                          isFirst ? '${formatDateShort(p.date)}\n' : '',
                          GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 11),
                            color: dim,
                            fontWeight: FontWeight.w500,
                          ),
                          children: [
                            TextSpan(
                              text: '${_names[idx]}: ${_fmtCal(s.y)} kcal',
                              style: GoogleFonts.manrope(
                                fontSize: Responsive.font(context, 13),
                                color: accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        );
                      }).toList();
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: Responsive.width(context, 44),
                      getTitlesWidget: (val, info) {
                        if (val == info.min || val == info.max) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          meta: info,
                          child: Text(
                            _fmtCal(val),
                            style: GoogleFonts.manrope(
                              fontSize: Responsive.font(context, 9),
                              color: dim,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: points.length <= 10,
                      reservedSize: Responsive.height(context, 28),
                      interval: points.length <= 5 ? 1 : 2,
                      getTitlesWidget: (val, info) {
                        final i = val.toInt();
                        if (i < 0 || i >= points.length) {
                          return const SizedBox.shrink();
                        }
                        final d = points[i].date;
                        return SideTitleWidget(
                          meta: info,
                          fitInside: SideTitleFitInsideData.fromTitleMeta(info),
                          child: Text(
                            '${d.month}/${d.day}',
                            style: GoogleFonts.manrope(
                              fontSize: Responsive.font(context, 9),
                              color: dim,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  for (int i = 0; i < visibleSpots.length; i++)
                    line(visibleSpots[i], visibleColors[i]),
                ],
              ),
            ),
          ),
          SizedBox(height: Responsive.height(context, 12)),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: Responsive.width(context, 8),
            runSpacing: Responsive.height(context, 6),
            children: [
              focusChip('All', null),
              for (int i = 0; i < _names.length; i++) focusChip(_names[i], i),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroLineChart extends ConsumerStatefulWidget {
  final List<_DayPoint> points;
  const _MacroLineChart({required this.points});

  @override
  ConsumerState<_MacroLineChart> createState() => _MacroLineChartState();
}

class _MacroLineChartState extends ConsumerState<_MacroLineChart> {
  Color get appColor => ref.watch(
    userDataProvider.select((s) => s.value?.appColor ?? defaultAppColor),
  );

  // null = all macros shown
  int? _focus;

  static const _names = ['Protein', 'Carbs', 'Fat'];

  @override
  Widget build(BuildContext context) {
    final accent = lightenColor(appColor, 0.45);
    final dim = lightenColor(appColor, 0.35);
    final points = widget.points;

    final allSpots = [
      [
        for (int i = 0; i < points.length; i++)
          FlSpot(i.toDouble(), points[i].protein),
      ],
      [
        for (int i = 0; i < points.length; i++)
          FlSpot(i.toDouble(), points[i].carbs),
      ],
      [
        for (int i = 0; i < points.length; i++)
          FlSpot(i.toDouble(), points[i].fat),
      ],
    ];
    final colors = [accent, accent.withAlpha(160), accent.withAlpha(90)];

    final visibleSpots = _focus != null ? [allSpots[_focus!]] : allSpots;
    final visibleColors = _focus != null ? [colors[_focus!]] : colors;
    final allY = visibleSpots.expand((s) => s).map((s) => s.y).toList();
    final maxY = allY.isEmpty ? 1.0 : allY.reduce((a, b) => a > b ? a : b);

    LineChartBarData line(List<FlSpot> spots, Color color) => LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.35,
      color: color,
      barWidth: 2,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
          radius: Responsive.scale(context, 3),
          color: color,
          strokeWidth: 1,
          strokeColor: darkenColor(appColor, 0.05).withAlpha(180),
        ),
      ),
    );

    Widget focusChip(String label, int? index) {
      final selected = _focus == index;
      final chipColor = index != null ? colors[index] : accent;
      return GestureDetector(
        onTap: () => setState(() => _focus = selected ? null : index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.width(context, 10),
            vertical: Responsive.height(context, 5),
          ),
          decoration: BoxDecoration(
            color: selected ? chipColor.withAlpha(50) : chipColor.withAlpha(15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? chipColor.withAlpha(140)
                  : chipColor.withAlpha(30),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: Responsive.font(context, 11),
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? chipColor : dim,
            ),
          ),
        ),
      );
    }

    return frostedGlassCard(
      context,
      color: appColor,
      padding: EdgeInsets.all(Responsive.scale(context, 16)),
      child: Column(
        children: [
          SizedBox(
            height: Responsive.isDesktop(context)
                ? 320
                : Responsive.height(context, 200),
            child: LineChart(
              LineChartData(
                clipData: const FlClipData.none(),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                minY: 0,
                maxY: maxY * 1.2,
                lineTouchData: LineTouchData(
                  touchSpotThreshold: 20,
                  touchTooltipData: LineTouchTooltipData(
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipColor: (_) =>
                        darkenColor(appColor, 0.1).withAlpha(220),
                    getTooltipItems: (touched) {
                      // sort by barIndex so the date header always appears on the first line
                      final sorted = [...touched]
                        ..sort((a, b) => a.barIndex.compareTo(b.barIndex));
                      return sorted.asMap().entries.map((entry) {
                        final s = entry.value;
                        final isFirst = entry.key == 0;
                        final p = points[s.spotIndex];
                        // when a macro is focused, barIndex is always 0 so fall back to _focus for the name
                        final idx = _focus ?? s.barIndex;
                        return LineTooltipItem(
                          isFirst ? '${formatDateShort(p.date)}\n' : '',
                          GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 11),
                            color: dim,
                            fontWeight: FontWeight.w500,
                          ),
                          children: [
                            TextSpan(
                              text: '${_names[idx]}: ${s.y.round()}g',
                              style: GoogleFonts.manrope(
                                fontSize: Responsive.font(context, 13),
                                color: accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        );
                      }).toList();
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: Responsive.width(context, 36),
                      getTitlesWidget: (val, info) {
                        if (val == info.min || val == info.max) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          meta: info,
                          child: Text(
                            '${val.round()}g',
                            style: GoogleFonts.manrope(
                              fontSize: Responsive.font(context, 9),
                              color: dim,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: points.length <= 10,
                      reservedSize: Responsive.height(context, 28),
                      interval: points.length <= 5 ? 1 : 2,
                      getTitlesWidget: (val, info) {
                        final i = val.toInt();
                        if (i < 0 || i >= points.length) {
                          return const SizedBox.shrink();
                        }
                        final d = points[i].date;
                        return SideTitleWidget(
                          meta: info,
                          fitInside: SideTitleFitInsideData.fromTitleMeta(info),
                          child: Text(
                            '${d.month}/${d.day}',
                            style: GoogleFonts.manrope(
                              fontSize: Responsive.font(context, 9),
                              color: dim,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  for (int i = 0; i < visibleSpots.length; i++)
                    line(visibleSpots[i], visibleColors[i]),
                ],
              ),
            ),
          ),
          SizedBox(height: Responsive.height(context, 12)),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: Responsive.width(context, 8),
            runSpacing: Responsive.height(context, 6),
            children: [
              focusChip('All', null),
              for (int i = 0; i < _names.length; i++) focusChip(_names[i], i),
            ],
          ),
        ],
      ),
    );
  }
}

// Extracted daily tab body so the main build method stays readable
// chart builders are passed as callbacks so _DailyTab stays stateless
// while the parent retains chart logic tied to its state
class _DailyTab extends StatelessWidget {
  final BuildContext context;
  final Color appColor;
  final double totalCal;
  final double breakfastCal;
  final double lunchCal;
  final double dinnerCal;
  final double snacksCal;
  final Map<String, double> macros;
  final Map<String, double> breakfastMacros;
  final Map<String, double> lunchMacros;
  final Map<String, double> dinnerMacros;
  final Map<String, double> snacksMacros;
  final double totalMacroCal;
  final DateTime currentDate;
  final void Function(DateTime) onDateChanged;
  final int animationKey;
  final Widget Function(
    BuildContext, {
    required double breakfastCal,
    required double lunchCal,
    required double dinnerCal,
    required double snacksCal,
  })
  mealBarChart;
  final Widget Function(
    BuildContext, {
    required double proteinG,
    required double carbsG,
    required double fatG,
  })
  macroBarChart;
  final Widget Function(BuildContext, String) emptyState;

  const _DailyTab({
    required this.context,
    required this.appColor,
    required this.totalCal,
    required this.breakfastCal,
    required this.lunchCal,
    required this.dinnerCal,
    required this.snacksCal,
    required this.macros,
    required this.breakfastMacros,
    required this.lunchMacros,
    required this.dinnerMacros,
    required this.snacksMacros,
    required this.totalMacroCal,
    required this.currentDate,
    required this.onDateChanged,
    required this.animationKey,
    required this.mealBarChart,
    required this.macroBarChart,
    required this.emptyState,
  });

  @override
  Widget build(BuildContext ctx) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.centeredHorizontalPadding(ctx, 20),
          vertical: Responsive.height(ctx, 24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Date navigation shared with Food Logging via DateNavigationRow in globals.dart
            DateNavigationRow(
              currentDate: currentDate,
              onDateChanged: onDateChanged,
            ),

            SizedBox(height: Responsive.height(ctx, 16)),

            sectionHeader(() {
              const months = [
                'January',
                'February',
                'March',
                'April',
                'May',
                'June',
                'July',
                'August',
                'September',
                'October',
                'November',
                'December',
              ];
              return 'SUMMARY · ${months[currentDate.month - 1].toUpperCase()} ${currentDate.day}, ${currentDate.year}';
            }(), ctx),

            _statTilesRow(
                  context: ctx,
                  appColor: appColor,
                  totalCal: totalCal,
                  macros: macros,
                  breakfastCal: breakfastCal,
                  lunchCal: lunchCal,
                  dinnerCal: dinnerCal,
                  snacksCal: snacksCal,
                  breakfastMacros: breakfastMacros,
                  lunchMacros: lunchMacros,
                  dinnerMacros: dinnerMacros,
                  snacksMacros: snacksMacros,
                )
                .animate(key: ValueKey(('stat_tiles', animationKey)))
                .fadeIn(duration: 300.ms)
                .slideY(begin: 0.08, duration: 300.ms, curve: Curves.easeOut),

            SizedBox(height: Responsive.height(ctx, 24)),

            // Calorie breakdown section
            sectionHeader("CALORIE BREAKDOWN", ctx)
                .animate(key: ValueKey(('calories_title', animationKey)))
                .fadeIn(duration: 300.ms)
                .slideY(begin: 0.08, duration: 300.ms, curve: Curves.easeOut),
            frostedGlassCard(
                  ctx,
                  color: appColor,
                  padding: EdgeInsets.all(Responsive.scale(ctx, 20)),
                  child: totalCal == 0
                      ? emptyState(ctx, "No calories logged for this day")
                      : mealBarChart(
                          ctx,
                          breakfastCal: breakfastCal,
                          lunchCal: lunchCal,
                          dinnerCal: dinnerCal,
                          snacksCal: snacksCal,
                        ),
                )
                .animate(key: ValueKey(('calories_chart', animationKey)))
                .fadeIn(delay: 50.ms, duration: 300.ms)
                .slideY(
                  begin: 0.08,
                  delay: 50.ms,
                  duration: 300.ms,
                  curve: Curves.easeOut,
                ),

            SizedBox(height: Responsive.height(ctx, 24)),

            // Macro breakdown: bars sized by gram weight
            sectionHeader("MACRO BREAKDOWN", ctx)
                .animate(key: ValueKey(('macros_title', animationKey)))
                .fadeIn(delay: 150.ms, duration: 300.ms)
                .slideY(
                  begin: 0.08,
                  delay: 150.ms,
                  duration: 300.ms,
                  curve: Curves.easeOut,
                ),
            frostedGlassCard(
                  ctx,
                  color: appColor,
                  padding: EdgeInsets.all(Responsive.scale(ctx, 20)),
                  child: totalMacroCal == 0
                      ? emptyState(ctx, "No macro data for this day")
                      : macroBarChart(
                          ctx,
                          proteinG: macros['protein']!,
                          carbsG: macros['carbs']!,
                          fatG: macros['fat']!,
                        ),
                )
                .animate(key: ValueKey(('macros_chart', animationKey)))
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
    );
  }
}

// Daily summary card: total calories + stacked meal bar + macro row
Widget _statTilesRow({
  required BuildContext context,
  required Color appColor,
  required double totalCal,
  required Map<String, double> macros,
  double breakfastCal = 0,
  double lunchCal = 0,
  double dinnerCal = 0,
  double snacksCal = 0,
  Map<String, double>? breakfastMacros,
  Map<String, double>? lunchMacros,
  Map<String, double>? dinnerMacros,
  Map<String, double>? snacksMacros,
}) {
  final accent = lightenColor(appColor, 0.45);
  final dim = lightenColor(appColor, 0.35);
  final meals = [
    ('Breakfast', breakfastCal),
    ('Lunch', lunchCal),
    ('Dinner', dinnerCal),
    ('Snacks', snacksCal),
  ];
  final mealMacros = [breakfastMacros, lunchMacros, dinnerMacros, snacksMacros];
  final protein = macros['protein'] ?? 0;
  final carbs = macros['carbs'] ?? 0;
  final fat = macros['fat'] ?? 0;

  return frostedGlassCard(
    context,
    color: appColor,
    padding: EdgeInsets.all(Responsive.scale(context, 20)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              totalCal == 0 ? '—' : _fmtCal(totalCal),
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 28),
                fontWeight: FontWeight.w800,
                color: accent,
                height: 1,
              ),
            ),
            SizedBox(width: Responsive.width(context, 6)),
            Text(
              'kcal',
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 18),
                fontWeight: FontWeight.w500,
                color: dim,
              ),
            ),
          ],
        ),
        if (totalCal > 0) ...[
          SizedBox(height: Responsive.height(context, 16)),
          Divider(color: accent.withAlpha(30), height: 1, thickness: 1),
          SizedBox(height: Responsive.height(context, 12)),
          for (int i = 0; i < meals.length; i++) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  meals[i].$1,
                  style: GoogleFonts.manrope(
                    fontSize: Responsive.font(context, 13),
                    fontWeight: FontWeight.w500,
                    color: dim,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      meals[i].$2 > 0
                          ? '${_fmtCal(meals[i].$2)} kcal'
                          : 'No data',
                      style: GoogleFonts.manrope(
                        fontSize: Responsive.font(context, 13),
                        fontWeight: FontWeight.w700,
                        color: meals[i].$2 > 0 ? accent : dim.withAlpha(100),
                      ),
                    ),
                    if (meals[i].$2 > 0 && mealMacros[i] != null) ...[
                      SizedBox(height: Responsive.height(context, 2)),
                      Text(
                        'P ${(mealMacros[i]!['protein'] ?? 0).round()}g · C ${(mealMacros[i]!['carbs'] ?? 0).round()}g · F ${(mealMacros[i]!['fat'] ?? 0).round()}g',
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 10),
                          color: dim,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            if (i < meals.length - 1)
              SizedBox(height: Responsive.height(context, 8)),
          ],
          SizedBox(height: Responsive.height(context, 16)),
          Divider(color: accent.withAlpha(30), height: 1, thickness: 1),
          SizedBox(height: Responsive.height(context, 12)),
          Row(
            children: [
              _macroInline(context, 'Protein', protein, accent, dim),
              SizedBox(width: Responsive.width(context, 20)),
              _macroInline(context, 'Carbs', carbs, accent, dim),
              SizedBox(width: Responsive.width(context, 20)),
              _macroInline(context, 'Fat', fat, accent, dim),
            ],
          ),
        ],
      ],
    ),
  );
}

Widget _macroInline(
  BuildContext context,
  String label,
  double grams,
  Color accent,
  Color dim,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: Responsive.font(context, 10),
          fontWeight: FontWeight.w500,
          color: dim,
        ),
      ),
      Text(
        grams == 0 ? '—' : '${grams.round()}g',
        style: GoogleFonts.manrope(
          fontSize: Responsive.font(context, 14),
          fontWeight: FontWeight.w700,
          color: accent,
        ),
      ),
    ],
  );
}

Widget _calorieSummaryCard(
  BuildContext context,
  _RangeAggregate agg,
  Color appColor,
) {
  final accent = lightenColor(appColor, 0.45);
  final dim = lightenColor(appColor, 0.35);
  final days = agg.daysWithData;
  final total = agg.totalCal;
  final meals = [
    ('Breakfast', agg.breakfastCal),
    ('Lunch', agg.lunchCal),
    ('Dinner', agg.dinnerCal),
    ('Snacks', agg.snacksCal),
  ];
  return frostedGlassCard(
    context,
    color: appColor,
    padding: EdgeInsets.all(Responsive.scale(context, 20)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              total == 0 ? '—' : _fmtCal(total),
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 28),
                fontWeight: FontWeight.w800,
                color: accent,
                height: 1,
              ),
            ),
            SizedBox(width: Responsive.width(context, 6)),
            Text(
              'kcal',
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 13),
                fontWeight: FontWeight.w500,
                color: dim,
              ),
            ),
          ],
        ),
        if (total > 0) ...[
          SizedBox(height: Responsive.height(context, 16)),
          Divider(color: accent.withAlpha(30), height: 1, thickness: 1),
          SizedBox(height: Responsive.height(context, 12)),
          for (int i = 0; i < meals.length; i++) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  meals[i].$1,
                  style: GoogleFonts.manrope(
                    fontSize: Responsive.font(context, 13),
                    fontWeight: FontWeight.w500,
                    color: dim,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      meals[i].$2 > 0
                          ? '${_fmtCal(meals[i].$2)} kcal'
                          : 'No data',
                      style: GoogleFonts.manrope(
                        fontSize: Responsive.font(context, 13),
                        fontWeight: FontWeight.w700,
                        color: meals[i].$2 > 0 ? accent : dim.withAlpha(100),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (i < meals.length - 1)
              SizedBox(height: Responsive.height(context, 8)),
          ],
          if (days > 0 && total > 0) ...[
            SizedBox(height: Responsive.height(context, 12)),
            Divider(color: accent.withAlpha(30), height: 1, thickness: 1),
            SizedBox(height: Responsive.height(context, 12)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Daily average',
                  style: GoogleFonts.manrope(
                    fontSize: Responsive.font(context, 13),
                    fontWeight: FontWeight.w500,
                    color: dim,
                  ),
                ),
                Text(
                  '${_fmtCal(total / days)} kcal',
                  style: GoogleFonts.manrope(
                    fontSize: Responsive.font(context, 13),
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ],
            ),
          ],
        ],
      ],
    ),
  );
}

String _fmtCal(double v) {
  final n = v.round();
  if (n >= 1000) {
    return '${n ~/ 1000},${(n % 1000).toString().padLeft(3, '0')}';
  }
  return '$n';
}

Widget _macroSummaryCard(
  BuildContext context,
  _RangeAggregate agg,
  Color appColor,
) {
  final accent = lightenColor(appColor, 0.45);
  final days = agg.daysWithData;

  Widget macroChip(String label, double total, IconData icon) {
    final avg = days > 0 ? (total / days).round() : 0;
    return Expanded(
      child: _rangeTile(
        context: context,
        appColor: appColor,
        icon: icon,
        iconColor: accent,
        label: label,
        total: total == 0 ? '—' : total.round().toString(),
        unit: total == 0 ? '' : 'g',
        avg: days > 0 && total > 0 ? '$avg g avg/day' : '',
      ),
    );
  }

  // IntrinsicHeight forces all three Expanded tiles to match the tallest one's height
  return IntrinsicHeight(
    child: Row(
      children: [
        macroChip('Protein', agg.protein, HugeIcons.strokeRoundedDumbbell01),
        SizedBox(width: Responsive.width(context, 10)),
        macroChip('Carbs', agg.carbs, HugeIcons.strokeRoundedBread01),
        SizedBox(width: Responsive.width(context, 10)),
        macroChip('Fat', agg.fat, HugeIcons.strokeRoundedDroplet),
      ],
    ),
  );
}

// same as _statTile but adds an avg line beneath the unit label
// avg is pre-formatted by the caller so this widget doesn't need to know about daysWithData
Widget _rangeTile({
  required BuildContext context,
  required Color appColor,
  required IconData icon,
  required Color iconColor,
  required String label,
  required String total,
  required String unit,
  String avg = '',
}) {
  return frostedGlassCard(
    context,
    color: appColor,
    padding: EdgeInsets.symmetric(
      horizontal: Responsive.width(context, 10),
      vertical: Responsive.height(context, 14),
    ),
    child: SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          HugeIcon(
            icon: icon,
            color: iconColor,
            size: Responsive.font(context, 20),
          ),
          SizedBox(height: Responsive.height(context, 6)),
          Text(
            total,
            style: GoogleFonts.manrope(
              fontSize: Responsive.font(context, 18),
              fontWeight: FontWeight.w800,
              color: iconColor,
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
                color: iconColor.withAlpha(140),
              ),
            ),
          ],
          if (avg.isNotEmpty) ...[
            SizedBox(height: Responsive.height(context, 4)),
            Text(
              avg,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 11),
                fontWeight: FontWeight.w500,
                color: iconColor.withAlpha(180),
              ),
            ),
          ],
          SizedBox(height: Responsive.height(context, 6)),
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

class _DayPoint {
  final DateTime date;
  final double cal;
  final double breakfastCal;
  final double lunchCal;
  final double dinnerCal;
  final double snacksCal;
  final double protein;
  final double carbs;
  final double fat;
  const _DayPoint({
    required this.date,
    required this.cal,
    required this.breakfastCal,
    required this.lunchCal,
    required this.dinnerCal,
    required this.snacksCal,
    required this.protein,
    required this.carbs,
    required this.fat,
  });
}

// Holds all aggregated totals for a date range plus the count of days that had data
class _RangeAggregate {
  final double totalCal;
  final double breakfastCal;
  final double lunchCal;
  final double dinnerCal;
  final double snacksCal;
  final double protein;
  final double carbs;
  final double fat;
  final int daysWithData;
  final double breakfastProtein;
  final double breakfastCarbs;
  final double breakfastFat;
  final double lunchProtein;
  final double lunchCarbs;
  final double lunchFat;
  final double dinnerProtein;
  final double dinnerCarbs;
  final double dinnerFat;
  final double snacksProtein;
  final double snacksCarbs;
  final double snacksFat;

  const _RangeAggregate({
    required this.totalCal,
    required this.breakfastCal,
    required this.lunchCal,
    required this.dinnerCal,
    required this.snacksCal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.daysWithData,
    required this.breakfastProtein,
    required this.breakfastCarbs,
    required this.breakfastFat,
    required this.lunchProtein,
    required this.lunchCarbs,
    required this.lunchFat,
    required this.dinnerProtein,
    required this.dinnerCarbs,
    required this.dinnerFat,
    required this.snacksProtein,
    required this.snacksCarbs,
    required this.snacksFat,
  });
}
