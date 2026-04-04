import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:level_up/utility/responsive.dart';
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

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // Get current user's UID to highlight their row
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Container(
      decoration: BoxDecoration(gradient: buildThemeGradient()),
      child: Scaffold(
        backgroundColor: Colors.transparent, // Body color
        // Header box
        appBar: AppBar(
          backgroundColor: darkenColor(
            appColorNotifier.value,
            0.025,
          ), // Header color
          centerTitle: true,
          title: createTitle("Leaderboard", context),
          scrolledUnderElevation:
              0, // So the appBar does not change color when the user scrolls down
        ),
        body: StreamBuilder<QuerySnapshot>(
          // Obtain the users from Firestore in real-time
          stream: FirebaseFirestore.instance
              .collection('users-public')
              .orderBy('level', descending: true)
              .orderBy('expPoints', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            // Check if the stream encountered an error (like a missing index)
            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  "Error loading leaderboard",
                  style: TextStyle(color: Colors.white),
                ),
              );
            }

            // Wait until the users are loaded from the stream
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // Map Firestore docs into a local users list
            final leaderboardUsers = snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              data['uid'] = doc.id; // Store the UID as an additional field
              // Decode base64 image once to improve performance
              if (data['pfpBase64'] != null) {
                data['pfpBytes'] = base64Decode(data['pfpBase64']);
              }
              return data;
            }).toList();

            if (leaderboardUsers.isEmpty) {
              return const Center(
                child: Text(
                  "No users found",
                  style: TextStyle(color: Colors.white),
                ),
              );
            }

            return ListView.builder(
              padding: EdgeInsets.symmetric(
                vertical: Responsive.width(context, 20),
              ),
              itemCount: leaderboardUsers.length,
              itemBuilder: (context, i) {
                final user = leaderboardUsers[i];
                final isCurrentUser = user['uid'] == currentUserId;
                final level = user['level'] ?? 1;

                return Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: Responsive.width(context, 20),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isCurrentUser
                          ? lightenColor(appColorNotifier.value, 0.2).withAlpha(
                              35,
                            ) // Highlight current user with a light version of the app color
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: Responsive.width(context, 10),
                        ), // spacing on the left side of the row
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
                            fontSize: Responsive.font(context, 18),
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        SizedBox(
                          width: Responsive.width(context, 10),
                        ), // spacing between the rank and the profile picture
                        // Load the user's profile picture if it exists
                        user['pfpBytes'] != null
                            ? Image.memory(
                                // Load profile picture from decoded bytes to prevent decoding the base64 string multiple times (expensive operation)
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

                        SizedBox(
                          width: Responsive.width(context, 15),
                        ), // spacing between the profile picture and the username
                        Text(
                          // Only show the user's username if it exists and is not the default username (their UID)
                          user['username'] != user['uid'] &&
                                  user['username'] != null
                              ? user['username']
                              : 'Unnamed',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: Responsive.font(context, 18),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          "Level $level | ${user['expPoints'] ?? 0} / ${experienceNeededForLevel(level)}",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: Responsive.font(context, 16),
                          ),
                        ),
                        SizedBox(
                          width: Responsive.width(context, 10),
                        ), // spacing on the right side of the row
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
