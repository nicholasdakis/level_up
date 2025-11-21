import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart'; // FatSecret snippet code launch
import 'dart:async'; // for using Timer
// Packages for handling food information through the server.py file
import 'dart:convert';
import 'package:http/http.dart' as http;
// Class imports
import '../globals.dart';

class FoodLogging extends StatefulWidget {
  const FoodLogging({super.key});

  @override
  State<FoodLogging> createState() => _FoodLoggingState();
}

class _FoodLoggingState extends State<FoodLogging> {
  DropdownMenuItem<String> addMenuItem(String text) {
    return DropdownMenuItem<String>(value: text, child: Text(text));
  }

  // This method tries to launch the FatSecret website when called
  Future<void> launchFatSecret() async {
    final uri = Uri.parse(
      "https://www.fatsecret.com",
    ); // Store the url as a Uri
    if (!await launchUrl(uri)) {
      // If the website could not be launched
      throw "Error: Could not open website.";
    }
  }

  String latestQuery = "";

  // Method to format time to show user how long until tokens reset
  String formatDuration(String rawTime) {
    // Split by dot then take the first section (to ignore the milliseconds section)
    rawTime = rawTime.split('.')[0];
    // to concatenate the string
    StringBuffer sb = StringBuffer();
    // split by section
    List<String> parts = rawTime.split(':');

    // convert the segments to integers: eg "01" becomes 1
    int hours = int.parse(parts[0]);
    int minutes = int.parse(parts[1]);
    int seconds = int.parse(parts[2]);

    // Case 1: All zeros
    if (hours == 0 && minutes == 0 && seconds == 0) {
      sb.write("0 seconds");
      // There are hours
    } else {
      if (hours > 0) {
        sb.write(
          "$hours hour${hours == 1 ? '' : 's'}",
        ); // add an s only if plural
        // edge cases
        if (minutes > 0 || seconds > 0) sb.write(", ");
      }
      // There are minutes
      if (minutes > 0) {
        sb.write(
          "$minutes minute${minutes == 1 ? '' : 's'}",
        ); // add an s only if plural
        // edge case
        if (seconds > 0) sb.write(", and ");
      }
      // There are seconds
      if (seconds > 0) {
        sb.write(
          "$seconds second${seconds == 1 ? '' : 's'}",
        ); // add an s only if plural
      }
    }
    return sb.toString();
  }

  // Function that calls the API to search the user's input after the timer has gone to 0 (to avoid making too many requests)
  void handleApiCall(DateTime? dateTime, String query) async {
    latestQuery = query;
    if (query.isEmpty) return;

    debugPrint("Searching for food: $query");

    final url = Uri.parse(
      'https://level-up-69vz.onrender.com/get_food/$query',
    ); // search the food via the backend get_food method
    try {
      final response = await http.get(url);

      debugPrint("Response status: ${response.statusCode}");
      debugPrint("Response body: ${response.body}");

      if (response.statusCode == 200) {
        if (latestQuery == query) {
          final data = jsonDecode(response.body);

          final foods = data['foods'];
          if (foods != null && foods['food'] != null) {
            setState(() {
              foodList = List<dynamic>.from(foods['food']);
            });
          } else {
            setState(() {
              foodList = [];
            });
          }
        }
      } else if (!snackbarActive && response.statusCode == 429) {
        snackbarActive = true;

        // Handle errors
        final errorData = jsonDecode(response.body);

        // Token limit exceeded error
        if (errorData['error'] == "Token limit exceeded") {
          // retrieve time left from the json file
          String resetTimeStr = errorData['time_left'];
          // format nicely for UX
          String formattedTime = formatDuration(resetTimeStr);
          ScaffoldMessenger.of(context)
              .showSnackBar(
                SnackBar(
                  content: Text(
                    "Daily search limit reached. The limit resets in $formattedTime.",
                  ),
                  duration: Duration(seconds: 5),
                ),
              )
              .closed
              .then((_) {
                snackbarActive = false;
              });
        }
        setState(() {
          foodList = [];
        });
      } else {
        setState(() {
          foodList = [];
        });
      }
    } catch (error) {
      debugPrint("API call error: $error");
      setState(() {
        foodList = [];
      });
    }
  }

  final TextEditingController searchController =
      TextEditingController(); // for reading the user's search input

  // Whether the user is allowed to type in the search bar (disabled after a food is clicked on)
  bool userCanType = true;
  // Whether the validity check can pass or not (Equal to !userCanType, simply created for readability)
  bool mealChosen = false;

  // Whether a snackbar is already opened
  bool snackbarActive = false;

  String? mealType;

  // Timer to prevent too many requests to the API too frequently
  Timer? checkTimer;

  // Variable to store the user's current time for Timer usage
  DateTime? lastInput;

  // The list that holds and displays the foods found from the user's search
  List<dynamic> foodList = [];

  // The lists that hold and display the foods the user selects based on the category of food
  List<String> breakfastFoods = [];
  List<String> lunchFoods = [];
  List<String> dinnerFoods = [];
  List<String> snackFoods = [];

