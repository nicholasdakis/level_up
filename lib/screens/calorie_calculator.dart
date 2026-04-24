import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'calorie_calculator/results.dart';
import '../globals.dart';
import '/utility/responsive.dart';
import '/utility/shared_preferences/shared_prefs_async.dart';
import '../services/user_data_manager.dart' show trackTrivialAchievement;

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

  // Method to prevent values outside of the valid range upon conversion
  int keepValueInRange(int val, int min, int max) {
    if (val < min) return min;
    if (val > max) return max;
    return val;
  }

  // Helper to build a two-option segmented toggle for binary choices
  Widget buildSegmentedToggle<T>({
    required String label,
    required T? selectedValue,
    required List<({T value, String label, IconData? icon})> options,
    required void Function(T) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 12),
            color: Colors.white54,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        SizedBox(height: Responsive.height(context, 8)),
        Row(
          children: options.map((opt) {
            final isSelected = selectedValue == opt.value;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(opt.value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.only(
                    right: opt != options.last
                        ? Responsive.width(context, 8)
                        : 0,
                  ),
                  padding: EdgeInsets.symmetric(
                    vertical: Responsive.height(context, 12),
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? appColorNotifier.value.withAlpha(200)
                        : Colors.white.withAlpha(18),
                    borderRadius: BorderRadius.circular(
                      Responsive.scale(context, 12),
                    ),
                    border: Border.all(
                      color: isSelected
                          ? appColorNotifier.value
                          : Colors.white.withAlpha(30),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (opt.icon != null) ...[
                        Icon(
                          opt.icon,
                          size: Responsive.scale(context, 15),
                          color: isSelected ? Colors.white : Colors.white54,
                        ),
                        SizedBox(width: Responsive.width(context, 6)),
                      ],
                      Text(
                        opt.label,
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 14),
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected ? Colors.white : Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // Helper to build a slider row with a label and live value readout
  Widget buildSliderField({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String Function(double) valueLabel,
    required void Function(double) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 12),
                color: Colors.white54,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
            // Pill that shows the current slider value next to the label
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.width(context, 10),
                vertical: Responsive.height(context, 4),
              ),
              decoration: BoxDecoration(
                color: lightenColor(appColorNotifier.value.withAlpha(90), 0.2),
                borderRadius: BorderRadius.circular(
                  Responsive.scale(context, 20),
                ),
              ),
              child: Text(
                valueLabel(value),
                style: GoogleFonts.manrope(
                  fontSize: Responsive.font(context, 13),
                  color: lightenColor(appColorNotifier.value, 0.5),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: appColorNotifier.value,
            inactiveTrackColor: Colors.white.withAlpha(30),
            thumbColor: appColorNotifier.value,
            overlayColor: Colors.transparent,
            trackHeight: Responsive.scale(context, 3),
            thumbShape: RoundSliderThumbShape(
              enabledThumbRadius: Responsive.scale(context, 10),
            ),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: null,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  // Helper to build a multi-option pill selector for choices with more than two options
  Widget buildPillSelector<T>({
    required String label,
    required T? selectedValue,
    required List<({T value, String label})> options,
    required void Function(T) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 12),
            color: Colors.white54,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        SizedBox(height: Responsive.height(context, 8)),
        Wrap(
          spacing: Responsive.width(context, 8),
          runSpacing: Responsive.height(context, 8),
          children: options.map((opt) {
            final isSelected = selectedValue == opt.value;
            return GestureDetector(
              onTap: () => onChanged(opt.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.width(context, 16),
                  vertical: Responsive.height(context, 10),
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? appColorNotifier.value.withAlpha(200)
                      : Colors.white.withAlpha(18),
                  borderRadius: BorderRadius.circular(
                    Responsive.scale(context, 30),
                  ),
                  border: Border.all(
                    color: isSelected
                        ? appColorNotifier.value
                        : Colors.white.withAlpha(30),
                    width: 1,
                  ),
                ),
                child: Text(
                  opt.label,
                  style: GoogleFonts.manrope(
                    fontSize: Responsive.font(context, 13),
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.white54,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
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
    // Determine whether in metric or imperial mode. MetricDefault counts as metric
    final bool isMetric = units == "Metric" || units == "MetricDefault";

    // Safe fallbacks so sliders always have a valid position before the user picks a value
    final double ageSliderValue = (age ?? 25).toDouble().clamp(13, 100);
    final double heightSliderValue = isMetric
        ? (heightCm ?? 170).toDouble().clamp(100, 275)
        : (heightInches ?? 68).toDouble().clamp(36, 107);

    return Container(
      decoration: BoxDecoration(gradient: buildThemeGradient()),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // Header box
        appBar: AppBar(
          backgroundColor: darkenColor(appColorNotifier.value, 0.025),
          centerTitle: true,
          toolbarHeight: Responsive.height(context, 100),
          title: createTitle("Calorie Calculator", context),
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
                // SECTION: BASIC INFO
                sectionHeader("BASIC INFO", context),
                frostedGlassCard(
                  context,
                  padding: EdgeInsets.all(Responsive.scale(context, 20)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // CHOOSE YOUR UNITS TOGGLE BUTTON
                      buildSegmentedToggle<String>(
                        label: "UNITS",
                        selectedValue: units == "MetricDefault" ? null : units,
                        options: [
                          (
                            value: 'Metric',
                            label: 'Metric (kg / cm)',
                            icon: null,
                          ),
                          (
                            value: 'Imperial',
                            label: 'Imperial (lbs / in)',
                            icon: null,
                          ),
                        ],
                        onChanged: (value) {
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
                            } else if (heightCm != null &&
                                value == "Imperial") {
                              int converted = (heightCm! / 2.54).round();
                              heightInches = keepValueInRange(
                                converted,
                                36,
                                107,
                              );
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
                              weightController.text = weight!.toStringAsFixed(
                                2,
                              );
                            }
                          });
                        },
                      ),

                      SizedBox(height: Responsive.height(context, 22)),

                      // SELECT CALORIE EQUATION FORMULA
                      buildSegmentedToggle<String>(
                        label: "EQUATION",
                        selectedValue: equation,
                        options: [
                          (
                            value: 'Harris-Benedict',
                            label: 'Harris-Benedict',
                            icon: null,
                          ),
                          (
                            value: 'Mifflin-St Jeor',
                            label: 'Mifflin-St Jeor',
                            icon: null,
                          ),
                        ],
                        onChanged: (value) => setState(() => equation = value),
                      ),

                      SizedBox(height: Responsive.height(context, 22)),

                      // CHOOSE YOUR SEX TOGGLE BUTTON
                      buildSegmentedToggle<String>(
                        label: "SEX",
                        selectedValue: sex,
                        options: [
                          (value: 'Male', label: 'Male', icon: Icons.male),
                          (
                            value: 'Female',
                            label: 'Female',
                            icon: Icons.female,
                          ),
                        ],
                        onChanged: (value) => setState(() => sex = value),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: Responsive.height(context, 24)),

                // SECTION: MEASUREMENTS
                sectionHeader("MEASUREMENTS", context),
                frostedGlassCard(
                  context,
                  padding: EdgeInsets.all(Responsive.scale(context, 20)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // CHOOSE YOUR AGE SLIDER
                      buildSliderField(
                        label: "AGE",
                        value: ageSliderValue,
                        min: 13,
                        max: 100,
                        divisions: 87,
                        valueLabel: (v) => "${v.round()} yrs",
                        onChanged: (value) =>
                            setState(() => age = value.round()),
                      ),

                      SizedBox(height: Responsive.height(context, 8)),

                      // CHOOSE YOUR HEIGHT SLIDER, range and display format adjusts based on units
                      buildSliderField(
                        label: "HEIGHT",
                        value: heightSliderValue,
                        min: isMetric ? 100 : 36,
                        max: isMetric ? 275 : 107,
                        divisions: isMetric ? 175 : 71,
                        valueLabel: (v) {
                          if (isMetric) return "${v.round()} cm";
                          // Convert total inches to feet and inches for display
                          final totalInches = v.round();
                          final feet = totalInches ~/ 12;
                          final inches = totalInches % 12;
                          return "$feet'$inches\"";
                        },
                        onChanged: (value) {
                          setState(() {
                            if (isMetric) {
                              heightCm = value.round();
                            } else {
                              heightInches = value.round();
                            }
                          });
                        },
                      ),

                      SizedBox(height: Responsive.height(context, 16)),

                      // ENTER YOUR WEIGHT INPUT, full width, hint and suffix update based on units
                      Text(
                        "WEIGHT",
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 12),
                          color: Colors.white54,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                      SizedBox(height: Responsive.height(context, 8)),
                      Theme(
                        data: Theme.of(context).copyWith(
                          // Remove the purple highlight when interacting with the weight input
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
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: false,
                          ),
                          inputFormatters: [
                            TextInputFormatter.withFunction((
                              oldValue,
                              newValue,
                            ) {
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
                            fontSize: Responsive.font(context, 15),
                            color: Colors.white,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white.withAlpha(12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                Responsive.scale(context, 12),
                              ),
                              borderSide: BorderSide.none,
                            ),
                            hintText: isMetric
                                ? "Enter your weight in kg"
                                : "Enter your weight in lbs",
                            // Suffix text to specify the weight's units
                            suffixText: weightController.text.isNotEmpty
                                ? (currentUnits == 'Metric' ||
                                          currentUnits == 'MetricDefault'
                                      ? 'kg'
                                      : 'lbs')
                                : null,
                            suffixStyle: GoogleFonts.manrope(
                              color: Colors.white70,
                              fontSize: Responsive.font(context, 14),
                            ),
                            hintStyle: GoogleFonts.manrope(
                              fontSize: Responsive.font(context, 14),
                              color: Colors.white38,
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: Responsive.width(context, 16),
                              vertical: Responsive.height(context, 14),
                            ),
                          ),
                          onChanged: (inputWeight) {
                            setState(() {
                              weight = double.tryParse(inputWeight);
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: Responsive.height(context, 24)),

                // SECTION: GOAL AND ACTIVITY
                sectionHeader("GOAL & ACTIVITY", context),
                frostedGlassCard(
                  context,
                  padding: EdgeInsets.all(Responsive.scale(context, 20)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // CHOOSE YOUR CALORIE GOAL
                      buildPillSelector<String>(
                        label: "CALORIE GOAL",
                        selectedValue: goal,
                        options: [
                          (value: 'Lose Weight', label: 'Lose Weight'),
                          (value: 'Maintain Weight', label: 'Maintain Weight'),
                          (value: 'Gain Weight', label: 'Gain Weight'),
                        ],
                        onChanged: (value) => setState(() => goal = value),
                      ),

                      SizedBox(height: Responsive.height(context, 22)),

                      // CHOOSE YOUR ACTIVITY LEVEL
                      buildPillSelector<String>(
                        label: "ACTIVITY LEVEL",
                        selectedValue: activityLevel,
                        options: [
                          (value: 'Sedentary', label: 'Sedentary'),
                          (value: 'Light', label: 'Light'),
                          (value: 'Moderate', label: 'Moderate'),
                          (value: 'Active', label: 'Active'),
                          (value: 'Very Active', label: 'Very Active'),
                        ],
                        onChanged: (value) =>
                            setState(() => activityLevel = value),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: Responsive.height(context, 16)),

                // Activity level descriptions so the user knows what each option means
                sectionHeader("ACTIVITY INFO", context),
                frostedGlassCard(
                  context,
                  padding: EdgeInsets.all(Responsive.scale(context, 16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildActivityRow(
                        Icons.weekend_outlined,
                        "Sedentary",
                        "Low or no exercise.",
                      ),
                      _buildActivityRow(
                        Icons.directions_walk,
                        "Light",
                        "Light exercise 1–3 days per week.",
                      ),
                      _buildActivityRow(
                        Icons.directions_bike,
                        "Moderate",
                        "Moderate exercise 3–5 days per week.",
                      ),
                      _buildActivityRow(
                        Icons.fitness_center,
                        "Active",
                        "Hard exercise 6–7 days per week.",
                      ),
                      _buildActivityRow(
                        Icons.bolt,
                        "Very Active",
                        "Very hard exercise or physical job 6–7 days per week.",
                        isLast: true,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: Responsive.height(context, 28)),

                // RESULTS BUTTON
                SizedBox(
                  height: Responsive.height(context, 54),
                  child: ElevatedButton(
                    onPressed: () {
                      // Validity checks — all fields must be filled
                      if (units == null ||
                          equation == null ||
                          sex == null ||
                          age == null ||
                          weight == null ||
                          (heightCm == null && heightInches == null) ||
                          goal == null ||
                          activityLevel == null) {
                        if (resultsSnackbarActive == true) {
                          return; // a snackbar is already opened
                        }
                        resultsSnackbarActive = true;
                        // Let the user know that not all fields are filled out
                        ScaffoldMessenger.of(context)
                            .showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.info, color: Colors.white),
                                    SizedBox(
                                      width: Responsive.width(context, 10),
                                    ),
                                    const Text("All fields must be filled."),
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
                                // Pass in variables to the same-named variables in Results
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
                          transitionDuration: const Duration(milliseconds: 400),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                                const start = Offset(0.0, 1.0);
                                const finish = Offset.zero;
                                final tween = Tween(
                                  begin: start,
                                  end: finish,
                                ).chain(CurveTween(curve: Curves.easeIn));
                                final offsetAnimation = animation.drive(tween);
                                return SlideTransition(
                                  position: offsetAnimation,
                                  child: child,
                                );
                              },
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: appColorNotifier.value,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          Responsive.scale(context, 14),
                        ),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      "Get Results",
                      style: GoogleFonts.manrope(
                        fontSize: Responsive.font(context, 16),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: Responsive.height(context, 40)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Builds a single activity level description row with an icon, bold label, and description
  Widget _buildActivityRow(
    IconData icon,
    String level,
    String description, {
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: isLast ? 0 : Responsive.height(context, 10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: Responsive.scale(context, 16),
            color: Colors.white38,
          ),
          SizedBox(width: Responsive.width(context, 10)),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: "$level — ",
                    style: GoogleFonts.manrope(
                      fontSize: Responsive.font(context, 13),
                      color: Colors.white60,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: description,
                    style: GoogleFonts.manrope(
                      fontSize: Responsive.font(context, 13),
                      color: Colors.white38,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
