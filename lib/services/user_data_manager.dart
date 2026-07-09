import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../globals.dart';
import '../guest.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

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

// Calls the backend /progress endpoint to get the user's level, XP, and reward status
// Separated into its own function so it can be called on pull-to-refresh and the leaderboard
Future<Map<String, dynamic>> fetchProgress() async {
  final response = await authenticatedGet('progress');
  if (response.statusCode == 200) {
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
  throw Exception(
    'getProgress failed: ${response.statusCode} ${response.body}',
  );
}

// silently stores the user's timezone based on UTC offset
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

class UserDataManager {
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

      if (!isBeingDeleted) {
        logAnalyticsEvent('food_logged');
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

  // Returns the user's leaderboard rank and total player count for the given type
  static Future<Map<String, dynamic>> fetchLeaderboardStanding({
    String type = 'xp',
  }) async {
    final response = await authenticatedGet('leaderboard_standing?type=$type');
    if (response.statusCode != 200) {
      throw Exception(
        'leaderboard_standing failed: ${response.statusCode} ${response.body}',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
