import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/providers/user_data_provider.dart';
import '/services/user_data_manager.dart' show defaultAppColor;
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '/globals.dart';
import '/utility/responsive.dart';
import '/utility/tdee_calculator.dart';

class Results extends ConsumerStatefulWidget {
  // same-named variables from Calorie Calculator that are assigned when the page is switched from that tab to this one
  final String? units;
  final String? goal;
  final String? sex;
  final String? activityLevel;
  final String? equation;
  final int? age;
  final int? heightCm;
  final int? heightInches;
  final double?
  weight; // One value for either Lbs or Kg -> Converted to a double -> Calculated based on units chosen

  const Results({
    // constructor
    super.key,
    required this.units, // required means the value cannot be null and a value must be provided when creating the widget
    required this.goal,
    required this.sex,
    required this.activityLevel,
    required this.equation,
    required this.age,
    required this.heightCm,
    required this.heightInches,
    required this.weight,
  });

  @override
  ConsumerState<Results> createState() => _ResultsState();
}

class _ResultsState extends ConsumerState<Results> {
  Color get appColor => ref.watch(
    userDataProvider.select((s) => s.value?.appColor ?? defaultAppColor),
  );

  @override
  void initState() {
    super.initState();
    FirebaseAnalytics.instance.logScreenView(
      screenName: '/calorie-calculator/results',
      screenClass: 'Results',
    );
  }

  late final String bmr = calculateBMR();
  late final int tdee = calculateTDEE(bmr, calculateActivityLevel());
  int?
  _goalSetCalories; // calories value most recently set as goal, for confirmation

  String calculateBMR() {
    return // MIFFLIN CASES
    widget.equation ==
            "Mifflin-St Jeor" // MIFFLIN
        ? widget.units == "MetricDefault" ||
                  widget.units ==
                      "Metric" // Mifflin and Metric
              ? widget.sex ==
                        "Female" // Female and Metric and Mifflin
                    ? ((10 * widget.weight!) +
                              (6.25 * widget.heightCm!) -
                              (5 * widget.age!) -
                              161)
                          .toStringAsFixed(0) // Female and Metric and Mifflin
                    : ((10 * widget.weight!) +
                              (6.25 * widget.heightCm!) -
                              (5 * widget.age!) +
                              5)
                          .toStringAsFixed(0) // Male and Metric and Mifflin
              : widget.sex ==
                    "Female" // Female and Imperial and Mifflin
              ? (((10 / 2.205) * widget.weight!) +
                        ((6.25 * 2.54) * widget.heightInches!) -
                        (5 * widget.age!) -
                        161)
                    .toStringAsFixed(0) // Female and Imperial and Mifflin
              : (((10 / 2.205) * widget.weight!) +
                        ((6.25 * 2.54) * widget.heightInches!) -
                        (5 * widget.age!) +
                        5)
                    .toStringAsFixed(0) // Male and Imperial and Mifflin
        // HARRIS CASES
        : widget.units == "MetricDefault" ||
              widget.units ==
                  "Metric" // Harris and Metric
        ? widget.sex ==
                  "Female" // Female and Metric and Harris
              ? ((9.247 * widget.weight!) +
                        (3.098 * widget.heightCm!) -
                        (4.330 * widget.age!) +
                        447.593)
                    .toStringAsFixed(0) // Female and Metric and Harris
              : ((13.397 * widget.weight!) +
                        (4.799 * widget.heightCm!) -
                        (5.677 * widget.age!) +
                        88.362)
                    .toStringAsFixed(0) // Male and Metric and Harris
        : widget.sex ==
              "Female" // Female and Imperial and Harris
        ? (((9.247 / 2.205) * widget.weight!) +
                  ((3.098 * 2.54) * widget.heightInches!) -
                  (4.330 * widget.age!) +
                  447.593)
              .toStringAsFixed(0) // Female and Imperial and Harris
        : (((13.397 / 2.205) * widget.weight!) +
                  ((4.799 * 2.54) * widget.heightInches!) -
                  (5.677 * widget.age!) +
                  88.362)
              .toStringAsFixed(0); // Male and Imperial and Harris
  }

  Future<void> _setCalorieGoal(int calories) async {
    final goalType = widget.goal == "Lose Weight"
        ? "lose"
        : widget.goal == "Gain Weight"
        ? "gain"
        : "maintain";
    await userManager.updateGoals(
      caloriesGoal: calories,
      weightGoalType: goalType,
      context: context,
    );
    if (!mounted) return;
    setState(() => _goalSetCalories = calories);
  }

