import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../globals.dart';
import 'user_data.dart';
import 'reminder_data.dart';

class UserDataManager {
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
    final remindersSnapshot = await FirebaseFirestore.instance
        .collection('users')
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
          lastDailyClaim: null,
          username: uid, // default username is uid
          reminders: [],
          appColor: Colors.blue,
        );
      }
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      // if the user has a stored profile picture in Base64, load that profile picture
      if (doc.exists && doc.data()?['pfpBase64'] != null) {
        currentUserData?.pfpBase64 = doc.data()?['pfpBase64'];
        // else statements are for newly-added fields to be compatible with existent users
      } else {
        FirebaseFirestore.instance.collection('users').doc(uid).set({
          'pfpBase64': null,
        }, SetOptions(merge: true));
      }

      // if the user has a stored level, load that level
      if (doc.exists && doc.data()?['level'] != null) {
        currentUserData?.level = doc.data()?['level'];
        // else statements are for newly-added fields to be compatible with existent users
      } else {
        FirebaseFirestore.instance.collection('users').doc(uid).set({
          'level': 1,
        }, SetOptions(merge: true));
      }

      // if the user has stored expPoints, load them
      if (doc.exists && doc.data()?['expPoints'] != null) {
        currentUserData?.expPoints = doc.data()?['expPoints'];
        // else statements are for newly-added fields to be compatible with existent users
      } else {
        FirebaseFirestore.instance.collection('users').doc(uid).set({
          'expPoints': 0,
        }, SetOptions(merge: true));
      }

      // load the last claiming date if it exists
      if (doc.exists && doc.data()?['lastDailyClaim'] != null) {
        // Convert to Timestamp so Firestore understands (Firestore stores dates as Timestamp, not DateTime)
        final timestamp = doc.data()?['lastDailyClaim'] as Timestamp?;
        currentUserData?.lastDailyClaim = timestamp?.toDate();
      } else {
        currentUserData?.lastDailyClaim = null;
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'lastDailyClaim': null,
        }, SetOptions(merge: true));
      }

      // load the boolean for claiming the daily reward
      final lastClaim = currentUserData?.lastDailyClaim;
      final now = DateTime.now();
      // Case 1: Can claim because 23+ hours passed, or the user has never claimed before
      if (lastClaim == null ||
          now.isAfter(lastClaim.add(Duration(hours: 23)))) {
        // update locally
        currentUserData?.canClaimDailyReward = true;
        // update to firestore
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'canClaimDailyReward': true,
        }, SetOptions(merge: true));
        // Case 2: <23 hours have passed, so cannot claim
      } else {
        currentUserData?.canClaimDailyReward = false;
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'canClaimDailyReward': false,
        }, SetOptions(merge: true));
      }

      // if the user has a stored username, load it
      if (doc.exists && doc.data()?['username'] != null) {
        currentUserData?.username = doc.data()?['username'];
        // else statements are for newly-added fields to be compatible with existent users
      } else {
        FirebaseFirestore.instance.collection('users').doc(uid).set({
          'username': uid,
        }, SetOptions(merge: true));
      }

      // if the user has a stored app theme color, load it
      if (doc.exists && doc.data()?['appColor'] != null) {
        final int storedColor = doc.data()?['appColor'];
        currentUserData?.appColor = Color(storedColor);
        // update ValueNotifier with the stored value so HomeScreen is correct on initialization
        appColorNotifier.value = currentUserData!.appColor;
      } else {
        // default theme color
        currentUserData?.appColor = Colors.blue;
      }

      // Load the list of  reminders
      try {
        currentUserData?.reminders = await loadRemindersFromFirestore(
          currentUserData!.uid,
        );
      } catch (e) {
        debugPrint('Error loading reminders: $e');
        currentUserData?.reminders = [];
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

  // boolean flag to ensure profile picture updating is valid
  Future<bool> canUpdateProfilePicture(File file, BuildContext? context) async {
    // 750 KB size limit in bytes (To meet the 1 MB Firebase limit when converted to base64)
    const int maxFileSize = 750 * 1024; // 768000 bytes

    // Check file size
    final int fileSize = file.lengthSync();
    if (fileSize > maxFileSize) {
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Profile picture must be 0.75 MB or less."),
            duration: Duration(milliseconds: 1500),
          ),
        );
      }
      return false; // early exit if file too large
    }
    return true;
  }

  Future<void> updateProfilePicture(
    File file, {
    VoidCallback? onProfileUpdated,
    BuildContext? context, // for error snackbar
  }) async {
    if (!await canUpdateProfilePicture(file, context)) {
      return;
    }

    try {
      // 1. Convert image to Base64
      final bytes = await file.readAsBytes();
      final base64String = base64Encode(bytes);

      // 2. Save Base64 string in Firestore
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'pfpBase64': base64String,
      }, SetOptions(merge: true));

      // 3. Update currentUserData with the complete stored variables with the updated profile picture
      currentUserData = UserData(
        uid: currentUserData!.uid,
        pfpBase64: base64String,
        level: currentUserData!.level,
        expPoints: currentUserData!.expPoints,
        canClaimDailyReward: currentUserData!.canClaimDailyReward,
        lastDailyClaim: currentUserData!.lastDailyClaim,
        username: currentUserData!.username,
        reminders: currentUserData!.reminders,
        appColor: currentUserData!.appColor,
      );
      // Call callback when the UI must rebuild
      onProfileUpdated?.call();
    } catch (e) {
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Profile picture update unsuccessful: $e"),
            duration: Duration(milliseconds: 1500),
          ),
        );
      }
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

      // UPDATE TO FIRESTORE
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
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
    // Returns true if reward was successfully claimed, false otherwise
    final uid = FirebaseAuth.instance.currentUser!.uid;
    DateTime? lastClaim = currentUserData!.lastDailyClaim;

    // if allowed to claim
    if (lastClaim == null ||
        DateTime.now().isAfter(lastClaim.add(Duration(hours: 23)))) {
      final now = DateTime.now();

      // Update Firestore first
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'canClaimDailyReward': false,
        'lastDailyClaim': Timestamp.fromDate(now),
      }, SetOptions(merge: true));

      // Only after Firestore update, update local state
      currentUserData!.canClaimDailyReward = false;
      currentUserData!.lastDailyClaim = now;

      return true; // Successfully claimed
    } else {
      // Not enough time passed, cannot claim
      currentUserData!.canClaimDailyReward = false;
      return false;
    }
  }

  // Method for checking if a username already exists on the server
  Future<bool> usernameExists(String username) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final query = await FirebaseFirestore.instance
        .collection('users')
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
  Future<void> updateUsername(
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
      } else {
        // Update locally
        currentUserData!.username = updatedUsername;
        // Update to Firestore
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'username': currentUserData!.username,
        }, SetOptions(merge: true));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Success! Username updated."),
            duration: const Duration(milliseconds: 1500),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error updating username: $e"),
          duration: const Duration(milliseconds: 1500),
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

      // Update Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'appColor': argbInt,
      }, SetOptions(merge: true));

      // Confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Theme color updated!"),
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
}
