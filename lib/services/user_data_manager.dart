import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../globals.dart';
import '../guest.dart';
import '../models/user_data.dart';
import '../utility/image_crop_handler.dart';
import 'profile_image_service.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

// Base URL for the backend hosted on Render. All backend requests go to this URL
const String backendBaseUrl = 'https://level-up-69vz.onrender.com';

// The default dark grey app color — used as a fallback when no color has been set
const Color defaultAppColor = Color.fromARGB(255, 45, 45, 45);

// Firebase Cloud Messaging VAPID key for web push notifications
const String fcmVapidKey =
    'BHOUN3IilK1CAEVwa3wGYU-2Ne801epRrf881PxACR6ZD064wMMrMNH89OCxWm4ArfE7Mc4GJhiZOcd0nbsGPQ0';

// Gets a fresh Firebase ID token, a JWT, to authenticate requests with the backend
// Firebase caches this automatically so it only re-fetches when close to expiry (1hr)
Future<String> getIdToken() async {
  final token = await FirebaseAuth.instance.currentUser?.getIdToken().timeout(
    Duration(seconds: 2),
  );
  if (token == null) throw Exception('User not logged in');
  return token;
}

// Sends an authenticated POST to a backend endpoint, automatically attaching the token as a Bearer header
Future<http.Response> authenticatedPost(
  String endpoint, {
  Map<String, dynamic> body = const {},
  Duration timeout = const Duration(seconds: 5),
}) async {
  final token = await getIdToken();
  return http
      .post(
        Uri.parse('$backendBaseUrl/$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      )
      .timeout(timeout);
}

// Sends an authenticated GET to a backend endpoint with the token as a Bearer header
Future<http.Response> authenticatedGet(
  String endpoint, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final token = await getIdToken();
  return http
      .get(
        Uri.parse('$backendBaseUrl/$endpoint'),
        headers: {'Authorization': 'Bearer $token'},
      )
      .timeout(timeout);
}

// Fires and forgets a trivial achievement increment to the backend
void trackTrivialAchievement(String achievementId) async {
  if (isGuest) return;
  try {
    await authenticatedPost(
      'claim_trivial_achievement',
      body: {'achievement_id': achievementId},
    );
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Failed to track trivial achievement $achievementId: $e');
    }
  }
}

// Online connectivity checker
bool isConnected = true;

// The method acts as a stream that checks if the user is connected so that it reflects the user's current connection state
void initConnectivity() {
  Connectivity().onConnectivityChanged.listen((statusList) {
    isConnected = !statusList.contains(ConnectivityResult.none);
  });
}

class UserDataManager {
  bool lastLoadFailed = false;

  // Formula for calculating experience needed for next level: 100 * 1.25^(current_level-0.5) * 1.05 + (current_level * 10), rounded to a multiple of 10
  // Kept here so the XP bar can render instantly
  int? get experienceNeeded {
    if (currentUserData == null) return null;
    int exp =
        (100 * pow(1.25, currentUserData!.level - 0.5) * 1.05 +
                (currentUserData!.level * 10))
            .round();
    // Round the experience formula to a multiple of 10
    return (exp / 10).round() * 10;
  }

  // Calculates total lifetime XP by summing the XP needed for each completed level plus current progress
  int? get totalXpEarned {
    if (currentUserData == null) return null;
    int total = 0;
    for (int level = 1; level < currentUserData!.level; level++) {
      int exp = (100 * pow(1.25, level - 0.5) * 1.05 + (level * 10)).round();
      total += (exp / 10).round() * 10;
    }
    return total + (currentUserData!.expPoints);
  }

  // Calls the backend /progress endpoint to get the user's level, XP, and reward status
  // Separated into its own method so it can be called on pull-to-refresh and the leaderboard
  static Future<Map<String, dynamic>> fetchProgress() async {
    final response = await authenticatedGet('progress');
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(
      'getProgress failed: ${response.statusCode} ${response.body}',
    );
  }

  // Returns the user's profile picture widget. Called when the user updates their profile picture
  Widget insertProfilePicture() {
    if (currentUserData?.pfpBase64 != null) {
      return Image.memory(
        base64Decode(currentUserData!.pfpBase64!),
        width: 40,
        height: 40,
        fit: BoxFit.cover,
      );
    } else {
      return const Icon(Icons.person, color: Colors.white, size: 40);
    }
  }

  Future<void> updateProfilePicture(
    File? file, {
    VoidCallback? onProfileUpdated,
    BuildContext? context, // for error snackbar
    Uint8List? imageInBytes, // web bytes
  }) async {
    // Step 1: Crop first
    if (kIsWeb) {
      final cropped = await ImageCropHelper.cropPicture(
        webBytes: imageInBytes,
        context: context!,
      );
      // User cancelled
      if (cropped == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Profile picture update cancelled."),
            duration: snackBarDuration,
          ),
        );
        return;
      }
      // Update the image to its cropped version
      imageInBytes = await ImageCropHelper.getBytes(cropped);
    } else {
      // Mobile
      final cropped = await ImageCropHelper.cropPicture(
        mobileFile: file,
        context: context!,
      );
      // User cancelled
      if (cropped == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Profile picture update cancelled."),
            duration: snackBarDuration,
          ),
        );
        return;
      }

      // Update the file to its cropped version
      file = File(cropped.path);
    }

    // Step 2: Check size and compress
    if (!await ProfileImageService.checkSize(
      file,
      context,
      isWeb: kIsWeb,
      webBytes: imageInBytes,
    )) {
      return;
    }

    String? base64String;

    try {
      if (kIsWeb) {
        // Web
        base64String = base64Encode(
          await ProfileImageService.compressWeb(imageInBytes!),
        );
      } else {
        // Mobile
        base64String = base64Encode(
          await ProfileImageService.compressMobile(file!),
        );
      }

      if (isGuest) {
        Guest.block(context);
        return;
      }

      // Send the Base64 string to the backend to store in Postgres
      final response = await authenticatedPost(
        'update_pfp',
        body: {'pfp_base64': base64String},
        timeout: Duration(seconds: 5),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'update_pfp failed: ${response.statusCode} ${response.body}',
        );
      }

      // Update currentUserData with the complete stored variables with the updated profile picture
      userDataNotifier.value = UserData(
        uid: currentUserData!.uid,
        pfpBase64: base64String,
        level: currentUserData!.level,
        expPoints: currentUserData!.expPoints,
        canClaimDailyReward: currentUserData!.canClaimDailyReward,
        notificationsEnabled: currentUserData!.notificationsEnabled,
        lastDailyClaim: currentUserData!.lastDailyClaim,
        username: currentUserData!.username,
        appColor: currentUserData!.appColor,
        fcmTokens: currentUserData!.fcmTokens,
      );
      // Confirmation snackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Profile picture successfully updated."),
          duration: snackBarDuration,
        ),
      );
      // Call callback when the UI must rebuild
      onProfileUpdated?.call();
    } catch (e) {
      // No connection so the update cannot be completed
      if (!isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("No connection. Please try again when online."),
            duration: snackBarDuration,
          ),
        );
        return;
      }

      String message;

      if (e is TimeoutException) {
        message = "Connection is slow. Please try again.";
      } else {
        message = "Profile picture update unsuccessful: $e";
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: snackBarDuration),
      );
    }
  }

  // Method for updating the user's notification preference and storing it
  Future<void> updateNotificationsEnabled(
    bool enabled,
    BuildContext context,
  ) async {
    if (isGuest) {
      Guest.block(context);
      return;
    }
    currentUserData!.notificationsEnabled = enabled;
    userDataNotifier.notifyListeners();
    try {
      final response = await authenticatedPost(
        'update_notifications',
        body: {'enabled': enabled},
      );

      if (response.statusCode != 200) {
        throw Exception(
          'update_notifications failed: ${response.statusCode} ${response.body}',
        );
      }

      // Default confirmation snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Notification preferences updated successfully."),
          duration: Duration(milliseconds: 500),
        ),
      );
    } catch (e) {
      // No connection so the update cannot be completed
      if (!isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("No connection. Please try again when online."),
            duration: snackBarDuration,
          ),
        );
        return;
      }

      String message;

      if (e is TimeoutException) {
        message = "Connection is slow. Please try again.";
      } else {
        message = "Error updating notification preferences.";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: snackBarDuration),
      );
    }
  }

  Future<bool> updateWaterLog(String dateKey, List<int> entriesMl) async {
    final previous = List<int>.from(
      currentUserData?.waterEntriesByDate[dateKey] ?? [],
    );
    currentUserData?.waterEntriesByDate[dateKey] = entriesMl;
    userDataNotifier.notifyListeners();
    try {
      await authenticatedPost(
        'upsert_water_log',
        body: {
          'date': dateKey,
          'entries_ml': entriesMl.map((ml) => {'amount_ml': ml}).toList(),
        },
      );
      return true;
    } catch (e) {
      // Roll back on failure so the UI reflects the actual saved state
      currentUserData?.waterEntriesByDate[dateKey] = previous;
      userDataNotifier.notifyListeners();
      debugPrint('[water] Failed to upsert water log: $e');
      return false;
    }
  }

  Future<bool> updateWeightLog(String dateKey, double weightKg) async {
    final previous = currentUserData?.weightByDate[dateKey];
    currentUserData?.weightByDate[dateKey] = weightKg;
    userDataNotifier.notifyListeners();
    try {
      await authenticatedPost(
        'upsert_weight_log',
        body: {'date': dateKey, 'weight_kg': weightKg},
      );
      return true;
    } catch (e) {
      // Roll back on failure
      if (previous == null) {
        currentUserData?.weightByDate.remove(dateKey);
      } else {
        currentUserData?.weightByDate[dateKey] = previous;
      }
      userDataNotifier.notifyListeners();
      debugPrint('[weight] Failed to upsert weight log: $e');
      return false;
    }
  }

  Future<bool> deleteWeightLog(String dateKey) async {
    final previous = currentUserData?.weightByDate[dateKey];
    currentUserData?.weightByDate.remove(dateKey);
    userDataNotifier.notifyListeners();
    try {
      await authenticatedPost('delete_weight_log', body: {'date': dateKey});
      return true;
    } catch (e) {
      if (previous != null) currentUserData?.weightByDate[dateKey] = previous;
      userDataNotifier.notifyListeners();
      debugPrint('[weight] Failed to delete weight log: $e');
      return false;
    }
  }

  Future<void> updateUnits(
    String units,
    BuildContext context, {
    bool showFeedback = true,
  }) async {
    if (isGuest) {
      Guest.block(context);
      return;
    }
    currentUserData!.units = units;
    userDataNotifier.notifyListeners();
    try {
      final response = await authenticatedPost(
        'update_units',
        body: {'units': units},
      );
      if (response.statusCode != 200) {
        throw Exception(
          'update_units failed: ${response.statusCode} ${response.body}',
        );
      }
      if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Units updated successfully."),
            duration: snackBarDuration,
          ),
        );
      }
    } catch (e) {
      if (!isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("No connection. Please try again when online."),
            duration: snackBarDuration,
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error updating unit preference."),
          duration: snackBarDuration,
        ),
      );
    }
  }

  // Method that silently stores the user's timezone based on UTC offset
  Future<void> updateUtcOffset() async {
    if (isGuest) return;
    try {
      final offset = DateTime.now().timeZoneOffset.inMinutes;
      await authenticatedPost(
        'update_utc_offset_minutes',
        body: {'utc_offset': offset},
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Error updating utc offset: $e');
    }
  }

  // Method for updating the app theme color and storing it
  Future<void> updateAppColor(
    Color newColor,
    BuildContext context, {
    bool showFeedback = true,
  }) async {
    if (isGuest) {
      Guest.block(context);
      return;
    }
    currentUserData!.appColor = newColor;
    userDataNotifier.notifyListeners();
    try {
      // Convert color to int
      final int argbInt = newColor.toARGB32();

      // Flag for checking if the chosen color is the default app color
      bool isDefaultColor = argbInt == defaultAppColor.toARGB32();

      final response = await authenticatedPost(
        'update_app_color',
        body: {'app_color': argbInt},
      );

      if (response.statusCode != 200) {
        throw Exception(
          'update_app_color failed: ${response.statusCode} ${response.body}',
        );
      }

      if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isDefaultColor ? "Theme color reset!" : "Theme color updated!",
            ),
            duration: snackBarDuration,
          ),
        );
      }
    } catch (e) {
      if (!showFeedback) return;
      if (!isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("No connection. Please try again when online."),
            duration: snackBarDuration,
          ),
        );
        return;
      }
      final message = e is TimeoutException
          ? "Connection is slow. Please try again."
          : "Error updating theme color.";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: snackBarDuration),
      );
    }
  }

  Future<void> updateFoodDataByDateV2(
    Map<String, Map<String, List<Map<String, dynamic>>>> newFoodData, {
    BuildContext? context,
    bool isBeingDeleted = false,
    bool isBeingEdited = false,
  }) async {
    if (isGuest) {
      if (context != null) Guest.block(context);
      return;
    }
    try {
      for (final entry in newFoodData.entries) {
        final dateKey = entry.key;
        final meals = entry.value;
        // Flatten all meals into a single list of items with meal name attached
        final items = <Map<String, dynamic>>[];
        for (final meal in ['breakfast', 'lunch', 'dinner', 'snacks']) {
          for (final food in (meals[meal] ?? [])) {
            items.add({...food, 'meal': meal});
          }
        }

        final response = await authenticatedPost(
          'upsert_food_log_v2',
          body: {'date': dateKey, 'items': items},
          timeout: const Duration(seconds: 10),
        );

        if (response.statusCode != 200) {
          throw Exception(
            'upsert_food_log_v2 failed: ${response.statusCode} ${response.body}',
          );
        }
      }

      // Only refetch streak if today is a new day since the last logged date
      if (!isBeingDeleted) {
        final today = DateTime.now();
        final todayKey =
            '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
        if (currentUserData?.foodLogStreakLastDate != todayKey) {
          try {
            final streaks = await fetchStreaks();
            final foodRow = streaks.firstWhere(
              (s) => s['streak_type'] == 'food_streak',
              orElse: () => {},
            );
            currentUserData?.foodLogStreak = (foodRow['streak'] as int?) ?? 0;
            currentUserData?.foodLogStreakBest =
                (foodRow['highest_streak'] as int?) ?? 0;
            currentUserData?.foodLogStreakLastDate =
                foodRow['last_date'] as String?;
            userDataNotifier.notifyListeners();
          } catch (_) {}
        }
      }

      if (!isBeingDeleted) {
        FirebaseAnalytics.instance.logEvent(name: 'food_logged');
        const milestones = [3, 7, 14, 30, 60, 100];
        final streak = currentUserData?.foodLogStreak ?? 0;
        if (milestones.contains(streak)) {
          FirebaseAnalytics.instance.logEvent(
            name: 'streak_milestone',
            parameters: {'streak_type': 'food', 'streak': streak},
          );
        }
      }

      // Only show success snackbar if connected, otherwise the error snackbar is shown in the catch block
      final msg = isBeingDeleted
          ? "Food deleted successfully."
          : isBeingEdited
          ? "Food edited successfully."
          : "Food logged successfully.";
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), duration: snackBarDuration),
        );
      }
    } catch (e) {
      if (context != null) {
        // No connection so the update cannot be completed
        if (!isConnected) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("No connection. Please try again when online."),
              duration: snackBarDuration,
            ),
          );
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error updating food data: $e"),
            duration: snackBarDuration,
          ),
        );
      }
    }
  }

  // Searches for food via the backend, which proxies to FatSecret API
  static Future<http.Response> searchFood(String query) async {
    if (isGuest) return http.Response('{"foods": []}', 200);
    return await authenticatedPost('food', body: {'food_name': query});
  }

  // Method for calling the /update_goals route from the frontend
  Future<void> updateGoals({
    int? caloriesGoal,
    int? proteinGoal,
    int? carbsGoal,
    int? fatGoal,
    String? weightGoalType,
    int? weeklyWorkoutsGoal,
    BuildContext? context,
  }) async {
    if (isGuest) {
      if (context != null) Guest.block(context);
      return;
    }
    try {
      final response = await authenticatedPost(
        'update_goals',
        body: {
          'calories_goal': caloriesGoal,
          'protein_goal': proteinGoal,
          'carbs_goal': carbsGoal,
          'fat_goal': fatGoal,
          'weight_goal_type': weightGoalType,
          'weekly_workouts_goal': weeklyWorkoutsGoal,
        },
        timeout: const Duration(seconds: 2),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'update_goals failed: ${response.statusCode} ${response.body}',
        );
      }

      // update local state for only the fields that were provided
      if (currentUserData != null) {
        if (caloriesGoal != null) currentUserData!.caloriesGoal = caloriesGoal;
        if (proteinGoal != null) currentUserData!.proteinGoal = proteinGoal;
        if (carbsGoal != null) currentUserData!.carbsGoal = carbsGoal;
        if (fatGoal != null) currentUserData!.fatGoal = fatGoal;
        if (weightGoalType != null) {
          currentUserData!.weightGoalType = weightGoalType;
        }
        if (weeklyWorkoutsGoal != null) {
          currentUserData!.weeklyWorkoutsGoal = weeklyWorkoutsGoal;
        }
        userDataNotifier.notifyListeners();
      }

      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Goals updated successfully."),
            duration: snackBarDuration,
          ),
        );
      }
    } catch (e) {
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error updating goals: $e"),
            duration: snackBarDuration,
          ),
        );
      }
    }
  }

  Future<void> updateNutritionGoals({
    int? caloriesGoal,
    int? proteinGoal,
    int? carbsGoal,
    int? fatGoal,
    BuildContext? context,
  }) async {
    if (isGuest) {
      if (context != null) Guest.block(context);
      return;
    }
    try {
      final response = await authenticatedPost(
        'update_nutrition_goals',
        body: {
          'calories_goal': caloriesGoal,
          'protein_goal': proteinGoal,
          'carbs_goal': carbsGoal,
          'fat_goal': fatGoal,
        },
        timeout: const Duration(seconds: 2),
      );
      if (response.statusCode != 200) {
        throw Exception(
          'update_nutrition_goals failed: ${response.statusCode} ${response.body}',
        );
      }
      if (currentUserData != null) {
        if (caloriesGoal != null) currentUserData!.caloriesGoal = caloriesGoal;
        if (proteinGoal != null) currentUserData!.proteinGoal = proteinGoal;
        if (carbsGoal != null) currentUserData!.carbsGoal = carbsGoal;
        if (fatGoal != null) currentUserData!.fatGoal = fatGoal;
        userDataNotifier.notifyListeners();
      }
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Nutrition goals updated."),
            duration: snackBarDuration,
          ),
        );
      }
    } catch (e) {
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error updating nutrition goals: $e"),
            duration: snackBarDuration,
          ),
        );
      }
    }
  }

  Future<void> updateWeightGoal({
    String? weightGoalType,
    double? weightKgGoal,
    BuildContext? context,
  }) async {
    if (isGuest) {
      if (context != null) Guest.block(context);
      return;
    }
    try {
      final response = await authenticatedPost(
        'update_weight_goal',
        body: {
          'weight_goal_type': weightGoalType,
          'weight_kg_goal': weightKgGoal,
        },
        timeout: const Duration(seconds: 2),
      );
      if (response.statusCode != 200) {
        throw Exception(
          'update_weight_goal failed: ${response.statusCode} ${response.body}',
        );
      }
      if (currentUserData != null) {
        if (weightGoalType != null) {
          currentUserData!.weightGoalType = weightGoalType;
        }
        if (weightKgGoal != null) currentUserData!.weightKgGoal = weightKgGoal;
        userDataNotifier.notifyListeners();
      }
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Weight goal updated."),
            duration: snackBarDuration,
          ),
        );
      }
    } catch (e) {
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error updating weight goal: $e"),
            duration: snackBarDuration,
          ),
        );
      }
    }
  }

  Future<void> updateWaterGoal({
    int? waterMlGoal,
    BuildContext? context,
  }) async {
    if (isGuest) {
      if (context != null) Guest.block(context);
      return;
    }
    try {
      final response = await authenticatedPost(
        'update_water_goal',
        body: {'water_ml_goal': waterMlGoal},
        timeout: const Duration(seconds: 2),
      );
      if (response.statusCode != 200) {
        throw Exception(
          'update_water_goal failed: ${response.statusCode} ${response.body}',
        );
      }
      if (currentUserData != null && waterMlGoal != null) {
        currentUserData!.waterMlGoal = waterMlGoal;
        userDataNotifier.notifyListeners();
      }
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Water goal updated."),
            duration: snackBarDuration,
          ),
        );
      }
    } catch (e) {
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error updating water goal: $e"),
            duration: snackBarDuration,
          ),
        );
      }
    }
  }

  Future<void> updateWeeklyWorkoutsGoal({
    int? weeklyWorkoutsGoal,
    BuildContext? context,
  }) async {
    if (isGuest) {
      if (context != null) Guest.block(context);
      return;
    }
    try {
      final response = await authenticatedPost(
        'update_weekly_workouts_goal',
        body: {'weekly_workouts_goal': weeklyWorkoutsGoal},
        timeout: const Duration(seconds: 2),
      );
      if (response.statusCode != 200) {
        throw Exception(
          'update_weekly_workouts_goal failed: ${response.statusCode} ${response.body}',
        );
      }
      if (currentUserData != null && weeklyWorkoutsGoal != null) {
        currentUserData!.weeklyWorkoutsGoal = weeklyWorkoutsGoal;
        userDataNotifier.notifyListeners();
      }
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Workout goal updated."),
            duration: snackBarDuration,
          ),
        );
      }
    } catch (e) {
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error updating workout goal: $e"),
            duration: snackBarDuration,
          ),
        );
      }
    }
  }

  // Fetches the user's streak data from the backend
  static Future<List<Map<String, dynamic>>> fetchStreaks() async {
    if (isGuest) return [];
    final response = await authenticatedGet('streaks');

    if (response.statusCode != 200) {
      throw Exception(
        'get_streaks failed: ${response.statusCode} ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['streaks'] as List<dynamic>)
        .map((s) => Map<String, dynamic>.from(s as Map))
        .toList();
  }

  // Fetches the achievement definitions (public, no auth)
  static Future<List<Map<String, dynamic>>> fetchAchievementDefs() async {
    final response = await http
        .get(Uri.parse('$backendBaseUrl/achievement_defs'))
        .timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw Exception(
        'achievement_defs failed: ${response.statusCode} ${response.body}',
      );
    }

    return (jsonDecode(response.body) as List<dynamic>)
        .map((d) => Map<String, dynamic>.from(d as Map))
        .toList();
  }

  // Fetches the user's achievement progress and claims from the backend
  static Future<Map<String, dynamic>> fetchAchievements() async {
    final response = await authenticatedGet('achievements');

    if (response.statusCode != 200) {
      throw Exception(
        'get_achievements failed: ${response.statusCode} ${response.body}',
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // Returns the user's leaderboard rank and total player count
  static Future<Map<String, dynamic>> fetchLeaderboardStanding() async {
    final response = await authenticatedGet('leaderboard_standing');
    if (response.statusCode != 200) {
      throw Exception(
        'leaderboard_standing failed: ${response.statusCode} ${response.body}',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> fetchRecentExercises() async {
    try {
      final response = await authenticatedGet(
        'recent_exercises',
        timeout: const Duration(seconds: 8),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['exercises'] as List)
            .map((exercise) => Map<String, dynamic>.from(exercise as Map))
            .toList();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('fetchRecentExercises failed: $e');
    }
    return [];
  }

  Future<Map<String, int>> fetchWorkoutHeatmap() async {
    try {
      final response = await authenticatedGet(
        'workout_heatmap',
        timeout: const Duration(seconds: 8),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final days = data['days'] as List;
        return {for (final d in days) d['date'] as String: d['count'] as int};
      }
    } catch (e) {
      if (kDebugMode) debugPrint('fetchWorkoutHeatmap failed: $e');
    }
    return {};
  }

  Future<Map<String, dynamic>> fetchTodayOverview() async {
    try {
      final response = await authenticatedGet(
        'today_overview',
        timeout: const Duration(seconds: 8),
      );
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('fetchTodayOverview failed: $e');
    }
    return {
      'volume_kg': 0.0,
      'exercises': 0,
      'sets': 0,
      'reps': 0,
      'duration_seconds': 0,
      'primary_muscles': [],
      'secondary_muscles': [],
    };
  }

  Future<int> fetchWeeklyWorkoutCount() async {
    try {
      final response = await authenticatedGet(
        'weekly_workout_count',
        timeout: const Duration(seconds: 8),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['count'] as int? ?? 0;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('fetchWeeklyWorkoutCount failed: $e');
    }
    return 0;
  }

  Future<List<Map<String, dynamic>>> fetchRecentWorkouts() async {
    try {
      final response = await authenticatedGet(
        'recent_workouts',
        timeout: const Duration(seconds: 8),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['workouts'] as List)
            .map((workout) => Map<String, dynamic>.from(workout as Map))
            .toList();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('fetchRecentWorkouts failed: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> createCustomExercise({
    required String name,
    String? primaryMuscle,
    List<String> secondaryMuscles = const [],
    String? equipment,
    String? level,
  }) async {
    try {
      final response = await authenticatedPost(
        'create_custom_exercise',
        body: {
          'name': name,
          'primary_muscle': primaryMuscle,
          'secondary_muscles': secondaryMuscles,
          'equipment': equipment,
          'level': level,
        },
      );
      final data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      if (response.statusCode == 200) return data;
      // return the error message from the backend so the dialog can show it
      return {'error': data['error'] ?? 'Failed to create exercise'};
    } catch (e) {
      if (kDebugMode) debugPrint('createCustomExercise failed: $e');
    }
    return null;
  }

  Future<bool> editCustomExercise({
    required int exerciseId,
    required String name,
    String? primaryMuscle,
    List<String> secondaryMuscles = const [],
    String? equipment,
    String? level,
  }) async {
    try {
      final response = await authenticatedPost(
        'edit_custom_exercise',
        body: {
          'exercise_id': exerciseId,
          'name': name,
          'primary_muscle': primaryMuscle,
          'secondary_muscles': secondaryMuscles,
          'equipment': equipment,
          'level': level,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('editCustomExercise failed: $e');
    }
    return false;
  }

  Future<Map<String, dynamic>> fetchBrowseRoutines() async {
    try {
      final response = await authenticatedGet(
        'browse_routines',
        timeout: const Duration(seconds: 10),
      );
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('fetchBrowseRoutines failed: $e');
    }
    return {'featured': [], 'community': []};
  }

  Future<List<Map<String, dynamic>>> fetchMyRoutines() async {
    try {
      final response = await authenticatedGet(
        'my_routines',
        timeout: const Duration(seconds: 8),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['routines'] as List)
            .map((routine) => Map<String, dynamic>.from(routine as Map))
            .toList();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('fetchMyRoutines failed: $e');
    }
    return [];
  }

  // returns previous sets keyed by exercise_name -> set_number -> {weight_kg, reps}
  Future<Map<String, Map<int, Map<String, dynamic>>>> fetchEveryPrevSet(
    List<String> exerciseNames,
  ) async {
    try {
      final response = await authenticatedPost(
        'every_prev_set',
        body: {'exercise_names': exerciseNames},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final result = <String, Map<int, Map<String, dynamic>>>{};
        for (final prevSet in data['sets'] as List) {
          final setMap = Map<String, dynamic>.from(prevSet as Map);
          final exerciseName = setMap['exercise_name'] as String;
          final setNumber = setMap['set_number'] as int;
          result.putIfAbsent(exerciseName, () => {});
          result[exerciseName]![setNumber] = setMap;
        }
        return result;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('fetchEveryPrevSet failed: $e');
    }
    return {};
  }

  Future<Map<String, Map<String, dynamic>>> fetchExerciseStats() async {
    try {
      final response = await authenticatedGet('exercise_stats');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final stats = (data['stats'] as List)
            .map((stat) => Map<String, dynamic>.from(stat as Map))
            .toList();
        // keyed by exercise_name for O(1) lookup during workout
        return {
          for (final stat in stats) stat['exercise_name'] as String: stat,
        };
      }
    } catch (e) {
      if (kDebugMode) debugPrint('fetchExerciseStats failed: $e');
    }
    return {};
  }

  Future<bool> deleteRoutine({required String templateId}) async {
    try {
      final response = await authenticatedPost(
        'delete_routine',
        body: {'template_id': templateId},
      );
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('deleteRoutine failed: $e');
    }
    return false;
  }

  Future<bool> likeRoutine({required String templateId}) async {
    try {
      final response = await authenticatedPost(
        'like_routine',
        body: {'template_id': templateId},
      );
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('likeRoutine failed: $e');
    }
    return false;
  }

  Future<bool> unlikeRoutine({required String templateId}) async {
    try {
      final response = await authenticatedPost(
        'unlike_routine',
        body: {'template_id': templateId},
      );
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('unlikeRoutine failed: $e');
    }
    return false;
  }

  // copies a public browse routine into the user's own routines
  Future<bool> copyRoutine({required String templateId}) async {
    try {
      final response = await authenticatedPost(
        'copy_routine',
        body: {'template_id': templateId},
      );
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('copyRoutine failed: $e');
    }
    return false;
  }

  Future<bool> createRoutine({
    required String name,
    required List<Map<String, dynamic>> exercises,
    int? estimatedDurationMinutes,
  }) async {
    try {
      final response = await authenticatedPost(
        'create_routine',
        body: {
          'name': name,
          'exercises': exercises,
          'estimated_duration_minutes': ?estimatedDurationMinutes,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('createRoutine failed: $e');
    }
    return false;
  }

  Future<bool> deleteCustomExercise(int exerciseId) async {
    try {
      final response = await authenticatedPost(
        'delete_custom_exercise',
        body: {'exercise_id': exerciseId},
      );
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('deleteCustomExercise failed: $e');
    }
    return false;
  }
}
