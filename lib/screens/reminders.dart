import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class Reminders extends StatefulWidget{
  const Reminders({super.key});
  
  @override
  State<Reminders> createState() => _RemindersState();
}

class _RemindersState extends State<Reminders> {
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
                        "Reminders",
                        style: GoogleFonts.russoOne(
                          fontSize: screenWidth*0.12,
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
        child: Text("Reminders tab")
      )
    );
  }
}