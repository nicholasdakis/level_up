import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
//import 'package:cloud_firestore/cloud_firestore.dart';
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

  // Hold selected food for updating the UI in real time
  Map<String, dynamic>? selectedFood;

  // Method to extract the calories from the food-description string
  int extractCalories(String description) {
    // Apple example: "Per 100g - Calories: 52kcal | Fat: 0.17g | Carbs: 13.81g | Protein: 0.26g"
    final regex = RegExp(r'Calories:\s*(\d+)kcal', caseSensitive: false);
    final match = regex.firstMatch(description);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '') ?? 0;
    }
    return 0;
  }

  // Method for calculating caloric total for the day
  int getTotalCaloriesForDay() {
    num total = 0;

    for (var item in breakfastFoods) {
      total += (item['calories'] ?? 0);
    }
    for (var item in lunchFoods) {
      total += (item['calories'] ?? 0);
    }
    for (var item in dinnerFoods) {
      total += (item['calories'] ?? 0);
    }
    for (var item in snackFoods) {
      total += (item['calories'] ?? 0);
    }
    return total.toInt(); // convert to int at the end
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

  DateTime currentDate = DateTime.now();

  // Timer to prevent too many requests to the API too frequently
  Timer? checkTimer;

  // Variable to store the user's current time for Timer usage
  DateTime? lastInput;

  // The list that holds and displays the foods found from the user's search
  List<dynamic> foodList = [];

  // The lists that hold and display the foods and nutritional information the user selects based on the category of food
  List<Map<String, dynamic>> breakfastFoods = [];
  List<Map<String, dynamic>> lunchFoods = [];
  List<Map<String, dynamic>> dinnerFoods = [];
  List<Map<String, dynamic>> snackFoods = [];

  // Map to hold all food based on date
  Map<String, Map<String, List<Map<String, dynamic>>>> foodDataByDate = {};

  // Use Future to load and initialize user data asynchronously
  late Future<void> _loadUserDataFuture;

  @override
  void initState() {
    super.initState();
    _loadUserDataFuture = _loadUserDataAndInit();
  }

  Future<void> _loadUserDataAndInit() async {
    await userManager.loadUserData();
    if (currentUserData?.foodDataByDate != null) {
      foodDataByDate =
          Map<String, Map<String, List<Map<String, dynamic>>>>.from(
            currentUserData!.foodDataByDate,
          );
    } else {
      foodDataByDate = {};
    }
    loadFoodForDate(currentDate);
  }

  // Method to format date
  String formatDateKey(DateTime date) {
    return "${date.year.toString().padLeft(4, '0')}-" // padLeft so date x < 10 appears as 0x
        "${date.month.toString().padLeft(2, '0')}-"
        "${date.day.toString().padLeft(2, '0')}";
  }

  // Method to show the correct foods based on date
  void loadFoodForDate(DateTime date) {
    final key = formatDateKey(date);
    final dayData = foodDataByDate[key];

    setState(() {
      breakfastFoods =
          (dayData?['Breakfast'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          [];
      lunchFoods =
          (dayData?['Lunch'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
          [];
      dinnerFoods =
          (dayData?['Dinner'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          [];
      snackFoods =
          (dayData?['Snack'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
          [];
    });
  }

  // Save foodDataByDate to persistent storage after changes
  Future<void> saveFoodData() async {
    if (currentUserData == null) return;
    currentUserData!.foodDataByDate = foodDataByDate;
    await userManager.updateFoodDataByDate(foodDataByDate);
  }

  // Arrow-controlled method to change the date
  void changeDate(int days) {
    setState(() {
      currentDate = currentDate.add(Duration(days: days));
    });
    loadFoodForDate(currentDate);
  }

  @override
  void dispose() {
    checkTimer?.cancel(); // cancel the timer to prevent callbacks after dispose
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight =
        1.sh; // Make widgets the size of the user's personal screen size
    double screenWidth =
        1.sw; // Make widgets the size of the user's personal screen size

    return FutureBuilder(
      future: _loadUserDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: appColorNotifier.value.withAlpha(
              128,
            ), // Body color
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          backgroundColor: appColorNotifier.value.withAlpha(128), // Body color
          // Header box
          appBar: AppBar(
            scrolledUnderElevation: 0,
            backgroundColor: appColorNotifier.value.withAlpha(
              64,
            ), // Header color
            centerTitle: true,
            toolbarHeight: screenHeight * 0.15,
            title: createTitle("Food Logging", screenWidth),
          ),
          body: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                // date arrows and display
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_left, color: Colors.white),
                      onPressed: () => changeDate(-1),
                    ),
                    Text(
                      "${currentDate.year.toString().padLeft(4, '0')}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}",
                      style: GoogleFonts.manrope(
                        fontSize: screenWidth * 0.045,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.arrow_right, color: Colors.white),
                      onPressed: () => changeDate(1),
                    ),
                  ],
                ),

                // FatSecret attribution
                Container(
                  alignment: Alignment.center,
                  child: InkWell(
                    onTap: () async {
                      await launchFatSecret();
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

                // Display total calories text
                Text(
                  "Total Calories: ${getTotalCaloriesForDay()}",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                // Search Food input
                SizedBox(
                  width: screenWidth * 0.9,
                  child: Theme(
                    data: Theme.of(context).copyWith(
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
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.grey,
                            width: 0.25,
                          ),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.grey,
                            width: 0.25,
                          ),
                        ),
                        hintText: "Search",
                        suffixIcon: Icon(Icons.search),
                        contentPadding: EdgeInsets.only(top: 13, left: 6),
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
                        lastInput = DateTime.now();
                        checkTimer?.cancel();
                        checkTimer = Timer(Duration(milliseconds: 750), () {
                          handleApiCall(lastInput, value);
                        });
                      },
                    ),
                  ),
                ),

                SizedBox(height: 0.01 * screenHeight),

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
                          maxHeight: 200,
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
                          setState(() {
                            mealType = value;
                          });
                        },
                      ),
                    ),

                    // Log Food Button
                    Expanded(
                      child: SizedBox(
                        height: screenHeight * 0.075,
                        width: screenWidth * 0.4,
                        child: simpleCustomButton(
                          "Log Food",
                          context,
                          baseColor: appColorNotifier.value.withAlpha(64),
                          onPressed: () async {
                            if (mealType == null || !mealChosen) {
                              if (snackbarActive) return;
                              snackbarActive = true;
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
                                    snackbarActive = false;
                                  });
                              return;
                            } else {
                              final foodObject = selectedFood;

                              // extract calories
                              if (foodObject != null) {
                                foodObject['calories'] = extractCalories(
                                  foodObject['food_description'] ?? '',
                                );

                                // extract the key for the current date
                                final dateKey = formatDateKey(currentDate);

                                // create a map for the date if it does not exist
                                if (!foodDataByDate.containsKey(dateKey)) {
                                  foodDataByDate[dateKey] = {
                                    "Breakfast": [],
                                    "Lunch": [],
                                    "Dinner": [],
                                    "Snack": [],
                                  };
                                }

                                foodDataByDate[dateKey]![mealType!]!.add(
                                  foodObject,
                                );

                                // update to firestore
                                await saveFoodData();

                                setState(() {
                                  loadFoodForDate(
                                    currentDate,
                                  ); // update locally by refreshing UI

                                  // reset conditions for searching
                                  userCanType = true;
                                  mealChosen = false;
                                  selectedFood = null;
                                  searchController.clear();
                                  mealType = null;
                                });
                              }
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 20),

                // foodList not empty means the user searched a food and the API returned results
                if (foodList.isNotEmpty)
                  Expanded(
                    child: ListView.builder(
                      itemCount: foodList.length,
                      itemBuilder: (context, index) {
                        final food = foodList[index];
                        return InkWell(
                          onTap: () {
                            // upon tap, the table disappears, the user cannot tap, and the search bar becomes the clicked-on food
                            FocusScope.of(context).unfocus();
                            setState(() {
                              userCanType = false;
                              mealChosen = true;

                              selectedFood = food;

                              searchController.text = food["food_name"] ?? "";
                              searchController.selection =
                                  TextSelection.fromPosition(
                                    TextPosition(
                                      offset: searchController.text.length,
                                    ),
                                  );
                              foodList = [];
                            });
                          },
                          // ListTile displays the returned foods from the API and their corresponding descriptions (i.e nutritional information)
                          child: ListTile(
                            title: Text(
                              food['food_name'] ?? '',
                              style: GoogleFonts.manrope(color: Colors.white),
                            ),
                            subtitle: Text(
                              food['food_description'] ?? '',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        );
                      },
                    ),
                  )
                // Else means no food is being searched for, so show the table of meals
                else
                  Expanded(
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Breakfast
                            ExpansionTile(
                              initiallyExpanded: true,
                              title: textWithCard(
                                "Breakfast (${breakfastFoods.length})",
                                screenWidth,
                                0.1,
                              ),
                              children: breakfastFoods.asMap().entries.map((
                                entry,
                              ) {
                                int idx = entry
                                    .key; // store index of food for deletion option
                                Map<String, dynamic> food = entry.value;
                                return Dismissible(
                                  // Dismissible widget so the food can be swiped to delete
                                  key: ValueKey(
                                    "breakfast_$idx${food['food_name']}", // unique key that combines the index and food name
                                  ),
                                  // formatting of background when user swipes to delete a food
                                  background: Container(
                                    color: Colors.red,
                                    alignment: Alignment.centerRight,
                                    padding: EdgeInsets.only(right: 20),
                                    child: Icon(
                                      Icons.delete,
                                      color: Colors.white,
                                    ),
                                  ),
                                  direction: DismissDirection.endToStart,
                                  onDismissed: (direction) async {
                                    setState(() {
                                      // when the user swipes to delete, remove the food and update to the server
                                      breakfastFoods.removeAt(idx);
                                      final dateKey = formatDateKey(
                                        currentDate,
                                      );
                                      foodDataByDate[dateKey]!['Breakfast'] =
                                          breakfastFoods;
                                    });
                                    await saveFoodData();
                                  },
                                  // Display breakfast food name
                                  child: ListTile(
                                    title: Text(
                                      food['food_name'] ?? '',
                                      style: GoogleFonts.manrope(
                                        color: Colors.white,
                                      ),
                                    ),
                                    // Display breakfast calories under food name
                                    subtitle: Text(
                                      "${food['calories'] ?? 0} kcal",
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ),
                                );
                              }).toList(), // convert to a List<Widget> so ExpansionTile can render
                            ),

                            // Lunch
                            ExpansionTile(
                              initiallyExpanded: true,
                              title: textWithCard(
                                "Lunch (${lunchFoods.length})",
                                screenWidth,
                                0.1,
                              ),
                              children: lunchFoods.asMap().entries.map((entry) {
                                int idx = entry
                                    .key; // store index of food for deletion option
                                Map<String, dynamic> food = entry.value;
                                return Dismissible(
                                  // Dismissible widget so the food can be swiped to delete
                                  key: ValueKey(
                                    "lunch_$idx${food['food_name']}", // unique key that combines the index and food name
                                  ),
                                  // formatting of background when user swipes to delete a food
                                  background: Container(
                                    color: Colors.red,
                                    alignment: Alignment.centerRight,
                                    padding: EdgeInsets.only(right: 20),
                                    child: Icon(
                                      Icons.delete,
                                      color: Colors.white,
                                    ),
                                  ),
                                  direction: DismissDirection.endToStart,
                                  onDismissed: (direction) async {
                                    setState(() {
                                      // when the user swipes to delete, remove the food and update to the server
                                      lunchFoods.removeAt(idx);
                                      final dateKey = formatDateKey(
                                        currentDate,
                                      );
                                      foodDataByDate[dateKey]!['Lunch'] =
                                          lunchFoods;
                                    });
                                    await saveFoodData();
                                  },
                                  // Display lunch food name
                                  child: ListTile(
                                    title: Text(
                                      food['food_name'] ?? '',
                                      style: GoogleFonts.manrope(
                                        color: Colors.white,
                                      ),
                                    ),
                                    // Display lunch calories under food name
                                    subtitle: Text(
                                      "${food['calories'] ?? 0} kcal",
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ),
                                );
                              }).toList(), // convert to a List<Widget> so ExpansionTile can render
                            ),

                            // Dinner
                            ExpansionTile(
                              initiallyExpanded: true,
                              title: textWithCard(
                                "Dinner (${dinnerFoods.length})",
                                screenWidth,
                                0.1,
                              ),
                              children: dinnerFoods.asMap().entries.map((
                                entry,
                              ) {
                                int idx = entry
                                    .key; // store index of food for deletion option
                                Map<String, dynamic> food = entry.value;
                                return Dismissible(
                                  // Dismissible widget so the food can be swiped to delete
                                  key: ValueKey(
                                    "dinner_$idx${food['food_name']}", // unique key that combines the index and food name
                                  ),
                                  // formatting of background when user swipes to delete a food
                                  background: Container(
                                    color: Colors.red,
                                    alignment: Alignment.centerRight,
                                    padding: EdgeInsets.only(right: 20),
                                    child: Icon(
                                      Icons.delete,
                                      color: Colors.white,
                                    ),
                                  ),
                                  direction: DismissDirection.endToStart,
                                  onDismissed: (direction) async {
                                    setState(() {
                                      // when the user swipes to delete, remove the food and update to the server
                                      dinnerFoods.removeAt(idx);
                                      final dateKey = formatDateKey(
                                        currentDate,
                                      );
                                      foodDataByDate[dateKey]!['Dinner'] =
                                          dinnerFoods;
                                    });
                                    await saveFoodData();
                                  },
                                  // Display dinner food name
                                  child: ListTile(
                                    title: Text(
                                      food['food_name'] ?? '',
                                      style: GoogleFonts.manrope(
                                        color: Colors.white,
                                      ),
                                    ),
                                    // Display dinner calories under food name
                                    subtitle: Text(
                                      "${food['calories'] ?? 0} kcal",
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ),
                                );
                              }).toList(), // convert to a List<Widget> so ExpansionTile can render
                            ),

                            // Snacks
                            ExpansionTile(
                              initiallyExpanded: true,
                              title: textWithCard(
                                "Snacks (${snackFoods.length})",
                                screenWidth,
                                0.1,
                              ),
                              children: snackFoods.asMap().entries.map((entry) {
                                int idx = entry
                                    .key; // store index of food for deletion option
                                Map<String, dynamic> food = entry.value;
                                return Dismissible(
                                  // Dismissible widget so the food can be swiped to delete
                                  key: ValueKey(
                                    "snack_$idx${food['food_name']}", // unique key that combines the index and food name
                                  ),
                                  // formatting of background when user swipes to delete a food
                                  background: Container(
                                    color: Colors.red,
                                    alignment: Alignment.centerRight,
                                    padding: EdgeInsets.only(right: 20),
                                    child: Icon(
                                      Icons.delete,
                                      color: Colors.white,
                                    ),
                                  ),
                                  direction: DismissDirection.endToStart,
                                  onDismissed: (direction) async {
                                    setState(() {
                                      // when the user swipes to delete, remove the food and update to the server
                                      snackFoods.removeAt(idx);
                                      final dateKey = formatDateKey(
                                        currentDate,
                                      );
                                      foodDataByDate[dateKey]!['Snack'] =
                                          snackFoods;
                                    });
                                    await saveFoodData();
                                  },
                                  // Display snack food name
                                  child: ListTile(
                                    title: Text(
                                      food['food_name'] ?? '',
                                      style: GoogleFonts.manrope(
                                        color: Colors.white,
                                      ),
                                    ),
                                    // Display snack calories under food name
                                    subtitle: Text(
                                      "${food['calories'] ?? 0} kcal",
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ),
                                );
                              }).toList(), // convert to a List<Widget> so ExpansionTile can render
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
