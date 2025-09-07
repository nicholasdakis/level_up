import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../globals.dart';
import '../home_screen.dart';

class RegisterOrLogin extends StatefulWidget {
  const RegisterOrLogin({super.key});

  @override
  State<RegisterOrLogin> createState() => _RegisterOrLoginState();
}

class _RegisterOrLoginState extends State<RegisterOrLogin> {
  @override
  Widget build(BuildContext context) {
    double screenHeight = 1.sh;
    double screenWidth = 1.sw;
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(screenHeight * 0.15),
        child: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: const Color(0xFF121212),
          centerTitle: true,
          toolbarHeight: screenHeight * 0.5,
          elevation: 0,
          title: createTitle("Welcome!", screenWidth),
          flexibleSpace: Center(
            child: Padding(padding: EdgeInsets.only(top: screenWidth * 0.125)),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(screenHeight * 0.02),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              customButton(
                "Test",
                16,
                screenHeight,
                screenWidth,
                context,
                destination: const HomeScreen(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
