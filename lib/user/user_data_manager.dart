import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../globals.dart';
import 'user_data.dart';

class UserDataManager {
  // Formula for calculating experience needed for next level: 100 * 1.25^(current_level-0.5) * 1.05 + (current_level * 10)
  int? get experienceNeeded {
    if (currentUserData == null) return null;
    return (100 * pow(1.25, currentUserData!.level - 0.5) * 1.05 +
            (currentUserData!.level * 10))
        .round();
  }

  // Loads the user's profile picture, level, and experience from Firebase if they exist
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

      // 3. Update currentUserData with the base64 string
      currentUserData = UserData(
        uid: currentUserData!.uid,
        pfpBase64: base64String,
        level: currentUserData!.level,
        expPoints: currentUserData!.expPoints,
      );

      // Call callback in case the UI must rebuild
      onProfileUpdated?.call();
    } catch (e) {
      rethrow; // Let the UI handle SnackBars
    }
  }
}
