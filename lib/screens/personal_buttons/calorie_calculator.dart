import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dropdown_button2/dropdown_button2.dart'; // more customizable dropdown button (specifically, always open downward and round borders)

class CalorieCalculator extends StatefulWidget{
  const CalorieCalculator({super.key});
  
  @override
  State<CalorieCalculator> createState() => _CalorieCalculatorState();
}

class _CalorieCalculatorState extends State<CalorieCalculator> {
  // store information about the user to use in the calculations
  String? sex;
  String? goal;
  int? age;

  int? heightCm;
  int? heightFeet;
  int? heightInches;

  int? weightKg;
  int? weightLbs;
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
                        "Calories",
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
        child: Padding(
          padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // ENTER YOUR SEX BUTTON
            DropdownButton2<String>(
              dropdownStyleData: DropdownStyleData(
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 91, 89, 89).withAlpha(128),
                  borderRadius: BorderRadius.circular(10),
                ),
                maxHeight: 200, // adds a scrollbar if needed (if larger than 200px)
              ),
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
                ),
              hint: Text(
                "Enter your sex",
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
                ),
              ),
              value: sex,
              items: [
                DropdownMenuItem(value: 'Male', child: Text('Male')),
                DropdownMenuItem(value: 'Female', child: Text('Female')),
              ],
              onChanged: (value) { // when the user selects their sex
                setState(() { // update the value
                  sex = value;
                });
              },
            ),
                        // ENTER YOUR AGE BUTTON
              DropdownButton2<int>(
              dropdownStyleData: DropdownStyleData(
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 91, 89, 89).withAlpha(128),
                  borderRadius: BorderRadius.circular(10),
                ),
                maxHeight: 200, // adds a scrollbar if needed (if larger than 200px)
              ),
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
                ),
              hint: Text(
                "Enter your age",
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
                ),
              ),
              value: age,
              items: [
                for (int i=13;i<=122;i++)
                  DropdownMenuItem(value: i, child: Text("$i"))
              ],
              onChanged: (value) { // when the user selects their sex
                setState(() { // update the value
                  age = value;
                });
              },
            ),
            // ENTER YOUR GOAL BUTTON
              DropdownButton2<String>(
              dropdownStyleData: DropdownStyleData(
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 91, 89, 89).withAlpha(128),
                  borderRadius: BorderRadius.circular(10),
                ),
                maxHeight: 200, // adds a scrollbar if needed (if larger than 200px)
              ),
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
                ),
              hint: Text(
                "Enter your goal",
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
                ),
              ),
              value: goal,
              items: [
                DropdownMenuItem(value: 'Gain Weight', child: Text('Gain Weight')),
                DropdownMenuItem(value: 'Lose Weight', child: Text('Lose Weight')),
                DropdownMenuItem(value: 'Maintain Weight', child: Text('Maintain Weight')),
              ],
              onChanged: (value) { // when the user selects their sex
                setState(() { // update the value
                  goal = value;
                });
              },
            ),
            ]
            ),
        )
      )
    );
  }
}