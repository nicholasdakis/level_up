import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../globals.dart';
import 'user_data.dart';
import 'reminder_data.dart';
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

// Online connectivity checker
bool isConnected = true;

// The method acts as a stream that checks if the user is connected so that it reflects the user's current connection state
void initConnectivity() {
  Connectivity().onConnectivityChanged.listen((statusList) {
    isConnected = !statusList.contains(ConnectivityResult.none);
  });
}

class UserDataManager {
  // Firestore collection references
  // Currently still used for non-critical data, like reminders, settings, app theme, etc.
  static CollectionReference<Map<String, dynamic>> get _publicUsers =>
      FirebaseFirestore.instance.collection('users-public');
  static CollectionReference<Map<String, dynamic>> get _privateUsers =>
      FirebaseFirestore.instance.collection('users-private');

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

  // Load the user's "reminders" collection from Firestore
  Future<List<ReminderData>> loadRemindersFromFirestore(String uid) async {
    final remindersSnapshot = await _privateUsers
        .doc(uid)
        .collection('reminders')
        .get();
    // empty list if non-existent
    if (remindersSnapshot.docs.isEmpty) return [];

    return remindersSnapshot.docs
        .map((doc) => ReminderData.fromMap(doc.data()))
        .toList();
  }

  // Loads the user's non-critical information from Firebase if it exists (critical data is loaded by the backend)
  Future<void> loadUserData() async {
    final stopwatch = Stopwatch()..start();
    // Initialize the connectivity stream to know the user's connectivity state
    initConnectivity();
    debugPrint(
      'initConnectivity happened at ${stopwatch.elapsedMilliseconds}ms',
    );

    final uid = FirebaseAuth.instance.currentUser?.uid;
    debugPrint('Setting uid happened at ${stopwatch.elapsedMilliseconds}ms');
    // if the user is logged in

    if (uid != null) {
      // Initialize currentUserData if it's null or has the wrong UID
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

      // Load the user's data in parallel (critical fields are later overwritten by the backend code)
      final results = await Future.wait([
        // Run in parallel instead of sequentially to load faster
        _publicUsers.doc(uid).get(),
        _privateUsers.doc(uid).get(),
      ]);
      debugPrint(
        'Future.wait on the public and private documents happened at ${stopwatch.elapsedMilliseconds}ms',
      );

      // The data as DocumentSnapshot
      final publicDoc = results[0];
      final privateDoc = results[1];

      // The data as Map<String, dynamic>
      final publicData = publicDoc.data();
      final privateData = privateDoc.data();

      // If the loads failed, there is nothing for the method to work with
      if (!publicDoc.exists && !privateDoc.exists) {
        return; // nothing to work with
      }

      // NOTE: else statements are for newly-added fields to be compatible with existent users

      // if the user has a stored profile picture in Base64, load that profile picture
      if (publicDoc.exists && publicData?['pfpBase64'] != null) {
        currentUserData?.pfpBase64 = publicData?['pfpBase64'];
      } else {
        _publicUsers.doc(uid).set({'pfpBase64': null}, SetOptions(merge: true));
      }

      // if the user has a stored username, load it
      if (publicDoc.exists && publicData?['username'] != null) {
        currentUserData?.username = publicData?['username'];
      } else {
        _publicUsers.doc(uid).set({'username': uid}, SetOptions(merge: true));
      }

      // load the last claiming date if it exists
      if (privateDoc.exists && privateData?['lastDailyClaim'] != null) {
        // Convert to Timestamp so Firestore understands (Firestore stores dates as Timestamp, not DateTime)
        final timestamp = privateData?['lastDailyClaim'] as Timestamp?;
        currentUserData?.lastDailyClaim = timestamp?.toDate();
      } else {
        currentUserData?.lastDailyClaim = null;
        await _privateUsers.doc(uid).set({
          'lastDailyClaim': null,
        }, SetOptions(merge: true));
      }

      // if the user has stored fcmTokens, load them
      if (privateDoc.exists && privateData?['fcmTokens'] != null) {
        List<dynamic> tokensFromFirestore = privateData?['fcmTokens'];
        currentUserData?.fcmTokens = tokensFromFirestore
            .map((token) => token.toString())
            .toList();
      } else {
        _privateUsers.doc(uid).set({'fcmTokens': []}, SetOptions(merge: true));
      }

      // if the user has a stored notificationsEnabled, load it
      if (privateDoc.exists && privateData?['notificationsEnabled'] != null) {
        currentUserData?.notificationsEnabled =
            privateData?['notificationsEnabled'];
      } else {
        currentUserData?.notificationsEnabled = true;
        _privateUsers.doc(uid).set({
          'notificationsEnabled': true,
        }, SetOptions(merge: true));
      }

      // if the user has a stored app theme color, load it
      if (privateDoc.exists && privateData?['appColor'] != null) {
        final int storedColor = privateData?['appColor'];
        currentUserData?.appColor = Color(storedColor);
        // update ValueNotifier with the stored value so HomeScreen is correct on initialization
        appColorNotifier.value = currentUserData!.appColor;
      } else {
        // default theme color
        currentUserData?.appColor = const Color.fromARGB(
          255,
          45,
          45,
          45,
        ); // default app theme color
      }

      // Await operations run in parallel
      await Future.wait([
        _loadFoodDataSafely(uid),
        _loadRemindersSafely(uid),
        _fetchProgressSafely(
          publicDoc,
          privateDoc,
          publicData,
          privateData,
          uid,
        ),
      ]);
    }
    stopwatch.stop();
    debugPrint('loadUserData took ${stopwatch.elapsedMilliseconds}ms');
  }

