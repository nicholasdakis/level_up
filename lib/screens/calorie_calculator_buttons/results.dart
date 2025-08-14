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
        """• The ${widget.equation} equation calculates your Basal Metabolic Rate (BMR), the minimum
number of calories your body needs to undergo essential roles for survival.\n • Examples include breathing, cell repair, and blood circulation.""",
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
          : "(4.536 x weight (lbs))\n + (15.88 x height (inches))\n - (5 x age (years))\n + 5"// Mifflin and NOT Metric
        : widget.units=="MetricDefault" || widget.units=="Metric" // NOT Mifflin and Metric
          ? "harris and metric"
          : "Harris and NOT metric", // NOT Mifflin and NOT Metric
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
          : "(4.536 x weight (lbs))\n + (15.88 x height (inches))\n - (5 x age (years))\n - 161"// Mifflin and NOT Metric
        : widget.units=="MetricDefault" || widget.units=="Metric" // NOT Mifflin and Metric
          ? "harris and metric"
          : "Harris and NOT metric", // NOT Mifflin and NOT Metric
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
            : "(10 x ${widget.weight})\n + (6.25 x ${widget.heightCm})\n - (5 x ${widget.age})\n + 5" // NOT Female and Metric and Mifflin
        : widget.sex=="Female" // Female and NOT Metric and Mifflin
          ? "(4.536 x ${widget.weight})\n + (15.88 x ${widget.heightInches})\n - (5 x ${widget.age})\n - 161" // Female and NOT Metric and Mifflin
          : "(4.536 x ${widget.weight})\n + (15.88 x ${widget.heightInches})\n - (5 x ${widget.age})\n + 5" // NOT Female and NOT Metric and Mifflin

        // HARRISON CASES
        : widget.units=="MetricDefault" || widget.units=="Metric" // NOT Mifflin and Metric
          ? widget.sex=="Female" // Female and Metric and NOT Mifflin
            ? "Female, Harrison, Metric" // Female and Metric and NOT Mifflin
            : "Male, Harrison, Metric" // NOT Female and Metric and NOT Mifflin
        : widget.sex=="Female" // Female and NOT Metric and Mifflin
          ? "Female, Harrison, Imperial" // Female and NOT Metric and NOT Mifflin
          : "Male, Harrison, Imperial", // NOT Female and NOT Metric and NOT Mifflin

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