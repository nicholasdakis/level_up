import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class FoodLogging extends StatefulWidget{
  const FoodLogging({super.key});
  
  @override
  State<FoodLogging> createState() => _FoodLoggingState();
}

class _FoodLoggingState extends State<FoodLogging> {
  @override
  Widget build(BuildContext context) {
    double screenHeight = 1.sh; // Make widgets the size of the user's personal screen size
    double screenWidth = 1.sw; // Make widgets the size of the user's personal screen size
    return Scaffold(
                backgroundColor:Color(0xFF1E1E1E),
                // Header box
                appBar: AppBar(
                  backgroundColor: Color(0xFF121212),
                  centerTitle: true,
                  toolbarHeight: screenHeight * 0.15,
                  title: Text(
                        "Food Logging",
                        style: GoogleFonts.russoOne(
                          fontSize: screenWidth*0.10,
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
                ),
      body: Center(
        child: Text("Food Logging tab")
      )
    );
  }
}