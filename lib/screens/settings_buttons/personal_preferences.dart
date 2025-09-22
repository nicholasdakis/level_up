import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '/globals.dart';
import 'package:level_up/authentication/user_data.dart';
import 'dart:io';
import 'dart:convert'; // for base64
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PersonalPreferences extends StatefulWidget {
  final VoidCallback?
  onProfileImageUpdated; // callback to call HomeScreen when the profile picture is updated
  const PersonalPreferences({super.key, this.onProfileImageUpdated});

  @override
  State<PersonalPreferences> createState() => _PersonalPreferencesState();
}

class _PersonalPreferencesState extends State<PersonalPreferences> {
  Future _imageFromGallery() async {
    // Let the user pick an image
    final returnedImage = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );

    if (!mounted || returnedImage == null) {
      return; // stop if the user exited without picking a profile picture
    }

    final file = File(returnedImage.path);

    try {
      // 1. Convert image to Base64
      final bytes = await file.readAsBytes();
      final base64String = base64Encode(bytes);

      // 2. Save Base64 string in Firestore
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'pfpBase64': base64String,
      }, SetOptions(merge: true));

      // 3. Update currentUser with the base64 string
      setState(() {
        currentUser = UserData(uid: currentUser!.uid, pfpBase64: base64String);
      });
      widget.onProfileImageUpdated?.call(); // rebuild HomeScreen
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
