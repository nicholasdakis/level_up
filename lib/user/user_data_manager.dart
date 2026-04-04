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

// Base URL for the backend hosted on Render. All backend requests go to this URL
const String _backendBaseUrl = 'https://level-up-69vz.onrender.com';

// Gets a fresh Firebase ID token, a JWT, to authenticate requests with the backend
// Firebase caches this automatically so it only re-fetches when close to expiry (1hr)
Future<String> _getIdToken() async {
  final token = await FirebaseAuth.instance.currentUser?.getIdToken();
  if (token == null) throw Exception('User not logged in');
  return token;
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
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

      // Load the user's data from both the public and private collections (critical fields are later overwritten by the backend code)
      final publicDoc = await _publicUsers.doc(uid).get();
      final privateDoc = await _privateUsers.doc(uid).get();
      final publicData = publicDoc.data();
      final privateData = privateDoc.data();

      // NOTE: else statements are for newly-added fields to be compatible with existent users

      // --- PUBLIC FIELDS ---
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

      // --- PRIVATE FIELDS ---
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

      // --- FOOD DATA (subcollection) ---
      // if the user has stored food data, load it (stored as a map of date strings to meal maps, where each meal map is a map of meal types to lists of food entries)
      final foodLogSnapshot = await _privateUsers
          .doc(uid)
          .collection('foodLog')
          .get();

      if (foodLogSnapshot.docs.isNotEmpty) {
        final Map<String, Map<String, List<Map<String, dynamic>>>> foodData =
            {};
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
        // no food data found
        currentUserData?.foodDataByDate = {};
      }

      // Load the list of reminders
      try {
        currentUserData?.reminders = await loadRemindersFromFirestore(
          currentUserData!.uid,
        );
      } catch (e) {
        debugPrint('Error loading reminders: $e');
        currentUserData?.reminders = [];
      }

      // Backend calls for critical data (level, XP, daily reward status) that can't be manipulated client-side
      // If the backend is unreachable, fall back to whatever Firestore has stored
      try {
        final progress = await _fetchProgress();
        debugPrint('Backend progress response: $progress');
        currentUserData?.level = progress['level'] ?? currentUserData?.level;
        currentUserData?.expPoints =
            progress['exp_points'] ?? currentUserData?.expPoints;
        currentUserData?.canClaimDailyReward =
            progress['can_claim_daily_reward'] ?? true;
        // keep the notifier in sync so XP bar rebuilds immediately
        expNotifier.value = currentUserData!.expPoints;
      } catch (e) {
        debugPrint(
          'Backend getProgress failed, falling back to Firestore values: $e',
        );
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
    }
  }

  // Calls the backend /get_progress endpoint to get the user's level, XP, and reward status
  // Separated into its own method so it can be called on pull-to-refresh too
  static Future<Map<String, dynamic>> _fetchProgress() async {
    final response = await http.post(
      Uri.parse('$_backendBaseUrl/get_progress'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id_token': await _getIdToken()}),
    );
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
      await _publicUsers.doc(uid).set({
        'pfpBase64': base64String,
      }, SetOptions(merge: true));

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Profile picture update unsuccessful: $e"),
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
        Uri.parse('$_backendBaseUrl/update_exp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_token': await _getIdToken(),
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
  Future<bool> claimDailyReward() async {
    try {
      final response = await http.post(
        Uri.parse('$_backendBaseUrl/claim_daily_reward'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id_token': await _getIdToken()}),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'claimDailyReward failed: ${response.statusCode} ${response.body}',
        );
      }

      final result = jsonDecode(response.body) as Map<String, dynamic>;

      if (!result['claimed']) {
        // Cooldown not met, lock the button locally
        currentUserData!.canClaimDailyReward = false;
        return false; // Not enough time has passed
      }

      // Update local state from the backend response
      currentUserData!.level = result['new_level'];
      currentUserData!.expPoints = result['new_exp'];
      currentUserData!.canClaimDailyReward = false;
      currentUserData!.lastDailyClaim = DateTime.now().toUtc();

      // keep the notifier in sync so XP bar rebuilds immediately
      expNotifier.value = result['new_exp'];

      return true; // Successfully claimed
    } catch (e) {
      debugPrint('claimDailyReward backend error: $e');
      return false;
    }
  }

  // Method for checking if a username already exists on the server
  Future<bool> usernameExists(String username) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final query = await _publicUsers
        .where(
          'username',
          isEqualTo: username.toLowerCase(),
        ) // username uniqueness is not case sensitive
        .get();

    // Check if any doc with this username belongs to another user
    for (var doc in query.docs) {
      if (doc.id != uid) {
        return true; // duplicate found for another user
      }
    }
    return false; // No duplicates. Either the user is modifying capitalization, or choosing a new username entirely
  }

  // Method for storing the user's updated username to Firebase
  Future<bool> updateUsername(
    String updatedUsername,
    BuildContext context,
  ) async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // First, check that the username is not already assigned to another user
      if (await usernameExists(updatedUsername)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: This username is taken."),
            duration: const Duration(milliseconds: 1500),
          ),
        );
        return false;
      } else {
        // Update locally
        currentUserData!.username = updatedUsername;
        // Update to users-public
        await _publicUsers.doc(uid).set({
          'username': currentUserData!.username,
        }, SetOptions(merge: true));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Success! Username updated."),
            duration: const Duration(milliseconds: 1500),
          ),
        );
        return true;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error updating username: $e"),
          duration: const Duration(milliseconds: 1500),
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
  Future<void> updateNotificationsEnabled(bool enabled) async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      currentUserData!.notificationsEnabled = enabled;
      await _privateUsers.doc(uid).update({'notificationsEnabled': enabled});
    } catch (e) {
      debugPrint("Error updating notificationsEnabled: $e");
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

      // Update users-private
      await _privateUsers.doc(uid).set({
        'appColor': argbInt,
      }, SetOptions(merge: true));

      // Confirmation
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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error updating theme color: $e"),
          duration: Duration(milliseconds: 1500),
        ),
      );
    }
  }

  Future<void> updateFoodDataByDate(
    Map<String, Map<String, List<Map<String, dynamic>>>> newFoodData, {
    BuildContext? context,
  }) async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // Update local currentUserData.foodDataByDate with the new data
      currentUserData?.foodDataByDate = newFoodData;

      // Write each date as its own document in the foodLog subcollection
      final foodLogCol = _privateUsers.doc(uid).collection('foodLog');

      for (final entry in newFoodData.entries) {
        await foodLogCol.doc(entry.key).set(entry.value);
      }

      // show confirmation snackbar
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Food data updated successfully."),
            duration: Duration(milliseconds: 1500),
          ),
        );
      }
    } catch (e) {
      // Show error snackbar if context provided
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error updating food data: $e"),
            duration: const Duration(milliseconds: 1500),
          ),
        );
      }
    }
  }
}
