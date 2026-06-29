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
import '../models/reminder_data.dart';
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

  // Loads all user data from the backend in a single call
  Future<void> loadUserData() async {
    final stopwatch = Stopwatch()..start();
    // Initialize the connectivity stream to know the user's connectivity state
    initConnectivity();

    if (isGuest) {
      userDataNotifier.value = Guest.defaultUserData;
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid != null) {
      // Initialize currentUserData if it's null or has the wrong UID (safety guard that gets overwritten)
      if (currentUserData == null || currentUserData!.uid != uid) {
        userDataNotifier.value = UserData(
          uid: uid,
          pfpBase64: null,
          level: 1,
          expPoints: 0,
          canClaimDailyReward: true,
          notificationsEnabled: true,
          lastDailyClaim: null,
          username: uid, // default username is uid
          reminders: [],
          appColor: defaultAppColor,
          foodLogs: [],
          fcmTokens: [],
        );
      }

      await _fetchUserDataSafely();
    }
    stopwatch.stop();
  }

  // Calls the backend /user_data endpoint to load all user fields at once, with no fallback since Firestore is no longer the source of truth
  Future<void> _fetchUserDataSafely() async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await authenticatedGet('user_data');

      if (response.statusCode != 200) {
        throw Exception(
          'get_user_data failed: ${response.statusCode} ${response.body}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      // Map the backend response fields to currentUserData
      currentUserData?.level = data['level'] ?? currentUserData?.level;
      currentUserData?.expPoints =
          data['exp_points'] ?? currentUserData?.expPoints;
      currentUserData?.pfpBase64 = data['pfp_base64'];
      currentUserData?.username = data['username'] ?? currentUserData?.uid;
      currentUserData?.notificationsEnabled =
          data['notifications_enabled'] ?? true;
      currentUserData?.fcmTokens =
          (data['fcm_tokens'] as List<dynamic>?)
              ?.map((t) => t.toString())
              .toList() ??
          [];

      if (data['app_color'] != null) {
        currentUserData?.appColor = Color(data['app_color'] as int);
        appColorNotifier.value = currentUserData!.appColor;
      }

      currentUserData?.dailyClaimStreak = data['daily_streak'] ?? 1;

      // Compute canClaimDailyReward directly from last_daily_claim (23-hour cooldown)
      if (data['last_daily_claim'] != null) {
        currentUserData?.lastDailyClaim = DateTime.parse(
          data['last_daily_claim'],
        );
        final secondsSince = DateTime.now()
            .toUtc()
            .difference(currentUserData!.lastDailyClaim!.toUtc())
            .inSeconds;
        currentUserData!.canClaimDailyReward =
            secondsSince >= dailyRewardCooldown.inSeconds;
      } else {
        currentUserData!.canClaimDailyReward = true;
      }

      // Load flat food log list from food_logs_v2
      if (data['food_logs_v2'] != null) {
        currentUserData?.foodLogs = (data['food_logs_v2'] as List<dynamic>)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }

      // Map reminders from the backend response into ReminderData objects
      if (data['reminders'] != null) {
        currentUserData?.reminders = (data['reminders'] as List<dynamic>)
            .map((r) => ReminderData.fromJson(r))
            .toList();
      }

      // Map goals from the backend response if they exist
      if (data['goals'] != null) {
        currentUserData?.caloriesGoal = data['goals']['calories_goal'];
        currentUserData?.proteinGoal = data['goals']['protein_goal'];
        currentUserData?.carbsGoal = data['goals']['carbs_goal'];
        currentUserData?.fatGoal = data['goals']['fat_goal'];
        currentUserData?.weightGoalType = data['goals']['weight_goal_type'];
        currentUserData?.weeklyWorkoutsGoal =
            data['goals']['weekly_workouts_goal'];
        currentUserData?.waterMlGoal = data['goals']['water_ml_goal'];
        final rawWeightKgGoal = data['goals']['weight_kg_goal'];
        currentUserData?.weightKgGoal = rawWeightKgGoal != null
            ? (rawWeightKgGoal as num).toDouble()
            : null;
      }

      currentUserData?.referralCode = data['referral_code'];
      currentUserData?.referralCount = data['referral_count'] ?? 0;
      currentUserData?.referralUsed = data['referral_used'] ?? false;
      currentUserData?.units = data['units'] ?? 'metric';
      final createdAtStr = data['created_at'] as String?;
      if (createdAtStr != null) {
        currentUserData?.createdAt = DateTime.tryParse(createdAtStr)?.toLocal();
      }

      if (data['water_logs'] != null) {
        final Map<String, List<int>> waterData = {};
        for (final row in (data['water_logs'] as List<dynamic>)) {
          final map = row as Map<String, dynamic>;
          final dateKey = map['date'] as String;
          final entries = (map['entries_ml'] as List<dynamic>?) ?? [];
          waterData[dateKey] = entries
              .map(
                (e) => (e as Map<String, dynamic>)['amount_ml'] as int,
              ) // unwrap {amount_ml: x} to just x
              .toList();
        }
        currentUserData?.waterEntriesByDate = waterData;
      }

      if (data['weight_logs'] != null) {
        final Map<String, double> weightData = {};
        for (final row in (data['weight_logs'] as List<dynamic>)) {
          final map = row as Map<String, dynamic>;
          final dateKey = map['date'] as String;
          weightData[dateKey] = (map['weight_kg'] as num)
              .toDouble(); // always kg, converted to lbs at display time
        }
        currentUserData?.weightByDate = weightData;
      }

      // keep the notifier in sync so XP bar rebuilds immediately
      expNotifier.value = currentUserData!.expPoints;

      // fetch current and best streaks from the streaks table
      try {
        final streaks = await fetchStreaks();
        final foodRow = streaks.firstWhere(
          (s) => s['streak_type'] == 'food_streak',
          orElse: () => {},
        );
        final claimRow = streaks.firstWhere(
          (s) => s['streak_type'] == 'daily_consecutive_streak',
          orElse: () => {},
        );
        currentUserData?.foodLogStreak = (foodRow['streak'] as int?) ?? 0;
        currentUserData?.foodLogStreakBest =
            (foodRow['highest_streak'] as int?) ?? 0;
        currentUserData?.foodLogStreakLastDate =
            foodRow['last_date'] as String?;
        currentUserData?.dailyClaimStreakBest =
            (claimRow['highest_streak'] as int?) ?? 0;
        userDataNotifier.notifyListeners();
      } catch (_) {}

      lastLoadFailed = false;
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading user data: $e');
      currentUserData?.username =
          null; // signals fetch failed so username dialog is not shown
      currentUserData?.canClaimDailyReward =
          true; // let the backend decide on claim attempt
      userDataNotifier.notifyListeners();
      lastLoadFailed = true;
    }
    stopwatch.stop();
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
        reminders: currentUserData!.reminders,
        appColor: currentUserData!.appColor,
        foodLogs: currentUserData!.foodLogs,
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

  // Updates the user's XP by sending a verified event to the backend
  // The backend validates the 23-hour cooldown and writes XP/level atomically in a transaction
  // This prevents double-claiming even if the user taps the button twice rapidly
  Future<(int, int, int, double)?> claimDailyReward() async {
    if (isGuest) return null;

    try {
      // Call backend to claim daily reward
      final response = await authenticatedPost('claim_daily_reward');

      if (response.statusCode != 200) {
        throw Exception(
          'claimDailyReward failed: ${response.statusCode} ${response.body}',
        );
      }

      final result = jsonDecode(response.body) as Map<String, dynamic>;

      // If reward wasn't claimed (cooldown not met), lock the button locally
      if (!result['claimed']) {
        currentUserData!.canClaimDailyReward = false;
        return null; // Not enough time has passed
      }

      // Update local state from the backend response
      final prevLevel = currentUserData!.level;
      currentUserData!.level = result['new_level'];
      currentUserData!.expPoints = result['new_exp'];
      if (prevLevel < 3 && currentUserData!.level >= 3) {
        FirebaseAnalytics.instance.logEvent(name: 'reached_level_3');
      }
      currentUserData!.canClaimDailyReward = false;
      currentUserData!.lastDailyClaim = DateTime.now().toUtc();

      final xpGained = result['xp_gained'] as int;
      final baseXp = (result['base_xp'] ?? xpGained) as int;
      final streak = (result['daily_streak'] ?? 1) as int;
      final multiplier = ((result['streak_multiplier'] ?? 1.0) as num)
          .toDouble();

      // Keep local streak in sync so home screen reflects the new value immediately
      currentUserData!.dailyClaimStreak = streak;
      if (streak > (currentUserData!.dailyClaimStreakBest)) {
        currentUserData!.dailyClaimStreakBest = streak;
      }
      userDataNotifier.notifyListeners();

      return (xpGained, baseXp, streak, multiplier);
    } catch (e) {
      if (kDebugMode) debugPrint('claimDailyReward backend error: $e');
      return (-1, -1, -1, -1.0); // sentinel for network failure
    }
  }

  // Method for storing the user's updated username, verified and checked for uniqueness by the backend
  Future<bool> updateUsername(
    // returns a bool to handle whether the dialog box should close or open
    String updatedUsername,
    BuildContext context, {
    bool showFeedback = true,
  }) async {
    if (isGuest) {
      Guest.block(context);
      return false;
    }

    try {
      // Call the backend to check uniqueness and update the username atomically
      final response = await authenticatedPost(
        'update_username',
        body: {'username': updatedUsername},
      );

      final result = jsonDecode(response.body) as Map<String, dynamic>;

      // Username is rejected
      if (response.statusCode == 409) {
        final error = result['error'] as String? ?? 'Error updating username.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $error"), duration: snackBarDuration),
        );
        return false; // false to keep the dialog box open
      }
      // Username was successfully updated
      else if (response.statusCode == 200) {
        // Update locally so the UI reflects the change immediately
        currentUserData!.username = updatedUsername;
        userDataNotifier.notifyListeners();
        if (showFeedback) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Success! Username updated."),
              duration: snackBarDuration,
            ),
          );
        }
        return true;
      } else {
        // Backend rejected the update (username taken)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? "Error updating username."),
            duration: snackBarDuration,
          ),
        );
        return false;
      }
    } catch (e) {
      // No connection, so show the local confirmation snackbar
      if (!isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Error updating username. Check your connection and try again.",
            ),
            duration: snackBarDuration,
          ),
        );
        return true; // to close the dialog
      }

      // Other error messages unrelated to no connection
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error updating username: $e"),
          duration: snackBarDuration,
        ),
      );
      return false;
    }
  }

  // Method to initialize FCM token on app startup and add it to Postgres if not already present, ensuring no duplicates
  Future<void> initializeFcmToken(String deviceToken) async {
    if (isGuest) return;
    try {
      // Add token locally if not already present (guard against race condition where currentUserData may not be set yet)
      if (currentUserData != null &&
          !currentUserData!.fcmTokens.contains(deviceToken)) {
        currentUserData!.fcmTokens.add(deviceToken);
        userDataNotifier.notifyListeners();
      }

      await authenticatedPost('add_fcm_token', body: {'token': deviceToken});
    } catch (e) {
      if (kDebugMode) debugPrint("Error initializing FCM token: $e");
    }
  }

  // Adds this device's FCM token to Postgres (called on token refresh)
  Future<void> addFcmToken(String deviceToken, {String? oldToken}) async {
    if (isGuest) return;
    try {
      // clear the stale token
      if (oldToken != null) await removeFcmToken(oldToken);

      // Update local list if not already present
      if (currentUserData != null &&
          !currentUserData!.fcmTokens.contains(deviceToken)) {
        currentUserData!.fcmTokens.add(deviceToken);
        userDataNotifier.notifyListeners();
      }

      await authenticatedPost('add_fcm_token', body: {'token': deviceToken});
    } catch (e) {
      if (kDebugMode) debugPrint("Error adding FCM token: $e");
    }
  }

  // Removes this device's FCM token from Postgres (called on logout)
  Future<void> removeFcmToken(String deviceToken) async {
    if (isGuest) return;
    try {
      // Remove token from local list
      currentUserData!.fcmTokens.remove(deviceToken);
      userDataNotifier.notifyListeners();

      await authenticatedPost('remove_fcm_token', body: {'token': deviceToken});
    } catch (e) {
      if (kDebugMode) debugPrint("Error removing FCM token: $e");
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
      // Update foodLogs locally by replacing items for affected dates
      for (final entry in newFoodData.entries) {
        final dateKey = entry.key;
        currentUserData?.foodLogs.removeWhere((f) => f['date'] == dateKey);
        for (final meal in ['breakfast', 'lunch', 'dinner', 'snacks']) {
          for (final food in (entry.value[meal] ?? [])) {
            currentUserData?.foodLogs.add({
              ...food,
              'date': dateKey,
              'meal': meal,
            });
          }
        }
      }
      userDataNotifier.notifyListeners();

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

        // Patch the real id and logged_at from the backend onto newly inserted local entries
        // Only entries without an id need patching — existing ones already have theirs
        final responseData = jsonDecode(response.body);
        final returnedItems = (responseData['items'] as List<dynamic>? ?? []);
        for (final returned in returnedItems) {
          final id = returned['id'];
          final name = returned['food_name'];
          final meal = returned['meal'];
          final loggedAt = returned['logged_at'];
          if (id == null) continue;
          // Match by food_name + meal + date + no id (new entries only)
          final idx = currentUserData?.foodLogs.indexWhere(
            (f) =>
                f['id'] == null &&
                f['food_name'] == name &&
                f['meal'] == meal &&
                f['date'] == dateKey,
          );
          if (idx != null && idx >= 0) {
            currentUserData!.foodLogs[idx]['id'] = id;
            currentUserData!.foodLogs[idx]['logged_at'] = loggedAt;
          }
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
    return await authenticatedPost('get_food', body: {'food_name': query});
  }

  // Refreshes all user data from the backend, called on Food Logging tab switch to keep data fresh across devices
  Future<void> refreshUserData() async {
    if (isGuest) return;
    await _fetchUserDataSafely();
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
        .get(Uri.parse('$backendBaseUrl/get_achievement_defs'))
        .timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw Exception(
        'get_achievement_defs failed: ${response.statusCode} ${response.body}',
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

  // Awards XP for watching a rewarded ad
  Future<void> claimAdXp(BuildContext context) async {
    try {
      final response = await authenticatedPost('claim_ad_xp');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final xpGained = data['xp_gained'] ?? 0;
        await refreshUserData();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("+$xpGained XP earned!"),
              duration: snackBarDuration,
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('claimAdXp failed: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchRecentExercises() async {
    try {
      final response = await authenticatedGet(
        'get_recent_exercises',
        timeout: const Duration(seconds: 8),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['exercises'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('fetchRecentExercises failed: $e');
    }
    return [];
  }

  Future<int> fetchWeeklyWorkoutCount() async {
    try {
      final response = await authenticatedGet(
        'get_weekly_workout_count',
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
        'get_recent_workouts',
        timeout: const Duration(seconds: 8),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['workouts'] as List)
            .map((w) => Map<String, dynamic>.from(w as Map))
            .toList();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('fetchRecentWorkouts failed: $e');
    }
    return [];
  }
}
