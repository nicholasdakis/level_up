import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dropdown_button2/dropdown_button2.dart'; // more customizable dropdown button (specifically, always open downward and round borders)
import 'package:flutter/services.dart';
import 'calorie_calculator_buttons/results.dart';
import '../globals.dart';
import '/utility/responsive.dart';
import '/utility/shared_preferences/shared_prefs_async.dart';
import '../user/user_data_manager.dart' show trackTrivialAchievement;

class CalorieCalculator extends StatefulWidget {
  const CalorieCalculator({super.key});

  @override
  State<CalorieCalculator> createState() => _CalorieCalculatorState();
}

class _CalorieCalculatorState extends State<CalorieCalculator> {
  // Prevent memory leaks
  @override
  void dispose() {
    weightController.dispose();
    super.dispose();
  }

  // store information about the user to use in the calculations
  String? units =
      "MetricDefault"; // default value, but uses a different name so the user can still see "Choose your units" text
  String? currentUnits = "MetricDefault";
  String? previousUnits = "MetricDefault";
  String? sex;
  String? goal;
  String? activityLevel;
  String? equation;
  int? age;
  int? heightCm;
  int? heightInches;
  double?
  weight; // One value for either Lbs or Kg -> Converted to a double -> Calculated based on units chosen

  final TextEditingController weightController =
      TextEditingController(); // To allow the user to type in their weight

  bool resultsSnackbarActive =
      false; // flag so only one snackbar shows at a time

  // Centralized cache wrapper for SharedPreferences
  final SharedPrefsService _prefs = SharedPrefsService();

  // Method to store the user's chosen values to their shared preferences
  Future<void> saveCalculatorDataToPrefs() async {
    Map<String, dynamic> data = {
      'units': units,
      'equation': equation,
      'sex': sex,
      'age': age,
      'weight': weight,
      'heightCm': heightCm,
      'heightInches': heightInches,
      'goal': goal,
      'activityLevel': activityLevel,
    };

    // Store to device storage
    await _prefs.setJsonMap(SharedPreferencesKey.calorieCalculatorData, data);
  }

  // Method to load the user's stored calorie calculator data
  Future<Map<String, dynamic>> loadCalculatorDataFromPrefs() async {
    return await _prefs.getJsonMap(SharedPreferencesKey.calorieCalculatorData);
  }

  // Method to update the variables with the stored ones
  void applyCalculatorData(Map<String, dynamic> data) {
    units = data['units'];
    currentUnits = data['units'];
    previousUnits = data['units'];
    equation = data['equation'];
    sex = data['sex'];
    age = data['age'];
    weight = (data['weight'] as num?)?.toDouble();
    heightCm = data['heightCm'];
    heightInches = data['heightInches'];
    goal = data['goal'];
    activityLevel = data['activityLevel'];
  }

