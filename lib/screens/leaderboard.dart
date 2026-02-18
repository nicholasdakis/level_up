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
  // Cache for experience calculations
  final Map<int, int> _expCache = {};

  // Method to show the total experience needed for a specific user to reach their next level
  int experienceNeededForLevel(int level) {
    if (_expCache.containsKey(level)) {
      return _expCache[level]!;
    } // if the exp needed has already been cached, no need to recalculate it

    int exp = (100 * pow(1.25, level - 0.5) * 1.05 + (level * 10)).round();
    exp = (exp / 10).round() * 10; // rounds to nearest 10
    _expCache[level] = exp;
    return exp;
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
        // Decode base64 image once to improve performance
        if (data['pfpBase64'] != null) {
          data['pfpBytes'] = base64Decode(data['pfpBase64']);
        }
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
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .orderBy('level', descending: true)
                  .orderBy('expPoints', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  ); // wait for stream
                }

                // Map Firestore docs into a local users list
                final leaderboardUsers = snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  data['uid'] = doc.id;
                  if (data['pfpBase64'] != null) {
                    data['pfpBytes'] = base64Decode(data['pfpBase64']);
                  }
                  return data;
                }).toList();

                return ListView.builder(
                  padding: EdgeInsets.symmetric(vertical: screenWidth * 0.02),
                  itemCount: leaderboardUsers.length,
                  itemBuilder: (context, i) {
                    final user = leaderboardUsers[i];
                    final isCurrentUser = user['uid'] == currentUserId;
                    final level = user['level'] ?? 1;

                    return Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: screenWidth * 0.02,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isCurrentUser
                              ? Colors.white.withAlpha(
                                  64,
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
                            user['pfpBytes'] != null
                                ? Image.memory(
                                    user['pfpBytes'],
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
                              user['username'] != user['uid'] &&
                                      user['username'] != null
                                  ? user['username']
                                  : 'Unnamed',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              "Level $level | ${user['expPoints'] ?? 0} / ${experienceNeededForLevel(level)}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
