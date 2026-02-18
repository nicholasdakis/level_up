import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dropdown_button2/dropdown_button2.dart'; // more customizable dropdown button (specifically, always open downward and round borders)
import 'package:flutter/services.dart';
import 'calorie_calculator_buttons/results.dart';
import '../globals.dart';

class CalorieCalculator extends StatefulWidget {
  const CalorieCalculator({super.key});

  @override
  State<CalorieCalculator> createState() => _CalorieCalculatorState();
}

class _CalorieCalculatorState extends State<CalorieCalculator> {
  // store information about the user to use in the calculations
  String? units =
      "MetricDefault"; // default value, but uses a different name so the user can still see "Choose your units" text
  String? currentUnits =
      "MetricDefault"; // store the user's currently chosen units
  String? previousUnits =
      "MetricDefault"; // variable to store the previously chosen units
  String? sex;
  String? goal;
  String? activityLevel;
  String? equation; // which formula / equation to be used for the calculation
  int? age;

  int? heightCm;
  int? heightInches;

  double?
  weight; // One value for either Lbs or Kg -> Converted to a double -> Calculated based on units chosen

  final TextEditingController weightController =
      TextEditingController(); // allow the user to type in their weight
  bool resultsSnackbarActive =
      false; // flag so only one snackbar shows at a time

  // Method to prevent values outside of the dropdown button upon conversion
  int keepValueInRange(int val, int min, int max) {
    if (val < min) return min;
    if (val > max) return max;
    return val;
  }

  /// Helper method to reduce repetition of DropdownButton2 widgets.
  /// Takes the hint text, current value, list of items, and onChanged callback.
  Widget buildDropdown<T>({
    // generic type <T> to use different values for the same method
    required String hint,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    double? fontSize,
  }) {
    return DropdownButton2<T>(
      dropdownStyleData: DropdownStyleData(
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 91, 89, 89).withAlpha(128),
          borderRadius: BorderRadius.circular(10),
        ),
        maxHeight: 200, // adds a scrollbar if needed (if larger than 200px)
      ),
      style: GoogleFonts.manrope(
        fontSize: fontSize ?? 16,
        color: Colors.white,
        shadows: [
          Shadow(offset: Offset(4, 4), blurRadius: 10, color: Colors.black),
        ],
      ),
      hint: Text(
        hint,
        style: GoogleFonts.manrope(
          fontSize: fontSize ?? 16,
          color: Colors.white,
          shadows: [
            Shadow(offset: Offset(4, 4), blurRadius: 10, color: Colors.black),
          ],
        ),
      ),
      value: value,
      items: items,
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight =
        1.sh; // Make widgets the size of the user's personal screen size
    double screenWidth =
        1.sw; // Make widgets the size of the user's personal screen size
    // preventing an error by setting the dropdownvalue to null instead of "MetricDefault"
    String? dropdownValue;
    if (units == "MetricDefault") {
      dropdownValue = null;
    } else {
      dropdownValue = units;
    }

