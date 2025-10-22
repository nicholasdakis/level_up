import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '/globals.dart';
import 'dart:io'; // for base64
import 'package:image_picker/image_picker.dart';
import '/user/user_data_manager.dart';

class PersonalPreferences extends StatefulWidget {
  final VoidCallback?
  onProfileImageUpdated; // callback to call HomeScreen when the profile picture is updated
  const PersonalPreferences({super.key, this.onProfileImageUpdated});

  @override
  State<PersonalPreferences> createState() => _PersonalPreferencesState();
}

class _PersonalPreferencesState extends State<PersonalPreferences> {
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
                        SizedBox(
                          height: screenHeight * 0.15,
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
                              "Update Profile Picture",
                              screenWidth * 0.1,
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
