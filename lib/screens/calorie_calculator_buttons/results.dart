import 'package:flutter/material.dart';
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
        sb.write("A healthy weight loss rate is 0.5–2 pounds per week.\n\n");
        sb.write("• Lose 0.5 lbs/week → ${userTDEE - 250} cal/day\n");
        sb.write("• Lose 1 lb/week → ${userTDEE - 500} cal/day\n");
        sb.write("• Lose 1.5 lbs/week → ${userTDEE - 750} cal/day\n");
        sb.write("• Lose 2 lbs/week → ${userTDEE - 1000} cal/day");
      } else {
        sb.write("A healthy weight loss rate is 0.23–0.9 kg per week.\n\n");
        sb.write("• Lose 0.23 kg/week → ${userTDEE - 250} cal/day\n");
        sb.write("• Lose 0.45 kg/week → ${userTDEE - 500} cal/day\n");
        sb.write("• Lose 0.68 kg/week → ${userTDEE - 750} cal/day\n");
        sb.write("• Lose 0.9 kg/week → ${userTDEE - 1000} cal/day");
      }
      // Case 3: Goal is to gain
    } else if (widget.units == "Imperial" && widget.goal == "Gain Weight") {
      sb.write("A healthy weight gain rate is 0.5–1 pound per week.\n\n");
      sb.write("• Gain 0.5 lbs/week → ${userTDEE + 250} cal/day\n");
      sb.write("• Gain 1 lb/week → ${userTDEE + 500} cal/day");
    } else {
      sb.write("A healthy weight gain rate is 0.23–0.45 kg per week.\n\n");
      sb.write("• Gain 0.23 kg/week → ${userTDEE + 250} cal/day\n");
      sb.write("• Gain 0.45 kg/week → ${userTDEE + 500} cal/day");
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

  Widget sectionTitle(String text, BuildContext context, {Color? color}) {
    return Padding(
      padding: EdgeInsets.only(
        top: Responsive.height(context, 20),
        bottom: Responsive.height(context, 8),
      ),
      child: Text(
        text,
        style: GoogleFonts.dangrek(
          fontSize: Responsive.font(context, 28),
          color: color ?? Colors.white,
          shadows: [
            Shadow(
              offset: Offset(
                Responsive.scale(context, 2),
                Responsive.scale(context, 2),
              ),
              blurRadius: Responsive.scale(context, 6),
              color: Colors.black,
            ),
          ],
        ),
      ),
    );
  }

  Widget resultCard(String text, BuildContext context) {
    return Card(
      elevation: Responsive.scale(context, 4),
      color: darkenColor(appColorNotifier.value, 0.025),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Responsive.scale(context, 12)),
      ),
      child: Padding(
        padding: EdgeInsets.all(Responsive.width(context, 16)),
        child: Text(
          text,
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 18),
            color: Colors.white,
            height: 1.6, // line spacing for readability
            shadows: [
              Shadow(
                offset: Offset(
                  Responsive.scale(context, 2),
                  Responsive.scale(context, 2),
                ),
                blurRadius: Responsive.scale(context, 6),
                color: Colors.black,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Divider between user and educational section
  Widget sectionDivider(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: Responsive.height(context, 10)),
      child: Divider(
        color: Colors.white.withAlpha(40),
        thickness: Responsive.scale(context, 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
          title: createTitle("Results", context),
        ),
        body: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(Responsive.width(context, 20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // User results first
                  sectionTitle("Your BMR", context, color: Colors.redAccent),
                  resultCard(
                    widget.equation == "Mifflin-St Jeor"
                        ? widget.units == "MetricDefault" ||
                                  widget.units == "Metric"
                              ? widget.sex == "Female"
                                    ? "(10 × ${widget.weight}) + (6.25 × ${widget.heightCm}) − (5 × ${widget.age}) − 161 = $bmr" // Female Metric Mifflin
                                    : "(10 × ${widget.weight}) + (6.25 × ${widget.heightCm}) − (5 × ${widget.age}) + 5 = $bmr" // Male Metric Mifflin
                              : widget.sex == "Female"
                              ? "(4.35 × ${widget.weight}) + (4.7 × ${widget.heightInches}) − (4.7 × ${widget.age} + 655) = $bmr" // Female Imperial Mifflin
                              : "(6.23 × ${widget.weight}) + (12.7 × ${widget.heightInches}) − (6.8 × ${widget.age} + 66) = $bmr" // Male Imperial Mifflin
                        : widget.units == "MetricDefault" ||
                              widget.units == "Metric"
                        ? widget.sex == "Female"
                              ? "(9.247 × ${widget.weight}) + (3.098 × ${widget.heightCm}) − (4.330 × ${widget.age}) + 447.593 = $bmr" // Female Metric Harris
                              : "(13.397 × ${widget.weight}) + (4.799 × ${widget.heightCm}) − (5.677 × ${widget.age}) + 88.362 = $bmr" // Male Metric Harris
                        : widget.sex == "Female"
                        ? "(4.35 × ${widget.weight}) + (4.7 × ${widget.heightInches}) − (4.7 × ${widget.age}) + 655.095 = $bmr" // Female Imperial Harris
                        : "(6.23 × ${widget.weight}) + (12.7 × ${widget.heightInches}) − (6.8 × ${widget.age}) + 66.473 = $bmr", // Male Imperial Harris
                    context,
                  ),

                  sectionTitle("Your TDEE", context, color: Colors.redAccent),
                  resultCard(
                    "$bmr × ${calculateActivityLevel()} = ${calculateTDEE(bmr, calculateActivityLevel())} calories/day",
                    context,
                  ),

                  sectionTitle(
                    "How to ${widget.goal}",
                    context,
                    color: Colors.redAccent,
                  ),
                  resultCard(calculateGoal(), context),

                  sectionDivider(context),

                  // Educational section
                  sectionTitle("What is BMR?", context),
                  resultCard(
                    widget.equation == "Mifflin-St Jeor"
                        ? "The ${widget.equation} equation calculates your Basal Metabolic Rate (BMR) — the minimum calories your body needs for essential functions like breathing, cell repair, and blood circulation. This formula is a revised version of the Harris-Benedict equation."
                        : "The revised ${widget.equation} equation calculates your Basal Metabolic Rate (BMR) — the minimum calories your body needs for essential functions like breathing, cell repair, and blood circulation. The original formula was revised in 1984 by Roza and Shizgal for greater accuracy.",
                    context,
                  ),

                  sectionTitle(
                    "Male BMR Formula",
                    context,
                    color: const Color.fromARGB(255, 5, 71, 142),
                  ),
                  resultCard(
                    widget.equation == "Mifflin-St Jeor"
                        ? widget.units == "MetricDefault" ||
                                  widget.units == "Metric"
                              ? "(10 × weight kg) + (6.25 × height cm) − (5 × age) + 5" // Mifflin Metric
                              : "([10 / 2.205] × weight lbs) + ([6.25 × 2.54] × height in) − (5 × age) + 5" // Mifflin Imperial
                        : widget.units == "MetricDefault" ||
                              widget.units == "Metric"
                        ? "(13.397 × weight kg) + (4.799 × height cm) − (5.677 × age) + 88.362" // Harris Metric
                        : "([13.397 / 2.205] × weight lbs) + ([4.799 × 2.54] × height in) − (5.677 × age) + 88.362", // Harris Imperial
                    context,
                  ),

                  sectionTitle(
                    "Female BMR Formula",
                    context,
                    color: const Color.fromARGB(255, 210, 4, 138),
                  ),
                  resultCard(
                    widget.equation == "Mifflin-St Jeor"
                        ? widget.units == "MetricDefault" ||
                                  widget.units == "Metric"
                              ? "(10 × weight kg) + (6.25 × height cm) − (5 × age) − 161" // Mifflin Metric
                              : "([10 / 2.205] × weight lbs) + ([6.25 × 2.54] × height in) − (5 × age) − 161" // Mifflin Imperial
                        : widget.units == "MetricDefault" ||
                              widget.units == "Metric"
                        ? "(9.247 × weight kg) + (3.098 × height cm) − (4.330 × age) + 447.593" // Harris Metric
                        : "([9.247 / 2.205] × weight lbs) + ([3.098 × 2.54] × height in) − (4.330 × age) + 447.593", // Harris Imperial
                    context,
                  ),

                  sectionTitle("What is TDEE?", context),
                  resultCard(
                    "Your Total Daily Energy Expenditure (TDEE) is the total calories you burn in a day. Consuming this amount maintains your current weight.\n\nTDEE = BMR × Activity Level",
                    context,
                  ),

                  sectionTitle("Activity Level Multipliers", context),
                  resultCard(
                    "• Sedentary = 1.2\n• Light = 1.375\n• Moderate = 1.55\n• Active = 1.725\n• Very Active = 1.9",
                    context,
                  ),

                  SizedBox(height: Responsive.height(context, 30)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
