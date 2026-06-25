import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
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
    ageController.dispose();
    heightCmController.dispose();
    heightFtController.dispose();
    heightInController.dispose();
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

  final TextEditingController weightController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController heightCmController = TextEditingController();
  final TextEditingController heightFtController = TextEditingController();
  final TextEditingController heightInController = TextEditingController();

  bool resultsSnackbarActive = false;

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
    } else if (currentUserData != null) {
      setState(() {
        units = currentUserData!.units == 'imperial' ? 'Imperial' : 'Metric';
        currentUnits = units;
        previousUnits = units;
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
        if (label.isNotEmpty) ...[
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
        ],
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
                        HugeIcon(
                          icon: opt.icon!,
                          size: Responsive.scale(context, 15),
                          color: isSelected ? Colors.white : Colors.white54,
                        ),
                        SizedBox(width: Responsive.width(context, 6)),
                      ],
                      Flexible(
                        child: Text(
                          opt.label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 12),
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected ? Colors.white : Colors.white54,
                          ),
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
  // showButtons adds +/- buttons on either side of the slider for fine-tuning by 1 unit
  Widget buildSliderField({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String Function(double) valueLabel,
    required void Function(double) onChanged,
    bool isSet = true,
    bool sliderVisible = true,
    VoidCallback? onReveal,
  }) {
    void decrement() {
      if (value > min) onChanged((value - 1).clamp(min, max));
    }

    void increment() {
      if (value < max) onChanged((value + 1).clamp(min, max));
    }

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
            // Pill showing the current slider value, tappable to reveal slider
            GestureDetector(
              onTap: sliderVisible ? null : onReveal,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.width(context, 10),
                  vertical: Responsive.height(context, 4),
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(15),
                  borderRadius: BorderRadius.circular(
                    Responsive.scale(context, 20),
                  ),
                  border: Border.all(
                    color: Colors.white.withAlpha(40),
                    width: Responsive.scale(context, 1),
                  ),
                ),
                child: Text(
                  isSet ? valueLabel(value) : "Tap to choose",
                  style: GoogleFonts.manrope(
                    fontSize: Responsive.font(context, isSet ? 13 : 11),
                    color: isSet
                        ? lightenColor(appColorNotifier.value, 0.5)
                        : Colors.white38,
                    fontWeight: isSet ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (sliderVisible)
          Row(
            children: [
              _sliderButton(HugeIcons.strokeRoundedRemove01, decrement),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: appColorNotifier.value,
                    inactiveTrackColor: Colors.white.withAlpha(30),
                    thumbColor: appColorNotifier.value,
                    overlayColor: Colors.transparent,
                    trackHeight: Responsive.scale(context, 3),
                    thumbShape: RoundSliderThumbShape(
                      enabledThumbRadius: Responsive.scale(context, 7),
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
              ),
              _sliderButton(HugeIcons.strokeRoundedAdd01, increment),
            ],
          ),
      ],
    );
  }

  // Method to add the + and - buttons to age and height sliders
  Widget _sliderButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: Responsive.scale(context, 28),
        height: Responsive.scale(context, 28),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(18),
          borderRadius: BorderRadius.circular(Responsive.scale(context, 8)),
          border: Border.all(color: Colors.white.withAlpha(30)),
        ),
        child: HugeIcon(
          icon: icon,
          color: Colors.white70,
          size: Responsive.font(context, 14),
        ),
      ),
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
        if (label.isNotEmpty) ...[
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
        ],
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
                    Responsive.scale(context, 12),
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
    FirebaseAnalytics.instance.logScreenView(
      screenName: '/calorie-calculator',
      screenClass: 'CalorieCalculator',
    );
    restoreCalculatorDataFromPrefs().catchError((e) {
      if (kDebugMode) {
        debugPrint('Failed to restore calculator data ${e.runtimeType}');
      }
    });
  }

  Widget _calcField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required String suffix,
    required int maxLength,
    required void Function(String) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
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
        ],
        Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            textSelectionTheme: const TextSelectionThemeData(
              cursorColor: Colors.white,
            ),
          ),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(maxLength),
            ],
            style: GoogleFonts.manrope(
              color: Colors.white,
              fontSize: Responsive.font(context, 16),
            ),
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.manrope(
                color: Colors.white38,
                fontSize: Responsive.font(context, 16),
              ),
              suffix: Text(
                suffix,
                style: GoogleFonts.manrope(
                  color: Colors.white54,
                  fontSize: Responsive.font(context, 14),
                ),
              ),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white54),
              ),
              contentPadding: EdgeInsets.only(
                bottom: Responsive.height(context, 4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine whether in metric or imperial mode. MetricDefault counts as metric
    final bool isMetric = units == "Metric" || units == "MetricDefault";

    return Container(
      decoration: BoxDecoration(gradient: buildThemeGradient()),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                left: Responsive.centeredHorizontalPadding(context, 50),
                right: Responsive.centeredHorizontalPadding(context, 50),
                bottom: Responsive.height(context, 24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.only(
                      top: Responsive.height(context, 8),
                      bottom: Responsive.height(context, 12),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          padding: EdgeInsets.all(
                            Responsive.scale(context, 12),
                          ),
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
                          selectedValue: units == "MetricDefault"
                              ? null
                              : units,
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
                                heightCm = keepValueInRange(
                                  converted,
                                  100,
                                  275,
                                );
                                heightInches = null;
                                heightCmController.text = heightCm.toString();
                                heightFtController.clear();
                                heightInController.clear();
                              } else if (heightCm != null &&
                                  value == "Imperial") {
                                int converted = (heightCm! / 2.54).round();
                                heightInches = keepValueInRange(
                                  converted,
                                  36,
                                  107,
                                );
                                heightCm = null;
                                heightCmController.clear();
                                heightFtController.text = (heightInches! ~/ 12)
                                    .toString();
                                heightInController.text = (heightInches! % 12)
                                    .toString();
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
                          onChanged: (value) =>
                              setState(() => equation = value),
                        ),

                        SizedBox(height: Responsive.height(context, 22)),

                        // CHOOSE YOUR SEX TOGGLE BUTTON
                        buildSegmentedToggle<String>(
                          label: "SEX",
                          selectedValue: sex,
                          options: [
                            (
                              value: 'Male',
                              label: 'Male',
                              icon: HugeIcons.strokeRoundedMaleSymbol,
                            ),
                            (
                              value: 'Female',
                              label: 'Female',
                              icon: HugeIcons.strokeRoundedFemaleSymbol,
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
                        // AGE INPUT
                        _calcField(
                          label: "AGE",
                          controller: ageController,
                          hint: "Enter your age",
                          suffix: "yrs",
                          maxLength: 3,
                          onChanged: (v) =>
                              setState(() => age = int.tryParse(v)),
                        ),

                        SizedBox(height: Responsive.height(context, 16)),

                        // HEIGHT INPUT
                        Text(
                          "HEIGHT",
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 12),
                            color: Colors.white54,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                        ),
                        SizedBox(height: Responsive.height(context, 8)),
                        if (isMetric)
                          _calcField(
                            label: "",
                            controller: heightCmController,
                            hint: "Enter your height",
                            suffix: "cm",
                            maxLength: 3,
                            onChanged: (v) =>
                                setState(() => heightCm = int.tryParse(v)),
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: _calcField(
                                  label: "",
                                  controller: heightFtController,
                                  hint: "Feet",
                                  suffix: "ft",
                                  maxLength: 1,
                                  onChanged: (v) {
                                    final ft = int.tryParse(v) ?? 0;
                                    final inVal =
                                        int.tryParse(heightInController.text) ??
                                        0;
                                    setState(
                                      () => heightInches = ft * 12 + inVal,
                                    );
                                  },
                                ),
                              ),
                              SizedBox(width: Responsive.width(context, 12)),
                              Expanded(
                                child: _calcField(
                                  label: "",
                                  controller: heightInController,
                                  hint: "Inches",
                                  suffix: "in",
                                  maxLength: 2,
                                  onChanged: (v) {
                                    final ft =
                                        int.tryParse(heightFtController.text) ??
                                        0;
                                    final inVal = int.tryParse(v) ?? 0;
                                    setState(
                                      () => heightInches = ft * 12 + inVal,
                                    );
                                  },
                                ),
                              ),
                            ],
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

                  // SECTION: GOAL
                  sectionHeader("GOAL", context),
                  frostedGlassCard(
                    context,
                    padding: EdgeInsets.all(Responsive.scale(context, 20)),
                    child: buildSegmentedToggle<String>(
                      label: "",
                      selectedValue: goal,
                      options: [
                        (
                          value: 'Lose Weight',
                          label: 'Lose Weight',
                          icon: null,
                        ),
                        (
                          value: 'Maintain Weight',
                          label: 'Maintain',
                          icon: null,
                        ),
                        (
                          value: 'Gain Weight',
                          label: 'Gain Weight',
                          icon: null,
                        ),
                      ],
                      onChanged: (value) => setState(() => goal = value),
                    ),
                  ),

                  SizedBox(height: Responsive.height(context, 24)),

                  // SECTION: ACTIVITY LEVEL
                  sectionHeader("ACTIVITY LEVEL", context),
                  frostedGlassCard(
                    context,
                    padding: EdgeInsets.all(Responsive.scale(context, 20)),
                    child: Column(
                      children: [
                        buildSegmentedToggle<String>(
                          label: "",
                          selectedValue: activityLevel,
                          options: [
                            (
                              value: 'Sedentary',
                              label: 'Sedentary',
                              icon: null,
                            ),
                            (value: 'Light', label: 'Light', icon: null),
                            (value: 'Moderate', label: 'Moderate', icon: null),
                          ],
                          onChanged: (value) =>
                              setState(() => activityLevel = value),
                        ),
                        SizedBox(height: Responsive.height(context, 8)),
                        buildSegmentedToggle<String>(
                          label: "",
                          selectedValue: activityLevel,
                          options: [
                            (value: 'Active', label: 'Active', icon: null),
                            (
                              value: 'Very Active',
                              label: 'Very Active',
                              icon: null,
                            ),
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
                          HugeIcons.strokeRoundedSofa01,
                          "Sedentary",
                          "Low or no exercise.",
                        ),
                        _buildActivityRow(
                          HugeIcons.strokeRoundedRunningShoes,
                          "Light",
                          "Light exercise 1–3 days per week.",
                        ),
                        _buildActivityRow(
                          HugeIcons.strokeRoundedBicycle01,
                          "Moderate",
                          "Moderate exercise 3–5 days per week.",
                        ),
                        _buildActivityRow(
                          HugeIcons.strokeRoundedDumbbell01,
                          "Active",
                          "Hard exercise 6–7 days per week.",
                        ),
                        _buildActivityRow(
                          HugeIcons.strokeRoundedFlash,
                          "Very Active",
                          "Very hard exercise or physical job 6–7 days per week.",
                          isLast: true,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: Responsive.height(context, 28)),

                  // RESULTS BUTTON
                  frostedButton(
                    "Get Results",
                    context,
                    color: appColorNotifier.value,
                    onPressed: () {
                      // Validity checks: all fields must be filled
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
                                    HugeIcon(
                                      icon: HugeIcons
                                          .strokeRoundedInformationCircle,
                                      color: Colors.white,
                                      size: Responsive.scale(context, 20),
                                    ),
                                    SizedBox(
                                      width: Responsive.width(context, 10),
                                    ),
                                    const Expanded(child: Text("All fields must be filled.", softWrap: true)),
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

                      // Pass in variables to the same-named variables in Results
                      context.push(
                        '/calorie-calculator/results',
                        extra: {
                          'units': units ?? "0",
                          'goal': goal ?? "0",
                          'activityLevel': activityLevel ?? "0",
                          'equation': equation ?? "0",
                          'age': age ?? 0,
                          'sex': sex ?? "0",
                          'heightCm': heightCm ?? 0,
                          'heightInches': heightInches ?? 0,
                          'weight': weight ?? 0,
                        },
                      );
                    },
                  ),

                  SizedBox(height: Responsive.height(context, 40)),
                ],
              ),
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
          HugeIcon(
            icon: icon,
            size: Responsive.scale(context, 16),
            color: Colors.white38,
          ),
          SizedBox(width: Responsive.width(context, 10)),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: "$level: ",
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
