import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class Results extends StatefulWidget{
  // same-named variables from Calorie Calculator that are assigned when the page is switched from that tab to this one
  final String? units;
  final String? goal;
  final String? activityLevel;
  final String? equation; // which formula / equation to be used for the calculation
  final int? age;
  final int? heightCm;
  final int? heightInches;
  final String? weight; // One value for either Lbs or Kg -> Converted to a double -> Calculated based on units chosen

  const Results({ // constructor
    super.key,
    required this.units, // required means the value cannot be null and a value must be provided when creating the widget
    required this.goal,
    required this.activityLevel,
    required this.equation,
    required this.age,
    required this.heightCm,
    required this.heightInches,
    required this.weight
    });
  
  @override
  State<Results> createState() => _ResultsState();
}

class _ResultsState extends State<Results> {
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
                        "Results",
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
      body: Wrap(
        children: [Padding(
        padding: EdgeInsets.all(16),
        child: Text(
         "${widget.units} is your metrics chosen. You weigh ${widget.weight}, and your height in cm is ${widget.heightCm}!",
          style: GoogleFonts.russoOne(
          fontSize: screenWidth*0.05,
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
      )]
      )
    );
  }
}