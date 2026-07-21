import 'dart:async';
import 'dart:convert';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/providers/user_data_provider.dart';
import 'dart:ui';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../../utility/unit_converter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '/globals.dart';
import '/guest.dart';
import '/services/user_data_manager.dart';
import '/utility/responsive.dart';
import '/services/fcm/notification_service.dart';
import '../premium_sheet.dart' show showPremiumSheet;
import '../widgets/profile_card.dart' show showProfileCard;

Future<void> showUsernameDialogBox(
  BuildContext context,
  String title,
  TextEditingController usernameController,
  WidgetRef ref,
  Color appColor,
) async {
  final accent = Colors.white;
  final dim = Colors.white;
  final currentUsername = ref.read(userDataProvider).value?.username;
  final hasUsername =
      currentUsername != null &&
      currentUsername != ref.read(userDataProvider).value?.uid;

  await showFrostedDialog(
    context: context,
    appColor: appColor,
    child: StatefulBuilder(
      builder: (context, setDialogState) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: GoogleFonts.manrope(
                color: accent,
                fontSize: Responsive.font(context, 18),
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            if (hasUsername) ...[
              SizedBox(height: Responsive.height(context, 4)),
              Text(
                'Current: $currentUsername',
                style: GoogleFonts.manrope(
                  color: dim,
                  fontSize: Responsive.font(context, 12),
                ),
                textAlign: TextAlign.center,
              ),
            ],
            SizedBox(height: Responsive.height(context, 16)),
            TextField(
              controller: usernameController,
              autofocus: true,
              maxLength: 20,
              style: GoogleFonts.manrope(color: Colors.white),
              textCapitalization: TextCapitalization.none,
              decoration: InputDecoration(
                hintText: 'Username',
                hintStyle: GoogleFonts.manrope(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withAlpha(10),
                counterStyle: GoogleFonts.manrope(
                  color: Colors.white54,
                  fontSize: Responsive.font(context, 11),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    Responsive.scale(context, 10),
                  ),
                  borderSide: BorderSide(color: Colors.white.withAlpha(25)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    Responsive.scale(context, 10),
                  ),
                  borderSide: BorderSide(color: Colors.white.withAlpha(25)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    Responsive.scale(context, 10),
                  ),
                  borderSide: const BorderSide(color: Colors.white, width: 1.5),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: Responsive.width(context, 14),
                  vertical: Responsive.height(context, 12),
                ),
              ),
            ),
            SizedBox(height: Responsive.height(context, 16)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () =>
                      Navigator.of(context, rootNavigator: true).pop(),
                  child: Text('Cancel', style: dialogButtonStyle()),
                ),
                TextButton(
                  onPressed: () async {
                    final updatedUsername = usernameController.text.trim();
                    if (updatedUsername.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Please enter a username.'),
                          duration: snackBarDuration,
                        ),
                      );
                      return;
                    }
                    if (await ref
                        .read(userDataProvider.notifier)
                        .updateUsername(updatedUsername, context)) {
                      Navigator.of(context, rootNavigator: true).pop();
                    }
                  },
                  child: Text(
                    'Confirm',
                    style: dialogButtonStyle(confirm: true),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ),
  ).then((_) {
    usernameController.text = '';
  });
}

class PersonalPreferences extends ConsumerStatefulWidget {
  final VoidCallback?
  onProfileImageUpdated; // callback to notify HomeScreen when the profile picture is updated

  const PersonalPreferences({super.key, this.onProfileImageUpdated});

  @override
  ConsumerState<PersonalPreferences> createState() =>
      _PersonalPreferencesState();
}

class _PersonalPreferencesState extends ConsumerState<PersonalPreferences>
    with SingleTickerProviderStateMixin {
  Color get appColor => ref.watch(
    userDataProvider.select((s) => s.value?.appColor ?? defaultAppColor),
  );

  TextEditingController usernameController = TextEditingController();
  late AnimationController _colorAnimController;
  late Color _animFromColor;

  @override
  void dispose() {
    _colorAnimController.dispose();
    usernameController.dispose();
    super.dispose();
  }

  late Color baseColor; // tracks the current theme color for the UI
  late bool notificationsEnabled; // tracks the notification toggle state
  late String _units; // tracks the selected unit system (metric or imperial)
  bool _cropLoading = false;

  // TODO: load per-type prefs from backend when setup
  bool _notifyDailyReward = true;
  bool _notifyFriendRequests = true;
  bool _notifyNudges = true;
  bool _notifyReminders = true;

  @override
  void initState() {
    super.initState();
    final userData = ref.read(userDataProvider).value;
    baseColor = userData?.appColor ?? defaultAppColor;
    notificationsEnabled = userData?.notificationsEnabled ?? true;
    _units = userData?.units ?? 'metric';
    _animFromColor = appColor;
    FirebaseAnalytics.instance.logScreenView(
      screenName: '/settings/preferences',
      screenClass: 'PersonalPreferences',
    );
    _colorAnimController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 2000),
        )..addListener(() {
          if (mounted) {
            // Animate appColorNotifier through intermediate colors for background/gradient,
            // cards already have final color so they don't pop
            final c = Color.lerp(
              _animFromColor,
              appColor,
              _colorAnimController.value,
            );
            if (c != null) setState(() {});
          }
        });
  }

  Future pickProfileImage() async {
    if (isGuest) {
      Guest.block(context);
      return;
    }
    final returnedImage = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (!mounted || returnedImage == null) return; // stop if user canceled

    setState(() => _cropLoading = true);

    try {
      Uint8List? imageBytes;
      File? file;

      // Handle web and mobile separately
      if (kIsWeb) {
        // Web: get bytes directly from XFile
        imageBytes = await returnedImage.readAsBytes();
      } else {
        // Mobile: convert to File
        file = File(returnedImage.path);
      }

      if (mounted) {
        if (kIsWeb) {
          // Pass null for file, only use bytes
          await ref
              .read(userDataProvider.notifier)
              .updateProfilePicture(
                null,
                context: context,
                onProfileUpdated: widget.onProfileImageUpdated,
                imageInBytes: imageBytes,
              );
        } else {
          await ref
              .read(userDataProvider.notifier)
              .updateProfilePicture(
                file,
                context: context,
                onProfileUpdated: widget.onProfileImageUpdated,
              );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to update profile picture: $e"),
            duration: snackBarDuration,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cropLoading = false);
    }
  }

  Future<void> applyAppColor(Color color) async {
    if (isGuest) {
      Guest.block(context);
      return;
    }
    unawaited(ref.read(userDataProvider.notifier).setAppColor(color, context));

    _animFromColor = appColor; // snapshot start color
    _colorAnimController.forward(from: 0); // animate setState for background
    baseColor = color;
    setState(() {});
  }

  void showColorPickerDialog() {
    if (isGuest) {
      Guest.block(context);
      return;
    }
    _showPresetColorDialog();
  }

  static const _presetColors = [
    (Color(0xFF2D2D2D), 'Default'),
    (Color(0xFF4F8EF7), 'Blue'),
    (Color(0xFF7C5CBF), 'Purple'),
    (Color(0xFFE05C8A), 'Pink'),
    (Color(0xFF2EBF91), 'Teal'),
    (Color(0xFFE8864B), 'Orange'),
    (Color(0xFF5782AF), 'Steel'),
    (Color(0xFF4F17A1), 'Violet'),
    (Color(0xFFE84B4B), 'Red'),
    (Color(0xFF1A2A4A), 'Navy'),
    (Color(0xFF1A3A2A), 'Forest'),
    (Color(0xFF2A1A3A), 'Midnight'),
    (Color(0xFF3A1A1A), 'Crimson'),
    (Color(0xFFB8D4F0), 'Ice'),
    (Color(0xFFCFB8E8), 'Lilac'),
  ];

  void _showPresetColorDialog() {
    showFrostedDialog(
      context: context,
      appColor: appColor,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Theme Color',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 15),
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: Responsive.height(context, 6)),
            Text(
              'Choose a preset color',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 12),
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: Responsive.height(context, 20)),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: Responsive.width(context, 8),
              mainAxisSpacing: Responsive.height(context, 12),
              children: [
                for (final (color, label) in _presetColors)
                  GestureDetector(
                    onTap: () async {
                      Navigator.of(context, rootNavigator: true).pop();
                      await applyAppColor(color);
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: Responsive.scale(context, 44),
                          height: Responsive.scale(context, 44),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: baseColor == color
                                  ? Colors.white
                                  : Colors.white.withAlpha(40),
                              width: baseColor == color ? 2.5 : 1.5,
                            ),
                          ),
                        ),
                        SizedBox(height: Responsive.height(context, 4)),
                        Text(
                          label,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 9),
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                // custom picker, unlocked for premium, locked otherwise
                Builder(
                  builder: (context) {
                    final isPremium =
                        ref.read(userDataProvider).value?.isPremium ?? false;
                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context, rootNavigator: true).pop();
                        if (isPremium) {
                          _showFullColorPickerDialog();
                        } else {
                          showProFeatureDialog(
                            context,
                            feature: 'Custom Theme Colors',
                            appColor: appColor,
                            onLearnMore: () {
                              logAnalyticsEvent(
                                'premium_sheet_opened_from_learn_more',
                              );
                              showPremiumSheet(context, ref);
                            },
                          );
                        }
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: Responsive.scale(context, 44),
                            height: Responsive.scale(context, 44),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const SweepGradient(
                                colors: [
                                  Color(0xFFE84B4B),
                                  Color(0xFFE8864B),
                                  Color(0xFFE8C44B),
                                  Color(0xFF2EBF91),
                                  Color(0xFF4F8EF7),
                                  Color(0xFF7C5CBF),
                                  Color(0xFFE84B4B),
                                ],
                              ),
                              border: Border.all(
                                color: cardColors(appColor).border,
                                width: 1.5,
                              ),
                            ),
                            child: isPremium
                                ? null
                                : Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withAlpha(100),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.lock_rounded,
                                      color: Colors.white.withAlpha(200),
                                      size: Responsive.scale(context, 18),
                                    ),
                                  ),
                          ),
                          SizedBox(height: Responsive.height(context, 4)),
                          Text(
                            'Custom',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                              fontSize: Responsive.font(context, 9),
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
            SizedBox(height: Responsive.height(context, 16)),
            TextButton(
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
              child: Text('Cancel', style: dialogButtonStyle()),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullColorPickerDialog() {
    Color pickerColor = baseColor.withAlpha(255);
    // IntrinsicWidth sizes the dialog to exactly the picker's colorPickerWidth
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(),
        insetPadding: EdgeInsets.symmetric(
          horizontal: Responsive.width(context, 24),
          vertical: Responsive.height(context, 40),
        ),
        child: IntrinsicWidth(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Responsive.scale(context, 20)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(10),
                  borderRadius: BorderRadius.circular(
                    Responsive.scale(context, 20),
                  ),
                  border: Border.all(
                    color: cardColors(appColor).border,
                    width: 1,
                  ),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.width(context, 28),
                  vertical: Responsive.height(context, 32),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Pick a theme color',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: Responsive.font(context, 15),
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: Responsive.height(context, 16)),
                    ColorPicker(
                      pickerColor: pickerColor,
                      onColorChanged: (color) => pickerColor = color,
                      colorPickerWidth: 280,
                      labelTypes: const [],
                      enableAlpha: false,
                      pickerAreaHeightPercent: 0.8,
                    ),
                    SizedBox(height: Responsive.height(context, 16)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: Text('Cancel', style: dialogButtonStyle()),
                        ),
                        TextButton(
                          onPressed: () async {
                            await applyAppColor(defaultAppColor);
                            Navigator.of(ctx).pop();
                          },
                          child: Text('Default', style: dialogButtonStyle()),
                        ),
                        TextButton(
                          onPressed: () async {
                            await applyAppColor(pickerColor);
                            Navigator.of(ctx).pop();
                          },
                          child: Text(
                            'Select',
                            style: dialogButtonStyle(confirm: true),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // opens a dialog to update the user's nutrition (calorie + macro) goals
  Future<void> showNutritionGoalsDialog() async {
    if (isGuest) {
      Guest.block(context);
      return;
    }
    // pre-fill with existing values if they exist
    final ud = ref.read(userDataProvider).value;
    final calCtrl = TextEditingController(
      text: ud?.caloriesGoal?.toString() ?? '',
    );
    final proCtrl = TextEditingController(
      text: ud?.proteinGoal?.toString() ?? '',
    );
    final carbCtrl = TextEditingController(
      text: ud?.carbsGoal?.toString() ?? '',
    );
    final fatCtrl = TextEditingController(text: ud?.fatGoal?.toString() ?? '');
    final fiberCtrl = TextEditingController(
      text: ud?.fiberGoal?.toString() ?? '',
    );
    final sugarCtrl = TextEditingController(
      text: ud?.sugarGoal?.toString() ?? '',
    );
    final sodiumCtrl = TextEditingController(
      text: ud?.sodiumGoal?.toString() ?? '',
    );

    await showFrostedAlertDialog(
      context: context,
      appColor: appColor,
      title: "Nutrition Goals",
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _goalField(calCtrl, "Daily Calories (kcal)", maxLength: 5),
            _goalField(proCtrl, "Protein (g)"),
            _goalField(carbCtrl, "Carbs (g)"),
            _goalField(fatCtrl, "Fat (g)"),
            _goalField(fiberCtrl, "Fiber (g)"),
            _goalField(sugarCtrl, "Sugar (g)"),
            _goalField(sodiumCtrl, "Sodium (mg)", maxLength: 5),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: Text("Cancel", style: dialogButtonStyle()),
          onPressed: () => Navigator.pop(context),
        ),
        TextButton(
          child: Text("Save", style: dialogButtonStyle(confirm: true)),
          onPressed: () async {
            await ref
                .read(userDataProvider.notifier)
                .updateNutritionGoals(
                  caloriesGoal: int.tryParse(calCtrl.text.trim()),
                  proteinGoal: int.tryParse(proCtrl.text.trim()),
                  carbsGoal: int.tryParse(carbCtrl.text.trim()),
                  fatGoal: int.tryParse(fatCtrl.text.trim()),
                  fiberGoal: int.tryParse(fiberCtrl.text.trim()),
                  sugarGoal: int.tryParse(sugarCtrl.text.trim()),
                  sodiumGoal: int.tryParse(sodiumCtrl.text.trim()),
                  context: context,
                );
            if (mounted) setState(() {}); // refresh subtitle with new values
            Navigator.pop(context);
          },
        ),
      ],
    );
  }

  // opens a dialog to update the user's weight goal type and target weight
  Future<void> showWeightGoalDialog() async {
    if (isGuest) {
      Guest.block(context);
      return;
    }
    String? weightGoalType = ref.read(userDataProvider).value?.weightGoalType;
    final bool isMetric = (_units == 'metric');
    final double? currentKg = ref.read(userDataProvider).value?.weightKgGoal;
    String initialWeight = '';
    // convert stored kg to the user's preferred unit for display
    if (currentKg != null) {
      initialWeight = isMetric
          ? currentKg.toStringAsFixed(1)
          : UnitConverter.displayWeight(currentKg, imperial: true);
    }
    final weightCtrl = TextEditingController(text: initialWeight);

    await showFrostedAlertDialog(
      context: context,
      appColor: appColor,
      title: "Weight Goal",
      content: StatefulBuilder(
        // StatefulBuilder so the goal type selector can update without rebuilding the whole dialog
        builder: (sbContext, setDialogState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Goal type",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: Responsive.font(context, 13),
                ),
              ),
              SizedBox(height: Responsive.height(context, 8)),
              Row(
                children: [
                  for (final option in ['lose', 'maintain', 'gain'])
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: option != 'gain'
                              ? Responsive.width(context, 8)
                              : 0,
                        ),
                        child: GestureDetector(
                          onTap: () => setDialogState(
                            () => weightGoalType = weightGoalType == option
                                ? null
                                : option,
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: EdgeInsets.symmetric(
                              vertical: Responsive.height(context, 10),
                            ),
                            decoration: BoxDecoration(
                              color: weightGoalType == option
                                  ? cardColors(appColor).iconBox
                                  : Colors.white.withAlpha(10),
                              borderRadius: BorderRadius.circular(
                                Responsive.scale(context, 10),
                              ),
                              border: Border.all(
                                color: weightGoalType == option
                                    ? cardColors(appColor).border
                                    : cardColors(appColor).border.withAlpha(80),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              option[0].toUpperCase() + option.substring(1),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.manrope(
                                color: weightGoalType == option
                                    ? Colors.white
                                    : Colors.white,
                                fontSize: Responsive.font(context, 14),
                                fontWeight: weightGoalType == option
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: Responsive.height(context, 8)),
              _decimalGoalField(
                weightCtrl,
                isMetric ? "Target weight (kg)" : "Target weight (lbs)",
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          child: Text("Cancel", style: dialogButtonStyle()),
          onPressed: () => Navigator.pop(context),
        ),
        TextButton(
          child: Text("Save", style: dialogButtonStyle(confirm: true)),
          onPressed: () async {
            double? weightKg;
            final parsed = double.tryParse(weightCtrl.text.trim());
            // always store in kg regardless of user's unit preference
            if (parsed != null) {
              weightKg = isMetric ? parsed : UnitConverter.lbsToKg(parsed);
            }
            await ref
                .read(userDataProvider.notifier)
                .updateWeightGoal(
                  weightGoalType: weightGoalType,
                  weightKgGoal: weightKg,
                  context: context,
                );
            if (mounted) setState(() {}); // refresh subtitle with new values
            Navigator.pop(context);
          },
        ),
      ],
    );
  }

  Future<void> showWeeklyWorkoutGoalDialog() async {
    if (isGuest) {
      Guest.block(context);
      return;
    }
    int selected = ref.read(userDataProvider).value?.weeklyWorkoutsGoal ?? 3;

    await showFrostedAlertDialog(
      context: context,
      appColor: appColor,
      title: "Weekly Workout Goal",
      content: StatefulBuilder(
        builder: (sbContext, setDialogState) {
          final accent = Colors.white;
          final dim = Colors.white;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'How many workouts are you planning to do per week?',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  color: dim,
                  fontSize: Responsive.font(context, 12),
                ),
              ),
              SizedBox(height: Responsive.height(context, 16)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: selected > 1
                        ? () => setDialogState(() => selected--)
                        : null,
                    icon: Icon(
                      Icons.remove_circle_outline,
                      color: selected > 1
                          ? accent
                          : Colors.white.withAlpha(100),
                    ),
                  ),
                  SizedBox(width: Responsive.width(context, 12)),
                  Text(
                    '$selected',
                    style: GoogleFonts.manrope(
                      color: accent,
                      fontSize: Responsive.font(context, 32),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: Responsive.width(context, 12)),
                  IconButton(
                    onPressed: selected < 7
                        ? () => setDialogState(() => selected++)
                        : null,
                    icon: Icon(
                      Icons.add_circle_outline,
                      color: selected < 7
                          ? accent
                          : Colors.white.withAlpha(100),
                    ),
                  ),
                ],
              ),
              Text(
                'days per week',
                style: GoogleFonts.manrope(
                  color: dim,
                  fontSize: Responsive.font(context, 13),
                ),
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          child: Text('Cancel', style: dialogButtonStyle()),
        ),
        TextButton(
          onPressed: () async {
            Navigator.of(context, rootNavigator: true).pop();
            await ref
                .read(userDataProvider.notifier)
                .updateGoals(weeklyWorkoutsGoal: selected, context: context);
            if (mounted) setState(() {});
          },
          child: Text('Save', style: dialogButtonStyle(confirm: true)),
        ),
      ],
    );
  }

  // opens a dialog to update the user's daily water intake goal
  Future<void> showWaterGoalDialog() async {
    if (isGuest) {
      Guest.block(context);
      return;
    }
    final bool isMetric = (_units == 'metric');
    final int? currentMl = ref.read(userDataProvider).value?.waterMlGoal;
    String initialWater = '';
    // convert stored ml to oz for imperial users
    if (currentMl != null) {
      initialWater = isMetric
          ? currentMl.toString()
          : UnitConverter.displayWater(currentMl, imperial: true, decimals: 0);
    }
    final waterCtrl = TextEditingController(text: initialWater);

    await showFrostedAlertDialog(
      context: context,
      appColor: appColor,
      title: "Water Goal",
      content: _goalField(
        waterCtrl,
        isMetric ? "Daily water goal (ml)" : "Daily water goal (oz)",
        maxLength: 5,
      ),
      actions: [
        TextButton(
          child: Text("Cancel", style: dialogButtonStyle()),
          onPressed: () => Navigator.pop(context),
        ),
        TextButton(
          child: Text("Save", style: dialogButtonStyle(confirm: true)),
          onPressed: () async {
            int? waterMl;
            final parsed = int.tryParse(waterCtrl.text.trim());
            // always store in ml regardless of user's unit preference
            if (parsed != null) {
              waterMl = isMetric
                  ? parsed
                  : UnitConverter.ozToMl(parsed.toDouble()).round();
            }
            await ref
                .read(userDataProvider.notifier)
                .updateWaterGoal(waterMlGoal: waterMl, context: context);
            if (mounted) setState(() {}); // refresh subtitle with new values
            Navigator.pop(context);
          },
        ),
      ],
    );
  }

  // integer-only goal field
  Widget _goalField(
    TextEditingController ctrl,
    String hint, {
    int maxLength = 4,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(maxLength),
        ],
        style: GoogleFonts.manrope(color: Colors.white),
        decoration: InputDecoration(
          labelText: hint,
          labelStyle: GoogleFonts.manrope(color: Colors.white),
          floatingLabelStyle: GoogleFonts.manrope(color: Colors.white),
          filled: true,
          fillColor: Colors.white.withAlpha(12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Responsive.scale(context, 12)),
            borderSide: const BorderSide(color: Colors.white),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Responsive.scale(context, 12)),
            borderSide: const BorderSide(color: Colors.white, width: 1.5),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: Responsive.width(context, 16),
            vertical: Responsive.height(context, 14),
          ),
        ),
      ),
    );
  }

  // decimal goal field (for weight target)
  Widget _decimalGoalField(TextEditingController ctrl, String hint) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          TextInputFormatter.withFunction((oldValue, newValue) {
            if (newValue.text.isEmpty) return newValue;
            if (!RegExp(r'^\d{0,4}\.?\d{0,1}$').hasMatch(newValue.text)) {
              return oldValue;
            }
            return newValue;
          }),
        ],
        style: GoogleFonts.manrope(color: Colors.white),
        decoration: InputDecoration(
          labelText: hint,
          labelStyle: GoogleFonts.manrope(color: Colors.white),
          floatingLabelStyle: GoogleFonts.manrope(color: Colors.white),
          filled: true,
          fillColor: Colors.white.withAlpha(12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Responsive.scale(context, 12)),
            borderSide: const BorderSide(color: Colors.white),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Responsive.scale(context, 12)),
            borderSide: const BorderSide(color: Colors.white, width: 1.5),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: Responsive.width(context, 16),
            vertical: Responsive.height(context, 14),
          ),
        ),
      ),
    );
  }

  Widget _notifTypeRow(
    BuildContext context, {
    required Color appColor,
    required IconData icon,
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return buildPreferenceRow(
      icon: icon,
      label: label,
      subtitle: subtitle,
      trailing: Switch.adaptive(
        value: value,
        activeThumbColor: onTheme(appColor),
        activeTrackColor: cardColors(appColor).border,
        inactiveThumbColor: onTheme(appColor).withAlpha(120),
        inactiveTrackColor: cardColors(appColor).iconBox,
        onChanged: isGuest ? (_) => Guest.block(context) : onChanged,
      ),
    );
  }

  Future<void> _showBlockedUsersDialog() async {
    const int pageSize = 10;
    List<Map<String, dynamic>> items = [];
    bool isLoading = true;
    bool hasMore = false;
    int offset = 0;

    // Search state
    final searchController = TextEditingController();
    Map<String, dynamic>? searchResult;
    bool searched = false;
    bool searchLoading = false;
    // 'none' | 'blocking' | 'blocked'
    String blockState = 'none';

    Future<void> fetchPage(void Function(void Function()) setState) async {
      setState(() => isLoading = true);
      try {
        final res = await authenticatedGet(
          'blocked_users?limit=${pageSize + 1}&offset=$offset',
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final page = (data['items'] as List).cast<Map<String, dynamic>>();
          hasMore = page.length > pageSize;
          offset += pageSize;
          setState(() {
            items = [...items, ...page.take(pageSize)];
            isLoading = false;
          });
        } else {
          setState(() => isLoading = false);
        }
      } catch (_) {
        setState(() => isLoading = false);
      }
    }

    Future<void> doSearch(void Function(void Function()) setState) async {
      final query = searchController.text.trim();
      if (query.isEmpty) return;
      setState(() {
        searched = false;
        searchResult = null;
        searchLoading = true;
        blockState = 'none';
      });
      final res = await authenticatedGet(
        'search_user?username=${Uri.encodeComponent(query)}',
      );
      Map<String, dynamic>? result;
      if (res.statusCode == 200) {
        result = jsonDecode(res.body) as Map<String, dynamic>;
        final alreadyBlocked = items.any((u) => u['uid'] == result!['uid']);
        setState(() {
          searchResult = result;
          searched = true;
          searchLoading = false;
          blockState = alreadyBlocked ? 'blocked' : 'none';
        });
      } else {
        setState(() {
          searched = true;
          searchLoading = false;
        });
      }
    }

    bool initialFetchDone = false;

    await showFrostedDialog(
      context: context,
      appColor: appColor,
      child: StatefulBuilder(
        builder: (ctx, setState) {
          final primary = lightenColor(appColor, 0.45);
          final c = cardColors(appColor);

          if (!initialFetchDone) {
            initialFetchDone = true;
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => fetchPage(setState),
            );
          }

          Widget buildUserRow({
            required String uid,
            required String username,
            required Map<String, dynamic>? rawUser,
            required Widget trailing,
          }) {
            final pfpBytes = rawUser?['pfp_base64'] != null
                ? base64Decode(rawUser!['pfp_base64'] as String)
                : null;
            return Padding(
              padding: EdgeInsets.only(bottom: Responsive.height(ctx, 10)),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => showProfileCard(
                      ctx,
                      uid: uid,
                      appColor: appColor,
                      isOwnProfile: false,
                      onUnblock: () => setState(
                        () => items.removeWhere((u) => u['uid'] == uid),
                      ),
                    ),
                    child: Container(
                      width: Responsive.scale(ctx, 36),
                      height: Responsive.scale(ctx, 36),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c.iconBox,
                        border: Border.all(color: c.border, width: 1.5),
                      ),
                      child: ClipOval(
                        child: pfpBytes != null
                            ? Image.memory(pfpBytes, fit: BoxFit.cover)
                            : Icon(
                                Icons.person_rounded,
                                color: lightenColor(appColor, 0.40),
                                size: Responsive.scale(ctx, 18),
                              ),
                      ),
                    ),
                  ),
                  SizedBox(width: Responsive.width(ctx, 10)),
                  Expanded(
                    child: Text(
                      username,
                      style: GoogleFonts.manrope(
                        fontSize: Responsive.font(ctx, 13),
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  trailing,
                ],
              ),
            );
          }

          Widget unblockButton(String uid, String username) {
            return GestureDetector(
              onTap: () async {
                final confirmed = await showFrostedAlertDialog<bool>(
                  context: ctx,
                  appColor: appColor,
                  title: 'Unblock $username?',
                  actions: [
                    TextButton(
                      onPressed: () =>
                          Navigator.of(ctx, rootNavigator: true).pop(false),
                      child: Text('Cancel', style: dialogButtonStyle()),
                    ),
                    TextButton(
                      onPressed: () =>
                          Navigator.of(ctx, rootNavigator: true).pop(true),
                      child: Text(
                        'Unblock',
                        style: dialogButtonStyle(confirm: true),
                      ),
                    ),
                  ],
                );
                if (confirmed != true) return;
                await authenticatedPost('unblock', body: {'target_uid': uid});
                setState(() {
                  items.removeWhere((u) => u['uid'] == uid);
                  if (searchResult?['uid'] == uid) blockState = 'none';
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.width(ctx, 12),
                  vertical: Responsive.height(ctx, 6),
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(12),
                  borderRadius: BorderRadius.circular(
                    Responsive.scale(ctx, 20),
                  ),
                  border: Border.all(
                    color: Colors.white.withAlpha(30),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  'Unblock',
                  style: GoogleFonts.manrope(
                    fontSize: Responsive.font(ctx, 12),
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Blocked Users',
                style: GoogleFonts.manrope(
                  fontSize: Responsive.font(ctx, 18),
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: Responsive.height(ctx, 14)),

              sectionHeader(
                'BLOCK A USER',
                ctx,
                appColor: appColor,
                padding: EdgeInsets.only(bottom: Responsive.height(ctx, 8)),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      maxLength: 20,
                      cursorColor: Colors.white,
                      style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontSize: Responsive.font(ctx, 13),
                      ),
                      textCapitalization: TextCapitalization.none,
                      decoration: InputDecoration(
                        hintText: 'Search by username',
                        hintStyle: GoogleFonts.manrope(
                          color: Colors.white38,
                          fontSize: Responsive.font(ctx, 13),
                        ),
                        counterText: '',
                        filled: true,
                        fillColor: Colors.white.withAlpha(10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            Responsive.scale(ctx, 10),
                          ),
                          borderSide: BorderSide(
                            color: Colors.white.withAlpha(60),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            Responsive.scale(ctx, 10),
                          ),
                          borderSide: BorderSide(
                            color: Colors.white.withAlpha(60),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            Responsive.scale(ctx, 10),
                          ),
                          borderSide: const BorderSide(
                            color: Colors.white,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: Responsive.width(ctx, 12),
                          vertical: Responsive.height(ctx, 10),
                        ),
                      ),
                      onSubmitted: (_) => doSearch(setState),
                    ),
                  ),
                  SizedBox(width: Responsive.width(ctx, 8)),
                  GestureDetector(
                    onTap: () => doSearch(setState),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.width(ctx, 14),
                        vertical: Responsive.height(ctx, 10),
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: c.gradient,
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(
                          Responsive.scale(ctx, 10),
                        ),
                        border: Border.all(color: c.border, width: 1),
                      ),
                      child: searchLoading
                          ? SizedBox(
                              width: Responsive.scale(ctx, 14),
                              height: Responsive.scale(ctx, 14),
                              child: const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Search',
                              style: GoogleFonts.manrope(
                                fontSize: Responsive.font(ctx, 13),
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),

              // Search result
              if (searched) ...[
                SizedBox(height: Responsive.height(ctx, 12)),
                if (searchResult == null)
                  Padding(
                    padding: EdgeInsets.only(bottom: Responsive.height(ctx, 4)),
                    child: Text(
                      'No user found with that username.',
                      style: GoogleFonts.manrope(
                        fontSize: Responsive.font(ctx, 13),
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  buildUserRow(
                    uid: searchResult!['uid'] as String,
                    username: searchResult!['username'] as String? ?? 'Unknown',
                    rawUser: searchResult,
                    trailing: blockState == 'blocked'
                        ? unblockButton(
                            searchResult!['uid'] as String,
                            searchResult!['username'] as String? ?? 'Unknown',
                          )
                        : GestureDetector(
                            onTap: () async {
                              final uid = searchResult!['uid'] as String;
                              final username =
                                  searchResult!['username'] as String? ??
                                  'Unknown';
                              final confirmed = await showHoldToConfirmDialog(
                                context: ctx,
                                appColor: appColor,
                                title: 'Block $username?',
                                subtitle:
                                    'They won\'t be able to find your profile or send you friend requests.',
                                icon: HugeIcons.strokeRoundedUserRemove01,
                              );
                              if (confirmed != true) return;
                              await authenticatedPost(
                                'block',
                                body: {'target_uid': uid},
                              );
                              setState(() {
                                items.removeWhere((u) => u['uid'] == uid);
                                items.insert(0, searchResult!);
                                searchResult = null;
                                searched = false;
                                searchController.clear();
                                blockState = 'none';
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: Responsive.width(ctx, 12),
                                vertical: Responsive.height(ctx, 6),
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: c.gradient,
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(
                                  Responsive.scale(ctx, 20),
                                ),
                                border: Border.all(color: c.border, width: 1.5),
                              ),
                              child: Text(
                                'Block',
                                style: GoogleFonts.manrope(
                                  fontSize: Responsive.font(ctx, 12),
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                  ),
              ],

              if (items.isNotEmpty || (isLoading && items.isEmpty))
                Padding(
                  padding: EdgeInsets.only(top: Responsive.height(ctx, 14)),
                  child: sectionHeader(
                    'BLOCKED USERS',
                    ctx,
                    appColor: appColor,
                    padding: EdgeInsets.only(bottom: Responsive.height(ctx, 8)),
                  ),
                ),

              if (isLoading && items.isEmpty)
                Skeletonizer(
                  enabled: true,
                  effect: ShimmerEffect(
                    baseColor: c.iconBox,
                    highlightColor: c.border,
                    duration: const Duration(milliseconds: 1200),
                  ),
                  child: Column(
                    children: List.generate(
                      3,
                      (_) => Padding(
                        padding: EdgeInsets.only(
                          bottom: Responsive.height(ctx, 12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: Responsive.scale(ctx, 36),
                              height: Responsive.scale(ctx, 36),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: c.iconBox,
                              ),
                            ),
                            SizedBox(width: Responsive.width(ctx, 10)),
                            Expanded(
                              child: Container(
                                height: Responsive.height(ctx, 14),
                                decoration: BoxDecoration(
                                  color: c.iconBox,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              else if (items.isEmpty && !searched)
                Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: Responsive.height(ctx, 12),
                  ),
                  child: Text(
                    'No blocked users',
                    style: GoogleFonts.manrope(
                      fontSize: Responsive.font(ctx, 13),
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              else if (items.isNotEmpty)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: Responsive.height(ctx, 220),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: items.length + (hasMore ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i == items.length) {
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: Responsive.height(ctx, 8),
                          ),
                          child: GestureDetector(
                            onTap: () => fetchPage(setState),
                            child: Text(
                              'Load more',
                              style: GoogleFonts.manrope(
                                color: primary,
                                fontSize: Responsive.font(ctx, 12),
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }
                      final user = items[i];
                      final uid = user['uid'] as String;
                      final username = user['username'] as String? ?? 'Unknown';
                      return buildUserRow(
                        uid: uid,
                        username: username,
                        rawUser: user,
                        trailing: unblockButton(uid, username),
                      );
                    },
                  ),
                ),
              SizedBox(height: Responsive.height(ctx, 8)),
              TextButton(
                onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
                child: Text('Close', style: dialogButtonStyle()),
              ),
            ],
          );
        },
      ),
    );
  }

  // builds a single tappable row inside a frosted glass card
  // each row has: icon badge on the left, label + optional subtitle, and a trailing widget or chevron
  Widget buildPreferenceRow({
    required IconData icon,
    required String label,
    String? subtitle,
    Widget?
    trailing, // optional widget on the right (e.g. Switch, color preview)
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Responsive.scale(context, 12)),
        splashColor: appColor.withAlpha(100),
        highlightColor: appColor.withAlpha(15),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.width(context, 20),
            vertical: Responsive.height(context, 16),
          ),
          child: Row(
            children: [
              // Icon badge with themed background
              Container(
                padding: EdgeInsets.all(Responsive.scale(context, 8)),
                decoration: BoxDecoration(
                  color: cardColors(appColor).iconBox,
                  borderRadius: BorderRadius.circular(
                    Responsive.scale(context, 10),
                  ),
                  border: Border.all(
                    color: cardColors(appColor).iconBorder,
                    width: 1.5,
                  ),
                ),
                child: HugeIcon(
                  icon: icon,
                  color: onTheme(appColor),
                  size: Responsive.scale(context, 22),
                ),
              ),
              SizedBox(width: Responsive.width(context, 16)),
              // Label and subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.manrope(
                        fontSize: Responsive.font(context, 15),
                        color: onTheme(appColor),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      SizedBox(height: Responsive.height(context, 2)),
                      Text(
                        subtitle,
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 12),
                          color: onTheme(appColor),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                SizedBox(width: Responsive.width(context, 12)),
              // Show trailing widget if provided, otherwise show a chevron for tappable rows
              if (trailing != null)
                trailing
              else if (onTap != null)
                HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  color: onTheme(appColor),
                  size: Responsive.scale(context, 20),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Thin divider between rows inside a glass card
  Widget buildDivider() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Responsive.width(context, 20)),
      child: Divider(
        color: onTheme(appColor).withAlpha(120),
        height: 1,
        thickness: 1.5,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userData = ref.watch(userDataProvider).value;
    // Color swatch preview for the theme color row
    final colorPreview = Container(
      width: Responsive.scale(context, 32),
      height: Responsive.scale(context, 32),
      decoration: BoxDecoration(
        color: baseColor,
        shape: BoxShape.circle,
        border: Border.all(color: cardColors(appColor).iconBorder, width: 1.5),
      ),
    );

    return Container(
      decoration: BoxDecoration(gradient: buildThemeGradient(appColor)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.centeredHorizontalPadding(
                      context,
                      50,
                    ),
                    vertical: Responsive.height(context, 24),
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
                          child: themedIconBox(
                            context,
                            icon: Icons.arrow_back_ios_new,
                            color: appColor,
                            iconSize: 13,
                            padding: 12,
                            circle: true,
                            onTap: () => context.pop(),
                          ),
                        ),
                      ),
                      // Appearance section
                      sectionHeader(
                        "APPEARANCE",
                        context,
                        appColor: appColor,
                        padding: EdgeInsets.only(
                          bottom: Responsive.height(context, 4),
                          left: Responsive.width(context, 4),
                        ),
                      ),
                      frostedGlassCard(
                        context,
                        color: appColor,
                        child: Column(
                          children: [
                            buildPreferenceRow(
                              icon: HugeIcons.strokeRoundedPaintBoard,
                              label: "App Theme Color",
                              subtitle: "Customize your app's color scheme",
                              trailing: colorPreview,
                              onTap: showColorPickerDialog,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: Responsive.height(context, 28)),

                      // Profile section
                      sectionHeader(
                        "PROFILE",
                        context,
                        appColor: appColor,
                        padding: EdgeInsets.only(
                          bottom: Responsive.height(context, 4),
                          left: Responsive.width(context, 4),
                        ),
                      ),
                      frostedGlassCard(
                        context,
                        color: appColor,
                        child: Column(
                          children: [
                            buildPreferenceRow(
                              icon: HugeIcons.strokeRoundedCamera01,
                              label: "Profile Picture",
                              subtitle: "Update your profile picture",
                              onTap: pickProfileImage,
                            ),
                            buildDivider(),
                            buildPreferenceRow(
                              icon: HugeIcons.strokeRoundedUserCircle,
                              label: "Username",
                              subtitle: userData?.username != userData?.uid
                                  ? "Current username: ${userData?.username}"
                                  : "Set a display name",
                              onTap: () {
                                if (isGuest) {
                                  Guest.block(context);
                                  return;
                                }
                                showUsernameDialogBox(
                                  context,
                                  "Update your username",
                                  usernameController,
                                  ref,
                                  appColor,
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: Responsive.height(context, 28)),

                      // Units section
                      sectionHeader(
                        "UNITS",
                        context,
                        appColor: appColor,
                        padding: EdgeInsets.only(
                          bottom: Responsive.height(context, 4),
                          left: Responsive.width(context, 4),
                        ),
                      ),
                      frostedGlassCard(
                        context,
                        color: appColor,
                        child: Column(
                          children: [
                            buildPreferenceRow(
                              icon: HugeIcons.strokeRoundedRuler,
                              label: "Units",
                              subtitle: _units == 'metric'
                                  ? "kg, ml, cm"
                                  : "lbs, oz, ft",
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (final option in ['metric', 'imperial'])
                                    GestureDetector(
                                      onTap: () async {
                                        if (isGuest) {
                                          Guest.block(context);
                                          return;
                                        }
                                        if (_units == option) return;
                                        setState(() => _units = option);
                                        await ref
                                            .read(userDataProvider.notifier)
                                            .updateUnits(option, context);
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        margin: EdgeInsets.only(
                                          left: option == 'imperial'
                                              ? Responsive.width(context, 6)
                                              : 0,
                                        ),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: Responsive.width(
                                            context,
                                            12,
                                          ),
                                          vertical: Responsive.height(
                                            context,
                                            6,
                                          ),
                                        ),
                                        decoration: BoxDecoration(
                                          color: _units == option
                                              ? cardColors(appColor).iconBox
                                              : Colors.white.withAlpha(10),
                                          borderRadius: BorderRadius.circular(
                                            Responsive.scale(context, 8),
                                          ),
                                          border: Border.all(
                                            color: _units == option
                                                ? cardColors(appColor).border
                                                : cardColors(
                                                    appColor,
                                                  ).border.withAlpha(80),
                                          ),
                                        ),
                                        child: Text(
                                          option == 'metric'
                                              ? "Metric"
                                              : "Imperial",
                                          style: GoogleFonts.manrope(
                                            color: _units == option
                                                ? onTheme(appColor)
                                                : onTheme(
                                                    appColor,
                                                  ).withAlpha(140),
                                            fontSize: Responsive.font(
                                              context,
                                              12,
                                            ),
                                            fontWeight: _units == option
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: Responsive.height(context, 28)),

                      // Goals section
                      sectionHeader(
                        "GOALS",
                        context,
                        appColor: appColor,
                        padding: EdgeInsets.only(
                          bottom: Responsive.height(context, 4),
                          left: Responsive.width(context, 4),
                        ),
                      ),
                      frostedGlassCard(
                        context,
                        color: appColor,
                        child: Column(
                          children: [
                            buildPreferenceRow(
                              icon: HugeIcons.strokeRoundedApple01,
                              label: "Nutrition Goals",
                              subtitle: () {
                                final cal = userData?.caloriesGoal;
                                final pro = userData?.proteinGoal;
                                final carb = userData?.carbsGoal;
                                final fat = userData?.fatGoal;
                                final fiber = userData?.fiberGoal;
                                final sugar = userData?.sugarGoal;
                                final sodium = userData?.sodiumGoal;
                                if (cal == null &&
                                    pro == null &&
                                    carb == null &&
                                    fat == null &&
                                    fiber == null &&
                                    sugar == null &&
                                    sodium == null) {
                                  return "Current: None";
                                }
                                final parts = [
                                  if (cal != null) "$cal kcal",
                                  if (pro != null) "${pro}g protein",
                                  if (carb != null) "${carb}g carbs",
                                  if (fat != null) "${fat}g fat",
                                  if (fiber != null) "${fiber}g fiber",
                                  if (sugar != null) "${sugar}g sugar",
                                  if (sodium != null) "${sodium}mg sodium",
                                ];
                                return "Current: ${parts.join(' · ')}";
                              }(),
                              onTap: showNutritionGoalsDialog,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: Responsive.height(context, 16)),

                      frostedGlassCard(
                        context,
                        color: appColor,
                        child: Column(
                          children: [
                            buildPreferenceRow(
                              icon: HugeIcons.strokeRoundedWeightScale,
                              label: "Weight Goal",
                              subtitle: () {
                                final type = userData?.weightGoalType;
                                final kg = userData?.weightKgGoal;
                                final typePart = type != null
                                    ? type[0].toUpperCase() + type.substring(1)
                                    : null;
                                final weightPart = kg != null
                                    ? UnitConverter.displayWeightWithUnit(
                                        kg,
                                        imperial: _units == 'imperial',
                                      )
                                    : null;
                                final detail = [
                                  typePart,
                                  weightPart,
                                ].whereType<String>().join(' · ');
                                return detail.isEmpty
                                    ? "Current: None"
                                    : "Current: $detail";
                              }(),
                              onTap: showWeightGoalDialog,
                            ),
                            buildPreferenceRow(
                              icon: HugeIcons.strokeRoundedDumbbell01,
                              label: "Weekly Workout Goal",
                              subtitle: () {
                                final n = userData?.weeklyWorkoutsGoal;
                                return n == null
                                    ? "Current: None"
                                    : "Current: $n workouts/week";
                              }(),
                              onTap: showWeeklyWorkoutGoalDialog,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: Responsive.height(context, 16)),

                      frostedGlassCard(
                        context,
                        color: appColor,
                        child: Column(
                          children: [
                            buildPreferenceRow(
                              icon: HugeIcons.strokeRoundedDroplet,
                              label: "Water Goal",
                              subtitle: () {
                                final ml = userData?.waterMlGoal;
                                if (ml == null) return "Current: None";
                                return _units == 'metric'
                                    ? "Current: $ml ml"
                                    : "Current: ${UnitConverter.displayWater(ml, imperial: true, decimals: 0)} oz";
                              }(),
                              onTap: showWaterGoalDialog,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: Responsive.height(context, 28)),

                      // Food Logging section
                      // Notifications section
                      sectionHeader(
                        "NOTIFICATIONS",
                        context,
                        appColor: appColor,
                        padding: EdgeInsets.only(
                          bottom: Responsive.height(context, 4),
                          left: Responsive.width(context, 4),
                        ),
                      ),
                      frostedGlassCard(
                        context,
                        color: appColor,
                        child: Column(
                          children: [
                            // Master toggle
                            buildPreferenceRow(
                              icon: notificationsEnabled
                                  ? HugeIcons.strokeRoundedNotification01
                                  : HugeIcons.strokeRoundedNotificationOff01,
                              label: "Push Notifications",
                              subtitle: notificationsEnabled
                                  ? "Enabled"
                                  : "Disabled",
                              // Switch.adaptive uses the platform's native switch style (Material on Android, Cupertino on iOS)
                              trailing: Switch.adaptive(
                                value: notificationsEnabled,
                                activeThumbColor: onTheme(appColor),
                                activeTrackColor: cardColors(appColor).border,
                                inactiveThumbColor: onTheme(
                                  appColor,
                                ).withAlpha(120),
                                inactiveTrackColor: cardColors(
                                  appColor,
                                ).iconBox,
                                onChanged: (value) async {
                                  if (isGuest) {
                                    Guest.block(context);
                                    return;
                                  }
                                  setState(() => notificationsEnabled = value);
                                  await ref
                                      .read(userDataProvider.notifier)
                                      .updateNotificationsEnabled(
                                        value,
                                        context,
                                      );

                                  // If enabling on web, also request browser permission and get FCM token
                                  if (value && kIsWeb) {
                                    final token =
                                        await requestNotificationAndToken();
                                    if (token != null) {
                                      await ref
                                          .read(userDataProvider.notifier)
                                          .addFcmToken(token);
                                    } else if (mounted) {
                                      showBrowserBlockedDialog(
                                        context,
                                        ref.read(userDataProvider.notifier),
                                        appColor: appColor,
                                      ); // browser is blocking notifications
                                    }
                                  }
                                },
                              ),
                            ),

                            // Per-type toggles, only shown when master is on
                            AnimatedSize(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutQuart,
                              child: notificationsEnabled
                                  ? Column(
                                      children: [
                                        Divider(
                                          color: cardColors(
                                            appColor,
                                          ).border.withAlpha(80),
                                          height: 1,
                                          indent: Responsive.width(context, 16),
                                          endIndent: Responsive.width(
                                            context,
                                            16,
                                          ),
                                        ),
                                        _notifTypeRow(
                                          context,
                                          appColor: appColor,
                                          icon: HugeIcons.strokeRoundedGift,
                                          label: "Daily Reward",
                                          subtitle:
                                              "Remind me to claim my reward",
                                          value: _notifyDailyReward,
                                          onChanged: (v) {
                                            setState(
                                              () => _notifyDailyReward = v,
                                            );
                                            // TODO: save to backend notification_prefs
                                          },
                                        ),
                                        _notifTypeRow(
                                          context,
                                          appColor: appColor,
                                          icon:
                                              HugeIcons.strokeRoundedUserAdd01,
                                          label: "Friend Requests",
                                          subtitle: "When someone adds you",
                                          value: _notifyFriendRequests,
                                          onChanged: (v) {
                                            setState(
                                              () => _notifyFriendRequests = v,
                                            );
                                            // TODO: save to backend notification_prefs
                                          },
                                        ),
                                        _notifTypeRow(
                                          context,
                                          appColor: appColor,
                                          icon: HugeIcons
                                              .strokeRoundedNotification01,
                                          label: "Nudges",
                                          subtitle: "When a friend nudges you",
                                          value: _notifyNudges,
                                          onChanged: (v) {
                                            setState(() => _notifyNudges = v);
                                            // TODO: save to backend notification_prefs
                                          },
                                        ),
                                        _notifTypeRow(
                                          context,
                                          appColor: appColor,
                                          icon:
                                              HugeIcons.strokeRoundedAlarmClock,
                                          label: "Reminders",
                                          subtitle:
                                              "Custom reminders you've set",
                                          value: _notifyReminders,
                                          onChanged: (v) {
                                            setState(
                                              () => _notifyReminders = v,
                                            );
                                            // TODO: save to backend notification_prefs
                                          },
                                        ),
                                      ],
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: Responsive.height(context, 28)),
                      sectionHeader(
                        "SOCIAL",
                        context,
                        appColor: appColor,
                        padding: EdgeInsets.only(
                          bottom: Responsive.height(context, 4),
                          left: Responsive.width(context, 4),
                        ),
                      ),
                      frostedGlassCard(
                        context,
                        color: appColor,
                        child: Column(
                          children: [
                            buildPreferenceRow(
                              icon: HugeIcons.strokeRoundedUserRemove01,
                              label: 'Blocked Users',
                              subtitle: 'Manage who you have blocked',
                              onTap: () => _showBlockedUsersDialog(),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: Responsive.height(context, 40)),
                    ],
                  ),
                ),
              ),
              OnboardingHint(
                appColor: appColor,
                hintKey: 'settings',
                title: 'Set up your profile',
                description:
                    'Set a username, choose your units, adjust your goals, and more',
              ),
              if (_cropLoading)
                Container(
                  color: Colors.black54,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: onTheme(appColor)),
                        SizedBox(height: Responsive.height(context, 16)),
                        Text(
                          "Preparing image editor...",
                          style: TextStyle(color: onTheme(appColor)),
                        ),
                      ],
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
