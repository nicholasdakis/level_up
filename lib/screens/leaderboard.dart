import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:convert';
import '../globals.dart';
import 'dart:math';

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
      users = leaderboard.docs.map((doc) => doc.data()).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = 1.sw;
    return Scaffold(
      backgroundColor: Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: Color(0xFF121212),
        centerTitle: true,
        title: createTitle("Leaderboard", screenWidth),
      ),
      body: users.isEmpty
          ? Center(
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
                                  ? Color(0xFFCD7F32)
                                  // All other users receive white text
                                  : Colors.white,
                              fontSize: 18,
                            ),
                          ),
                          SizedBox(width: 10),
                          // Load the user's profile picture if it exists
                          users[i]['pfpBase64'] != null
                              ? Image.memory(
                                  base64Decode(users[i]['pfpBase64']),
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                )
                              // Otherwise, load the default icon avatar
                              : Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 40,
                                ),
                          SizedBox(width: 10),
                          Text(
                            // Only show the user's username if it exists and is not the default username (their UID)
                            users[i]['username'] != null &&
                                    users[i]['username'] != users[i]['uid']
                                ? users[i]['username']
                                : 'Unnamed',
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                          Spacer(),
                          Text(
                            "Level ${users[i]['level'] ?? 1} | ${users[i]['expPoints'] ?? 0} / ${experienceNeededForLevel(users[i]['level'] ?? 1)}",
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                          SizedBox(width: 10),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
