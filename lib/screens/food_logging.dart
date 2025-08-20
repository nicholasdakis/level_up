import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import '../main.dart';
// Packages for handling food information through the server.py file
import 'dart:convert';
import 'package:http/http.dart' as http;

class FoodLogging extends StatefulWidget {
  const FoodLogging({super.key});

  @override
  State<FoodLogging> createState() => _FoodLoggingState();
}

class _FoodLoggingState extends State<FoodLogging> {
  DropdownMenuItem<String> addMenuItem(String text) {
    return DropdownMenuItem<String>(value: text, child: Text(text));
  }

  final TextEditingController searchController =
      TextEditingController(); // allow the user to type in their weight

  String? mealType;

  @override
  Widget build(BuildContext context) {
    double screenHeight =
        1.sh; // Make widgets the size of the user's personal screen size
    double screenWidth =
        1.sw; // Make widgets the size of the user's personal screen size
    return Scaffold(
      backgroundColor: Color(0xFF1E1E1E),
      // Header box
      appBar: AppBar(
        backgroundColor: Color(0xFF121212),
        centerTitle: true,
        toolbarHeight: screenHeight * 0.15,
        title: Text(
          "Food Logging",
          style: GoogleFonts.pacifico(
            fontSize: screenWidth * 0.10,
            color: Colors.white,
            shadows: [
              Shadow(
                offset: Offset(4, 4),
                blurRadius: 10,
                color: const Color.fromARGB(255, 0, 0, 0),
              ),
            ],
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Search Food input
            SizedBox(
              // make the underline narrower
              width: screenWidth * 0.9,
              child: Theme(
                data: Theme.of(context).copyWith(
                  // Theme to remove the purple when interacting with the input
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  textSelectionTheme: TextSelectionThemeData(
                    cursorColor: Colors.white,
                    selectionHandleColor: Colors.white,
                    selectionColor: const Color.fromARGB(
                      255,
                      83,
                      75,
                      75,
                    ).withAlpha(128),
                  ),
                ),
                child: TextField(
                  controller: searchController,
                  keyboardType: TextInputType.text,
                  style: GoogleFonts.russoOne(
                    // style of the input text
                    fontSize: screenWidth * 0.05,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        offset: Offset(4, 4),
                        blurRadius: 10,
                        color: const Color.fromARGB(255, 0, 0, 0),
                      ),
                    ],
                  ),
                  decoration: InputDecoration(
                    // style of the hint text
                    enabledBorder: UnderlineInputBorder(
                      // custom border
                      borderSide: BorderSide(color: Colors.grey, width: 0.25),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      // custom border
                      borderSide: BorderSide(color: Colors.grey, width: 0.25),
                    ),
                    hintText: "Search",
                    suffixIcon: Icon(Icons.search),
                    contentPadding: EdgeInsets.only(
                      top: 13,
                      left: 6,
                    ), // Move the text down and to the right to look more natural
                    hintStyle: GoogleFonts.russoOne(
                      fontSize: screenWidth * 0.05,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          offset: Offset(4, 4),
                          blurRadius: 10,
                          color: const Color.fromARGB(255, 0, 0, 0),
                        ),
                      ],
                    ),
                  ),
                  onChanged: (inputWeight) {},
                ),
              ),
            ),
            SizedBox(height: 0.01*screenHeight), // Lower the next two buttons
            // Horizontally lay out the next two buttons
            Row(
              children: [
                // Meal Type chooser
                Expanded(
                  child: DropdownButton2<String>(
                    dropdownStyleData: DropdownStyleData(
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(
                          255,
                          91,
                          89,
                          89,
                        ).withAlpha(128),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      maxHeight:
                          200, // adds a scrollbar if needed (if larger than 200px)
                    ),
                    style: GoogleFonts.russoOne(
                      fontSize: screenWidth * 0.05,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          offset: Offset(4, 4),
                          blurRadius: 10,
                          color: const Color.fromARGB(255, 0, 0, 0),
                        ),
                      ],
                    ),
                    hint: Text(
                      "Meal Type",
                      style: GoogleFonts.russoOne(
                        fontSize: screenWidth * 0.05,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            offset: Offset(4, 4),
                            blurRadius: 10,
                            color: const Color.fromARGB(255, 0, 0, 0),
                          ),
                        ],
                      ),
                    ),
                    value: mealType,
                    items: [
                      addMenuItem("Breakfast"),
                      addMenuItem("Lunch"),
                      addMenuItem("Dinner"),
                      addMenuItem("Snack"),
                    ],
                    onChanged: (value) {
                      // when the user selects their sex
                      setState(() {
                        mealType = value; // update to chosen meal
                      });
                    },
                  ),
                ), // Log Food Button
                  Expanded(
                    child: SizedBox(
                          // to explicitly control the ElevatedButton size
                          height: screenHeight * 0.05,
                          width: screenWidth * 0.4,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              backgroundColor: Color(0xFF2A2A2A), // Actual button color
                              foregroundColor: Colors.white, // Button text color
                              side: BorderSide(color: Colors.black, width: screenWidth * 0.005),
                            ),
                            onPressed: () {
                            },
                            child: buttonText("Log Food", screenWidth * 0.05),
                          ),
                        ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
