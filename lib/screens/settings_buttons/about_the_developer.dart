import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '/globals.dart';

class AboutTheDeveloper extends StatefulWidget {
  const AboutTheDeveloper({super.key});

  @override
  State<AboutTheDeveloper> createState() => _AboutTheDeveloperState();
}

class _AboutTheDeveloperState extends State<AboutTheDeveloper> {
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
        title: createTitle("Developer", screenWidth),
      ),
      body: Center(child: Text("About The Developer tab")),
    );
  }
}