  // Method to safely call loadFoodData
  Future<void> _loadFoodDataSafely(String uid) async {
    final stopwatch = Stopwatch()..start();
    try {
      await loadFoodData(uid);
    } catch (e) {
      // The data never gets overwritten if the method fails, so it uses the default empty value given in loadUserData()
      debugPrint("Loading food failed.");
    }
    stopwatch.stop();
    debugPrint('Food Data took ${stopwatch.elapsedMilliseconds}ms');
  }

  // Method to safely load reminders from Firestore
  Future<void> _loadRemindersSafely(String uid) async {
    final stopwatch = Stopwatch()..start();
    try {
      currentUserData?.reminders = await loadRemindersFromFirestore(
        currentUserData!.uid,
      );
    } catch (e) {
      debugPrint('Error loading reminders: $e');
      currentUserData?.reminders = [];
    }
    stopwatch.stop();
    debugPrint('Reminders took ${stopwatch.elapsedMilliseconds}ms');
  }

  // Method to safely load the user's data from Firestore using the backend. If the backend is unreachable, fall back to what Firestore had stored
  Future<void> _fetchProgressSafely(
    DocumentSnapshot publicDoc,
    DocumentSnapshot privateDoc,
    Map<String, dynamic>? publicData,
    Map<String, dynamic>? privateData,
    String uid,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      final progress = await _fetchProgress();
      currentUserData?.level = progress['level'] ?? currentUserData?.level;
      currentUserData?.expPoints =
          progress['exp_points'] ?? currentUserData?.expPoints;
      currentUserData?.canClaimDailyReward =
          progress['can_claim_daily_reward'] ?? true;
      // keep the notifier in sync so XP bar rebuilds immediately
      expNotifier.value = currentUserData!.expPoints;
    } catch (e) {
      // fall back to Firestore for level and XP if the backend is unreachable
      if (publicDoc.exists && publicData?['level'] != null) {
        currentUserData?.level = publicData?['level'];
      } else {
        _publicUsers.doc(uid).set({'level': 1}, SetOptions(merge: true));
      }
      if (publicDoc.exists && publicData?['expPoints'] != null) {
        currentUserData?.expPoints = publicData?['expPoints'];
      } else {
        _publicUsers.doc(uid).set({'expPoints': 0}, SetOptions(merge: true));
      }
      // fall back to a local cooldown check if the backend is unreachable
      final lastClaimTimestamp = privateData?['lastDailyClaim'] as Timestamp?;
      if (lastClaimTimestamp == null) {
        currentUserData?.canClaimDailyReward = true;
      } else {
        // not exploitable since the backend is unreachable, so the user can't claim rewards anyway
        final lastClaim = lastClaimTimestamp.toDate().toUtc();
        final now = DateTime.now().toUtc();
        currentUserData?.canClaimDailyReward = now.isAfter(
          lastClaim.add(const Duration(hours: 23)),
        );
      }
    }
    stopwatch.stop();
    debugPrint('fetch progress took ${stopwatch.elapsedMilliseconds}ms');
  }

  // Loads the user's food log from Firestore, called on initial load and on Food Logging tab switch to keep data fresh across devices
  Future<void> loadFoodData(String uid) async {
    final foodLogSnapshot = await _privateUsers
        .doc(uid)
        .collection('foodLog')
        .get();
    if (foodLogSnapshot.docs.isNotEmpty) {
      final Map<String, Map<String, List<Map<String, dynamic>>>> foodData = {};
      for (final dateDoc in foodLogSnapshot.docs) {
        final dateKey = dateDoc.id;
        final mealMap = dateDoc.data();
        foodData[dateKey] = mealMap.map((mealType, foods) {
          final foodList = (foods as List<dynamic>)
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
          return MapEntry(mealType, foodList);
        });
      }
      currentUserData?.foodDataByDate = foodData;
    } else {
      currentUserData?.foodDataByDate = {};
    }
  }

  // Calls the backend /get_progress endpoint to get the user's level, XP, and reward status
  // Separated into its own method so it can be called on pull-to-refresh too
  static Future<Map<String, dynamic>> _fetchProgress() async {
    final token = await getIdToken();
    final response = await http
        .post(
          Uri.parse('$backendBaseUrl/get_progress'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'id_token': token}),
        )
        .timeout(Duration(seconds: 2));
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
        750 *
        1024; // max limit for base64 images to be stored in Firebase freely

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
        750 *
        1024; // max limit for base64 images to be stored in Firebase freely

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
    // 750 KB size limit in bytes (To meet the 1 MB Firebase limit when converted to base64)
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
      // Save Base64 string to users-public
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await _publicUsers
          .doc(uid)
          .set({'pfpBase64': base64String}, SetOptions(merge: true))
          .timeout(Duration(seconds: 2));

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
      // Default snackbar for if the user is offline (the write fails but adds it to the cache)
      if (!isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Profile picture updated locally. Changes will sync when connection is restored.",
            ),
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
  // The backend checks the event actually happened in Firestore before awarding any XP
  Future<void> updateExpPoints(
    String event,
    String eventId, {
    BuildContext? context,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$backendBaseUrl/update_exp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_token': await getIdToken(),
          'event': event,
          'event_id': eventId,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'updateExpPoints failed: ${response.statusCode} ${response.body}',
        );
      }

      final result = jsonDecode(response.body) as Map<String, dynamic>;

      // only update locally if the backend actually awarded XP
      if (result['new_level'] != null && result['new_exp'] != null) {
        currentUserData!.level = result['new_level'];
        currentUserData!.expPoints = result['new_exp'];
        expNotifier.value = result['new_exp'];
      }
    } catch (e) {
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error updating experience points: $e"),
            duration: const Duration(milliseconds: 1500),
          ),
        );
      }
    }
  }

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

      // keep the notifier in sync so XP bar rebuilds immediately
      expNotifier.value = result['new_exp'];

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
          .timeout(Duration(seconds: 2));

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

  // Method to initialize FCM token on app startup and add it to Firestore if not already present, ensuring no duplicates
  Future<void> initializeFcmToken(String deviceToken) async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // Add token locally if not already present (guard against race condition where currentUserData may not be set yet)
      if (currentUserData != null &&
          !currentUserData!.fcmTokens.contains(deviceToken)) {
        currentUserData!.fcmTokens.add(deviceToken);
      }

      await _privateUsers.doc(uid).update({
        'fcmTokens': FieldValue.arrayUnion([deviceToken]),
      });
    } catch (e) {
      debugPrint("Error initializing FCM token: $e");
    }
  }

  // Adds this device's FCM token to Firestore (called on token refresh)
  Future<void> addFcmToken(String deviceToken) async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // Update local list if not already present
      if (currentUserData != null &&
          !currentUserData!.fcmTokens.contains(deviceToken)) {
        currentUserData!.fcmTokens.add(deviceToken);
      }

      await _privateUsers.doc(uid).update({
        'fcmTokens': FieldValue.arrayUnion([deviceToken]),
      });
    } catch (e) {
      debugPrint("Error adding FCM token: $e");
    }
  }

  // Removes this device's FCM token from Firestore (called on logout)
  Future<void> removeFcmToken(String deviceToken) async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // Remove token from local list
      currentUserData!.fcmTokens.remove(deviceToken);

      // Remove token from Firestore array safely
      await _privateUsers.doc(uid).update({
        'fcmTokens': FieldValue.arrayRemove([deviceToken]),
      });
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
      final uid = FirebaseAuth.instance.currentUser!.uid;
      currentUserData!.notificationsEnabled = enabled;
      await _privateUsers
          .doc(uid)
          .update({'notificationsEnabled': enabled})
          .timeout(Duration(seconds: 2));

      // Default confirmation snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Notification prefences updated successfully."),
          duration: Duration(milliseconds: 500),
        ),
      );
    } catch (e) {
      // No connection, so show the local confirmation snackbar
      if (!isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Notification preferences updated locally. Changes will sync when connection is restored.",
            ),
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

  // Method for updating the app theme color and storing it
  Future<void> updateAppColor(Color newColor, BuildContext context) async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // Update locally
      currentUserData!.appColor = newColor;

      // Convert color to int
      final int argbInt = newColor.toARGB32();

      // Flag for checking if the chosen color is the "Default color" atribute
      bool isDefaultColor = false;
      if (argbInt == 4281150765) {
        isDefaultColor = true;
      }

      // Update users-private (if offline, it is added to cache)
      await _privateUsers
          .doc(uid)
          .set({'appColor': argbInt}, SetOptions(merge: true))
          .timeout(
            Duration(seconds: 2),
          ); // if it doesn't load instantly, there is likely an error, so stop trying quickly

      // Default confirmation snackbar
      if (isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              // conditionally mention whether it was updated to a custom color or reset
              isDefaultColor ? "Theme color reset!" : "Theme color updated!",
            ),
            duration: Duration(milliseconds: 1500),
          ),
        );
        // Error snackbar
      }
    } catch (e) {
      // No connection, so show the local confirmation snackbar
      if (!isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Theme color updated locally. Changes will sync when connection is restored.",
            ),
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
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // Update locally so the UI reflects the change immediately
      currentUserData?.foodDataByDate = newFoodData;

      // Write each date as its own document in the foodLog subcollection
      final foodLogCol = _privateUsers.doc(uid).collection('foodLog');

      for (final entry in newFoodData.entries) {
        // Timeout so it doesn't hang indefinitely if there is no connection
        await foodLogCol
            .doc(entry.key)
            .set(entry.value)
            .timeout(Duration(seconds: 2));
      }

      // Only show success snackbar if connected, otherwise the offline snackbar is shown in the catch block
      final msg = isBeingDeleted
          ? "Food deleted successfully."
          : "Food logged successfully.";
      if (context != null && isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), duration: Duration(milliseconds: 1500)),
        );
      }
    } catch (e) {
      if (context != null) {
        // No connection, so the write was added to Firestore's cache and will sync when connection is restored
        if (!isConnected) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Food logged locally. Changes will sync when connection is restored.",
              ),
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
}
