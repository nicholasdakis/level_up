import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class Results extends StatefulWidget{
  // same-named variables from Calorie Calculator that are assigned when the page is switched from that tab to this one
  final String? units;
  final String? goal;
  final String? sex;
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
    required this.sex,
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
                  scrolledUnderElevation: 0, // So the appBar does not change color when the user scrolls down
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
      body: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(30),
        child:
        Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
      Text(
        widget.equation=="Mifflin-St Jeor"
        ? """• The ${widget.equation} equation calculates your Basal Metabolic Rate (BMR), the minimum
number of calories your body needs to undergo essential roles for survival.\n • Examples include breathing, cell repair, and blood circulation. • This formula is a revised version of the Harris-Benedict equation."""
        :"""• The revised ${widget.equation} equation calculates your Basal Metabolic Rate (BMR), the minimum
number of calories your body needs to undergo essential roles for survival.\n • Examples include breathing, cell repair, and blood circulation.\n • The original formula was revised in 1984 by Roza and Shizgal to show more accurate results.""",
      style: GoogleFonts.russoOne(
        fontSize: screenWidth*0.045,
        color: Colors.white,
        shadows: [
          Shadow( offset: Offset(4,4),
          blurRadius: 10,
          color: const Color.fromARGB(255, 0, 0, 0)
          )
      ]
      )
      ),
      SizedBox( // Separate the text
        height: 0.025*screenWidth
      ),
      Text(
        textAlign: TextAlign.center,
        "BMR is calculated as follows:",
      style: GoogleFonts.russoOne(
        fontSize: screenWidth*0.08,
        color: Colors.white,
        shadows: [
          Shadow( offset: Offset(4,4),
          blurRadius: 10,
          color: const Color.fromARGB(255, 0, 0, 0)
          )
      ]
      )
      ),
      Text(
        textAlign: TextAlign.center,
        "Males:",
      style: GoogleFonts.russoOne(
        fontSize: screenWidth*0.15,
        color: const Color.fromARGB(255, 5, 71, 142),
        shadows: [
          Shadow( offset: Offset(4,4),
          blurRadius: 10,
          color: const Color.fromARGB(255, 0, 0, 0)
          )
      ]
      )
      ),
      Text(
        widget.equation=="Mifflin-St Jeor"
        ? widget.units=="MetricDefault" || widget.units=="Metric"
          ? "(10 x weight (kg))\n + (6.25 x height (cm))\n - (5 x age (years))\n + 5" // Mifflin and Metric
          : "(4.536 x weight (lbs))\n + (15.88 x height (inches))\n - (5 x age (years))\n + 5" // Mifflin and Imperial
        : widget.units=="MetricDefault" || widget.units=="Metric" // Harris and Metric
          ? "(13.397 x weight (kg))\n + (4.799 x height (cm))\n - (5.677 x age (years))\n + 88.362" // Harris and Metric
          : "(6.23 x weight (lbs))\n + (12.7 x height (inches))\n - (6.8 x age (years))\n + 66.473", // Harris and Imperial
      style: GoogleFonts.russoOne(
        fontSize: screenWidth*0.062,
        color: const Color.fromARGB(255, 5, 71, 142),
        shadows: [
          Shadow( offset: Offset(4,4),
          blurRadius: 10,
          color: const Color.fromARGB(255, 0, 0, 0)
          )
      ]
      )
      ),
            SizedBox( // Separate the text
        height: 0.025*screenWidth
      ),
        Text(
        textAlign: TextAlign.center,
        "Females:",
      style: GoogleFonts.russoOne(
        fontSize: screenWidth*0.15,
        color: const Color.fromARGB(255, 132, 9, 79),
        shadows: [
          Shadow( offset: Offset(4,4),
          blurRadius: 10,
          color: const Color.fromARGB(255, 0, 0, 0)
          )
      ]
      )
      ),
      Text(
        widget.equation=="Mifflin-St Jeor"
        ? widget.units=="MetricDefault" || widget.units=="Metric"
          ? "(10 x weight (kg))\n + (6.25 x height (cm))\n - (5 x age (years))\n - 161" // Mifflin and Metric
          : "(4.536 x weight (lbs))\n + (15.88 x height (inches))\n - (5 x age (years))\n - 161"// Mifflin and Imperial
        : widget.units=="MetricDefault" || widget.units=="Metric" // Harris and Metric
          ? "(9.247 x weight (kg))\n + (3.098 x height (cm))\n - (4.330 x age (years))\n + 447.593" // Harris and Metric
          : "(4.35 x weight (lbs))\n + (4.7 x height (inches))\n - (4.7 x age (years))\n + 655.095", // Harris and NOT Imperial
      style: GoogleFonts.russoOne(
        fontSize: screenWidth*0.065,
        color: const Color.fromARGB(255, 132, 9, 79),
        shadows: [
          Shadow( offset: Offset(4,4),
          blurRadius: 10,
          color: const Color.fromARGB(255, 0, 0, 0)
          )
      ]
      )
      ),
            Text(
        textAlign: TextAlign.center,
        "You:",
      style: GoogleFonts.russoOne(
        fontSize: screenWidth*0.15,
        color: Colors.white,
        shadows: [
          Shadow( offset: Offset(4,4),
          blurRadius: 10,
          color: const Color.fromARGB(255, 0, 0, 0)
          )
      ]
      )
      ),
            Text(

        // MIFFLIN CASES
        widget.equation=="Mifflin-St Jeor" // MIFFLIN
        ? widget.units=="MetricDefault" || widget.units=="Metric" // Mifflin and Metric
          ? widget.sex=="Female" // Female and Metric and Mifflin
            ? "(10 x ${widget.weight})\n + (6.25 x ${widget.heightCm})\n - (5 x ${widget.age})\n - 161" // Female and Metric and Mifflin
            : "(10 x ${widget.weight})\n + (6.25 x ${widget.heightCm})\n - (5 x ${widget.age})\n + 5" // Male and Metric and Mifflin
        : widget.sex=="Female" // Female and NOT Metric and Mifflin
          ? "(4.536 x ${widget.weight})\n + (15.88 x ${widget.heightInches})\n - (5 x ${widget.age})\n - 161" // Female and Imperial and Mifflin
          : "(4.536 x ${widget.weight})\n + (15.88 x ${widget.heightInches})\n - (5 x ${widget.age})\n + 5" // Male and Imperial and Mifflin

        // HARRIS CASES
        : widget.units=="MetricDefault" || widget.units=="Metric" // NOT Mifflin and Metric
          ? widget.sex=="Female" // Female and Metric and NOT Mifflin
            ? "(9.247 x ${widget.weight} (kg))\n + (3.098 x ${widget.heightCm} (cm))\n - (4.330 x ${widget.age} (years))\n + 447.593" // Female and Metric and Harris
            : "(13.397 x ${widget.weight} (kg))\n + (4.799 x ${widget.heightCm} (cm))\n - (5.677 x ${widget.age} (years))\n + 88.362" //Male and Metric and Harris
        : widget.sex=="Female" // Female and NOT Metric and Mifflin
          ? "(4.35 x ${widget.weight} (lbs))\n + (4.7 x ${widget.heightInches} (inches))\n - (4.7 x ${widget.age} (years))\n + 655.095" // Female and Imperial and Harris
          : "(6.23 x ${widget.weight} (lbs))\n + (12.7 x ${widget.heightInches} (inches))\n - (6.8 x ${widget.age} (years))\n + 66.473", // Male and Imperial and Harris

      style: GoogleFonts.russoOne(
        fontSize: screenWidth*0.065,
        color: const Color.fromARGB(255, 132, 9, 79),
        shadows: [
          Shadow( offset: Offset(4,4),
          blurRadius: 10,
          color: const Color.fromARGB(255, 0, 0, 0)
          )
      ]
      )
      ),
      ]
    )
      )
    )
      )
    );
  }
}