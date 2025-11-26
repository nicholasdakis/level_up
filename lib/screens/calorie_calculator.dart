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
  bool weightNeverChanged =
      true; // flag so weight is not converted if the user switches from MetricDefault to Metric

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
                DropdownButton2<String>(
                  dropdownStyleData: DropdownStyleData(
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(
                        255,
                        91,
                        89,
                        89,
                      ).withAlpha(128),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    maxHeight:
                        200, // adds a scrollbar if needed (if larger than 200px)
                  ),
                  style: GoogleFonts.manrope(
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
                  hint: Text(
                    "     Choose your units",
                    style: GoogleFonts.manrope(
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
                      // update the value
                      if (value == currentUnits) {
                        return; // selected the already chosen unit, so do nothing
                      }
                      units = value;
                      currentUnits = units;
                      // USER CHANGES UNITS AFTER ALREADY HAVING A HEIGHT SET
                      if (heightInches != null && value == "Metric") {
                        // initially set an imperial height and switched units to metric
                        heightCm = (heightInches! * 2.54)
                            .round(); // store that imperial height in metric
                        heightInches = null; // reset the imperial value
                      } else if (heightCm != null && value == "Imperial") {
                        // initially set a metric height and switched units to imperial
                        heightInches = (heightCm! / 2.54)
                            .round(); // store that metric height in imperial
                        heightCm = null; // reset the metric value
                      }
                      // USER CHANGES UNITS AFTER ALREADY HAVING A WEIGHT SET
                      if (weight != null && weightNeverChanged) {
                        if (value == "Metric") {
                          // inner if so that the else ifs run even when value is not metric
                          // do nothing (keep the weight the same)
                          weightNeverChanged =
                              false; // true only when user hasn't chosen units and is using the MetricDefault units
                        }
                      } else if (weight != null && value == "Metric") {
                        // initially set an imperial height and switched units to metric
                        weight = weight! / 2.205; // lbs to kg
                        weightController.text = weight!.toStringAsFixed(
                          2,
                        ); // update the controller to visually see the change
                      } else if (weight != null && value == "Imperial") {
                        // initially set a metric height and switched units to imperial
                        weight = weight! * 2.205; // kg to lbs
                        weightController.text = weight!.toStringAsFixed(2);
                      }
                    });
                  },
                ),
                // SELECT CALORIE EQUATION FORMULA
                DropdownButton2<String>(
                  dropdownStyleData: DropdownStyleData(
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(
                        255,
                        91,
                        89,
                        89,
                      ).withAlpha(128),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    maxHeight:
                        200, // adds a scrollbar if needed (if larger than 200px)
                  ),
                  style: GoogleFonts.manrope(
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
                  hint: Text(
                    "Select Calorie Equation",
                    style: GoogleFonts.manrope(
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
                  onChanged: (value) {
                    // when the user selects their sex
                    setState(() {
                      // update the value
                      equation = value;
                    });
                  },
                ),
                // CHOOSE YOUR SEX BUTTON
                DropdownButton2<String>(
                  dropdownStyleData: DropdownStyleData(
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(
                        255,
                        91,
                        89,
                        89,
                      ).withAlpha(128),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    maxHeight:
                        200, // adds a scrollbar if needed (if larger than 200px)
                  ),
                  style: GoogleFonts.manrope(
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
                  hint: Text(
                    "      Choose your sex",
                    style: GoogleFonts.manrope(
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
                  value: sex,
                  items: [
                    DropdownMenuItem(value: 'Male', child: Text('Male')),
                    DropdownMenuItem(value: 'Female', child: Text('Female')),
                  ],
                  onChanged: (value) {
                    // when the user selects their sex
                    setState(() {
                      // update the value
                      sex = value;
                    });
                  },
                ),
                // CHOOSE YOUR AGE BUTTON
                DropdownButton2<int>(
                  dropdownStyleData: DropdownStyleData(
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(
                        255,
                        91,
                        89,
                        89,
                      ).withAlpha(128),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    maxHeight:
                        200, // adds a scrollbar if needed (if larger than 200px)
                  ),
                  style: GoogleFonts.manrope(
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
                  hint: Text(
                    "      Choose your age",
                    style: GoogleFonts.manrope(
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
                  value: age,
                  items: [
                    for (int i = 13; i <= 122; i++)
                      DropdownMenuItem(value: i, child: Text("$i")),
                  ],
                  onChanged: (value) {
                    // when the user selects their age
                    setState(() {
                      // update the value
                      age = value;
                    });
                  },
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
                            ? "  Type your weight in kg" // if
                            : "  Type your weight in lbs", // else
                        contentPadding: EdgeInsets.only(
                          top: 13,
                          left: 6,
                        ), // Move the text down and to the right to look more natural
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
                        weight = double.parse(
                          inputWeight,
                        ); // store the user's input
                      },
                    ),
                  ),
                ),
                // CHOOSE YOUR HEIGHT BUTTON
                DropdownButton2<int>(
                  dropdownStyleData: DropdownStyleData(
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(
                        255,
                        91,
                        89,
                        89,
                      ).withAlpha(128),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    maxHeight:
                        200, // adds a scrollbar if needed (if larger than 200px)
                  ),
                  style: GoogleFonts.manrope(
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
                  hint: Text(
                    "   Choose your height",
                    style: GoogleFonts.manrope(
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
                  value: units == "Metric" || units == "MetricDefault"
                      ? heightCm
                      : heightInches, // only set value to the height unit chosen
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
                          ), // store value entirely in inches but visually show feet and inches
                  ],
                  onChanged: (value) {
                    // when the user selects their height
                    setState(() {
                      // update the value
                      if (units == "Metric" || units == "MetricDefault") {
                        heightCm = value;
                      } else {
                        heightInches = value;
                      }
                    });
                  },
                ),
                // CHOOSE YOUR GOAL BUTTON
                DropdownButton2<String>(
                  dropdownStyleData: DropdownStyleData(
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(
                        255,
                        91,
                        89,
                        89,
                      ).withAlpha(128),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    maxHeight:
                        200, // adds a scrollbar if needed (if larger than 200px)
                  ),
                  style: GoogleFonts.manrope(
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
                  hint: Text(
                    "Choose your calorie goal",
                    style: GoogleFonts.manrope(
                      fontSize: screenWidth * 0.045,
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
                  onChanged: (value) {
                    // when the user selects their goal
                    setState(() {
                      // update the value
                      goal = value;
                    });
                  },
                ),
                // CHOOSE YOUR ACTIVITY LEVEL BUTTON
                DropdownButton2<String>(
                  dropdownStyleData: DropdownStyleData(
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(
                        255,
                        91,
                        89,
                        89,
                      ).withAlpha(128),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    maxHeight:
                        200, // adds a scrollbar if needed (if larger than 200px)
                  ),
                  style: GoogleFonts.manrope(
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
                  hint: Text(
                    "Choose your activity level",
                    style: GoogleFonts.manrope(
                      fontSize: screenWidth * 0.045,
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
                  onChanged: (value) {
                    // when the user selects their activity level
                    setState(() {
                      // update the value
                      activityLevel = value;
                    });
                  },
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
                                  units:
                                      units ??
                                      "0", // default value of 0 if null
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
                                  const start = Offset(
                                    0.0,
                                    1.0,
                                  ); // Start right below the screen
                                  const finish = Offset
                                      .zero; // Stop right at the top of the screen
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