  @override
  void dispose() {
    checkTimer?.cancel(); // cancel the timer to prevent callbacks after dispose
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
  }

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
        scrolledUnderElevation:
            0, // So the appBar does not change color when the user scrolls down
        backgroundColor: Color(0xFF121212),
        centerTitle: true,
        toolbarHeight: screenHeight * 0.15,
        title: createTitle("Food Logging", screenWidth),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // FatSecret attribution
            Container(
              alignment: Alignment.center,
              child: InkWell(
                onTap: () async {
                  await launchFatSecret(); // wait for the function to finish calling // load method which updates noApiTokens variable
                },
                child: Column(
                  children: [
                    textWithFont(
                      "Powered by fatsecret",
                      screenWidth,
                      0.035,
                      color: Colors.blue,
                    ),
                  ],
                ),
              ),
            ),

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
                  enabled: userCanType,
                  keyboardType: TextInputType.text,
                  style: GoogleFonts.manrope(
                    // style of the input text
                    fontSize: screenWidth * 0.04,
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
                    hintStyle: GoogleFonts.manrope(
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
                  onChanged: (value) {
                    lastInput =
                        DateTime.now(); // Store the time at which the user pressed the last character
                    checkTimer
                        ?.cancel(); // Cancel any previous timers to avoid calling the function continuously
                    checkTimer = Timer(
                      Duration(milliseconds: 500), // Set a timer for 500ms
                      () {
                        handleApiCall(
                          lastInput,
                          value,
                        ); // Run if the timer goes to 0
                      },
                    );
                  },
                ),
              ),
            ),
            SizedBox(height: 0.01 * screenHeight), // Lower the next two buttons
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
                    style: GoogleFonts.manrope(
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
                      style: GoogleFonts.manrope(
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
                        backgroundColor: Color(
                          0xFF2A2A2A,
                        ), // Actual button color
                        foregroundColor: Colors.white, // Button text color
                        side: BorderSide(
                          color: Colors.black,
                          width: screenWidth * 0.005,
                        ),
                      ),
                      onPressed: () {
                        // When "Log Food" is pressed
                        // VALIDITY CHECKS
                        // CASE 1) LOG FOOD IS INVALID TO PRESS
                        if (mealType == null || !mealChosen) {
                          if (snackbarActive == true) {
                            return; // a snackBar is already opened, so do nothing
                          }
                          snackbarActive = true; // Otherwise open a snackbar
                          // Let the user know that not all fields are filled out.
                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(Icons.info, color: Colors.white),
                                      SizedBox(width: 10),
                                      Text("All fields must be filled."),
                                    ],
                                  ),
                                ),
                              )
                              .closed
                              .then((_) {
                                snackbarActive =
                                    false; // reset the flag (prevent many snackbars from stacking)
                              });
                          return;
                        }
                        // CASE 2: LOG FOOD IS VALID TO PRESS, SO ADD THE FOOD TO THE LIST
                        else {
                          setState(() {
                            final foodName = searchController.text;
                            switch (mealType) {
                              case "Breakfast":
                                breakfastFoods.add(foodName);
                                break;
                              case "Lunch":
                                lunchFoods.add(foodName);
                                break;
                              case "Dinner":
                                dinnerFoods.add(foodName);
                                break;
                              case "Snack":
                                snackFoods.add(foodName);
                                break;
                            }
                            // Reset inputs for next entry
                            userCanType = true;
                            mealChosen = false;
                            searchController.clear();
                            mealType = null;
                          });
                        }
                      },
                      child: buttonText("Log Food", screenWidth * 0.05),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            // DISPLAY AVAILABLE FOOD OPTIONS (when searching) OR FOOD CATEGORIES
            if (foodList
                .isNotEmpty) // if results were not returned from the API,
              // Show search results
              Expanded(
                child: ListView.builder(
                  itemCount: foodList.length,
                  itemBuilder: (context, index) {
                    final food = foodList[index];
                    return InkWell(
                      // To make each item clickable
                      onTap: () {
                        FocusScope.of(
                          context,
                        ).unfocus(); // disable keyboard focus
                        setState(() {
                          userCanType = false; // disable typing
                          mealChosen =
                              true; // allow the validity check to successfully pass
                          searchController.text =
                              food["food_name"] ??
                              ""; // update the searchbar text to the selected food
                          searchController
                              .selection = TextSelection.fromPosition(
                            TextPosition(
                              offset: searchController.text.length,
                            ), // keep the blinking cursor at the end of the word
                          );
                          foodList = []; // hide search results after selecting
                        });
                      },
                      child: ListTile(
                        title: Text(
                          food['food_name'] ??
                              '', // List the food name (or nothing if nothing is found)
                          style: GoogleFonts.manrope(color: Colors.white),
                        ),
                        subtitle: Text(
                          food['food_description'] ??
                              '', // List the info (or nothing)
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    );
                  },
                ),
              )
            else
              // DISPLAY FOOD CATEGORIES
              Expanded(
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        textWithCard("Breakfast", screenWidth, 0.1),
                        textWithCard(
                          breakfastFoods.join("\n"),
                          screenWidth,
                          0.025,
                        ),
                        textWithCard("Lunch", screenWidth, 0.1),
                        textWithCard(lunchFoods.join("\n"), screenWidth, 0.025),
                        textWithCard("Dinner", screenWidth, 0.1),
                        textWithCard(
                          dinnerFoods.join("\n"),
                          screenWidth,
                          0.025,
                        ),
                        textWithCard("Snacks", screenWidth, 0.1),
                        textWithCard(snackFoods.join("\n"), screenWidth, 0.025),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