  // Method called on initialization that gets the stored data if it exists and updates the class variables with them
  Future<void> restoreCalculatorDataFromPrefs() async {
    Map<String, dynamic> mappedData = await loadCalculatorDataFromPrefs();
    if (mappedData.isNotEmpty) {
      // Update the UI with the stored values
      setState(() {
        applyCalculatorData(mappedData);
        weightController.text = weight?.toString() ?? '';
      });
    }
  }

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
    // Wrapped in a consistent full-width bottom-bordered container to match weight field
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey,
            width: Responsive.scale(context, 0.25),
          ),
        ),
      ),
      child: DropdownButton2<T>(
        isExpanded: true, // fill the full width of the container
        underline:
            SizedBox.shrink(), // remove default underline since container handles it
        dropdownStyleData: DropdownStyleData(
          decoration: BoxDecoration(
            color: appColorNotifier.value.withAlpha(
              128,
            ), // match the app's theme color
            borderRadius: BorderRadius.circular(Responsive.scale(context, 10)),
          ),
          maxHeight: Responsive.height(
            context,
            200,
          ), // adds a scrollbar if needed (if larger than 200px)
        ),
        style: GoogleFonts.manrope(
          fontSize: fontSize ?? Responsive.font(context, 15),
          color: Colors.white,
          shadows: [textDropShadow(context)],
        ),
        hint: Text(
          hint,
          style: GoogleFonts.manrope(
            fontSize: fontSize ?? Responsive.font(context, 15),
            color: Colors.white,
            shadows: [textDropShadow(context)],
          ),
        ),
        value: value,
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    restoreCalculatorDataFromPrefs().catchError((e) {
      debugPrint('Failed to restore calculator data ${e.runtimeType}');
    });
  }

  @override
  Widget build(BuildContext context) {
    // preventing an error by setting the dropdownvalue to null instead of "MetricDefault"
    String? dropdownValue;
    if (units == "MetricDefault") {
      dropdownValue = null;
    } else {
      dropdownValue = units;
    }

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
          centerTitle: true,
          toolbarHeight: Responsive.buttonHeight(context, 120),
          title: createTitle("Calculator", context),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(Responsive.padding(context, 50)),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // CHOOSE YOUR UNITS BUTTON
                  buildDropdown<String>(
                    hint: "Choose your units",
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

                        if (value == "Imperial") {
                          trackTrivialAchievement("switch_imperial");
                        }

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
                    fontSize: Responsive.font(context, 15),
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
                    fontSize: Responsive.font(context, 15),
                  ),
                  // CHOOSE YOUR SEX BUTTON
                  buildDropdown<String>(
                    hint: "Choose your sex",
                    value: sex,
                    items: [
                      DropdownMenuItem(value: 'Male', child: Text('Male')),
                      DropdownMenuItem(value: 'Female', child: Text('Female')),
                    ],
                    onChanged: (value) => setState(() => sex = value),
                    fontSize: Responsive.font(context, 15),
                  ),
                  // CHOOSE YOUR AGE BUTTON
                  buildDropdown<int>(
                    hint: "Choose your age",
                    value: age,
                    items: [
                      for (int i = 13; i <= 122; i++)
                        DropdownMenuItem(value: i, child: Text("$i")),
                    ],
                    onChanged: (value) => setState(() => age = value),
                    fontSize: Responsive.font(context, 15),
                  ),
                  // ENTER YOUR WEIGHT INPUT - full width to match dropdowns
                  Theme(
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
                        TextInputFormatter.withFunction((oldValue, newValue) {
                          // Allow empty
                          if (newValue.text.isEmpty) return newValue;
                          // Check: max 3 digits before decimal, optional decimal, max 3 digits after
                          final valid = RegExp(
                            r'^\d{0,3}(\.\d{0,3})?$',
                          ).hasMatch(newValue.text);
                          return valid
                              ? newValue
                              : oldValue; // reject if invalid, keep old value
                        }),
                      ],
                      style: GoogleFonts.manrope(
                        // style of the input text
                        fontSize: Responsive.font(context, 15),
                        color: Colors.white,
                        shadows: [textDropShadow(context)],
                      ),
                      decoration: InputDecoration(
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.grey,
                            width: Responsive.scale(context, 0.25),
                          ),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.grey,
                            width: Responsive.scale(context, 0.25),
                          ),
                        ),
                        hintText:
                            (units == "MetricDefault" || units == "Metric")
                            ? "Enter your weight in kg"
                            : "Enter your weight in lbs",
                        // Suffix text to specify the weight's units
                        suffixText: weightController.text.isNotEmpty
                            ? (currentUnits == 'Metric' ||
                                      currentUnits == 'MetricDefault'
                                  ? 'kg'
                                  : 'lbs')
                            : null,
                        suffixStyle: TextStyle(color: Colors.white),
                        contentPadding: EdgeInsets.only(
                          top: Responsive.height(context, 13),
                          left: Responsive.width(context, 6),
                        ),
                        hintStyle: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 15),
                          color: Colors.white,
                          shadows: [textDropShadow(context)],
                        ),
                      ),
                      onChanged: (inputWeight) {
                        setState(() {
                          weight = double.tryParse(inputWeight);
                        });
                      },
                    ),
                  ),
                  // CHOOSE YOUR HEIGHT BUTTON
                  buildDropdown<int>(
                    hint: "Choose your height",
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
                    fontSize: Responsive.font(context, 15),
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
                    fontSize: Responsive.font(context, 15),
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
                    fontSize: Responsive.font(context, 15),
                  ),
                  SizedBox(height: Responsive.height(context, 5)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start, // align left
                    children: [
                      Text(
                        "• Sedentary = Low or no exercise.",
                        style: GoogleFonts.roboto(
                          fontSize: Responsive.font(context, 15),
                          color: Colors.white.withAlpha(128),
                          shadows: [textDropShadow(context)],
                        ),
                      ),
                      Text(
                        "• Light = Light exercise 1-3 days per week.",
                        style: GoogleFonts.roboto(
                          fontSize: Responsive.font(context, 15),
                          color: Colors.white.withAlpha(128),
                          shadows: [textDropShadow(context)],
                        ),
                      ),
                      Text(
                        "• Moderate = Moderate exercise 3-5 days per week.",
                        style: GoogleFonts.roboto(
                          fontSize: Responsive.font(context, 15),
                          color: Colors.white.withAlpha(128),
                          shadows: [textDropShadow(context)],
                        ),
                      ),
                      Text(
                        "• Active = Hard exercise 6-7 days per week.",
                        style: GoogleFonts.roboto(
                          fontSize: Responsive.font(context, 15),
                          color: Colors.white.withAlpha(128),
                          shadows: [textDropShadow(context)],
                        ),
                      ),
                      Text(
                        "• Very Active = Very hard exercise or physical job 6-7 days per week.\n",
                        style: GoogleFonts.roboto(
                          fontSize: Responsive.font(context, 15),
                          color: Colors.white.withAlpha(128),
                          shadows: [textDropShadow(context)],
                        ),
                      ),
                      SizedBox(height: Responsive.height(context, 30)),
                      // Results button
                      customButton(
                        "Get Results",
                        24,
                        80,
                        375,
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
                                        SizedBox(
                                          width: Responsive.width(context, 10),
                                        ),
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
                          // NO EARLY RETURN SO THE TAP WAS SUCCESSFUL

                          // Store the results to the user's device
                          saveCalculatorDataToPrefs();

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
      ),
    );
  }
}