  // Builds the goal section as a styled card with big calorie targets and rate breakdowns
  Widget _goalCard() {
    final userTDEE = calculateTDEE(bmr, calculateActivityLevel());
    final imperial = widget.units == "Imperial";

    // Case 1: Goal is to maintain
    if (widget.goal == "Maintain Weight") {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _statCard(
            userTDEE.toString(),
            "calories / day",
            "TDEE = $userTDEE",
            note: "Eating this amount keeps your weight stable.",
          ),
          SizedBox(height: Responsive.height(context, 12)),
          _setGoalButton(userTDEE),
        ],
      );
    }

    final bool losing = widget.goal == "Lose Weight";

    // Case 2: Goal is to lose
    final String healthyRange = losing
        ? (imperial
              ? "A healthy loss rate is 0.5–2 lbs per week."
              : "A healthy loss rate is 0.23–0.9 kg per week.")
        // Case 3: Goal is to gain
        : (imperial
              ? "A healthy gain rate is 0.5–1 lb per week."
              : "A healthy gain rate is 0.23–0.45 kg per week.");

    final List<({String rate, int calories})> rates = losing
        ? imperial
              ? [
                  (rate: "Lose 0.5 lbs / week", calories: userTDEE - 250),
                  (rate: "Lose 1 lb / week", calories: userTDEE - 500),
                  (rate: "Lose 1.5 lbs / week", calories: userTDEE - 750),
                  (rate: "Lose 2 lbs / week", calories: userTDEE - 1000),
                ]
              : [
                  (rate: "Lose 0.23 kg / week", calories: userTDEE - 250),
                  (rate: "Lose 0.45 kg / week", calories: userTDEE - 500),
                  (rate: "Lose 0.68 kg / week", calories: userTDEE - 750),
                  (rate: "Lose 0.9 kg / week", calories: userTDEE - 1000),
                ]
        : imperial
        ? [
            (rate: "Gain 0.5 lbs / week", calories: userTDEE + 250),
            (rate: "Gain 1 lb / week", calories: userTDEE + 500),
          ]
        : [
            (rate: "Gain 0.23 kg / week", calories: userTDEE + 250),
            (rate: "Gain 0.45 kg / week", calories: userTDEE + 500),
          ];

    return frostedGlassCard(
      context,
      color: appColor,
      padding: EdgeInsets.all(Responsive.scale(context, 18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            healthyRange,
            style: GoogleFonts.manrope(
              fontSize: Responsive.font(context, 13),
              color: Colors.white54,
              height: 1.5,
            ),
          ),
          SizedBox(height: Responsive.height(context, 16)),
          for (final entry in rates) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.rate,
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 13),
                          color: Colors.white54,
                        ),
                      ),
                      ShaderMask(
                        shaderCallback: (bounds) =>
                            subtleTextGradient().createShader(
                              Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                            ),
                        child: Text(
                          "${entry.calories} cal/day",
                          style: GoogleFonts.dangrek(
                            fontSize: Responsive.font(context, 22),
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _setGoalButton(entry.calories),
              ],
            ),
            if (entry != rates.last)
              Divider(
                color: Colors.white.withAlpha(20),
                height: Responsive.height(context, 24),
              ),
          ],
        ],
      ),
    );
  }

  Widget _setGoalButton(int calories) {
    final isSet = _goalSetCalories == calories;
    return GestureDetector(
      onTap: isSet
          ? null
          : () async {
              final confirmed = await showFrostedAlertDialog<bool>(
                context: context,
                title: "Set calorie goal?",
                content: Text(
                  "This will set your daily calorie goal to $calories kcal.",
                  style: GoogleFonts.manrope(color: Colors.white70),
                ),
                actions: [
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context, rootNavigator: true).pop(false),
                    child: Text("Cancel", style: dialogButtonStyle()),
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context, rootNavigator: true).pop(true),
                    child: Text("Set", style: dialogButtonStyle(confirm: true)),
                  ),
                ],
              );
              if (confirmed == true) _setCalorieGoal(calories);
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.width(context, 12),
          vertical: Responsive.height(context, 6),
        ),
        decoration: BoxDecoration(
          color: lightenColor(appColor, 0.1).withAlpha(isSet ? 60 : 30),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: lightenColor(appColor, 0.35).withAlpha(isSet ? 200 : 120),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSet ? Icons.check : Icons.flag_outlined,
              color: lightenColor(appColor, 0.45),
              size: Responsive.scale(context, 13),
            ),
            SizedBox(width: Responsive.width(context, 4)),
            Text(
              isSet ? "Goal set" : "Set goal",
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 12),
                fontWeight: FontWeight.w600,
                color: lightenColor(appColor, 0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double calculateActivityLevel() => tdeeActivityFactor(widget.activityLevel!);

  int calculateTDEE(String userBMR, double activityLvl) {
    return (double.parse(userBMR) * activityLvl).round();
  }

  // Returns the BMR equation with the user's numbers plugged in
  String _bmrEquationText() {
    if (widget.equation == "Mifflin-St Jeor") {
      if (widget.units == "MetricDefault" || widget.units == "Metric") {
        if (widget.sex == "Female") {
          return "(10 × ${widget.weight}) + (6.25 × ${widget.heightCm}) - (5 × ${widget.age}) - 161"; // Female Metric Mifflin
        } else {
          return "(10 × ${widget.weight}) + (6.25 × ${widget.heightCm}) - (5 × ${widget.age}) + 5"; // Male Metric Mifflin
        }
      } else {
        if (widget.sex == "Female") {
          return "(4.35 × ${widget.weight}) + (4.7 × ${widget.heightInches}) - (4.7 × ${widget.age} + 655)"; // Female Imperial Mifflin
        } else {
          return "(6.23 × ${widget.weight}) + (12.7 × ${widget.heightInches}) - (6.8 × ${widget.age} + 66)"; // Male Imperial Mifflin
        }
      }
    } else {
      // HARRIS CASES
      if (widget.units == "MetricDefault" || widget.units == "Metric") {
        if (widget.sex == "Female") {
          return "(9.247 × ${widget.weight}) + (3.098 × ${widget.heightCm}) - (4.330 × ${widget.age}) + 447.593"; // Female Metric Harris
        } else {
          return "(13.397 × ${widget.weight}) + (4.799 × ${widget.heightCm}) - (5.677 × ${widget.age}) + 88.362"; // Male Metric Harris
        }
      } else {
        if (widget.sex == "Female") {
          return "(4.35 × ${widget.weight}) + (4.7 × ${widget.heightInches}) - (4.7 × ${widget.age}) + 655.095"; // Female Imperial Harris
        } else {
          return "(6.23 × ${widget.weight}) + (12.7 × ${widget.heightInches}) - (6.8 × ${widget.age}) + 66.473"; // Male Imperial Harris
        }
      }
    }
  }

  // Returns the general BMR formula with variable names instead of the user's numbers
  String _bmrFormulaText(String sex) {
    if (widget.equation == "Mifflin-St Jeor") {
      if (widget.units == "MetricDefault" || widget.units == "Metric") {
        if (sex == "Female") {
          return "(10 × weight kg) + (6.25 × height cm) - (5 × age) - 161"; // Mifflin Metric Female
        } else {
          return "(10 × weight kg) + (6.25 × height cm) - (5 × age) + 5"; // Mifflin Metric Male
        }
      } else {
        if (sex == "Female") {
          return "([10 / 2.205] × weight lbs) + ([6.25 × 2.54] × height in) - (5 × age) - 161"; // Mifflin Imperial Female
        } else {
          return "([10 / 2.205] × weight lbs) + ([6.25 × 2.54] × height in) - (5 × age) + 5"; // Mifflin Imperial Male
        }
      }
    } else {
      // HARRIS CASES
      if (widget.units == "MetricDefault" || widget.units == "Metric") {
        if (sex == "Female") {
          return "(9.247 × weight kg) + (3.098 × height cm) - (4.330 × age) + 447.593"; // Harris Metric Female
        } else {
          return "(13.397 × weight kg) + (4.799 × height cm) - (5.677 × age) + 88.362"; // Harris Metric Male
        }
      } else {
        if (sex == "Female") {
          return "([9.247 / 2.205] × weight lbs) + ([3.098 × 2.54] × height in) - (4.330 × age) + 447.593"; // Harris Imperial Female
        } else {
          return "([13.397 / 2.205] × weight lbs) + ([4.799 × 2.54] × height in) - (5.677 × age) + 88.362"; // Harris Imperial Male
        }
      }
    }
  }

  // Shared card style for plain text content
  Widget _infoCard(
    String text, {
    bool addDivider = false,
    String aboveDividerText = "",
  }) {
    return frostedGlassCard(
      context,
      color: appColor,
      padding: EdgeInsets.all(Responsive.scale(context, 18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (addDivider) ...[
            if (aboveDividerText.isNotEmpty) ...[
              Text(
                aboveDividerText,
                style: GoogleFonts.manrope(
                  fontSize: Responsive.font(context, 13),
                  color: Colors.white60,
                ),
              ),
              SizedBox(height: Responsive.height(context, 6)),
            ],
            Divider(color: Colors.white.withAlpha(20), height: 1),
            SizedBox(height: Responsive.height(context, 10)),
          ],
          Text(
            text,
            style: GoogleFonts.manrope(
              fontSize: Responsive.font(context, 15),
              color: Colors.white70,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  // Large stat display for a key result number with its equation as secondary context
  Widget _statCard(
    String number,
    String unit,
    String equation, {
    String? note,
  }) {
    return frostedGlassCard(
      context,
      color: appColor,
      padding: EdgeInsets.all(Responsive.scale(context, 18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Big gradient number using the same shader as the app title
          ShaderMask(
            shaderCallback: (bounds) => subtleTextGradient().createShader(
              Rect.fromLTWH(0, 0, bounds.width, bounds.height),
            ),
            child: Text(
              number,
              style: GoogleFonts.dangrek(
                fontSize: Responsive.font(context, 52),
                color: Colors.white, // color is overridden by the ShaderMask
              ),
            ),
          ),
          Text(
            unit,
            style: GoogleFonts.manrope(
              fontSize: Responsive.font(context, 12),
              color: Colors.white38,
              letterSpacing: 0.5,
            ),
          ),
          // Note to clarify what the number means
          if (note != null) ...[
            SizedBox(height: Responsive.height(context, 8)),
            Text(
              note,
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 13),
                color: Colors.white54,
                height: 1.5,
              ),
            ),
          ],
          SizedBox(height: Responsive.height(context, 12)),
          Divider(color: Colors.white.withAlpha(20), height: 1),
          SizedBox(height: Responsive.height(context, 10)),
          // Equation shown as secondary context below the big number
          Text(
            equation,
            style: GoogleFonts.manrope(
              fontSize: Responsive.font(context, 13),
              color: Colors.white38,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // Formula card with a colored label to distinguish male vs female
  Widget _formulaCard(
    String formula,
    String label,
    Color labelColor,
    IconData icon,
  ) {
    return frostedGlassCard(
      context,
      color: appColor,
      padding: EdgeInsets.all(Responsive.scale(context, 18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(
                icon: icon,
                color: labelColor,
                size: Responsive.scale(context, 18),
              ),
              SizedBox(width: Responsive.width(context, 8)),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: Responsive.font(context, 14),
                  color: labelColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.height(context, 10)),
          Divider(color: Colors.white.withAlpha(20), height: 1),
          SizedBox(height: Responsive.height(context, 10)),
          Text(
            formula,
            style: GoogleFonts.manrope(
              fontSize: Responsive.font(context, 15),
              color: Colors.white70,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  // Section header with a small icon on the left
  Widget _sectionWithIcon(String text, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: Responsive.height(context, 12)),
      child: Row(
        children: [
          HugeIcon(
            icon: icon,
            color: Colors.white38,
            size: Responsive.scale(context, 13),
          ),
          SizedBox(width: Responsive.width(context, 6)),
          Text(
            text,
            style: GoogleFonts.manrope(
              fontSize: Responsive.font(context, 11),
              color: Colors.white38,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // Shared scrollable layout wrapper used by each tab
  Widget _tab(List<Widget> children) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.centeredHorizontalPadding(context, 20),
        vertical: Responsive.height(context, 24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Wraps the scaffold so the TabBar and TabBarView share the same controller
    return DefaultTabController(
      length: 3,
      child: Container(
        decoration: BoxDecoration(gradient: buildThemeGradient()),
        child: Scaffold(
          backgroundColor: Colors.transparent, // Body color
          body: SafeArea(
            child: Column(
              children: [
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
                // Pill-style tab bar in the body so it sits on the gradient instead of the AppBar background
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.width(context, 12),
                    vertical: Responsive.height(context, 8),
                  ),
                  child: TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.center,
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
                      Tab(text: "Results"),
                      Tab(text: "Overview"),
                      Tab(text: "Formulas"),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Tab 1: User results
                      _tab([
                        _sectionWithIcon(
                          "YOUR BASAL METABOLIC RATE",
                          HugeIcons.strokeRoundedHeartCheck,
                        ),
                        _statCard(
                          bmr,
                          "calories / day at rest",
                          "${_bmrEquationText()} = $bmr",
                          note:
                              "What your body burns just to stay alive. Does not include any physical activity.",
                        ),
                        SizedBox(height: Responsive.height(context, 20)),
                        _sectionWithIcon(
                          "YOUR TOTAL DAILY ENERGY EXPENDITURE",
                          HugeIcons.strokeRoundedFire,
                        ),
                        _statCard(
                          tdee.toString(),
                          "calories / day total",
                          "$bmr × ${calculateActivityLevel()} = $tdee",
                          note:
                              "Your real daily burn based on how active you are. This is the number to use for your goals.",
                        ),
                        SizedBox(height: Responsive.height(context, 20)),
                        _sectionWithIcon(
                          "HOW TO ${widget.goal?.toUpperCase() ?? ''}",
                          HugeIcons.strokeRoundedFlag01,
                        ),
                        _goalCard(),
                        SizedBox(height: Responsive.height(context, 40)),
                      ]),

                      // Tab 2: Educational section
                      _tab([
                        _sectionWithIcon(
                          "WHAT IS BASAL METABOLIC RATE?",
                          HugeIcons.strokeRoundedInformationCircle,
                        ),
                        _infoCard(
                          widget.equation == "Mifflin-St Jeor"
                              ? "The ${widget.equation} equation calculates your Basal Metabolic Rate (BMR) - the minimum calories your body needs for essential functions like breathing, cell repair, and blood circulation. This formula is a revised version of the Harris-Benedict equation."
                              : "The revised ${widget.equation} equation calculates your Basal Metabolic Rate (BMR) - the minimum calories your body needs for essential functions like breathing, cell repair, and blood circulation. The original formula was revised in 1984 by Roza and Shizgal for greater accuracy.",
                        ),
                        SizedBox(height: Responsive.height(context, 20)),
                        _sectionWithIcon(
                          "WHAT IS TOTAL DAILY ENERGY EXPENDITURE?",
                          HugeIcons.strokeRoundedFire,
                        ),
                        _infoCard(
                          "Your Total Daily Energy Expenditure (TDEE) is the total calories you burn in a day. Consuming this amount maintains your current weight.\n\nTDEE = BMR × Activity Level",
                        ),
                        SizedBox(height: Responsive.height(context, 40)),
                      ]),

                      // Tab 3: Full BMR formulas for reference
                      _tab([
                        _sectionWithIcon(
                          "BMR FORMULAS",
                          HugeIcons.strokeRoundedCalculate,
                        ),
                        _formulaCard(
                          _bmrFormulaText("Male"),
                          "Male",
                          lightenColor(appColor, 0.3),
                          HugeIcons.strokeRoundedMaleSymbol,
                        ),
                        SizedBox(height: Responsive.height(context, 20)),
                        _formulaCard(
                          _bmrFormulaText("Female"),
                          "Female",
                          lightenColor(appColor, 0.3),
                          HugeIcons.strokeRoundedFemaleSymbol,
                        ),
                        SizedBox(height: Responsive.height(context, 20)),
                        _sectionWithIcon(
                          "ACTIVITY LEVEL MULTIPLIERS",
                          HugeIcons.strokeRoundedMultiplicationSign,
                        ),

                        _infoCard(
                          "Sedentary = 1.2\nLight = 1.375\nModerate = 1.55\nActive = 1.725\nVery Active = 1.9",
                        ),
                        SizedBox(height: Responsive.height(context, 20)),
                        _sectionWithIcon(
                          "TDEE FORMULA",
                          HugeIcons.strokeRoundedFire,
                        ),
                        frostedGlassCard(
                          context,
                          color: appColor,
                          padding: EdgeInsets.all(
                            Responsive.scale(context, 18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) =>
                                    subtleTextGradient().createShader(
                                      Rect.fromLTWH(
                                        0,
                                        0,
                                        bounds.width,
                                        bounds.height,
                                      ),
                                    ),
                                child: Text(
                                  "TDEE = BMR × Activity Multiplier",
                                  style: GoogleFonts.dangrek(
                                    fontSize: Responsive.font(context, 28),
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(height: Responsive.height(context, 8)),
                              Text(
                                "Multiply your BMR by your activity level to get the total calories your body burns each day.",
                                style: GoogleFonts.manrope(
                                  fontSize: Responsive.font(context, 13),
                                  color: Colors.white54,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: Responsive.height(context, 40)),
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
}
