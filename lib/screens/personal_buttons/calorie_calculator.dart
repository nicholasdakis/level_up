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
  String? activityLevel;
  String? equation; // which formula / equation to be used for the calculation
  int? age;

  int? heightCm;
  int? heightFeet;
  int? heightInches;

  double? weightKg;
  double? weightLbs;

  final TextEditingController weightController = TextEditingController(); // allow the user to type in their weight
  bool snackbarActive = false; // flag for only one snack bar at a time

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
              // ENTER YOUR HEIGHT BUTTON
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
                "Enter your height",
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
              value: heightCm,
              items: [
                for (int i=100;i<=250;i++)
                  DropdownMenuItem(value: i, child: Text("$i"))
              ],
              onChanged: (value) { // when the user selects their sex
                setState(() { // update the value
                  heightCm = value;
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
            // ENTER YOUR ACTIVITY LEVEL BUTTON
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
                "Enter your activity level",
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
              value: activityLevel,
              items: [
                DropdownMenuItem(value: 'Sedentary', child: Text('Sedentary')),
                DropdownMenuItem(value: 'Light', child: Text('Light')),
                DropdownMenuItem(value: 'Moderate', child: Text('Moderate')),
                DropdownMenuItem(value: 'Very', child: Text('Very')),
              ],
              onChanged: (value) { // when the user selects their sex
                setState(() { // update the value
                  activityLevel = value;
                });
              },
            ),
            SizedBox(height: 5.h),
            Wrap(
              children: 
              [Text(
                "• Sedentary = Low or no exercise.",
                style: GoogleFonts.roboto(
                fontSize: screenWidth*0.03,
                color: Colors.white.withAlpha(128),
                shadows: [
                  Shadow(
                    offset: Offset(4,4),
                    blurRadius: 10,
                    color: Color.fromARGB(255, 0, 0, 0)
                  )
                ]
                ),
              ),
              Text(
                "• Light = Light exercise 1-3 days per week.",
                style: GoogleFonts.roboto(
                fontSize: screenWidth*0.03,
                color: Colors.white.withAlpha(128),
                shadows: [
                  Shadow(
                    offset: Offset(4,4),
                    blurRadius: 10,
                    color: Color.fromARGB(255, 0, 0, 0)
                  )
                ]
                ),
              ),
              Text(
                "• Moderate = Moderate exercise 3-5 days per week.",
                style: GoogleFonts.roboto(
                fontSize: screenWidth*0.03,
                color: Colors.white.withAlpha(128),
                shadows: [
                  Shadow(
                    offset: Offset(4,4),
                    blurRadius: 10,
                    color: Color.fromARGB(255, 0, 0, 0)
                  )
                ]
                ),
              ),
              Text(
                "• Very = Hard exercise 6-7 days per week.",
                style: GoogleFonts.roboto(
                fontSize: screenWidth*0.03,
                color: Colors.white.withAlpha(128),
                shadows: [
                  Shadow(
                    offset: Offset(4,4),
                    blurRadius: 10,
                    color: Color.fromARGB(255, 0, 0, 0)
                  )
                ]
                ),
              ),
              SizedBox(height: 30.h),
              // Results button
              SizedBox( // to explicitly control the ElevatedButton size
              height: screenHeight*0.10,
              width: screenWidth*0.85,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(90)
                  ),
                  backgroundColor: Color(0xFF2A2A2A), // Actual button color
                  foregroundColor: Colors.white, // Button text color
                  side: BorderSide(
                    color: Colors.black,
                    width: screenWidth*0.005,
                  )
                ),
                onPressed: () {
                  // validity checks
                  if (age==null) {
                    if (snackbarActive == true) return; // a snackBar is already opened
                    snackbarActive=true;
                    // Let the user know that not all fields are filled out.
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.info, color: Colors.white),
                            SizedBox(width: 10),
                            Text("All fields must be filled."),
                          ]
                      )
                    )
                    ).closed.then(
                      (_) {
                      snackbarActive=false; // reset the flag (prevent many snackbars from stacking)
                      }
                    );
                    return;
                  }
                  Navigator.push(
                    context,
                    PageRouteBuilder( // Animation when switching screen
                      pageBuilder: (context, animation, secondaryAnimation) => Results(),
                      transitionDuration: Duration(milliseconds:400),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        const start = Offset(0.0,1.0); // Start right below the screen
                        const finish = Offset.zero; // Stop right at the top of the screen
                        final tween = Tween(begin: start, end: finish).chain(CurveTween(curve: Curves.easeIn));
                        final offsetAnimation = animation.drive(tween);
                        return SlideTransition(position: offsetAnimation, child:child);
                      }
                    )
                  );
                },
                  child: Center(
                    child: Text(
                      "Get Results",
                        style: GoogleFonts.workSans(
                          fontSize: screenWidth*0.1,
                          color: Colors.white,
                          shadows: [
                            Shadow( // Up Left
                              offset: Offset(-1,-1),
                              color: Colors.black
                            ),
                            Shadow( // Up Right
                              offset: Offset(1,-1),
                              color: Colors.black
                            ),
                            Shadow( // Down Left
                              offset: Offset(-1,1),
                              color: Colors.black
                            ),
                            Shadow( // Down Right
                              offset: Offset(1,1),
                              color: Colors.black
                            )
                          ]
                        )
                    ),
                  )
              ),
              ),
              ],
            )
            ]
            ),
        )
      )
    );
  }
}

// RESULTS CLASS //
class Results extends StatefulWidget{
  const Results({super.key});
  
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
      body: Center(
        child: Text("Results tab")
      )
    );
  }
}