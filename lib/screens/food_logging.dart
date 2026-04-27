import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../globals.dart';
import '../utility/responsive.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_data_manager.dart';
import '../services/recent_foods_service.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../services/voice_search_service.dart';
import '../utility/food_logging_helper.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart' hide ShimmerEffect;

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
    with TickerProviderStateMixin {
  // 2 tickers: one for TabController and one for AnimatedSize

  String? _inlineError;

  // Hold selected food for updating the UI in real time
  Map<String, dynamic>? selectedFood;
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

  // Voice search
  final VoiceSearchService _voiceSearch = VoiceSearchService();

  // Recent foods
  final RecentFoodsService _recentFoodsService = RecentFoodsService();
  List<Map<String, dynamic>> _recentFoods = [];
  bool _recentFoodsExpanded = false;
  // Controls the expand/collapse animation for the recent foods section
  late AnimationController _recentFoodsAnim;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
    ); // vsync: this gives the TickerProvider
    // vsync: this gives AnimationController a ticker from TickerProviderStateMixin
    _recentFoodsAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadUserDataFuture = _loadUserDataAndInit();
    _loadRecentFoods();
    _voiceSearch.init(() {
      if (mounted) setState(() {});
    });
  }

  // Helper method with the 750ms debouncer before calling the API
  void _scheduleSearch(String value) {
    lastInput = DateTime.now();
    checkTimer?.cancel();
    checkTimer = Timer(
      Duration(milliseconds: 750),
      () => handleApiCall(lastInput, value),
    );
  }

  // Method that enables the microphone for listening to the user's input when the
  // microphone is pressed
  Future<void> _toggleListening() async {
    if (!_voiceSearch.isAvailable) {
      _showSnackbar("Voice search isn't available on this device.");
      return;
    }
    await _voiceSearch.toggle((text) {
      searchController.text = text;
      searchController.selection = TextSelection.fromPosition(
        TextPosition(offset: searchController.text.length),
      );
      // Only calls the API when the user has finished talking
      _scheduleSearch(text);
    });
  }

  // Dispose to prevent memory leaks
  @override
  void dispose() {
    checkTimer?.cancel(); // clear the debouncer timer
    // stop speech engine first so its final-timeout can't write to disposed controllers
    _voiceSearch.cancel();
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
    _recentFoodsAnim.dispose();
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
    Duration duration = const Duration(milliseconds: 500),
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
    // Skip reloading all user data if already loaded for this user to avoid unnecessary backend reads on every tab switch
    if (currentUserData != null &&
        currentUserData!.uid == FirebaseAuth.instance.currentUser?.uid) {
      // Always refresh food data in case it was updated on another device
      await userManager.refreshUserData();
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

  void loadFoodForDate(DateTime date) {
    final dayData = foodDataByDate[FoodLoggingHelper.formatDateKey(date)];
    setState(() {
      breakfastFoods = FoodLoggingHelper.castFoodList(dayData?['breakfast']);
      lunchFoods = FoodLoggingHelper.castFoodList(dayData?['lunch']);
      dinnerFoods = FoodLoggingHelper.castFoodList(dayData?['dinner']);
      snacksFoods = FoodLoggingHelper.castFoodList(dayData?['snacks']);
    });
  }

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

  // Method for granting the full course meal achievement
  void checkFullDayBadge() {
    final dateKey = FoodLoggingHelper.formatDateKey(currentDate);
    final dayData = foodDataByDate[dateKey];

    final breakfast = (dayData?['breakfast'] ?? []).isNotEmpty;
    final lunch = (dayData?['lunch'] ?? []).isNotEmpty;
    final dinner = (dayData?['dinner'] ?? []).isNotEmpty;
    final snacks = (dayData?['snacks'] ?? []).isNotEmpty;

    if (breakfast && lunch && dinner && snacks) {
      trackTrivialAchievement("food_full_day");
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

  void _initServing(String description) {
    final parsed = FoodLoggingHelper.parseServing(description);
    baseAmount = parsed['amount'] as double;
    selectedUnit = parsed['unit'] as String;
    servingAmountController.text = baseAmount % 1 == 0
        ? baseAmount.toInt().toString()
        : baseAmount.toString();
    baseMacros = FoodLoggingHelper.extractMacros(description);
    displayDescription = FoodLoggingHelper.buildDescription(
      baseMacros,
      baseAmount,
      selectedUnit,
    );
  }

  // Method to update the UI and values when the user edits the serving size
  void _onServingChanged() {
    final newAmount =
        double.tryParse(servingAmountController.text) ?? baseAmount;
    final scaled = FoodLoggingHelper.scaleFood(
      baseMacros,
      baseAmount,
      newAmount,
    );
    setState(
      () => displayDescription = FoodLoggingHelper.buildDescription(
        scaled,
        newAmount,
        selectedUnit,
      ),
    );
  }

  // Build a macro summary text from a food's food_description
  Widget _buildMacroText(
    Map<String, dynamic> food, {
    double fontSize = 12,
    Color color = Colors.white60,
    bool includeServing = true,
    bool compact = false,
  }) {
    final macros = FoodLoggingHelper.extractMacros(
      food['food_description'] as String? ?? '',
    );
    final parts = <String>[];
    if (includeServing) {
      final serving = FoodLoggingHelper.parseServing(
        food['food_description'] as String? ?? '',
      );
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

  // Function that calls the API to search the user's input after the timer has gone to 0 (to avoid making too many requests)
  void handleApiCall(DateTime? dateTime, String query) async {
    if (query.isEmpty) return;

    // Normalize the query to reduce API calls
    query = query
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim(); // remove extra spaces and lowercase the query

    // Race condition guard in case the user changes their query
    latestQuery = query;

    try {
      final response = await UserDataManager.searchFood(query);

      if (response.statusCode == 200) {
        if (latestQuery != query) return;
        final foods = jsonDecode(response.body)['foods'];

        // Dismiss the keyboard so results aren't hidden on mobile
        FocusScope.of(context).unfocus();

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
            "Daily search limit reached, try another tab. The limit resets in ${FoodLoggingHelper.formatDuration(errorData['time_left'])}.",
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
              'brand_name': data['product']['brands'],
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

  // Inline validation error shown above the Log Food button
  Widget _buildInlineError() {
    if (_inlineError == null) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: Responsive.height(context, 6)),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.redAccent,
            size: Responsive.font(context, 14),
          ),
          SizedBox(width: Responsive.width(context, 6)),
          Text(
            _inlineError!,
            style: GoogleFonts.manrope(
              fontSize: Responsive.font(context, 13),
              color: Colors.redAccent,
            ),
          ),
        ],
      ),
    );
  }

  // Single tappable meal tile that fills half the row width
  Widget _mealTile(BuildContext context, (String, String, Color) meal) {
    final (label, value, color) = meal;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.pop(context, value),
          borderRadius: BorderRadius.circular(Responsive.scale(context, 16)),
          splashColor: color.withAlpha(60),
          child: Container(
            height: Responsive.height(context, 64),
            decoration: BoxDecoration(
              color: color.withAlpha(60),
              borderRadius: BorderRadius.circular(
                Responsive.scale(context, 16),
              ),
              border: Border.all(color: color.withAlpha(120), width: 1),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 16),
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Lays two meal tiles side by side with a gap between them
  Widget _mealRow(
    BuildContext context,
    (String, String, Color) a,
    (String, String, Color) b,
  ) {
    return Row(
      children: [
        _mealTile(context, a),
        SizedBox(width: Responsive.scale(context, 10)),
        _mealTile(context, b),
      ],
    );
  }

  // Method that shows a centered meal picker dialog and logs the food once a meal is chosen
  Future<void> _showMealPicker(
    Map<String, dynamic> foodObject, {
    String? achievementId,
  }) async {
    if (isLogging) {
      _showSnackbar("Please wait before logging again.");
      return;
    }

    final base = appColorNotifier.value;
    final meals = [
      ("Breakfast", "breakfast", lightenColor(base, 0.30)),
      ("Lunch", "lunch", lightenColor(base, 0.30)),
      ("Dinner", "dinner", lightenColor(base, 0.30)),
      ("Snacks", "snacks", lightenColor(base, 0.30)),
    ];

    final chosen = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: darkenColor(appColorNotifier.value, 0.02).withAlpha(230),
            borderRadius: BorderRadius.circular(Responsive.scale(context, 24)),
            border: Border.all(color: Colors.white.withAlpha(20), width: 1),
          ),
          padding: EdgeInsets.all(Responsive.scale(context, 24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dialog title
              Text(
                "ADD TO MEAL",
                style: GoogleFonts.manrope(
                  fontSize: Responsive.font(context, 11),
                  color: Colors.white38,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
              SizedBox(height: Responsive.height(context, 20)),
              // Top row: Breakfast and Lunch
              _mealRow(context, meals[0], meals[1]),
              SizedBox(height: Responsive.scale(context, 10)),
              // Bottom row: Dinner and Snacks
              _mealRow(context, meals[2], meals[3]),
              SizedBox(height: Responsive.height(context, 4)),
              // Cancel button
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "Cancel",
                    style: GoogleFonts.manrope(
                      fontSize: Responsive.font(context, 13),
                      color: Colors.white30,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (chosen == null) return;
    if (achievementId != null) trackTrivialAchievement(achievementId);
    await logFood(foodObject, chosen);
  }

  Future<void> logFood(Map<String, dynamic> foodObject, String meal) async {
    // For search/barcode: rebuild description with scaled serving values
    if (!foodObject.containsKey('calories') && baseMacros.isNotEmpty) {
      final newAmount =
          double.tryParse(servingAmountController.text) ?? baseAmount;
      final scaled = FoodLoggingHelper.scaleFood(
        baseMacros,
        baseAmount,
        newAmount,
      );
      foodObject['food_description'] = FoodLoggingHelper.buildDescription(
        scaled,
        newAmount,
        selectedUnit,
      );
      foodObject['calories'] = scaled['calories']!.round();
    } else if (!foodObject.containsKey('calories')) {
      foodObject['calories'] = FoodLoggingHelper.extractCalories(
        foodObject['food_description'] ?? '',
      );
    }

    setState(() => isLogging = true);

    _saveToRecentFoods(foodObject);

    // Ensure this day's data exists and fallback to empty lists if not
    final dateKey = FoodLoggingHelper.formatDateKey(currentDate);
    foodDataByDate.putIfAbsent(
      dateKey,
      () => {"breakfast": [], "lunch": [], "dinner": [], "snacks": []},
    );
    foodDataByDate[dateKey]![meal]!.add(foodObject);

    checkFullDayBadge(); // gives the user the full course meal achievement if it can be earned

    try {
      await saveFoodData("add");
    } catch (e) {
      debugPrint("Error saving food data: $e");
    }

    setState(() {
      loadFoodForDate(currentDate);
      // Reset search state
      _inlineError = null;
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
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => isLogging = false);
    });
  }

  Future<void> saveFoodData(String? addOrDelete) async {
    if (currentUserData == null) return;
    currentUserData!.foodDataByDate = foodDataByDate;
    // Only sends the current date's data
    final dateKey = FoodLoggingHelper.formatDateKey(currentDate);
    final currentDateData = {dateKey: foodDataByDate[dateKey]!};
    await userManager.updateFoodDataByDate(
      currentDateData,
      context: context,
      isBeingDeleted: addOrDelete == "delete",
    );
  }

  Future<void> _deleteFood(
    String mealKey,
    int idx,
    List<Map<String, dynamic>> foods,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: darkenColor(
          appColorNotifier.value,
          0.025,
        ).withAlpha(100),
        title: Text(
          "Delete food?",
          style: GoogleFonts.manrope(color: Colors.white),
        ),
        content: Text(
          "Are you sure you want to remove ${foods[idx]['food_name'] ?? 'this food'}?",
          style: GoogleFonts.manrope(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text("Delete", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      foods.removeAt(idx);
      final dateKey = FoodLoggingHelper.formatDateKey(currentDate);
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
      setState(
        () => _inlineError =
            "Food name, calories, and serving size are required.",
      );
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
    await _showMealPicker({
      'food_name': name,
      'food_description': 'Per $servingLabel - ${parts.join(' | ')}',
      'calories': calories,
    }, achievementId: 'food_manual');
  }

  Widget buildAttribution(String url, String text, Color color) {
    return Container(
      alignment: Alignment.center,
      child: InkWell(
        splashColor: appColorNotifier.value.withAlpha(100),
        onTap: () async {
          final uri = Uri.parse(url);
          if (!await launchUrl(uri)) throw "Error: Could not open website.";
        },
        child: textWithFont(
          text,
          context,
          Responsive.font(context, 15),
          color: color,
        ),
      ),
    );
  }

  Widget buildSearchButton() {
    return TextField(
      controller: searchController,
      readOnly: !userCanType,
      keyboardType: TextInputType.text,
      style: GoogleFonts.manrope(
        fontSize: Responsive.font(context, 17),
        color: Colors.white,
      ),
      decoration: InputDecoration(
        border: InputBorder.none,
        hintText: "Search",
        // Clear food icon when a food is selected
        suffix: selectedFood != null
            ? GestureDetector(
                onTap: () {
                  setState(() {
                    selectedFood = null;
                    userCanType = true;
                    mealChosen = false;
                    searchController.clear();
                    foodList = [];
                    displayDescription = "";
                    baseMacros = {};
                  });
                },
                child: Padding(
                  padding: EdgeInsets.only(
                    right: Responsive.width(context, 12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.close,
                        color: Colors.white54,
                        size: Responsive.font(context, 14),
                      ),
                      SizedBox(width: Responsive.width(context, 4)),
                      Text(
                        "Clear",
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 13),
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
        // Microphone icon when a food is not selected
        suffixIcon: selectedFood == null
            ? Opacity(
                opacity: userCanType ? 1.0 : 0.3,
                child: IconButton(
                  icon: Icon(
                    // Red microphone icon when actively listening
                    _voiceSearch.isListening ? Icons.mic : Icons.mic_none,
                    color: _voiceSearch.isListening
                        ? Colors.redAccent
                        : Colors.white54,
                  ),
                  onPressed: userCanType ? _toggleListening : null,
                ),
              )
            : null,
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
      onChanged: _scheduleSearch,
    );
  }

  Widget buildLogFoodButton() {
    return IgnorePointer(
      // Prevents tapping while the cooldown bar is running
      ignoring: isLogging,
      child: Stack(
        children: [
          // The button itself, full width so the Stack has a defined size
          SizedBox(
            width: double.infinity,
            child: frostedButton(
              "Log Food",
              context,
              onPressed: () async {
                final tab = _tabController.index;
                if (tab == FoodTab.search) {
                  if (!mealChosen || selectedFood == null) {
                    setState(() => _inlineError = "Select a food first.");
                    return;
                  }
                  setState(() => _inlineError = null);
                  await _showMealPicker(
                    Map<String, dynamic>.from(selectedFood!),
                    achievementId: 'food_search',
                  );
                } else if (tab == FoodTab.barcode) {
                  if (barcodeResult == null) {
                    setState(() => _inlineError = "Scan a barcode first.");
                    return;
                  }
                  setState(() => _inlineError = null);
                  await _showMealPicker(
                    Map<String, dynamic>.from(barcodeResult!),
                    achievementId: 'food_barcode',
                  );
                } else if (tab == FoodTab.manual) {
                  setState(() => _inlineError = null);
                  await handleManualEntry();
                }
              },
            ),
          ),
          // Cooldown progress bar overlaid at the bottom of the button
          if (isLogging)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  Responsive.scale(context, 12),
                ),
                child: Container(color: appColorNotifier.value.withAlpha(80))
                    .animate()
                    .custom(
                      duration: const Duration(seconds: 3),
                      builder: (context, value, child) => FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: 1.0 - value, // drains from full to empty
                        child: child,
                      ),
                    ),
              ),
            ),
        ],
      ),
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
        if (selectedFood != null && foodList.isEmpty) ...[
          // Spread operator to put the widgets in the list into the parent widget’s children list
          _buildServingRow(),
          SizedBox(height: Responsive.height(context, 10)),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.width(context, 20),
            ),
            child: frostedGlassCard(
              context,
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.width(context, 16),
                vertical: Responsive.height(context, 12),
              ),
              child: Text(
                displayDescription,
                style: GoogleFonts.manrope(
                  color: Colors.white70,
                  fontSize: Responsive.font(context, 13),
                ),
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
                  splashColor: appColorNotifier.value.withAlpha(100),
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
                      food['brand_name'] != null
                          ? '${food['brand_name']} · ${food['food_name'] ?? ''}'
                          : (food['food_name'] ?? ''),
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
        // Scan button shown only when the scanner isn't active and there's no result or error yet
        if (!scannerActive && barcodeResult == null && barcodeError == null)
          GestureDetector(
            onTap: () => setState(() => scannerActive = true),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.width(context, 20),
                vertical: Responsive.height(context, 16),
              ),
              child: SizedBox(
                width: double.infinity,
                child: frostedGlassCard(
                  context,
                  baseRadius: 24,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(
                          top: Responsive.height(context, 8),
                        ),
                        child: Text(
                          "Scan Barcode",
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 24),
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
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
                    barcodeResult!['brand_name'] != null
                        ? '${barcodeResult!['brand_name']} · ${barcodeResult!['food_name'] ?? ''}'
                        : (barcodeResult!['food_name'] ?? ''),
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
      padding: EdgeInsets.symmetric(horizontal: Responsive.width(context, 20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionHeader(
            "ENTER FOOD INFORMATION",
            context,
            baseFontSize: 15,
            padding: EdgeInsets.only(
              top: Responsive.height(context, 16),
              bottom: Responsive.height(context, 12),
              left: Responsive.width(context, 4),
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
            onTap: () {
              setState(() => _recentFoodsExpanded = !_recentFoodsExpanded);
              // forward() plays 0->1 (expand), reverse() plays 1->0 (collapse)
              if (_recentFoodsExpanded) {
                _recentFoodsAnim.forward();
              } else {
                _recentFoodsAnim.reverse();
              }
            },
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: Responsive.height(context, 12),
                horizontal: Responsive.width(context, 4),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.history,
                    color: Colors.white54,
                    size: Responsive.scale(context, 22),
                  ),
                  SizedBox(width: Responsive.width(context, 8)),
                  Text(
                    "RECENT FOODS",
                    style: GoogleFonts.manrope(
                      fontSize: Responsive.font(context, 20),
                      color: Colors.white38,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: Responsive.width(context, 6)),
                  Icon(
                    _recentFoodsExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: Colors.white54,
                    size: Responsive.scale(context, 24),
                  ),
                ],
              ),
            ),
          ),
        ),
        // SizeTransition scales the visible portion of its child
        // based on _recentFoodsAnim (0.0 = fully collapsed, 1.0 = fully
        // expanded). The child is always built at full size, and
        // SizeTransition clips it so during collapse the cards slide
        // behind the header like a curtain instead of disappearing first
        SizeTransition(
          sizeFactor: CurvedAnimation(
            parent: _recentFoodsAnim,
            curve: Curves.easeInOut,
          ),
          // axisAlignment -1.0 means the content is pinned to the top,
          // so it reveals downward when expanding and hides upward
          // when collapsing
          axisAlignment: -1.0,
          child: ConstrainedBox(
            // Cap the max height so the list can't push tab content off screen
            constraints: BoxConstraints(
              maxHeight: Responsive.height(context, 200),
            ),
            // ShaderMask fades the bottom of the scroll area to transparent
            child: ShaderMask(
              shaderCallback: (bounds) =>
                  const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black,
                      Colors.black,
                      Colors.transparent,
                    ], // black just means visible, and fades out at the bottom
                    stops: [0.0, 0.85, 1.0],
                  ).createShader(
                    bounds,
                  ), // sizes the gradient to the widget (SingleChildScrollView)
              blendMode: BlendMode
                  .dstIn, // keeps SingleChildScrollView where shader is opaque, hides it where transparent
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final food in _recentFoods)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: Responsive.height(context, 6),
                        ),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => _showMealPicker(
                              Map<String, dynamic>.from(food),
                              achievementId: 'food_recent',
                            ),
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
                                    SizedBox(
                                      width: Responsive.width(context, 12),
                                    ),
                                    Flexible(
                                      flex: 1,
                                      fit: FlexFit.tight,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          food['brand_name'] != null
                                              ? '${food['brand_name']} · ${food['food_name'] ?? ''}'
                                              : (food['food_name'] ?? ''),
                                          style: GoogleFonts.manrope(
                                            fontSize: Responsive.font(
                                              context,
                                              14,
                                            ),
                                            color: Colors.white,
                                          ),
                                          softWrap: true,
                                        ),
                                      ),
                                    ),
                                    Flexible(
                                      flex: 2,
                                      fit: FlexFit.tight,
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: _buildMacroText(
                                          food,
                                          fontSize: 11,
                                          color: Colors.white54,
                                          compact: true,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    SizedBox(height: Responsive.height(context, 6)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAllMealSections() {
    return Column(
      children: [
        _buildMealSection("breakfast", breakfastFoods),
        _buildMealSection("lunch", lunchFoods),
        _buildMealSection("dinner", dinnerFoods),
        _buildMealSection("snacks", snacksFoods),
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
              confirmDismiss: (_) async {
                await _deleteFood(title, idx, foods);
                // Always return false since _deleteFood handles removal via setState
                return false;
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
                              food['brand_name'] != null
                                  ? '${food['brand_name']} · ${food['food_name'] ?? ''}'
                                  : (food['food_name'] ?? ''),
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
        final isLoading = snapshot.connectionState != ConnectionState.done;

        return Container(
          decoration: BoxDecoration(gradient: buildThemeGradient()),
          child: Scaffold(
            backgroundColor: Colors.transparent, // Body color
            appBar: AppBar(
              scrolledUnderElevation: 0,
              backgroundColor: darkenColor(appColorNotifier.value, 0.025),
              centerTitle: true,
              toolbarHeight: Responsive.buttonHeight(context, 120),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => context.pop(),
              ),
              title: createTitle("Food Logging", context),
              bottom: PreferredSize(
                preferredSize: Size.fromHeight(Responsive.height(context, 1)),
                child: Container(
                  height: Responsive.height(context, 1),
                  color: Colors.white.withAlpha(25),
                ),
              ),
            ),
            body: Padding(
              padding: EdgeInsets.all(Responsive.width(context, 16)),
              child: Skeletonizer(
                enabled:
                    isLoading, // shows bone placeholders while loading, passes through normally when done
                effect: ShimmerEffect(
                  baseColor: lightenColor(appColorNotifier.value, 0.3),
                  highlightColor: lightenColor(appColorNotifier.value, 0.1),
                  duration: const Duration(milliseconds: 1200),
                ),
                child: Column(
                  children: [
                    // Date navigation
                    DateNavigationRow(
                      currentDate: currentDate,
                      onDateChanged: (date) {
                        setState(() => currentDate = date);
                        loadFoodForDate(date);
                      },
                    ),

                    // Total calories for the day text
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          // leads to the food logging charts screen when clicked
                          context.push(
                            '/food-logging/analytics',
                            extra: {
                              'initialDate': currentDate,
                              'onDateChanged': (DateTime date) {
                                setState(() => currentDate = date);
                                loadFoodForDate(date);
                              },
                            },
                          );
                        },
                        borderRadius: BorderRadius.circular(
                          Responsive.scale(context, 12),
                        ),
                        splashColor: appColorNotifier.value.withAlpha(80),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: Responsive.width(context, 16),
                            vertical: Responsive.height(context, 10),
                          ),
                          decoration: BoxDecoration(
                            color: appColorNotifier.value.withAlpha(35),
                            borderRadius: BorderRadius.circular(
                              Responsive.scale(context, 12),
                            ),
                            border: Border.all(
                              color: appColorNotifier.value.withAlpha(140),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.bar_chart_rounded,
                                color: appColorNotifier.value,
                                size: Responsive.font(context, 18),
                              ),
                              SizedBox(width: Responsive.width(context, 8)),
                              Text(
                                "Total Calories: ${getTotalCaloriesForDay()}",
                                style: GoogleFonts.manrope(
                                  color: Colors.white,
                                  fontSize: Responsive.font(context, 18),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: Responsive.width(context, 8)),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.white54,
                                size: Responsive.font(context, 18),
                              ),
                            ],
                          ),
                        ),
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
                            _inlineError = null;
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

                    // Attribution text above the meal type row
                    if (_tabController.index ==
                        FoodTab.search) // Search tab attribution
                      Padding(
                        padding: EdgeInsets.only(
                          left: Responsive.width(context, 20),
                          right: Responsive.width(context, 20),
                          bottom: Responsive.height(context, 6),
                        ),
                        child: buildAttribution(
                          "https://www.fatsecret.com",
                          "Powered by fatsecret",
                          Colors.blue,
                        ),
                      ),
                    if (_tabController.index ==
                        FoodTab.barcode) // Barcode tab attribution
                      Padding(
                        padding: EdgeInsets.only(
                          left: Responsive.width(context, 20),
                          right: Responsive.width(context, 20),
                          bottom: Responsive.height(context, 6),
                        ),
                        child: buildAttribution(
                          "https://openfoodfacts.org",
                          "Powered by Open Food Facts",
                          Colors.green,
                        ),
                      ),

                    if (_tabController.index ==
                        FoodTab.manual) // Manual tab attribution
                      Padding(
                        padding: EdgeInsets.only(
                          left: Responsive.width(context, 20),
                          right: Responsive.width(context, 20),
                          bottom: Responsive.height(context, 6),
                        ),
                        child: Builder(
                          builder: (context) {
                            final username = currentUserData?.username;
                            final hasUsername =
                                username != null &&
                                username != currentUserData?.uid;
                            final label = hasUsername
                                ? "Powered by $username!"
                                : "Powered by you!";
                            return textWithFont(
                              label,
                              context,
                              Responsive.font(context, 15),
                              color: lightenColor(appColorNotifier.value, 0.5),
                            );
                          },
                        ),
                      ),

                    // Inline error for barcode and manual tabs
                    if (_tabController.index != FoodTab.search)
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.width(context, 20),
                        ),
                        child: _buildInlineError(),
                      ),

                    // Search field on search tab, log button on barcode/manual
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.width(context, 20),
                      ),
                      child: SizedBox(
                        height: Responsive.height(context, 58),
                        child: _tabController.index == FoodTab.search
                            ? buildSearchButton()
                            : buildLogFoodButton(),
                      ),
                    ),

                    SizedBox(height: Responsive.height(context, 10)),

                    // Log Food button for the search tab
                    if (_tabController.index == FoodTab.search)
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.width(context, 20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInlineError(),
                            SizedBox(
                              width: double.infinity,
                              child: buildLogFoodButton(),
                            ),
                          ],
                        ),
                      ),

                    // Recent foods collapsible section
                    if (_recentFoods.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.width(context, 20),
                        ),
                        child: _buildRecentFoodsSection(),
                      ),

                    // Tab content area and meal tiles
                    Expanded(
                      child: NotificationListener<ScrollNotification>(
                        // Collapse recent foods when the user scrolls the content area below
                        onNotification: (notification) {
                          if (_recentFoodsExpanded &&
                              notification is ScrollStartNotification) {
                            setState(() => _recentFoodsExpanded = false);
                            _recentFoodsAnim.reverse();
                          }
                          return false;
                        },
                        child: GestureDetector(
                          // Collapse recent foods when the user taps the content area below
                          behavior: HitTestBehavior.translucent,
                          onTap: _recentFoodsExpanded
                              ? () {
                                  setState(() => _recentFoodsExpanded = false);
                                  _recentFoodsAnim.reverse();
                                }
                              : null,
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
                                else if (_tabController.index ==
                                    FoodTab.barcode)
                                  _buildBarcodeTab(),
                                Expanded(child: _buildMealTiles()),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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
