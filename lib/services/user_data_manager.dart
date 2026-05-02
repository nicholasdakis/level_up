import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../globals.dart';
import '../models/user_data.dart';
import '../models/reminder_data.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../utility/image_crop_handler.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

// Base URL for the backend hosted on Render. All backend requests go to this URL
const String backendBaseUrl = 'https://level-up-69vz.onrender.com';

// Gets a fresh Firebase ID token, a JWT, to authenticate requests with the backend
// Firebase caches this automatically so it only re-fetches when close to expiry (1hr)
Future<String> getIdToken() async {
  final token = await FirebaseAuth.instance.currentUser?.getIdToken().timeout(
    Duration(seconds: 2),
  );
  if (token == null) throw Exception('User not logged in');
  return token;
}

// Fires and forgets a trivial achievement increment to the backend
void trackTrivialAchievement(String achievementId) async {
  try {
    final token = await getIdToken();
    await http
        .post(
          Uri.parse('$backendBaseUrl/claim_trivial_achievement'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'id_token': token,
            'achievement_id': achievementId,
          }),
        )
        .timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint('Failed to track trivial achievement $achievementId: $e');
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

  // Loads all user data from the backend in a single call
  Future<void> loadUserData() async {
    final stopwatch = Stopwatch()..start();
    // Initialize the connectivity stream to know the user's connectivity state
    initConnectivity();
    debugPrint(
      'initConnectivity happened at ${stopwatch.elapsedMilliseconds}ms',
    );

    final uid = FirebaseAuth.instance.currentUser?.uid;
    debugPrint('Setting uid happened at ${stopwatch.elapsedMilliseconds}ms');

    if (uid != null) {
      // Initialize currentUserData if it's null or has the wrong UID (safety guard that gets overwritten)
      if (currentUserData == null || currentUserData!.uid != uid) {
        currentUserData = UserData(
          uid: uid,
          pfpBase64: null,
          level: 1,
          expPoints: 0,
          canClaimDailyReward: true,
          notificationsEnabled: true,
          lastDailyClaim: null,
          username: uid, // default username is uid
          reminders: [],
          appColor: const Color.fromARGB(255, 45, 45, 45),
          foodDataByDate: {},
          fcmTokens: [],
        );
      }
      debugPrint(
        'initializing currentuserdata happened at ${stopwatch.elapsedMilliseconds}ms',
      );

      await _fetchUserDataSafely();
    }
    stopwatch.stop();
    debugPrint('loadUserData took ${stopwatch.elapsedMilliseconds}ms');
  }

  // Calls the backend /get_user_data endpoint to load all user fields at once, with no fallback since Firestore is no longer the source of truth
  Future<void> _fetchUserDataSafely() async {
    final stopwatch = Stopwatch()..start();
    try {
      final token = await getIdToken();
      final response = await http
          .post(
            Uri.parse('$backendBaseUrl/get_user_data'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'id_token': token}),
          )
          .timeout(Duration(seconds: 5));

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
      currentUserData?.canClaimDailyReward =
          data['can_claim_daily_reward'] ?? true;
      currentUserData?.pfpBase64 = data['pfp_base64'];
      currentUserData?.username = data['username'] ?? currentUserData?.uid;
      currentUserData?.notificationsEnabled =
          data['notifications_enabled'] ?? true;
      currentUserData?.fcmTokens =
          (data['fcm_tokens'] as List<dynamic>?)
              ?.map((t) => t.toString())
              .toList() ??
          [];

      // Convert app_color int to Flutter Color if present
      // appColorNotifier is not updated here on purpose. It is done in Home Screen
      // right before the skeletonizer to prevent a re-rendering
      if (data['app_color'] != null) {
        currentUserData?.appColor = Color(data['app_color'] as int);
      }

      // Convert last_daily_claim ISO string to DateTime if present
      if (data['last_daily_claim'] != null) {
        currentUserData?.lastDailyClaim = DateTime.parse(
          data['last_daily_claim'],
        );
      }

      // If the backend says the reward can't be claimed but 23 hours have passed
      // locally, override it (can't be exploited as the backend independently verifies this too)
      if (currentUserData?.canClaimDailyReward == false &&
          currentUserData?.lastDailyClaim != null) {
        final secondsSince = DateTime.now()
            .toUtc()
            .difference(currentUserData!.lastDailyClaim!.toUtc())
            .inSeconds;
        if (secondsSince >= 82800) currentUserData!.canClaimDailyReward = true;
      }

      // Map food logs from the backend response into the local foodDataByDate format
      if (data['food_logs'] != null) {
        final Map<String, Map<String, List<Map<String, dynamic>>>> foodData =
            {};
        for (final row in (data['food_logs'] as List<dynamic>)) {
          final map = row as Map<String, dynamic>;
          final dateKey = map['date'] as String;
          foodData[dateKey] = {
            'breakfast': _parseMealList(map['breakfast']),
            'lunch': _parseMealList(map['lunch']),
            'dinner': _parseMealList(map['dinner']),
            'snacks': _parseMealList(map['snack']),
          };
        }
        currentUserData?.foodDataByDate = foodData;
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
      }

      // keep the notifier in sync so XP bar rebuilds immediately
      expNotifier.value = currentUserData!.expPoints;
      lastLoadFailed = false;
    } catch (e) {
      debugPrint('Error loading user data: $e');
      currentUserData?.username =
          null; // signals fetch failed so username dialog is not shown
      currentUserData?.canClaimDailyReward =
          true; // let the backend decide on claim attempt
      lastLoadFailed = true;
    }
    stopwatch.stop();
    debugPrint('_fetchUserDataSafely took ${stopwatch.elapsedMilliseconds}ms');
  }

  // Helper to safely parse a meal list from the backend response
  List<Map<String, dynamic>> _parseMealList(dynamic meal) {
    if (meal == null) return [];
    return (meal as List<dynamic>)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  // Calls the backend /get_progress endpoint to get the user's level, XP, and reward status
  // Separated into its own method so it can be called on pull-to-refresh and the leaderboard
  static Future<Map<String, dynamic>> fetchProgress() async {
    final token = await getIdToken();
    final response = await http
        .post(
          Uri.parse('$backendBaseUrl/get_progress'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'id_token': token}),
        )
        .timeout(Duration(seconds: 5));
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

  Future<Uint8List> webCompressIfNeed(Uint8List image) async {
    const int maxFileSize =
        750 * 1024; // max limit for base64 images to be stored in Postgres

    // No compression needed
    if (image.lengthInBytes <= maxFileSize) {
      return image;
    }

    // Compress
    var result = await FlutterImageCompress.compressWithList(
      image,
      quality: 70,
    );
    return result;
  }

  Future<Uint8List> mobileCompressIfNeed(File file) async {
    const int maxFileSize =
        750 * 1024; // max limit for base64 images to be stored in Postgres

    // Read bytes from the file
    Uint8List bytes = await file.readAsBytes();

    // No compression needed
    if (bytes.lengthInBytes <= maxFileSize) return bytes;

    // Compress using FlutterImageCompress
    Uint8List? compressedBytes = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      quality: 70,
    );

    return compressedBytes!;
  }

  Future<bool> canUpdateProfilePicture(
    File? file,
    BuildContext? context, {
    bool isWeb = false,
    Uint8List? webBytes, // The optional parameters are only used for web
  }) async {
    // 750 KB size limit in bytes (To meet the 1 MB Postgres limit when converted to base64)
    const int maxFileSize = 750 * 1024; // 768000 bytes

    // Handle Web
    if (isWeb) {
      // Check the size of the web image bytes
      if (webBytes != null && webBytes.lengthInBytes > maxFileSize) {
        webBytes = await webCompressIfNeed(webBytes);

        // If still too big:
        if (context != null && webBytes.lengthInBytes > maxFileSize) {
          double sizeInMbWeb = webBytes.lengthInBytes / (1024 * 1024);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Profile picture must be 0.75 MB or less. This image is ${sizeInMbWeb.toStringAsFixed(2)} MB after compression.",
              ),
              duration: Duration(milliseconds: 1500),
            ),
          );
          return false; // file too large
        }
      }
      return true;
    }

    // Handle Mobile (File check)
    if (file == null) return false; // safety check

    Uint8List fileBytes = await mobileCompressIfNeed(file);

    int fileSize = fileBytes.lengthInBytes;

    if (fileSize > maxFileSize) {
      if (context != null) {
        double sizeInMbMobile = fileSize / (1024 * 1024);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Profile picture must be 0.75 MB or less. This image is ${sizeInMbMobile.toStringAsFixed(2)} MB after compression.",
            ),
            duration: Duration(milliseconds: 1500),
          ),
        );
      }
      return false; // early exit if file too large
    }

    return true;
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
            duration: Duration(milliseconds: 1500),
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
            duration: Duration(milliseconds: 1500),
          ),
        );
        return;
      }

      // Update the file to its cropped version
      file = File(cropped.path);
    }

    // Step 2: Check size and compress
    if (!await canUpdateProfilePicture(
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
        base64String = base64Encode(await webCompressIfNeed(imageInBytes!));
      } else {
        // Mobile
        base64String = base64Encode(await mobileCompressIfNeed(file!));
      }

      // Send the Base64 string to the backend to store in Postgres
      final response = await http
          .post(
            Uri.parse('$backendBaseUrl/update_pfp'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'id_token': await getIdToken(),
              'pfp_base64': base64String,
            }),
          )
          .timeout(Duration(seconds: 5));

      if (response.statusCode != 200) {
        throw Exception(
          'update_pfp failed: ${response.statusCode} ${response.body}',
        );
      }

      // Update currentUserData with the complete stored variables with the updated profile picture
      currentUserData = UserData(
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
        foodDataByDate: currentUserData!.foodDataByDate,
        fcmTokens: currentUserData!.fcmTokens,
      );
      // Confirmation snackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Profile picture successfully updated."),
          duration: Duration(milliseconds: 1500),
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
            duration: Duration(milliseconds: 1500),
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
        SnackBar(
          content: Text(message),
          duration: Duration(milliseconds: 1500),
        ),
      );
    }
  }

  // Updates the user's XP by sending a verified event to the backend
  // The backend validates the 23-hour cooldown and writes XP/level atomically in a transaction
  // This prevents double-claiming even if the user taps the button twice rapidly
  Future<int?> claimDailyReward() async {
    try {
      // Call backend to claim daily reward
      final response = await http.post(
        Uri.parse('$backendBaseUrl/claim_daily_reward'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id_token': await getIdToken()}),
      );

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
      currentUserData!.level = result['new_level'];
      currentUserData!.expPoints = result['new_exp'];
      currentUserData!.canClaimDailyReward = false;
      currentUserData!.lastDailyClaim = DateTime.now().toUtc();

      // Return the XP gained
      return result['xp_gained'];
    } catch (e) {
      debugPrint('claimDailyReward backend error: $e');
      return null;
    }
  }

  // Method for storing the user's updated username, verified and checked for uniqueness by the backend
  Future<bool> updateUsername(
    // returns a bool to handle whether the dialog box should close or open
    String updatedUsername,
    BuildContext context,
  ) async {
    try {
      // Call the backend to check uniqueness and update the username atomically
      final response = await http
          .post(
            Uri.parse('$backendBaseUrl/update_username'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'id_token': await getIdToken(),
              'username': updatedUsername,
            }),
          )
          .timeout(Duration(seconds: 5));

      final result = jsonDecode(response.body) as Map<String, dynamic>;

      // Username is taken
      if (response.statusCode == 409) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: This username is already taken."),
            duration: Duration(milliseconds: 1500),
          ),
        );
        return false; // false to keep the dialog box open
      }
      // Username was successfully updated
      else if (response.statusCode == 200) {
        // Update locally so the UI reflects the change immediately
        currentUserData!.username = updatedUsername;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Success! Username updated."),
            duration: Duration(milliseconds: 1500),
          ),
        );
        return true;
      } else {
        // Backend rejected the update (username taken)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? "Error updating username."),
            duration: Duration(milliseconds: 1500),
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
            duration: Duration(milliseconds: 1500),
          ),
        );
        return true; // to close the dialog
      }

      // Other error messages unrelated to no connection
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error updating username: $e"),
          duration: Duration(milliseconds: 1500),
        ),
      );
      return false;
    }
  }

  // Method to initialize FCM token on app startup and add it to Postgres if not already present, ensuring no duplicates
  Future<void> initializeFcmToken(String deviceToken) async {
    try {
      // Add token locally if not already present (guard against race condition where currentUserData may not be set yet)
      if (currentUserData != null &&
          !currentUserData!.fcmTokens.contains(deviceToken)) {
        currentUserData!.fcmTokens.add(deviceToken);
      }

      await http.post(
        Uri.parse('$backendBaseUrl/add_fcm_token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_token': await getIdToken(),
          'token': deviceToken,
        }),
      );
    } catch (e) {
      debugPrint("Error initializing FCM token: $e");
    }
  }

  // Adds this device's FCM token to Postgres (called on token refresh)
  Future<void> addFcmToken(String deviceToken, {String? oldToken}) async {
    try {
      // clear the stale token
      if (oldToken != null) await removeFcmToken(oldToken);

      // Update local list if not already present
      if (currentUserData != null &&
          !currentUserData!.fcmTokens.contains(deviceToken)) {
        currentUserData!.fcmTokens.add(deviceToken);
      }

      await http.post(
        Uri.parse('$backendBaseUrl/add_fcm_token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_token': await getIdToken(),
          'token': deviceToken,
        }),
      );
    } catch (e) {
      debugPrint("Error adding FCM token: $e");
    }
  }

  // Removes this device's FCM token from Postgres (called on logout)
  Future<void> removeFcmToken(String deviceToken) async {
    try {
      // Remove token from local list
      currentUserData!.fcmTokens.remove(deviceToken);

      await http.post(
        Uri.parse('$backendBaseUrl/remove_fcm_token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_token': await getIdToken(),
          'token': deviceToken,
        }),
      );
    } catch (e) {
      debugPrint("Error removing FCM token: $e");
    }
  }

  // Method for updating the user's notification preference and storing it
  Future<void> updateNotificationsEnabled(
    bool enabled,
    BuildContext context,
  ) async {
    try {
      // Update locally so the UI reflects the change immediately
      currentUserData!.notificationsEnabled = enabled;

      final response = await http
          .post(
            Uri.parse('$backendBaseUrl/update_notifications'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'id_token': await getIdToken(),
              'enabled': enabled,
            }),
          )
          .timeout(Duration(seconds: 5));

      if (response.statusCode != 200) {
        throw Exception(
          'update_notifications failed: ${response.statusCode} ${response.body}',
        );
      }

      // Default confirmation snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Notification prefences updated successfully."),
          duration: Duration(milliseconds: 500),
        ),
      );
    } catch (e) {
      // No connection so the update cannot be completed
      if (!isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("No connection. Please try again when online."),
            duration: Duration(milliseconds: 1500),
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
        SnackBar(
          content: Text(message),
          duration: Duration(milliseconds: 1500),
        ),
      );
    }
  }

  // Method that silently stores the user's timezone based on UTC offset
  Future<void> updateUtcOffset() async {
    try {
      final offset = DateTime.now().timeZoneOffset.inMinutes;
      await http
          .post(
            Uri.parse('$backendBaseUrl/update_utc_offset_minutes'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'id_token': await getIdToken(),
              'utc_offset': offset,
            }),
          )
          .timeout(Duration(seconds: 5));
    } catch (e) {
      debugPrint('Error updating utc offset: $e');
    }
  }

  // Method for updating the app theme color and storing it
  Future<void> updateAppColor(Color newColor, BuildContext context) async {
    try {
      // Update locally
      currentUserData!.appColor = newColor;

      // Convert color to int
      final int argbInt = newColor.toARGB32();

      // Flag for checking if the chosen color is the "Default color" atribute
      bool isDefaultColor = false;
      if (argbInt == 4281150765) {
        isDefaultColor = true;
      }

      final response = await http
          .post(
            Uri.parse('$backendBaseUrl/update_app_color'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'id_token': await getIdToken(),
              'app_color': argbInt,
            }),
          )
          .timeout(Duration(seconds: 5));

      if (response.statusCode != 200) {
        throw Exception(
          'update_app_color failed: ${response.statusCode} ${response.body}',
        );
      }

      // Default confirmation snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            // conditionally mention whether it was updated to a custom color or reset
            isDefaultColor ? "Theme color reset!" : "Theme color updated!",
          ),
          duration: Duration(milliseconds: 1500),
        ),
      );
    } catch (e) {
      // No connection so the update cannot be completed
      if (!isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("No connection. Please try again when online."),
            duration: Duration(milliseconds: 1500),
          ),
        );
        return;
      }

      String message;

      if (e is TimeoutException) {
        message = "Connection is slow. Please try again.";
      } else {
        message = "Error updating theme color.";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: Duration(milliseconds: 1500),
        ),
      );
    }
  }

  Future<void> updateFoodDataByDate(
    Map<String, Map<String, List<Map<String, dynamic>>>> newFoodData, {
    BuildContext? context,
    bool isBeingDeleted = false,
  }) async {
    try {
      // Update locally so the UI reflects the change immediately
      currentUserData?.foodDataByDate = newFoodData;

      // Write each date as its own row in Postgres via the backend
      for (final entry in newFoodData.entries) {
        final dateKey = entry.key;
        final meals = entry.value;

        final response = await http
            .post(
              Uri.parse('$backendBaseUrl/upsert_food_log'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'id_token': await getIdToken(),
                'date': dateKey,
                'breakfast': meals['breakfast'] ?? [],
                'lunch': meals['lunch'] ?? [],
                'dinner': meals['dinner'] ?? [],
                'snack': meals['snacks'] ?? [],
              }),
            )
            .timeout(Duration(seconds: 10));

        if (response.statusCode != 200) {
          throw Exception(
            'upsert_food_log failed: ${response.statusCode} ${response.body}',
          );
        }
      }

      // Only show success snackbar if connected, otherwise the error snackbar is shown in the catch block
      final msg = isBeingDeleted
          ? "Food deleted successfully."
          : "Food logged successfully.";
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), duration: Duration(milliseconds: 1500)),
        );
      }
    } catch (e) {
      if (context != null) {
        // No connection so the update cannot be completed
        if (!isConnected) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("No connection. Please try again when online."),
              duration: Duration(milliseconds: 1500),
            ),
          );
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error updating food data: $e"),
            duration: const Duration(milliseconds: 1500),
          ),
        );
      }
    }
  }

  // Searches for food via the backend, which proxies to FatSecret API
  static Future<http.Response> searchFood(String query) async {
    final idToken = await getIdToken();
    return await http.post(
      Uri.parse('$backendBaseUrl/get_food'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id_token': idToken, 'food_name': query}),
    );
  }

  // Refreshes all user data from the backend, called on Food Logging tab switch to keep data fresh across devices
  Future<void> refreshUserData() async {
    await _fetchUserDataSafely();
  }

  // Method for calling the /update_goals route from the frontend
  Future<void> updateGoals({
    int? caloriesGoal,
    int? proteinGoal,
    int? carbsGoal,
    int? fatGoal,
    String? weightGoalType,
    BuildContext? context,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$backendBaseUrl/update_goals'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'id_token': await getIdToken(),
              'calories_goal': caloriesGoal,
              'protein_goal': proteinGoal,
              'carbs_goal': carbsGoal,
              'fat_goal': fatGoal,
              'weight_goal_type': weightGoalType,
            }),
          )
          .timeout(const Duration(seconds: 2));

      if (response.statusCode != 200) {
        throw Exception(
          'update_goals failed: ${response.statusCode} ${response.body}',
        );
      }

      // update local state
      if (currentUserData != null) {
        currentUserData!.caloriesGoal = caloriesGoal;
        currentUserData!.proteinGoal = proteinGoal;
        currentUserData!.carbsGoal = carbsGoal;
        currentUserData!.fatGoal = fatGoal;
        currentUserData!.weightGoalType = weightGoalType;
      }

      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Goals updated successfully."),
            duration: Duration(milliseconds: 1500),
          ),
        );
      }
    } catch (e) {
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error updating goals: $e"),
            duration: const Duration(milliseconds: 1500),
          ),
        );
      }
    }
  }
}
