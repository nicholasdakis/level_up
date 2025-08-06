import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Screens for buttons from the Personal tab
import 'personal_buttons/calorie_calculator.dart';

class Personal extends StatefulWidget{
  const Personal({super.key});
  
  @override
  State<Personal> createState() => _PersonalState();
}

class _PersonalState extends State<Personal> {
  @override
  Widget build(BuildContext context) {
        double screenHeight = 1.sh; // Make widgets the size of the user's personal screen size
        double screenWidth = 1.sw; // Make widgets the size of the user's personal screen size
        return Scaffold(
                backgroundColor:Color(0xFF1E1E1E),
                body: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Header box
                    Container(
                    height: screenHeight * 0.15,
                    width: screenWidth,
                    color: Color(0xFF121212),
                    padding: EdgeInsets.all(25),
                      child: Center (
                        child: Text(
                        "Personal",
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
                      child: Padding(
                        padding: EdgeInsets.all(screenHeight*0.02),
                        child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Update Info button
                            SizedBox( // to explicitly control the ElevatedButton size
                            height: screenHeight*0.15,
                            width: screenWidth*0.90,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
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
                                // change to a dropdown menu with Update profile pic, Update units, Update weight, update step goal
                              },
                                child: Center(
                                  child: Text(
                                    textAlign: TextAlign.center,
                                    "Update Your Information",
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
                            SizedBox(height: 50.h), // Spacer between buttons
                            // Calorie Calculator tab
                            SizedBox( // to explicitly control the ElevatedButton size
                            height: screenHeight*0.15,
                            width: screenWidth*0.90,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
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
                                Navigator.push(
                                  context,
                                  PageRouteBuilder( // Animation when switching screen
                                    pageBuilder: (context, animation, secondaryAnimation) => CalorieCalculator(),
                                    transitionDuration: Duration(milliseconds:220),
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
                                    textAlign: TextAlign.center,
                                    "Calorie Calculator",
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
                            SizedBox(height: 10.h), // Space between buttons
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