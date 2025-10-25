import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../globals.dart';
import 'user_data.dart';

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

  // Loads the user's profile picture, level, experience, and username from Firebase if they exist
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
          username: uid, // default username is uid
        );
      }
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      // if the user has a stored profile picture in Base64, load that profile picture
      if (doc.exists && doc.data()?['pfpBase64'] != null) {
        currentUserData?.pfpBase64 = doc.data()?['pfpBase64'];
      }
      // if the user has a stored level, load that level
      if (doc.exists && doc.data()?['level'] != null) {
        currentUserData?.level = doc.data()?['level'];
      }
      // if the user has stored expPoints, load them
      if (doc.exists && doc.data()?['expPoints'] != null) {
        currentUserData?.expPoints = doc.data()?['expPoints'];
      }
      // if the user has a stored username, load it
      if (doc.exists && doc.data()?['username'] != null) {
        currentUserData?.username = doc.data()?['username'];
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

  Future<void> updateProfilePicture(
    File file, {
    VoidCallback? onProfileUpdated,
    BuildContext? context, // for error snackbar
  }) async {
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
        username: currentUserData!.username,
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
}
