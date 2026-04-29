import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '/globals.dart';
import '/services/user_data_manager.dart';
import '/utility/responsive.dart';
import '/services/fcm/notification_service.dart';
import 'dart:math';

Future<void> showUsernameDialogBox(
  BuildContext context,
  String title,
  TextEditingController usernameController,
) async {
  await showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      // dialogContext so that the snackbar works after popping
      backgroundColor: appColorNotifier.value.withAlpha(255),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Only show text if the user has set a username before
          if (currentUserData?.username != currentUserData?.uid)
            Text(
              "Current username: \n ${currentUserData?.username}",
              style: TextStyle(color: Colors.white70),
            ),
          SizedBox(height: 10),
          TextField(
            controller: usernameController,
            decoration: InputDecoration(
              hintText: "Enter a username.",
              hintStyle: TextStyle(color: Colors.white54),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
            ),
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
      actions: [
        Row(
          mainAxisAlignment:
              // spaceBetween so CANCEL appears at the left and CONFIRM at the right
              MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              child: Text("CANCEL", style: TextStyle(color: Colors.white)),
              // close if canceled
              onPressed: () => Navigator.pop(dialogContext),
            ),
            TextButton(
              child: Text("CONFIRM", style: TextStyle(color: Colors.white)),
              // Handle username update
              onPressed: () async {
                String updatedUsername = usernameController.text.trim();
                // Only pop if successful
                if (await UserDataManager().updateUsername(
                  updatedUsername,
                  context,
                )) {
                  Navigator.pop(dialogContext);
                }
              },
            ),
          ],
        ),
      ],
    ),
  ).then((_) {
    // Reset the text field after exiting the dialog box
    usernameController.text = "";
  });
}

class PersonalPreferences extends StatefulWidget {
  final VoidCallback?
  onProfileImageUpdated; // callback to notify HomeScreen when the profile picture is updated

  const PersonalPreferences({super.key, this.onProfileImageUpdated});

  @override
  State<PersonalPreferences> createState() => _PersonalPreferencesState();
}

class _PersonalPreferencesState extends State<PersonalPreferences> {
  TextEditingController usernameController = TextEditingController();

  @override
  void dispose() {
    usernameController.dispose(); // free resources and prevent memory leaks
    super.dispose();
  }

  Color baseColor =
      currentUserData!.appColor; // tracks the current theme color for the UI
  bool notificationsEnabled =
      currentUserData?.notificationsEnabled ??
      true; // tracks the notification toggle state
  bool _cropLoading = false;

  Future pickProfileImage() async {
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
            duration: Duration(milliseconds: 1500),
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
    return luminance > 0.7; // threshold for "too light"
  }

  double getDarknessMultiplier(Color color) {
    return max(
      (color.computeLuminance() - 0.7) *
          0.5, // the lighter the color, the more it gets darkened
      0.1,
    ); // lighter colors get darkened more, but minimum darkness multiplier is 0.1
  }

  Future<void> applyAppColor(Color color) async {
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
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
    baseColor = color;
    currentUserData!.appColor = color;
    appColorNotifier.value = color;
    await userManager.updateAppColor(color, context);
    setState(() {}); // refresh UI
  }

