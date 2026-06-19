import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:table_calendar/table_calendar.dart';
import '../globals.dart';
import '../utility/responsive.dart';
import '../utility/food_logging_helper.dart';

// initialDate opens the screen on the same date the user was viewing in Food Logging
// onDateChanged is optional so Food Logging can stay in sync when dates are changed here
class FoodAnalyticsScreen extends StatefulWidget {
  final DateTime initialDate;
  final void Function(DateTime)? onDateChanged;

  const FoodAnalyticsScreen({
    super.key,
    required this.initialDate,
    this.onDateChanged,
  });

  @override
  State<FoodAnalyticsScreen> createState() => _FoodAnalyticsScreenState();
}

class _FoodAnalyticsScreenState extends State<FoodAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late DateTime currentDate;

  // Daily tab state
  List<Map<String, dynamic>> breakfastFoods = [];
  List<Map<String, dynamic>> lunchFoods = [];
  List<Map<String, dynamic>> dinnerFoods = [];
  List<Map<String, dynamic>> snacksFoods = [];

  // incrementing this re-triggers all .animate(key: ValueKey(...)) animations on date change
  int _animationKey = 0;

  // Range tab state
  // null until the user picks dates so the calendar shows no highlight initially
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  bool _rangeSelected = false;
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

  // Goes through all days and sums the calories and macros
  // daysWithData is returned to compute averages without using empty days
  _RangeAggregate _aggregateRange(DateTime start, DateTime end) {
    final foodDataByDate = currentUserData?.foodDataByDate ?? {};
    double totalCal = 0;
    double protein = 0, carbs = 0, fat = 0;
    double breakfastCal = 0, lunchCal = 0, dinnerCal = 0, snacksCal = 0;
    int daysWithData = 0;

    DateTime day = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);

    while (!day.isAfter(endDay)) {
      final dayData = foodDataByDate[FoodLoggingHelper.formatDateKey(day)];
      if (dayData != null) {
        final breakfast = FoodLoggingHelper.castFoodList(dayData['breakfast']);
        final lunch = FoodLoggingHelper.castFoodList(dayData['lunch']);
        final dinner = FoodLoggingHelper.castFoodList(dayData['dinner']);
        final snacks = FoodLoggingHelper.castFoodList(dayData['snacks']);

        final allFoods = [...breakfast, ...lunch, ...dinner, ...snacks];
        if (allFoods.isEmpty) {
          day = day.add(const Duration(days: 1));
          continue;
        }

        daysWithData++;

        double dayCal = 0;
        for (var food in allFoods) {
          dayCal += (num.tryParse(food['calories'].toString()) ?? 0).toDouble();
        }
        // accumulate per-meal totals separately so the calorie bar chart can show the breakdown by meal
        for (var food in breakfast) {
          breakfastCal += (num.tryParse(food['calories'].toString()) ?? 0)
              .toDouble();
        }
        for (var food in lunch) {
          lunchCal += (num.tryParse(food['calories'].toString()) ?? 0)
              .toDouble();
        }
        for (var food in dinner) {
          dinnerCal += (num.tryParse(food['calories'].toString()) ?? 0)
              .toDouble();
        }
        for (var food in snacks) {
          snacksCal += (num.tryParse(food['calories'].toString()) ?? 0)
              .toDouble();
        }
        totalCal += dayCal;

        for (var food in allFoods) {
          final macros = FoodLoggingHelper.extractMacros(
            food['food_description'] as String? ?? '',
          );
          protein += macros['protein'] ?? 0;
          carbs += macros['carbs'] ?? 0;
          fat += macros['fat'] ?? 0;
        }
      }
      day = day.add(const Duration(days: 1));
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
    );
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
                  lightenColor(appColorNotifier.value, 0.45),
                  lightenColor(appColorNotifier.value, 0.2),
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
      height: Responsive.height(context, 220),
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
                            color: lightenColor(appColorNotifier.value, 0.45),
                          ),
                        ),
                        Text(
                          "${v.round()} kcal",
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 10),
                            fontWeight: FontWeight.w700,
                            color: lightenColor(appColorNotifier.value, 0.45),
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
                        fontSize: Responsive.font(context, 10),
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
                  lightenColor(appColorNotifier.value, 0.45),
                  lightenColor(appColorNotifier.value, 0.2),
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
      height: Responsive.height(context, 220),
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
                            color: lightenColor(appColorNotifier.value, 0.45),
                          ),
                        ),
                        Text(
                          "${v.round()}g",
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 10),
                            fontWeight: FontWeight.w700,
                            color: lightenColor(appColorNotifier.value, 0.45),
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
                        fontSize: Responsive.font(context, 10),
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
    // Protein and carbs are 4 kcal/g, fat is 9 kcal/g
    // These convert grams to calories so the macro bar reflects its actual contribution
    final proteinCal = macros['protein']! * 4;
    final carbsCal = macros['carbs']! * 4;
    final fatCal = macros['fat']! * 9;
    final totalMacroCal = proteinCal + carbsCal + fatCal;

    return Container(
      decoration: BoxDecoration(gradient: buildThemeGradient()),
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
                        Icons.arrow_back_ios_new,
                        color: lightenColor(
                          appColorNotifier.value,
                          0.3,
                        ).withAlpha(180),
                        size: Responsive.font(context, 13),
                      ),
                    ),
                  ),
                ),
              ),
              // Pill-style tab bar sitting on the gradient
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.width(context, 12),
                  vertical: Responsive.height(context, 8),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: Responsive.isDesktop(context),
                  tabAlignment: Responsive.isDesktop(context)
                      ? TabAlignment.center
                      : TabAlignment.fill,
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
                      totalCal: totalCal,
                      breakfastCal: breakfastCal,
                      lunchCal: lunchCal,
                      dinnerCal: dinnerCal,
                      snacksCal: snacksCal,
                      macros: macros,
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
            frostedGlassCard(
              context,
              padding: EdgeInsets.all(Responsive.scale(context, 12)),
              child: TableCalendar(
                firstDay: DateTime(2020),
                lastDay: DateTime.now(),
                focusedDay: _calendarFocused,
                rangeStartDay: _rangeStart,
                rangeEndDay: _rangeSelected ? _rangeEnd : null,
                rangeSelectionMode: RangeSelectionMode.toggledOn,
                // AvailableGestures.none disables the built-in gesture recognizers so mouse clicks register correctly
                availableGestures: AvailableGestures.none,
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
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  todayDecoration: const BoxDecoration(),
                  rangeStartDecoration: BoxDecoration(
                    color: appColorNotifier.value,
                    shape: BoxShape.circle,
                  ),
                  rangeEndDecoration: BoxDecoration(
                    color: appColorNotifier.value,
                    shape: BoxShape.circle,
                  ),
                  withinRangeDecoration: const BoxDecoration(
                    color: Colors.transparent,
                  ),
                  rangeHighlightColor: Colors.white.withAlpha(25),
                  defaultTextStyle: GoogleFonts.manrope(
                    color: Colors.white70,
                    fontSize: Responsive.font(context, 13),
                  ),
                  weekendTextStyle: GoogleFonts.manrope(
                    color: Colors.white70,
                    fontSize: Responsive.font(context, 13),
                  ),
                  todayTextStyle: GoogleFonts.manrope(
                    color: Colors.white70,
                    fontSize: Responsive.font(context, 13),
                  ),
                  rangeStartTextStyle: GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: Responsive.font(context, 13),
                    fontWeight: FontWeight.w700,
                  ),
                  rangeEndTextStyle: GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: Responsive.font(context, 13),
                    fontWeight: FontWeight.w700,
                  ),
                  withinRangeTextStyle: GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: Responsive.font(context, 13),
                  ),
                  outsideTextStyle: GoogleFonts.manrope(
                    color: Colors.white24,
                    fontSize: Responsive.font(context, 13),
                  ),
                  disabledTextStyle: GoogleFonts.manrope(
                    color: Colors.white24,
                    fontSize: Responsive.font(context, 13),
                  ),
                ),
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: Responsive.font(context, 14),
                    fontWeight: FontWeight.w700,
                  ),
                  leftChevronIcon: HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowLeft01,
                    color: Colors.white70,
                    size: Responsive.font(context, 22),
                  ),
                  rightChevronIcon: HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    color: Colors.white70,
                    size: Responsive.font(context, 22),
                  ),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: GoogleFonts.manrope(
                    color: Colors.white38,
                    fontSize: Responsive.font(context, 12),
                    fontWeight: FontWeight.w600,
                  ),
                  weekendStyle: GoogleFonts.manrope(
                    color: Colors.white38,
                    fontSize: Responsive.font(context, 12),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            if (!_rangeSelected) ...[
              SizedBox(height: Responsive.height(context, 32)),
              Center(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedCursor01,
                      color: Colors.white24,
                      size: Responsive.font(context, 28),
                    ),
                    SizedBox(height: Responsive.height(context, 10)),
                    Text(
                      "Pick a start date, then an end date to view your nutrition trends",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: Responsive.font(context, 14),
                        fontWeight: FontWeight.w600,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
            ],

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

                  final totalMacroCal =
                      agg.protein * 4 + agg.carbs * 4 + agg.fat * 9;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // stat tiles show the range total with an avg/logged day line underneath
                      _rangeStatTilesRow(context: context, agg: agg)
                          .animate(
                            key: ValueKey((
                              'range_stat_tiles',
                              _rangeAnimationKey,
                            )),
                          )
                          .fadeIn(duration: 300.ms)
                          .slideY(
                            begin: 0.08,
                            duration: 300.ms,
                            curve: Curves.easeOut,
                          ),

                      SizedBox(height: Responsive.height(context, 24)),

                      sectionHeader("CALORIE BREAKDOWN", context)
                          .animate(
                            key: ValueKey((
                              'range_calories_title',
                              _rangeAnimationKey,
                            )),
                          )
                          .fadeIn(duration: 300.ms)
                          .slideY(
                            begin: 0.08,
                            duration: 300.ms,
                            curve: Curves.easeOut,
                          ),
                      frostedGlassCard(
                            context,
                            padding: EdgeInsets.all(
                              Responsive.scale(context, 20),
                            ),
                            child: agg.totalCal == 0
                                ? _emptyState(
                                    context,
                                    "No calories logged in this range",
                                  )
                                : _mealBarChart(
                                    context,
                                    breakfastCal: agg.breakfastCal,
                                    lunchCal: agg.lunchCal,
                                    dinnerCal: agg.dinnerCal,
                                    snacksCal: agg.snacksCal,
                                  ),
                          )
                          .animate(
                            key: ValueKey((
                              'range_calories_chart',
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

                      sectionHeader("MACRO BREAKDOWN", context)
                          .animate(
                            key: ValueKey((
                              'range_macros_title',
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
                      frostedGlassCard(
                            context,
                            padding: EdgeInsets.all(
                              Responsive.scale(context, 20),
                            ),
                            child: totalMacroCal == 0
                                ? _emptyState(
                                    context,
                                    "No macro data for this range",
                                  )
                                : _macroBarChart(
                                    context,
                                    proteinG: agg.protein,
                                    carbsG: agg.carbs,
                                    fatG: agg.fat,
                                  ),
                          )
                          .animate(
                            key: ValueKey((
                              'range_macros_chart',
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

// Extracted daily tab body so the main build method stays readable
class _DailyTab extends StatelessWidget {
  final BuildContext context;
  final double totalCal;
  final double breakfastCal;
  final double lunchCal;
  final double dinnerCal;
  final double snacksCal;
  final Map<String, double> macros;
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
    required this.totalCal,
    required this.breakfastCal,
    required this.lunchCal,
    required this.dinnerCal,
    required this.snacksCal,
    required this.macros,
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

            // Summary stat tiles: calories, protein, carbs, fat at a glance
            _statTilesRow(context: ctx, totalCal: totalCal, macros: macros)
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

// The four tiles shown between the date picker and the charts
// total calories, protein, carbs, and fat for the selected day
Widget _statTilesRow({
  required BuildContext context,
  required double totalCal,
  required Map<String, double> macros,
}) {
  final base = appColorNotifier.value;
  // IntrinsicHeight forces all tiles to match the height of the tallest one
  return IntrinsicHeight(
    child: Row(
      children: [
        // Calories tile is wider since it anchors the whole summary
        Expanded(
          flex: 5,
          child: _statTile(
            context: context,
            icon: HugeIcons.strokeRoundedFire,
            iconColor: lightenColor(base, 0.45),
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
            icon: HugeIcons.strokeRoundedDumbbell01,
            iconColor: lightenColor(base, 0.45),
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
            icon: HugeIcons.strokeRoundedBread01,
            iconColor: lightenColor(base, 0.45),
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
            icon: HugeIcons.strokeRoundedDroplet,
            iconColor: lightenColor(base, 0.45),
            label: "Fat",
            value: macros['fat'] == 0 ? "—" : macros['fat']!.round().toString(),
            unit: macros['fat'] == 0 ? "" : "g",
          ),
        ),
      ],
    ),
  );
}

// same layout as the daily stat tiles row but passes agg instead of individual values
// each tile shows the range total and an avg/logged day line so the user sees both at a glance
Widget _rangeStatTilesRow({
  required BuildContext context,
  required _RangeAggregate agg,
}) {
  final base = appColorNotifier.value;
  final days = agg.daysWithData;
  return IntrinsicHeight(
    child: Row(
      children: [
        Expanded(
          flex: 5,
          child: _rangeTile(
            context: context,
            icon: HugeIcons.strokeRoundedFire,
            iconColor: lightenColor(base, 0.45),
            label: "Calories",
            total: agg.totalCal == 0 ? "—" : agg.totalCal.round().toString(),
            unit: agg.totalCal == 0 ? "" : "kcal",
            avg: days > 0
                ? "${(agg.totalCal / days).round()} avg/logged day"
                : "",
          ),
        ),
        SizedBox(width: Responsive.width(context, 10)),
        Expanded(
          flex: 4,
          child: _rangeTile(
            context: context,
            icon: HugeIcons.strokeRoundedDumbbell01,
            iconColor: lightenColor(base, 0.45),
            label: "Protein",
            total: agg.protein == 0 ? "—" : agg.protein.round().toString(),
            unit: agg.protein == 0 ? "" : "g",
            avg: days > 0
                ? "${(agg.protein / days).round()} avg/logged day"
                : "",
          ),
        ),
        SizedBox(width: Responsive.width(context, 10)),
        Expanded(
          flex: 4,
          child: _rangeTile(
            context: context,
            icon: HugeIcons.strokeRoundedBread01,
            iconColor: lightenColor(base, 0.45),
            label: "Carbs",
            total: agg.carbs == 0 ? "—" : agg.carbs.round().toString(),
            unit: agg.carbs == 0 ? "" : "g",
            avg: days > 0 ? "${(agg.carbs / days).round()} avg/logged day" : "",
          ),
        ),
        SizedBox(width: Responsive.width(context, 10)),
        Expanded(
          flex: 4,
          child: _rangeTile(
            context: context,
            icon: HugeIcons.strokeRoundedDroplet,
            iconColor: lightenColor(base, 0.45),
            label: "Fat",
            total: agg.fat == 0 ? "—" : agg.fat.round().toString(),
            unit: agg.fat == 0 ? "" : "g",
            avg: days > 0 ? "${(agg.fat / days).round()} avg/logged day" : "",
          ),
        ),
      ],
    ),
  );
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
          HugeIcon(
            icon: icon,
            color: iconColor,
            size: Responsive.font(context, 20),
          ),
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

// same as _statTile but adds an avg line beneath the unit label
// avg is pre-formatted by the caller so this widget doesn't need to know about daysWithData
Widget _rangeTile({
  required BuildContext context,
  required IconData icon,
  required Color iconColor,
  required String label,
  required String total,
  required String unit,
  required String avg,
}) {
  return frostedGlassCard(
    context,
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
  });
}
