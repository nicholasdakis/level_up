import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show
        FilteringTextInputFormatter,
        LengthLimitingTextInputFormatter,
        TextInputFormatter,
        TextEditingValue;
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import '/globals.dart';
import '/utility/responsive.dart';
import '/utility/tdee_calculator.dart';

// Unified onboarding wizard: steps 1-3 in a single dialog with dots + back nav
Future<String?> showOnboardingWizard(BuildContext context) async {
  // Step 1 state is a static list

  // Step 2 state
  final weightGoals = [
    (label: 'Lose Weight', value: 'lose'),
    (label: 'Maintain Weight', value: 'maintain'),
    (label: 'Gain Weight', value: 'gain'),
  ];
  String? selectedGoal;
  final currentWeightController = TextEditingController();
  final targetWeightController = TextEditingController();
  String selectedUnits = 'metric';

  // Step 3 state
  bool isMetricCalorie = true;
  String? selectedSex;
  String? selectedActivity;
  bool rateCustomMode = false;
  String? setupMissingError;
  final ageController = TextEditingController();
  final heightCmController = TextEditingController();
  final heightFtController = TextEditingController();
  final heightInController = TextEditingController();
  final rateController = TextEditingController();

  final activityLevels = [
    (
      value: 'Sedentary',
      label: 'Sedentary',
      sub: 'Desk job, no planned exercise',
    ),
    (
      value: 'Light',
      label: 'Light',
      sub: 'Light walks or casual gym 1-3x/week',
    ),
    (value: 'Moderate', label: 'Moderate', sub: 'Gym or cardio 3-5x/week'),
    (value: 'Active', label: 'Active', sub: 'Hard training most days'),
    (
      value: 'Very Active',
      label: 'Very Active',
      sub: 'Physical job plus daily training',
    ),
  ];

  int currentStep = 0; // 0 = pitch, 1 = goals, 2 = calories, 3 = activation
  const totalSteps = 4;
  String? wizardChoice;

  wizardChoice = await showFrostedDialog<String>(
    context: context,
    dismissible: false,
    child: StatefulBuilder(
      builder: (ctx, setState) {
        final accent = lightenColor(appColorNotifier.value, 0.45);
        final dim = lightenColor(appColorNotifier.value, 0.35);

        // Step 2 derived
        final isMetricGoal = selectedUnits == 'metric';
        final weightUnit = isMetricGoal ? 'kg' : 'lbs';
        final showTarget = selectedGoal == 'lose' || selectedGoal == 'gain';

        // Step 3 derived
        // selectedGoal takes priority so back-navigation reflects the current pick
        final goalType =
            selectedGoal ?? currentUserData?.weightGoalType ?? 'maintain';
        final age = int.tryParse(ageController.text.trim());
        double? heightCm;
        if (isMetricCalorie) {
          heightCm = double.tryParse(heightCmController.text.trim());
        } else {
          final ft = double.tryParse(heightFtController.text.trim());
          final inc = double.tryParse(heightInController.text.trim());
          if (ft != null && inc != null) heightCm = (ft * 12 + inc) * 2.54;
        }
        double? currentWeightKg;
        final today = DateTime.now();
        final dateKey =
            '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
        currentWeightKg = currentUserData?.weightByDate[dateKey];
        // also read from what was just typed on step 2
        if (currentWeightKg == null) {
          final raw = double.tryParse(currentWeightController.text.trim());
          if (raw != null && raw > 0) {
            currentWeightKg = isMetricGoal ? raw : raw * 0.453592;
          }
        }

        final tdee = (selectedSex == null || selectedActivity == null)
            ? null
            : calculateTdee(
                sex: selectedSex!,
                weightKg: currentWeightKg,
                heightCm: heightCm,
                age: age,
                activityLevel: selectedActivity!,
              );
        // clear error once fields are filled
        if (tdee != null && setupMissingError != null) setupMissingError = null;
        // no rate until user explicitly picks one (preset or custom)
        final rateRaw = rateController.text.trim().isEmpty
            ? (goalType == 'maintain' ? 0.0 : null)
            : double.tryParse(rateController.text.trim());
        final rateKg = rateRaw == null
            ? 0.0
            : (isMetricCalorie ? rateRaw : rateRaw / 2.205);
        int? liveCalories;
        if (tdee != null && rateRaw != null) {
          final deficit = (rateKg * 7700 / 7).round();
          liveCalories = goalType == 'lose'
              ? tdee - deficit
              : goalType == 'gain'
              ? tdee + deficit
              : tdee;
        }

        // all writes happen once, right before the dialog closes
        void commitAll() {
          if (selectedGoal != null) {
            currentUserData?.weightGoalType = selectedGoal;
            userManager.updateWeightGoal(weightGoalType: selectedGoal);
          }
          if (selectedUnits != (currentUserData?.units ?? 'metric')) {
            currentUserData?.units = selectedUnits;
            userManager.updateUnits(
              selectedUnits,
              context,
              showFeedback: false,
            );
          }
          final currentWeightRaw = double.tryParse(
            currentWeightController.text.trim(),
          );
          if (currentWeightRaw != null && currentWeightRaw > 0) {
            final kg = isMetricGoal
                ? currentWeightRaw
                : currentWeightRaw * 0.453592;
            currentUserData?.weightByDate[dateKey] = kg;
            userManager.updateWeightLog(dateKey, kg);
          }
          final showTarget = selectedGoal == 'lose' || selectedGoal == 'gain';
          if (showTarget) {
            final targetWeightRaw = double.tryParse(
              targetWeightController.text.trim(),
            );
            if (targetWeightRaw != null && targetWeightRaw > 0) {
              final kg = isMetricGoal
                  ? targetWeightRaw
                  : targetWeightRaw * 0.453592;
              currentUserData?.weightKgGoal = kg;
              userManager.updateWeightGoal(weightKgGoal: kg);
            }
          }
          if (liveCalories != null && liveCalories > 0) {
            currentUserData?.caloriesGoal = liveCalories;
            userManager.updateGoals(caloriesGoal: liveCalories);
          }
          userDataNotifier.notifyListeners();
        }

        Widget buildDots() {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              totalSteps,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutQuart,
                margin: EdgeInsets.symmetric(
                  horizontal: Responsive.width(ctx, 3),
                ),
                width: Responsive.scale(ctx, i == currentStep ? 18 : 6),
                height: Responsive.scale(ctx, 6),
                decoration: BoxDecoration(
                  color: i == currentStep ? accent : accent.withAlpha(60),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          );
        }

        Widget buildStep1() => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/app_logo_circle.png',
              width: Responsive.scale(ctx, 64),
              height: Responsive.scale(ctx, 64),
            ),
            SizedBox(height: Responsive.height(ctx, 16)),
            Text(
              'Welcome to Level Up!',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(ctx, 24),
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            SizedBox(height: Responsive.height(ctx, 6)),
            Text(
              'Your health habits, gamified.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(ctx, 14),
                color: accent,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: Responsive.height(ctx, 20)),
            Divider(color: Colors.white.withAlpha(20), thickness: 1),
            SizedBox(height: Responsive.height(ctx, 16)),
            _featurePill(
              ctx,
              HugeIcons.strokeRoundedRestaurant03,
              'Food, water and weight logging',
              accent,
              dim,
            ),
            SizedBox(height: Responsive.height(ctx, 10)),
            _featurePill(
              ctx,
              HugeIcons.strokeRoundedAnalytics01,
              'Rich nutrition analytics and trends',
              accent,
              dim,
            ),
            SizedBox(height: Responsive.height(ctx, 10)),
            _featurePill(
              ctx,
              HugeIcons.strokeRoundedStar,
              'Daily XP rewards and levels',
              accent,
              dim,
            ),
            SizedBox(height: Responsive.height(ctx, 10)),
            _featurePill(
              ctx,
              HugeIcons.strokeRoundedMedal01,
              'Leaderboard and badges',
              accent,
              dim,
            ),
            SizedBox(height: Responsive.height(ctx, 10)),
            _featurePill(
              ctx,
              HugeIcons.strokeRoundedMapsLocation01,
              'Visit nearby locations for XP points!',
              accent,
              dim,
            ),
            SizedBox(height: Responsive.height(ctx, 10)),
            _featurePill(
              ctx,
              HugeIcons.strokeRoundedSmartPhone01,
              'Cross-device sync',
              accent,
              dim,
            ),
            SizedBox(height: Responsive.height(ctx, 10)),
            _featurePill(
              ctx,
              HugeIcons.strokeRoundedPaintBrush01,
              'Custom theme color',
              accent,
              dim,
            ),
            SizedBox(height: Responsive.height(ctx, 32)),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => setState(() => currentStep = 1),
                style: ElevatedButton.styleFrom(
                  backgroundColor: appColorNotifier.value,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.symmetric(
                    vertical: Responsive.height(ctx, 16),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: accent.withAlpha(80), width: 1),
                  ),
                ),
                child: Text(
                  "Let's get started",
                  style: GoogleFonts.manrope(
                    fontSize: Responsive.font(ctx, 16),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ],
        );

        Widget buildStep2() => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Let's start with weight goals",
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(ctx, 20),
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            SizedBox(height: Responsive.height(ctx, 6)),
            Text(
              'This helps personalize your goals. You can change any of this later in settings.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(ctx, 13),
                color: dim,
              ),
            ),
            SizedBox(height: Responsive.height(ctx, 24)),
            for (final goal in weightGoals) ...[
              GestureDetector(
                onTap: () => setState(() => selectedGoal = goal.value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.width(ctx, 16),
                    vertical: Responsive.height(ctx, 14),
                  ),
                  decoration: BoxDecoration(
                    color: selectedGoal == goal.value
                        ? accent.withAlpha(30)
                        : accent.withAlpha(10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selectedGoal == goal.value
                          ? accent.withAlpha(160)
                          : accent.withAlpha(40),
                      width: selectedGoal == goal.value ? 1.5 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      goal.label,
                      style: GoogleFonts.manrope(
                        fontSize: Responsive.font(ctx, 16),
                        fontWeight: selectedGoal == goal.value
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: selectedGoal == goal.value ? accent : dim,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: Responsive.height(ctx, 8)),
            ],
            SizedBox(
              width: double.infinity,
              child: AnimatedSize(
                duration: const Duration(milliseconds: 480),
                curve: Curves.easeOutQuart,
                child: selectedGoal == null
                    ? const SizedBox.shrink()
                    : AnimatedOpacity(
                        duration: const Duration(milliseconds: 360),
                        opacity: 1.0,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(height: Responsive.height(ctx, 8)),
                            Row(
                              children: [
                                for (final u in ['metric', 'imperial']) ...[
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() {
                                        final toMetric = u == 'metric';
                                        if (toMetric &&
                                            selectedUnits == 'imperial') {
                                          final lbs = double.tryParse(
                                            currentWeightController.text.trim(),
                                          );
                                          if (lbs != null) {
                                            currentWeightController.text =
                                                (lbs * 0.453592)
                                                    .toStringAsFixed(1);
                                          }
                                          final tLbs = double.tryParse(
                                            targetWeightController.text.trim(),
                                          );
                                          if (tLbs != null) {
                                            targetWeightController.text =
                                                (tLbs * 0.453592)
                                                    .toStringAsFixed(1);
                                          }
                                        } else if (!toMetric &&
                                            selectedUnits == 'metric') {
                                          final kg = double.tryParse(
                                            currentWeightController.text.trim(),
                                          );
                                          if (kg != null) {
                                            currentWeightController.text =
                                                (kg / 0.453592).toStringAsFixed(
                                                  1,
                                                );
                                          }
                                          final tKg = double.tryParse(
                                            targetWeightController.text.trim(),
                                          );
                                          if (tKg != null) {
                                            targetWeightController.text =
                                                (tKg / 0.453592)
                                                    .toStringAsFixed(1);
                                          }
                                        }
                                        selectedUnits = u;
                                        isMetricCalorie = u == 'metric';
                                      }),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        padding: EdgeInsets.symmetric(
                                          vertical: Responsive.height(ctx, 10),
                                        ),
                                        decoration: BoxDecoration(
                                          color: selectedUnits == u
                                              ? accent.withAlpha(30)
                                              : accent.withAlpha(10),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: selectedUnits == u
                                                ? accent.withAlpha(160)
                                                : accent.withAlpha(40),
                                            width: selectedUnits == u ? 1.5 : 1,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            u == 'metric' ? 'kg' : 'lbs',
                                            style: GoogleFonts.manrope(
                                              fontSize: Responsive.font(
                                                ctx,
                                                14,
                                              ),
                                              fontWeight: selectedUnits == u
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: selectedUnits == u
                                                  ? accent
                                                  : dim,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (u == 'metric')
                                    SizedBox(width: Responsive.width(ctx, 8)),
                                ],
                              ],
                            ),
                            SizedBox(height: Responsive.height(ctx, 12)),
                            _weightField(
                              ctx,
                              currentWeightController,
                              'Current weight',
                              weightUnit,
                              accent,
                              dim,
                            ),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 480),
                              curve: Curves.easeOutQuart,
                              child: SizedBox(
                                width: double.infinity,
                                child: showTarget
                                    ? Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            height: Responsive.height(ctx, 10),
                                          ),
                                          AnimatedOpacity(
                                            duration: const Duration(
                                              milliseconds: 320,
                                            ),
                                            opacity: showTarget ? 1.0 : 0.0,
                                            child: _weightField(
                                              ctx,
                                              targetWeightController,
                                              'Target weight',
                                              weightUnit,
                                              accent,
                                              dim,
                                            ),
                                          ),
                                        ],
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ),
                            SizedBox(height: Responsive.height(ctx, 20)),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () =>
                                    setState(() => currentStep = 2),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: appColorNotifier.value,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: EdgeInsets.symmetric(
                                    vertical: Responsive.height(ctx, 14),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: accent.withAlpha(80),
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  'Continue',
                                  style: GoogleFonts.manrope(
                                    fontSize: Responsive.font(ctx, 15),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        );

        Widget buildStep3() {
          final isMetric3 = isMetricCalorie;
          final presets = isMetric3
              ? [0.25, 0.5, 0.75, 1.0]
              : [0.5, 1.0, 1.5, 2.0];
          final isCustomActive = rateCustomMode;
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.65,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Set your calorie goal',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: Responsive.font(ctx, 20),
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: Responsive.height(ctx, 6)),
                  Text(
                    "Age, sex, height, and weight let us calculate your metabolic rate so your calorie target is accurate for you.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: Responsive.font(ctx, 13),
                      color: dim,
                    ),
                  ),
                  SizedBox(height: Responsive.height(ctx, 20)),
                  // Units toggle
                  Row(
                    children: [
                      for (final u in ['metric', 'imperial']) ...[
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() {
                              final toMetric = u == 'metric';
                              if (toMetric && !isMetricCalorie) {
                                final ft = double.tryParse(
                                  heightFtController.text.trim(),
                                );
                                final inc = double.tryParse(
                                  heightInController.text.trim(),
                                );
                                if (ft != null || inc != null) {
                                  final totalIn = (ft ?? 0) * 12 + (inc ?? 0);
                                  heightCmController.text = (totalIn * 2.54)
                                      .round()
                                      .toString();
                                  heightFtController.clear();
                                  heightInController.clear();
                                }
                              } else if (!toMetric && isMetricCalorie) {
                                final cm = double.tryParse(
                                  heightCmController.text.trim(),
                                );
                                if (cm != null) {
                                  final totalIn = (cm / 2.54).round();
                                  heightFtController.text = (totalIn ~/ 12)
                                      .toString();
                                  heightInController.text = (totalIn % 12)
                                      .toString();
                                  heightCmController.clear();
                                }
                              }
                              final currentRate = double.tryParse(
                                rateController.text.trim(),
                              );
                              if (currentRate != null) {
                                rateController.text = toMetric
                                    ? (currentRate / 2.205).toStringAsFixed(2)
                                    : (currentRate * 2.205).toStringAsFixed(2);
                              } else {
                                rateController.clear();
                              }
                              isMetricCalorie = toMetric;
                              rateController.clear();
                              rateCustomMode = false;
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: EdgeInsets.symmetric(
                                vertical: Responsive.height(ctx, 10),
                              ),
                              decoration: BoxDecoration(
                                color: (isMetricCalorie == (u == 'metric'))
                                    ? accent.withAlpha(30)
                                    : accent.withAlpha(10),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: (isMetricCalorie == (u == 'metric'))
                                      ? accent.withAlpha(160)
                                      : accent.withAlpha(40),
                                  width: (isMetricCalorie == (u == 'metric'))
                                      ? 1.5
                                      : 1,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  u == 'metric' ? 'kg / cm' : 'lbs / ft',
                                  style: GoogleFonts.manrope(
                                    fontSize: Responsive.font(ctx, 13),
                                    fontWeight:
                                        (isMetricCalorie == (u == 'metric'))
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: (isMetricCalorie == (u == 'metric'))
                                        ? accent
                                        : dim,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (u == 'metric')
                          SizedBox(width: Responsive.width(ctx, 8)),
                      ],
                    ],
                  ),
                  SizedBox(height: Responsive.height(ctx, 12)),
                  // Sex toggle
                  Row(
                    children: [
                      for (final s in ['Male', 'Female']) ...[
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => selectedSex = s),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: EdgeInsets.symmetric(
                                vertical: Responsive.height(ctx, 10),
                              ),
                              decoration: BoxDecoration(
                                color: selectedSex == s
                                    ? accent.withAlpha(30)
                                    : accent.withAlpha(10),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selectedSex == s
                                      ? accent.withAlpha(160)
                                      : accent.withAlpha(40),
                                  width: selectedSex == s ? 1.5 : 1,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  s,
                                  style: GoogleFonts.manrope(
                                    fontSize: Responsive.font(ctx, 14),
                                    fontWeight: selectedSex == s
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: selectedSex == s ? accent : dim,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (s == 'Male')
                          SizedBox(width: Responsive.width(ctx, 8)),
                      ],
                    ],
                  ),
                  SizedBox(height: Responsive.height(ctx, 12)),
                  // Age + height
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _labeledField(
                          ctx,
                          controller: ageController,
                          hint: 'Age',
                          suffix: 'yrs',
                          accent: accent,
                          dim: dim,
                          maxLength: 3,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      SizedBox(width: Responsive.width(ctx, 8)),
                      Expanded(
                        flex: 2,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 440),
                          switchInCurve: Curves.easeOutQuart,
                          switchOutCurve: Curves.easeInQuart,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0.08, 0),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              ),
                          child: isMetric3
                              ? KeyedSubtree(
                                  key: const ValueKey('cm'),
                                  child: _labeledField(
                                    ctx,
                                    controller: heightCmController,
                                    hint: 'Height',
                                    suffix: 'cm',
                                    accent: accent,
                                    dim: dim,
                                    maxLength: 3,
                                    onChanged: (_) => setState(() {}),
                                  ),
                                )
                              : Row(
                                  key: const ValueKey('ftIn'),
                                  children: [
                                    Expanded(
                                      child: _labeledField(
                                        ctx,
                                        controller: heightFtController,
                                        hint: 'ft',
                                        suffix: 'ft',
                                        accent: accent,
                                        dim: dim,
                                        maxLength: 1,
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                    SizedBox(width: Responsive.width(ctx, 6)),
                                    Expanded(
                                      child: _labeledField(
                                        ctx,
                                        controller: heightInController,
                                        hint: 'in',
                                        suffix: 'in',
                                        accent: accent,
                                        dim: dim,
                                        maxLength: 2,
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                  // show weight field if it wasn't entered on step 2
                  if (currentWeightKg == null) ...[
                    SizedBox(height: Responsive.height(ctx, 12)),
                    _weightField(
                      ctx,
                      currentWeightController,
                      isMetricCalorie ? 'Current weight' : 'Current weight',
                      isMetricCalorie ? 'kg' : 'lbs',
                      accent,
                      dim,
                    ),
                  ],
                  SizedBox(height: Responsive.height(ctx, 16)),
                  // Activity
                  Text(
                    'Activity level',
                    style: GoogleFonts.manrope(
                      fontSize: Responsive.font(ctx, 13),
                      color: dim,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: Responsive.height(ctx, 8)),
                  SizedBox(
                    width: double.infinity,
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 380),
                      curve: Curves.easeOutQuart,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        switchInCurve: Curves.easeOutQuart,
                        switchOutCurve: Curves.easeInCubic,
                        layoutBuilder: (current, previous) =>
                            current ?? const SizedBox.shrink(),
                        transitionBuilder: (child, animation) =>
                            FadeTransition(opacity: animation, child: child),
                        child: selectedActivity != null
                            // collapsed summary, tap to reopen
                            ? KeyedSubtree(
                                key: const ValueKey('collapsed'),
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => selectedActivity = null),
                                  child: Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: Responsive.width(ctx, 14),
                                      vertical: Responsive.height(ctx, 10),
                                    ),
                                    decoration: BoxDecoration(
                                      color: accent.withAlpha(28),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: accent.withAlpha(150),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            activityLevels
                                                .firstWhere(
                                                  (l) =>
                                                      l.value ==
                                                      selectedActivity,
                                                )
                                                .label,
                                            style: GoogleFonts.manrope(
                                              fontSize: Responsive.font(
                                                ctx,
                                                14,
                                              ),
                                              fontWeight: FontWeight.w700,
                                              color: accent,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          Icons.check_rounded,
                                          color: accent,
                                          size: Responsive.scale(ctx, 16),
                                        ),
                                        SizedBox(
                                          width: Responsive.width(ctx, 8),
                                        ),
                                        Text(
                                          'change',
                                          style: GoogleFonts.manrope(
                                            fontSize: Responsive.font(ctx, 11),
                                            color: dim,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            // full list
                            : KeyedSubtree(
                                key: const ValueKey('expanded'),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (final level in activityLevels) ...[
                                      GestureDetector(
                                        onTap: () => setState(
                                          () => selectedActivity = level.value,
                                        ),
                                        child: Container(
                                          width: double.infinity,
                                          padding: EdgeInsets.symmetric(
                                            horizontal: Responsive.width(
                                              ctx,
                                              14,
                                            ),
                                            vertical: Responsive.height(ctx, 7),
                                          ),
                                          decoration: BoxDecoration(
                                            color: accent.withAlpha(8),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: accent.withAlpha(35),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      level.label,
                                                      style:
                                                          GoogleFonts.manrope(
                                                            fontSize:
                                                                Responsive.font(
                                                                  ctx,
                                                                  14,
                                                                ),
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            color: dim,
                                                          ),
                                                    ),
                                                    Text(
                                                      level.sub,
                                                      style:
                                                          GoogleFonts.manrope(
                                                            fontSize:
                                                                Responsive.font(
                                                                  ctx,
                                                                  11,
                                                                ),
                                                            color: dim
                                                                .withAlpha(160),
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        height: Responsive.height(ctx, 4),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ),
                  // Rate + calorie result
                  SizedBox(
                    width: double.infinity,
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 480),
                      curve: Curves.easeOutQuart,
                      child: tdee == null
                          ? const SizedBox.shrink()
                          : AnimatedOpacity(
                              duration: const Duration(milliseconds: 360),
                              opacity: 1.0,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(height: Responsive.height(ctx, 16)),
                                  if (goalType != 'maintain') ...[
                                    Text(
                                      'How many ${isMetric3 ? 'kg' : 'lbs'} do you want to ${goalType == 'lose' ? 'lose' : 'gain'} per week?',
                                      style: GoogleFonts.manrope(
                                        fontSize: Responsive.font(ctx, 13),
                                        color: dim,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(height: Responsive.height(ctx, 8)),
                                    Row(
                                      children: [
                                        for (final r in presets) ...[
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: () => setState(() {
                                                rateController.text = r
                                                    .toString();
                                                rateCustomMode = false;
                                              }),
                                              child: AnimatedContainer(
                                                duration: const Duration(
                                                  milliseconds: 180,
                                                ),
                                                padding: EdgeInsets.symmetric(
                                                  vertical: Responsive.height(
                                                    ctx,
                                                    9,
                                                  ),
                                                ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      !isCustomActive &&
                                                          rateController.text ==
                                                              r.toString()
                                                      ? accent.withAlpha(30)
                                                      : accent.withAlpha(8),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color:
                                                        !isCustomActive &&
                                                            rateController
                                                                    .text ==
                                                                r.toString()
                                                        ? accent.withAlpha(160)
                                                        : accent.withAlpha(35),
                                                    width:
                                                        !isCustomActive &&
                                                            rateController
                                                                    .text ==
                                                                r.toString()
                                                        ? 1.5
                                                        : 1,
                                                  ),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    '${r % 1 == 0 ? r.toInt() : r}',
                                                    style: GoogleFonts.manrope(
                                                      fontSize: Responsive.font(
                                                        ctx,
                                                        13,
                                                      ),
                                                      fontWeight:
                                                          !isCustomActive &&
                                                              rateController
                                                                      .text ==
                                                                  r.toString()
                                                          ? FontWeight.w700
                                                          : FontWeight.w500,
                                                      color:
                                                          !isCustomActive &&
                                                              rateController
                                                                      .text ==
                                                                  r.toString()
                                                          ? accent
                                                          : dim,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: Responsive.width(ctx, 6),
                                          ),
                                        ],
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () => setState(() {
                                              rateCustomMode = true;
                                              rateController.clear();
                                            }),
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 180,
                                              ),
                                              padding: EdgeInsets.symmetric(
                                                vertical: Responsive.height(
                                                  ctx,
                                                  9,
                                                ),
                                              ),
                                              decoration: BoxDecoration(
                                                color: isCustomActive
                                                    ? accent.withAlpha(30)
                                                    : accent.withAlpha(8),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: isCustomActive
                                                      ? accent.withAlpha(160)
                                                      : accent.withAlpha(35),
                                                  width: isCustomActive
                                                      ? 1.5
                                                      : 1,
                                                ),
                                              ),
                                              child: Center(
                                                child: HugeIcon(
                                                  icon: HugeIcons
                                                      .strokeRoundedPencilEdit01,
                                                  color: isCustomActive
                                                      ? accent
                                                      : dim,
                                                  size: Responsive.scale(
                                                    ctx,
                                                    14,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(
                                      width: double.infinity,
                                      child: AnimatedSize(
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        curve: Curves.easeOutQuart,
                                        child: isCustomActive
                                            ? Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  SizedBox(
                                                    height: Responsive.height(
                                                      ctx,
                                                      8,
                                                    ),
                                                  ),
                                                  _labeledField(
                                                    ctx,
                                                    controller: rateController,
                                                    hint: isMetric3
                                                        ? 'e.g. 0.3'
                                                        : 'e.g. 0.7',
                                                    suffix: isMetric3
                                                        ? 'kg/wk'
                                                        : 'lbs/wk',
                                                    accent: accent,
                                                    dim: dim,
                                                    maxLength: 7,
                                                    allowDecimal: true,
                                                    maxIntDigits: 1,
                                                    maxDecimalPlaces: 5,
                                                    onChanged: (_) =>
                                                        setState(() {}),
                                                  ),
                                                ],
                                              )
                                            : const SizedBox.shrink(),
                                      ),
                                    ),
                                    SizedBox(
                                      height: Responsive.height(ctx, 12),
                                    ),
                                  ],
                                  if (liveCalories != null)
                                    Container(
                                      width: double.infinity,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: Responsive.width(ctx, 16),
                                        vertical: Responsive.height(ctx, 14),
                                      ),
                                      decoration: BoxDecoration(
                                        color: accent.withAlpha(18),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: accent.withAlpha(60),
                                          width: 1,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            goalType == 'maintain'
                                                ? 'To maintain your weight'
                                                : '~${rateRaw?.toStringAsFixed(2) ?? ''} ${isMetric3 ? 'kg' : 'lbs'}/week',
                                            style: GoogleFonts.manrope(
                                              fontSize: Responsive.font(
                                                ctx,
                                                12,
                                              ),
                                              color: dim,
                                            ),
                                          ),
                                          SizedBox(
                                            height: Responsive.height(ctx, 4),
                                          ),
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                '$liveCalories',
                                                style: GoogleFonts.manrope(
                                                  fontSize: Responsive.font(
                                                    ctx,
                                                    28,
                                                  ),
                                                  fontWeight: FontWeight.w800,
                                                  color: accent,
                                                ),
                                              ),
                                              SizedBox(
                                                width: Responsive.width(ctx, 6),
                                              ),
                                              Flexible(
                                                child: Padding(
                                                  padding: EdgeInsets.only(
                                                    bottom: Responsive.height(
                                                      ctx,
                                                      4,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    'kcal/day',
                                                    style: GoogleFonts.manrope(
                                                      fontSize: Responsive.font(
                                                        ctx,
                                                        13,
                                                      ),
                                                      color: dim,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                    ),
                  ),
                  SizedBox(height: Responsive.height(ctx, 20)),
                  // red is fine here â€” users have not chosen a theme color yet at this point in onboarding
                  if (setupMissingError != null)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: Responsive.height(ctx, 10),
                      ),
                      child: Text(
                        setupMissingError!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(ctx, 12),
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          (tdee != null &&
                              (goalType == 'maintain' ||
                                  rateController.text.isNotEmpty))
                          ? () => setState(() => currentStep = 3)
                          : () {
                              final missing = <String>[];
                              if (selectedSex == null) missing.add('sex');
                              if (age == null) missing.add('age');
                              if (heightCm == null) missing.add('height');
                              if (currentWeightKg == null) {
                                missing.add('current weight');
                              }
                              if (tdee != null &&
                                  goalType != 'maintain' &&
                                  rateController.text.isEmpty) {
                                missing.add('weekly rate');
                              }
                              if (selectedActivity == null) {
                                missing.add('activity level');
                              }
                              setState(() {
                                setupMissingError =
                                    'Still needed: ${missing.join(', ')}.';
                              });
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            (tdee != null &&
                                (goalType == 'maintain' ||
                                    rateController.text.isNotEmpty))
                            ? appColorNotifier.value
                            : Colors.white.withAlpha(20),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(
                          vertical: Responsive.height(ctx, 14),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color:
                                (tdee != null &&
                                    (goalType == 'maintain' ||
                                        rateController.text.isNotEmpty))
                                ? accent.withAlpha(80)
                                : Colors.white.withAlpha(30),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Text(
                        'Set my calorie goal',
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(ctx, 15),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        Widget buildStep4() {
          final name = currentUserData?.username;
          final hasName = name != null && name != currentUserData?.uid;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                hasName ? "You're all set, $name!" : "You're all set!",
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: Responsive.font(ctx, 20),
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: Responsive.height(ctx, 6)),
              Text(
                'Where do you want to start?',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: Responsive.font(ctx, 13),
                  color: dim,
                ),
              ),
              SizedBox(height: Responsive.height(ctx, 20)),
              _activationOption(
                ctx,
                icon: HugeIcons.strokeRoundedRestaurant03,
                title: 'Log my first food',
                subtitle: 'Search, scan a barcode, or enter manually',
                accent: accent,
                dim: dim,
                onTap: () {
                  commitAll();
                  finishOnboarding(context);
                  Navigator.of(context, rootNavigator: true).pop('food');
                },
              ),
              SizedBox(height: Responsive.height(ctx, 10)),
              _activationOption(
                ctx,
                icon: HugeIcons.strokeRoundedHome01,
                title: 'Explore the home dashboard',
                subtitle:
                    'Claim your daily XP, track streaks, log water and weight, and more',
                accent: accent,
                dim: dim,
                onTap: () {
                  finishOnboarding(context);
                  Navigator.of(context, rootNavigator: true).pop('reward');
                },
              ),
              SizedBox(height: Responsive.height(ctx, 10)),
              _activationOption(
                ctx,
                icon: HugeIcons.strokeRoundedSlidersHorizontal,
                title: 'Customize the app',
                subtitle: 'Set your username, units, goals and more',
                accent: accent,
                dim: dim,
                onTap: () {
                  finishOnboarding(context);
                  Navigator.of(context, rootNavigator: true).pop('settings');
                },
              ),
            ],
          );
        }

        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dots indicator
              buildDots(),
              SizedBox(height: Responsive.height(ctx, 20)),
              // AnimatedSize drives the height change, AnimatedOpacity fades content in/out
              AnimatedSize(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutQuart,
                clipBehavior: Clip.none,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  switchInCurve: Curves.easeOutQuart,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (current, previous) =>
                      current ?? const SizedBox.shrink(),
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: SizedBox(
                    key: ValueKey(currentStep),
                    width: double.infinity,
                    child: currentStep == 0
                        ? buildStep1()
                        : currentStep == 1
                        ? buildStep2()
                        : currentStep == 2
                        ? buildStep3()
                        : buildStep4(),
                  ),
                ),
              ),
              // Back button (hidden on step 1) and Skip button (shown on steps 2 and 3)
              if (currentStep > 0) ...[
                SizedBox(height: Responsive.height(ctx, 8)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () => setState(() {
                        // if goals were skipped, back from activation goes to step 2 not 3
                        if (currentStep == 3 && selectedGoal == null) {
                          currentStep = 1;
                        } else {
                          currentStep--;
                        }
                      }),
                      icon: Icon(
                        Icons.arrow_back_ios_rounded,
                        size: Responsive.scale(ctx, 12),
                        color: dim,
                      ),
                      label: Text(
                        'Back',
                        style: GoogleFonts.manrope(
                          color: dim,
                          fontSize: Responsive.font(ctx, 12),
                        ),
                      ),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    ),
                    if (currentStep == 1 || currentStep == 2)
                      TextButton(
                        onPressed: () => setState(() => currentStep = 3),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              currentStep == 1
                                  ? "I'll do this later"
                                  : 'Skip this step',
                              style: GoogleFonts.manrope(
                                color: dim,
                                fontSize: Responsive.font(ctx, 12),
                              ),
                            ),
                            SizedBox(width: Responsive.width(ctx, 4)),
                            Transform.flip(
                              flipX: true,
                              child: Icon(
                                Icons.arrow_back_ios_rounded,
                                size: Responsive.scale(ctx, 12),
                                color: dim,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
  currentWeightController.dispose();
  targetWeightController.dispose();
  ageController.dispose();
  heightCmController.dispose();
  heightFtController.dispose();
  heightInController.dispose();
  rateController.dispose();
  return wizardChoice;
}

Widget _featurePill(
  BuildContext context,
  IconData icon,
  String label,
  Color accent,
  Color dim,
) {
  return Row(
    children: [
      HugeIcon(icon: icon, color: accent, size: Responsive.scale(context, 20)),
      SizedBox(width: Responsive.width(context, 12)),
      Flexible(
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 14),
            color: dim,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ],
  );
}

Widget _labeledField(
  BuildContext context, {
  required TextEditingController controller,
  required String hint,
  required String suffix,
  required Color accent,
  required Color dim,
  ValueChanged<String>? onChanged,
  int maxLength = 6,
  bool allowDecimal = false,
  int maxIntDigits = 4,
  int maxDecimalPlaces = 5,
}) {
  return TextField(
    controller: controller,
    keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
    onChanged: onChanged,
    inputFormatters: [
      if (allowDecimal)
        _DecimalInputFormatter(
          maxIntDigits: maxIntDigits,
          maxDecimalPlaces: maxDecimalPlaces,
        )
      else
        FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(maxLength),
    ],
    style: TextStyle(
      color: Colors.white,
      fontSize: Responsive.font(context, 15),
    ),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white30),
      suffixText: suffix,
      suffixStyle: GoogleFonts.manrope(color: dim),
      filled: true,
      fillColor: Colors.white.withAlpha(12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withAlpha(25)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: accent.withAlpha(180)),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: Responsive.width(context, 14),
        vertical: Responsive.height(context, 13),
      ),
    ),
  );
}

Widget _weightField(
  BuildContext context,
  TextEditingController controller,
  String label,
  String unit,
  Color accent,
  Color dim,
) {
  return TextField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [
      _DecimalInputFormatter(maxIntDigits: 3, maxDecimalPlaces: 2),
      LengthLimitingTextInputFormatter(6),
    ],
    style: TextStyle(
      color: Colors.white,
      fontSize: Responsive.font(context, 15),
    ),
    decoration: InputDecoration(
      hintText: label,
      hintStyle: const TextStyle(color: Colors.white30),
      suffixText: unit,
      suffixStyle: GoogleFonts.manrope(color: dim),
      filled: true,
      fillColor: Colors.white.withAlpha(12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withAlpha(25)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: accent.withAlpha(180)),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: Responsive.width(context, 14),
        vertical: Responsive.height(context, 13),
      ),
    ),
  );
}

// Called at the end of onboarding to assign a random username and mark the user as no longer new
void finishOnboarding(BuildContext context) {
  if (currentUserData?.username == currentUserData?.uid) {
    final name = generateRandomUsername();
    currentUserData?.username = name;
    userDataNotifier.notifyListeners();
    userManager
        .updateUsername(name, context, showFeedback: false)
        .catchError((_) => false);
  }
}

Widget _activationOption(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String subtitle,
  required Color accent,
  required Color dim,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.width(context, 16),
        vertical: Responsive.height(context, 14),
      ),
      decoration: BoxDecoration(
        color: accent.withAlpha(12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withAlpha(50), width: 1),
      ),
      child: Row(
        children: [
          HugeIcon(
            icon: icon,
            color: accent,
            size: Responsive.scale(context, 24),
          ),
          SizedBox(width: Responsive.width(context, 14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: Responsive.font(context, 14),
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.manrope(
                    fontSize: Responsive.font(context, 12),
                    color: dim,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: dim,
            size: Responsive.scale(context, 14),
          ),
        ],
      ),
    ),
  );
}

// Builds a random username in the format AdjectiveNoun#### (e.g. SwiftFalcon4213)
String generateRandomUsername() {
  final rand = Random();
  final adjectives = [
    'Swift',
    'Bold',
    'Iron',
    'Stellar',
    'Nova',
    'Cosmic',
    'Turbo',
    'Epic',
    'Neon',
    'Phantom',
    'Shadow',
    'Blazing',
    'Golden',
    'Thunder',
    'Mighty',
    'Fierce',
    'Sharp',
    'Nimble',
    'Agile',
    'Brave',
    'Peak',
    'Prime',
    'Apex',
    'Rapid',
    'Steel',
    'Solar',
    'Lunar',
    'Atomic',
    'Hyper',
    'Ultra',
    'Blaze',
    'Frost',
    'Storm',
    'Ember',
    'Grit',
    'Radiant',
    'Savage',
    'Sleek',
    'Solid',
    'Crisp',
    'Elite',
    'Vital',
    'Feral',
    'Rough',
    'Keen',
    'Lone',
    'Dark',
    'Wild',
    'Hype',
    'Clutch',
    'Raw',
    'Jade',
    'Onyx',
    'Coral',
    'Azure',
    'Crimson',
    'Silver',
    'Obsidian',
  ];
  final nouns = [
    'Runner',
    'Lifter',
    'Climber',
    'Sprinter',
    'Warrior',
    'Champion',
    'Grinder',
    'Beast',
    'Titan',
    'Legend',
    'Viper',
    'Hawk',
    'Wolf',
    'Falcon',
    'Racer',
    'Surge',
    'Forge',
    'Crest',
    'Pulse',
    'Hustle',
    'Striker',
    'Hunter',
    'Ranger',
    'Knight',
    'Archer',
    'Blade',
    'Phantom',
    'Specter',
    'Rogue',
    'Scout',
    'Drifter',
    'Nomad',
    'Crusher',
    'Slayer',
    'Duelist',
    'Lancer',
    'Brawler',
    'Reaper',
    'Sniper',
    'Vanguard',
    'Condor',
    'Cobra',
    'Jaguar',
    'Lynx',
    'Panther',
    'Raptor',
    'Stallion',
    'Tempest',
    'Cyclone',
    'Inferno',
    'Avalanche',
    'Comet',
    'Eclipse',
  ];
  final adj = adjectives[rand.nextInt(adjectives.length)];
  final noun = nouns[rand.nextInt(nouns.length)];
  final number = rand.nextInt(9999) + 1;
  return '$adj$noun$number';
}

class _DecimalInputFormatter extends TextInputFormatter {
  final int maxIntDigits;
  final int maxDecimalPlaces;

  _DecimalInputFormatter({
    required this.maxIntDigits,
    required this.maxDecimalPlaces,
  });

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    final parts = text.split('.');
    if (parts.length > 2) return oldValue; // more than one dot
    if (parts[0].length > maxIntDigits) return oldValue;
    if (parts.length == 2 && parts[1].length > maxDecimalPlaces) {
      return oldValue;
    }
    if (!RegExp(r'^\d*\.?\d*$').hasMatch(text)) return oldValue;
    return newValue;
  }
}
