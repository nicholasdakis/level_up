import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:async';
import 'dart:ui';
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
}

class _LogFoodScreenState extends State<LogFoodScreen>
    with SingleTickerProviderStateMixin {
  String? _inlineError;
  String? _manualInlineError;
  Map<String, dynamic>? selectedFood;
  bool userCanType = true;
  bool snackbarActive = false;
  bool isLogging = false;
  String latestQuery = "";
  Timer? checkTimer;
  DateTime? lastInput;
  List<dynamic> foodList = [];
  String selectedUnit = 'g';
  double baseAmount = 1.0;
  Map<String, double> baseMacros = {};
  String displayDescription = '';

  // Barcode scanner state
  bool scannerActive = false;
  bool barcodeLoading = false;
  String? barcodeError;

  // Manual entry form visibility
  bool manualExpanded = true;

  // Recent foods section visibility
  bool _recentExpanded = true;
  final _prefs = SharedPrefsService();

  // Recent food matches shown when a search query matches something in recent foods
  List<Map<String, dynamic>> _recentMatches = [];
  bool _showingRecentMatches = true;

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

  @override
  void initState() {
    super.initState();
    _loadRecentFoods();
    _loadRecentExpanded();
    _voiceSearch.init(() {
      if (mounted) setState(() {});
    });
  }

  // Instantly filters recent foods, then schedules a debounced API call if no recent matches
  void _scheduleSearch(String value) {
    if (isGuest) {
      Guest.block(context);
      return;
    } // For guest users

    final query = value.toLowerCase().trim();

    if (query.isEmpty) {
      setState(() {
        _recentMatches = [];
        foodList = [];
      });
      checkTimer?.cancel();
      return;
    }

    final matches = _recentFoods.where((f) {
      final name = (f['food_name'] as String? ?? '').toLowerCase();
      return name.contains(query);
    }).toList();

    if (matches.isNotEmpty) {
      checkTimer?.cancel();
      setState(() {
        _recentMatches = matches;
        _showingRecentMatches = true;
        foodList = [];
      });
    } else {
      setState(() => _recentMatches = []);
      lastInput = DateTime.now();
      checkTimer?.cancel();
      checkTimer = Timer(
        const Duration(milliseconds: 750),
        () => handleApiCall(lastInput, value),
      );
    }
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
      // Call the search after the user finishes speaking
      _scheduleSearch(text);
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
    super.dispose();
  }

  // Allows up to 5 digits with an optional decimal up to decimalPlaces places
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
    final recents = await _recentFoodsService.getRecentFoods();
    if (mounted) setState(() => _recentFoods = recents);
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
  void handleApiCall(DateTime? dateTime, String query) async {
    if (query.isEmpty) return;
    query = query.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    latestQuery = query;

    try {
      final response = await UserDataManager.searchFood(query);
      if (response.statusCode == 200) {
        if (latestQuery != query) return;
        final foods = jsonDecode(response.body)['foods'];
        FocusScope.of(context).unfocus();
        setState(() {
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
        setState(() => foodList = []);
      } else {
        setState(() => foodList = []);
      }
    } catch (error) {
      if (kDebugMode) debugPrint("API call error: $error");
      setState(() => foodList = []);
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

    widget.onFoodLogged();
    if (mounted) context.pop();
  }

  // Validates the manual form and formats it like the other food types
  Future<void> handleManualEntry() async {
    final name = manualNameController.text.trim();
    if (name.isEmpty ||
        manualCaloriesController.text.trim().isEmpty ||
        manualServingAmountController.text.trim().isEmpty ||
        manualSelectedUnit.isEmpty) {
      setState(
        () => _manualInlineError =
            "Food name, calories, and serving size are required.",
      );
      return;
    }

    final calories = int.tryParse(manualCaloriesController.text.trim()) ?? 0;
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Go Back",
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _submitManualEntry(name, calories, fat, carbs, protein);
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
    await _submitManualEntry(name, calories, fat, carbs, protein);
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
          color: Colors.white24,
          decoration: TextDecoration.underline,
          decorationColor: Colors.white24,
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
          "https://www.fatsecret.com",
          "Powered by FatSecret",
        ),
        Text(
          "  ·  ",
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 11),
            color: Colors.white24,
          ),
        ),
        _buildAttributionLink(
          "https://openfoodfacts.org",
          "Powered by Open Food Facts",
        ),
      ],
    );
  }

  // Thin horizontal rule used to visually separate sections
  Widget _buildDivider() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: Responsive.height(context, 20)),
      child: Container(
        height: Responsive.height(context, 1),
        color: Colors.white.withAlpha(18),
      ),
    );
  }

  // Shows a serving size dialog before logging a recent food so the user can adjust the amount
  Future<void> _logRecentWithServingPicker(Map<String, dynamic> food) async {
    final description = food['food_description'] as String? ?? '';
    final serving = FoodLoggingHelper.parseServing(description);
    final currentAmt = serving['amount'] as double;
    final unit = serving['unit'] as String;

    final controller = TextEditingController(
      text: currentAmt % 1 == 0
          ? currentAmt.toInt().toString()
          : currentAmt.toString(),
    );

    final newAmtStr = await showFrostedAlertDialog<String>(
      context: context,
      title: "Serving size",
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            food['food_name'] as String? ?? '',
            style: GoogleFonts.manrope(color: Colors.white70, fontSize: 13),
          ),
          SizedBox(height: Responsive.height(context, 12)),
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.manrope(color: Colors.white),
            decoration: InputDecoration(
              suffixText: unit,
              suffixStyle: GoogleFonts.manrope(color: Colors.white54),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white38),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text("Log", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
    controller.dispose();

    if (newAmtStr == null || newAmtStr.isEmpty) return;
    final newAmt = double.tryParse(newAmtStr);
    if (newAmt == null || newAmt <= 0) return;

    // Use the same scaling path as search/barcode: _initServing populates baseMacros
    // and logFood re-scales based on whatever the user typed
    _initServing(description);
    servingAmountController.text = newAmt % 1 == 0
        ? newAmt.toInt().toString()
        : newAmt.toString();

    trackTrivialAchievement('food_recent');
    await logFood(Map<String, dynamic>.from(food));
  }

  // Recent food tile which is a simple row with food name, macros, and a tap-to-log plus icon
  Widget _buildSourceTab(
    String label,
    bool active,
    Color appColor,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      splashColor: appColor.withAlpha(40),
      borderRadius: BorderRadius.circular(Responsive.scale(context, 20)),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.width(context, 10),
          vertical: Responsive.height(context, 4),
        ),
        decoration: BoxDecoration(
          color: active ? appColor.withAlpha(40) : Colors.transparent,
          border: Border.all(
            color: active ? appColor.withAlpha(160) : Colors.transparent,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(Responsive.scale(context, 20)),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            color: active ? lightenColor(appColor, 0.2) : Colors.white38,
            fontSize: Responsive.font(context, 11),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }

  Widget _buildRecentTile(Map<String, dynamic> food) {
    return InkWell(
      onTap: () => _logRecentWithServingPicker(food),
      splashColor: appColorNotifier.value.withAlpha(40),
      borderRadius: BorderRadius.circular(Responsive.scale(context, 12)),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: Responsive.height(context, 14),
          horizontal: Responsive.width(context, 4),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food['brand_name'] != null
                        ? '${food['brand_name']} · ${food['food_name'] ?? ''}'
                        : (food['food_name'] ?? ''),
                    style: GoogleFonts.manrope(
                      fontSize: Responsive.font(context, 14),
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: Responsive.height(context, 3)),
                  _buildMacroText(food),
                ],
              ),
            ),
            SizedBox(width: Responsive.width(context, 12)),
            GestureDetector(
              onTap: () async {
                final confirmed = await showFrostedAlertDialog<bool>(
                  context: context,
                  title: "Remove from recents?",
                  content: Text(
                    food['food_name'] ?? '',
                    style: GoogleFonts.manrope(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text("Remove", style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                );
                if (confirmed != true) return;
                await _recentFoodsService.removeRecentFood(food['food_name']);
                await _loadRecentFoods();
              },
              child: Padding(
                padding: EdgeInsets.only(right: Responsive.width(context, 8)),
                child: Icon(
                  Icons.delete_outline,
                  color: Colors.white24,
                  size: Responsive.scale(context, 18),
                ),
              ),
            ),
            Icon(
              Icons.add_circle_outline,
              color: Colors.white38,
              size: Responsive.scale(context, 20),
            ),
          ],
        ),
      ),
    );
  }

  // Serving size row shown once a food is selected
  Widget _buildServingRow() {
    return Row(
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
                  color: lightenColor(appColorNotifier.value, 0.3),
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
    );
  }

  Widget _buildLogFoodButton({VoidCallback? onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: frostedButton("Log Food", context, onPressed: onPressed ?? () {}),
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
            color: Colors.redAccent,
            size: Responsive.font(context, 14),
          ),
          SizedBox(width: Responsive.width(context, 6)),
          Expanded(
            child: Text(
              error,
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 13),
                color: Colors.redAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Shared underline text field used inside the manual entry form
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
          textSelectionTheme: const TextSelectionThemeData(
            cursorColor: Colors.white,
          ),
        ),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 15),
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
                color: lightenColor(appColorNotifier.value, 0.3),
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
              color: Colors.white38,
            ),
          ),
        ),
      ),
    );
  }

  // Macro summary line shown under each recent food tile
  Widget _buildMacroText(Map<String, dynamic> food) {
    final macros = FoodLoggingHelper.extractMacros(
      food['food_description'] as String? ?? '',
    );
    final serving = FoodLoggingHelper.parseServing(
      food['food_description'] as String? ?? '',
    );
    final servingAmt = serving['amount'] as double;
    final servingStr = servingAmt % 1 == 0
        ? servingAmt.toInt().toString()
        : servingAmt.toString();
    final cal = num.tryParse(food['calories'].toString()) ?? 0;
    final parts = <String>['$servingStr ${serving['unit']} - $cal kcal'];
    if ((macros['protein'] ?? 0) > 0) {
      parts.add('P: ${macros['protein']!.toStringAsFixed(1)}g');
    }
    if ((macros['carbs'] ?? 0) > 0) {
      parts.add('C: ${macros['carbs']!.toStringAsFixed(1)}g');
    }
    if ((macros['fat'] ?? 0) > 0) {
      parts.add('F: ${macros['fat']!.toStringAsFixed(1)}g');
    }
    return Text(
      parts.join(' - '),
      style: GoogleFonts.manrope(
        fontSize: Responsive.font(context, 11),
        color: Colors.white54,
      ),
    );
  }

  // Full screen barcode scanner that dismisses on a successful scan or back tap
  Widget _buildBarcodeScanner() {
    final appColor = appColorNotifier.value;
    return Container(
      decoration: BoxDecoration(gradient: buildThemeGradient()),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          scrolledUnderElevation: 0,
          backgroundColor: darkenColor(appColor, 0.025),
          centerTitle: true,
          toolbarHeight: Responsive.buttonHeight(context, 120),
          leading: GestureDetector(
            onTap: () => setState(() => scannerActive = false),
            child: Center(
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
          title: createTitle("Scan Barcode", context),
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(Responsive.height(context, 3)),
            child: Container(
              height: Responsive.height(context, 3),
              color: Colors.white.withAlpha(25),
            ),
          ),
        ),
        body: Column(
          children: [
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
              padding: EdgeInsets.only(bottom: Responsive.height(context, 20)),
              child: Center(
                child: _buildAttributionLink(
                  "https://openfoodfacts.org",
                  "Powered by Open Food Facts",
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (scannerActive) return _buildBarcodeScanner();

    final appColor = appColorNotifier.value;
    final mealLabel = widget.meal[0].toUpperCase() + widget.meal.substring(1);

    // Only show recent and manual sections when the user isn't mid-search
    final showSections =
        foodList.isEmpty && selectedFood == null && _recentMatches.isEmpty;

    return Container(
      decoration: BoxDecoration(gradient: buildThemeGradient()),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          scrolledUnderElevation: 0,
          backgroundColor: darkenColor(appColor, 0.025),
          centerTitle: true,
          toolbarHeight: Responsive.buttonHeight(context, 120),
          leading: GestureDetector(
            onTap: () => context.pop(),
            child: Center(
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
          title: createTitle("Log to $mealLabel", context),
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(Responsive.height(context, 3)),
            child: Container(
              height: Responsive.height(context, 3),
              color: Colors.white.withAlpha(25),
            ),
          ),
        ),
        body: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.width(context, 20),
            vertical: Responsive.height(context, 20),
          ),
          children: [
            // Search bar with mic and scan icons baked in
            frostedGlassCard(
              context,
              baseRadius: 16,
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.width(context, 14),
                vertical: Responsive.height(context, 6),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search,
                    color: Colors.white38,
                    size: Responsive.font(context, 22),
                  ),
                  SizedBox(width: Responsive.width(context, 10)),
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      readOnly: !userCanType || isGuest, // For guest users
                      onTap: isGuest ? () => Guest.block(context) : null,
                      keyboardType: TextInputType.text,
                      style: GoogleFonts.manrope(
                        fontSize: Responsive.font(context, 16),
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: "Search for a food...",
                        hintStyle: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 15),
                          color: Colors.white38,
                        ),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          vertical: Responsive.height(context, 10),
                          horizontal: Responsive.width(context, 4),
                        ),
                      ),
                      onChanged: _scheduleSearch,
                    ),
                  ),
                  SizedBox(width: Responsive.width(context, 4)),
                  if (selectedFood != null)
                    // Clear replaces all icons when a food is locked in
                    GestureDetector(
                      onTap: _clearSelection,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.width(context, 6),
                        ),
                        child: Icon(
                          Icons.close,
                          color: Colors.white38,
                          size: Responsive.font(context, 22),
                        ),
                      ),
                    )
                  else ...[
                    GestureDetector(
                      onTap: _toggleListening,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.width(context, 6),
                        ),
                        child: Icon(
                          _voiceSearch.isListening ? Icons.mic : Icons.mic_none,
                          color: _voiceSearch.isListening
                              ? Colors.redAccent
                              : Colors.white38,
                          size: Responsive.font(context, 22),
                        ),
                      ),
                    ),
                    // crop_free looks cleaner than qr_code_scanner for a scan hint
                    GestureDetector(
                      onTap: () {
                        // For guest users
                        if (isGuest) {
                          Guest.block(context);
                          return;
                        }
                        setState(() => scannerActive = true);
                      },
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: Responsive.width(context, 2),
                          right: Responsive.width(context, 4),
                        ),
                        child: Icon(
                          Icons.crop_free,
                          color: Colors.white38,
                          size: Responsive.font(context, 22),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            SizedBox(height: Responsive.height(context, 6)),

            // Legal attribution — tiny and unobtrusive below the search bar
            Center(child: _buildAttributionRow()),

            SizedBox(height: Responsive.height(context, 20)),

            // Barcode lookup spinner
            if (barcodeLoading)
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: Responsive.height(context, 24),
                  ),
                  child: CircularProgressIndicator(
                    color: lightenColor(appColor, 0.2),
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
                      color: Colors.redAccent,
                      size: Responsive.font(context, 14),
                    ),
                    SizedBox(width: Responsive.width(context, 8)),
                    Expanded(
                      child: Text(
                        barcodeError!,
                        style: GoogleFonts.manrope(
                          color: Colors.redAccent,
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
                          color: lightenColor(appColor, 0.3),
                          fontSize: Responsive.font(context, 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Selected food card that appears once the user taps a result
            if (selectedFood != null && foodList.isEmpty) ...[
              frostedGlassCard(
                context,
                baseRadius: 16,
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.width(context, 18),
                  vertical: Responsive.height(context, 16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedFood!['brand_name'] != null
                          ? '${selectedFood!['brand_name']} · ${selectedFood!['food_name'] ?? ''}'
                          : (selectedFood!['food_name'] ?? ''),
                      style: GoogleFonts.manrope(
                        fontSize: Responsive.font(context, 16),
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: Responsive.height(context, 6)),
                    Text(
                      displayDescription,
                      style: GoogleFonts.manrope(
                        fontSize: Responsive.font(context, 13),
                        color: Colors.white54,
                      ),
                    ),
                    SizedBox(height: Responsive.height(context, 14)),
                    _buildServingRow(),
                  ],
                ),
              ),
              SizedBox(height: Responsive.height(context, 14)),
              _buildInlineError(_inlineError),
              _buildLogFoodButton(
                onPressed: () async {
                  setState(() => _inlineError = null);
                  await logFood(Map<String, dynamic>.from(selectedFood!));
                },
              ),
              SizedBox(height: Responsive.height(context, 24)),
            ],

            // Recent foods that match the current search query
            if (_recentMatches.isNotEmpty ||
                (foodList.isNotEmpty && !_showingRecentMatches)) ...[
              Padding(
                padding: EdgeInsets.only(bottom: Responsive.height(context, 8)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSourceTab(
                      'Recent',
                      _showingRecentMatches,
                      appColor,
                      () {
                        setState(() {
                          _showingRecentMatches = true;
                          foodList = [];
                        });
                      },
                    ),
                    SizedBox(width: Responsive.width(context, 8)),
                    _buildSourceTab(
                      'Database',
                      !_showingRecentMatches,
                      appColor,
                      () {
                        setState(() => _showingRecentMatches = false);
                        lastInput = DateTime.now();
                        handleApiCall(lastInput, searchController.text);
                      },
                    ),
                  ],
                ),
              ),
              if (_showingRecentMatches)
                for (int i = 0; i < _recentMatches.length; i++) ...[
                  InkWell(
                    splashColor: appColor.withAlpha(60),
                    borderRadius: BorderRadius.circular(
                      Responsive.scale(context, 10),
                    ),
                    onTap: () {
                      FocusScope.of(context).unfocus();
                      _initServing(_recentMatches[i]['food_description'] ?? '');
                      setState(() {
                        userCanType = false;
                        selectedFood = _recentMatches[i];
                        searchController.text =
                            _recentMatches[i]['food_name'] ?? '';
                        _recentMatches = [];
                      });
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: Responsive.height(context, 12),
                        horizontal: Responsive.width(context, 4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _recentMatches[i]['brand_name'] != null
                                ? '${_recentMatches[i]['brand_name']} · ${_recentMatches[i]['food_name'] ?? ''}'
                                : (_recentMatches[i]['food_name'] ?? ''),
                            style: GoogleFonts.manrope(
                              color: Colors.white,
                              fontSize: Responsive.font(context, 14),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: Responsive.height(context, 4)),
                          Text(
                            _recentMatches[i]['food_description'] ?? '',
                            style: GoogleFonts.manrope(
                              color: Colors.white38,
                              fontSize: Responsive.font(context, 12),
                            ),
                          ),
                          SizedBox(height: Responsive.height(context, 12)),
                          Container(
                            height: 1,
                            color: Colors.white.withAlpha(12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              SizedBox(height: Responsive.height(context, 12)),
            ],

            // Search results from FatSecret API replaces sections while the user is searching
            if (foodList.isNotEmpty &&
                (!_showingRecentMatches || _recentMatches.isEmpty)) ...[
              ...foodList.map((food) {
                return InkWell(
                  splashColor: appColor.withAlpha(60),
                  borderRadius: BorderRadius.circular(
                    Responsive.scale(context, 10),
                  ),
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    _initServing(food['food_description'] ?? '');
                    setState(() {
                      userCanType = false;
                      selectedFood = food;
                      searchController.text = food['food_name'] ?? '';
                      foodList = [];
                    });
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: Responsive.height(context, 12),
                      horizontal: Responsive.width(context, 4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          food['brand_name'] != null
                              ? '${food['brand_name']} · ${food['food_name'] ?? ''}'
                              : (food['food_name'] ?? ''),
                          style: GoogleFonts.manrope(
                            color: Colors.white,
                            fontSize: Responsive.font(context, 14),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: Responsive.height(context, 4)),
                        Text(
                          food['food_description'] ?? '',
                          style: GoogleFonts.manrope(
                            color: Colors.white38,
                            fontSize: Responsive.font(context, 12),
                          ),
                        ),
                        SizedBox(height: Responsive.height(context, 12)),
                        Container(height: 1, color: Colors.white.withAlpha(12)),
                      ],
                    ),
                  ),
                );
              }),
              SizedBox(height: Responsive.height(context, 12)),
            ],

            // RECENT FOODS section
            if (showSections) ...[
              GestureDetector(
                onTap: () {
                  final next = !_recentExpanded;
                  setState(() => _recentExpanded = next);
                  _saveRecentExpanded(next);
                },
                child: Row(
                  children: [
                    Expanded(child: sectionHeader("RECENT", context)),
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: Responsive.height(context, 12),
                      ),
                      child: Icon(
                        _recentExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: Colors.white38,
                        size: Responsive.scale(context, 20),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState: _recentExpanded
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: _recentFoods.isEmpty
                    ? Padding(
                        padding: EdgeInsets.only(
                          left: Responsive.width(context, 4),
                          bottom: Responsive.height(context, 8),
                        ),
                        child: Text(
                          "Nothing logged recently",
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 13),
                            color: Colors.white24,
                          ),
                        ),
                      )
                    : Column(
                        children: List.generate(_recentFoods.length, (i) {
                          final food = _recentFoods[i];
                          return Column(
                            children: [
                              _buildRecentTile(food),
                              if (i < _recentFoods.length - 1)
                                Container(
                                  height: 1,
                                  color: Colors.white.withAlpha(12),
                                ),
                            ],
                          );
                        }),
                      ),
                secondChild: const SizedBox.shrink(),
              ),

              _buildDivider(),

              // ENTER MANUALLY section is collapsible
              GestureDetector(
                onTap: () => setState(() {
                  manualExpanded = !manualExpanded;
                  _manualInlineError = null;
                }),
                child: Row(
                  children: [
                    Expanded(child: sectionHeader("ENTER MANUALLY", context)),
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: Responsive.height(context, 12),
                      ),
                      child: Icon(
                        manualExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: Colors.white38,
                        size: Responsive.scale(context, 20),
                      ),
                    ),
                  ],
                ),
              ),

              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState: manualExpanded
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: Column(
                  children: [
                    SizedBox(height: Responsive.height(context, 14)),
                    frostedGlassCard(
                      context,
                      baseRadius: 16,
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
                              fontSize: Responsive.font(context, 11),
                              color: Colors.white38,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                            ),
                          ),
                          _buildManualField(manualNameController, "Food Name"),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                flex: 2,
                                child: _buildManualField(
                                  manualServingAmountController,
                                  "Serving Amount",
                                  keyboardType: TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  inputFormatters: [_decimalFormatter()],
                                ),
                              ),
                              SizedBox(width: Responsive.width(context, 12)),
                              Expanded(
                                flex: 1,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: Responsive.height(context, 4),
                                  ),
                                  child: GestureDetector(
                                    onTap: () async {
                                      final picked = await showModalBottomSheet<String>(
                                        context: context,
                                        backgroundColor: Colors.transparent,
                                        builder: (ctx) => ClipRRect(
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                top: Radius.circular(24),
                                              ),
                                          child: BackdropFilter(
                                            filter: ImageFilter.blur(
                                              sigmaX: 20,
                                              sigmaY: 20,
                                            ),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: darkenColor(
                                                  appColor,
                                                  0.025,
                                                ).withAlpha(200),
                                                borderRadius:
                                                    const BorderRadius.vertical(
                                                      top: Radius.circular(24),
                                                    ),
                                                border: Border(
                                                  top: BorderSide(
                                                    color: Colors.white
                                                        .withAlpha(25),
                                                    width: 3,
                                                  ),
                                                ),
                                              ),
                                              padding: EdgeInsets.fromLTRB(
                                                Responsive.width(ctx, 24),
                                                Responsive.height(ctx, 20),
                                                Responsive.width(ctx, 24),
                                                Responsive.height(ctx, 32),
                                              ),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    "UNIT",
                                                    style: GoogleFonts.manrope(
                                                      fontSize: Responsive.font(
                                                        ctx,
                                                        11,
                                                      ),
                                                      color: Colors.white38,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      letterSpacing: 1.1,
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    height: Responsive.height(
                                                      ctx,
                                                      12,
                                                    ),
                                                  ),
                                                  // Standard units
                                                  ...allowedUnits.map(
                                                    (u) => Material(
                                                      color: Colors.transparent,
                                                      child: InkWell(
                                                        onTap: () =>
                                                            Navigator.pop(
                                                              ctx,
                                                              u,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        child: Padding(
                                                          padding: EdgeInsets.symmetric(
                                                            vertical:
                                                                Responsive.height(
                                                                  ctx,
                                                                  12,
                                                                ),
                                                            horizontal:
                                                                Responsive.width(
                                                                  ctx,
                                                                  8,
                                                                ),
                                                          ),
                                                          child: Row(
                                                            children: [
                                                              Expanded(
                                                                child: Text(
                                                                  u,
                                                                  style: GoogleFonts.manrope(
                                                                    fontSize:
                                                                        Responsive.font(
                                                                          ctx,
                                                                          16,
                                                                        ),
                                                                    color:
                                                                        manualSelectedUnit ==
                                                                            u
                                                                        ? Colors
                                                                              .white
                                                                        : Colors
                                                                              .white60,
                                                                    fontWeight:
                                                                        manualSelectedUnit ==
                                                                            u
                                                                        ? FontWeight
                                                                              .w600
                                                                        : FontWeight
                                                                              .w400,
                                                                  ),
                                                                ),
                                                              ),
                                                              if (manualSelectedUnit ==
                                                                  u)
                                                                Icon(
                                                                  Icons.check,
                                                                  color: Colors
                                                                      .white,
                                                                  size:
                                                                      Responsive.scale(
                                                                        ctx,
                                                                        18,
                                                                      ),
                                                                ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  Divider(
                                                    color: Colors.white
                                                        .withAlpha(25),
                                                    thickness: 1,
                                                  ),
                                                  // Custom unit option
                                                  Material(
                                                    color: Colors.transparent,
                                                    child: InkWell(
                                                      onTap: () =>
                                                          Navigator.pop(
                                                            ctx,
                                                            '__custom__',
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                      child: Padding(
                                                        padding: EdgeInsets.symmetric(
                                                          vertical:
                                                              Responsive.height(
                                                                ctx,
                                                                12,
                                                              ),
                                                          horizontal:
                                                              Responsive.width(
                                                                ctx,
                                                                8,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          "Custom...",
                                                          style: GoogleFonts.manrope(
                                                            fontSize:
                                                                Responsive.font(
                                                                  ctx,
                                                                  16,
                                                                ),
                                                            color:
                                                                Colors.white38,
                                                          ),
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
                                      if (picked == '__custom__') {
                                        _customUnitController.clear();
                                        if (!mounted) return;
                                        showFrostedAlertDialog(
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
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: const Text(
                                                "Cancel",
                                                style: TextStyle(
                                                  color: Colors.white54,
                                                ),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                final custom =
                                                    _customUnitController.text
                                                        .trim();
                                                if (custom.isNotEmpty) {
                                                  setState(
                                                    () => manualSelectedUnit =
                                                        custom,
                                                  );
                                                }
                                                Navigator.pop(context);
                                              },
                                              child: const Text(
                                                "OK",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      } else if (picked != null) {
                                        setState(
                                          () => manualSelectedUnit = picked,
                                        );
                                      }
                                    },
                                    child: Container(
                                      padding: EdgeInsets.only(
                                        bottom: Responsive.height(context, 6),
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: lightenColor(appColor, 0.15),
                                            width: Responsive.scale(
                                              context,
                                              0.25,
                                            ),
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              manualSelectedUnit,
                                              style: GoogleFonts.manrope(
                                                fontSize: Responsive.font(
                                                  context,
                                                  14,
                                                ),
                                                color: Colors.white38,
                                              ),
                                            ),
                                          ),
                                          Icon(
                                            Icons.keyboard_arrow_down,
                                            color: Colors.white38,
                                            size: Responsive.scale(context, 16),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          _buildManualField(
                            manualCaloriesController,
                            "Calories (kcal)",
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              _decimalFormatter(decimalPlaces: 3),
                            ],
                          ),
                          SizedBox(height: Responsive.height(context, 14)),
                          Text(
                            "OPTIONAL",
                            style: GoogleFonts.manrope(
                              fontSize: Responsive.font(context, 11),
                              color: Colors.white38,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                            ),
                          ),
                          _buildManualField(
                            manualProteinController,
                            "Protein (g)",
                            keyboardType: TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              _decimalFormatter(decimalPlaces: 3),
                            ],
                          ),
                          _buildManualField(
                            manualCarbsController,
                            "Carbs (g)",
                            keyboardType: TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              _decimalFormatter(decimalPlaces: 3),
                            ],
                          ),
                          _buildManualField(
                            manualFatController,
                            "Fat (g)",
                            keyboardType: TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              _decimalFormatter(decimalPlaces: 3),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: Responsive.height(context, 14)),
                    _buildInlineError(_manualInlineError),
                    _buildLogFoodButton(
                      onPressed: () async {
                        setState(() => _manualInlineError = null);
                        await handleManualEntry();
                      },
                    ),
                    SizedBox(height: Responsive.height(context, 32)),
                  ],
                ),
                secondChild: const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
