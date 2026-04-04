import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '/globals.dart';
import '/user/user_data_manager.dart';
import '/utility/responsive.dart';
import '/utility/notification_service.dart';
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
          // Only show text if the username has set a username before
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
              // spaceBetween so CANCEL appears in the left-most part of the box and CONFIRM at the right-most
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
  onProfileImageUpdated; // callback to call HomeScreen when the profile picture is updated

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

  Future pickProfileImage() async {
    final returnedImage = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (!mounted || returnedImage == null) return; // stop if user canceled

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
          title: textWithFont('Pick theme color', context, 0.075),
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

                  // Default app color
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

  // Builds a single tappable row inside a frosted glass card
  // Each row has: icon badge on the left, label + optional subtitle, and a trailing widget or chevron
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
        splashColor: appColorNotifier.value.withAlpha(30),
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
              if (trailing != null) trailing,
              if (trailing == null && onTap != null)
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

  // Section header label (e.g. "APPEARANCE", "PROFILE", "NOTIFICATIONS")
  Widget buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: Responsive.height(context, 10),
        left: Responsive.width(context, 4),
      ),
      child: Text(
        title,
        style: GoogleFonts.manrope(
          fontSize: Responsive.font(context, 11),
          color: Colors.white38,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
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
          title: createTitle("Preferences", context),
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
                // Appearance section
                buildSectionHeader("APPEARANCE"),
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
                buildSectionHeader("PROFILE"),
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
                            currentUserData?.username != currentUserData?.uid
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

                // Notifications section
                buildSectionHeader("NOTIFICATIONS"),
                frostedGlassCard(
                  context,
                  child: Column(
                    children: [
                      buildPreferenceRow(
                        icon: notificationsEnabled
                            ? Icons.notifications_active_outlined
                            : Icons.notifications_off_outlined,
                        label: "Push Notifications",
                        subtitle: notificationsEnabled ? "Enabled" : "Disabled",
                        // Switch.adaptive uses the platform's native switch style (Material on Android, Cupertino on iOS)
                        trailing: Switch.adaptive(
                          value: notificationsEnabled,
                          activeThumbColor:
                              appColorNotifier.value ==
                                  const Color.fromARGB(255, 45, 45, 45)
                              ? Colors.white70
                              : lightenColor(appColorNotifier.value, 0.2),
                          activeTrackColor: appColorNotifier.value.withAlpha(
                            100,
                          ),
                          inactiveThumbColor: Colors.white38,
                          inactiveTrackColor: Colors.white.withAlpha(20),
                          onChanged: (value) async {
                            setState(() {
                              notificationsEnabled = value;
                            });
                            // Save the preference to Firestore and locally
                            await userManager.updateNotificationsEnabled(value);
                            currentUserData!.notificationsEnabled = value;

                            // If enabling on web, also request browser permission and get FCM token
                            if (value && kIsWeb) {
                              final token = await requestNotificationAndToken();
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

                SizedBox(height: Responsive.height(context, 24)),

                // Hint text about profile pictures
                Text(
                  "Please wait for the cropping screen to appear upon choosing a profile picture. This may take a few seconds for larger photos.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: Responsive.font(context, 20),
                    color: Colors.white24,
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
}
