import 'package:flutter/material.dart';
import 'package:level_up/utility/responsive.dart';
import '../globals.dart';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import '../utility/leaderboard/leaderboard_entry.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart' hide ShimmerEffect;

class Leaderboard extends StatefulWidget {
  const Leaderboard({super.key});

  @override
  State<Leaderboard> createState() => _LeaderboardState();
}

class _LeaderboardState extends State<Leaderboard> {
  // Cache for experience calculations
  final Map<int, int> _expCache = {};
  // Tracks which card indices have already played their entrance animation
  final Set<int> _animatedIndices = {};
  late Future<List<LeaderboardEntry>> _leaderboardFuture;

  // Fake entries for the skeleton loading placeholder
  static final List<LeaderboardEntry> _skeletonEntries = List.generate(
    20,
    // Mock data for each fake user
    (i) => LeaderboardEntry(
      uid: 'skeleton_$i',
      username: BoneMock.name,
      level: 1,
      expPoints: 0,
    ),
  );

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
    _leaderboardFuture = leaderboardService.fetchLeaderboard();
  }

  void _refreshLeaderboard() {
    setState(() {
      _leaderboardFuture = leaderboardService.fetchLeaderboard();
    });
  }

  // Rank color for the top 3 users, white for everyone else
  Color _rankColor(int index) {
    if (index == 0) return Colors.yellow;
    if (index == 1) return Colors.grey;
    if (index == 2) return const Color(0xFFCD7F32);
    return Colors.white;
  }

  // Medal icon for the top 3 users
  Widget? _rankMedal(int index) {
    if (index > 2) return null;
    return Icon(
      Icons.emoji_events,
      color: _rankColor(index),
      size: Responsive.scale(context, 18),
    );
  }

  // Circular profile picture, or a default person icon if none exists
  Widget _profilePicture(LeaderboardEntry user) {
    final size = Responsive.scale(context, 40);
    if (user.pfpBytes != null) {
      return ClipOval(
        child: Image.memory(
          // Load profile picture from decoded bytes to prevent decoding the base64 string multiple times (expensive operation)
          user.pfpBytes!,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }
    return Icon(Icons.person, color: Colors.white, size: size);
  }

  // Single leaderboard entry card
  Widget _buildUserCard(LeaderboardEntry user, int index, bool isCurrentUser) {
    // Only show the user's username if it exists and is not the default username (their UID)
    final username = (user.username == null || user.username == user.uid)
        ? "Unnamed"
        : user.username!;
    final expNeeded = experienceNeededForLevel(user.level);
    // XP progress toward next level (0.0 to 1.0)
    final progressFraction = (user.expPoints / expNeeded).clamp(0.0, 1.0);

    // The frosted glass card for this leaderboard entry
    final Widget card = frostedGlassCard(
      context,
      baseRadius: 16,
      padding: EdgeInsets.zero,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.width(context, 16),
          vertical: Responsive.height(context, 12),
        ),
        // Current user gets a tinted background
        decoration: BoxDecoration(
          color: isCurrentUser
              ? lightenColor(appColorNotifier.value, 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(Responsive.scale(context, 16)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Top 3: rank gets a centered medal and their pfp in a fixed-width group
                if (_rankMedal(index) != null)
                  SizedBox(
                    width: Responsive.width(context, 125),
                    child: Row(
                      children: [
                        Text(
                          "#${index + 1}",
                          maxLines: 1,
                          style: GoogleFonts.manrope(
                            color: _rankColor(index),
                            fontSize: Responsive.font(context, 16),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        _rankMedal(index)!,
                        const Spacer(),
                        _profilePicture(user),
                      ],
                    ),
                  )
                // Non-top 3: Rank and pfp with a smaller gap
                else ...[
                  SizedBox(
                    width: Responsive.width(context, 45),
                    child: Text(
                      "#${index + 1}",
                      maxLines: 1,
                      style: GoogleFonts.manrope(
                        color: _rankColor(index),
                        fontSize: Responsive.font(context, 16),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _profilePicture(user),
                ],
                SizedBox(width: Responsive.width(context, 12)),
                // Username and level
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: GoogleFonts.manrope(
                          color: Colors.white,
                          fontSize: Responsive.font(context, 15),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: Responsive.height(context, 2)),
                      Text(
                        "Level ${user.level}",
                        style: GoogleFonts.manrope(
                          color: Colors.white60,
                          fontSize: Responsive.font(context, 12),
                        ),
                      ),
                    ],
                  ),
                ),
                // XP display
                Text(
                  "${user.expPoints} / $expNeeded",
                  style: GoogleFonts.manrope(
                    color: Colors.white38,
                    fontSize: Responsive.font(context, 12),
                  ),
                ),
              ],
            ),
            SizedBox(height: Responsive.height(context, 10)),
            // XP progress bar toward next level
            ClipRRect(
              borderRadius: BorderRadius.circular(Responsive.scale(context, 6)),
              child: LinearProgressIndicator(
                value: progressFraction,
                minHeight: Responsive.height(context, 5),
                backgroundColor: Colors.white.withAlpha(20),
                valueColor: AlwaysStoppedAnimation<Color>(
                  appColorNotifier.value,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: Responsive.height(context, 10)),
      child: card,
    );
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
          toolbarHeight: Responsive.buttonHeight(context, 120),
          title: createTitle("Leaderboard", context),
          scrolledUnderElevation:
              0, // So the appBar does not change color when the user scrolls down
          actions: [
            Padding(
              padding: EdgeInsets.all(Responsive.padding(context, 8)),
              child: IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _refreshLeaderboard,
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(Responsive.height(context, 1)),
            child: Container(
              height: Responsive.height(context, 1),
              color: Colors.white.withAlpha(25),
            ),
          ),
        ),
        body: FutureBuilder<List<LeaderboardEntry>>(
          future: _leaderboardFuture,
          builder: (context, snapshot) {
            // Check if the stream encountered an error
            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  "Error loading leaderboard",
                  style: TextStyle(color: Colors.white),
                ),
              );
            }

            // Uses the skeleton entries while loading and real data once loaded
            final isLoading =
                !snapshot.hasData ||
                snapshot.connectionState == ConnectionState.waiting;
            final leaderboardUsers = isLoading
                ? _skeletonEntries
                : snapshot.data!;

            if (!isLoading && leaderboardUsers.isEmpty) {
              return const Center(
                child: Text(
                  "No users found",
                  style: TextStyle(color: Colors.white),
                ),
              );
            }

            return Skeletonizer(
              enabled:
                  isLoading, // shows bone placeholders while loading, passes through normally when done
              effect: ShimmerEffect(
                baseColor: lightenColor(appColorNotifier.value, 0.3),
                highlightColor: lightenColor(appColorNotifier.value, 0.1),
                duration: const Duration(milliseconds: 1200),
              ),
              child: ListView.builder(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.width(context, 15),
                  vertical: Responsive.height(context, 24),
                ),
                itemCount:
                    leaderboardUsers.length >
                        100 // Only shows up to the top 100
                    ? 100
                    : leaderboardUsers.length,
                itemBuilder: (context, i) {
                  final user = leaderboardUsers[i];
                  final isCurrentUser = user.uid == currentUserId;
                  final card = _buildUserCard(user, i, isCurrentUser);
                  // Only the first 20 spots get the animation
                  if (isLoading || i >= 20 || _animatedIndices.contains(i)) {
                    return card;
                  }
                  _animatedIndices.add(
                    i,
                  ); // make sure to add a card that hasn't been animated so it is not reanimated
                  return card // card animation for each card's first appearance
                      .animate()
                      .fadeIn(
                        delay: (i * 50).clamp(0, 400).ms,
                        duration: 300.ms,
                      )
                      .slideY(
                        begin: 0.08,
                        duration: 300.ms,
                        curve: Curves.easeOut,
                      );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
