import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../globals.dart';
import '../guest.dart';
import '../utility/responsive.dart';
import '../services/user_data_manager.dart';
import '../services/recent_foods_service.dart';
import '../services/voice_search_service.dart';
import '../utility/food_logging_helper.dart';
import '../utility/shared_preferences/shared_prefs_async.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:skeletonizer/skeletonizer.dart';

class LogFoodScreen extends StatefulWidget {
  final String meal;
  final DateTime currentDate;
  final VoidCallback
  onFoodLogged; // Called on a successful log so the parent screen refreshes
  final String?
  achievementId; // Which input method opened this screen, used to fire the right achievement

  const LogFoodScreen({
    super.key,
    required this.meal,
    required this.currentDate,
    required this.onFoodLogged,
    this.achievementId,
  });

  @override
  State<LogFoodScreen> createState() => _LogFoodScreenState();

  // Allows up to 5 digits with an optional decimal up to decimalPlaces places
  static TextInputFormatter decimalFormatter({int decimalPlaces = 2}) {
    return TextInputFormatter.withFunction((oldValue, newValue) {
      if (newValue.text.isEmpty) return newValue;
      return RegExp(
            '^\\d{0,5}(\\.\\d{0,$decimalPlaces})?\$',
          ).hasMatch(newValue.text)
          ? newValue
          : oldValue;
    });
  }
}

