import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '/globals.dart';
import 'dart:io'; // for base64
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '/user/user_data_manager.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class PersonalPreferences extends StatefulWidget {
  final VoidCallback?
  onProfileImageUpdated; // callback to call HomeScreen when the profile picture is updated

  const PersonalPreferences({super.key, this.onProfileImageUpdated});

  @override
  State<PersonalPreferences> createState() => _PersonalPreferencesState();
}

class _PersonalPreferencesState extends State<PersonalPreferences> {
  TextEditingController usernameController =
      TextEditingController(); // controller to read the user's input for username change

  @override
  void dispose() {
    usernameController.dispose(); // free resources and prevent memory leaks
    super.dispose();
  }

  Color baseColor = currentUserData!.appColor;

  // Method for picking the profile picture
  Future _pickProfileImage() async {
    final returnedImage = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (!mounted || returnedImage == null) return; // stop if user canceled

    final file = File(returnedImage.path);

    try {
      // await the boolean flag to make sure the update will be valid
      final canUpdate = await userManager.canUpdateProfilePicture(
        file,
        context,
      );

      // Case 1: can't update
      if (!canUpdate) {
        return;
      }

      // Case 2: update
      if (mounted && canUpdate) {
        // Update pfp
        await userManager.updateProfilePicture(
          file,
          context: context,
          onProfileUpdated: widget.onProfileImageUpdated,
        );

        // Confirmation snackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Profile picture successfully updated."),
            duration: Duration(milliseconds: 1500),
          ),
        );
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

  Future<void> _applyAppColor(Color color) async {
    baseColor = color;
    currentUserData!.appColor = color;
    appColorNotifier.value = color;
    await userManager.updateAppColor(color, context);
    setState(() {}); // refresh UI
  }

  // Method for the app theme color picker
  void _showColorPicker() {
    Color pickerColor = baseColor.withAlpha(
      255,
    ); // .withAlpha(255) so the alpha circle is initially filled up
    double screenWidth = 1.sw;
    // Dialog box prompting the chosen color
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: appColorNotifier.value.withAlpha(200),
          title: textWithFont('Pick theme color', screenWidth, 0.075),
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
                      await _applyAppColor(Color.fromARGB(255, 45, 45, 45));
                      Navigator.of(context).pop();
                    },
                  ),

                  // Confirm selection
                  TextButton(
                    child: Text('Select'),
                    onPressed: () async {
                      await _applyAppColor(pickerColor);
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

  @override
  Widget build(BuildContext context) {
    double screenHeight = 1.sh;
    double screenWidth = 1.sw;
    return Scaffold(
      backgroundColor: appColorNotifier.value.withAlpha(128), // Body color
      // Header box
      appBar: AppBar(
        backgroundColor: appColorNotifier.value.withAlpha(64), // Header color
        centerTitle: true,
        toolbarHeight: screenHeight * 0.15,
        title: createTitle("Preferences", screenWidth),
      ),
      body: Column(
        children: [
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(screenHeight * 0.02),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Button for choosing the app-theme color
                        simpleCustomButton(
                          "App Theme Color",
                          context,
                          baseColor: baseColor,
                          onPressed: () {
                            _showColorPicker();
                          },
                        ),
                        // spacing
                        SizedBox(height: screenHeight * 0.02),
                        // Update pfp button
                        simpleCustomButton(
                          "Profile Picture",
                          context,
                          baseColor: baseColor,
                          onPressed: _pickProfileImage,
                        ),
                        // spacing
                        SizedBox(height: screenHeight * 0.02),
                        // Update username button
                        simpleCustomButton(
                          "Username",
                          context,
                          baseColor: baseColor,
                          onPressed: () {
                            // Dialog box for updating username
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: appColorNotifier.value
                                    .withAlpha(255),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                title: Text(
                                  "Update your username",
                                  style: TextStyle(color: Colors.white),
                                ),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Current username: \n ${currentUserData?.username ?? ''}",
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                    SizedBox(height: 10),
                                    TextField(
                                      controller: usernameController,
                                      decoration: InputDecoration(
                                        hintText:
                                            "Enter your updated username.",
                                        hintStyle: TextStyle(
                                          color: Colors.white54,
                                        ),
                                        enabledBorder: UnderlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Colors.white24,
                                          ),
                                        ),
                                        focusedBorder: UnderlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Colors.white,
                                          ),
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
                                        child: Text(
                                          "CANCEL",
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        // close if canceled
                                        onPressed: () => Navigator.pop(context),
                                      ),
                                      TextButton(
                                        child: Text(
                                          "CONFIRM",
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        // Handle username update
                                        onPressed: () {
                                          String updatedUsername =
                                              usernameController.text.trim();
                                          UserDataManager().updateUsername(
                                            updatedUsername,
                                            context,
                                          );
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
                          },
                        ),
                        // text under Username button informing user
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: SizedBox(
                            height: screenHeight * 0.05,
                            child: Text(
                              "Please wait for confirmation that your profile picture has been updated before exiting this screen.",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.manrope(
                                fontSize: screenWidth * 0.03,
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
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