    return Scaffold(
      backgroundColor: appColorNotifier.value.withAlpha(128), // Body color
      // Header box
      appBar: AppBar(
        backgroundColor: appColorNotifier.value.withAlpha(64), // Header color
        centerTitle: true,
        toolbarHeight: screenHeight * 0.15,
        title: createTitle("Calculator", screenWidth),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(50),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // CHOOSE YOUR UNITS BUTTON
                buildDropdown<String>(
                  hint: "     Choose your units",
                  value: dropdownValue,
                  items: [
                    DropdownMenuItem(
                      value: 'Metric',
                      child: Text('Metric (default)'),
                    ),
                    DropdownMenuItem(
                      value: 'Imperial',
                      child: Text('Imperial'),
                    ),
                  ],
                  onChanged: (value) {
                    // when the user selects their units
                    setState(() {
                      if (value == currentUnits) return;

                      previousUnits = currentUnits;
                      currentUnits = value;
                      units = value;

                      // HEIGHT CONVERSION
                      if (heightInches != null && value == "Metric") {
                        int converted = (heightInches! * 2.54).round();
                        heightCm = keepValueInRange(converted, 100, 275);
                        heightInches = null;
                      } else if (heightCm != null && value == "Imperial") {
                        int converted = (heightCm! / 2.54).round();
                        heightInches = keepValueInRange(converted, 36, 107);
                        heightCm = null;
                      }

                      // WEIGHT CONVERSION
                      if (weight != null) {
                        if (previousUnits == "Imperial" &&
                            currentUnits == "Metric") {
                          weight = weight! / 2.205;
                        } else if ((previousUnits == "Metric" &&
                                currentUnits == "Imperial") ||
                            (previousUnits == "MetricDefault" &&
                                currentUnits == "Imperial")) {
                          weight = weight! * 2.205;
                        }
                        weightController.text = weight!.toStringAsFixed(2);
                      }
                    });
                  },
                  fontSize: screenWidth * 0.05,
                ),
                // SELECT CALORIE EQUATION FORMULA
                buildDropdown<String>(
                  hint: "Select Calorie Equation",
                  value: equation,
                  items: [
                    DropdownMenuItem(
                      value: 'Harris-Benedict',
                      child: Text('Harris-Benedict'),
                    ),
                    DropdownMenuItem(
                      value: 'Mifflin-St Jeor',
                      child: Text('Mifflin-St Jeor'),
                    ),
                  ],
                  onChanged: (value) => setState(() => equation = value),
                  fontSize: screenWidth * 0.05,
                ),
                // CHOOSE YOUR SEX BUTTON
                buildDropdown<String>(
                  hint: "      Choose your sex",
                  value: sex,
                  items: [
                    DropdownMenuItem(value: 'Male', child: Text('Male')),
                    DropdownMenuItem(value: 'Female', child: Text('Female')),
                  ],
                  onChanged: (value) => setState(() => sex = value),
                  fontSize: screenWidth * 0.05,
                ),
                // CHOOSE YOUR AGE BUTTON
                buildDropdown<int>(
                  hint: "      Choose your age",
                  value: age,
                  items: [
                    for (int i = 13; i <= 122; i++)
                      DropdownMenuItem(value: i, child: Text("$i")),
                  ],
                  onChanged: (value) => setState(() => age = value),
                  fontSize: screenWidth * 0.05,
                ),
                // ENTER YOUR WEIGHT INPUT
                SizedBox(
                  // make the underline narrower
                  width: screenWidth * 0.65,
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      // Theme to remove the purple when interacting with the input weight
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      textSelectionTheme: TextSelectionThemeData(
                        cursorColor: Colors.white,
                        selectionHandleColor: Colors.white,
                        selectionColor: const Color.fromARGB(
                          255,
                          83,
                          75,
                          75,
                        ).withAlpha(128),
                      ),
                    ),
                    child: TextField(
                      controller: weightController,
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                        signed: false,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*$'),
                        ),
                      ],
                      style: GoogleFonts.manrope(
                        // style of the input text
                        fontSize: screenWidth * 0.05,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            offset: Offset(4, 4),
                            blurRadius: 10,
                            color: const Color.fromARGB(255, 0, 0, 0),
                          ),
                        ],
                      ),
                      decoration: InputDecoration(
                        // style of the hint text
                        enabledBorder: UnderlineInputBorder(
                          // custom border to look consistent with the other prompts
                          borderSide: BorderSide(
                            color: Colors.grey,
                            width: 0.25,
                          ),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          // custom border to look consistent with the other prompts
                          borderSide: BorderSide(
                            color: Colors.grey,
                            width: 0.25,
                          ),
                        ),
                        hintText:
                            (units == "MetricDefault" || units == "Metric")
                            ? "  Enter your weight in kg"
                            : "  Enter your weight in lbs",
                        // Suffix text to specify the weight's units
                        suffixText: weightController.text.isNotEmpty
                            ? (currentUnits == 'Metric' ||
                                      currentUnits == 'MetricDefault'
                                  ? 'kg'
                                  : 'lbs')
                            : null,
                        suffixStyle: TextStyle(color: Colors.white),
                        contentPadding: EdgeInsets.only(top: 13, left: 6),
                        hintStyle: GoogleFonts.manrope(
                          fontSize: screenWidth * 0.05,
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
                      onChanged: (inputWeight) {
                        setState(() {
                          weight = double.tryParse(inputWeight);
                        });
                      },
                    ),
                  ),
                ),
                // CHOOSE YOUR HEIGHT BUTTON
                buildDropdown<int>(
                  hint: "   Choose your height",
                  value: units == "Metric" || units == "MetricDefault"
                      ? heightCm
                      : heightInches,
                  items: [
                    if (units == "Metric" || units == "MetricDefault")
                      for (int i = 100; i <= 275; i++)
                        DropdownMenuItem(value: i, child: Text("$i cm"))
                    else if (units == "Imperial")
                      for (int j = 3; j < 9; j++)
                        for (int k = 0; k < 12; k++)
                          DropdownMenuItem(
                            value: j * 12 + k,
                            child: Text("$j'$k''"),
                          ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      if (units == "Metric" || units == "MetricDefault") {
                        heightCm = value;
                      } else {
                        heightInches = value;
                      }
                    });
                  },
                  fontSize: screenWidth * 0.05,
                ),
                // CHOOSE YOUR GOAL BUTTON
                buildDropdown<String>(
                  hint: "Choose your calorie goal",
                  value: goal,
                  items: [
                    DropdownMenuItem(
                      value: 'Gain Weight',
                      child: Text('Gain Weight'),
                    ),
                    DropdownMenuItem(
                      value: 'Lose Weight',
                      child: Text('Lose Weight'),
                    ),
                    DropdownMenuItem(
                      value: 'Maintain Weight',
                      child: Text('Maintain Weight'),
                    ),
                  ],
                  onChanged: (value) => setState(() => goal = value),
                  fontSize: screenWidth * 0.045,
                ),
                // CHOOSE YOUR ACTIVITY LEVEL BUTTON
                buildDropdown<String>(
                  hint: "Choose your activity level",
                  value: activityLevel,
                  items: [
                    DropdownMenuItem(
                      value: 'Sedentary',
                      child: Text('Sedentary'),
                    ),
                    DropdownMenuItem(value: 'Light', child: Text('Light')),
                    DropdownMenuItem(
                      value: 'Moderate',
                      child: Text('Moderate'),
                    ),
                    DropdownMenuItem(value: 'Active', child: Text('Active')),
                    DropdownMenuItem(
                      value: 'Very Active',
                      child: Text('Very Active'),
                    ),
                  ],
                  onChanged: (value) => setState(() => activityLevel = value),
                  fontSize: screenWidth * 0.045,
                ),
                SizedBox(height: 5.h),
                Wrap(
                  children: [
                    Text(
                      "• Sedentary = Low or no exercise.",
                      style: GoogleFonts.roboto(
                        fontSize: screenWidth * 0.03,
                        color: Colors.white.withAlpha(128),
                        shadows: [
                          Shadow(
                            offset: Offset(4, 4),
                            blurRadius: 10,
                            color: Color.fromARGB(255, 0, 0, 0),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      "• Light = Light exercise 1-3 days per week.",
                      style: GoogleFonts.roboto(
                        fontSize: screenWidth * 0.03,
                        color: Colors.white.withAlpha(128),
                        shadows: [
                          Shadow(
                            offset: Offset(4, 4),
                            blurRadius: 10,
                            color: Color.fromARGB(255, 0, 0, 0),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      "• Moderate = Moderate exercise 3-5 days per week.",
                      style: GoogleFonts.roboto(
                        fontSize: screenWidth * 0.03,
                        color: Colors.white.withAlpha(128),
                        shadows: [
                          Shadow(
                            offset: Offset(4, 4),
                            blurRadius: 10,
                            color: Color.fromARGB(255, 0, 0, 0),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      "• Active = Hard exercise 6-7 days per week.",
                      style: GoogleFonts.roboto(
                        fontSize: screenWidth * 0.03,
                        color: Colors.white.withAlpha(128),
                        shadows: [
                          Shadow(
                            offset: Offset(4, 4),
                            blurRadius: 10,
                            color: Color.fromARGB(255, 0, 0, 0),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      "• Very Active = Very hard exercise or physical job 6-7 days per week.\n",
                      style: GoogleFonts.roboto(
                        fontSize: screenWidth * 0.03,
                        color: Colors.white.withAlpha(128),
                        shadows: [
                          Shadow(
                            offset: Offset(4, 4),
                            blurRadius: 10,
                            color: Color.fromARGB(255, 0, 0, 0),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 30.h),
                    // Results button
                    customButton(
                      "Get Results",
                      screenWidth * 0.1,
                      screenHeight * 0.75,
                      screenWidth,
                      context,
                      onPressed: () {
                        // validity checks
                        if (units == null ||
                            equation == null ||
                            sex == null ||
                            age == null ||
                            weight == null ||
                            (heightCm == null && heightInches == null) ||
                            goal == null ||
                            activityLevel == null) {
                          if (resultsSnackbarActive == true) {
                            return; // a snackBar is already opened
                          }
                          resultsSnackbarActive = true;
                          // Let the user know that not all fields are filled out.
                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(Icons.info, color: Colors.white),
                                      SizedBox(width: 10),
                                      Text("All fields must be filled."),
                                    ],
                                  ),
                                ),
                              )
                              .closed
                              .then((_) {
                                resultsSnackbarActive =
                                    false; // reset the flag (prevent many snackbars from stacking)
                              });
                          return;
                        }
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            // Animation when switching screen
                            pageBuilder:
                                (
                                  context,
                                  animation,
                                  secondaryAnimation,
                                ) => Results(
                                  // pass in variables to the same-named variables in Results
                                  units: units ?? "0",
                                  goal: goal ?? "0",
                                  activityLevel: activityLevel ?? "0",
                                  equation: equation ?? "0",
                                  age: age ?? 0,
                                  sex: sex ?? "0",
                                  heightCm: heightCm ?? 0,
                                  heightInches: heightInches ?? 0,
                                  weight: weight ?? 0,
                                ),
                            transitionDuration: Duration(milliseconds: 400),
                            transitionsBuilder:
                                (
                                  context,
                                  animation,
                                  secondaryAnimation,
                                  child,
                                ) {
                                  const start = Offset(0.0, 1.0);
                                  const finish = Offset.zero;
                                  final tween = Tween(
                                    begin: start,
                                    end: finish,
                                  ).chain(CurveTween(curve: Curves.easeIn));
                                  final offsetAnimation = animation.drive(
                                    tween,
                                  );
                                  return SlideTransition(
                                    position: offsetAnimation,
                                    child: child,
                                  );
                                },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
