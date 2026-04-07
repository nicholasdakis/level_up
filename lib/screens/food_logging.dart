import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
//import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart'; // FatSecret snippet code launch
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:async'; // for using Timer
import 'package:flutter/services.dart'; // for input validation on manual entry fields
// Packages for handling food information through the server.py file
import 'dart:convert';
import 'package:http/http.dart' as http;
// Class imports
import '../globals.dart';
import '../utility/responsive.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../user/user_data_manager.dart';

// Tab indices for the food logging input methods
class FoodTab {
  static const int search = 0;
  static const int barcode = 1;
  static const int manual = 2;
}

class FoodLogging extends StatefulWidget {
  const FoodLogging({super.key});

  @override
  State<FoodLogging> createState() => _FoodLoggingState();
}

class _FoodLoggingState extends State<FoodLogging>
    with SingleTickerProviderStateMixin {
  // SingleTickerProviderStateMixin is needed for TabController
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

  int getTotalCaloriesForDay() {
    num total = 0;

    for (var item in breakfastFoods) {
      total += num.tryParse(item['calories'].toString()) ?? 0;
    }
    for (var item in lunchFoods) {
      total += num.tryParse(item['calories'].toString()) ?? 0;
    }
    for (var item in dinnerFoods) {
      total += num.tryParse(item['calories'].toString()) ?? 0;
    }
    for (var item in snacksFoods) {
      total += num.tryParse(item['calories'].toString()) ?? 0;
    }
    return total.toInt();
  }

  Future<void> launchWebsite(String websiteUrl) async {
    final uri = Uri.parse(websiteUrl); // Store the url as a Uri
    if (!await launchUrl(uri)) {
      // If the website could not be launched
      throw "Error: Could not open website.";
    }
  }

  Widget buildSearchButton() {
    return Expanded(
      child: TextField(
        controller: searchController,
        enabled: userCanType,
        keyboardType: TextInputType.text,
        style: GoogleFonts.manrope(
          fontSize: Responsive.font(context, 17),
          color: Colors.white,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: "Search",
          suffixIcon: Icon(Icons.search, color: Colors.white54),
          contentPadding: EdgeInsets.symmetric(
            vertical: Responsive.height(context, 12),
            horizontal: Responsive.width(context, 14),
          ),
          hintStyle: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 15),
            color: Colors.white54,
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
    );
  }

  Widget buildLogFoodButton() {
    return frostedButton(
      "Log Food",
      context,
      onPressed: () async {
        final tab = _tabController.index;
        if (tab == FoodTab.search) {
          if (mealType == null || !mealChosen) {
            if (snackbarActive) return;
            snackbarActive = true;
            ScaffoldMessenger.of(context)
                .showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.info, color: Colors.white),
                        SizedBox(width: Responsive.width(context, 10)),
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
          }
          if (selectedFood != null) {
            await logFood(Map<String, dynamic>.from(selectedFood!));
          }
        } else if (tab == FoodTab.barcode) {
          if (barcodeResult == null) {
            if (snackbarActive) return;
            snackbarActive = true;
            ScaffoldMessenger.of(context)
                .showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.info, color: Colors.white),
                        SizedBox(width: Responsive.width(context, 10)),
                        Text("Scan a barcode first."),
                      ],
                    ),
                  ),
                )
                .closed
                .then((_) {
                  snackbarActive = false;
                });
            return;
          }
          await logFood(Map<String, dynamic>.from(barcodeResult!));
        } else if (tab == FoodTab.manual) {
          await handleManualEntry();
        }
      },
    );
  }

  Widget buildAttribution(
    String websiteUrl,
    String displayText,
    Color textColor,
  ) {
    return Container(
      alignment: Alignment.center,
      child: InkWell(
        onTap: () async {
          await launchWebsite(websiteUrl);
        },
        child: Column(
          children: [
            textWithFont(
              displayText,
              context,
              Responsive.font(context, 16),
              color: textColor,
            ),
          ],
        ),
      ),
    );
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

    // Normalize the query to reduce API calls
    query = query
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim(); // remove extra spaces and lowercase the query

    final url = Uri.parse(
      'https://level-up-69vz.onrender.com/get_food/$query',
    ); // search the food via the backend get_food method
    try {
      final response = await http.get(url);

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
      if (!isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Error searching for foods. Check your connection and try again.",
            ),
            duration: Duration(milliseconds: 1500),
          ),
        );
      }
    }
  }

  // Barcode lookup via Open Food Facts
  Future<void> lookupBarcode(String barcode) async {
    setState(() {
      barcodeLoading = true;
      barcodeResult = null;
      barcodeError = null;
    });

    try {
      final url = Uri.parse(
        'https://world.openfoodfacts.org/api/v2/product/$barcode.json',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 1) {
          final product = data['product'];
          final nutriments = product['nutriments'] ?? {};

          // Build a description string matching FatSecret format
          final calories = (nutriments['energy-kcal_100g'] ?? 0).round();
          final fat = nutriments['fat_100g'] ?? 0;
          final carbs = nutriments['carbohydrates_100g'] ?? 0;
          final protein = nutriments['proteins_100g'] ?? 0;

          final description =
              'Per 100g - Calories: ${calories}kcal | Fat: ${fat}g | Carbs: ${carbs}g | Protein: ${protein}g';

          setState(() {
            barcodeResult = {
              'food_name': product['product_name'] ?? 'Unknown Product',
              'food_description': description,
            };
            barcodeLoading = false;
          });
        } else {
          setState(() {
            barcodeError = "Product not found in database.";
            barcodeLoading = false;
          });
        }
      } else {
        setState(() {
          barcodeError = "Failed to look up product. Try again.";
          barcodeLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        barcodeError = "Network error. Check your connection.";
        barcodeLoading = false;
      });
    }
  }

  final TextEditingController searchController =
      TextEditingController(); // for reading the user's search input

  // Whether the user is allowed to type in the search bar. This is disabled after a food is clicked on
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
  List<Map<String, dynamic>> snacksFoods = [];

  // Map to hold all food based on date
  Map<String, Map<String, List<Map<String, dynamic>>>> foodDataByDate = {};

  // Use Future to load and initialize user data asynchronously
  late Future<void> _loadUserDataFuture;

  // Tab controller for Search, Barcode, Manual Entry
  late TabController _tabController;

  // Barcode tab state
  bool barcodeLoading = false;
  Map<String, dynamic>? barcodeResult;
  String? barcodeError;
  bool scannerActive = false;

  // Manual entry controllers
  final TextEditingController manualNameController = TextEditingController();
  final TextEditingController manualCaloriesController =
      TextEditingController();
  final TextEditingController manualFatController = TextEditingController();
  final TextEditingController manualCarbsController = TextEditingController();
  final TextEditingController manualProteinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserDataFuture = _loadUserDataAndInit();
  }

  Future<void> _loadUserDataAndInit() async {
    // Skip reloading all user data if already loaded for this user to avoid unnecessary Firestore reads on every tab switch
    if (currentUserData != null &&
        currentUserData!.uid == FirebaseAuth.instance.currentUser?.uid) {
      // Always refresh food data in case it was updated on another device
      await userManager.loadFoodData(currentUserData!.uid);
      // Sync the local food map with the updated data from Firestore
      if (currentUserData?.foodDataByDate != null) {
        foodDataByDate =
            Map<String, Map<String, List<Map<String, dynamic>>>>.from(
              currentUserData!.foodDataByDate,
            );
      } else {
        foodDataByDate = {};
      }
      loadFoodForDate(currentDate);
      return;
    }

    // First time loading for this user, so load all user data from Firestore and the backend
    await userManager.loadUserData();
    // Sync the local food map with the loaded data
    if (currentUserData?.foodDataByDate != null) {
      foodDataByDate =
          Map<String, Map<String, List<Map<String, dynamic>>>>.from(
            currentUserData!.foodDataByDate,
          );
    } else {
      // no food data found
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
      snacksFoods =
          (dayData?['Snacks'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          [];
    });
  }

  // Save foodDataByDate to persistent storage after changes
  Future<void> saveFoodData() async {
    if (currentUserData == null) return;
    currentUserData!.foodDataByDate = foodDataByDate;
    await userManager.updateFoodDataByDate(foodDataByDate, context: context);
  }

  // Arrow-controlled method to change the date
  void changeDate(int days) {
    setState(() {
      currentDate = currentDate.add(Duration(days: days));
    });
    loadFoodForDate(currentDate);
  }

  // Open a calendar picker to jump to a specific date
  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2026),
      lastDate: DateTime(2100),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked != null) {
      setState(() {
        currentDate = picked;
      });
      loadFoodForDate(currentDate);
    }
  }

  // Log the selected food to the chosen meal type
  Future<void> logFood(Map<String, dynamic> foodObject) async {
    debugPrint('logFood called');
    debugPrint('mealType: $mealType');
    debugPrint('foodObject: $foodObject');

    if (mealType == null) {
      if (snackbarActive) return;
      snackbarActive = true;
      ScaffoldMessenger.of(context)
          .showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.info, color: Colors.white),
                  SizedBox(width: Responsive.width(context, 10)),
                  Text("Please select a meal type."),
                ],
              ),
            ),
          )
          .closed
          .then((_) {
            snackbarActive = false;
          });
      return;
    }

    // extract calories from API search / barcode scanning (not for manual as it is already set as a key in the foodObject)
    if (!foodObject.containsKey('calories')) {
      foodObject['calories'] = extractCalories(
        foodObject['food_description'] ?? '',
      );
    }

    // extract the key for the current date
    final dateKey = formatDateKey(currentDate);

    // create a map for the date if it does not exist
    if (!foodDataByDate.containsKey(dateKey)) {
      foodDataByDate[dateKey] = {
        "Breakfast": [],
        "Lunch": [],
        "Dinner": [],
        "Snacks": [],
      };
    }

    foodDataByDate[dateKey]![mealType!]!.add(foodObject);

    // update to firestore
    await saveFoodData();

    setState(() {
      loadFoodForDate(currentDate); // update locally by refreshing UI

      // reset conditions for searching
      userCanType = true;
      mealChosen = false;
      selectedFood = null;
      searchController.clear();
      foodList = [];

      // Reset barcode tab state
      barcodeResult = null;
      barcodeError = null;
      scannerActive = false;

      // Reset manual entry state
      manualNameController.clear();
      manualCaloriesController.clear();
      manualFatController.clear();
      manualCarbsController.clear();
      manualProteinController.clear();

      mealType = null;
    });
  }

  // Handle logging from the manual entry tab
  Future<void> handleManualEntry() async {
    final name = manualNameController.text.trim();
    final caloriesText = manualCaloriesController.text.trim();

    if (name.isEmpty || caloriesText.isEmpty) {
      if (snackbarActive) return;
      snackbarActive = true;
      ScaffoldMessenger.of(context)
          .showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.info, color: Colors.white),
                  SizedBox(width: Responsive.width(context, 10)),
                  Text("Food name and calories are required."),
                ],
              ),
            ),
          )
          .closed
          .then((_) {
            snackbarActive = false;
          });
      return;
    }

    final calories =
        int.tryParse(manualCaloriesController.text.trim()) ??
        0; // calories is expected as an int because of logFood, but also as a string for the description
    final fat = manualFatController.text.trim();
    final carbs = manualCarbsController.text.trim();
    final protein = manualProteinController.text.trim();

    // Check if all optional fields are empty and warn the user
    if (fat.isEmpty && carbs.isEmpty && protein.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: darkenColor(
            appColorNotifier.value,
            0.025,
          ).withAlpha(200),
          title: Text(
            "No macronutrients entered!",
            style: GoogleFonts.manrope(color: Colors.white),
          ),
          content: Text(
            "You haven't entered any fat, carbs, or protein for this food. Log anyway?",
            style: GoogleFonts.manrope(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Go Back", style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _submitManualEntry(name, calories, fat, carbs, protein);
              },
              child: Text("Log Anyway", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }
    await _submitManualEntry(name, calories, fat, carbs, protein);
  }

  Future<void> _submitManualEntry(
    String name,
    int calories,
    String fat,
    String carbs,
    String protein,
  ) async {
    // Add together the non-empty parts to create a description string in the same format as the API results
    final parts = <String>['Calories: ${calories}kcal'];
    if (fat.isNotEmpty) parts.add('Fat: ${fat}g');
    if (carbs.isNotEmpty) parts.add('Carbs: ${carbs}g');
    if (protein.isNotEmpty) parts.add('Protein: ${protein}g');
    final description = 'Per serving - ${parts.join(' | ')}';

    final foodObject = {
      'food_name': name,
      'food_description': description,
      'calories': calories,
    };

    await logFood(foodObject);
  }

  @override
  void dispose() {
    checkTimer?.cancel(); // cancel the timer to prevent callbacks after dispose
    searchController.dispose();
    _tabController.dispose();
    manualNameController.dispose();
    manualCaloriesController.dispose();
    manualFatController.dispose();
    manualCarbsController.dispose();
    manualProteinController.dispose();
    super.dispose();
  }

  // Shared text field styling for the manual entry tab
  Widget _buildManualField(
    TextEditingController controller,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: Responsive.height(context, 4)),
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
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 16),
            color: Colors.white,
          ),
          decoration: InputDecoration(
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: lightenColor(appColorNotifier.value, 0.15),
                width: Responsive.scale(context, 0.25),
              ),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: lightenColor(appColorNotifier.value, 0.25),
                width: Responsive.scale(context, 0.25),
              ),
            ),
            hintText: hint,
            contentPadding: EdgeInsets.only(
              top: Responsive.height(context, 13),
              left: Responsive.width(context, 6),
            ),
            hintStyle: GoogleFonts.manrope(
              fontSize: Responsive.font(context, 14),
              color: Colors.white54,
            ),
          ),
        ),
      ),
    );
  }

  // Build the Search tab content
  Widget _buildSearchTab() {
    return Column(
      children: [
        buildAttribution(
          "https://www.fatsecret.com",
          "Powered by fatsecret",
          Colors.blue,
        ),

        SizedBox(height: Responsive.height(context, 10)),

        // Search Food input inside frosted glass
        Center(
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.width(context, 20),
              ),
              child: buildLogFoodButton(),
            ),
          ),
        ),

        SizedBox(height: Responsive.height(context, 10)),

        // Search results
        if (foodList.isNotEmpty)
          Expanded(
            child: ListView.builder(
              itemCount: foodList.length,
              itemBuilder: (context, index) {
                final food = foodList[index];
                return InkWell(
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    setState(() {
                      userCanType = false;
                      mealChosen = true;
                      selectedFood = food;
                      searchController.text = food["food_name"] ?? "";
                      searchController.selection = TextSelection.fromPosition(
                        TextPosition(offset: searchController.text.length),
                      );
                      foodList = [];
                    });
                  },
                  child: ListTile(
                    title: Text(
                      food['food_name'] ?? '',
                      style: GoogleFonts.manrope(color: Colors.white),
                    ),
                    subtitle: Text(
                      food['food_description'] ?? '',
                      style: TextStyle(
                        color: lightenColor(appColorNotifier.value, 0.2),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // Build the Barcode tab content
  Widget _buildBarcodeTab() {
    return Column(
      children: [
        buildAttribution(
          "https://openfoodfacts.org",
          "Powered by Open Food Facts",
          Colors.green,
        ),

        SizedBox(height: Responsive.height(context, 10)),

        // Full width scan button when scanner is not active
        if (!scannerActive && barcodeResult == null && barcodeError == null)
          GestureDetector(
            onTap: () {
              setState(() {
                scannerActive = true;
              });
            },
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.width(context, 10),
              ),
              child: SizedBox(
                width: double.infinity,
                child: frostedGlassCard(
                  context,
                  baseRadius: 24,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: Responsive.height(context, 10)),
                      Text(
                        "Scan Barcode",
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 24),
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: Responsive.height(context, 8)),
                      Text(
                        "Tap to open camera",
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 13),
                          color: Colors.white38,
                        ),
                      ),
                      SizedBox(height: Responsive.height(context, 10)),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Scanner view
        if (scannerActive)
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                Responsive.scale(context, 12),
              ),
              child: MobileScanner(
                onDetect: (BarcodeCapture capture) {
                  final barcode = capture.barcodes.firstOrNull;
                  if (barcode != null && barcode.rawValue != null) {
                    setState(() {
                      scannerActive = false;
                    });
                    lookupBarcode(barcode.rawValue!);
                  }
                },
              ),
            ),
          ),

        // Loading indicator
        if (barcodeLoading)
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: Responsive.height(context, 40),
            ),
            child: CircularProgressIndicator(color: Colors.white),
          ),

        // Error message
        if (barcodeError != null)
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: Responsive.height(context, 20),
            ),
            child: Column(
              children: [
                Text(
                  barcodeError!,
                  style: GoogleFonts.manrope(
                    color: Colors.redAccent,
                    fontSize: Responsive.font(context, 16),
                  ),
                ),
                SizedBox(height: Responsive.height(context, 10)),
                frostedButton(
                  "Try Again",
                  context,
                  onPressed: () {
                    setState(() {
                      barcodeError = null;
                      scannerActive = true;
                    });
                  },
                ),
              ],
            ),
          ),

        // Barcode result
        if (barcodeResult != null)
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: Responsive.height(context, 10),
            ),
            child: Column(
              children: [
                ListTile(
                  title: Text(
                    barcodeResult!['food_name'] ?? '',
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontSize: Responsive.font(context, 18),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    barcodeResult!['food_description'] ?? '',
                    style: TextStyle(
                      color: lightenColor(appColorNotifier.value, 0.2),
                      fontSize: Responsive.font(context, 14),
                    ),
                  ),
                ),
                SizedBox(height: Responsive.height(context, 10)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    frostedButton(
                      "Scan Again",
                      context,
                      onPressed: () {
                        setState(() {
                          barcodeResult = null;
                          scannerActive = true;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  // Build the Manual Entry tab content, all fields inside one frosted glass card
  Widget _buildManualEntryTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: EdgeInsets.only(
              top: Responsive.height(context, 16),
              bottom: Responsive.height(context, 12),
              left: Responsive.width(context, 4),
            ),
            child: Text(
              "ENTER FOOD INFORMATION",
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 15),
                color: Colors.white38,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
          ),
          frostedGlassCard(
            context,
            baseRadius: 20,
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.width(context, 20),
              vertical: Responsive.height(context, 16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "REQUIRED",
                  style: GoogleFonts.manrope(
                    fontSize: Responsive.font(context, 15),
                    color: Colors.white38,
                    fontWeight: FontWeight.w700,
                    letterSpacing: Responsive.scale(context, 1.4),
                  ),
                ),
                _buildManualField(manualNameController, "Food Name"),
                _buildManualField(
                  manualCaloriesController,
                  "Calories (kcal)",
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      final text = newValue.text;

                      if (text.isEmpty) return newValue;

                      return RegExp(r'^\d{0,5}(\.\d{0,3})?$').hasMatch(text)
                          ? newValue
                          : oldValue;
                    }),
                  ], // only whole numbers
                ),
                SizedBox(height: Responsive.height(context, 16)),
                Text(
                  "OPTIONAL",
                  style: GoogleFonts.manrope(
                    fontSize: Responsive.font(context, 15),
                    color: Colors.white38,
                    fontWeight: FontWeight.w700,
                    letterSpacing: Responsive.scale(context, 1.4),
                  ),
                ),
                _buildManualField(
                  manualProteinController,
                  "Protein (g)",
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      final text = newValue.text;

                      if (text.isEmpty) return newValue;

                      return RegExp(r'^\d{0,5}(\.\d{0,3})?$').hasMatch(text)
                          ? newValue
                          : oldValue;
                    }),
                  ],
                ),
                _buildManualField(
                  manualCarbsController,
                  "Carbs (g)",
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      final text = newValue.text;

                      if (text.isEmpty) return newValue;

                      return RegExp(r'^\d{0,5}(\.\d{0,3})?$').hasMatch(text)
                          ? newValue
                          : oldValue;
                    }),
                  ],
                ),
                _buildManualField(
                  manualFatController,
                  "Fat (g)",
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      final text = newValue.text;

                      if (text.isEmpty) return newValue;

                      return RegExp(r'^\d{0,5}(\.\d{0,3})?$').hasMatch(text)
                          ? newValue
                          : oldValue;
                    }),
                  ],
                ),
              ],
            ),
          ),
          // Meal tiles inline so everything scrolls together
          _buildMealSection("Breakfast", breakfastFoods),
          _buildMealSection("Lunch", lunchFoods),
          _buildMealSection("Dinner", dinnerFoods),
          _buildMealSection("Snacks", snacksFoods),
          SizedBox(height: Responsive.height(context, 20)),
        ],
      ),
    );
  }

  // Build the meal sections (shared across all tabs)
  Widget _buildMealTiles() {
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: Responsive.width(context, 16)),
      children: [
        // Breakfast
        _buildMealSection("Breakfast", breakfastFoods),
        // Lunch
        _buildMealSection("Lunch", lunchFoods),
        // Dinner
        _buildMealSection("Dinner", dinnerFoods),
        // Snacks
        _buildMealSection("Snacks", snacksFoods),
        SizedBox(height: Responsive.height(context, 20)),
      ],
    );
  }

  Widget _buildMealSection(String title, List<Map<String, dynamic>> foods) {
    final key = title;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: EdgeInsets.only(
            top: Responsive.height(context, 16),
            bottom: Responsive.height(context, 12),
            left: Responsive.width(context, 4),
          ),
          child: Text(
            "${title.toUpperCase()} (${foods.length})",
            style: GoogleFonts.manrope(
              fontSize: Responsive.font(context, 15),
              color: Colors.white38,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
        ),
        // Food cards or empty state
        if (foods.isEmpty)
          Padding(
            padding: EdgeInsets.only(
              left: Responsive.width(context, 4),
              bottom: Responsive.height(context, 4),
            ),
            child: Text(
              "No foods logged",
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 13),
                color: Colors.white24,
              ),
            ),
          )
        else
          ...foods.asMap().entries.map((entry) {
            // spread operator to individually return each food card, as well as index for unique keys and deletion
            int idx = entry.key; // store index of food for deletion option
            Map<String, dynamic> food = entry.value;
            return Dismissible(
              // Dismissible widget so the food can be swiped to delete
              key: ValueKey(
                "${key.toLowerCase()}_$idx${food['food_name']}",
              ), // unique key that combines the index and food name
              // formatting of background when user swipes to delete a food
              background: Container(
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.centerRight,
                padding: EdgeInsets.only(right: Responsive.width(context, 20)),
                child: Icon(Icons.delete, color: Colors.white),
              ),
              direction: DismissDirection.endToStart,
              onDismissed: (direction) async {
                setState(() {
                  // when the user swipes to delete, remove the food and update to the server
                  foods.removeAt(idx);
                  final dateKey = formatDateKey(currentDate);
                  foodDataByDate[dateKey]![key] = foods;
                });
                await saveFoodData();
              },
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: Responsive.height(context, 10),
                ),
                child: frostedGlassCard(
                  context,
                  baseRadius: 16,
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.width(context, 20),
                    vertical: Responsive.height(context, 14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.restaurant_outlined,
                        color: appColorNotifier.value,
                        size: Responsive.scale(context, 22),
                      ),
                      SizedBox(width: Responsive.width(context, 14)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              food['food_name'] ?? '',
                              style: GoogleFonts.manrope(
                                fontSize: Responsive.font(context, 15),
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: Responsive.height(context, 4)),
                            // Display calories under food name
                            Text(
                              "${num.tryParse(food['calories'].toString()) ?? 0} kcal",
                              style: GoogleFonts.manrope(
                                fontSize: Responsive.font(context, 12),
                                color: Colors.white60,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Delete button to remove a food by tapping instead of swiping
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                          size: Responsive.scale(context, 20),
                        ),
                        onPressed: () async {
                          setState(() {
                            foods.removeAt(idx);
                            final dateKey = formatDateKey(currentDate);
                            foodDataByDate[dateKey]![key] = foods;
                          });
                          await saveFoodData();
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _loadUserDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Container(
            decoration: BoxDecoration(gradient: buildThemeGradient()),
            child: Scaffold(
              backgroundColor: Colors.transparent, // Body color
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: Responsive.height(context, 24)),
                    Text(
                      "Loading food data, please wait...",
                      style: TextStyle(
                        fontSize: Responsive.font(context, 20),
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(gradient: buildThemeGradient()),
          child: Scaffold(
            backgroundColor: Colors.transparent, // Body color
            // Header box
            appBar: AppBar(
              scrolledUnderElevation: 0,
              backgroundColor: darkenColor(
                appColorNotifier.value,
                0.025,
              ), // Header color
              centerTitle: true,
              toolbarHeight: Responsive.buttonHeight(context, 120),
              title: createTitle("Food Logging", context),
            ),
            body: Padding(
              padding: EdgeInsets.all(Responsive.width(context, 16)),
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
                      InkWell(
                        onTap: pickDate,
                        borderRadius: BorderRadius.circular(
                          Responsive.scale(context, 8),
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: Responsive.width(context, 12),
                            vertical: Responsive.height(context, 6),
                          ),
                          child: Text(
                            "${const ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][currentDate.month - 1]} ${currentDate.day}, ${currentDate.year}",
                            style: GoogleFonts.manrope(
                              fontSize: Responsive.font(context, 18),
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.arrow_right, color: Colors.white),
                        onPressed: () => changeDate(1),
                      ),
                    ],
                  ),

                  // Display total calories text
                  Text(
                    "Total Calories: ${getTotalCaloriesForDay()}",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: Responsive.font(context, 20),
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: Responsive.height(context, 8)),

                  // Tab bar
                  TabBar(
                    controller: _tabController,
                    onTap: (_) => setState(() {}),
                    indicatorColor: Colors.white,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    labelStyle: GoogleFonts.manrope(
                      fontSize: Responsive.font(
                        context,
                        20,
                      ), // label gets bigger on the selected tab
                      fontWeight: FontWeight.bold,
                    ),
                    unselectedLabelStyle: GoogleFonts.manrope(
                      fontSize: Responsive.font(
                        context,
                        15,
                      ), // unselected tab label size
                    ),
                    tabs: const [
                      Tab(text: "Search"),
                      Tab(text: "Barcode"),
                      Tab(text: "Manual"),
                    ],
                  ),

                  SizedBox(height: Responsive.height(context, 8)),

                  // Horizontally lay out the next two buttons
                  Row(
                    children: [
                      // Meal Type chooser
                      DropdownButton2<String>(
                        dropdownStyleData: DropdownStyleData(
                          decoration: BoxDecoration(
                            color: appColorNotifier.value.withAlpha(128),
                            borderRadius: BorderRadius.circular(
                              Responsive.scale(context, 10),
                            ),
                          ),
                          maxHeight: Responsive.height(context, 200),
                        ),
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 15),
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              offset: Offset(
                                Responsive.scale(context, 4),
                                Responsive.scale(context, 4),
                              ),
                              blurRadius: Responsive.scale(context, 10),
                              color: const Color.fromARGB(255, 0, 0, 0),
                            ),
                          ],
                        ),
                        hint: Text(
                          "Meal Type",
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 20),
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                offset: Offset(
                                  Responsive.scale(context, 4),
                                  Responsive.scale(context, 4),
                                ),
                                blurRadius: Responsive.scale(context, 10),
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
                          addMenuItem("Snacks"),
                        ],
                        onChanged: (value) {
                          setState(() {
                            mealType = value;
                          });
                        },
                      ),

                      // Separate the two buttons with some space
                      SizedBox(width: Responsive.width(context, 25)),

                      // Search Button, which is replaced with the Log Food button when not on the Search tab
                      _tabController.index == FoodTab.search
                          ? buildSearchButton()
                          : Expanded(child: buildLogFoodButton()),
                    ],
                  ),

                  SizedBox(height: Responsive.height(context, 10)),

                  // Tab content area and meal tiles
                  Expanded(
                    child: Column(
                      children: [
                        if (_hasActiveInput()) // Meal tiles shouldn't show
                          Expanded(
                            child: _tabController.index == FoodTab.search
                                ? _buildSearchTab()
                                : _buildBarcodeTab(),
                          )
                        else if (_tabController.index == FoodTab.manual)
                          Expanded(child: _buildManualEntryTab())
                        else ...[
                          // Spread operator to conditionally include the tab content only when there's no active input, allowing meal tiles to take up remaining space
                          if (_tabController.index == FoodTab.search)
                            _buildSearchTab()
                          else if (_tabController.index == FoodTab.barcode)
                            _buildBarcodeTab(),
                          Expanded(child: _buildMealTiles()),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Whether the current tab has active input taking up space
  bool _hasActiveInput() {
    final tab = _tabController.index;
    if (tab == FoodTab.search) return foodList.isNotEmpty;
    if (tab == FoodTab.barcode) {
      return scannerActive ||
          barcodeLoading ||
          barcodeResult != null ||
          barcodeError != null;
    }
    if (tab == FoodTab.manual) {
      return false; // manual tab doesn't have dynamic input that changes the layout, so we consider it to never have "active input" for layout purposes
    }
    return false;
  }
}
