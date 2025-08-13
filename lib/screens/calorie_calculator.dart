import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dropdown_button2/dropdown_button2.dart'; // more customizable dropdown button (specifically, always open downward and round borders)
import 'calorie_calculator_buttons/results.dart';
import 'package:flutter/services.dart';

class CalorieCalculator extends StatefulWidget{
  const CalorieCalculator({super.key});
  
  @override
  State<CalorieCalculator> createState() => _CalorieCalculatorState();
}

class _CalorieCalculatorState extends State<CalorieCalculator> {
  // store information about the user to use in the calculations
  String? units = "MetricDefault"; // default value, but uses a different name so the user can still see "Enter your units" text
  String? sex;
  String? goal;
  String? activityLevel;
  String? equation; // which formula / equation to be used for the calculation
  int? age;

  int? heightCm;
  int? heightInches;

  String? weight; // One value for either Lbs or Kg -> Converted to a double -> Calculated based on units chosen

  final TextEditingController weightController = TextEditingController(); // allow the user to type in their weight
  bool resultsSnackbarActive = false; // flag so only one snackbar shows at a time

  @override
  Widget build(BuildContext context) {
    double screenHeight = 1.sh; // Make widgets the size of the user's personal screen size
    double screenWidth = 1.sw; // Make widgets the size of the user's personal screen size
    // preventing an error by setting the dropdownvalue to null instead of "MetricDefault"
    String? dropdownValue;
    if (units=="MetricDefault") {
      dropdownValue = null;
    }
    else {
      dropdownValue = units;
    }
    return Scaffold(
                backgroundColor:Color(0xFF1E1E1E),
                // Header box
                appBar: AppBar(
                  backgroundColor: Color(0xFF121212),
                  centerTitle: true,
                  toolbarHeight: screenHeight * 0.15,
                  title: Text(
                        "Calculator",
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
      body: SingleChildScrollView(
        child: Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: SizedBox( 
            width: 300,
        child: Column(
          children: [
              // ENTER YOUR UNITS BUTTON
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
                "Enter your units",
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
              value: dropdownValue,
              items: [
                DropdownMenuItem(value: 'Metric', child: Text('Metric (default)')),
                DropdownMenuItem(value: 'Imperial', child: Text('Imperial')),
              ],
              onChanged: (value) { // when the user selects their units
                setState(() { // update the value
                  units = value;
                  // empty the height fields just in case they were altered before units were changed
                  heightInches = null;
                  heightCm = null;
                });
              },
            ),
                        // SELECT CALORIE EQUATION FORMULA
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
                "Select Equation",
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
              value: equation,
              items: [
                DropdownMenuItem(value: 'Harris-Benedict', child: Text('Harris-Benedict')),
                DropdownMenuItem(value: 'Mifflin-St Jeor', child: Text('Mifflin-St Jeor'))
              ],
              onChanged: (value) { // when the user selects their sex
                setState(() { // update the value
                  equation = value;
                });
              },
            ),
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
              onChanged: (value) { // when the user selects their age
                setState(() { // update the value
                  age = value;
                });
              },
            ),
              // ENTER YOUR WEIGHT INPUT
              SizedBox( // make the underline narrower
                width: screenWidth*0.5,
                child: Theme(
                  data: Theme.of(context).copyWith( // Theme to remove the purple when interacting with the input weight
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    textSelectionTheme: TextSelectionThemeData(
                      cursorColor: Colors.white,
                      selectionHandleColor: Colors.white,
                      selectionColor: const Color.fromARGB(255, 83, 75, 75).withAlpha(128)
                    ),
                  ),
                child: TextField(
                controller: weightController,
                 keyboardType: TextInputType.numberWithOptions(decimal: true, signed: false),
                 inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                 ],
                style: GoogleFonts.russoOne( // style of the input text
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
                decoration: InputDecoration( // style of the hint text
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white, width: 0.25)
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white, width: 0.25)
                ),
                hintText: "Enter your weight",
                contentPadding: EdgeInsets.only(top: 13), // Move the text down so it is consistent with the other tabs
                hintStyle: GoogleFonts.russoOne(
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
              onChanged: (inputWeight) {
                weight = inputWeight; // store the user's input
              }
              )
              )
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
              value: heightInches,
              items: [
                if (units=="Metric" || units=="MetricDefault")
                for (int i=100;i<=275;i++)
                  DropdownMenuItem(value: i, child: Text("$i cm"))
                else if (units=="Imperial") 
                  for (int j=3;j<9;j++)
                    for (int k=0;k<12;k++)
                      DropdownMenuItem(value: j*12 + k, child: Text("$j'$k''")) // store value entirely in inches but visually show feet and inches
              ],
              onChanged: (value) { // when the user selects their height
                setState(() { // update the value
                  heightInches = value;
                    heightCm = (heightInches! * 2.54).round(); // ! next to heightInches because I know it won't be null
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
              onChanged: (value) { // when the user selects their goal
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
                fontSize: screenWidth*0.045,
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
              onChanged: (value) { // when the user selects their activity level
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
                  if (units == null || equation == null || sex == null || age == null || weight==null
                  || (heightCm == null && heightInches == null) || goal == null || activityLevel == null) {
                    if (resultsSnackbarActive == true) return; // a snackBar is already opened
                    resultsSnackbarActive=true;
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
                      resultsSnackbarActive=false; // reset the flag (prevent many snackbars from stacking)
                      }
                    );
                    return;
                  }
                  Navigator.push(
                    context,
                    PageRouteBuilder( // Animation when switching screen
                      pageBuilder: (context, animation, secondaryAnimation) => Results( // // pass in variables to the same-named variables in Results
                        units: units,
                        goal: goal,
                        activityLevel: activityLevel,
                        equation: equation,
                        age: age,
                        heightCm: heightCm,
                        heightInches: heightInches,
                        weight: weight
                        ), 
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
      )
      )
    );
  }
}