import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:convert';
import '../globals.dart';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart'; // needed for currentUser

class Leaderboard extends StatefulWidget {
  const Leaderboard({super.key});

  @override
  State<Leaderboard> createState() => _LeaderboardState();
}

class _LeaderboardState extends State<Leaderboard> {
  // Method to show the total experience needed for a specific user to reach their next level
  int experienceNeededForLevel(int level) {
    int exp = (100 * pow(1.25, level - 0.5) * 1.05 + (level * 10)).round();
    return (exp / 10).round() * 10; // rounds to nearest 10
  }

  // List of Leaderboard users
  List<Map<String, dynamic>> users = [];

  @override
  void initState() {
    super.initState();
    // Load the leaderboard when this tab is opened
    loadLeaderboard();
  }

  Future<void> loadLeaderboard() async {
    // Obtain the users from Firestore
    final leaderboard = await FirebaseFirestore.instance
        .collection('users')
        .orderBy('level', descending: true)
        .orderBy('expPoints', descending: true)
        .get();
    // Update the screen with the users
    setState(() {
      users = leaderboard.docs.map((doc) {
        final data = doc.data();
        data['uid'] = doc.id; // Store the UID as an additional field
        return data;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = 1.sw;

    // Get current user's UID to highlight their row
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: appColorNotifier.value.withAlpha(128), // Body color
      // Header box
      appBar: AppBar(
        backgroundColor: appColorNotifier.value.withAlpha(64), // Header color
        centerTitle: true,
        title: createTitle("Leaderboard", screenWidth),
      ),
      body: users.isEmpty
          ? const Center(
              child:
                  CircularProgressIndicator(), // Wait until the users are loaded
            )
          : SingleChildScrollView(
              // Scrollable
              child: Column(
                children: [
                  for (int i = 0; i < users.length; i++)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: screenWidth * 0.02,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: users[i]['uid'] == currentUserId
                              ? Colors.yellow.withAlpha(
                                  32,
                                ) // yellow tint to emphasize the user's profile
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            SizedBox(width: screenWidth * 0.025),
                            Text(
                              "#${i + 1}",
                              style: TextStyle(
                                color: i == 0
                                    ? Colors
                                          .yellow // #1 Gets yellow text
                                    : i == 1
                                    ? Colors
                                          .grey // #2 Gets grey text
                                    : i ==
                                          2 // #3 Gets bronze text
                                    ? const Color(0xFFCD7F32)
                                    // All other users receive white text
                                    : Colors.white,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Load the user's profile picture if it exists
                            users[i]['pfpBase64'] != null
                                ? Image.memory(
                                    base64Decode(users[i]['pfpBase64']),
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                  )
                                // Otherwise, load the default icon avatar
                                : const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                            const SizedBox(width: 10),
                            Text(
                              // Only show the user's username if it exists and is not the default username (their UID)
                              users[i]['username'] != users[i]['uid'] &&
                                      users[i]['username'] != null
                                  ? users[i]['username']
                                  : 'Unnamed',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              "Level ${users[i]['level'] ?? 1} | ${users[i]['expPoints'] ?? 0} / ${experienceNeededForLevel(users[i]['level'] ?? 1)}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
