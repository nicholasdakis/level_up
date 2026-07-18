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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '/globals.dart';
import '/providers/user_data_provider.dart';
import '/providers/weight_logs_provider.dart';
import '/utility/responsive.dart';
import '/utility/tdee_calculator.dart';

// Unified onboarding wizard: steps 1-3 in a single dialog with dots + back nav
Future<String?> showOnboardingWizard(
  BuildContext context,
  Color appColor,
  WidgetRef ref,
) async {
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

  bool step0Animated = false;
  List<String> randomSuggestions = [];
  String? selectedSuggestion;
  String? step2MissingError;
  String? step3MissingError;
  int currentStep =
      0; // 0 = pitch, 1 = goals, 2 = body stats, 3 = activity + calorie goal, 4 = macro profile, 5 = username, 6 = activation
  const totalSteps = 7;
  final usernameController = TextEditingController();
  String? usernameError;
  // pending macro/micro selections, written to db only in commitAll
  int? pendingProtein;
  int? pendingCarbs;
  int? pendingFat;
  int? pendingFiber;
  int? pendingSugar;
  int? pendingSodium;
  String? wizardChoice;

  FirebaseAnalytics.instance.logEvent(name: 'onboarding_started');

  wizardChoice = await showFrostedDialog<String>(
    context: context,
    appColor: appColor,
    dismissible: false,
    maxWidth: 460,
    barrierColor: const Color(0xD9000000),
    borderColor: const Color(0x883B82F6),
    backgroundColor: const Color(0x2A3B82F6),
    child: StatefulBuilder(
      builder: (ctx, setState) {
        final accent = Colors.white;
        final dim = Colors.white.withAlpha(180);

        // Step 2 derived
        final isMetricGoal = selectedUnits == 'metric';
        final weightUnit = isMetricGoal ? 'kg' : 'lbs';
        final showTarget = selectedGoal == 'lose' || selectedGoal == 'gain';

        // Step 3 derived
        // selectedGoal takes priority so back-navigation reflects the current pick
        final goalType =
            selectedGoal ??
            ref.read(userDataProvider).value?.weightGoalType ??
            'maintain';
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
        currentWeightKg = ref.read(weightLogsProvider).value?[dateKey];
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
          final currentWeightRaw = double.tryParse(
            currentWeightController.text.trim(),
          );
          final currentWeightKg =
              currentWeightRaw != null && currentWeightRaw > 0
              ? (isMetricGoal ? currentWeightRaw : currentWeightRaw * 0.453592)
              : null;
          final targetWeightRaw =
              (selectedGoal == 'lose' || selectedGoal == 'gain')
              ? double.tryParse(targetWeightController.text.trim())
              : null;
          final weightKgGoal = targetWeightRaw != null && targetWeightRaw > 0
              ? (isMetricGoal ? targetWeightRaw : targetWeightRaw * 0.453592)
              : null;
          ref
              .read(userDataProvider.notifier)
              .commitOnboarding(
                context: context,
                currentUnits:
                    ref.read(userDataProvider).value?.units ?? 'metric',
                weightGoalType: selectedGoal,
                selectedUnits: selectedUnits,
                currentWeightKg: currentWeightKg,
                weightKgGoal: weightKgGoal,
                caloriesGoal: liveCalories,
                proteinGoal: pendingProtein,
                carbsGoal: pendingCarbs,
                fatGoal: pendingFat,
                fiberGoal: pendingFiber,
                sugarGoal: pendingSugar,
                sodiumGoal: pendingSodium,
                dateKey: dateKey,
              );
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

        Widget buildStep1() {
          final shouldAnimate = !step0Animated;
          if (!step0Animated) step0Animated = true;
          return Column(
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
              SizedBox(height: Responsive.height(ctx, 20)),
              _featurePill(
                ctx,
                HugeIcons.strokeRoundedDumbbell01,
                'Workout tracking & PRs',
                accent,
                dim,
                index: 0,
                animate: shouldAnimate,
              ),
              SizedBox(height: Responsive.height(ctx, 14)),
              _featurePill(
                ctx,
                HugeIcons.strokeRoundedRestaurant03,
                'Log food, water & weight',
                accent,
                dim,
                index: 1,
                animate: shouldAnimate,
              ),
              SizedBox(height: Responsive.height(ctx, 14)),
              _featurePill(
                ctx,
                HugeIcons.strokeRoundedStar,
                'XP & leveling',
                accent,
                dim,
                index: 2,
                animate: shouldAnimate,
              ),
              SizedBox(height: Responsive.height(ctx, 14)),
              _featurePill(
                ctx,
                HugeIcons.strokeRoundedAnalytics01,
                'Calorie & macro trends',
                accent,
                dim,
                index: 3,
                animate: shouldAnimate,
              ),
              SizedBox(height: Responsive.height(ctx, 14)),
              _featurePill(
                ctx,
                HugeIcons.strokeRoundedMedal01,
                'Leaderboard & badges',
                accent,
                dim,
                index: 4,
                animate: shouldAnimate,
              ),
              SizedBox(height: Responsive.height(ctx, 14)),
              _featurePill(
                ctx,
                HugeIcons.strokeRoundedMapsLocation01,
                'Nearby location check-ins',
                accent,
                dim,
                index: 5,
                animate: shouldAnimate,
              ),
              SizedBox(height: Responsive.height(ctx, 16)),
              GestureDetector(
                onTap: () {
                  FirebaseAnalytics.instance.logEvent(
                    name: 'onboarding_step_viewed',
                    parameters: {'step': 1},
                  );
                  setState(() => currentStep = 1);
                },
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    vertical: Responsive.height(ctx, 17),
                    horizontal: Responsive.width(ctx, 24),
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      Responsive.scale(ctx, 14),
                    ),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF22D3EE),
                        Color(0xFF3B82F6),
                        Color(0xFF1E40AF),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    border: Border.all(
                      color: const Color(0xFF3B82F6),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    "Let's get started",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: Responsive.font(ctx, 16),
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        Widget buildStep2() => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Let's set up your profile!",
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
                color: Colors.white.withAlpha(180),
              ),
            ),
            SizedBox(height: Responsive.height(ctx, 24)),
            for (final goal in weightGoals) ...[
              GestureDetector(
                onTap: () => setState(() {
                  selectedGoal = goal.value;
                  step2MissingError = null;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.width(ctx, 24),
                    vertical: Responsive.height(ctx, 17),
                  ),
                  decoration: BoxDecoration(
                    gradient: selectedGoal == goal.value
                        ? const LinearGradient(
                            colors: [
                              Color(0xFF22D3EE),
                              Color(0xFF3B82F6),
                              Color(0xFF1E40AF),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          )
                        : null,
                    color: selectedGoal == goal.value
                        ? null
                        : const Color(0x223B82F6),
                    borderRadius: BorderRadius.circular(
                      Responsive.scale(ctx, 14),
                    ),
                    border: Border.all(
                      color: selectedGoal == goal.value
                          ? const Color(0xFF3B82F6)
                          : const Color(0xCC3B82F6),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      goal.label,
                      style: GoogleFonts.manrope(
                        fontSize: Responsive.font(ctx, 16),
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
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
                            Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                padding: EdgeInsets.all(
                                  Responsive.scale(ctx, 3),
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0x1A3B82F6),
                                  borderRadius: BorderRadius.circular(
                                    Responsive.scale(ctx, 20),
                                  ),
                                  border: Border.all(
                                    color: const Color(0x443B82F6),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (final u in ['metric', 'imperial'])
                                      GestureDetector(
                                        onTap: () => setState(() {
                                          final toMetric = u == 'metric';
                                          if (toMetric &&
                                              selectedUnits == 'imperial') {
                                            final lbs = double.tryParse(
                                              currentWeightController.text
                                                  .trim(),
                                            );
                                            if (lbs != null) {
                                              currentWeightController.text =
                                                  (lbs * 0.453592)
                                                      .toStringAsFixed(1);
                                            }
                                            final tLbs = double.tryParse(
                                              targetWeightController.text
                                                  .trim(),
                                            );
                                            if (tLbs != null) {
                                              targetWeightController.text =
                                                  (tLbs * 0.453592)
                                                      .toStringAsFixed(1);
                                            }
                                          } else if (!toMetric &&
                                              selectedUnits == 'metric') {
                                            final kg = double.tryParse(
                                              currentWeightController.text
                                                  .trim(),
                                            );
                                            if (kg != null) {
                                              currentWeightController.text =
                                                  (kg / 0.453592)
                                                      .toStringAsFixed(1);
                                            }
                                            final tKg = double.tryParse(
                                              targetWeightController.text
                                                  .trim(),
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
                                            horizontal: Responsive.width(
                                              ctx,
                                              12,
                                            ),
                                            vertical: Responsive.height(ctx, 6),
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: selectedUnits == u
                                                ? const LinearGradient(
                                                    colors: [
                                                      Color(0xFF22D3EE),
                                                      Color(0xFF3B82F6),
                                                      Color(0xFF1E40AF),
                                                    ],
                                                    begin: Alignment.centerLeft,
                                                    end: Alignment.centerRight,
                                                  )
                                                : null,
                                            borderRadius: BorderRadius.circular(
                                              Responsive.scale(ctx, 16),
                                            ),
                                          ),
                                          child: Text(
                                            u == 'metric' ? 'kg' : 'lbs',
                                            style: GoogleFonts.manrope(
                                              fontSize: Responsive.font(
                                                ctx,
                                                12,
                                              ),
                                              fontWeight: selectedUnits == u
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: selectedUnits == u
                                                  ? Colors.white
                                                  : dim,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: Responsive.height(ctx, 12)),
                            _weightField(
                              ctx,
                              currentWeightController,
                              'Current weight',
                              weightUnit,
                              accent,
                              dim,
                              onChanged: (_) => setState(() {}),
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
                                              onChanged: (_) => setState(() {}),
                                            ),
                                          ),
                                        ],
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ),
                            SizedBox(height: Responsive.height(ctx, 20)),
                            GestureDetector(
                              onTap: () {
                                final missing = <String>[];
                                if (currentWeightController.text
                                    .trim()
                                    .isEmpty) {
                                  missing.add('current weight');
                                }
                                if (showTarget &&
                                    targetWeightController.text
                                        .trim()
                                        .isEmpty) {
                                  missing.add('target weight');
                                }
                                if (missing.isNotEmpty) {
                                  setState(
                                    () => step2MissingError =
                                        'Still needed: ${missing.join(', ')}.',
                                  );
                                  return;
                                }
                                FirebaseAnalytics.instance.logEvent(
                                  name: 'onboarding_step_viewed',
                                  parameters: {'step': 2},
                                );
                                setState(() {
                                  step2MissingError = null;
                                  currentStep = 2;
                                });
                              },
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: double.infinity,
                                    padding: EdgeInsets.symmetric(
                                      vertical: Responsive.height(ctx, 17),
                                      horizontal: Responsive.width(ctx, 24),
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(
                                        Responsive.scale(ctx, 14),
                                      ),
                                      gradient:
                                          (selectedGoal != null &&
                                              currentWeightController.text
                                                  .trim()
                                                  .isNotEmpty &&
                                              (!showTarget ||
                                                  targetWeightController.text
                                                      .trim()
                                                      .isNotEmpty))
                                          ? const LinearGradient(
                                              colors: [
                                                Color(0xFF22D3EE),
                                                Color(0xFF3B82F6),
                                                Color(0xFF1E40AF),
                                              ],
                                              begin: Alignment.centerLeft,
                                              end: Alignment.centerRight,
                                            )
                                          : const LinearGradient(
                                              colors: [
                                                Color(0xFFFF6B6B),
                                                Color(0xFFEF4444),
                                                Color(0xFFB91C1C),
                                              ],
                                              begin: Alignment.centerLeft,
                                              end: Alignment.centerRight,
                                            ),
                                      border: Border.all(
                                        color:
                                            (selectedGoal != null &&
                                                currentWeightController.text
                                                    .trim()
                                                    .isNotEmpty &&
                                                (!showTarget ||
                                                    targetWeightController.text
                                                        .trim()
                                                        .isNotEmpty))
                                            ? const Color(0xFF3B82F6)
                                            : const Color(0xFFEF4444),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Text(
                                      'Continue',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.manrope(
                                        fontSize: Responsive.font(ctx, 15),
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  if (step2MissingError != null)
                                    Padding(
                                      padding: EdgeInsets.only(
                                        top: Responsive.height(ctx, 8),
                                      ),
                                      child: Text(
                                        step2MissingError!,
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.manrope(
                                          fontSize: Responsive.font(ctx, 12),
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                    ),
                                ],
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
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.65,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Tell us about yourself',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: Responsive.font(ctx, 20),
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: Responsive.height(ctx, 6)),
                  Text(
                    'This lets us calculate your calorie target accurately. You can skip this and set goals manually later.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: Responsive.font(ctx, 13),
                      color: Colors.white.withAlpha(180),
                    ),
                  ),
                  SizedBox(height: Responsive.height(ctx, 20)),
                  // Units toggle
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: EdgeInsets.all(Responsive.scale(ctx, 3)),
                      decoration: BoxDecoration(
                        color: const Color(0x1A3B82F6),
                        borderRadius: BorderRadius.circular(
                          Responsive.scale(ctx, 20),
                        ),
                        border: Border.all(
                          color: const Color(0x443B82F6),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final u in ['metric', 'imperial']) ...[
                            GestureDetector(
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
                                      : (currentRate * 2.205).toStringAsFixed(
                                          2,
                                        );
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
                                  horizontal: Responsive.width(ctx, 12),
                                  vertical: Responsive.height(ctx, 6),
                                ),
                                decoration: BoxDecoration(
                                  gradient: (isMetricCalorie == (u == 'metric'))
                                      ? const LinearGradient(
                                          colors: [
                                            Color(0xFF22D3EE),
                                            Color(0xFF3B82F6),
                                            Color(0xFF1E40AF),
                                          ],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        )
                                      : null,
                                  borderRadius: BorderRadius.circular(
                                    Responsive.scale(ctx, 16),
                                  ),
                                ),
                                child: Text(
                                  u == 'metric' ? 'kg / cm' : 'lbs / ft',
                                  style: GoogleFonts.manrope(
                                    fontSize: Responsive.font(ctx, 12),
                                    fontWeight:
                                        (isMetricCalorie == (u == 'metric'))
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: (isMetricCalorie == (u == 'metric'))
                                        ? Colors.white
                                        : dim,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: Responsive.height(ctx, 12)),
                  // Sex toggle
                  Row(
                    children: [
                      for (final s in ['Male', 'Female']) ...[
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() {
                              selectedSex = s;
                              step3MissingError = null;
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: EdgeInsets.symmetric(
                                vertical: Responsive.height(ctx, 10),
                              ),
                              decoration: BoxDecoration(
                                gradient: selectedSex == s
                                    ? const LinearGradient(
                                        colors: [
                                          Color(0xFF22D3EE),
                                          Color(0xFF3B82F6),
                                          Color(0xFF1E40AF),
                                        ],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      )
                                    : null,
                                color: selectedSex == s
                                    ? null
                                    : const Color(0x113B82F6),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selectedSex == s
                                      ? const Color(0xFF3B82F6)
                                      : const Color(0x663B82F6),
                                  width: 1.5,
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
                  // show weight field if it wasn't entered on step 1
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
                  SizedBox(height: Responsive.height(ctx, 20)),
                  GestureDetector(
                    onTap: () {
                      final missing = <String>[];
                      if (selectedSex == null) missing.add('sex');
                      if (ageController.text.trim().isEmpty) missing.add('age');
                      if (heightCm == null) missing.add('height');
                      if (missing.isNotEmpty) {
                        setState(
                          () => step3MissingError =
                              'Still needed: ${missing.join(', ')}.',
                        );
                        return;
                      }
                      FirebaseAnalytics.instance.logEvent(
                        name: 'onboarding_step_viewed',
                        parameters: {'step': 3},
                      );
                      setState(() {
                        step3MissingError = null;
                        currentStep = 3;
                      });
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            vertical: Responsive.height(ctx, 17),
                            horizontal: Responsive.width(ctx, 24),
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              Responsive.scale(ctx, 14),
                            ),
                            gradient:
                                (selectedSex != null &&
                                    ageController.text.trim().isNotEmpty &&
                                    heightCm != null)
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFF22D3EE),
                                      Color(0xFF3B82F6),
                                      Color(0xFF1E40AF),
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  )
                                : const LinearGradient(
                                    colors: [
                                      Color(0xFFFF6B6B),
                                      Color(0xFFEF4444),
                                      Color(0xFFB91C1C),
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                            border: Border.all(
                              color:
                                  (selectedSex != null &&
                                      ageController.text.trim().isNotEmpty &&
                                      heightCm != null)
                                  ? const Color(0xFF3B82F6)
                                  : const Color(0xFFEF4444),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            'Continue',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                              fontSize: Responsive.font(ctx, 15),
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (step3MissingError != null)
                          Padding(
                            padding: EdgeInsets.only(
                              top: Responsive.height(ctx, 8),
                            ),
                            child: Text(
                              step3MissingError!,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.manrope(
                                fontSize: Responsive.font(ctx, 12),
                                color: Colors.redAccent,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        Widget buildStep4() {
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
                    'How active are you, and what rate do you want to progress at?',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: Responsive.font(ctx, 13),
                      color: Colors.white.withAlpha(180),
                    ),
                  ),
                  SizedBox(height: Responsive.height(ctx, 20)),
                  // Activity
                  Text(
                    'Activity level',
                    style: GoogleFonts.manrope(
                      fontSize: Responsive.font(ctx, 15),
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
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
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF22D3EE),
                                          Color(0xFF3B82F6),
                                          Color(0xFF1E40AF),
                                        ],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFF3B82F6),
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
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          Icons.check_rounded,
                                          color: Colors.white,
                                          size: Responsive.scale(ctx, 16),
                                        ),
                                        SizedBox(
                                          width: Responsive.width(ctx, 8),
                                        ),
                                        Text(
                                          'change',
                                          style: GoogleFonts.manrope(
                                            fontSize: Responsive.font(ctx, 11),
                                            color: Colors.white.withAlpha(180),
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
                                            color: const Color(0x1A3B82F6),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: const Color(0x663B82F6),
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
                                                                FontWeight.w600,
                                                            color: Colors.white,
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
                                                            color: Colors.white
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
                                        color: Colors.white.withAlpha(180),
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
                                                  gradient:
                                                      !isCustomActive &&
                                                          rateController.text ==
                                                              r.toString()
                                                      ? const LinearGradient(
                                                          colors: [
                                                            Color(0xFF22D3EE),
                                                            Color(0xFF3B82F6),
                                                            Color(0xFF1E40AF),
                                                          ],
                                                          begin: Alignment
                                                              .centerLeft,
                                                          end: Alignment
                                                              .centerRight,
                                                        )
                                                      : null,
                                                  color:
                                                      !isCustomActive &&
                                                          rateController.text ==
                                                              r.toString()
                                                      ? null
                                                      : const Color(0x113B82F6),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color:
                                                        !isCustomActive &&
                                                            rateController
                                                                    .text ==
                                                                r.toString()
                                                        ? const Color(
                                                            0xFF3B82F6,
                                                          )
                                                        : const Color(
                                                            0x663B82F6,
                                                          ),
                                                    width: 1.5,
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
                                                gradient: isCustomActive
                                                    ? const LinearGradient(
                                                        colors: [
                                                          Color(0xFF22D3EE),
                                                          Color(0xFF3B82F6),
                                                          Color(0xFF1E40AF),
                                                        ],
                                                        begin: Alignment
                                                            .centerLeft,
                                                        end: Alignment
                                                            .centerRight,
                                                      )
                                                    : null,
                                                color: isCustomActive
                                                    ? null
                                                    : const Color(0x113B82F6),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: isCustomActive
                                                      ? const Color(0xFF3B82F6)
                                                      : const Color(0x663B82F6),
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: Center(
                                                child: HugeIcon(
                                                  icon: HugeIcons
                                                      .strokeRoundedPencilEdit01,
                                                  color: isCustomActive
                                                      ? accent
                                                      : Colors.white.withAlpha(
                                                          180,
                                                        ),
                                                  size: Responsive.scale(
                                                    ctx,
                                                    16,
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
                                        color: const Color(0x1A3B82F6),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0x663B82F6),
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
                                              color: Colors.white,
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
                                                      color: Colors.white,
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
                  GestureDetector(
                    onTap:
                        (tdee != null &&
                            (goalType == 'maintain' ||
                                rateController.text.isNotEmpty))
                        ? () {
                            FirebaseAnalytics.instance.logEvent(
                              name: 'onboarding_step_viewed',
                              parameters: {'step': 4},
                            );
                            setState(() => currentStep = 4);
                          }
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
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        vertical: Responsive.height(ctx, 17),
                        horizontal: Responsive.width(ctx, 24),
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          Responsive.scale(ctx, 14),
                        ),
                        gradient:
                            (tdee != null &&
                                (goalType == 'maintain' ||
                                    rateController.text.isNotEmpty))
                            ? const LinearGradient(
                                colors: [
                                  Color(0xFF22D3EE),
                                  Color(0xFF3B82F6),
                                  Color(0xFF1E40AF),
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              )
                            : const LinearGradient(
                                colors: [
                                  Color(0xFFFF6B6B),
                                  Color(0xFFEF4444),
                                  Color(0xFFB91C1C),
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                        border: Border.all(
                          color:
                              (tdee != null &&
                                  (goalType == 'maintain' ||
                                      rateController.text.isNotEmpty))
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFFEF4444),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        'Set my calorie goal',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(ctx, 15),
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  // red is fine here, users have not chosen a theme color yet at this point in onboarding
                  if (setupMissingError != null)
                    Padding(
                      padding: EdgeInsets.only(top: Responsive.height(ctx, 8)),
                      child: Text(
                        setupMissingError!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(ctx, 12),
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }

        // Macro profile step: only shown when a calorie target was calculated
        Widget buildStep5() {
          void applyMacros(int protein, int carbs, int fat) {
            // store pending, written to db in commitAll
            pendingProtein = protein;
            pendingCarbs = carbs;
            pendingFat = fat;
            // standard micro defaults based on calorie target
            pendingFiber = ((liveCalories ?? 2000) * 0.014).round().clamp(
              20,
              40,
            );
            pendingSugar = ((liveCalories ?? 2000) * 0.025).round().clamp(
              25,
              60,
            );
            pendingSodium = 2300;
            FirebaseAnalytics.instance.logEvent(
              name: 'onboarding_step_viewed',
              parameters: {'step': 5},
            );
            setState(() => currentStep = 5);
          }

          final calories = liveCalories ?? 2000;

          // Standard macro splits derived from calorie target
          // Build muscle: protein 30%, carbs 45%, fat 25%
          final muscleProtein = ((calories * 0.30) / 4).round();
          final muscleCarbs = ((calories * 0.45) / 4).round();
          final muscleFat = ((calories * 0.25) / 9).round();
          // Lose fat: protein 40%, carbs 30%, fat 30%
          final fatLossProtein = ((calories * 0.40) / 4).round();
          final fatLossCarbs = ((calories * 0.30) / 4).round();
          final fatLossFat = ((calories * 0.30) / 9).round();
          // Stay lean: protein 35%, carbs 40%, fat 25%
          final leanProtein = ((calories * 0.35) / 4).round();
          final leanCarbs = ((calories * 0.40) / 4).round();
          final leanFat = ((calories * 0.25) / 9).round();
          // Balanced: protein 25%, carbs 50%, fat 25%
          final balancedProtein = ((calories * 0.25) / 4).round();
          final balancedCarbs = ((calories * 0.50) / 4).round();
          final balancedFat = ((calories * 0.25) / 9).round();

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'What are you going for?',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: Responsive.font(ctx, 20),
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: Responsive.height(ctx, 6)),
              Text(
                "We'll set your macro goals automatically",
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: Responsive.font(ctx, 13),
                  color: Colors.white.withAlpha(180),
                ),
              ),
              SizedBox(height: Responsive.height(ctx, 20)),
              _activationOption(
                ctx,
                icon: HugeIcons.strokeRoundedDumbbell01,
                title: 'Build muscle',
                subtitle:
                    '${muscleProtein}g protein · ${muscleCarbs}g carbs · ${muscleFat}g fat',
                description: 'Higher carbs to fuel training, moderate fat',
                accent: accent,
                dim: dim,
                onTap: () => applyMacros(muscleProtein, muscleCarbs, muscleFat),
              ),
              SizedBox(height: Responsive.height(ctx, 10)),
              _activationOption(
                ctx,
                icon: HugeIcons.strokeRoundedFire,
                title: 'Lose fat',
                subtitle:
                    '${fatLossProtein}g protein · ${fatLossCarbs}g carbs · ${fatLossFat}g fat',
                description:
                    'High protein to preserve muscle while in a deficit',
                accent: accent,
                dim: dim,
                onTap: () =>
                    applyMacros(fatLossProtein, fatLossCarbs, fatLossFat),
              ),
              SizedBox(height: Responsive.height(ctx, 10)),
              _activationOption(
                ctx,
                icon: HugeIcons.strokeRoundedActivity01,
                title: 'Stay lean',
                subtitle:
                    '${leanProtein}g protein · ${leanCarbs}g carbs · ${leanFat}g fat',
                description:
                    'Balanced split for active people maintaining their weight',
                accent: accent,
                dim: dim,
                onTap: () => applyMacros(leanProtein, leanCarbs, leanFat),
              ),
              SizedBox(height: Responsive.height(ctx, 10)),
              _activationOption(
                ctx,
                icon: HugeIcons.strokeRoundedApple01,
                title: 'Just eat healthier',
                subtitle:
                    '${balancedProtein}g protein · ${balancedCarbs}g carbs · ${balancedFat}g fat',
                description:
                    'A simple balanced split with no strict requirements',
                accent: accent,
                dim: dim,
                onTap: () =>
                    applyMacros(balancedProtein, balancedCarbs, balancedFat),
              ),
            ],
          );
        }

        // Username step: let user pick a name, or get a random one
        Widget buildStep6() {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Pick a username',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: Responsive.font(ctx, 20),
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: Responsive.height(ctx, 6)),
              Text(
                'This is how you appear on the leaderboard',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: Responsive.font(ctx, 13),
                  color: Colors.white.withAlpha(180),
                ),
              ),
              SizedBox(height: Responsive.height(ctx, 20)),
              AnimatedSize(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutQuart,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeOutQuart,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.06),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: randomSuggestions.isEmpty
                      ? KeyedSubtree(
                          key: const ValueKey('type-own'),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                controller: usernameController,
                                style: GoogleFonts.manrope(color: Colors.white),
                                textCapitalization: TextCapitalization.none,
                                decoration: InputDecoration(
                                  hintText: 'Username',
                                  hintStyle: GoogleFonts.manrope(
                                    color: Colors.white38,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withAlpha(10),
                                  errorText: usernameError,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      Responsive.scale(ctx, 12),
                                    ),
                                    borderSide: const BorderSide(
                                      color: Color(0x663B82F6),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      Responsive.scale(ctx, 12),
                                    ),
                                    borderSide: const BorderSide(
                                      color: Color(0x663B82F6),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      Responsive.scale(ctx, 12),
                                    ),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF3B82F6),
                                      width: 1.5,
                                    ),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: Responsive.width(ctx, 16),
                                    vertical: Responsive.height(ctx, 14),
                                  ),
                                ),
                                onChanged: (_) {
                                  if (usernameError != null) {
                                    setState(() => usernameError = null);
                                  }
                                },
                              ),
                              SizedBox(height: Responsive.height(ctx, 12)),
                              GestureDetector(
                                onTap: () async {
                                  final name = usernameController.text.trim();
                                  if (name.isEmpty) {
                                    setState(
                                      () => usernameError =
                                          'Enter a username to continue',
                                    );
                                    return;
                                  }
                                  if (name.length > 20) {
                                    setState(
                                      () => usernameError =
                                          'Must be 20 characters or fewer',
                                    );
                                    return;
                                  }
                                  final ok = await ref
                                      .read(userDataProvider.notifier)
                                      .updateUsername(
                                        name,
                                        ctx,
                                        showFeedback: false,
                                      );
                                  if (ok) {
                                    ref
                                        .read(userDataProvider.notifier)
                                        .patch(
                                          (u) => u.copyWith(username: name),
                                        );
                                    if (ctx.mounted) {
                                      FirebaseAnalytics.instance.logEvent(
                                        name: 'onboarding_step_viewed',
                                        parameters: {'step': 6},
                                      );
                                      FirebaseAnalytics.instance.logEvent(
                                        name: 'onboarding_username_set',
                                      );
                                      setState(() => currentStep = 6);
                                    }
                                  } else {
                                    setState(
                                      () => usernameError =
                                          'Username already taken',
                                    );
                                  }
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.symmetric(
                                    vertical: Responsive.height(ctx, 17),
                                    horizontal: Responsive.width(ctx, 24),
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      Responsive.scale(ctx, 14),
                                    ),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF22D3EE),
                                        Color(0xFF3B82F6),
                                        Color(0xFF1E40AF),
                                      ],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    border: Border.all(
                                      color: const Color(0xFF3B82F6),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Text(
                                    'Continue',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.manrope(
                                      fontSize: Responsive.font(ctx, 15),
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: Responsive.height(ctx, 16)),
                              GestureDetector(
                                onTap: () => setState(() {
                                  randomSuggestions = List.generate(
                                    3,
                                    (_) => generateRandomUsername(),
                                  );
                                  selectedSuggestion = null;
                                }),
                                child: Text(
                                  'Give me a random name instead',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.manrope(
                                    color: Colors.white.withAlpha(200),
                                    fontSize: Responsive.font(ctx, 13),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : KeyedSubtree(
                          key: const ValueKey('random'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  GestureDetector(
                                    onTap: () => setState(() {
                                      randomSuggestions = List.generate(
                                        3,
                                        (_) => generateRandomUsername(),
                                      );
                                      selectedSuggestion = null;
                                    }),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.refresh_rounded,
                                          color: Colors.white,
                                          size: Responsive.scale(ctx, 14),
                                        ),
                                        SizedBox(
                                          width: Responsive.width(ctx, 4),
                                        ),
                                        Text(
                                          'Regenerate',
                                          style: GoogleFonts.manrope(
                                            color: Colors.white,
                                            fontSize: Responsive.font(ctx, 12),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: Responsive.height(ctx, 8)),
                              for (final name in randomSuggestions) ...[
                                GestureDetector(
                                  onTap: () =>
                                      setState(() => selectedSuggestion = name),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    width: double.infinity,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: Responsive.width(ctx, 16),
                                      vertical: Responsive.height(ctx, 11),
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: selectedSuggestion == name
                                          ? const LinearGradient(
                                              colors: [
                                                Color(0xFF22D3EE),
                                                Color(0xFF3B82F6),
                                                Color(0xFF1E40AF),
                                              ],
                                              begin: Alignment.centerLeft,
                                              end: Alignment.centerRight,
                                            )
                                          : null,
                                      color: selectedSuggestion == name
                                          ? null
                                          : const Color(0x113B82F6),
                                      borderRadius: BorderRadius.circular(
                                        Responsive.scale(ctx, 10),
                                      ),
                                      border: Border.all(
                                        color: selectedSuggestion == name
                                            ? const Color(0xFF3B82F6)
                                            : const Color(0x663B82F6),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Text(
                                      name,
                                      style: GoogleFonts.manrope(
                                        color: Colors.white,
                                        fontSize: Responsive.font(ctx, 14),
                                        fontWeight: selectedSuggestion == name
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: Responsive.height(ctx, 6)),
                              ],
                              if (selectedSuggestion != null) ...[
                                SizedBox(height: Responsive.height(ctx, 4)),
                                GestureDetector(
                                  onTap: () async {
                                    final name = selectedSuggestion!;
                                    final ok = await ref
                                        .read(userDataProvider.notifier)
                                        .updateUsername(
                                          name,
                                          ctx,
                                          showFeedback: false,
                                        );
                                    if (ok) {
                                      ref
                                          .read(userDataProvider.notifier)
                                          .patch(
                                            (u) => u.copyWith(username: name),
                                          );
                                      if (ctx.mounted) {
                                        FirebaseAnalytics.instance.logEvent(
                                          name: 'onboarding_username_set',
                                        );
                                        FirebaseAnalytics.instance.logEvent(
                                          name: 'onboarding_step_viewed',
                                          parameters: {'step': 6},
                                        );
                                        setState(() => currentStep = 6);
                                      }
                                    } else {
                                      setState(() {
                                        randomSuggestions = List.generate(
                                          3,
                                          (_) => generateRandomUsername(),
                                        );
                                        selectedSuggestion = null;
                                      });
                                    }
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.symmetric(
                                      vertical: Responsive.height(ctx, 17),
                                      horizontal: Responsive.width(ctx, 24),
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(
                                        Responsive.scale(ctx, 14),
                                      ),
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF22D3EE),
                                          Color(0xFF3B82F6),
                                          Color(0xFF1E40AF),
                                        ],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                      border: Border.all(
                                        color: const Color(0xFF3B82F6),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Text(
                                      'Use $selectedSuggestion',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.manrope(
                                        fontSize: Responsive.font(ctx, 15),
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              SizedBox(height: Responsive.height(ctx, 12)),
                              GestureDetector(
                                onTap: () => setState(() {
                                  randomSuggestions = [];
                                  selectedSuggestion = null;
                                }),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: Text(
                                    'Type my own instead',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.manrope(
                                      color: Colors.white,
                                      fontSize: Responsive.font(ctx, 15),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ), // Column
                        ), // KeyedSubtree
                ), // AnimatedSwitcher
              ), // AnimatedSize
            ],
          );
        }

        Widget buildStep7() {
          final name = ref.read(userDataProvider).value?.username;
          final hasName =
              name != null && name != ref.read(userDataProvider).value?.uid;
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
                  color: Colors.white.withAlpha(180),
                ),
              ),
              SizedBox(height: Responsive.height(ctx, 20)),
              _activationOption(
                ctx,
                icon: HugeIcons.strokeRoundedDumbbell01,
                title: 'Start my first workout',
                subtitle: 'Log exercises, track sets and follow a routine',
                accent: accent,
                dim: dim,
                onTap: () {
                  FirebaseAnalytics.instance.logEvent(
                    name: 'onboarding_activation_choice',
                    parameters: {'choice': 'workout'},
                  );
                  commitAll();
                  finishOnboarding(context, ref);
                  Navigator.of(context, rootNavigator: true).pop('workout');
                },
              ),
              SizedBox(height: Responsive.height(ctx, 10)),
              _activationOption(
                ctx,
                icon: HugeIcons.strokeRoundedRestaurant03,
                title: 'Log my first food',
                subtitle: 'Search, scan a barcode, or enter manually',
                accent: accent,
                dim: dim,
                onTap: () {
                  FirebaseAnalytics.instance.logEvent(
                    name: 'onboarding_activation_choice',
                    parameters: {'choice': 'food'},
                  );
                  commitAll();
                  finishOnboarding(context, ref);
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
                  FirebaseAnalytics.instance.logEvent(
                    name: 'onboarding_activation_choice',
                    parameters: {'choice': 'home'},
                  );
                  commitAll();
                  finishOnboarding(context, ref);
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
                  FirebaseAnalytics.instance.logEvent(
                    name: 'onboarding_activation_choice',
                    parameters: {'choice': 'settings'},
                  );
                  commitAll();
                  finishOnboarding(context, ref);
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
                        : currentStep == 3
                        ? buildStep4()
                        : currentStep == 4
                        ? buildStep5()
                        : currentStep == 5
                        ? buildStep6()
                        : buildStep7(),
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
                        // if goals were skipped, back from macro/username jumps to step 1
                        if (currentStep == 4 && selectedGoal == null) {
                          currentStep = 1;
                        } else if (currentStep == 5 && selectedGoal == null) {
                          currentStep = 1;
                        } else {
                          currentStep--;
                        }
                      }),
                      icon: Icon(
                        Icons.arrow_back_ios_rounded,
                        size: Responsive.scale(ctx, 14),
                        color: Colors.white.withAlpha(220),
                      ),
                      label: Text(
                        'Back',
                        style: GoogleFonts.manrope(
                          color: Colors.white.withAlpha(220),
                          fontSize: Responsive.font(ctx, 14),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    ),
                    if (currentStep == 1 ||
                        currentStep == 2 ||
                        currentStep == 3 ||
                        currentStep == 4)
                      TextButton(
                        onPressed: () async {
                          if (currentStep == 1) {
                            final confirmed = await showFrostedDialog<bool>(
                              context: ctx,
                              appColor: appColor,
                              backgroundColor: const Color(0x2A3B82F6),
                              borderColor: const Color(0x883B82F6),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Skip goal setup?',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.manrope(
                                      fontSize: Responsive.font(ctx, 20),
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(height: Responsive.height(ctx, 12)),
                                  Text(
                                    "We'll use smart defaults for your calorie, macro, and weight goals. Change them anytime in Settings.",
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.manrope(
                                      color: Colors.white.withAlpha(180),
                                      fontSize: Responsive.font(ctx, 13),
                                    ),
                                  ),
                                  SizedBox(height: Responsive.height(ctx, 24)),
                                  GestureDetector(
                                    onTap: () => Navigator.of(
                                      ctx,
                                      rootNavigator: true,
                                    ).pop(false),
                                    child: Container(
                                      width: double.infinity,
                                      padding: EdgeInsets.symmetric(
                                        vertical: Responsive.height(ctx, 15),
                                        horizontal: Responsive.width(ctx, 24),
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(
                                          Responsive.scale(ctx, 14),
                                        ),
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF22D3EE),
                                            Color(0xFF3B82F6),
                                            Color(0xFF1E40AF),
                                          ],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        ),
                                        border: Border.all(
                                          color: const Color(0xFF3B82F6),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Text(
                                        'Fill it in',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.manrope(
                                          fontSize: Responsive.font(ctx, 15),
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: Responsive.height(ctx, 12)),
                                  GestureDetector(
                                    onTap: () => Navigator.of(
                                      ctx,
                                      rootNavigator: true,
                                    ).pop(true),
                                    child: Text(
                                      'Skip anyway',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.manrope(
                                        color: Colors.white.withAlpha(160),
                                        fontSize: Responsive.font(ctx, 13),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed != true) return;
                          }
                          FirebaseAnalytics.instance.logEvent(
                            name: 'onboarding_step_skipped',
                            parameters: {'from_step': currentStep},
                          );
                          FirebaseAnalytics.instance.logEvent(
                            name: 'onboarding_step_viewed',
                            parameters: {'step': 5},
                          );
                          if (ctx.mounted) setState(() => currentStep = 5);
                        },
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              currentStep == 1
                                  ? "I'll do this later"
                                  : 'Skip this step',
                              style: GoogleFonts.manrope(
                                color: Colors.white.withAlpha(220),
                                fontSize: Responsive.font(ctx, 14),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: Responsive.width(ctx, 4)),
                            Transform.flip(
                              flipX: true,
                              child: Icon(
                                Icons.arrow_back_ios_rounded,
                                size: Responsive.scale(ctx, 14),
                                color: Colors.white.withAlpha(220),
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
  usernameController.dispose();
  return wizardChoice;
}

class _FeaturePill extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final Color dim;
  final int index;
  final bool animate;

  const _FeaturePill({
    required this.icon,
    required this.label,
    required this.accent,
    required this.dim,
    required this.index,
    required this.animate,
  });

  @override
  State<_FeaturePill> createState() => _FeaturePillState();
}

class _FeaturePillState extends State<_FeaturePill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slide = Tween<Offset>(
      begin: const Offset(-0.18, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _fade = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));

    if (widget.animate) {
      Future.delayed(Duration(milliseconds: 80 * widget.index), () {
        if (mounted) _slideCtrl.forward();
      });
    } else {
      _slideCtrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.width(context, 12),
            vertical: Responsive.height(context, 9),
          ),
          decoration: BoxDecoration(
            color: const Color(0x0D3B82F6),
            borderRadius: BorderRadius.circular(Responsive.scale(context, 10)),
            border: Border(
              left: BorderSide(
                color: const Color(0xFF22D3EE),
                width: Responsive.scale(context, 3),
              ),
            ),
          ),
          child: Row(
            children: [
              HugeIcon(
                icon: widget.icon,
                color: widget.accent,
                size: Responsive.scale(context, 22),
              ),
              SizedBox(width: Responsive.width(context, 12)),
              Flexible(
                child: Text(
                  widget.label,
                  style: GoogleFonts.manrope(
                    fontSize: Responsive.font(context, 15),
                    color: widget.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _featurePill(
  BuildContext context,
  IconData icon,
  String label,
  Color accent,
  Color dim, {
  int index = 0,
  bool animate = true,
}) {
  return _FeaturePill(
    icon: icon,
    label: label,
    accent: accent,
    dim: dim,
    index: index,
    animate: animate,
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
        borderSide: const BorderSide(color: Color(0x663B82F6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
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
  Color dim, {
  ValueChanged<String>? onChanged,
}) {
  return TextField(
    controller: controller,
    onChanged: onChanged,
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
        borderSide: const BorderSide(color: Color(0x663B82F6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: Responsive.width(context, 14),
        vertical: Responsive.height(context, 13),
      ),
    ),
  );
}

// Called at the end of onboarding to assign a random username and mark the user as no longer new
void finishOnboarding(BuildContext context, WidgetRef ref) {
  final userData = ref.read(userDataProvider).value;
  if (userData?.username == userData?.uid) {
    final name = generateRandomUsername();
    ref
        .read(userDataProvider.notifier)
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
  String? description,
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
        color: const Color(0x113B82F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x993B82F6), width: 1.5),
      ),
      child: Row(
        children: [
          HugeIcon(
            icon: icon,
            color: Colors.white,
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
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.manrope(
                    fontSize: Responsive.font(context, 12),
                    color: Colors.white.withAlpha(180),
                  ),
                ),
                if (description != null) ...[
                  SizedBox(height: Responsive.height(context, 2)),
                  Text(
                    description,
                    style: GoogleFonts.manrope(
                      fontSize: Responsive.font(context, 11),
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: Colors.white,
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
    'Titan',
    'Venom',
    'Flux',
    'Zenith',
    'Surge',
    'Abyss',
    'Volt',
    'Raven',
    'Amber',
    'Cobalt',
    'Magma',
    'Arctic',
    'Phantom',
    'Toxic',
    'Vivid',
    'Rigid',
    'Dense',
    'Primal',
    'Rebel',
    'Ghost',
    'Cinder',
    'Molten',
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
    'Golem',
    'Wraith',
    'Hydra',
    'Phoenix',
    'Kraken',
    'Colossus',
    'Sentinel',
    'Warlord',
    'Enforcer',
    'Gladiator',
    'Apex',
    'Juggernaut',
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
