import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '/globals.dart';
import 'dart:io'; // for base64
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '/user/user_data_manager.dart';

class PersonalPreferences extends StatefulWidget {
  final VoidCallback?
  onProfileImageUpdated; // callback to call HomeScreen when the profile picture is updated

  const PersonalPreferences({super.key, this.onProfileImageUpdated});

  @override
  State<PersonalPreferences> createState() => _PersonalPreferencesState();
}

class _PersonalPreferencesState extends State<PersonalPreferences> {
  TextEditingController? usernameController =
      TextEditingController(); // controller to read the user's input for username change

  Future _pickProfileImage() async {
    final returnedImage = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (!mounted || returnedImage == null) return; // stop if user canceled

    final file = File(returnedImage.path);

    try {
      await UserDataManager().updateProfilePicture(
        file,
        onProfileUpdated: widget.onProfileImageUpdated,
        context: context,
      );

      if (mounted) {
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

  @override
  Widget build(BuildContext context) {
    double screenHeight = 1.sh;
    double screenWidth = 1.sw;
    return Scaffold(
      backgroundColor: Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: Color(0xFF121212),
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
                        // Update profile picture button
                        SizedBox(
                          height: screenHeight * 0.1,
                          width: screenWidth * 0.90,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              backgroundColor: Color(0xFF2A2A2A),
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.black,
                                width: screenWidth * 0.005,
                              ),
                            ),
                            onPressed: () {
                              _pickProfileImage();
                            },
                            child: buttonText(
                              "Profile Picture",
                              screenWidth * 0.1,
                            ),
                          ),
                        ),
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
                        // Update username button
                        SizedBox(
                          height: screenHeight * 0.1,
                          width: screenWidth * 0.90,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              backgroundColor: Color(0xFF2A2A2A),
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.black,
                                width: screenWidth * 0.005,
                              ),
                            ),
                            onPressed: () {
                              // Dialog box for updating username
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: Colors.grey[900],
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  title: Text(
                                    "Update your username",
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                          // close if canceled
                                          onPressed: () =>
                                              Navigator.pop(context),
                                        ),
                                        TextButton(
                                          child: Text(
                                            "CONFIRM",
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                          // Handle username update
                                          onPressed: () {
                                            String updatedUsername =
                                                usernameController!.text.trim();
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
                                usernameController!.text = "";
                              });
                            },
                            child: buttonText("Username", screenWidth * 0.1),
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
