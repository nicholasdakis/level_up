import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/providers/user_data_provider.dart';
import '/services/user_data_manager.dart' show defaultAppColor;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:level_up/utility/responsive.dart';
import '../globals.dart';
import '../guest.dart';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/leaderboard_entry.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart' hide ShimmerEffect;
import 'package:hugeicons/hugeicons.dart';

enum _LeaderboardType { xp, foods, workouts }

enum _LeaderboardPeriod { allTime, monthly, weekly }

class Leaderboard extends ConsumerStatefulWidget {
  const Leaderboard({super.key});

  @override
  ConsumerState<Leaderboard> createState() => _LeaderboardState();
}

class _LeaderboardState extends ConsumerState<Leaderboard> {
  Color get appColor => ref.watch(
    userDataProvider.select((s) => s.value?.appColor ?? defaultAppColor),
  );

  // Cache for experience calculations
  final Map<int, int> _expCache = {};
  // Tracks which card indices have already played their entrance animation
  final Set<int> _animatedIndices = {};
  late Future<List<LeaderboardEntry>> _leaderboardFuture;

  _LeaderboardType _selectedType = _LeaderboardType.xp;
  _LeaderboardPeriod _selectedPeriod = _LeaderboardPeriod.allTime;

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
    FirebaseAnalytics.instance.logScreenView(
      screenName: '/leaderboard',
      screenClass: 'Leaderboard',
    );
    _leaderboardFuture = leaderboardService.fetchLeaderboard(
      type: _lbType,
      period: _lbPeriod,
    );
    if (isGuest) Guest.blockOnOpen(context); // For guest users
  }

  @override
  void dispose() {
    super.dispose();
  }

  String get _lbType {
    switch (_selectedType) {
      case _LeaderboardType.xp:
        return 'xp';
      case _LeaderboardType.foods:
        return 'foods';
      case _LeaderboardType.workouts:
        return 'workouts';
    }
  }

  String get _lbPeriod {
    switch (_selectedPeriod) {
      case _LeaderboardPeriod.allTime:
        return 'all_time';
      case _LeaderboardPeriod.monthly:
        return 'monthly';
      case _LeaderboardPeriod.weekly:
        return 'weekly';
    }
  }

  void _refreshLeaderboard() {
    _animatedIndices.clear();
    setState(() {
      _leaderboardFuture = leaderboardService.fetchLeaderboard(
        type: _lbType,
        period: _lbPeriod,
        forceRefresh: true,
      );
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
    final isXp = _selectedType == _LeaderboardType.xp;
    final expNeeded = experienceNeededForLevel(user.level);
    // XP progress toward next level (0.0 to 1.0)
    final progressFraction = (user.expPoints / expNeeded).clamp(0.0, 1.0);

    String subtext() {
      if (!isXp) {
        final n = user.count ?? 0;
        if (_selectedType == _LeaderboardType.foods) return "$n foods logged";
        if (_selectedType == _LeaderboardType.workouts) return "$n workouts";
      }
      return "Level ${user.level}";
    }

    String trailingText() {
      if (!isXp) return "${user.count ?? 0}";
      return "${user.expPoints} / $expNeeded";
    }

    // The frosted glass card for this leaderboard entry
    final Widget card = frostedGlassCard(
      context,
      color: appColor,
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
              ? lightenColor(appColor, 0.15)
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
                // Username and subtext
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
                        subtext(),
                        style: GoogleFonts.manrope(
                          color: Colors.white60,
                          fontSize: Responsive.font(context, 12),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  trailingText(),
                  style: GoogleFonts.manrope(
                    color: Colors.white38,
                    fontSize: Responsive.font(context, 12),
                  ),
                ),
              ],
            ),
            if (isXp) ...[
              SizedBox(height: Responsive.height(context, 10)),
              // XP progress bar toward next level
              ClipRRect(
                borderRadius: BorderRadius.circular(
                  Responsive.scale(context, 6),
                ),
                child: LinearProgressIndicator(
                  value: progressFraction,
                  minHeight: Responsive.height(context, 8),
                  backgroundColor: Colors.white.withAlpha(20),
                  valueColor: AlwaysStoppedAnimation<Color>(appColor),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: Responsive.height(context, 10)),
      child: card,
    );
  }

  Widget _buildTypeChips() {
    final accent = lightenColor(appColor, 0.45);
    final dim = lightenColor(appColor, 0.30);

    final types = [
      (_LeaderboardType.xp, HugeIcons.strokeRoundedStar, "XP"),
      (_LeaderboardType.foods, HugeIcons.strokeRoundedRestaurant03, "Foods"),
      (
        _LeaderboardType.workouts,
        HugeIcons.strokeRoundedDumbbell01,
        "Workouts",
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = Responsive.width(context, 8);
        final chipWidth =
            (constraints.maxWidth - gap * (types.length - 1)) / types.length;
        return Row(
          children: [
            for (int i = 0; i < types.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              GestureDetector(
                onTap: () {
                  if (_selectedType != types[i].$1) {
                    setState(() {
                      _selectedType = types[i].$1;
                      if (types[i].$1 == _LeaderboardType.xp) {
                        _selectedPeriod = _LeaderboardPeriod.allTime;
                      }
                    });
                    _refreshLeaderboard();
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: chipWidth,
                  padding: EdgeInsets.symmetric(
                    vertical: Responsive.height(context, 7),
                  ),
                  decoration: BoxDecoration(
                    color: _selectedType == types[i].$1
                        ? appColor.withAlpha(60)
                        : Colors.white.withAlpha(10),
                    borderRadius: BorderRadius.circular(
                      Responsive.scale(context, 20),
                    ),
                    border: Border.all(
                      color: _selectedType == types[i].$1
                          ? accent.withAlpha(180)
                          : dim.withAlpha(60),
                      width: 1.2,
                    ),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HugeIcon(
                          icon: types[i].$2,
                          color: _selectedType == types[i].$1 ? accent : dim,
                          size: Responsive.scale(context, 13),
                        ),
                        SizedBox(width: Responsive.width(context, 5)),
                        Text(
                          types[i].$3,
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 12),
                            fontWeight: FontWeight.w600,
                            color: _selectedType == types[i].$1 ? accent : dim,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildPeriodToggle() {
    final accent = lightenColor(appColor, 0.45);
    final dim = lightenColor(appColor, 0.30);

    final periods = [
      (_LeaderboardPeriod.allTime, "All time"),
      (_LeaderboardPeriod.monthly, "Monthly"),
      (_LeaderboardPeriod.weekly, "Weekly"),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = Responsive.width(context, 8);
        final chipWidth =
            (constraints.maxWidth - gap * (periods.length - 1)) /
            periods.length;
        return Row(
          children: [
            for (int i = 0; i < periods.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              GestureDetector(
                onTap: () {
                  if (_selectedPeriod != periods[i].$1) {
                    setState(() => _selectedPeriod = periods[i].$1);
                    _refreshLeaderboard();
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: chipWidth,
                  padding: EdgeInsets.symmetric(
                    vertical: Responsive.height(context, 7),
                  ),
                  decoration: BoxDecoration(
                    color: _selectedPeriod == periods[i].$1
                        ? appColor.withAlpha(60)
                        : Colors.white.withAlpha(10),
                    borderRadius: BorderRadius.circular(
                      Responsive.scale(context, 20),
                    ),
                    border: Border.all(
                      color: _selectedPeriod == periods[i].$1
                          ? accent.withAlpha(180)
                          : dim.withAlpha(60),
                      width: 1.2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      periods[i].$2,
                      style: GoogleFonts.manrope(
                        fontSize: Responsive.font(context, 12),
                        fontWeight: FontWeight.w600,
                        color: _selectedPeriod == periods[i].$1 ? accent : dim,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get current user's UID to highlight their row
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Container(
      decoration: BoxDecoration(gradient: buildThemeGradient(appColor)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: FutureBuilder<List<LeaderboardEntry>>(
          future: _leaderboardFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                showFrostedAlertDialog(
                  context: context,
                  appColor: appColor,
                  title: "Failed to load",
                  content: Text(
                    "Failed to load the leaderboard.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.pop();
                      },
                      child: Text(
                        "Go back",
                        style: GoogleFonts.manrope(
                          color: lightenColor(appColor, 0.40),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _refreshLeaderboard();
                      },
                      child: Text(
                        "Retry",
                        style: GoogleFonts.manrope(
                          color: lightenColor(appColor, 0.45),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                );
              });
            }

            // Uses the skeleton entries while loading and real data once loaded
            final isLoading =
                !snapshot.hasData ||
                snapshot.connectionState == ConnectionState.waiting;
            final leaderboardUsers = isLoading
                ? _skeletonEntries
                : snapshot.data!;

            if (!isLoading && leaderboardUsers.isEmpty) {
              return Column(
                children: [
                  SizedBox(height: MediaQuery.paddingOf(context).top),
                  Padding(
                    padding: EdgeInsets.only(
                      top: Responsive.height(context, 8),
                      left: Responsive.centeredHorizontalPadding(context, 20),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          padding: EdgeInsets.all(
                            Responsive.scale(context, 12),
                          ),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: lightenColor(appColor, 0.1).withAlpha(20),
                            border: Border.all(
                              color: lightenColor(appColor, 0.3).withAlpha(180),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new,
                            color: lightenColor(appColor, 0.3).withAlpha(180),
                            size: Responsive.font(context, 13),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        isGuest
                            ? "Create an account to see the leaderboard"
                            : "No users found",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                ],
              );
            }

            final hPad = Responsive.centeredHorizontalPadding(context, 20);

            return Skeletonizer(
              enabled: isLoading,
              effect: ShimmerEffect(
                baseColor: lightenColor(appColor, 0.3),
                highlightColor: lightenColor(appColor, 0.1),
                duration: const Duration(milliseconds: 1200),
              ),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: hPad,
                        right: hPad,
                        top:
                            MediaQuery.paddingOf(context).top +
                            Responsive.height(context, 16),
                        bottom: Responsive.height(context, 12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Back and refresh buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: () => context.pop(),
                                child: Container(
                                  padding: EdgeInsets.all(
                                    Responsive.scale(context, 12),
                                  ),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: lightenColor(
                                      appColor,
                                      0.1,
                                    ).withAlpha(20),
                                    border: Border.all(
                                      color: lightenColor(
                                        appColor,
                                        0.3,
                                      ).withAlpha(180),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.arrow_back_ios_new,
                                    color: lightenColor(
                                      appColor,
                                      0.3,
                                    ).withAlpha(180),
                                    size: Responsive.font(context, 13),
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: _refreshLeaderboard,
                                child: Container(
                                  padding: EdgeInsets.all(
                                    Responsive.scale(context, 12),
                                  ),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: lightenColor(
                                      appColor,
                                      0.1,
                                    ).withAlpha(20),
                                    border: Border.all(
                                      color: lightenColor(
                                        appColor,
                                        0.3,
                                      ).withAlpha(180),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.refresh,
                                    color: lightenColor(
                                      appColor,
                                      0.3,
                                    ).withAlpha(180),
                                    size: Responsive.font(context, 13),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: Responsive.height(context, 16)),
                          _buildTypeChips(),
                          ClipRect(
                            child: AnimatedAlign(
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeInOut,
                              alignment: Alignment.topCenter,
                              heightFactor: _selectedType != _LeaderboardType.xp
                                  ? 1.0
                                  : 0.0,
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 300),
                                opacity: _selectedType != _LeaderboardType.xp
                                    ? 1.0
                                    : 0.0,
                                child: Column(
                                  children: [
                                    SizedBox(
                                      height: Responsive.height(context, 20),
                                    ),
                                    _buildPeriodToggle(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: Responsive.height(context, 16)),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.only(
                      left: hPad,
                      right: hPad,
                      bottom: Responsive.height(context, 120),
                    ),
                    sliver: SliverList.builder(
                      itemCount: leaderboardUsers.length > 100
                          ? 100
                          : leaderboardUsers.length,
                      itemBuilder: (context, i) {
                        final user = leaderboardUsers[i];
                        final isCurrentUser = user.uid == currentUserId;
                        final card = _buildUserCard(user, i, isCurrentUser);
                        // Only the first 20 spots get the animation
                        if (isLoading ||
                            i >= 20 ||
                            _animatedIndices.contains(i)) {
                          return card;
                        }
                        _animatedIndices.add(i);
                        return card
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
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
