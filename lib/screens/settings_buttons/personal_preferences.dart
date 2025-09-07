import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '/globals.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

File? selectedProfileImage; // above classes to be globally accessible

class PersonalPreferences extends StatefulWidget {
  final VoidCallback? onProfileImageUpdated; // callback to call HomeScreen when the profile picture is updated
  const PersonalPreferences({super.key, this.onProfileImageUpdated});

  @override
  State<PersonalPreferences> createState() => _PersonalPreferencesState();
}

class _PersonalPreferencesState extends State<PersonalPreferences> {
  
  File? _selectedImage;

  Future _imageFromGallery() async {
    final returnedImage = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );

    if (!mounted) return; // !mounted means Widget is not in the widget tree, so do not set state to the invalid widget tree

    setState(() {
      if (returnedImage != null) {
        _selectedImage = File(returnedImage.path);
        selectedProfileImage =
            _selectedImage; // store to retrieve in footer.dart
            widget.onProfileImageUpdated?.call(); // trigger HomeScreen rebuild
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Profile picture successfully updated."),
                duration: Duration(milliseconds: 1500)
              )
            );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight =
        1.sh; // Make widgets the size of the user's personal screen size
    double screenWidth =
        1.sw; // Make widgets the size of the user's personal screen size
    return Scaffold(
      backgroundColor: Color(0xFF1E1E1E),
      // Header box
      appBar: AppBar(
        backgroundColor: Color(0xFF121212),
        centerTitle: true,
        toolbarHeight: screenHeight * 0.15,
        title: createTitle("Preferences", screenWidth),
      ),
      body: Column(
        children: [
          // Middle body
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
                          // to explicitly control the ElevatedButton size
                          height: screenHeight * 0.15,
                          width: screenWidth * 0.90,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              backgroundColor: Color(
                                0xFF2A2A2A,
                              ), // Actual button color
                              foregroundColor:
                                  Colors.white, // Button text color
                              side: BorderSide(
                                color: Colors.black,
                                width: screenWidth * 0.005,
                              ),
                            ),
                            onPressed: () {
                              _imageFromGallery();
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