class _LogFoodScreenState extends State<LogFoodScreen>
    with SingleTickerProviderStateMixin {
  String? _inlineError;
  Map<String, dynamic>? selectedFood;
  bool userCanType = true;
  bool snackbarActive = false;
  bool isLogging = false;
  String latestQuery = "";
  Timer? checkTimer;
  List<dynamic> foodList = [];
  String selectedUnit = 'g';
  double baseAmount = 1.0;
  Map<String, double> baseMacros = {};
  String displayDescription = '';

  // Barcode scanner state
  bool scannerActive = false;
  bool barcodeLoading = false;
  String? barcodeError;

  // Recent foods section visibility
  bool _recentExpanded = true;
  final _prefs = SharedPrefsService();

  // Recent food matches shown when a search query matches something in recent foods
  List<Map<String, dynamic>> _recentMatches = [];
  bool _showingRecentMatches = true;
  bool _isSearching = false;

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
  final TextEditingController _recentServingController =
      TextEditingController();
  String manualSelectedUnit = 'serving';

  // Voice search
  final VoiceSearchService _voiceSearch = VoiceSearchService();

  // Recent foods
  final RecentFoodsService _recentFoodsService = RecentFoodsService();
  List<Map<String, dynamic>> _recentFoods = [];

  @override
  void initState() {
    super.initState();
    FirebaseAnalytics.instance.logScreenView(
      screenName: '/food-logging/log',
      screenClass: 'LogFoodScreen',
    );
    _loadRecentFoods();
    _loadRecentExpanded();
    _voiceSearch.init(() {
      if (mounted) setState(() {});
    });
  }

  // Instantly filters recent foods, then schedules a debounced API call if no recent matches
  void _filterRecents(String value) {
    if (isGuest) {
      Guest.block(context);
      return;
    }

    final query = value.toLowerCase().trim();

    if (query.isEmpty) {
      setState(() {
        _recentMatches = [];
        foodList = [];
        _isSearching = false;
      });
      return;
    }

    final matches = _recentFoods.where((f) {
      final name = (f['food_name'] as String? ?? '').toLowerCase();
      final brand = (f['brand_name'] as String? ?? '').toLowerCase();
      return name.contains(query) || brand.contains(query);
    }).toList();

    setState(() {
      _recentMatches = matches;
      _showingRecentMatches = matches.isNotEmpty;
      if (matches.isNotEmpty) foodList = [];
    });

    if (matches.isNotEmpty) checkTimer?.cancel();
  }

  // Toggles the microphone for voice input on the search bar
  Future<void> _toggleListening() async {
    if (isGuest) {
      Guest.block(context);
      return;
    } // For guest users
    if (!_voiceSearch.isAvailable) {
      _showSnackbar("Voice search isn't available on this device.");
      return;
    }
    await _voiceSearch.toggle((text) {
      searchController.text = text;
      searchController.selection = TextSelection.fromPosition(
        TextPosition(offset: searchController.text.length),
      );
      _filterRecents(text);
    });
  }

  // Disposes to prevent memory leaks
  @override
  void dispose() {
    checkTimer?.cancel();
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
    _recentServingController.dispose();
    super.dispose();
  }

  // Helper method for snackbars
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
                const Icon(Icons.info, color: Colors.white),
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

  // Method for getting the user's recently stored foods
  Future<void> _loadRecentFoods() async {
    if (mounted)
      setState(
        () => _recentFoods = [
          {
            'food_name': 'Chicken Breast',
            'brand_name': 'Generic',
            'calories': 165,
            'food_description':
                'Per 100g | Calories: 165kcal | Fat: 3.57g | Carbs: 0g | Protein: 31g | Serving: 100g',
          },
          {
            'food_name': 'Brown Rice',
            'brand_name': null,
            'calories': 216,
            'food_description':
                'Per 1 cup | Calories: 216kcal | Fat: 1.8g | Carbs: 44g | Protein: 5g | Serving: 1cup',
          },
          {
            'food_name': 'Greek Yogurt',
            'brand_name': 'Chobani',
            'calories': 90,
            'food_description':
                'Per 170g | Calories: 90kcal | Fat: 0g | Carbs: 6g | Protein: 17g | Serving: 170g',
          },
          {
            'food_name': 'Banana',
            'brand_name': null,
            'calories': 105,
            'food_description':
                'Per 1 medium | Calories: 105kcal | Fat: 0.4g | Carbs: 27g | Protein: 1.3g | Serving: 1serving',
          },
          {
            'food_name': 'Peanut Butter',
            'brand_name': 'Jif',
            'calories': 190,
            'food_description':
                'Per 2 tbsp | Calories: 190kcal | Fat: 16g | Carbs: 7g | Protein: 7g | Serving: 2tbsp',
          },
          {
            'food_name': 'Whole Milk',
            'brand_name': 'Organic Valley',
            'calories': 150,
            'food_description':
                'Per 1 cup | Calories: 150kcal | Fat: 8g | Carbs: 12g | Protein: 8g | Serving: 1cup',
          },
          {
            'food_name': 'Scrambled Eggs',
            'brand_name': null,
            'calories': 180,
            'food_description':
                'Per 2 eggs | Calories: 180kcal | Fat: 12g | Carbs: 1.6g | Protein: 14g | Serving: 2serving',
          },
          {
            'food_name': 'Oatmeal',
            'brand_name': 'Quaker',
            'calories': 150,
            'food_description':
                'Per 1 cup | Calories: 150kcal | Fat: 3g | Carbs: 27g | Protein: 5g | Serving: 1cup',
          },
          {
            'food_name': 'Almonds',
            'brand_name': 'Blue Diamond',
            'calories': 164,
            'food_description':
                'Per 28g | Calories: 164kcal | Fat: 14g | Carbs: 6g | Protein: 6g | Serving: 28g',
          },
          {
            'food_name': 'Salmon Fillet',
            'brand_name': null,
            'calories': 280,
            'food_description':
                'Per 150g | Calories: 280kcal | Fat: 13g | Carbs: 0g | Protein: 39g | Serving: 150g',
          },
        ],
      );
  }

  Future<void> _loadRecentExpanded() async {
    final val = await _prefs.getBool(SharedPreferencesKey.recentFoodsExpanded);
    if (mounted && val != null) setState(() => _recentExpanded = val);
  }

  void _saveRecentExpanded(bool val) {
    _prefs.setBool(SharedPreferencesKey.recentFoodsExpanded, val);
  }

  // Method for updating the user's recent stored foods to local storage
  Future<void> _saveToRecentFoods(Map<String, dynamic> food) async {
    await _recentFoodsService.addRecentFood(food);
    await _loadRecentFoods(); // update the shown list after updating
  }

  // Parses the serving string and sets up base macros so scaling works correctly
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

  // Recomputes the display description whenever the serving amount field changes
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

  // Calls the FatSecret search API after the debounce timer fires
  void handleApiCall(String query) async {
    if (query.isEmpty) return;
    query = query.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    latestQuery = query;
    setState(() => _isSearching = true);

    try {
      final response = await UserDataManager.searchFood(query);
      if (response.statusCode == 200) {
        if (latestQuery != query) return;
        final foods = jsonDecode(response.body)['foods'];
        FocusScope.of(context).unfocus();
        setState(() {
          _isSearching = false;
          foodList = foods?['food'] != null
              ? List<dynamic>.from(foods['food'])
              : [];
        });
      } else if (response.statusCode == 429) {
        final errorData = jsonDecode(response.body);
        if (errorData['error'] == "Token limit exceeded") {
          _showSnackbar(
            "Daily search limit reached. Resets in ${FoodLoggingHelper.formatDuration(errorData['time_left'])}.",
            duration: const Duration(seconds: 5),
          );
        }
        setState(() {
          _isSearching = false;
          foodList = [];
        });
      } else {
        setState(() {
          _isSearching = false;
          foodList = [];
        });
      }
    } catch (error) {
      if (kDebugMode) debugPrint("API call error: $error");
      setState(() {
        _isSearching = false;
        foodList = [];
      });
      if (!isConnected) {
        _showSnackbar("Error searching. Check your connection and try again.");
      }
    }
  }

  // Method that looks up the scanned barcode via Open Food Facts and populates selectedFood
  Future<void> lookupBarcode(String barcode) async {
    setState(() {
      barcodeLoading = true;
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
          trackTrivialAchievement('food_barcode');
          setState(() {
            // Treat the barcode result the same as a selected search result
            selectedFood = {
              'food_name': data['product']['product_name'] ?? 'Unknown Product',
              'brand_name': data['product']['brands'],
              'food_description': description,
            };
            searchController.text = selectedFood!['food_name'];
            userCanType = false;
            barcodeLoading = false;
            foodList = [];
          });
        } else {
          setState(() {
            barcodeError = "Product not found in database.";
            barcodeLoading = false;
            foodList = [];
            _recentMatches = [];
          });
        }
      } else {
        setState(() {
          barcodeError = "Failed to look up product. Try again.";
          barcodeLoading = false;
          foodList = [];
          _recentMatches = [];
        });
      }
    } catch (e) {
      setState(() {
        barcodeError = "Network error. Check your connection.";
        barcodeLoading = false;
        foodList = [];
        _recentMatches = [];
      });
    }
  }

  // Logs the food to the correct meal then notifies the parent and pops back
  Future<void> logFood(Map<String, dynamic> foodObject) async {
    if (isLogging) {
      _showSnackbar("Please wait before logging again.");
      return;
    }

    // Scale the food to the user's chosen serving size if baseMacros is available
    if (baseMacros.isNotEmpty) {
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

    // Group foods by date and create the day entry if it doesn’t exist
    final dateKey = FoodLoggingHelper.formatDateKey(widget.currentDate);

    currentUserData?.foodDataByDate.putIfAbsent(
      dateKey,
      () => {"breakfast": [], "lunch": [], "dinner": [], "snacks": []},
    );

    // Add food to the correct meal for that day
    currentUserData?.foodDataByDate[dateKey]![widget.meal]!.add(foodObject);

    // Add the logged food locally and into the database
    try {
      final currentDateData = {
        dateKey: currentUserData!.foodDataByDate[dateKey]!,
      };
      await userManager.updateFoodDataByDate(
        currentDateData,
        context: context,
        isBeingDeleted: false,
      );
    } catch (e) {
      if (kDebugMode) debugPrint("Error saving food data: $e");
    }

    // Track which input method the user used to log this food
    if (widget.achievementId != null) {
      trackTrivialAchievement(widget.achievementId!);
    }

    // Award the full course meal badge if all four meals now have at least one food
    final dayData = currentUserData?.foodDataByDate[dateKey];
    final allMealsFilled = [
      'breakfast',
      'lunch',
      'dinner',
      'snacks',
    ].every((m) => (dayData?[m] ?? []).isNotEmpty);
    if (allMealsFilled) trackTrivialAchievement("food_full_day");

    // time-based achievements based on the hour the food was logged
    final hour = DateTime.now().hour;
    if (hour >= 23) trackTrivialAchievement("night_owl"); // after 11pm
    if (hour < 8) trackTrivialAchievement("early_bird"); // before 8am

    foodLogNotifier.value++;
    widget.onFoodLogged();
    if (mounted) context.pop();
  }

  Future<void> _showManualEntrySheet() async {
    // Clear controllers each time the dialog opens
    manualNameController.clear();
    manualServingAmountController.clear();
    manualCaloriesController.clear();
    manualProteinController.clear();
    manualCarbsController.clear();
    manualFatController.clear();
    manualSelectedUnit = 'serving';
    String? dialogError;

    Widget goalField(
      BuildContext ctx,
      TextEditingController controller,
      String hint, {
      TextInputType keyboardType = TextInputType.text,
      List<TextInputFormatter>? inputFormatters,
    }) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: Responsive.height(ctx, 4)),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(ctx, 15),
            color: Colors.white,
          ),
          cursorColor: Colors.white,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.manrope(
              color: Colors.white38,
              fontSize: Responsive.font(ctx, 14),
            ),
            contentPadding: EdgeInsets.only(
              top: Responsive.height(ctx, 13),
              left: Responsive.width(ctx, 6),
            ),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white54),
            ),
          ),
        ),
      );
    }

    await showFrostedDialog(
      context: context,
      child: StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  "Enter Manually",
                  style: GoogleFonts.manrope(
                    fontSize: Responsive.font(context, 20),
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(height: Responsive.height(context, 16)),
              SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "REQUIRED",
                      style: GoogleFonts.manrope(
                        fontSize: Responsive.font(ctx, 11),
                        color: Colors.white38,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    goalField(
                      ctx,
                      manualNameController,
                      "Food Name",
                      inputFormatters: [LengthLimitingTextInputFormatter(50)],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          flex: 2,
                          child: goalField(
                            ctx,
                            manualServingAmountController,
                            "Serving Amount",
                            keyboardType: TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [LogFoodScreen.decimalFormatter()],
                          ),
                        ),
                        SizedBox(width: Responsive.width(ctx, 12)),
                        Expanded(
                          flex: 1,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: Responsive.height(ctx, 4),
                            ),
                            child: GestureDetector(
                              onTap: () async {
                                // Pick unit via a second dialog stacked on top
                                final picked = await showFrostedDialog<String>(
                                  context: ctx,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Center(
                                        child: Text(
                                          "Unit",
                                          style: GoogleFonts.manrope(
                                            fontSize: Responsive.font(ctx, 20),
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        height: Responsive.height(ctx, 12),
                                      ),
                                      // Standard units, GestureDetector avoids ripple bleeding over the dialog background
                                      ...allowedUnits.map(
                                        (u) => GestureDetector(
                                          onTap: () => Navigator.pop(ctx, u),
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: Responsive.height(
                                                ctx,
                                                10,
                                              ),
                                              horizontal: Responsive.width(
                                                ctx,
                                                4,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    u,
                                                    style: GoogleFonts.manrope(
                                                      fontSize: Responsive.font(
                                                        ctx,
                                                        15,
                                                      ),
                                                      color:
                                                          manualSelectedUnit ==
                                                              u
                                                          ? Colors.white
                                                          : Colors.white60,
                                                      fontWeight:
                                                          manualSelectedUnit ==
                                                              u
                                                          ? FontWeight.w600
                                                          : FontWeight.w400,
                                                    ),
                                                  ),
                                                ),
                                                if (manualSelectedUnit == u)
                                                  Icon(
                                                    Icons.check,
                                                    color: Colors.white,
                                                    size: Responsive.scale(
                                                      ctx,
                                                      16,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      Divider(
                                        color: Colors.white.withAlpha(25),
                                      ),
                                      GestureDetector(
                                        onTap: () =>
                                            Navigator.pop(ctx, '__custom__'),
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: Responsive.height(
                                              ctx,
                                              10,
                                            ),
                                            horizontal: Responsive.width(
                                              ctx,
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            "Custom...",
                                            style: GoogleFonts.manrope(
                                              fontSize: Responsive.font(
                                                ctx,
                                                15,
                                              ),
                                              color: Colors.white38,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (picked == '__custom__') {
                                  _customUnitController.clear();
                                  if (!mounted) return;
                                  await showFrostedAlertDialog(
                                    context: context,
                                    title: "Custom Unit",
                                    content: TextField(
                                      controller: _customUnitController,
                                      autofocus: true,
                                      style: GoogleFonts.manrope(
                                        color: Colors.white,
                                      ),
                                      decoration: InputDecoration(
                                        hintText:
                                            "e.g. a slice, a can, a bag...",
                                        hintStyle: GoogleFonts.manrope(
                                          color: Colors.white38,
                                        ),
                                        enabledBorder:
                                            const UnderlineInputBorder(
                                              borderSide: BorderSide(
                                                color: Colors.white38,
                                              ),
                                            ),
                                        focusedBorder:
                                            const UnderlineInputBorder(
                                              borderSide: BorderSide(
                                                color: Colors.white,
                                              ),
                                            ),
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(
                                          context,
                                          rootNavigator: true,
                                        ).pop(),
                                        child: const Text(
                                          "Cancel",
                                          style: TextStyle(
                                            color: Colors.white54,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          final custom = _customUnitController
                                              .text
                                              .trim();
                                          if (custom.isNotEmpty) {
                                            setDialogState(
                                              () => manualSelectedUnit = custom,
                                            );
                                          }
                                          Navigator.of(
                                            context,
                                            rootNavigator: true,
                                          ).pop();
                                        },
                                        child: const Text(
                                          "OK",
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  );
                                } else if (picked != null) {
                                  setDialogState(
                                    () => manualSelectedUnit = picked,
                                  );
                                }
                              },
                              child: Container(
                                padding: EdgeInsets.only(
                                  bottom: Responsive.height(ctx, 6),
                                ),
                                decoration: const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(color: Colors.white24),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        manualSelectedUnit,
                                        style: GoogleFonts.manrope(
                                          fontSize: Responsive.font(ctx, 14),
                                          color: Colors.white54,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right,
                                      color: Colors.white38,
                                      size: Responsive.scale(ctx, 16),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    goalField(
                      ctx,
                      manualCaloriesController,
                      "Calories (kcal)",
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        LogFoodScreen.decimalFormatter(decimalPlaces: 3),
                      ],
                    ),
                    SizedBox(height: Responsive.height(ctx, 14)),
                    Text(
                      "OPTIONAL",
                      style: GoogleFonts.manrope(
                        fontSize: Responsive.font(ctx, 11),
                        color: Colors.white38,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    goalField(
                      ctx,
                      manualProteinController,
                      "Protein (g)",
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        LogFoodScreen.decimalFormatter(decimalPlaces: 3),
                      ],
                    ),
                    goalField(
                      ctx,
                      manualCarbsController,
                      "Carbs (g)",
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        LogFoodScreen.decimalFormatter(decimalPlaces: 3),
                      ],
                    ),
                    goalField(
                      ctx,
                      manualFatController,
                      "Fat (g)",
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        LogFoodScreen.decimalFormatter(decimalPlaces: 3),
                      ],
                    ),
                    if (dialogError != null) ...[
                      SizedBox(height: Responsive.height(ctx, 8)),
                      Text(
                        dialogError!,
                        style: GoogleFonts.manrope(
                          color: Colors.white54,
                          fontSize: Responsive.font(ctx, 13),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: Responsive.height(context, 24)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      "CANCEL",
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final name = manualNameController.text.trim();
                      if (name.isEmpty ||
                          manualCaloriesController.text.trim().isEmpty ||
                          manualServingAmountController.text.trim().isEmpty) {
                        setDialogState(
                          () => dialogError =
                              "Name, calories, and serving size are required.",
                        );
                        return;
                      }
                      final calories =
                          int.tryParse(manualCaloriesController.text.trim()) ??
                          0;
                      final fat = manualFatController.text.trim();
                      final carbs = manualCarbsController.text.trim();
                      final protein = manualProteinController.text.trim();
                      if (fat.isEmpty && carbs.isEmpty && protein.isEmpty) {
                        showFrostedAlertDialog(
                          context: context,
                          title: "No macronutrients entered!",
                          content: Text(
                            "You haven't entered any fat, carbs, or protein. Log anyway?",
                            style: GoogleFonts.manrope(color: Colors.white70),
                          ),
                          actions: [
                            // Dismiss alert only, manual entry dialog stays open
                            TextButton(
                              onPressed: () => Navigator.of(
                                context,
                                rootNavigator: true,
                              ).pop(),
                              child: const Text(
                                "Go Back",
                                style: TextStyle(color: Colors.white54),
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                // Pop alert then manual entry dialog, then submit
                                Navigator.of(
                                  context,
                                  rootNavigator: true,
                                ).pop();
                                Navigator.pop(ctx);
                                await _submitManualEntry(
                                  name,
                                  calories,
                                  fat,
                                  carbs,
                                  protein,
                                );
                              },
                              child: const Text(
                                "Log Anyway",
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        );
                        return;
                      }
                      Navigator.pop(ctx);
                      await _submitManualEntry(
                        name,
                        calories,
                        fat,
                        carbs,
                        protein,
                      );
                    },
                    child: const Text(
                      "LOG",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  // Method for formatting manual entries in the same way as the Search and Barcode expects it
  Future<void> _submitManualEntry(
    String name,
    int calories,
    String fat,
    String carbs,
    String protein,
  ) async {
    final servingAmt = manualServingAmountController.text.trim();
    final servingLabel = servingAmt.isNotEmpty
        ? '$servingAmt $manualSelectedUnit'
        : manualSelectedUnit;
    final parts = <String>['Calories: ${calories}kcal'];
    if (fat.isNotEmpty) parts.add('Fat: ${fat}g');
    if (carbs.isNotEmpty) parts.add('Carbs: ${carbs}g');
    if (protein.isNotEmpty) parts.add('Protein: ${protein}g');

    trackTrivialAchievement('food_manual');
    await logFood({
      'food_name': name,
      'food_description': 'Per $servingLabel - ${parts.join(' | ')}',
      'calories': calories,
    });
  }

  // Clears the selected food and resets back to the empty search state
  void _clearSelection() {
    setState(() {
      selectedFood = null;
      userCanType = true;
      searchController.clear();
      foodList = [];
      _recentMatches = [];
      _showingRecentMatches = true;
      displayDescription = '';
      baseMacros = {};
      barcodeError = null;
      _inlineError = null;
    });
  }

  // Tappable attribution link helper method
  Widget _buildAttributionLink(String url, String text) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(url);
        if (!await launchUrl(uri)) throw "Error: Could not open website";
      },
      child: Text(
        text,
        style: GoogleFonts.manrope(
          fontSize: Responsive.font(context, 11),
          color: cardColors(appColorNotifier.value).onCard.withAlpha(120),
          decoration: TextDecoration.underline,
          decorationColor: cardColors(
            appColorNotifier.value,
          ).onCard.withAlpha(120),
        ),
      ),
    );
  }

  // Single attribution line combining both data sources
  Widget _buildAttributionRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildAttributionLink(
          "https://platform.fatsecret.com",
          "Powered by FatSecret",
        ),
        Text(
          "  ·  ",
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 11),
            color: cardColors(appColorNotifier.value).onCard.withAlpha(120),
          ),
        ),
        _buildAttributionLink(
          "https://openfoodfacts.org",
          "Open Food Facts (ODbL)",
        ),
      ],
    );
  }

  // Thin horizontal rule used to visually separate sections
  // Shows a unified serving + nutrition dialog for any food (search results, recent, barcode)
  Future<void> _showServingDialog(
    Map<String, dynamic> food, {
    String? achievementId,
  }) async {
    final description = food['food_description'] as String? ?? '';
    final serving = FoodLoggingHelper.parseServing(description);
    final baseAmt = serving['amount'] as double;

    _recentServingController.text = baseAmt % 1 == 0
        ? baseAmt.toInt().toString()
        : baseAmt.toString();

    final newAmtStr = await showServingAmountDialog(
      context: context,
      food: food,
      controller: _recentServingController,
      confirmLabel: 'Log',
    );

    if (newAmtStr == null || newAmtStr.isEmpty) return;
    final newAmt = double.tryParse(newAmtStr);
    if (newAmt == null || newAmt <= 0) return;

    _initServing(description);
    servingAmountController.text = newAmt % 1 == 0
        ? newAmt.toInt().toString()
        : newAmt.toString();

    if (achievementId != null) trackTrivialAchievement(achievementId);
    await logFood(Map<String, dynamic>.from(food));
  }

  Widget _buildSourceTab(
    String label,
    bool active,
    Color appColor,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: Responsive.height(context, 12)),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? lightenColor(appColor, 0.45) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 13),
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active
                ? lightenColor(appColor, 0.45)
                : lightenColor(appColor, 0.3),
          ),
        ),
      ),
    );
  }

  // Macro info shown on the selected food card, updates live as serving changes

  Widget _buildLogFoodButton({VoidCallback? onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: frostedButton(
        "Log Food",
        context,
        onPressed: onPressed ?? () {},
        color: appColorNotifier.value,
      ),
    );
  }

  // Inline validation error shown above the log button
  Widget _buildInlineError(String? error) {
    if (error == null) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: Responsive.height(context, 6)),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: cardColors(appColorNotifier.value).onCard.withAlpha(160),
            size: Responsive.font(context, 14),
          ),
          SizedBox(width: Responsive.width(context, 6)),
          Expanded(
            child: Text(
              error,
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 13),
                color: cardColors(appColorNotifier.value).onCard.withAlpha(160),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Macro summary line shown under each recent food tile

  // Full screen barcode scanner that dismisses on a successful scan or back tap
  Widget _buildBarcodeScanner() {
    return Container(
      decoration: BoxDecoration(gradient: buildThemeGradient()),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.only(
                  left: Responsive.width(context, 16),
                  top: Responsive.height(context, 8),
                  bottom: Responsive.height(context, 12),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => setState(() => scannerActive = false),
                    child: Container(
                      padding: EdgeInsets.all(Responsive.scale(context, 12)),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: lightenColor(
                          appColorNotifier.value,
                          0.1,
                        ).withAlpha(20),
                        border: Border.all(
                          color: lightenColor(
                            appColorNotifier.value,
                            0.3,
                          ).withAlpha(180),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new,
                        color: lightenColor(
                          appColorNotifier.value,
                          0.3,
                        ).withAlpha(180),
                        size: Responsive.font(context, 13),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(Responsive.width(context, 16)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      Responsive.scale(context, 16),
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
              ),
              Padding(
                padding: EdgeInsets.only(
                  bottom: Responsive.height(context, 20),
                ),
                child: Center(
                  child: _buildAttributionLink(
                    "https://openfoodfacts.org",
                    "Open Food Facts (ODbL)",
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // A single search result or recent-match row, name bold, description dim, + button on right
  Widget _buildFoodRow(
    Map<String, dynamic> food, {
    required VoidCallback onTap,
  }) {
    final c = cardColors(appColorNotifier.value);
    final description = food['food_description'] as String? ?? '';
    // calories may be a top-level key (manual/recent) or only in food_description (API results)
    final cal = food['calories'] != null
        ? (num.tryParse(food['calories'].toString()) ?? 0).toInt()
        : FoodLoggingHelper.extractCalories(description);
    final serving = FoodLoggingHelper.parseServing(description);
    final servingAmt = serving['amount'] as double;
    final servingStr = servingAmt % 1 == 0
        ? servingAmt.toInt().toString()
        : servingAmt.toString();
    final subtitle = '$servingStr ${serving['unit']} · $cal calories';
    final macros = FoodLoggingHelper.extractMacros(description);
    final hasMacros =
        (macros['protein'] ?? 0) > 0 ||
        (macros['carbs'] ?? 0) > 0 ||
        (macros['fat'] ?? 0) > 0;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior
          .opaque, // ensures tap registers across the full row including empty space
      child: Container(
        padding: EdgeInsets.symmetric(vertical: Responsive.height(context, 13)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food['food_name'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: Responsive.font(context, 14),
                      fontWeight: FontWeight.w600,
                      color: lightenColor(appColorNotifier.value, 0.45),
                    ),
                  ),
                  Text(
                    food['brand_name'] != null
                        ? '${food['brand_name']} · $subtitle'
                        : subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: Responsive.font(context, 12),
                      color: c.onCard.withAlpha(140),
                    ),
                  ),
                  if (hasMacros)
                    Text(
                      'Protein ${macros['protein']!.toStringAsFixed(1)}g · Carbs ${macros['carbs']!.toStringAsFixed(1)}g · Fat ${macros['fat']!.toStringAsFixed(1)}g',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: Responsive.font(context, 11),
                        color: c.onCard.withAlpha(100),
                      ),
                    ),
                ],
              ),
            ),
            // chevron makes it clear the row is tappable
            Icon(
              Icons.chevron_right,
              color: lightenColor(appColorNotifier.value, 0.3).withAlpha(160),
              size: Responsive.scale(context, 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEndOfResults() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: Responsive.height(context, 12)),
      child: Center(
        child: Text(
          "End of results",
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 12),
            color: cardColors(appColorNotifier.value).onCard.withAlpha(80),
          ),
        ),
      ),
    );
  }

  // One card in the 2x2 input method grid
  Widget _buildInputCard({
    required IconData icon,
    required String label,
    required String sublabel,
    required VoidCallback onTap,
    bool disabled = false,
  }) {
    final base = appColorNotifier.value;
    final c = cardColors(base);
    final radius = BorderRadius.circular(Responsive.scale(context, 16));
    return Opacity(
      opacity: disabled ? 0.4 : 1.0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: c.gradient,
          ),
          border: Border.all(color: c.border, width: 1),
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: disabled ? null : onTap,
              splashColor: c.splashColor,
              highlightColor: c.highlightColor,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.width(context, 16),
                  vertical: Responsive.height(context, 16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(Responsive.scale(context, 10)),
                      decoration: BoxDecoration(
                        color: c.iconBox,
                        borderRadius: BorderRadius.circular(
                          Responsive.scale(context, 12),
                        ),
                        border: Border.all(
                          color: lightenColor(base, 0.35).withAlpha(80),
                        ),
                      ),
                      child: HugeIcon(
                        icon: icon,
                        color: lightenColor(base, 0.45),
                        size: Responsive.scale(context, 20),
                      ),
                    ),
                    SizedBox(width: Responsive.width(context, 12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: Responsive.font(context, 14),
                              fontWeight: FontWeight.w700,
                              color: lightenColor(base, 0.45),
                            ),
                          ),
                          Text(
                            sublabel,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: Responsive.font(context, 11),
                              color: lightenColor(base, 0.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (scannerActive) return _buildBarcodeScanner();

    final appColor = appColorNotifier.value;
    final c = cardColors(appColor);
    final accent = lightenColor(appColor, 0.45);
    final dim = lightenColor(appColor, 0.35);
    final mealLabel = widget.meal[0].toUpperCase() + widget.meal.substring(1);

    // how many kcal already logged to this meal today

    // true when none of the active search/selection states are showing
    final showSections =
        foodList.isEmpty &&
        selectedFood == null &&
        !_isSearching &&
        _recentMatches.isEmpty;

    return Container(
      decoration: BoxDecoration(gradient: buildThemeGradient()),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListView(
            padding: EdgeInsets.only(
              left: Responsive.centeredHorizontalPadding(context, 20),
              right: Responsive.centeredHorizontalPadding(context, 20),
              bottom: Responsive.height(context, 32),
            ),
            children: [
              // Header: back button row then greeting-style meal label below
              Padding(
                padding: EdgeInsets.only(
                  top: Responsive.height(context, 8),
                  bottom: Responsive.height(context, 20),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        padding: EdgeInsets.all(Responsive.scale(context, 12)),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: lightenColor(appColor, 0.1).withAlpha(20),
                          border: Border.all(
                            color: lightenColor(appColor, 0.3).withAlpha(180),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new,
                          color: lightenColor(appColor, 0.3).withAlpha(180),
                          size: Responsive.font(context, 13),
                        ),
                      ),
                    ),
                    SizedBox(width: Responsive.width(context, 16)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "ADDING TO",
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 14),
                            fontWeight: FontWeight.w600,
                            color: accent,
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(height: Responsive.height(context, 2)),
                        Text(
                          mealLabel,
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 26),
                            fontWeight: FontWeight.w800,
                            color: accent,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Search bar, mic on the right, no leading icon
              frostedGlassCard(
                context,
                baseRadius: 14,
                border: Border.all(color: Colors.transparent),
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.width(context, 14),
                  vertical: Responsive.height(context, 8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search,
                      color: c.onCard.withAlpha(120),
                      size: Responsive.font(context, 20),
                    ),
                    SizedBox(width: Responsive.width(context, 10)),
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        readOnly: !userCanType || isGuest,
                        onTap: isGuest ? () => Guest.block(context) : null,
                        keyboardType: TextInputType.text,
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 15),
                          color: accent,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: "Search for a food...",
                          hintStyle: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 15),
                            color: c.onCard.withAlpha(100),
                          ),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            vertical: Responsive.height(context, 16),
                            horizontal: Responsive.width(context, 4),
                          ),
                        ),
                        onChanged: _filterRecents,
                        onSubmitted: (v) => handleApiCall(v),
                      ),
                    ),
                    // filled search button so it's obvious something needs to be tapped
                    if (searchController.text.isNotEmpty &&
                        selectedFood == null)
                      GestureDetector(
                        onTap: () {
                          setState(() => _showingRecentMatches = false);
                          handleApiCall(searchController.text);
                        },
                        child: Container(
                          margin: EdgeInsets.only(
                            left: Responsive.width(context, 6),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: Responsive.width(context, 12),
                            vertical: Responsive.height(context, 7),
                          ),
                          decoration: BoxDecoration(
                            color: lightenColor(appColor, 0.35).withAlpha(160),
                            borderRadius: BorderRadius.circular(
                              Responsive.scale(context, 20),
                            ),
                            border: Border.all(color: accent.withAlpha(180)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search,
                                color: accent,
                                size: Responsive.font(context, 16),
                              ),
                              SizedBox(width: Responsive.width(context, 4)),
                              Text(
                                "Search",
                                style: GoogleFonts.manrope(
                                  color: accent,
                                  fontSize: Responsive.font(context, 12),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // mic icon in search bar shows active state when listening
                    GestureDetector(
                      onTap: _toggleListening,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.width(context, 8),
                        ),
                        child: HugeIcon(
                          icon: _voiceSearch.isListening
                              ? HugeIcons.strokeRoundedMic01
                              : HugeIcons.strokeRoundedMic02,
                          color: _voiceSearch.isListening
                              ? accent
                              : c.onCard.withAlpha(140),
                          size: Responsive.font(context, 20),
                        ),
                      ),
                    ),
                    if (searchController.text.isNotEmpty)
                      GestureDetector(
                        onTap: _clearSelection,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: Responsive.width(context, 8),
                          ),
                          child: Icon(
                            Icons.close,
                            color: c.onCard.withAlpha(140),
                            size: Responsive.font(context, 20),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              SizedBox(height: Responsive.height(context, 20)),

              // 2x2 input method grid, only shown when not searching
              if (showSections) ...[
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _buildInputCard(
                          icon: HugeIcons.strokeRoundedQrCode,
                          label: "Scan",
                          sublabel: "Scan a barcode",
                          onTap: () {
                            if (isGuest) {
                              Guest.block(context);
                              return;
                            }
                            setState(() => scannerActive = true);
                          },
                        ),
                      ),
                      SizedBox(width: Responsive.width(context, 12)),
                      Expanded(
                        child: _buildInputCard(
                          icon: HugeIcons.strokeRoundedMic01,
                          label: "Voice",
                          sublabel: "Search with your voice",
                          onTap: _toggleListening,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: Responsive.height(context, 12)),
                _buildInputCard(
                  icon: HugeIcons.strokeRoundedPencilEdit01,
                  label: "Manual",
                  sublabel: "Type in the details yourself",
                  onTap: _showManualEntrySheet,
                ),
                SizedBox(height: Responsive.height(context, 20)),
              ],

              // Attribution always visible regardless of search state
              Center(child: _buildAttributionRow()),
              SizedBox(height: Responsive.height(context, 3)),
              Center(
                child: Text(
                  "Not a substitute for medical advice",
                  style: GoogleFonts.manrope(
                    fontSize: Responsive.font(context, 10),
                    color: c.onCard.withAlpha(80),
                  ),
                ),
              ),
              SizedBox(height: Responsive.height(context, 20)),

              // Barcode loading spinner
              if (barcodeLoading)
                Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: Responsive.height(context, 24),
                    ),
                    child: CircularProgressIndicator(
                      color: lightenColor(appColor, 0.3),
                    ),
                  ),
                ),

              // Barcode error with inline retry
              if (barcodeError != null)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: Responsive.height(context, 12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: c.onCard.withAlpha(160),
                        size: Responsive.font(context, 14),
                      ),
                      SizedBox(width: Responsive.width(context, 8)),
                      Expanded(
                        child: Text(
                          barcodeError!,
                          style: GoogleFonts.manrope(
                            color: c.onCard.withAlpha(160),
                            fontSize: Responsive.font(context, 13),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          barcodeError = null;
                          scannerActive = true;
                        }),
                        child: Text(
                          "Retry",
                          style: GoogleFonts.manrope(
                            color: dim,
                            fontSize: Responsive.font(context, 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Selected food dashboard, styled like the home screen logging cards
              if (selectedFood != null && foodList.isEmpty) ...[
                () {
                  final macros = FoodLoggingHelper.extractMacros(
                    displayDescription,
                  );
                  final cal = macros['calories']?.round() ?? 0;
                  final accentColor = lightenColor(appColor, 0.45);
                  final dimColor = lightenColor(appColor, 0.35);

                  // reusable small icon + label header like home screen cards
                  Widget cardLabel(IconData icon, String label) => Row(
                    children: [
                      HugeIcon(
                        icon: icon,
                        color: accentColor,
                        size: Responsive.scale(context, 14),
                      ),
                      SizedBox(width: Responsive.width(context, 5)),
                      Text(
                        label,
                        style: GoogleFonts.manrope(
                          color: accentColor,
                          fontSize: Responsive.font(context, 11),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  );

                  // reusable macro column used in the macros card
                  Widget macroCol(String label, String value) => Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          value,
                          style: GoogleFonts.manrope(
                            color: accentColor,
                            fontSize: Responsive.font(context, 18),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          label,
                          style: GoogleFonts.manrope(
                            color: accentColor,
                            fontSize: Responsive.font(context, 11),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // row 1: food name card (full width) + clear button top right
                      frostedGlassCard(
                        context,
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.width(context, 16),
                          vertical: Responsive.height(context, 14),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      HugeIcon(
                                        icon:
                                            HugeIcons.strokeRoundedPencilEdit01,
                                        color: accentColor,
                                        size: Responsive.scale(context, 14),
                                      ),
                                      SizedBox(
                                        width: Responsive.width(context, 5),
                                      ),
                                      Text(
                                        "Selected food",
                                        style: GoogleFonts.manrope(
                                          color: accentColor,
                                          fontSize: Responsive.font(
                                            context,
                                            11,
                                          ),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(
                                    height: Responsive.height(context, 6),
                                  ),
                                  Text(
                                    selectedFood!['food_name'] ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.manrope(
                                      color: accentColor,
                                      fontSize: Responsive.font(context, 18),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (selectedFood!['brand_name'] != null)
                                    Text(
                                      selectedFood!['brand_name'],
                                      style: GoogleFonts.manrope(
                                        fontSize: Responsive.font(context, 11),
                                        color: dimColor,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: _clearSelection,
                              child: Padding(
                                padding: EdgeInsets.only(
                                  left: Responsive.width(context, 8),
                                ),
                                child: Icon(
                                  Icons.close,
                                  color: accentColor.withAlpha(120),
                                  size: Responsive.scale(context, 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: Responsive.height(context, 10)),

                      // row 2: calories card + macros card side by side
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // calories card
                            Expanded(
                              child: frostedGlassCard(
                                context,
                                padding: EdgeInsets.symmetric(
                                  horizontal: Responsive.width(context, 16),
                                  vertical: Responsive.height(context, 14),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    cardLabel(
                                      HugeIcons.strokeRoundedFire,
                                      "Calories",
                                    ),
                                    SizedBox(
                                      height: Responsive.height(context, 6),
                                    ),
                                    Text(
                                      '$cal',
                                      style: GoogleFonts.manrope(
                                        color: accentColor,
                                        fontSize: Responsive.font(context, 22),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      'kcal',
                                      style: GoogleFonts.manrope(
                                        color: dimColor,
                                        fontSize: Responsive.font(context, 11),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(width: Responsive.width(context, 10)),
                            // macros card
                            Expanded(
                              child: frostedGlassCard(
                                context,
                                padding: EdgeInsets.symmetric(
                                  horizontal: Responsive.width(context, 16),
                                  vertical: Responsive.height(context, 14),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    cardLabel(
                                      HugeIcons.strokeRoundedAppleStocks,
                                      "Macros",
                                    ),
                                    SizedBox(
                                      height: Responsive.height(context, 10),
                                    ),
                                    Row(
                                      children: [
                                        macroCol(
                                          "protein",
                                          '${(macros['protein'] ?? 0).toStringAsFixed(1)}g',
                                        ),
                                        macroCol(
                                          "carbs",
                                          '${(macros['carbs'] ?? 0).toStringAsFixed(1)}g',
                                        ),
                                        macroCol(
                                          "fat",
                                          '${(macros['fat'] ?? 0).toStringAsFixed(1)}g',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: Responsive.height(context, 10)),

                      // row 3: serving size card
                      frostedGlassCard(
                        context,
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.width(context, 16),
                          vertical: Responsive.height(context, 14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            cardLabel(
                              HugeIcons.strokeRoundedWeightScale,
                              "Serving size",
                            ),
                            SizedBox(height: Responsive.height(context, 6)),
                            Row(
                              children: [
                                SizedBox(
                                  width: Responsive.width(context, 60),
                                  child: TextField(
                                    controller: servingAmountController,
                                    keyboardType:
                                        TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    inputFormatters: [
                                      LogFoodScreen.decimalFormatter(),
                                    ],
                                    style: GoogleFonts.manrope(
                                      color: accentColor,
                                      fontSize: Responsive.font(context, 22),
                                      fontWeight: FontWeight.w700,
                                    ),
                                    textAlign: TextAlign.left,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                      enabledBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: dimColor.withAlpha(80),
                                        ),
                                      ),
                                      focusedBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: accentColor,
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
                                    color: dimColor,
                                    fontSize: Responsive.font(context, 11),
                                  ),
                                ),
                                const Spacer(),
                                calcSuffixIcon(
                                  context,
                                  servingAmountController,
                                  onSet: _onServingChanged,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: Responsive.height(context, 12)),
                      _buildInlineError(_inlineError),
                      _buildLogFoodButton(
                        onPressed: () async {
                          setState(() => _inlineError = null);
                          await logFood(
                            Map<String, dynamic>.from(selectedFood!),
                          );
                        },
                      ),
                      SizedBox(height: Responsive.height(context, 24)),
                    ],
                  );
                }(),
              ],

              // Skeletonizer shown while the API search is in flight
              if (_isSearching)
                Skeletonizer(
                  enabled: true,
                  effect: ShimmerEffect(
                    baseColor: lightenColor(appColor, 0.10),
                    highlightColor: lightenColor(appColor, 0.22),
                    duration: const Duration(milliseconds: 1000),
                  ),
                  child: Column(
                    children: List.generate(10, (_) {
                      return Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: Responsive.height(context, 13),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: Responsive.scale(context, 38),
                              height: Responsive.scale(context, 38),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: lightenColor(appColor, 0.15),
                              ),
                            ),
                            SizedBox(width: Responsive.width(context, 12)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    height: Responsive.height(context, 14),
                                    width: Responsive.width(context, 160),
                                    decoration: BoxDecoration(
                                      color: lightenColor(appColor, 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  SizedBox(
                                    height: Responsive.height(context, 5),
                                  ),
                                  Container(
                                    height: Responsive.height(context, 11),
                                    width: Responsive.width(context, 100),
                                    decoration: BoxDecoration(
                                      color: lightenColor(appColor, 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: Responsive.scale(context, 30),
                              height: Responsive.scale(context, 30),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: lightenColor(appColor, 0.15),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),

              // Tab switcher shown whenever there are recent matches; Database tab triggers API call on demand
              if (_recentMatches.isNotEmpty && !_isSearching) ...[
                Padding(
                  padding: EdgeInsets.only(
                    bottom: Responsive.height(context, 10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildSourceTab(
                          'Recent',
                          _showingRecentMatches || foodList.isEmpty,
                          appColor,
                          () => setState(() => _showingRecentMatches = true),
                        ),
                      ),
                      SizedBox(width: Responsive.width(context, 8)),
                      Expanded(
                        child: _buildSourceTab(
                          'Database',
                          !_showingRecentMatches && foodList.isNotEmpty,
                          appColor,
                          () {
                            setState(() => _showingRecentMatches = false);
                            if (foodList.isEmpty) {
                              handleApiCall(searchController.text);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onHorizontalDragEnd: (details) {
                    final dx = details.primaryVelocity ?? 0;
                    if (dx < -200 && _showingRecentMatches) {
                      // swipe left: go to Database
                      setState(() => _showingRecentMatches = false);
                      if (foodList.isEmpty)
                        handleApiCall(searchController.text);
                    } else if (dx > 200 && !_showingRecentMatches) {
                      // swipe right: go to Recent
                      setState(() => _showingRecentMatches = true);
                    }
                  },
                  child: Column(
                    children: [
                      // recent matches tab
                      if (_showingRecentMatches &&
                          _recentMatches.isNotEmpty) ...[
                        for (int i = 0; i < _recentMatches.length; i++) ...[
                          _buildFoodRow(
                            _recentMatches[i],
                            onTap: () {
                              FocusScope.of(context).unfocus();
                              _showServingDialog(
                                _recentMatches[i],
                                achievementId: 'food_recent',
                              );
                            },
                          ),
                          if (i < _recentMatches.length - 1)
                            Container(height: 1, color: c.onCard.withAlpha(40)),
                        ],
                        _buildEndOfResults(),
                      ],
                      // database results tab
                      if (!_showingRecentMatches && foodList.isNotEmpty) ...[
                        for (int i = 0; i < foodList.length; i++) ...[
                          _buildFoodRow(
                            foodList[i] as Map<String, dynamic>,
                            onTap: () {
                              FocusScope.of(context).unfocus();
                              _showServingDialog(
                                foodList[i] as Map<String, dynamic>,
                                achievementId: 'food_search',
                              );
                            },
                          ),
                          if (i < foodList.length - 1)
                            Container(height: 1, color: c.onCard.withAlpha(40)),
                        ],
                        _buildEndOfResults(),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: Responsive.height(context, 12)),
              ],

              // Plain API results when there were no recent matches at all (no tab switcher shown)
              if (foodList.isNotEmpty &&
                  _recentMatches.isEmpty &&
                  !_isSearching &&
                  selectedFood == null) ...[
                for (int i = 0; i < foodList.length; i++) ...[
                  _buildFoodRow(
                    foodList[i] as Map<String, dynamic>,
                    onTap: () {
                      FocusScope.of(context).unfocus();
                      _showServingDialog(
                        foodList[i] as Map<String, dynamic>,
                        achievementId: 'food_search',
                      );
                    },
                  ),
                  if (i < foodList.length - 1)
                    Container(height: 1, color: c.onCard.withAlpha(40)),
                ],
                _buildEndOfResults(),
                SizedBox(height: Responsive.height(context, 12)),
              ],

              // Recent foods as a frosted card that fills the remaining space
              if (showSections)
                frostedGlassCard(
                  context,
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.width(context, 16),
                    vertical: Responsive.height(context, 14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          final next = !_recentExpanded;
                          setState(() => _recentExpanded = next);
                          _saveRecentExpanded(next);
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                HugeIcon(
                                  icon: HugeIcons.strokeRoundedClock01,
                                  color: accent,
                                  size: Responsive.scale(context, 14),
                                ),
                                SizedBox(width: Responsive.width(context, 5)),
                                Text(
                                  "RECENT",
                                  style: GoogleFonts.manrope(
                                    fontSize: Responsive.font(context, 13),
                                    fontWeight: FontWeight.w700,
                                    color: accent,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                            AnimatedRotation(
                              turns: _recentExpanded ? 0 : -0.5,
                              duration: const Duration(milliseconds: 200),
                              child: HugeIcon(
                                icon: HugeIcons.strokeRoundedArrowDown01,
                                color: dim,
                                size: Responsive.scale(context, 18),
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: _recentExpanded
                            ? Column(
                                children: [
                                  SizedBox(
                                    height: Responsive.height(context, 10),
                                  ),
                                  if (_recentFoods.isEmpty)
                                    Text(
                                      "Nothing logged recently",
                                      style: GoogleFonts.manrope(
                                        fontSize: Responsive.font(context, 13),
                                        color: c.onCard.withAlpha(100),
                                      ),
                                    )
                                  else
                                    ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxHeight:
                                            MediaQuery.of(context).size.height *
                                            0.42,
                                      ),
                                      child: SingleChildScrollView(
                                        child: Column(
                                          children: List.generate(
                                            _recentFoods.length,
                                            (i) {
                                              final food = _recentFoods[i];
                                              return Column(
                                                children: [
                                                  _buildFoodRow(
                                                    food,
                                                    onTap: () =>
                                                        _showServingDialog(
                                                          food,
                                                          achievementId:
                                                              'food_recent',
                                                        ),
                                                  ),
                                                  if (i <
                                                      _recentFoods.length - 1)
                                                    Container(
                                                      height: 1,
                                                      color: c.onCard.withAlpha(
                                                        40,
                                                      ),
                                                    ),
                                                ],
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