  void showColorPickerDialog() {
    Color pickerColor = baseColor.withAlpha(
      255,
    ); // .withAlpha(255) so the alpha circle is initially filled up
    // Dialog box prompting the chosen color
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: appColorNotifier.value.withAlpha(200),
          title: textWithFont(
            'Pick a theme color \n (Very light colors are not recommended)',
            context,
            0.075,
          ),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: pickerColor,
              onColorChanged: (color) {
                pickerColor = color;
              },
              labelTypes: [],
              enableAlpha: false, // disable the alpha slider
              pickerAreaHeightPercent: 0.8,
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity, // Make the row fill the dialog width
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween, // Space buttons evenly
                children: [
                  // Cancel selection
                  TextButton(
                    child: Text('Cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),

                  // Reset to default app color
                  TextButton(
                    child: Text('Default'),
                    onPressed: () async {
                      await applyAppColor(Color.fromARGB(255, 45, 45, 45));
                      Navigator.of(context).pop();
                    },
                  ),

                  // Confirm selection
                  TextButton(
                    child: Text('Select'),
                    onPressed: () async {
                      await applyAppColor(pickerColor);
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // opens a dialog to update the user's nutrition and weight goals
  Future<void> showGoalsDialog() async {
    // pre-fill with existing values if they exist
    final calCtrl = TextEditingController(
      text: currentUserData?.caloriesGoal?.toString() ?? '',
    );
    final proCtrl = TextEditingController(
      text: currentUserData?.proteinGoal?.toString() ?? '',
    );
    final carbCtrl = TextEditingController(
      text: currentUserData?.carbsGoal?.toString() ?? '',
    );
    final fatCtrl = TextEditingController(
      text: currentUserData?.fatGoal?.toString() ?? '',
    );
    String? weightGoal = currentUserData?.weightGoalType;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        // StatefulBuilder so the segmented button can update without rebuilding the whole screen
        return StatefulBuilder(
          builder: (sbContext, setDialogState) {
            return AlertDialog(
              backgroundColor: appColorNotifier.value.withAlpha(255),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                "Update Goals",
                style: TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _goalField(calCtrl, "Daily Calories (kcal)"),
                    _goalField(proCtrl, "Protein (g)"),
                    _goalField(carbCtrl, "Carbs (g)"),
                    _goalField(fatCtrl, "Fat (g)"),
                    SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Weight Goal",
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                    SizedBox(height: 6),
                    // segmented button so only one weight goal type can be selected at a time
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'lose', label: Text('Lose')),
                        ButtonSegment(
                          value: 'maintain',
                          label: Text('Maintain'),
                        ),
                        ButtonSegment(value: 'gain', label: Text('Gain')),
                      ],
                      selected: {if (weightGoal != null) weightGoal!},
                      emptySelectionAllowed: true, // allow deselecting
                      onSelectionChanged: (val) =>
                          setDialogState(() => weightGoal = val.firstOrNull),
                      style: ButtonStyle(
                        foregroundColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? Colors.white
                              : Colors.white54,
                        ),
                        backgroundColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? appColorNotifier.value
                              : Colors.transparent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      child: Text(
                        "CANCEL",
                        style: TextStyle(color: Colors.white),
                      ),
                      onPressed: () => Navigator.pop(dialogContext),
                    ),
                    TextButton(
                      child: Text(
                        "SAVE",
                        style: TextStyle(color: Colors.white),
                      ),
                      onPressed: () async {
                        await userManager.updateGoals(
                          caloriesGoal: int.tryParse(calCtrl.text.trim()),
                          proteinGoal: int.tryParse(proCtrl.text.trim()),
                          carbsGoal: int.tryParse(carbCtrl.text.trim()),
                          fatGoal: int.tryParse(fatCtrl.text.trim()),
                          weightGoalType: weightGoal,
                          context:
                              dialogContext, // dialogContext so snackbar works after popping
                        );
                        if (mounted) {
                          setState(() {}); // refresh subtitle with new values
                        }
                        Navigator.pop(dialogContext);
                      },
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  // single text field used inside the goals dialog
  Widget _goalField(TextEditingController ctrl, String hint) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white54),
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
        splashColor: appColorNotifier.value.withAlpha(100),
        highlightColor: appColorNotifier.value.withAlpha(15),
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
                  color: appColorNotifier.value.withAlpha(40),
                  borderRadius: BorderRadius.circular(
                    Responsive.scale(context, 10),
                  ),
                ),
                child: Icon(
                  icon,
                  // use white if default theme, otherwise lighten the user's chosen color
                  color:
                      appColorNotifier.value ==
                          const Color.fromARGB(255, 45, 45, 45)
                      ? Colors.white70
                      : lightenColor(appColorNotifier.value, 0.2),
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
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      SizedBox(height: Responsive.height(context, 2)),
                      Text(
                        subtitle,
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 12),
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Show trailing widget if provided, otherwise show a chevron for tappable rows
              if (trailing != null)
                trailing
              else if (onTap != null)
                Icon(
                  Icons.chevron_right,
                  color: Colors.white38,
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
    // Color swatch preview for the theme color row
    final colorPreview = Container(
      width: Responsive.scale(context, 24),
      height: Responsive.scale(context, 24),
      decoration: BoxDecoration(
        color: baseColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white38, width: 1.5),
      ),
    );

    return Container(
      decoration: BoxDecoration(gradient: buildThemeGradient()),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: darkenColor(appColorNotifier.value, 0.025),
          centerTitle: true,
          toolbarHeight: Responsive.height(context, 100),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
          title: createTitle("Personal Preferences", context),
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(Responsive.height(context, 1)),
            child: Container(
              height: Responsive.height(context, 1),
              color: Colors.white.withAlpha(25),
            ),
          ),
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.width(context, 50),
                  vertical: Responsive.height(context, 24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Appearance section
                    sectionHeader(
                      "APPEARANCE",
                      context,
                      padding: EdgeInsets.only(
                        bottom: Responsive.height(context, 10),
                        left: Responsive.width(context, 4),
                      ),
                    ),
                    frostedGlassCard(
                      context,
                      child: Column(
                        children: [
                          buildPreferenceRow(
                            icon: Icons.palette_outlined,
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
                        bottom: Responsive.height(context, 10),
                        left: Responsive.width(context, 4),
                      ),
                    ),
                    frostedGlassCard(
                      context,
                      child: Column(
                        children: [
                          buildPreferenceRow(
                            icon: Icons.camera_alt_outlined,
                            label: "Profile Picture",
                            subtitle: "Update your profile picture",
                            onTap: pickProfileImage,
                          ),
                          buildDivider(),
                          buildPreferenceRow(
                            icon: Icons.person_outline,
                            label: "Username",
                            subtitle:
                                currentUserData?.username !=
                                    currentUserData?.uid
                                ? "Current username: ${currentUserData?.username}"
                                : "Set a display name",
                            onTap: () => showUsernameDialogBox(
                              context,
                              "Update your username",
                              usernameController,
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
                        bottom: Responsive.height(context, 10),
                        left: Responsive.width(context, 4),
                      ),
                    ),
                    frostedGlassCard(
                      context,
                      child: Column(
                        children: [
                          buildPreferenceRow(
                            icon: Icons.track_changes_outlined,
                            label: "Nutrition and Weight Goals",
                            // show a summary of current goals if they exist
                            subtitle:
                                "Current goals:  "
                                "${currentUserData?.caloriesGoal != null ? '${currentUserData!.caloriesGoal} kcal' : 'no set calorie goal'}  ·  "
                                "${currentUserData?.proteinGoal != null ? '${currentUserData!.proteinGoal}g protein' : 'no set protein goal'}  ·  "
                                "${currentUserData?.carbsGoal != null ? '${currentUserData!.carbsGoal}g carbs' : 'no set carbs goal'}  ·  "
                                "${currentUserData?.fatGoal != null ? '${currentUserData!.fatGoal}g fat' : 'no set fat goal'}  ·  "
                                "${currentUserData?.weightGoalType != null ? 'goal: ${currentUserData!.weightGoalType}' : 'no weight goal'}",
                            onTap: showGoalsDialog,
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
                        bottom: Responsive.height(context, 10),
                        left: Responsive.width(context, 4),
                      ),
                    ),
                    frostedGlassCard(
                      context,
                      child: Column(
                        children: [
                          buildPreferenceRow(
                            icon: notificationsEnabled
                                ? Icons.notifications_active_outlined
                                : Icons.notifications_off_outlined,
                            label: "Push Notifications",
                            subtitle: notificationsEnabled
                                ? "Enabled"
                                : "Disabled",
                            // Switch.adaptive uses the platform's native switch style (Material on Android, Cupertino on iOS)
                            trailing: Switch.adaptive(
                              value: notificationsEnabled,
                              activeThumbColor:
                                  appColorNotifier.value ==
                                      const Color.fromARGB(255, 45, 45, 45)
                                  ? Colors.white70
                                  : lightenColor(appColorNotifier.value, 0.2),
                              activeTrackColor: appColorNotifier.value
                                  .withAlpha(100),
                              inactiveThumbColor: Colors.white38,
                              inactiveTrackColor: Colors.white.withAlpha(20),
                              onChanged: (value) async {
                                setState(() {
                                  notificationsEnabled = value;
                                });
                                // Save the preference to Firestore and locally
                                await userManager.updateNotificationsEnabled(
                                  value,
                                  context,
                                );
                                currentUserData!.notificationsEnabled = value;

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
    );
  }
}
