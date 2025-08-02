import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375,812), // Base size, scales from this
      minTextAdapt: true, // Keep text readable on very small screens
      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          home: child,
        );
      },
      child: const HomeScreen()
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height; // Make widgets the size of the user's personal screen size
    double screenWidth = MediaQuery.of(context).size.width; // Make widgets the size of the user's personal screen size
    return Scaffold(
        backgroundColor:Color(0xFF1E1E1E),
        body: Column(
          children: [
            // Header box
            Container(
            height: screenHeight * 0.15,
            width: screenWidth,
            color: Color(0xFF121212),
            padding: EdgeInsets.all(25),
              child: Center (
                child: Text(
                "Level Up!",
                style: GoogleFonts.russoOne(
                  fontSize: screenWidth*0.15,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      offset: Offset(4,4),
                      blurRadius: 10,
                      color: const Color.fromARGB(255, 0, 0, 0)
                    )
                  ]
                  )
                )
              )
          ),
          // Middle body
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(screenHeight*0.02),
                child: Column(
                  children: [
                    SizedBox( // to explicitly control the ElevatedButton size
                    height: screenHeight*0.11,
                    width: screenWidth*0.80,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: screenWidth*0.05, vertical: screenHeight*0.03),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)
                        ),
                        backgroundColor: Color(0xFF2A2A2A), // Actual button color
                        foregroundColor: Colors.white, // Button text color
                        side: BorderSide(
                          color: Colors.black,
                          width: screenWidth*0.005,
                        )
                      ),
                      onPressed: () {
                        // GO TO ACTIVITIES
                      },
                      child: Stack( // stack text for outline
                        children: [
                          Text(
                            "Activities",
                            style: GoogleFonts.russoOne(
                              fontSize: screenWidth*0.1002,
                              foreground: Paint()
                              // cascade operators (..)
                              ..style = PaintingStyle.stroke
                              ..strokeWidth = 4
                              ..color = Colors.pink
                            )
                          ),
                          Text(
                            "Activities",
                            style: GoogleFonts.russoOne(
                              fontSize: screenWidth*0.1,
                              color: Colors.white
                            )
                          )
                        ],
                      )
                    ),
                    )
                  ],
                )
              )
            )
          ),
          // Footer box
            Container(
            height: screenHeight * 0.15,
            width: screenWidth,
            color: Color(0xFF121212),
            padding: EdgeInsets.all(25),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer bar
                  Container(
                    height: screenHeight * 0.020,
                    width: screenWidth * 0.615,
                    decoration:BoxDecoration (
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(10),
                    )
                  ),
                  // Inner bar
                  Container(
                    height: screenHeight * 0.015,
                    width: screenWidth * 0.6,
                    decoration:BoxDecoration (
                      color: const Color.fromARGB(255, 227, 210, 210),
                      borderRadius: BorderRadius.circular(10),
                    )
                  ),
                ]
              )
          )
        ])
      );
  }
}