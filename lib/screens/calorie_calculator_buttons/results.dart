import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '/globals.dart';

class Results extends StatefulWidget {
  // same-named variables from Calorie Calculator that are assigned when the page is switched from that tab to this one
  final String? units;
  final String? goal;
  final String? sex;
  final String? activityLevel;
  final String?
  equation; // which formula / equation to be used for the calculation
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
    // Case 1: Goal is to maintian
    if (widget.goal == "Maintain Weight") {
      return "You must consume $userTDEE calories per day to maintain your weight.";
    }
    StringBuffer sb = StringBuffer();
    // Case 2: Goal is to lose
    if (widget.goal == "Lose Weight") {
      if (widget.units == "Imperial") {
        sb.write("• A healthy weight loss rate is 0.5-2 pounds per week.\n\n");
        sb.write(
          "• To lose 0.5 pounds per week, consume ${userTDEE - 250} calories per day.\n\n",
        );
        sb.write(
          "• To lose 1 pound per week, consume ${userTDEE - 500} calories per day.\n\n",
        );
        sb.write(
          "• To lose 1.5 pounds per week, consume ${userTDEE - 750} calories per day.\n\n",
        );
        sb.write(
          "• To lose 2 pounds per week, consume ${userTDEE - 1000} calories per day.",
        );
      } else {
        sb.write(
          "• A healthy weight loss rate is 0.23-0.9 kilograms per week.\n\n",
        );
        sb.write(
          "• To lose 0.23 kilograms per week, consume ${userTDEE - 250} calories per day.\n\n",
        );
        sb.write(
          "• To lose 0.45 kilograms per week, consume ${userTDEE - 500} calories per day.\n\n",
        );
        sb.write(
          "• To lose 0.68 kilograms per week, consume ${userTDEE - 750} calories per day.\n\n",
        );
        sb.write(
          "• To lose 0.9 kilograms per week, consume ${userTDEE - 1000} calories per day.",
        );
      }
      // Case 3: Goal is to gain
    } else if (widget.units == "Imperial" && widget.goal == "Gain Weight") {
      sb.write("• A healthy weight gain rate is 0.5-1 pound per week.\n\n");
      sb.write(
        "• To gain 0.5 pounds per week, consume ${userTDEE + 250} calories per day.\n\n",
      );
      sb.write(
        "• To gain 1 pound per week, consume ${userTDEE + 500} calories per day.",
      );
    } else {
      sb.write(
        "• A healthy weight gain rate is 0.23-0.45 kilograms per week.\n\n",
      );
      sb.write(
        "• To gain 0.23 kilograms per week, consume ${userTDEE + 250} calories per day.\n\n",
      );
      sb.write(
        "• To gain 0.45 kilograms per week, consume ${userTDEE + 500} calories per day.",
      );
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

  @override
  Widget build(BuildContext context) {
    double screenHeight =
        1.sh; // Make widgets the size of the user's personal screen size
    double screenWidth =
        1.sw; // Make widgets the size of the user's personal screen size
    return Scaffold(
      backgroundColor: appColorNotifier.value.withAlpha(128), // Body color
      // Header box
      appBar: AppBar(
        backgroundColor: appColorNotifier.value.withAlpha(64), // Header color
        scrolledUnderElevation:
            0, // So the appBar does not change color when the user scrolls down
        centerTitle: true,
        toolbarHeight: screenHeight * 0.15,
        title: Text(
          "Results",
          style: GoogleFonts.dangrek(
            fontSize: screenWidth * 0.12,
            color: Colors.white,
            shadows: [
              Shadow(
                offset: Offset(4, 4),
                blurRadius: 10,
                color: const Color.fromARGB(255, 0, 0, 0),
              ),
            ],
          ),
        ),
      ),
      body: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                textWithFont(
                  "About BMR",
                  screenWidth,
                  0.1,
                  decoration: TextDecoration.underline,
                ),
                textWithCard(
                  widget.equation == "Mifflin-St Jeor"
                      ? """• The ${widget.equation} equation calculates your Basal Metabolic Rate (BMR), the minimum number of calories your body needs to undergo essential roles for survival.\n\n • Examples include breathing, cell repair, and blood circulation.\n\n • This formula is a revised version of the Harris-Benedict equation."""
                      : """• The revised ${widget.equation} equation calculates your Basal Metabolic Rate (BMR), the minimum number of calories your body needs to undergo essential roles for survival.\n\n • Examples include breathing, cell repair, and blood circulation.\n\n • The original formula was revised in 1984 by Roza and Shizgal to show more accurate results.""",
                  screenWidth,
                  0.05,
                ),
                textWithFont(
                  "Male BMR:",
                  screenWidth,
                  0.1,
                  decoration: TextDecoration.underline,
                  color: const Color.fromARGB(255, 5, 71, 142),
                ),
                textWithCard(
                  widget.equation == "Mifflin-St Jeor"
                      ? widget.units == "MetricDefault" ||
                                widget.units == "Metric"
                            ? "(10 x weight (kg))\n + (6.25 x height (cm))\n - (5 x age (years))\n + 5" //correct Mifflin and Metric
                            : "([10 / 2.205] × weight (lbs)) + ([6.25 x 2.54] × height (inches)) – (5 × age (years))\n + 5" //correct Mifflin and Imperial
                      : widget.units == "MetricDefault" ||
                            widget.units ==
                                "Metric" // Harris and Metric
                      ? "(13.397 x weight (kg))\n + (4.799 x height (cm))\n - (5.677 x age (years))\n + 88.362" //correct Harris and Metric
                      : "([13.397 / 2.205] x weight (lbs))\n + ([4.799 x 2.54] x height (inches))\n - (5.677 x age (years))\n + 88.362",
                  screenWidth,
                  0.05, //correct Harris and Imperial
                ),
                textWithFont(
                  "Female BMR:",
                  screenWidth,
                  0.1,
                  decoration: TextDecoration.underline,
                  color: const Color.fromARGB(255, 210, 4, 138),
                ),
                textWithCard(
                  widget.equation == "Mifflin-St Jeor"
                      ? widget.units == "MetricDefault" ||
                                widget.units == "Metric"
                            ? "(10 x weight (kg))\n + (6.25 x height (cm))\n - (5 x age (years))\n - 161" //correct Mifflin and Metric
                            : "([10 / 2.205] × weight (lbs)) + ([6.25 x 2.54] × height (inches)) – (5 × age (years))\n - 161" //correct Mifflin and Imperial
                      : widget.units == "MetricDefault" ||
                            widget.units ==
                                "Metric" // Harris and Metric
                      ? "(9.247 x weight (kg))\n + (3.098 x height (cm))\n - (4.330 x age (years))\n + 447.593" //correct Harris and Metric
                      : "([9.247 / 2.205] x weight (lbs))\n + ([3.098 x 2.54]\n x height (inches))\n - (4.330 x age (years))\n + 447.593", //correct Harris and Imperial
                  screenWidth,
                  0.05,
                ),
                textWithFont(
                  "About TDEE",
                  screenWidth,
                  0.1,
                  decoration: TextDecoration.underline,
                ),
                textWithCard(
                  "• The amount of calories you burn in a day is known as your Total Daily Energy Expenditure (TDEE).\n\n• Consuming this amount of calories will cause your weight to maintain itself.\n\n TDEE = BMR x Activity Level",
                  screenWidth,
                  0.05,
                ),
                textWithFont(
                  "Activity Level",
                  screenWidth,
                  0.1,
                  decoration: TextDecoration.underline,
                ),
                textWithCard(
                  "• Sedentary = 1.2\n• Light = 1.375\n• Moderate = 1.55\n• Active = 1.725\n• Very Active = 1.9",
                  screenWidth,
                  0.05,
                ),
                textWithFont(
                  "Your BMR",
                  screenWidth,
                  0.1,
                  decoration: TextDecoration.underline,
                  color: Colors.redAccent,
                ),
                textWithCard(
                  widget.equation ==
                          "Mifflin-St Jeor" // MIFFLIN
                      ? widget.units == "MetricDefault" ||
                                widget.units ==
                                    "Metric" // Mifflin and Metric
                            ? widget.sex ==
                                      "Female" // Female and Metric and Mifflin
                                  ? "(10 x ${widget.weight})\n + (6.25 x ${widget.heightCm})\n - (5 x ${widget.age})\n - 161\n = $bmr is your BMR." // Female and Metric and Mifflin
                                  : "(10 x ${widget.weight})\n + (6.25 x ${widget.heightCm})\n - (5 x ${widget.age})\n + 5\n = $bmr is your BMR." // Male and Metric and Mifflin
                            : widget.sex ==
                                  "Female" // Female and Imperial and Mifflin
                            ? "(4.35 x ${widget.weight})\n + (4.7 x ${widget.heightInches})\n - (4.7 x ${widget.age}\n + 655)\n= $bmr is your BMR." // Female and Imperial and Mifflin
                            : "(6.23 x ${widget.weight})\n + (12.7 x ${widget.heightInches})\n - (6.8 x ${widget.age}\n + 66)\n= $bmr is your BMR." // Male and Imperial and Mifflin
                      // HARRIS CASES
                      : widget.units == "MetricDefault" ||
                            widget.units ==
                                "Metric" // Harris and Metric
                      ? widget.sex ==
                                "Female" // Female and Metric and Harris
                            ? "(9.247 x ${widget.weight} (kg))\n + (3.098 x ${widget.heightCm} (cm))\n - (4.330 x ${widget.age} (years))\n + 447.593\n = $bmr is your BMR." // Female and Metric and Harris
                            : "(13.397 x ${widget.weight} (kg))\n + (4.799 x ${widget.heightCm} (cm))\n - (5.677 x ${widget.age} (years))\n + 88.362\n = $bmr is your BMR." //Male and Metric and Harris
                      : widget.sex ==
                            "Female" // Female and Imperial and Mifflin
                      ? "(4.35 x ${widget.weight} (lbs))\n + (4.7 x ${widget.heightInches} (inches))\n - (4.7 x ${widget.age} (years))\n + 655.095\n = $bmr is your BMR." // Female and Imperial and Harris
                      : "(6.23 x ${widget.weight} (lbs))\n + (12.7 x ${widget.heightInches} (inches))\n - (6.8 x ${widget.age} (years))\n + 66.473\n = $bmr is your BMR.", // Male and Imperial and Harris
                  screenWidth,
                  0.05,
                ),
                textWithFont(
                  "Your TDEE",
                  screenWidth,
                  0.1,
                  decoration: TextDecoration.underline,
                  color: Colors.redAccent,
                ),
                textWithCard(
                  "$bmr x ${calculateActivityLevel()} = ${calculateTDEE(bmr, calculateActivityLevel())} is your TDEE.",
                  screenWidth,
                  0.05,
                ),
                textWithFont(
                  "How to ${widget.goal}",
                  screenWidth,
                  0.075,
                  decoration: TextDecoration.underline,
                  color: Colors.redAccent,
                ),
                textWithCard(calculateGoal(), screenWidth, 0.04),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
