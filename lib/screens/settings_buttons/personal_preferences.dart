import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '/globals.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class PersonalPreferences extends StatefulWidget {
  const PersonalPreferences({super.key});

  @override
  State<PersonalPreferences> createState() => _PersonalPreferencesState();
}

class _PersonalPreferencesState extends State<PersonalPreferences> {
  File? _selectedImage;

  Future _imageFromGallery() async {
    final returnedImage = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    setState(() {
      _selectedImage = File(returnedImage!.path);
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
          _selectedImage != null
              ? Image.file(
                  _selectedImage!,
                  width: 200,
                  height: 200,
                  fit: BoxFit.cover,
                )
              : const Text("Please select an image"),
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
                        // CALORIE CALCULATOR BUTTON
                        ElevatedButton(
                          onPressed: () {
                            _imageFromGallery();
                          },
                          child: Text("Choose an image"),
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
