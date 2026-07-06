import 'dart:async';
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
import '/services/recent_foods_service.dart';
import 'dart:math';

Future<void> showUsernameDialogBox(
  BuildContext context,
  String title,
  TextEditingController usernameController,
) async {
  await showFrostedAlertDialog(
    context: context,
    title: title,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Only show text if the user has set a username before
        if (currentUserData?.username != currentUserData?.uid)
          Text(
            "Current username: \n ${currentUserData?.username}",
            style: GoogleFonts.manrope(color: Colors.white70),
          ),
        SizedBox(height: 10),
        TextField(
          controller: usernameController,
          style: TextStyle(color: Colors.white),
        ),
      ],
    ),
    actions: [
      TextButton(
        // close if canceled
        onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
        child: Text("Cancel", style: dialogButtonStyle()),
      ),
      TextButton(
        // Handle username update
        onPressed: () async {
          final updatedUsername = usernameController.text.trim();
          if (updatedUsername.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Please enter a username."),
                duration: snackBarDuration,
              ),
            );
            return;
          }
          if (updatedUsername.length > 20) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Username must be 20 characters or fewer."),
                duration: snackBarDuration,
              ),
            );
            return;
          }
          // Only pop if successful
          if (await UserDataManager().updateUsername(
            updatedUsername,
            context,
          )) {
            Navigator.of(context, rootNavigator: true).pop();
          }
        },
        child: Text("Confirm", style: dialogButtonStyle(confirm: true)),
      ),
    ],
  ).then((_) {
    // Reset the text field after exiting the dialog box
    usernameController.text = "";
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
  Color get appColor =>
      ref.read(userDataProvider).value?.appColor ?? defaultAppColor;

  TextEditingController usernameController = TextEditingController();
  late AnimationController _colorAnimController;
  late Color _animFromColor;

  @override
  void dispose() {
    _colorAnimController.dispose();
    usernameController.dispose();
    super.dispose();
  }

  Color baseColor =
      currentUserData!.appColor; // tracks the current theme color for the UI
  bool notificationsEnabled =
      currentUserData?.notificationsEnabled ??
      true; // tracks the notification toggle state
  String _units = currentUserData?.units ?? 'metric';
  bool _cropLoading = false;
  int _recentFoodsMax =
      30; // current max, RecentFoodsService.unlimited (0) = unlimited

  final _recentFoodsService = RecentFoodsService();

  @override
  void initState() {
    super.initState();
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
    _recentFoodsService.getRecentFoodsMax().then((val) {
      if (mounted && val != null) setState(() => _recentFoodsMax = val);
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
          await userManager.updateProfilePicture(
            null,
            context: context,
            onProfileUpdated: widget.onProfileImageUpdated,
            imageInBytes: imageBytes,
          );
        } else {
          await userManager.updateProfilePicture(
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

  bool isColorTooLight(Color color) {
    // calculate the relative luminance of the color (0 = black, 1 = white)
    double luminance = color.computeLuminance();
    return luminance > 0.5; // threshold for "too light"
  }

  double getDarknessMultiplier(Color color) {
    return max(
      (color.computeLuminance() - 0.5) *
          0.8, // the lighter the color, the more it gets darkened
      0.15,
    ); // lighter colors get darkened more, but minimum darkness multiplier is 0.1
  }

  Future<void> applyAppColor(Color color) async {
    if (isGuest) {
      Guest.block(context);
      return;
    }
    // Check if the color is too light for white text / cards to be visible, and if so, darken it slightly
    if (isColorTooLight(color)) {
      color = darkenColor(color, getDarknessMultiplier(color));
      // show a snackbar explaining that the color was adjusted for better visibility
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "The selected color was too light, so it has been slightly darkened to improve visibility.",
            ),
            duration: snackBarDurationImportant,
          ),
        );
      }
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
    } // For guest users
    Color pickerColor = baseColor.withAlpha(
      255,
    ); // .withAlpha(255) so the alpha circle is initially filled up
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
                    color: Colors.white.withAlpha(22),
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
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.manrope(color: Colors.white54),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            await applyAppColor(defaultAppColor);
                            Navigator.of(ctx).pop();
                          },
                          child: Text(
                            'Default',
                            style: GoogleFonts.manrope(color: Colors.white54),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            await applyAppColor(pickerColor);
                            Navigator.of(ctx).pop();
                          },
                          child: Text(
                            'Select',
                            style: GoogleFonts.manrope(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
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
    final calCtrl = TextEditingController(
      text: ref.read(userDataProvider).value?.caloriesGoal?.toString() ?? '',
    );
    final proCtrl = TextEditingController(
      text: ref.read(userDataProvider).value?.proteinGoal?.toString() ?? '',
    );
    final carbCtrl = TextEditingController(
      text: ref.read(userDataProvider).value?.carbsGoal?.toString() ?? '',
    );
    final fatCtrl = TextEditingController(
      text: ref.read(userDataProvider).value?.fatGoal?.toString() ?? '',
    );

    await showFrostedAlertDialog(
      context: context,
      title: "Nutrition Goals",
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _goalField(calCtrl, "Daily Calories (kcal)", maxLength: 5),
            _goalField(proCtrl, "Protein (g)"),
            _goalField(carbCtrl, "Carbs (g)"),
            _goalField(fatCtrl, "Fat (g)"),
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
            await userManager.updateNutritionGoals(
              caloriesGoal: int.tryParse(calCtrl.text.trim()),
              proteinGoal: int.tryParse(proCtrl.text.trim()),
              carbsGoal: int.tryParse(carbCtrl.text.trim()),
              fatGoal: int.tryParse(fatCtrl.text.trim()),
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
                  color: Colors.white70,
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
                                  ? Colors.white.withAlpha(28)
                                  : Colors.white.withAlpha(10),
                              borderRadius: BorderRadius.circular(
                                Responsive.scale(context, 10),
                              ),
                              border: Border.all(
                                color: weightGoalType == option
                                    ? Colors.white.withAlpha(80)
                                    : Colors.white.withAlpha(25),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              option[0].toUpperCase() + option.substring(1),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.manrope(
                                color: weightGoalType == option
                                    ? Colors.white
                                    : Colors.white54,
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
            await userManager.updateWeightGoal(
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
      title: "Weekly Workout Goal",
      content: StatefulBuilder(
        builder: (sbContext, setDialogState) {
          final accent = lightenColor(appColor, 0.45);
          final dim = lightenColor(appColor, 0.35);
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
                      color: selected > 1 ? accent : Colors.white24,
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
                      color: selected < 7 ? accent : Colors.white24,
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
            await userManager.updateGoals(
              weeklyWorkoutsGoal: selected,
              context: context,
            );
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
            await userManager.updateWaterGoal(
              waterMlGoal: waterMl,
              context: context,
            );
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
        decoration: InputDecoration(
          labelText: hint,
          labelStyle: TextStyle(color: Colors.white54),
          floatingLabelStyle: TextStyle(color: Colors.white70),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white24),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white),
          ),
        ),
        style: TextStyle(color: Colors.white),
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
          FilteringTextInputFormatter.allow(
            RegExp(r'^\d{0,4}\.?\d{0,1}'),
          ), // up to 4 digits, optional decimal, 1 decimal place
        ],
        decoration: InputDecoration(
          labelText: hint,
          labelStyle: TextStyle(color: Colors.white54),
          floatingLabelStyle: TextStyle(color: Colors.white70),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white24),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white),
          ),
        ),
        style: TextStyle(color: Colors.white),
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
                  color: lightenColor(appColor, 0.05).withAlpha(80),
                  borderRadius: BorderRadius.circular(
                    Responsive.scale(context, 10),
                  ),
                  border: Border.all(
                    color: lightenColor(appColor, 0.25).withAlpha(60),
                    width: Responsive.width(context, 2),
                  ),
                ),
                child: HugeIcon(
                  icon: icon,
                  color: appColor == defaultAppColor
                      ? Colors.white70
                      : lightenColor(appColor, 0.2),
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
                        color: lightenColor(appColor, 0.45),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      SizedBox(height: Responsive.height(context, 2)),
                      Text(
                        subtitle,
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 12),
                          color: lightenColor(appColor, 0.45),
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
                  color: lightenColor(appColor, 0.45),
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
        color: Colors.white.withAlpha(20),
        height: 1,
        thickness: 1,
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
        border: Border.all(color: Colors.white.withAlpha(60), width: 1.5),
      ),
    );

    return Container(
      decoration: BoxDecoration(gradient: buildThemeGradient()),
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
                          child: GestureDetector(
                            onTap: () => context.pop(),
                            child: Container(
                              padding: EdgeInsets.all(
                                Responsive.scale(context, 12),
                              ),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: lightenColor(
                                  appColor,
                                  0.1,
                                ).withAlpha(20),
                                border: Border.all(
                                  color: lightenColor(
                                    appColor,
                                    0.3,
                                  ).withAlpha(180),
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(
                                Icons.arrow_back_ios_new,
                                color: lightenColor(
                                  appColor,
                                  0.3,
                                ).withAlpha(180),
                                size: Responsive.font(context, 13),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Appearance section
                      sectionHeader(
                        "APPEARANCE",
                        context,
                        padding: EdgeInsets.only(
                          bottom: Responsive.height(context, 4),
                          left: Responsive.width(context, 4),
                        ),
                      ),
                      frostedGlassCard(
                        context,
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
                        padding: EdgeInsets.only(
                          bottom: Responsive.height(context, 4),
                          left: Responsive.width(context, 4),
                        ),
                      ),
                      frostedGlassCard(
                        context,
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
                        padding: EdgeInsets.only(
                          bottom: Responsive.height(context, 4),
                          left: Responsive.width(context, 4),
                        ),
                      ),
                      frostedGlassCard(
                        context,
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
                                        await userManager.updateUnits(
                                          option,
                                          context,
                                        );
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
                                              ? Colors.white.withAlpha(28)
                                              : Colors.white.withAlpha(10),
                                          borderRadius: BorderRadius.circular(
                                            Responsive.scale(context, 8),
                                          ),
                                          border: Border.all(
                                            color: _units == option
                                                ? Colors.white.withAlpha(80)
                                                : Colors.white.withAlpha(25),
                                          ),
                                        ),
                                        child: Text(
                                          option == 'metric'
                                              ? "Metric"
                                              : "Imperial",
                                          style: GoogleFonts.manrope(
                                            color: _units == option
                                                ? Colors.white
                                                : Colors.white38,
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
                        padding: EdgeInsets.only(
                          bottom: Responsive.height(context, 4),
                          left: Responsive.width(context, 4),
                        ),
                      ),
                      frostedGlassCard(
                        context,
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
                                if (cal == null &&
                                    pro == null &&
                                    carb == null &&
                                    fat == null) {
                                  return "Current: None";
                                }
                                final parts = [
                                  if (cal != null) "$cal kcal",
                                  if (pro != null) "${pro}g protein",
                                  if (carb != null) "${carb}g carbs",
                                  if (fat != null) "${fat}g fat",
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
                      sectionHeader(
                        "FOOD LOGGING",
                        context,
                        padding: EdgeInsets.only(
                          bottom: Responsive.height(context, 4),
                          left: Responsive.width(context, 4),
                        ),
                      ),
                      frostedGlassCard(
                        context,
                        child: Column(
                          children: [
                            buildPreferenceRow(
                              icon: HugeIcons.strokeRoundedClock01,
                              label: "Recent Foods Limit",
                              subtitle:
                                  _recentFoodsMax ==
                                      RecentFoodsService.unlimited
                                  ? "No limit"
                                  : "Up to $_recentFoodsMax foods",
                              onTap: () async {
                                if (isGuest) {
                                  Guest.block(context);
                                  return;
                                }
                                final options = [
                                  10,
                                  20,
                                  30,
                                  50,
                                  100,
                                  RecentFoodsService.unlimited,
                                ];
                                final labels = [
                                  "10",
                                  "20",
                                  "30",
                                  "50",
                                  "100",
                                  "Unlimited",
                                ];
                                await showFrostedAlertDialog<void>(
                                  context: context,
                                  title: "Recent Foods Limit",
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      for (int i = 0; i < options.length; i++)
                                        GestureDetector(
                                          onTap: () async {
                                            await _recentFoodsService
                                                .setRecentFoodsMax(options[i]);
                                            if (mounted) {
                                              setState(
                                                () => _recentFoodsMax =
                                                    options[i],
                                              );
                                            }
                                            if (context.mounted) {
                                              Navigator.pop(context);
                                              final label =
                                                  options[i] ==
                                                      RecentFoodsService
                                                          .unlimited
                                                  ? "Unlimited"
                                                  : "${options[i]} foods";
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    "Recent foods limit set to $label",
                                                  ),
                                                  duration: snackBarDuration,
                                                ),
                                              );
                                            }
                                          },
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: Responsive.height(
                                                context,
                                                10,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  labels[i],
                                                  style: GoogleFonts.manrope(
                                                    fontSize: Responsive.font(
                                                      context,
                                                      15,
                                                    ),
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                if (_recentFoodsMax ==
                                                    options[i])
                                                  Icon(
                                                    Icons.check,
                                                    color: Colors.white,
                                                    size: Responsive.scale(
                                                      context,
                                                      18,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  actions: [
                                    Expanded(
                                      child: Center(
                                        child: TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: Text(
                                            "Cancel",
                                            style: dialogButtonStyle(),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: Responsive.height(context, 28)),

                      // Notifications section
                      sectionHeader(
                        "NOTIFICATIONS",
                        context,
                        padding: EdgeInsets.only(
                          bottom: Responsive.height(context, 4),
                          left: Responsive.width(context, 4),
                        ),
                      ),
                      frostedGlassCard(
                        context,
                        child: Column(
                          children: [
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
                                activeThumbColor: appColor == defaultAppColor
                                    ? Colors.white70
                                    : lightenColor(appColor, 0.2),
                                activeTrackColor: appColor.withAlpha(100),
                                inactiveThumbColor: Colors.white38,
                                inactiveTrackColor: Colors.white.withAlpha(20),
                                onChanged: (value) async {
                                  if (isGuest) {
                                    Guest.block(context);
                                    return;
                                  }
                                  setState(() {
                                    notificationsEnabled = value;
                                  });
                                  await ref
                                      .read(userDataProvider.notifier)
                                      .setNotificationsEnabled(value, context);

                                  // If enabling on web, also request browser permission and get FCM token
                                  if (value && kIsWeb) {
                                    final token =
                                        await requestNotificationAndToken();
                                    if (token != null) {
                                      await userManager.addFcmToken(token);
                                    } else if (mounted) {
                                      showBrowserBlockedDialog(
                                        context,
                                      ); // browser is blocking notifications
                                    }
                                  }
                                },
                              ),
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
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: Responsive.height(context, 16)),
                        Text(
                          "Preparing image editor...",
                          style: TextStyle(color: Colors.white),
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
