import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../globals.dart';
import 'user_data.dart';
import 'reminder_data.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../utility/image_crop_handler.dart';

class UserDataManager {
  // Firestore collection references
  static CollectionReference<Map<String, dynamic>> get _publicUsers =>
      FirebaseFirestore.instance.collection('users-public');
  static CollectionReference<Map<String, dynamic>> get _privateUsers =>
      FirebaseFirestore.instance.collection('users-private');

  // Formula for calculating experience needed for next level: 100 * 1.25^(current_level-0.5) * 1.05 + (current_level * 10), rounded to a multiple of 10
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

  // Loads the user's information from Firebase if it exists
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

      // if the user has a stored level, load that level
      if (publicDoc.exists && publicData?['level'] != null) {
        currentUserData?.level = publicData?['level'];
      } else {
        _publicUsers.doc(uid).set({'level': 1}, SetOptions(merge: true));
      }

      // if the user has stored expPoints, load them
      if (publicDoc.exists && publicData?['expPoints'] != null) {
        currentUserData?.expPoints = publicData?['expPoints'];
      } else {
        _publicUsers.doc(uid).set({'expPoints': 0}, SetOptions(merge: true));
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

      // Determine canClaimDailyReward using server timestamp only
      final lastClaimTimestamp = privateData?['lastDailyClaim'] as Timestamp?;
      if (lastClaimTimestamp == null) {
        currentUserData?.canClaimDailyReward = true;
        // Write back to Firestore so HomeScreen reads the correct value
        await _privateUsers.doc(uid).set({
          'canClaimDailyReward': true,
        }, SetOptions(merge: true));
      } else {
        await FirebaseFirestore.instance
            .collection('serverTime')
            .doc('now')
            .set({
              'currentServerTime': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

        final serverTimeSnap = await FirebaseFirestore.instance
            .collection('serverTime')
            .doc('now')
            .get();
        // null check so the app doesn't crash if the serverTime doc is missing or hasn't loaded yet
        final serverTimestamp =
            serverTimeSnap.data()?['currentServerTime'] as Timestamp?;
        if (serverTimestamp == null) {
          debugPrint("Server time not available, skipping daily reward check");
          return;
        }
        final serverTime = serverTimestamp.toDate().toUtc();

        final lastClaim = lastClaimTimestamp.toDate().toUtc();

        final canClaim = serverTime.isAfter(
          lastClaim.add(const Duration(hours: 23)),
        );
        currentUserData?.canClaimDailyReward = canClaim;
        // Write back to Firestore so HomeScreen reads the correct value
        await _privateUsers.doc(uid).set({
          'canClaimDailyReward': canClaim,
        }, SetOptions(merge: true));
      }
    }
  }

  // Returns the user's profile picture widget. Called when the user updates their profile picture.
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

  Future<void> updateExpPoints(int expGained, {BuildContext? context}) async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // Case 1. The experience gained will lead to a level up
      int newExp = expNotifier.value + expGained;
      while (newExp >= experienceNeeded!) {
        newExp -= experienceNeeded!;
        currentUserData!.level += 1; // Increase level by 1 locally
      }
      // Case 2. Experience gained without leveling up handled by while loop above

      // UPDATE LOCALLY
      currentUserData!.expPoints = newExp;

      // UPDATE ValueNotifier so UI rebuilds automatically
      expNotifier.value = newExp;

      // UPDATE TO FIRESTORE (public data)
      await _publicUsers.doc(uid).set({
        'level': currentUserData!.level,
        'expPoints': currentUserData!.expPoints,
      }, SetOptions(merge: true));
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

  // METHOD FOR CLAIMING THE DAILY REWARD AND UPDATING CANCLAIMDAILYREWARD APPROPRIATELY
  Future<bool> claimDailyReward() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final privateDocRef = _privateUsers.doc(uid);

    // Get the current lastDailyClaim from Firestore
    final doc = await privateDocRef.get();
    final data = doc.data();
    final lastClaimTimestamp = data?['lastDailyClaim'] as Timestamp?;

    // Check if 23 hours have passed since last claim
    if (lastClaimTimestamp != null) {
      final nextAllowedClaim = lastClaimTimestamp.toDate().toUtc().add(
        const Duration(hours: 23),
      );

      // Fetch server timestamp by writing and reading back
      await FirebaseFirestore.instance.collection('serverTime').doc('now').set({
        'currentServerTime': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final serverTimeSnap = await FirebaseFirestore.instance
          .collection('serverTime')
          .doc('now')
          .get();
      final serverTime =
          (serverTimeSnap.data()?['currentServerTime'] as Timestamp)
              .toDate()
              .toUtc();

      if (serverTime.isBefore(nextAllowedClaim)) {
        currentUserData!.canClaimDailyReward = false;
        return false; // Not enough time has passed
      }
    }

    // Update Firestore first with server timestamp
    await privateDocRef.set({
      'canClaimDailyReward': false,
      'lastDailyClaim': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Update local state after Firestore write
    final updatedDoc = await privateDocRef.get();
    final updatedData = updatedDoc.data();
    currentUserData!.lastDailyClaim =
        (updatedData?['lastDailyClaim'] as Timestamp).toDate().toUtc();
    currentUserData!.canClaimDailyReward = false;

    return true; // Successfully claimed
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
