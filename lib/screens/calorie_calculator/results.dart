import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '/globals.dart';
import '/utility/responsive.dart';

class Results extends StatefulWidget {
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
  State<Results> createState() => _ResultsState();
}

class _ResultsState extends State<Results> {
  late final String bmr = calculateBMR();
  late final int tdee = calculateTDEE(bmr, calculateActivityLevel());

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

  String calculateGoal() {
    int userTDEE = calculateTDEE(bmr, calculateActivityLevel());
    // Case 1: Goal is to maintain
    if (widget.goal == "Maintain Weight") {
      return "Consume $userTDEE calories per day to maintain your weight.";
    }
    StringBuffer sb = StringBuffer();
    // Case 2: Goal is to lose
    if (widget.goal == "Lose Weight") {
      if (widget.units == "Imperial") {
        sb.write("A healthy weight loss rate is 0.5-2 pounds per week.\n\n");
        sb.write("- Lose 0.5 lbs/week -> ${userTDEE - 250} cal/day\n");
        sb.write("- Lose 1 lb/week -> ${userTDEE - 500} cal/day\n");
        sb.write("- Lose 1.5 lbs/week -> ${userTDEE - 750} cal/day\n");
        sb.write("- Lose 2 lbs/week -> ${userTDEE - 1000} cal/day");
      } else {
        sb.write("A healthy weight loss rate is 0.23-0.9 kg per week.\n\n");
        sb.write("- Lose 0.23 kg/week -> ${userTDEE - 250} cal/day\n");
        sb.write("- Lose 0.45 kg/week -> ${userTDEE - 500} cal/day\n");
        sb.write("- Lose 0.68 kg/week -> ${userTDEE - 750} cal/day\n");
        sb.write("- Lose 0.9 kg/week -> ${userTDEE - 1000} cal/day");
      }
      // Case 3: Goal is to gain
    } else if (widget.units == "Imperial" && widget.goal == "Gain Weight") {
      sb.write("A healthy weight gain rate is 0.5-1 pound per week.\n\n");
      sb.write("- Gain 0.5 lbs/week -> ${userTDEE + 250} cal/day\n");
      sb.write("- Gain 1 lb/week -> ${userTDEE + 500} cal/day");
    } else {
      sb.write("A healthy weight gain rate is 0.23-0.45 kg per week.\n\n");
      sb.write("- Gain 0.23 kg/week -> ${userTDEE + 250} cal/day\n");
      sb.write("- Gain 0.45 kg/week -> ${userTDEE + 500} cal/day");
    }
    return sb.toString();
  }

  double calculateActivityLevel() {
    switch (widget.activityLevel!) {
      case "Sedentary":
        return 1.2;
      case "Light":
        return 1.375;
      case "Moderate":
        return 1.5;
      case "Active":
        return 1.725;
      case "Very Active":
        return 1.9;
    }
    return 1.2;
  }

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
      padding: EdgeInsets.all(Responsive.scale(context, 18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
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
          Icon(
            icon,
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
        horizontal: Responsive.width(context, 20),
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
          // Header box
          appBar: AppBar(
            backgroundColor: darkenColor(
              appColorNotifier.value,
              0.025,
            ), // Header color
            scrolledUnderElevation: 0,
            centerTitle: true,
            toolbarHeight: Responsive.buttonHeight(context, 120),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.go('/calorie-calculator'),
            ),
            title: createTitle("Calorie Results", context),
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(Responsive.height(context, 48)),
              child: Column(
                children: [
                  Container(
                    height: Responsive.height(context, 1),
                    color: Colors.white.withAlpha(25),
                  ),
                  // Tab bar with one tab per section
                  TabBar(
                    indicatorColor: Colors.white,
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white38,
                    labelStyle: GoogleFonts.manrope(
                      fontSize: Responsive.font(context, 13),
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: GoogleFonts.manrope(
                      fontSize: Responsive.font(context, 13),
                      fontWeight: FontWeight.w500,
                    ),
                    tabs: const [
                      Tab(text: "Results"),
                      Tab(text: "Overview"),
                      Tab(text: "Formulas"),
                    ],
                  ),
                ],
              ),
            ),
          ),
          body: TabBarView(
            children: [
              // Tab 1: User results
              _tab([
                _sectionWithIcon("YOUR BMR", Icons.favorite_border),
                _statCard(
                  bmr,
                  "calories / day at rest",
                  "${_bmrEquationText()} = $bmr",
                  note:
                      "What your body burns just to stay alive. Does not include any physical activity.",
                ),
                SizedBox(height: Responsive.height(context, 20)),
                _sectionWithIcon(
                  "YOUR TDEE",
                  Icons.local_fire_department_outlined,
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
                  Icons.flag_outlined,
                ),
                _infoCard(calculateGoal()),
                SizedBox(height: Responsive.height(context, 40)),
              ]),

              // Tab 2: Educational section
              _tab([
                _sectionWithIcon("WHAT IS BMR?", Icons.info_outline),
                _infoCard(
                  widget.equation == "Mifflin-St Jeor"
                      ? "The ${widget.equation} equation calculates your Basal Metabolic Rate (BMR) - the minimum calories your body needs for essential functions like breathing, cell repair, and blood circulation. This formula is a revised version of the Harris-Benedict equation."
                      : "The revised ${widget.equation} equation calculates your Basal Metabolic Rate (BMR) - the minimum calories your body needs for essential functions like breathing, cell repair, and blood circulation. The original formula was revised in 1984 by Roza and Shizgal for greater accuracy.",
                ),
                SizedBox(height: Responsive.height(context, 20)),
                _sectionWithIcon(
                  "WHAT IS TDEE?",
                  Icons.local_fire_department_outlined,
                ),
                _infoCard(
                  "Your Total Daily Energy Expenditure (TDEE) is the total calories you burn in a day. Consuming this amount maintains your current weight.\n\nTDEE = BMR × Activity Level",
                ),
                SizedBox(height: Responsive.height(context, 40)),
              ]),

              // Tab 3: Full BMR formulas for reference
              _tab([
                _sectionWithIcon("BMR FORMULAS", Icons.calculate_outlined),
                _formulaCard(
                  _bmrFormulaText("Male"),
                  "Male",
                  Colors.lightBlueAccent,
                  Icons.male,
                ),
                SizedBox(height: Responsive.height(context, 20)),
                _formulaCard(
                  _bmrFormulaText("Female"),
                  "Female",
                  Colors.pinkAccent,
                  Icons.female,
                ),
                SizedBox(height: Responsive.height(context, 20)),
                _sectionWithIcon(
                  "ACTIVITY LEVEL MULTIPLIERS",
                  Icons.directions_run,
                ),

                _infoCard(
                  "Sedentary = 1.2\nLight = 1.375\nModerate = 1.55\nActive = 1.725\nVery Active = 1.9",
                  addDivider: true,
                  aboveDividerText: "TDEE = BMR × Activity Multiplier",
                ),
                SizedBox(height: Responsive.height(context, 40)),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
