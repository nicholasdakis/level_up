import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../globals.dart';
import '../utility/responsive.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../user/user_data_manager.dart';
import '../utility/recent_foods_service.dart';

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

  // Hold selected food for updating the UI in real time
  Map<String, dynamic>? selectedFood;
  String? mealType;
  DateTime currentDate = DateTime.now();
  bool userCanType = true;
  bool mealChosen = false;
  bool snackbarActive = false;
  bool isLogging = false;
  String latestQuery = "";
  Timer? checkTimer;
  DateTime? lastInput;
  List<dynamic> foodList = [];
  Map<String, Map<String, List<Map<String, dynamic>>>> foodDataByDate = {};
  late Future<void> _loadUserDataFuture;

  // Tab
  late TabController _tabController;
  int _previousTabIndex = 0;

  // Barcode
  bool barcodeLoading = false;
  Map<String, dynamic>? barcodeResult;
  String? barcodeError;
  bool scannerActive = false;

  // Serving size
  String selectedUnit = 'g';
  double baseAmount = 1.0;
  Map<String, double> baseMacros = {};
  String displayDescription = '';

  // Meal lists
  List<Map<String, dynamic>> breakfastFoods = [];
  List<Map<String, dynamic>> lunchFoods = [];
  List<Map<String, dynamic>> dinnerFoods = [];
  List<Map<String, dynamic>> snacksFoods = [];

  static const List<String> allowedUnits = [
    'g',
    'oz',
    'cup',
    'tbsp',
    'ml',
    'serving',
  ];

  final TextEditingController searchController = TextEditingController();
  final TextEditingController servingAmountController = TextEditingController();
  final TextEditingController _customUnitController = TextEditingController();
  final TextEditingController manualNameController = TextEditingController();
  final TextEditingController manualCaloriesController =
      TextEditingController();
  final TextEditingController manualFatController = TextEditingController();
  final TextEditingController manualCarbsController = TextEditingController();
  final TextEditingController manualProteinController = TextEditingController();
  final TextEditingController manualServingAmountController =
      TextEditingController();
  String manualSelectedUnit = 'serving';

  // Recent foods
  final RecentFoodsService _recentFoodsService = RecentFoodsService();
  List<Map<String, dynamic>> _recentFoods = [];
  bool _recentFoodsExpanded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
    ); // vsync: this gives the TickerProvider
    _loadUserDataFuture = _loadUserDataAndInit();
    _loadRecentFoods();
  }

  // Dispose to prevent memory leaks
  @override
  void dispose() {
    checkTimer?.cancel(); // clear the debouncer timer
    searchController.dispose();
    servingAmountController.dispose();
    _customUnitController.dispose();
    manualNameController.dispose();
    manualCaloriesController.dispose();
    manualFatController.dispose();
    manualCarbsController.dispose();
    manualProteinController.dispose();
    manualServingAmountController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // Formats decimals with an optional limit of decimal points (2 if decimalPlaces isn't provided)
  static TextInputFormatter _decimalFormatter({int decimalPlaces = 2}) {
    return TextInputFormatter.withFunction((oldValue, newValue) {
      if (newValue.text.isEmpty) return newValue;
      return RegExp(
            '^\\d{0,5}(\\.\\d{0,$decimalPlaces})?\$',
          ).hasMatch(newValue.text)
          ? newValue
          : oldValue;
    });
  }

  // Reusable Snackbar maker
  void _showSnackbar(
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    if (snackbarActive) return;
    snackbarActive = true;
    ScaffoldMessenger.of(context)
        .showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.info, color: Colors.white),
                SizedBox(width: Responsive.width(context, 10)),
                Text(message),
              ],
            ),
            duration: duration,
          ),
        )
        .closed
        .then((_) => snackbarActive = false);
  }

  Future<void> _loadUserDataAndInit() async {
    // Skip reloading all user data if already loaded for this user to avoid unnecessary Firestore reads on every tab switch
    if (currentUserData != null &&
        currentUserData!.uid == FirebaseAuth.instance.currentUser?.uid) {
      // Always refresh food data in case it was updated on another device
      await userManager.loadFoodData(currentUserData!.uid);
      _syncFoodData();
      return;
    }
    // First time loading for this user
    await userManager.loadUserData();
    _syncFoodData();
  }

  // Method to populate foodDataByDate with the stored values of it in currentUserData
  void _syncFoodData() {
    foodDataByDate = currentUserData?.foodDataByDate != null
        ? Map<String, Map<String, List<Map<String, dynamic>>>>.from(
            currentUserData!.foodDataByDate,
          )
        : {}; // fallback
    loadFoodForDate(currentDate);
  }

  Future<void> _loadRecentFoods() async {
    final recents = await _recentFoodsService.getRecentFoods();
    if (mounted) setState(() => _recentFoods = recents);
  }

  Future<void> _saveToRecentFoods(Map<String, dynamic> food) async {
    await _recentFoodsService.addRecentFood(food);
    await _loadRecentFoods();
  }

  // Method that puts DateTime objects in the form that foodDataByDate expects
  String formatDateKey(DateTime date) {
    return "${date.year.toString().padLeft(4, '0')}-"
        "${date.month.toString().padLeft(2, '0')}-"
        "${date.day.toString().padLeft(2, '0')}";
  }

  void loadFoodForDate(DateTime date) {
    final dayData = foodDataByDate[formatDateKey(date)];
    setState(() {
      breakfastFoods = _castFoodList(dayData?['Breakfast']);
      lunchFoods = _castFoodList(dayData?['Lunch']);
      dinnerFoods = _castFoodList(dayData?['Dinner']);
      snacksFoods = _castFoodList(dayData?['Snacks']);
    });
  }

  // Make sure the food list is always a list of maps even when data is null
  List<Map<String, dynamic>> _castFoodList(dynamic raw) =>
      (raw as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

  void changeDate(int days) {
    setState(() => currentDate = currentDate.add(Duration(days: days)));
    loadFoodForDate(currentDate);
  }

  // Calendar pop-up for changing dates
  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2026),
      lastDate: DateTime(2100),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked != null) {
      setState(() => currentDate = picked);
      loadFoodForDate(currentDate);
    }
  }

  int getTotalCaloriesForDay() {
    int total = 0;

    // Go through each meal list and add calories
    for (var food in breakfastFoods) {
      total += int.tryParse(food['calories'].toString()) ?? 0;
    }

    for (var food in lunchFoods) {
      total += int.tryParse(food['calories'].toString()) ?? 0;
    }

    for (var food in dinnerFoods) {
      total += int.tryParse(food['calories'].toString()) ?? 0;
    }

    for (var food in snacksFoods) {
      total += int.tryParse(food['calories'].toString()) ?? 0;
    }

    return total;
  }

  int extractCalories(String description) {
    final match = RegExp(
      r'Calories:\s*(\d+)kcal',
      caseSensitive: false,
    ).firstMatch(description);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }

  // Takes the "Per ..." from food_description and parses it into {amount, unit}
  Map<String, dynamic> parseServing(String description) {
    // Regular expression to find the amount and units
    final perMatch = RegExp(
      r'Per\s+(.+?)\s*-',
    ).firstMatch(description); // food_description parses as "Per xxx -"
    if (perMatch == null) {
      return {'amount': 1.0, 'unit': 'serving'}; // fallback if none was found
    }

    // token is the "xxx" part of "Per xxx"
    final token = perMatch.group(1)!.trim();
    // Regular expression to separate the amount and units in the serving size
    final numUnitMatch = RegExp(
      r'^(\d+(?:/\d+)?(?:\.\d+)?)\s*(.+)$',
    ).firstMatch(token);
    if (numUnitMatch != null) {
      return {
        'amount': _parseFraction(numUnitMatch.group(1)!),
        'unit': numUnitMatch.group(2)!.trim(),
      };
    }
    return {'amount': 1.0, 'unit': token}; // fallback
  }

  // Method that converts fractional serving sizes into a decimal
  double _parseFraction(String value) {
    if (value.contains('/')) {
      final parts = value.split('/');
      final denominator = double.tryParse(parts[1]) ?? 1;
      if (denominator == 0) return 0;
      return double.parse(
        ((double.tryParse(parts[0]) ?? 0) / denominator).toStringAsFixed(2),
      );
    }
    return double.tryParse(value) ?? 1.0; // fallback
  }

  Map<String, double> extractMacros(String description) {
    double extract(String label) {
      final match = RegExp(
        '$label:\\s*([\\d.]+)',
        caseSensitive: false,
      ).firstMatch(description);
      return double.tryParse(match?.group(1) ?? '') ?? 0;
    }

    return {
      'calories': extract('Calories'),
      'fat': extract('Fat'),
      'carbs': extract('Carbs'),
      'protein': extract('Protein'),
    };
  }

  // Method that automatically scales the nutritional information of food with serving size changes
  Map<String, double> scaleFood(
    Map<String, double> base,
    double baseAmt,
    double newAmt,
  ) {
    if (baseAmt == 0) return base;
    final ratio = newAmt / baseAmt;
    // in (k, v) k is the nutritional field (calories, protein...) and v is its value
    return base.map(
      (k, v) => MapEntry(k, double.parse((v * ratio).toStringAsFixed(2))),
    );
  }

  void _initServing(String description) {
    final parsed = parseServing(description);
    baseAmount = parsed['amount'] as double;
    selectedUnit = parsed['unit'] as String;
    servingAmountController.text = baseAmount % 1 == 0
        ? baseAmount.toInt().toString()
        : baseAmount.toString();
    baseMacros = extractMacros(description);
    displayDescription = _buildDescription(
      baseMacros,
      baseAmount,
      selectedUnit,
    );
  }

  // Method to update the UI and values when the user edits the serving size
  void _onServingChanged() {
    final newAmount =
        double.tryParse(servingAmountController.text) ?? baseAmount;
    final scaled = scaleFood(baseMacros, baseAmount, newAmount);
    setState(
      () => displayDescription = _buildDescription(
        scaled,
        newAmount,
        selectedUnit,
      ),
    );
  }

  // Method so food info is all formatted like fatSecret's (originally that was the only tab in Food Logging so it was built with that in mind)
  String _buildDescription(
    Map<String, double> macros,
    double amount,
    String unit,
  ) {
    final amountStr = amount % 1 == 0
        ? amount.toInt().toString()
        : amount.toString();
    return 'Per $amountStr$unit - Calories: ${macros['calories']!.round()}kcal'
        ' | Fat: ${macros['fat']!.toStringAsFixed(2)}g'
        ' | Carbs: ${macros['carbs']!.toStringAsFixed(2)}g'
        ' | Protein: ${macros['protein']!.toStringAsFixed(2)}g';
  }

  // Build a macro summary text from a food's food_description
  Widget _buildMacroText(
    Map<String, dynamic> food, {
    double fontSize = 12,
    Color color = Colors.white60,
    bool includeServing = true,
    bool compact = false,
  }) {
    final macros = extractMacros(food['food_description'] as String? ?? '');
    final parts = <String>[];
    if (includeServing) {
      final serving = parseServing(food['food_description'] as String? ?? '');
      final servingAmt = serving['amount'] as double;
      final servingUnit = ' ${serving['unit'] as String}';
      final servingStr =
          servingAmt % 1 ==
              0 // Check if servingStr is a whole number or not
          ? servingAmt.toInt().toString()
          : servingAmt.toString();
      final cal = num.tryParse(food['calories'].toString()) ?? 0;
      parts.add('$servingStr$servingUnit · $cal kcal');
    }
    if (macros['protein']! >= 0) {
      parts.add(
        compact
            ? 'P: ${macros['protein']!.toStringAsFixed(1)}g'
            : 'Protein: ${macros['protein']!.toStringAsFixed(1)}g',
      );
    }
    if (macros['carbs']! >= 0) {
      parts.add(
        compact
            ? 'C: ${macros['carbs']!.toStringAsFixed(1)}g'
            : 'Carbs: ${macros['carbs']!.toStringAsFixed(1)}g',
      );
    }
    if (macros['fat']! >= 0) {
      parts.add(
        compact
            ? 'F: ${macros['fat']!.toStringAsFixed(1)}g'
            : 'Fat: ${macros['fat']!.toStringAsFixed(1)}g',
      );
    }
    if (parts.isEmpty) return SizedBox.shrink();
    return Text(
      parts.join(' - '),
      style: GoogleFonts.manrope(
        fontSize: Responsive.font(context, fontSize),
        color: color,
      ),
    );
  }

  // Method to format the time displayed to the user when the fatSecret API calls have been maxed out
  String formatDuration(String rawTime) {
    final parts = rawTime.split('.')[0].split(':');
    final hours = int.parse(parts[0]);
    final minutes = int.parse(parts[1]);
    final seconds = int.parse(parts[2]);

    if (hours == 0 && minutes == 0 && seconds == 0) return "0 seconds";

    String plural(int n, String unit) => "$n $unit${n == 1 ? '' : 's'}";
    final segments = <String>[
      if (hours > 0) plural(hours, 'hour'),
      if (minutes > 0) plural(minutes, 'minute'),
      if (seconds > 0) plural(seconds, 'second'),
    ];
    if (segments.length == 1) return segments.first;
    return '${segments.take(segments.length - 1).join(', ')}, and ${segments.last}';
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

    try {
      final response = await UserDataManager.searchFood(query);

      if (response.statusCode == 200) {
        if (latestQuery != query) return;
        final foods = jsonDecode(response.body)['foods'];
        setState(() {
          foodList = foods?['food'] != null
              ? List<dynamic>.from(foods['food'])
              : [];
        });
      } else if (response.statusCode == 429) {
        // retrieve time left from the json file
        final errorData = jsonDecode(response.body);
        if (errorData['error'] == "Token limit exceeded") {
          _showSnackbar(
            "Daily search limit reached. The limit resets in ${formatDuration(errorData['time_left'])}.",
            duration: Duration(seconds: 5),
          );
        }
        setState(() => foodList = []);
      } else {
        setState(() => foodList = []);
      }
    } catch (error) {
      debugPrint("API call error: $error");
      setState(() => foodList = []);
      if (!isConnected) {
        _showSnackbar(
          "Error searching for foods. Check your connection and try again.",
        );
      }
    }
  }

  Future<void> lookupBarcode(String barcode) async {
    setState(() {
      barcodeLoading = true;
      barcodeResult = null;
      barcodeError = null;
    });

    try {
      final response = await http.get(
        Uri.parse(
          'https://world.openfoodfacts.org/api/v2/product/$barcode.json',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 1) {
          final nutriments = data['product']['nutriments'] ?? {};
          final description =
              'Per 100g - Calories: ${(nutriments['energy-kcal_100g'] ?? 0).round()}kcal'
              ' | Fat: ${nutriments['fat_100g'] ?? 0}g'
              ' | Carbs: ${nutriments['carbohydrates_100g'] ?? 0}g'
              ' | Protein: ${nutriments['proteins_100g'] ?? 0}g';
          _initServing(description);
          setState(() {
            barcodeResult = {
              'food_name': data['product']['product_name'] ?? 'Unknown Product',
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

  Future<void> logFood(Map<String, dynamic> foodObject) async {
    if (isLogging) {
      _showSnackbar("Please wait before logging again.");
      return;
    }
    if (mealType == null) {
      _showSnackbar("Please select a meal type.");
      return;
    }

    // For search/barcode: rebuild description with scaled serving values
    if (!foodObject.containsKey('calories') && baseMacros.isNotEmpty) {
      final newAmount =
          double.tryParse(servingAmountController.text) ?? baseAmount;
      final scaled = scaleFood(baseMacros, baseAmount, newAmount);
      foodObject['food_description'] = _buildDescription(
        scaled,
        newAmount,
        selectedUnit,
      );
      foodObject['calories'] = scaled['calories']!.round();
    } else if (!foodObject.containsKey('calories')) {
      foodObject['calories'] = extractCalories(
        foodObject['food_description'] ?? '',
      );
    }

    setState(() => isLogging = true);

    _saveToRecentFoods(foodObject);

    // Ensure this day's data exists and fallback to empty lists if not
    final dateKey = formatDateKey(currentDate);
    foodDataByDate.putIfAbsent(
      dateKey,
      () => {"Breakfast": [], "Lunch": [], "Dinner": [], "Snacks": []},
    );
    foodDataByDate[dateKey]![mealType!]!.add(foodObject);
    await saveFoodData("add");

    setState(() {
      loadFoodForDate(currentDate);
      // Reset search state
      userCanType = true;
      mealChosen = false;
      selectedFood = null;
      searchController.clear();
      foodList = [];
      // Reset barcode state
      barcodeResult = null;
      barcodeError = null;
      scannerActive = false;
      // Reset serving state
      servingAmountController.clear();
      selectedUnit = 'g';
      baseAmount = 1.0;
      baseMacros = {};
      displayDescription = '';
      // Reset manual entry state
      for (final c in [
        manualNameController,
        manualCaloriesController,
        manualFatController,
        manualCarbsController,
        manualProteinController,
        manualServingAmountController,
      ]) {
        c.clear();
      }
      manualSelectedUnit = allowedUnits.first;
    });

    // Timer that prevents Log Food from being used too frequently
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => isLogging = false);
    });
  }

  Future<void> saveFoodData(String? addOrDelete) async {
    if (currentUserData == null) return;
    currentUserData!.foodDataByDate = foodDataByDate;
    await userManager.updateFoodDataByDate(
      foodDataByDate,
      context: context,
      isBeingDeleted: addOrDelete == "delete",
    );
  }

  Future<void> _deleteFood(
    String mealKey,
    int idx,
    List<Map<String, dynamic>> foods,
  ) async {
    setState(() {
      foods.removeAt(idx);
      final dateKey = formatDateKey(currentDate);
      foodDataByDate[dateKey]![mealKey] = foods;
    });
    await saveFoodData("delete");
  }

  Future<void> handleManualEntry() async {
    final name = manualNameController.text.trim();
    if (name.isEmpty ||
        manualCaloriesController.text.trim().isEmpty ||
        manualServingAmountController.text.trim().isEmpty ||
        manualSelectedUnit.isEmpty) {
      _showSnackbar("Food name, calories, and serving size are required.");
      return;
    }

    final calories = int.tryParse(manualCaloriesController.text.trim()) ?? 0;
    final fat = manualFatController.text.trim();
    final carbs = manualCarbsController.text.trim();
    final protein = manualProteinController.text.trim();

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
    final servingAmt = manualServingAmountController.text.trim();
    final servingLabel = servingAmt.isNotEmpty
        ? '$servingAmt$manualSelectedUnit'
        : manualSelectedUnit;

    final parts = <String>['Calories: ${calories}kcal'];
    if (fat.isNotEmpty) parts.add('Fat: ${fat}g');
    if (carbs.isNotEmpty) parts.add('Carbs: ${carbs}g');
    if (protein.isNotEmpty) parts.add('Protein: ${protein}g');

    // Format manual entry like the other tabs
    await logFood({
      'food_name': name,
      'food_description': 'Per $servingLabel - ${parts.join(' | ')}',
      'calories': calories,
    });
  }

  Widget buildAttribution(String url, String text, Color color) {
    return Container(
      alignment: Alignment.center,
      child: InkWell(
        onTap: () async {
          final uri = Uri.parse(url);
          if (!await launchUrl(uri)) throw "Error: Could not open website.";
        },
        child: textWithFont(
          text,
          context,
          Responsive.font(context, 16),
          color: color,
        ),
      ),
    );
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
        // Debouncer timer to prevent unwanted API calls
        onChanged: (value) {
          lastInput = DateTime.now();
          checkTimer?.cancel();
          checkTimer = Timer(
            Duration(milliseconds: 750),
            () => handleApiCall(lastInput, value),
          );
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
            _showSnackbar("All fields must be filled.");
            return;
          }
          if (selectedFood != null) {
            await logFood(Map<String, dynamic>.from(selectedFood!));
          }
        } else if (tab == FoodTab.barcode) {
          if (barcodeResult == null) {
            _showSnackbar("Scan a barcode first.");
            return;
          }
          await logFood(Map<String, dynamic>.from(barcodeResult!));
        } else if (tab == FoodTab.manual) {
          await handleManualEntry();
        }
      },
    );
  }

  // Serving size row for search and barcode tabs
  Widget _buildServingRow() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.width(context, 20),
        vertical: Responsive.height(context, 8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            "Serving: ",
            style: GoogleFonts.manrope(
              color: Colors.white70,
              fontSize: Responsive.font(context, 14),
            ),
          ),
          SizedBox(
            width: Responsive.width(context, 60),
            child: TextField(
              controller: servingAmountController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [_decimalFormatter()],
              style: GoogleFonts.manrope(
                color: Colors.white,
                fontSize: Responsive.font(context, 14),
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: Responsive.width(context, 6),
                  vertical: Responsive.height(context, 8),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: lightenColor(appColorNotifier.value, 0.15),
                  ),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: lightenColor(appColorNotifier.value, 0.25),
                  ),
                ),
              ),
              onChanged: (_) => _onServingChanged(),
            ),
          ),
          SizedBox(width: Responsive.width(context, 8)),
          Text(
            selectedUnit,
            style: GoogleFonts.manrope(
              color: Colors.white70,
              fontSize: Responsive.font(context, 14),
            ),
          ),
        ],
      ),
    );
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
          textSelectionTheme: TextSelectionThemeData(cursorColor: Colors.white),
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

  // TAB CONTENT

  Widget _buildSearchTab() {
    return Column(
      children: [
        buildAttribution(
          "https://www.fatsecret.com",
          "Powered by fatsecret",
          Colors.blue,
        ),
        SizedBox(height: Responsive.height(context, 10)),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.width(context, 20),
          ),
          child: SizedBox(width: double.infinity, child: buildLogFoodButton()),
        ),
        if (selectedFood != null && foodList.isEmpty) ...[
          // Spread operator to put the widgets in the list into the parent widget’s children list
          _buildServingRow(),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.width(context, 20),
            ),
            child: Text(
              displayDescription,
              style: TextStyle(
                color: lightenColor(appColorNotifier.value, 0.2),
                fontSize: Responsive.font(context, 13),
              ),
            ),
          ),
        ],
        SizedBox(height: Responsive.height(context, 10)),
        if (foodList.isNotEmpty)
          Expanded(
            child: ListView.builder(
              itemCount: foodList.length,
              itemBuilder: (context, index) {
                final food = foodList[index];
                return InkWell(
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    _initServing(food['food_description'] ?? '');
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

  Widget _buildBarcodeTab() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        buildAttribution(
          "https://openfoodfacts.org",
          "Powered by Open Food Facts",
          Colors.green,
        ),
        SizedBox(height: Responsive.height(context, 10)),

        // Scan button shown only when the scanner isn't active and there's no result or error yet
        if (!scannerActive && barcodeResult == null && barcodeError == null)
          GestureDetector(
            onTap: () => setState(() => scannerActive = true),
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

        if (scannerActive)
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                Responsive.scale(context, 12),
              ),
              child: MobileScanner(
                onDetect: (BarcodeCapture capture) {
                  final barcode = capture.barcodes.firstOrNull;
                  if (barcode?.rawValue != null) {
                    setState(() => scannerActive = false);
                    lookupBarcode(barcode!.rawValue!);
                  }
                },
              ),
            ),
          ),

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
                // Option to retry scanning if an error occurs
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
                    displayDescription,
                    style: TextStyle(
                      color: lightenColor(appColorNotifier.value, 0.2),
                      fontSize: Responsive.font(context, 14),
                    ),
                  ),
                ),
                _buildServingRow(),
                SizedBox(height: Responsive.height(context, 10)),
                frostedButton(
                  // Option to retry scanning on a successful scan
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
          ),
      ],
    );
  }

  // Build the Manual Entry tab content, all fields inside one frosted glass card
  Widget _buildManualEntryTab() {
    final macroFields = [
      (manualProteinController, "Protein (g)"),
      (manualCarbsController, "Carbs (g)"),
      (manualFatController, "Fat (g)"),
    ];

    return SingleChildScrollView(
      // Entire Manual tab is scrollable
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      flex: 2, // gets 2/3 of the row space
                      child: _buildManualField(
                        manualServingAmountController,
                        "Serving Amount:",
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [_decimalFormatter()],
                      ),
                    ),
                    SizedBox(width: Responsive.width(context, 12)),
                    Expanded(
                      flex: 1, // gets 1/3 of the row space
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom: Responsive.height(context, 4),
                        ),
                        child: DropdownButton<String>(
                          isDense: true,
                          focusColor: Colors.transparent,
                          value: allowedUnits.contains(manualSelectedUnit)
                              ? manualSelectedUnit
                              : '__custom_active__',
                          isExpanded: true,
                          dropdownColor: darkenColor(
                            appColorNotifier.value,
                            0.05,
                          ),
                          style: GoogleFonts.manrope(
                            color: Colors.white,
                            fontSize: Responsive.font(context, 14),
                          ),
                          underline: Container(
                            height: 1,
                            color: lightenColor(appColorNotifier.value, 0.15),
                          ),
                          items: [
                            if (!allowedUnits.contains(manualSelectedUnit))
                              DropdownMenuItem(
                                value: '__custom_active__',
                                child: Text(manualSelectedUnit),
                              ),
                            ...allowedUnits.map(
                              // Spread operator to loop over allowedUnits and create a DropdownMenuItem for each item
                              (u) => DropdownMenuItem(value: u, child: Text(u)),
                            ),
                            // Custom serving option for the Manual tab
                            DropdownMenuItem(
                              value: '__custom__',
                              child: Text(
                                "Custom...",
                                style: GoogleFonts.manrope(
                                  color: Colors.white54,
                                  fontSize: Responsive.font(context, 14),
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == '__custom__') {
                              _customUnitController.clear();
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: darkenColor(
                                    appColorNotifier.value,
                                    0.025,
                                  ).withAlpha(220),
                                  title: Text(
                                    "Custom Unit",
                                    style: GoogleFonts.manrope(
                                      color: Colors.white,
                                    ),
                                  ),
                                  content: TextField(
                                    controller: _customUnitController,
                                    style: GoogleFonts.manrope(
                                      color: Colors.white,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: "e.g. A slice, a can, a bag...",
                                      hintStyle: GoogleFonts.manrope(
                                        color: Colors.white38,
                                      ),
                                      enabledBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Colors.white38,
                                        ),
                                      ),
                                      focusedBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text(
                                        "Cancel",
                                        style: TextStyle(color: Colors.white54),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        final custom = _customUnitController
                                            .text
                                            .trim();
                                        if (custom.isNotEmpty) {
                                          setState(
                                            () => manualSelectedUnit = custom,
                                          );
                                        }
                                        Navigator.pop(context);
                                      },
                                      child: Text(
                                        "OK",
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            } else if (value != null &&
                                value != '__custom_active__') {
                              setState(() => manualSelectedUnit = value);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                _buildManualField(
                  manualCaloriesController,
                  "Calories (kcal)",
                  keyboardType: TextInputType.number,
                  inputFormatters: [_decimalFormatter(decimalPlaces: 3)],
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
                for (final (controller, hint) in macroFields)
                  _buildManualField(
                    controller,
                    hint,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [_decimalFormatter(decimalPlaces: 3)],
                  ),
              ],
            ),
          ),
          _buildAllMealSections(),
          SizedBox(height: Responsive.height(context, 20)),
        ],
      ),
    );
  }

  Widget _buildRecentFoodsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tappable header row to expand/collapse
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => setState(() {
              _recentFoodsExpanded = !_recentFoodsExpanded;
            }),
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: Responsive.height(context, 6),
                horizontal: Responsive.width(context, 4),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.history,
                    color: Colors.white54,
                    size: Responsive.scale(context, 18),
                  ),
                  SizedBox(width: Responsive.width(context, 8)),
                  Text(
                    "Recent Foods",
                    style: GoogleFonts.manrope(
                      fontSize: Responsive.font(context, 15),
                      color: Colors.white54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: Responsive.width(context, 6)),
                  Icon(
                    _recentFoodsExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: Colors.white54,
                    size: Responsive.scale(context, 20),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Expandable list of recent foods
        if (_recentFoodsExpanded)
          ...(_recentFoods.map((food) {
            // Spread operator so the UI adds every recent food as its own individual widget
            final name = food['food_name'] ?? '';
            return Padding(
              padding: EdgeInsets.only(bottom: Responsive.height(context, 6)),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  // Recent foods already have calories set, so logFood's
                  // calorie extraction is a no op here
                  onTap: () => logFood(Map<String, dynamic>.from(food)),
                  child: frostedGlassCard(
                    context,
                    baseRadius: 12,
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.width(context, 16),
                      vertical: Responsive.height(context, 10),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.width(context, 16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.add_circle_outline,
                            color: appColorNotifier.value,
                            size: Responsive.scale(context, 20),
                          ),
                          SizedBox(width: Responsive.width(context, 12)),
                          Expanded(
                            child: Text(
                              name,
                              style: GoogleFonts.manrope(
                                fontSize: Responsive.font(context, 14),
                                color: Colors.white,
                              ),
                              softWrap: true,
                            ),
                          ),
                          // Recent food card info
                          _buildMacroText(
                            food,
                            fontSize: 11,
                            color: Colors.white54,
                            compact: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          })),
        if (_recentFoodsExpanded)
          SizedBox(height: Responsive.height(context, 6)),
      ],
    );
  }

  Widget _buildAllMealSections() {
    return Column(
      children: [
        _buildMealSection("Breakfast", breakfastFoods),
        _buildMealSection("Lunch", lunchFoods),
        _buildMealSection("Dinner", dinnerFoods),
        _buildMealSection("Snacks", snacksFoods),
      ],
    );
  }

  Widget _buildMealTiles() {
    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      child: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.width(context, 16),
        ),
        children: [
          _buildAllMealSections(),
          SizedBox(height: Responsive.height(context, 20)),
        ],
      ),
    );
  }

  Widget _buildMealSection(String title, List<Map<String, dynamic>> foods) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              letterSpacing: Responsive.font(context, 1),
            ),
          ),
        ),
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
            final food = entry.value;
            return Dismissible(
              // Dismissible widget so the food can be swiped to delete
              key: ValueKey("${title.toLowerCase()}_$idx${food['food_name']}"),
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
              onDismissed: (_) => _deleteFood(title, idx, foods),
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
                            _buildMacroText(food),
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
                        onPressed: () => _deleteFood(title, idx, foods),
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
      future:
          _loadUserDataFuture, // same future instance across rebuilds, so the load only runs once
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
            appBar: AppBar(
              scrolledUnderElevation: 0,
              backgroundColor: darkenColor(appColorNotifier.value, 0.025),
              centerTitle: true,
              toolbarHeight: Responsive.buttonHeight(context, 120),
              title: createTitle("Food Logging", context),
            ),
            body: Padding(
              padding: EdgeInsets.all(Responsive.width(context, 16)),
              child: Column(
                children: [
                  // Date navigation
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

                  // Total calories for the day text
                  Text(
                    "Total Calories: ${getTotalCaloriesForDay()}",
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontSize: Responsive.font(context, 20),
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: Responsive.height(context, 8)),

                  // Tab bar
                  TabBar(
                    controller: _tabController,
                    // Only reset state when actually switching to a different tab,
                    // so a selected food survives navigating away and back
                    onTap: (index) {
                      if (index != _previousTabIndex) {
                        setState(() {
                          _previousTabIndex = index;
                          foodList = [];
                          servingAmountController.clear();
                          selectedUnit = 'g';
                          baseAmount = 1.0;
                          baseMacros = {};
                          displayDescription = '';
                          selectedFood = null;
                          userCanType = true;
                          mealChosen = false;
                          searchController.clear();
                          barcodeResult = null;
                          barcodeError = null;
                          scannerActive = false;
                        });
                      }
                    },
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

                  // Meal type dropdown and search field / log button
                  SizedBox(
                    height: Responsive.height(context, 58),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Meal Type chooser
                        DropdownButton2<String>(
                          isDense: true,
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
                          // Convert the strings to DropdownMenuItems
                          items: ["Breakfast", "Lunch", "Dinner", "Snacks"]
                              .map(
                                (t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(
                                    t,
                                    style: GoogleFonts.manrope(
                                      fontSize: Responsive.font(context, 20),
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => mealType = value),
                        ),
                        SizedBox(width: Responsive.width(context, 25)),
                        // Search field on the search tab, log button everywhere else
                        _tabController.index == FoodTab.search
                            ? buildSearchButton()
                            : Expanded(child: buildLogFoodButton()),
                      ],
                    ),
                  ),

                  SizedBox(height: Responsive.height(context, 10)),

                  // Recent foods collapsible section
                  if (_recentFoods.isNotEmpty) _buildRecentFoodsSection(),

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

  // Whether the current tab has active input that should take up the full content area (manual tab never does)
  bool _hasActiveInput() {
    if (_tabController.index == FoodTab.search) return foodList.isNotEmpty;
    if (_tabController.index == FoodTab.barcode) {
      return scannerActive ||
          barcodeLoading ||
          barcodeResult != null ||
          barcodeError != null;
    }
    return false;
  }
}
