import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/providers/user_data_provider.dart';
import '../providers/food_logs_provider.dart';
import '../models/food_log.dart';
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
import '../services/voice_search_service.dart';
import '../utility/food_logging_helper.dart';
import '../utility/shared_preferences/shared_prefs_async.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:flutter_animate/flutter_animate.dart' hide ShimmerEffect;

class LogFoodScreen extends ConsumerStatefulWidget {
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
  ConsumerState<LogFoodScreen> createState() => _LogFoodScreenState();

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

class _LogFoodScreenState extends ConsumerState<LogFoodScreen>
    with TickerProviderStateMixin {
  Color get appColor => ref.watch(
    userDataProvider.select((s) => s.value?.appColor ?? defaultAppColor),
  );

  bool snackbarActive = false;
  bool isLogging = false;
  String latestQuery = "";
  Timer? checkTimer;
  List<dynamic> foodList = [];

  // Barcode scanner state
  bool scannerActive = false;
  bool barcodeLoading = false;
  String? barcodeError;

  // Recent foods section visibility
  bool _recentExpanded = true;
  final _prefs = SharedPrefsService();

  // Recent food matches shown when a search query matches something in recent foods
  List<FoodLog> _recentMatches = [];
  bool _showingRecentMatches = true;
  bool _isSearching = false;
  bool _showSearchHint = false;
  Timer? _searchHintTimer;

  static const List<String> allowedUnits = [
    'g',
    'oz',
    'cup',
    'tbsp',
    'ml',
    'serving',
  ];

  final TextEditingController searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _customUnitController = TextEditingController();
  final TextEditingController manualNameController = TextEditingController();
  final TextEditingController manualCaloriesController =
      TextEditingController();
  final TextEditingController manualFatController = TextEditingController();
  final TextEditingController manualCarbsController = TextEditingController();
  final TextEditingController manualProteinController = TextEditingController();
  final TextEditingController manualFiberController = TextEditingController();
  final TextEditingController manualSugarController = TextEditingController();
  final TextEditingController manualSodiumController = TextEditingController();
  final TextEditingController manualServingAmountController =
      TextEditingController();
  final TextEditingController _recentServingController =
      TextEditingController();
  String manualSelectedUnit = 'serving';

  // Voice search
  final VoiceSearchService _voiceSearch = VoiceSearchService();

  // Recent foods
  List<FoodLog> _recentFoods = [];
  bool _recentLoading = true;

  // Suggested foods: top foods by log frequency in the past 7 days
  List<FoodLog> _suggestedFoods = [];
  bool _suggestedLoading = true;
  bool _showingSuggested = false;

  @override
  void initState() {
    super.initState();
    FirebaseAnalytics.instance.logScreenView(
      screenName: '/food-logging/log',
      screenClass: 'LogFoodScreen',
    );
    _loadRecentFoods();
    _loadSuggestedFoods();
    _loadRecentExpanded();
    _voiceSearch.init(() {
      if (mounted) setState(() {});
    });
  }

  // Instantly filters recent foods, then schedules a debounced API call if no recent matches
  void _filterRecents(String value) {
    if (isGuest) {
      Guest.block(
        context,
        title: 'Sign up to log food',
        description:
            'Create a free account to track calories, macros, and build your nutrition history.',
      );
      return;
    }

    final query = value.toLowerCase().trim();

    if (query.isEmpty) {
      _searchHintTimer?.cancel();
      if (_showSearchHint) setState(() => _showSearchHint = false);
      setState(() {
        _recentMatches = [];
        foodList = [];
        _isSearching = false;
      });
      return;
    }

    final matches = _recentFoods.where((f) {
      final name = f.foodName.toLowerCase();
      final brand = (f.brandName ?? '').toLowerCase();
      return name.contains(query) || brand.contains(query);
    }).toList();

    setState(() {
      _recentMatches = matches;
      _showingRecentMatches = matches.isNotEmpty;
      if (matches.isNotEmpty) foodList = [];
    });

    if (matches.isNotEmpty) checkTimer?.cancel();

    // restart the hint timer on every keystroke
    _searchHintTimer?.cancel();
    if (_showSearchHint) setState(() => _showSearchHint = false);
    _searchHintTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_isSearching) {
        setState(() => _showSearchHint = true);
      }
    });
  }

  // Toggles the microphone for voice input on the search bar
  Future<void> _toggleListening() async {
    if (isGuest) {
      Guest.block(
        context,
        title: 'Sign up to log food',
        description:
            'Create a free account to track calories, macros, and build your nutrition history.',
      );
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
    _searchHintTimer?.cancel();
    _voiceSearch.cancel();
    searchController.dispose();
    _customUnitController.dispose();
    manualNameController.dispose();
    manualCaloriesController.dispose();
    manualFatController.dispose();
    manualCarbsController.dispose();
    manualProteinController.dispose();
    manualFiberController.dispose();
    manualSugarController.dispose();
    manualSodiumController.dispose();
    manualServingAmountController.dispose();
    _recentServingController.dispose();
    _searchFocusNode.unfocus();
    _searchFocusNode.dispose();
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
                Expanded(child: Text(message, softWrap: true)),
              ],
            ),
            duration: duration,
          ),
        )
        .closed
        .then((_) => snackbarActive = false);
  }

  // Fetches suggested foods from the server: meal-slot match, recency-weighted frequency
  Future<void> _loadSuggestedFoods() async {
    if (isGuest) {
      if (mounted) setState(() => _suggestedLoading = false);
      return;
    }
    try {
      final response = await authenticatedGet(
        'suggested_foods?meal=${widget.meal}',
      );
      if (!mounted) return;
      final List data = response.statusCode == 200
          ? jsonDecode(response.body)['food_logs_v2']
          : [];
      setState(() {
        _suggestedFoods = data
            .map((e) => FoodLog.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _suggestedLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _suggestedLoading = false);
    }
  }

  // Fetches recent foods from the server: deduped by name, most recent first, capped by premium status
  Future<void> _loadRecentFoods() async {
    if (isGuest) {
      if (mounted) setState(() => _recentLoading = false);
      return;
    }
    try {
      final response = await authenticatedGet('recent_foods');
      if (!mounted) return;
      final List data = response.statusCode == 200
          ? jsonDecode(response.body)['food_logs_v2']
          : [];
      setState(() {
        _recentFoods = data
            .map((e) => FoodLog.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _recentLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _recentLoading = false);
    }
  }

  Future<void> _loadRecentExpanded() async {
    final val = await _prefs.getBool(SharedPreferencesKey.recentFoodsExpanded);
    if (mounted && val != null) setState(() => _recentExpanded = val);
  }

  void _saveRecentExpanded(bool val) {
    _prefs.setBool(SharedPreferencesKey.recentFoodsExpanded, val);
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
        final results = foods?['food'] != null
            ? List<dynamic>.from(foods['food'])
            : [];
        if (results.isEmpty) {
          _showSnackbar(
            "No results found for \"$query\".",
            duration: const Duration(seconds: 2),
          );
        }
        setState(() {
          _isSearching = false;
          foodList = results;
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
          trackTrivialAchievement('food_barcode');
          setState(() {
            barcodeLoading = false;
            scannerActive = false;
          });
          final food = FoodLog(
            date: FoodLoggingHelper.formatDateKey(widget.currentDate),
            meal: widget.meal,
            foodName: data['product']['product_name'] ?? 'Unknown Product',
            brandName: data['product']['brands'] as String?,
            foodDescription: description,
          );
          await _showServingDialog(food, achievementId: 'food_barcode');
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

  // Logs the food to the correct meal then notifies the parent. Returns true on success.
  Future<bool> logFood(FoodLog foodObject) async {
    if (isLogging) {
      _showSnackbar("Please wait before logging again.");
      return false;
    }

    setState(() => isLogging = true);

    try {
      final dateKey = FoodLoggingHelper.formatDateKey(widget.currentDate);

      final newFood = FoodLog(
        date: dateKey,
        meal: widget.meal,
        foodName: foodObject.foodName,
        brandName: foodObject.brandName,
        foodDescription: foodObject.foodDescription,
        calories:
            foodObject.calories ??
            FoodLoggingHelper.extractCalories(foodObject.foodDescription ?? ''),
        protein: foodObject.protein,
        carbs: foodObject.carbs,
        fat: foodObject.fat,
        fiber: foodObject.fiber,
        sugar: foodObject.sugar,
        sodium: foodObject.sodium,
        servingSize: foodObject.servingSize,
      );

      final result = await ref
          .read(foodLogsProvider.notifier)
          .addFoodLog(dateKey, newFood);
      final success = result != null;
      if (!success && kDebugMode) debugPrint("Error saving food data");

      _loadRecentFoods();

      // Track which input method the user used to log this food
      if (widget.achievementId != null) {
        trackTrivialAchievement(widget.achievementId!);
      }

      // Award the full course meal badge if all four meals now have at least one food
      final updatedLogs = ref.read(foodLogsProvider).value ?? [];
      final todayLogs = updatedLogs.where((f) => f.date == dateKey).toList();
      final allMealsFilled = [
        'breakfast',
        'lunch',
        'dinner',
        'snacks',
      ].every((m) => todayLogs.any((f) => f.meal == m));
      if (allMealsFilled) trackTrivialAchievement("food_full_day");

      // time-based achievements based on the hour the food was logged
      final hour = DateTime.now().hour;
      if (hour >= 23) trackTrivialAchievement("night_owl"); // after 11pm
      if (hour < 8) trackTrivialAchievement("early_bird"); // before 8am

      widget.onFoodLogged();
      ref.read(userDataProvider.notifier).updateFoodLogStreak();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? "Food logged successfully."
                  : (isConnected
                        ? "Error saving food."
                        : "No connection. Please try again when online."),
            ),
            duration: snackBarDuration,
          ),
        );
      }
      return success;
    } finally {
      if (mounted) setState(() => isLogging = false);
    }
  }

  Future<void> _showManualEntrySheet() async {
    // Clear controllers each time the dialog opens
    manualNameController.clear();
    manualServingAmountController.clear();
    manualCaloriesController.clear();
    manualProteinController.clear();
    manualCarbsController.clear();
    manualFatController.clear();
    manualFiberController.clear();
    manualSugarController.clear();
    manualSodiumController.clear();
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
            color: onTheme(appColor),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.manrope(
              color: onTheme(appColor).withAlpha(100),
              fontSize: Responsive.font(ctx, 14),
            ),
            filled: true,
            fillColor: Colors.white.withAlpha(12),
            contentPadding: EdgeInsets.symmetric(
              horizontal: Responsive.width(ctx, 16),
              vertical: Responsive.height(ctx, 14),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Responsive.scale(ctx, 12)),
              borderSide: BorderSide(color: cardColors(appColor).border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Responsive.scale(ctx, 12)),
              borderSide: BorderSide(color: onTheme(appColor), width: 1.5),
            ),
          ),
        ),
      );
    }

    await showFrostedDialog(
      context: context,
      appColor: appColor,
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
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "REQUIRED",
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(ctx, 11),
                          color: Colors.white,
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
                              inputFormatters: [
                                LogFoodScreen.decimalFormatter(),
                              ],
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
                                    appColor: appColor,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Center(
                                          child: Text(
                                            "Unit",
                                            style: GoogleFonts.manrope(
                                              fontSize: Responsive.font(
                                                ctx,
                                                20,
                                              ),
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
                                                        fontSize:
                                                            Responsive.font(
                                                              ctx,
                                                              15,
                                                            ),
                                                        color:
                                                            manualSelectedUnit ==
                                                                u
                                                            ? Colors.white
                                                            : Colors.white,
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
                                          color: Colors.white.withAlpha(120),
                                          thickness: 1.5,
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
                                                color: Colors.white,
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
                                      appColor: appColor,
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
                                            color: Colors.white,
                                          ),
                                          enabledBorder: UnderlineInputBorder(
                                            borderSide: BorderSide(
                                              color: Colors.white,
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
                                          child: Text(
                                            "Cancel",
                                            style: GoogleFonts.manrope(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
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
                                                () =>
                                                    manualSelectedUnit = custom,
                                              );
                                            }
                                            Navigator.of(
                                              context,
                                              rootNavigator: true,
                                            ).pop();
                                          },
                                          child: Text(
                                            "OK",
                                            style: GoogleFonts.manrope(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                            ),
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
                                  padding: EdgeInsets.symmetric(
                                    horizontal: Responsive.width(ctx, 16),
                                    vertical: Responsive.height(ctx, 14),
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(12),
                                    borderRadius: BorderRadius.circular(
                                      Responsive.scale(ctx, 12),
                                    ),
                                    border: Border.all(
                                      color: cardColors(appColor).border,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          manualSelectedUnit,
                                          style: GoogleFonts.manrope(
                                            fontSize: Responsive.font(ctx, 14),
                                            color: onTheme(appColor),
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right,
                                        color: onTheme(appColor),
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
                          color: Colors.white,
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
                      goalField(
                        ctx,
                        manualFiberController,
                        "Fiber (g)",
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          LogFoodScreen.decimalFormatter(decimalPlaces: 3),
                        ],
                      ),
                      goalField(
                        ctx,
                        manualSugarController,
                        "Sugar (g)",
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          LogFoodScreen.decimalFormatter(decimalPlaces: 3),
                        ],
                      ),
                      goalField(
                        ctx,
                        manualSodiumController,
                        "Sodium (mg)",
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
                            color: Colors.white,
                            fontSize: Responsive.font(ctx, 13),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(height: Responsive.height(context, 24)),
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (final keep in [true, false])
                        TextButton(
                          onPressed: () async {
                            final name = manualNameController.text.trim();
                            if (name.isEmpty ||
                                manualCaloriesController.text.trim().isEmpty ||
                                manualServingAmountController.text
                                    .trim()
                                    .isEmpty) {
                              setDialogState(
                                () => dialogError =
                                    "Name, calories, and serving size are required.",
                              );
                              return;
                            }
                            final calories =
                                int.tryParse(
                                  manualCaloriesController.text.trim(),
                                ) ??
                                0;
                            final fat = manualFatController.text.trim();
                            final carbs = manualCarbsController.text.trim();
                            final protein = manualProteinController.text.trim();
                            if (fat.isEmpty &&
                                carbs.isEmpty &&
                                protein.isEmpty) {
                              showFrostedAlertDialog(
                                context: context,
                                appColor: appColor,
                                title: "No macronutrients entered!",
                                content: Text(
                                  "You haven't entered any fat, carbs, or protein. Log anyway?",
                                  style: GoogleFonts.manrope(
                                    color: Colors.white,
                                  ),
                                ),
                                actions: [
                                  // Dismiss alert only, manual entry dialog stays open
                                  TextButton(
                                    onPressed: () => Navigator.of(
                                      context,
                                      rootNavigator: true,
                                    ).pop(),
                                    child: Text(
                                      "Go Back",
                                      style: dialogButtonStyle(),
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
                                        manualFiberController.text.trim(),
                                        manualSugarController.text.trim(),
                                        manualSodiumController.text.trim(),
                                        keepLogging: keep,
                                      );
                                    },
                                    child: Text(
                                      "Log Anyway",
                                      style: dialogButtonStyle(confirm: true),
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
                              manualFiberController.text.trim(),
                              manualSugarController.text.trim(),
                              manualSodiumController.text.trim(),
                              keepLogging: keep,
                            );
                          },
                          child: Text(
                            keep ? "Log More" : "Log",
                            style: dialogButtonStyle(confirm: true),
                          ),
                        ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text("Cancel", style: dialogButtonStyle()),
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
    String fiber,
    String sugar,
    String sodium, {
    bool keepLogging = false,
  }) async {
    final servingAmt = manualServingAmountController.text.trim();
    final servingLabel = servingAmt.isNotEmpty
        ? '$servingAmt $manualSelectedUnit'
        : manualSelectedUnit;
    final parts = <String>['Calories: ${calories}kcal'];
    if (fat.isNotEmpty) parts.add('Fat: ${fat}g');
    if (carbs.isNotEmpty) parts.add('Carbs: ${carbs}g');
    if (protein.isNotEmpty) parts.add('Protein: ${protein}g');
    if (fiber.isNotEmpty) parts.add('Fiber: ${fiber}g');
    if (sugar.isNotEmpty) parts.add('Sugar: ${sugar}g');
    if (sodium.isNotEmpty) parts.add('Sodium: ${sodium}mg');

    trackTrivialAchievement('food_manual');
    await logFood(
      FoodLog(
        date: FoodLoggingHelper.formatDateKey(widget.currentDate),
        meal: widget.meal,
        foodName: name,
        foodDescription: 'Per $servingLabel - ${parts.join(' | ')}',
        calories: calories,
        protein: double.tryParse(protein),
        carbs: double.tryParse(carbs),
        fat: double.tryParse(fat),
        fiber: double.tryParse(fiber),
        sugar: double.tryParse(sugar),
        sodium: double.tryParse(sodium),
        servingSize: servingLabel,
      ),
    );
    if (!mounted) return;
    if (keepLogging) {
      _showManualEntrySheet();
    } else {
      context.pop();
    }
  }

  // Clears the selected food and resets back to the empty search state
  void _clearSelection() {
    setState(() {
      searchController.clear();
      foodList = [];
      _recentMatches = [];
      _showingRecentMatches = true;
      barcodeError = null;
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
          color: onTheme(appColor),
          decoration: TextDecoration.underline,
          decorationColor: onTheme(appColor),
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
            color: onTheme(appColor),
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
  Future<void> _showServingDialog(FoodLog food, {String? achievementId}) async {
    final serving = FoodLoggingHelper.parseServingFromLog(food);
    final baseAmt = serving['amount'] as double;

    _recentServingController.text = baseAmt % 1 == 0
        ? baseAmt.toInt().toString()
        : baseAmt.toString();

    final result = await showServingAmountDialog(
      context: context,
      food: food,
      controller: _recentServingController,
      confirmLabel: 'Log',
      appColor: appColor,
      showLogMore: true,
    );

    if (result == null || result.amt.isEmpty) return;
    final newAmt = double.tryParse(result.amt);
    if (newAmt == null || newAmt <= 0) return;

    final baseMacros = FoodLoggingHelper.extractMacrosFromFood(food);
    final unit = serving['unit'] as String;
    final scaled = result.macroOverrides != null
        ? {
            'calories':
                (result.macroOverrides!['calories'] ??
                        FoodLoggingHelper.scaleFood(
                          baseMacros,
                          baseAmt,
                          newAmt,
                        )['calories']!)
                    .toDouble(),
            'protein':
                result.macroOverrides!['protein'] ??
                FoodLoggingHelper.scaleFood(
                  baseMacros,
                  baseAmt,
                  newAmt,
                )['protein']!,
            'carbs':
                result.macroOverrides!['carbs'] ??
                FoodLoggingHelper.scaleFood(
                  baseMacros,
                  baseAmt,
                  newAmt,
                )['carbs']!,
            'fat':
                result.macroOverrides!['fat'] ??
                FoodLoggingHelper.scaleFood(
                  baseMacros,
                  baseAmt,
                  newAmt,
                )['fat']!,
          }
        : FoodLoggingHelper.scaleFood(baseMacros, baseAmt, newAmt);

    final loggedFood = FoodLog(
      foodName: food.foodName,
      brandName: food.brandName,
      foodDescription: FoodLoggingHelper.buildDescription(scaled, newAmt, unit),
      calories: scaled['calories']!.round(),
      protein: scaled['protein'],
      carbs: scaled['carbs'],
      fat: scaled['fat'],
      fiber: food.fiber,
      sugar: food.sugar,
      sodium: food.sodium,
      servingSize: '$newAmt $unit',
      date: food.date,
      meal: food.meal,
    );

    if (achievementId != null) trackTrivialAchievement(achievementId);
    await logFood(loggedFood);

    if (!mounted) return;
    if (result.keepLogging) {
      // Clear search and stay on screen so user can log another food
      setState(() {
        searchController.clear();
        foodList = [];
        _recentMatches = [];
        _isSearching = false;
        _showingRecentMatches = false;
      });
    } else {
      context.pop();
    }
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
              color: active ? onTheme(appColor) : Colors.transparent,
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
            color: active ? onTheme(appColor) : onTheme(appColor),
          ),
        ),
      ),
    );
  }

  // Macro info shown on the selected food card, updates live as serving changes

  // Macro summary line shown under each recent food tile

  // Full screen barcode scanner that dismisses on a successful scan or back tap
  Widget _buildBarcodeScanner() {
    return Container(
      decoration: BoxDecoration(gradient: buildThemeGradient(appColor)),
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
                  child: themedIconBox(
                    context,
                    icon: Icons.arrow_back_ios_new,
                    color: appColor,
                    iconSize: 13,
                    padding: 12,
                    circle: true,
                    onTap: () => setState(() => scannerActive = false),
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

  Widget _buildRecentSkeleton(BuildContext context, Color appColor) {
    return Skeletonizer(
      enabled: true,
      ignoreContainers: false,
      effect: ShimmerEffect(
        baseColor: cardColors(appColor).iconBox,
        highlightColor: cardColors(appColor).border,
        duration: const Duration(milliseconds: 1200),
      ),
      child: Column(
        children: List.generate(4, (i) {
          return Column(
            children: [
              Padding(
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
                        color: onTheme(appColor),
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
                              color: onTheme(appColor),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          SizedBox(height: Responsive.height(context, 5)),
                          Container(
                            height: Responsive.height(context, 11),
                            width: Responsive.width(context, 100),
                            decoration: BoxDecoration(
                              color: onTheme(appColor),
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
                        color: onTheme(appColor),
                      ),
                    ),
                  ],
                ),
              ),
              if (i < 3)
                Container(height: 1, color: onTheme(appColor).withAlpha(120)),
            ],
          );
        }),
      ),
    );
  }

  // A single search result or recent-match row, name bold, description dim, + button on right
  Widget _buildFoodRow(FoodLog food, {required VoidCallback onTap}) {
    return _FoodResultRow(food: food, onTap: onTap, appColor: appColor);
  }

  Widget _buildEndOfResults() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: Responsive.height(context, 12)),
      child: Center(
        child: Text(
          "End of results",
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 12),
            color: onTheme(appColor),
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
    final base = appColor;
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
          border: Border.all(color: c.border, width: 1.5),
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
                    themedIconBox(
                      context,
                      icon: icon,
                      color: base,
                      iconSize: 20,
                      padding: 10,
                      hugeIcon: true,
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
                              color: onTheme(base),
                            ),
                          ),
                          Text(
                            sublabel,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: Responsive.font(context, 11),
                              color: onTheme(base),
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

    final c = cardColors(appColor);
    final accent = onTheme(appColor);
    final dim = onTheme(appColor);
    final mealLabel = widget.meal[0].toUpperCase() + widget.meal.substring(1);

    // how many kcal already logged to this meal today

    // true when none of the active search/selection states are showing
    final showSections =
        foodList.isEmpty && !_isSearching && _recentMatches.isEmpty;

    return Container(
      decoration: BoxDecoration(gradient: buildThemeGradient(appColor)),
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
                    themedIconBox(
                      context,
                      icon: Icons.arrow_back_ios_new,
                      color: appColor,
                      iconSize: 13,
                      padding: 12,
                      circle: true,
                      onTap: () => context.pop(),
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
              TextField(
                controller: searchController,
                focusNode: _searchFocusNode,
                readOnly: isGuest,
                onTap: isGuest ? () => Guest.block(context) : null,
                keyboardType: TextInputType.text,
                style: GoogleFonts.manrope(
                  fontSize: Responsive.font(context, 15),
                  color: accent,
                ),
                decoration: InputDecoration(
                  hintText: "Search for a food...",
                  hintStyle: GoogleFonts.manrope(
                    fontSize: Responsive.font(context, 15),
                    color: c.onCard.withAlpha(100),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: c.onCard.withAlpha(120),
                    size: Responsive.font(context, 20),
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSize(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOut,
                        child: searchController.text.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  _searchHintTimer?.cancel();
                                  setState(() {
                                    _showingRecentMatches = false;
                                    _showSearchHint = false;
                                  });
                                  handleApiCall(searchController.text);
                                },
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: Responsive.width(context, 10),
                                    vertical: Responsive.height(context, 8),
                                  ),
                                  child: _showSearchHint
                                      ? Text(
                                              'Search',
                                              style: GoogleFonts.manrope(
                                                color: accent,
                                                fontSize: Responsive.font(
                                                  context,
                                                  13,
                                                ),
                                                fontWeight: FontWeight.w700,
                                              ),
                                            )
                                            .animate(onPlay: (c) => c.repeat())
                                            .shimmer(
                                              duration: 2000.ms,
                                              color:
                                                  accent.computeLuminance() >
                                                      0.5
                                                  ? darkenColor(
                                                      accent,
                                                      0.35,
                                                    ).withAlpha(200)
                                                  : lightenColor(
                                                      accent,
                                                      0.4,
                                                    ).withAlpha(200),
                                            )
                                      : Text(
                                          'Search',
                                          style: GoogleFonts.manrope(
                                            color: accent,
                                            fontSize: Responsive.font(
                                              context,
                                              13,
                                            ),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                ),
                              )
                            : const SizedBox.shrink(),
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
                      AnimatedSize(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOut,
                        child: searchController.text.isNotEmpty
                            ? GestureDetector(
                                onTap: _clearSelection,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: Responsive.width(context, 8),
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    color: c.onCard,
                                    size: Responsive.font(context, 20),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                  filled: true,
                  fillColor: Colors.white.withAlpha(12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      Responsive.scale(context, 12),
                    ),
                    borderSide: BorderSide(
                      color: cardColors(appColor).iconBorder,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      Responsive.scale(context, 12),
                    ),
                    borderSide: BorderSide(
                      color: onTheme(appColor),
                      width: 1.5,
                    ),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    vertical: Responsive.height(context, 13),
                    horizontal: Responsive.width(context, 4),
                  ),
                ),
                onChanged: _filterRecents,
                onSubmitted: (v) {
                  _searchHintTimer?.cancel();
                  setState(() => _showSearchHint = false);
                  handleApiCall(v);
                },
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
                              Guest.block(
                                context,
                                title: 'Sign up to log food',
                                description:
                                    'Create a free account to track calories, macros, and build your nutrition history.',
                              );
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
                    color: c.onCard.withAlpha(160),
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
                    child: CircularProgressIndicator(color: onTheme(appColor)),
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
                        color: c.onCard,
                        size: Responsive.font(context, 14),
                      ),
                      SizedBox(width: Responsive.width(context, 8)),
                      Expanded(
                        child: Text(
                          barcodeError!,
                          style: GoogleFonts.manrope(
                            color: c.onCard,
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

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position:
                        Tween<Offset>(
                          begin: const Offset(0, 0.04),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(parent: anim, curve: Curves.easeOut),
                        ),
                    child: child,
                  ),
                ),
                child: _buildResultsSection(appColor, accent, dim),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsSection(Color appColor, Color accent, Color dim) {
    final c = cardColors(appColor);
    final showSections =
        foodList.isEmpty && !_isSearching && _recentMatches.isEmpty;
    final key = ValueKey(
      '${_isSearching}_${foodList.length}_${_recentMatches.length}',
    );
    return Column(
      key: key,
      children: [
        // Skeletonizer shown while the API search is in flight
        if (_isSearching)
          Skeletonizer(
            enabled: true,
            ignoreContainers: false,
            effect: ShimmerEffect(
              baseColor: cardColors(appColor).iconBox,
              highlightColor: cardColors(appColor).border,
              duration: const Duration(milliseconds: 1200),
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
                            SizedBox(height: Responsive.height(context, 5)),
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
            padding: EdgeInsets.only(bottom: Responsive.height(context, 10)),
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
                if (foodList.isEmpty) {
                  handleApiCall(searchController.text);
                }
              } else if (dx > 200 && !_showingRecentMatches) {
                // swipe right: go to Recent
                setState(() => _showingRecentMatches = true);
              }
            },
            child: Column(
              children: [
                // recent matches tab
                if (_showingRecentMatches && _recentMatches.isNotEmpty) ...[
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
                      Container(height: 1, color: c.onCard.withAlpha(120)),
                  ],
                  _buildEndOfResults(),
                ],
                // database results tab
                if (!_showingRecentMatches && foodList.isNotEmpty) ...[
                  for (int i = 0; i < foodList.length; i++) ...[
                    _buildFoodRow(
                      FoodLoggingHelper.foodLogFromApiMap(
                        foodList[i] as Map<String, dynamic>,
                        date: FoodLoggingHelper.formatDateKey(
                          widget.currentDate,
                        ),
                        meal: widget.meal,
                      ),
                      onTap: () {
                        FocusScope.of(context).unfocus();
                        _showServingDialog(
                          FoodLoggingHelper.foodLogFromApiMap(
                            foodList[i] as Map<String, dynamic>,
                            date: FoodLoggingHelper.formatDateKey(
                              widget.currentDate,
                            ),
                            meal: widget.meal,
                          ),
                          achievementId: 'food_search',
                        );
                      },
                    ),
                    if (i < foodList.length - 1)
                      Container(height: 1, color: c.onCard.withAlpha(120)),
                  ],
                  _buildEndOfResults(),
                ],
              ],
            ),
          ),
          SizedBox(height: Responsive.height(context, 12)),
        ],

        // Plain API results when there were no recent matches at all (no tab switcher shown)
        if (foodList.isNotEmpty && _recentMatches.isEmpty && !_isSearching) ...[
          for (int i = 0; i < foodList.length; i++) ...[
            _buildFoodRow(
              FoodLoggingHelper.foodLogFromApiMap(
                foodList[i] as Map<String, dynamic>,
                date: FoodLoggingHelper.formatDateKey(widget.currentDate),
                meal: widget.meal,
              ),
              onTap: () {
                FocusScope.of(context).unfocus();
                _showServingDialog(
                  FoodLoggingHelper.foodLogFromApiMap(
                    foodList[i] as Map<String, dynamic>,
                    date: FoodLoggingHelper.formatDateKey(widget.currentDate),
                    meal: widget.meal,
                  ),
                  achievementId: 'food_search',
                );
              },
            ),
            if (i < foodList.length - 1)
              Container(height: 1, color: c.onCard.withAlpha(120)),
          ],
          _buildEndOfResults(),
          SizedBox(height: Responsive.height(context, 12)),
        ],

        // Recent foods as a frosted card that fills the remaining space
        if (showSections)
          frostedGlassCard(
            context,
            color: appColor,
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.width(context, 16),
              vertical: Responsive.height(context, 14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize
                              .min, // shrink to content so Center works
                          children: [
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _showingSuggested = false),
                              child: Row(
                                children: [
                                  HugeIcon(
                                    icon: HugeIcons.strokeRoundedClock01,
                                    color: !_showingSuggested ? accent : dim,
                                    size: Responsive.scale(context, 14),
                                  ),
                                  SizedBox(width: Responsive.width(context, 5)),
                                  Text(
                                    "RECENT",
                                    style: GoogleFonts.manrope(
                                      fontSize: Responsive.font(context, 13),
                                      fontWeight: FontWeight.w700,
                                      color: !_showingSuggested ? accent : dim,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: Responsive.width(context, 16)),
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _showingSuggested = true),
                              child: Row(
                                children: [
                                  HugeIcon(
                                    icon: HugeIcons.strokeRoundedSparkles,
                                    color: _showingSuggested ? accent : dim,
                                    size: Responsive.scale(context, 14),
                                  ),
                                  SizedBox(width: Responsive.width(context, 5)),
                                  Text(
                                    "SUGGESTED",
                                    style: GoogleFonts.manrope(
                                      fontSize: Responsive.font(context, 13),
                                      fontWeight: FontWeight.w700,
                                      color: _showingSuggested ? accent : dim,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        final next = !_recentExpanded;
                        setState(() => _recentExpanded = next);
                        _saveRecentExpanded(next);
                      },
                      child: AnimatedRotation(
                        turns: _recentExpanded ? 0 : -0.5,
                        duration: const Duration(milliseconds: 200),
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedArrowDown01,
                          color: dim,
                          size: Responsive.scale(context, 18),
                        ),
                      ),
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: _recentExpanded
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: Responsive.height(context, 10)),
                            if (_showingSuggested) ...[
                              if (_suggestedLoading)
                                _buildRecentSkeleton(context, appColor)
                              else if (_suggestedFoods.isEmpty)
                                Text(
                                  "Nothing suggested, try logging more foods first",
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
                                        0.30,
                                  ),
                                  child: SingleChildScrollView(
                                    child: Column(
                                      children: List.generate(
                                        _suggestedFoods.length,
                                        (i) {
                                          final food = _suggestedFoods[i];
                                          return Column(
                                            children: [
                                              _buildFoodRow(
                                                food,
                                                onTap: () =>
                                                    _showServingDialog(food),
                                              ),
                                              if (i <
                                                  _suggestedFoods.length - 1)
                                                Container(
                                                  height: 1,
                                                  color: c.onCard.withAlpha(
                                                    120,
                                                  ),
                                                ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                            ] else if (_recentLoading)
                              _buildRecentSkeleton(context, appColor)
                            else if (_recentFoods.isEmpty)
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
                                      MediaQuery.of(context).size.height * 0.30,
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
                                              onTap: () => _showServingDialog(
                                                food,
                                                achievementId: 'food_recent',
                                              ),
                                            ),
                                            if (i < _recentFoods.length - 1)
                                              Container(
                                                height: 1,
                                                color: c.onCard.withAlpha(120),
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
    );
  }
}

class _FoodResultRow extends ConsumerStatefulWidget {
  final FoodLog food;
  final VoidCallback onTap;
  final Color appColor;
  const _FoodResultRow({
    required this.food,
    required this.onTap,
    required this.appColor,
  });

  @override
  ConsumerState<_FoodResultRow> createState() => _FoodResultRowState();
}

class _FoodResultRowState extends ConsumerState<_FoodResultRow> {
  bool _loadingMicros = false;
  double? _fiber;
  double? _sugar;
  double? _sodium;
  bool _microsLoaded = false;

  Future<void> _loadMicros() async {
    final foodId = widget.food.foodId;
    if (foodId == null || _loadingMicros || _microsLoaded) return;
    setState(() => _loadingMicros = true);
    try {
      final response = await authenticatedPost(
        'food_detail',
        body: {'food_id': foodId},
        timeout: const Duration(seconds: 9),
      );
      if (response.statusCode == 200) {
        final detail = jsonDecode(response.body);
        final food = detail['food'];
        final servings = food?['servings']?['serving'];
        Map<String, dynamic>? serving;
        if (servings is List) {
          serving = (servings.first as Map<String, dynamic>);
        } else if (servings is Map) {
          serving = servings.cast<String, dynamic>();
        }
        if (serving != null && mounted) {
          setState(() {
            _fiber = double.tryParse(serving!['fiber']?.toString() ?? '');
            _sugar = double.tryParse(serving['sugar']?.toString() ?? '');
            _sodium = double.tryParse(serving['sodium']?.toString() ?? '');
            _microsLoaded = true;
          });
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingMicros = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColor = widget.appColor;
    final food = widget.food;
    final cal =
        food.calories ??
        FoodLoggingHelper.extractCalories(food.foodDescription ?? '');
    final serving = FoodLoggingHelper.parseServingFromLog(food);
    final servingAmt = serving['amount'] as double;
    final servingStr = servingAmt % 1 == 0
        ? servingAmt.toInt().toString()
        : servingAmt.toString();
    final subtitle = '$servingStr ${serving['unit']} · $cal calories';
    final macros = FoodLoggingHelper.extractMacrosFromFood(food);
    final hasMacros =
        (macros['protein'] ?? 0) > 0 ||
        (macros['carbs'] ?? 0) > 0 ||
        (macros['fat'] ?? 0) > 0;
    final hasMicros =
        _microsLoaded && (_fiber != null || _sugar != null || _sodium != null);
    final dim = onTheme(appColor);

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: Responsive.height(context, 13)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food.foodName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: Responsive.font(context, 14),
                      fontWeight: FontWeight.w600,
                      color: onTheme(appColor),
                    ),
                  ),
                  Text(
                    food.brandName != null
                        ? '${food.brandName} · $subtitle'
                        : subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: Responsive.font(context, 12),
                      color: onTheme(appColor),
                    ),
                  ),
                  if (hasMacros)
                    Text(
                      'Protein ${macros['protein']!.toStringAsFixed(1)}g · Carbs ${macros['carbs']!.toStringAsFixed(1)}g · Fat ${macros['fat']!.toStringAsFixed(1)}g',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: Responsive.font(context, 11),
                        color: onTheme(appColor),
                      ),
                    ),
                  if (hasMicros)
                    Padding(
                      padding: EdgeInsets.only(
                        top: Responsive.height(context, 3),
                      ),
                      child: Text(
                        [
                          if (_fiber != null)
                            'Fiber ${_fiber!.toStringAsFixed(1)}g',
                          if (_sugar != null)
                            'Sugar ${_sugar!.toStringAsFixed(1)}g',
                          if (_sodium != null)
                            'Na ${_sodium!.toStringAsFixed(0)}mg',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 11),
                          color: onTheme(appColor),
                        ),
                      ),
                    ),
                  if (food.foodId != null && !_microsLoaded)
                    GestureDetector(
                      onTap: _loadMicros,
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: Responsive.height(context, 5),
                        ),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: Responsive.width(context, 8),
                            vertical: Responsive.height(context, 4),
                          ),
                          decoration: BoxDecoration(
                            color: dim.withAlpha(20),
                            borderRadius: BorderRadius.circular(
                              Responsive.scale(context, 20),
                            ),
                            border: Border.all(
                              color: dim.withAlpha(60),
                              width: 1,
                            ),
                          ),
                          child: _loadingMicros
                              ? SizedBox(
                                  width: Responsive.scale(context, 11),
                                  height: Responsive.scale(context, 11),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: dim,
                                  ),
                                )
                              : Text(
                                  'Preview Micros',
                                  style: GoogleFonts.manrope(
                                    fontSize: Responsive.font(context, 11),
                                    fontWeight: FontWeight.w600,
                                    color: dim,
                                  ),
                                ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: cardColors(appColor).iconBorder,
              size: Responsive.scale(context, 20),
            ),
          ],
        ),
      ),
    );
  }
}
