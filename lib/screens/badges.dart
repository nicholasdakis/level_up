import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/providers/user_data_provider.dart';
import "package:flutter/material.dart";
import 'dart:ui';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_animate/flutter_animate.dart' hide ShimmerEffect;
import "package:google_fonts/google_fonts.dart";
import "/globals.dart";
import "/guest.dart";
import "/utility/responsive.dart";
import '/utility/confetti.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../services/user_data_manager.dart';
import 'package:go_router/go_router.dart';

// Achievement definition with tiers for the UI
class AchievementDef {
  final String id;
  final String name;
  final String description; // short text explaining what the user needs to do
  final IconData icon;
  final List<int> tiers; // milestone thresholds (e.g. [5, 10, 25])
  final String unit; // what is being counted (e.g. "levels", "visits")
  final String section; // which tab this belongs under

  const AchievementDef({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.tiers,
    required this.unit,
    required this.section,
  });
}

// Tab definitions in display order
const List<String> tabSections = [
  "PROGRESSION",
  "EXPLORE",
  "TABS",
  "FOOD",
  "WORKOUT",
  "REMINDERS",
  "PERSONALIZATION",
  "SOCIAL",
  "META",
];

// Icons stay client-side since IconData is Flutter-specific
const Map<String, IconData> _achievementIcons = {
  "level": HugeIcons.strokeRoundedStairs01,
  "daily_claims": HugeIcons.strokeRoundedCalendar02,
  "daily_claim_streak": HugeIcons.strokeRoundedFire,
  "poi_visits": HugeIcons.strokeRoundedCompass,
  "poi_categories": HugeIcons.strokeRoundedLocation10,
  "poi_regular": HugeIcons.strokeRoundedRepeat,
  "open_food_logging": HugeIcons.strokeRoundedPencil,
  "open_explore": HugeIcons.strokeRoundedLocation01,
  "open_reminders": HugeIcons.strokeRoundedAlarmClock,
  "open_badges": HugeIcons.strokeRoundedCrown,
  "open_leaderboard": HugeIcons.strokeRoundedMedal01,
  "food_logs": HugeIcons.strokeRoundedNote,
  "food_recent": HugeIcons.strokeRoundedClock01,
  "food_full_day": HugeIcons.strokeRoundedRestaurant03,
  "food_streak": HugeIcons.strokeRoundedCalendar02,
  "food_manual": HugeIcons.strokeRoundedEdit01,
  "food_barcode": HugeIcons.strokeRoundedQrCode,
  "food_search": HugeIcons.strokeRoundedSearch01,
  "calorie_calculator": HugeIcons.strokeRoundedCalculate,
  "serving_calculator": HugeIcons.strokeRoundedCalculator,
  "night_owl": HugeIcons.strokeRoundedMoon02,
  "early_bird": HugeIcons.strokeRoundedSun03,
  "set_reminder": HugeIcons.strokeRoundedNotification01,
  "delete_reminder": HugeIcons.strokeRoundedDelete02,
  "future_reminder": HugeIcons.strokeRoundedCalendarAdd01,
  "active_reminders": HugeIcons.strokeRoundedNotification02,
  "set_username": HugeIcons.strokeRoundedUserCircle,
  "set_pfp": HugeIcons.strokeRoundedCamera01,
  "change_app_color": HugeIcons.strokeRoundedColors,
  "send_feedback": HugeIcons.strokeRoundedComment01,
  "switch_imperial": HugeIcons.strokeRoundedRuler,
  "color_indecisive": HugeIcons.strokeRoundedColorPicker,
  "change_username": HugeIcons.strokeRoundedUserCircle,
  "workouts_logged": HugeIcons.strokeRoundedDumbbell01,
  "workout_streak": HugeIcons.strokeRoundedFire,
  "double_session": HugeIcons.strokeRoundedDumbbell02,
  "muscle_variety": HugeIcons.strokeRoundedActivity01,
  "early_workout": HugeIcons.strokeRoundedSun03,
  "late_workout": HugeIcons.strokeRoundedMoon02,
  "referrals": HugeIcons.strokeRoundedUserAdd01,
  "total_achievements": HugeIcons.strokeRoundedMedal02,
};

class Badges extends ConsumerStatefulWidget {
  const Badges({super.key});

  @override
  ConsumerState<Badges> createState() {
    return _BadgesState();
  }
}

class _BadgesState extends ConsumerState<Badges> with TickerProviderStateMixin {
  Color get appColor => ref.watch(
    userDataProvider.select((s) => s.value?.appColor ?? defaultAppColor),
  );

  bool _isLoading = true; // for the skeletonizer
  // Populated from the backend on init
  List<AchievementDef> _achievementDefs = [];
  final Map<String, int> progress = {};
  final Map<String, Set<int>> claimedTiers = {};
  final Map<String, int> highestStreaks = {};

  // Tracks which tiers are currently being claimed to prevent double taps
  final Set<String> _claimingInProgress = {};
  // Whether the entrance animation has already played once
  bool _entranceAnimationPlayed = false;

  // Per-section scroll controllers and current dot index for the dot indicators
  final Map<String, ScrollController> _sectionScrolls = {};
  final Map<String, int> _sectionDotIndex = {};

  // Shared controllers so all even-index chips pulse together and all odd-index chips pulse together
  late final AnimationController _evenPulse;
  late final AnimationController _oddPulse;

  @override
  void initState() {
    super.initState();
    FirebaseAnalytics.instance.logScreenView(
      screenName: '/badges',
      screenClass: 'Badges',
    );

    _evenPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _oddPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    // Start odd controller half a cycle late so even and odd chips alternate phase
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _oddPulse.repeat(reverse: true);
    });

    // For guest users
    if (isGuest) {
      Guest.blockOnOpen(
        context,
        title: 'Sign up to earn badges',
        description:
            'Create a free account to unlock achievements and claim tier rewards.',
      );
      setState(() => _isLoading = false);
      return;
    }
    _fetchBadgesData();
  }

  @override
  void dispose() {
    _evenPulse.dispose();
    _oddPulse.dispose();
    for (final sc in _sectionScrolls.values) {
      sc.dispose();
    }
    super.dispose();
  }

  // Fetches all achievement progress, claimed tiers, and streaks from the backend in parallel
  Future<void> _fetchBadgesData() async {
    setState(() {
      _isLoading = true;
      _entranceAnimationPlayed = false;
    });
    try {
      // fetch in parallel for faster retrieval
      final results = await Future.wait([
        UserDataManager.fetchAchievements(),
        UserDataManager.fetchStreaks(),
        UserDataManager.fetchAchievementDefs(),
      ]);

      final data = results[0] as Map<String, dynamic>;
      final streaks = results[1] as List<Map<String, dynamic>>;
      final rawDefs = results[2] as List<Map<String, dynamic>>;

      setState(() {
        // Build achievement definitions from fetched data, merging with local icon map
        _achievementDefs = rawDefs
            .map(
              (d) => AchievementDef(
                id: d['id'] as String,
                name: d['name'] as String,
                description: d['description'] as String,
                icon: _achievementIcons[d['id']] ?? HugeIcons.strokeRoundedStar,
                tiers: List<int>.from(d['tiers'] as List),
                unit: d['unit'] as String,
                section: d['section'] as String,
              ),
            )
            .toList();

        // Populate progress map from the progress list
        for (final entry in data['progress']) {
          progress[entry['achievement_id']] = entry['progress'];
        }

        // Populate claimedTiers map from the claims list
        for (final claim in data['claims']) {
          claimedTiers[claim['achievement_id']] ??= {};
          claimedTiers[claim['achievement_id']]!.add(claim['tier']);
        }

        // Populate highestStreaks map from the streaks list
        for (final streak in streaks) {
          final streakType = streak['streak_type'] as String;
          // Map DB streak_type names to achievement IDs
          final achievementId = streakType == 'daily_consecutive_streak'
              ? 'daily_claim_streak'
              : streakType;
          highestStreaks[achievementId] = streak['highest_streak'] as int;
        }

        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to fetch badges data: $e');
      setState(() => _isLoading = false);
    }
  }

  // Returns a unique key for a specific achievement + tier combo
  String _claimKey(String achievementId, int tier) {
    return "${achievementId}_$tier";
  }

  // Attempts to claim a tier with a cooldown guard to prevent spam
  Future<void> _claimTier(AchievementDef def, int tier) async {
    final key = _claimKey(def.id, tier);
    // Ignore if this tier is already being claimed
    if (_claimingInProgress.contains(key)) return;
    _claimingInProgress.add(key);
    try {
      final response = await authenticatedPost(
        'claim_achievement',
        body: {'achievement_id': def.id, 'tier': tier},
      );
      if (response.statusCode != 200) {
        throw Exception(
          'claim_achievement failed: ${response.statusCode} ${response.body}',
        );
      }
      // Only update UI if the backend confirmed the claim
      setState(() {
        claimedTiers[def.id] ??= {};
        claimedTiers[def.id]!.add(tier);
      });
      badgesConfettiController.play();
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to claim tier: $e');
    }
    // Cooldown before allowing another claim attempt
    await Future.delayed(const Duration(seconds: 2));
    _claimingInProgress.remove(key);
  }

  // Builds a single tier chip showing the milestone, its status, and a claim button if ready
  Widget _buildTierChip(AchievementDef def, int tier, {int index = 0}) {
    final currentProgress =
        progress[def.id] ??
        0; // reads the progress in the achievement_progress table
    // Use highest ever streak for streak achievements so a broken streak doesn't lock tiers the user already earned
    final reachableProgress = highestStreaks.containsKey(def.id)
        ? (highestStreaks[def.id] ?? 0)
        : currentProgress;
    final claimed =
        claimedTiers[def.id]?.contains(tier) ??
        false; // whether this tier has already been claimed by the user
    final reachable =
        reachableProgress >=
        tier; // whether the user has reached this tier (claimable if not already claimed)

    final Color bgColor;
    final Color labelColor;
    final Color borderColor;
    final IconData statusIcon;

    if (claimed) {
      bgColor = appColor.withAlpha(60);
      labelColor = Colors.white38;
      borderColor = lightenColor(appColor, 0.25).withAlpha(60);
      statusIcon = HugeIcons.strokeRoundedCheckmarkCircle01;
    } else if (reachable) {
      bgColor = appColor.withAlpha(180);
      labelColor = Colors.white;
      borderColor = lightenColor(appColor, 0.4).withAlpha(220);
      statusIcon = HugeIcons.strokeRoundedGift;
    } else {
      bgColor = Colors.white.withAlpha(22);
      labelColor = Colors.white38;
      borderColor = Colors.white.withAlpha(40);
      statusIcon = HugeIcons.strokeRoundedLockKey;
    }

    final size = Responsive.scale(context, 40);
    final chip = GestureDetector(
      onTap: (reachable && !claimed) ? () => _claimTier(def, tier) : null,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bgColor,
              border: Border.all(
                color: borderColor,
                width: Responsive.width(context, 1.5),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                HugeIcon(
                  icon: statusIcon,
                  color: labelColor,
                  size: Responsive.scale(context, 9),
                ),
                SizedBox(height: Responsive.height(context, 1)),
                Text(
                  "$tier",
                  style: GoogleFonts.manrope(
                    fontSize: Responsive.font(context, 8),
                    color: labelColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (reachable && !claimed) {
      final controller = index.isOdd ? _oddPulse : _evenPulse;
      // autoPlay: false because the shared controller is already running, letting it autoPlay would restart it
      return chip
          .animate(controller: controller, autoPlay: false)
          .scaleXY(
            begin: 0.95,
            end: 1.05, // goes between slightly smaller and larger sizes
            duration: 1200.ms,
            curve: Curves.easeInOut,
          )
          .tint(
            color: lightenColor(
              appColor,
              0.3,
            ), // lightened app color for contrast against the chip
            begin: 0.0,
            end: 0.35, // pulses toward a lighter version of the theme color
            duration: 1200.ms,
            curve: Curves.easeInOut,
          );
    }
    return chip;
  }

  // Builds a single achievement card with icon, name, progress bar, and tier chips
  Widget _buildAchievementCard(
    AchievementDef def, {
    bool animate = false,
    int cardIndex = 0,
  }) {
    final currentProgress = progress[def.id] ?? 0;

    // Find the next tier the user hasn't reached yet
    int nextTier = def.tiers.last;
    for (final t in def.tiers) {
      if (currentProgress < t) {
        nextTier = t;
        break;
      }
    }

    // Only show "All tiers complete!" after the user has actually claimed every tier
    bool allClaimed = true;
    for (final t in def.tiers) {
      if (claimedTiers[def.id] == null || !claimedTiers[def.id]!.contains(t)) {
        allClaimed = false;
        break;
      }
    }

    final unclaimedCount = def.tiers.where((t) {
      final reached =
          (highestStreaks.containsKey(def.id)
              ? (highestStreaks[def.id] ?? 0)
              : currentProgress) >=
          t;
      final claimed = claimedTiers[def.id]?.contains(t) ?? false;
      return reached && !claimed;
    }).length;

    // Fill the bar fully if all tiers are done, otherwise show partial progress toward the next tier
    final progressFraction = allClaimed
        ? 1.0
        : (currentProgress / nextTier).clamp(0.0, 1.0);
    final accent = lightenColor(appColor, 0.45);
    final barColor = lightenColor(appColor, 0.3);

    final card = Padding(
      padding: EdgeInsets.only(bottom: Responsive.height(context, 12)),
      child: Skeleton.ignore(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Responsive.scale(context, 18)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                color: cardColors(appColor).gradient.first.withAlpha(180),
                borderRadius: BorderRadius.circular(
                  Responsive.scale(context, 18),
                ),
                border: Border.all(
                  color: allClaimed
                      ? lightenColor(appColor, 0.45).withAlpha(120)
                      : cardColors(appColor).border,
                  width: allClaimed
                      ? Responsive.width(context, 1.5)
                      : Responsive.width(context, 1),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  Responsive.scale(context, 16),
                  Responsive.scale(context, 16),
                  Responsive.scale(context, 16),
                  Responsive.scale(context, 16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row: icon + name + unclaimed pill
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            Responsive.scale(context, 10),
                          ),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: Container(
                              padding: EdgeInsets.all(
                                Responsive.scale(context, 9),
                              ),
                              decoration: BoxDecoration(
                                color: appColor.withAlpha(50),
                                borderRadius: BorderRadius.circular(
                                  Responsive.scale(context, 10),
                                ),
                                border: Border.all(
                                  color: barColor.withAlpha(80),
                                  width: Responsive.width(context, 1),
                                ),
                              ),
                              child: HugeIcon(
                                icon: def.icon,
                                color: barColor,
                                size: Responsive.scale(context, 22),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: Responsive.width(context, 12)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                def.name,
                                style: GoogleFonts.manrope(
                                  fontSize: Responsive.font(context, 16),
                                  color: accent,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                def.description,
                                style: GoogleFonts.manrope(
                                  fontSize: Responsive.font(context, 11),
                                  color: lightenColor(appColor, 0.35),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (unclaimedCount > 0) ...[
                          SizedBox(width: Responsive.width(context, 8)),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                              Responsive.scale(context, 20),
                            ),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: Responsive.width(context, 8),
                                  vertical: Responsive.height(context, 4),
                                ),
                                decoration: BoxDecoration(
                                  color: lightenColor(
                                    appColor,
                                    0.3,
                                  ).withAlpha(60),
                                  borderRadius: BorderRadius.circular(
                                    Responsive.scale(context, 20),
                                  ),
                                  border: Border.all(
                                    color: lightenColor(
                                      appColor,
                                      0.4,
                                    ).withAlpha(160),
                                    width: Responsive.width(context, 1),
                                  ),
                                ),
                                child: Text(
                                  "$unclaimedCount to claim",
                                  style: GoogleFonts.manrope(
                                    fontSize: Responsive.font(context, 10),
                                    color: lightenColor(appColor, 0.45),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (allClaimed) ...[
                          SizedBox(width: Responsive.width(context, 8)),
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                            color: lightenColor(appColor, 0.4),
                            size: Responsive.scale(context, 18),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: Responsive.height(context, 12)),
                    // Progress label + bar — hidden when all tiers are claimed
                    if (!allClaimed) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "$currentProgress / $nextTier ${def.unit}",
                            style: GoogleFonts.manrope(
                              fontSize: Responsive.font(context, 11),
                              color: accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            "${(progressFraction * 100).toStringAsFixed(0)}%",
                            style: GoogleFonts.manrope(
                              fontSize: Responsive.font(context, 11),
                              color: barColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: Responsive.height(context, 6)),
                      _ProgressBar(
                        fraction: progressFraction,
                        barColor: barColor,
                        tiers: def.tiers,
                        maxTier: def.tiers.last,
                      ),
                    ],
                    SizedBox(height: Responsive.height(context, 12)),
                    // Tier chips row: single tier renders inline, multiple tiers use swipeable carousel
                    if (def.tiers.length == 1)
                      Center(
                        child: _buildTierChip(def, def.tiers.first, index: 0),
                      )
                    else
                      _TierCarousel(def: def, tierChipBuilder: _buildTierChip),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (animate) {
      return card.animate().slideY(
        begin: 0.25,
        end: 0,
        delay: (cardIndex * 60).ms,
        duration: 350.ms,
        curve: Curves.easeOutCubic,
      );
    }
    return card;
  }

  Widget _buildSkeletonCard() {
    return Padding(
      padding: EdgeInsets.only(bottom: Responsive.height(context, 12)),
      child: frostedGlassCard(
        context,
        color: appColor,
        baseRadius: 18,
        padding: EdgeInsets.all(Responsive.scale(context, 16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: Responsive.scale(context, 40),
                  height: Responsive.scale(context, 40),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(60),
                    borderRadius: BorderRadius.circular(
                      Responsive.scale(context, 10),
                    ),
                  ),
                ),
                SizedBox(width: Responsive.width(context, 12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: Responsive.height(context, 14),
                        width: Responsive.width(context, 120),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(60),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      SizedBox(height: Responsive.height(context, 6)),
                      Container(
                        height: Responsive.height(context, 10),
                        width: Responsive.width(context, 180),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(40),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: Responsive.height(context, 16)),
            Container(
              height: Responsive.height(context, 6),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(40),
                borderRadius: BorderRadius.circular(
                  Responsive.scale(context, 6),
                ),
              ),
            ),
            SizedBox(height: Responsive.height(context, 16)),
            Row(
              children: [
                for (int i = 0; i < 3; i++) ...[
                  if (i > 0) SizedBox(width: Responsive.width(context, 8)),
                  Container(
                    width: Responsive.scale(context, 56),
                    height: Responsive.scale(context, 56),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withAlpha(50),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hPad = Responsive.centeredHorizontalPadding(context, 50);

    if (isGuest && !_isLoading) {
      return Container(
        decoration: BoxDecoration(gradient: buildThemeGradient(appColor)),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
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
                      padding: EdgeInsets.all(Responsive.scale(context, 12)),
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
              const Expanded(
                child: Center(
                  child: Text(
                    "Sign up to track your badges",
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Build the scrollable list with sticky section headers
    final animate = !_entranceAnimationPlayed;
    if (!_isLoading) _entranceAnimationPlayed = true;

    final slivers = <Widget>[];
    if (_isLoading) {
      slivers.add(
        SliverToBoxAdapter(
          child: Skeletonizer(
            enabled: true,
            effect: ShimmerEffect(
              baseColor: darkenColor(appColor, 0.1),
              highlightColor: lightenColor(appColor, 0.2),
              duration: const Duration(milliseconds: 1200),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: Column(
                children: List.generate(
                  4,
                  (_) => Padding(
                    padding: EdgeInsets.only(
                      top: Responsive.height(context, 12),
                    ),
                    child: _buildSkeletonCard(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      int globalCardIndex = 0;
      for (final section in tabSections) {
        final defs = _achievementDefs
            .where((d) => d.section == section)
            .toList();
        if (defs.isEmpty) continue;

        // Section header
        // Count claimable tiers in this section for the badge next to the header
        int sectionClaimable = 0;
        for (final d in defs) {
          final cur = highestStreaks.containsKey(d.id)
              ? (highestStreaks[d.id] ?? 0)
              : (progress[d.id] ?? 0);
          for (final t in d.tiers) {
            if (cur >= t && !(claimedTiers[d.id]?.contains(t) ?? false)) {
              sectionClaimable++;
            }
          }
        }

        // Lazy-init a scroll controller per section
        _sectionScrolls.putIfAbsent(section, () {
          final sc = ScrollController();
          sc.addListener(() {
            if (!sc.hasClients || defs.length <= 1) return;
            final max = sc.position.maxScrollExtent;
            final idx = max == 0
                ? 0
                : ((sc.offset / max) * (defs.length - 1)).round().clamp(
                    0,
                    defs.length - 1,
                  );
            if (idx != (_sectionDotIndex[section] ?? 0)) {
              setState(() => _sectionDotIndex[section] = idx);
            }
          });
          return sc;
        });
        final sc = _sectionScrolls[section]!;
        final dotIndex = _sectionDotIndex[section] ?? 0;

        slivers.add(
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: Responsive.height(context, 20)),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: hPad),
                    child: Row(
                      children: [
                        sectionHeader(
                          section,
                          context,
                          appColor: appColor,
                          padding: EdgeInsets.zero,
                        ),
                        if (sectionClaimable > 0) ...[
                          SizedBox(width: Responsive.width(context, 8)),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                              Responsive.scale(context, 20),
                            ),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: Responsive.width(context, 8),
                                  vertical: Responsive.height(context, 4),
                                ),
                                decoration: BoxDecoration(
                                  color: lightenColor(
                                    appColor,
                                    0.3,
                                  ).withAlpha(60),
                                  borderRadius: BorderRadius.circular(
                                    Responsive.scale(context, 20),
                                  ),
                                  border: Border.all(
                                    color: lightenColor(
                                      appColor,
                                      0.4,
                                    ).withAlpha(160),
                                    width: Responsive.width(context, 1),
                                  ),
                                ),
                                child: Text(
                                  "$sectionClaimable to claim",
                                  style: GoogleFonts.manrope(
                                    fontSize: Responsive.font(context, 10),
                                    color: lightenColor(appColor, 0.45),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        // Horizontal row of cards for this section
        final cardWidth = Responsive.scale(context, 260);
        final gap = Responsive.width(context, 10);
        final rowCards = <Widget>[];
        for (int i = 0; i < defs.length; i++) {
          if (i > 0) rowCards.add(SizedBox(width: gap));
          rowCards.add(
            SizedBox(
              width: cardWidth,
              child: _buildAchievementCard(
                defs[i],
                animate: animate,
                cardIndex: globalCardIndex,
              ),
            ),
          );
          globalCardIndex++;
        }

        slivers.add(
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: Responsive.height(context, 8)),
              child: Center(
                child: ConstrainedBox(
                  // Cap width on desktop so the row doesn't stretch wall-to-wall
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.white,
                            Colors.white,
                            Colors.transparent,
                          ],
                          stops: [0.0, 0.05, 0.95, 1.0],
                        ).createShader(bounds),
                        blendMode: BlendMode.dstIn,
                        child: ScrollConfiguration(
                          behavior: ScrollConfiguration.of(context).copyWith(
                            dragDevices: {
                              PointerDeviceKind.touch,
                              PointerDeviceKind.mouse,
                            },
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            controller: sc,
                            padding: EdgeInsets.symmetric(horizontal: hPad),
                            child: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: rowCards,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (defs.length > 1) ...[
                        SizedBox(height: Responsive.height(context, 8)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            defs.length,
                            (i) => AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutQuart,
                              margin: EdgeInsets.symmetric(
                                horizontal: Responsive.width(context, 3),
                              ),
                              width: Responsive.scale(
                                context,
                                i == dotIndex ? 18 : 6,
                              ),
                              height: Responsive.scale(context, 6),
                              decoration: BoxDecoration(
                                color: i == dotIndex
                                    ? lightenColor(appColor, 0.45)
                                    : lightenColor(
                                        appColor,
                                        0.45,
                                      ).withAlpha(60),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
      slivers.add(
        SliverToBoxAdapter(
          child: SizedBox(height: Responsive.height(context, 120)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(gradient: buildThemeGradient(appColor)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AppRefreshIndicator(
          onRefresh: _fetchBadgesData,
          appColor: appColor,
          child: ScrollConfiguration(
            behavior: NoGlowScrollBehavior(),
            child: Stack(
              children: [
                CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          SizedBox(height: MediaQuery.paddingOf(context).top),
                          Padding(
                            padding: EdgeInsets.only(
                              top: Responsive.height(context, 8),
                              bottom: Responsive.height(context, 8),
                              left: Responsive.centeredHorizontalPadding(
                                context,
                                20,
                              ),
                              right: Responsive.centeredHorizontalPadding(
                                context,
                                20,
                              ),
                            ),
                            child: Row(
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
                                  onTap: _fetchBadgesData,
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
                          ),
                        ],
                      ),
                    ),
                    ...slivers,
                  ],
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: buildDailyRewardConfetti(badgesConfettiController),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Progress bar with milestone marker ticks at each tier threshold
class _ProgressBar extends StatelessWidget {
  final double fraction;
  final Color barColor;
  final List<int> tiers;
  final int maxTier;

  const _ProgressBar({
    required this.fraction,
    required this.barColor,
    required this.tiers,
    required this.maxTier,
  });

  @override
  Widget build(BuildContext context) {
    final barHeight = Responsive.height(context, 8);
    final value = fraction.clamp(0.0, 1.0);

    return SizedBox(
      height: barHeight,
      child: Stack(
        children: [
          // Background track
          ClipRRect(
            borderRadius: BorderRadius.circular(Responsive.scale(context, 6)),
            child: Container(
              height: barHeight,
              color: Colors.white.withAlpha(18),
            ),
          ),
          // Filled portion
          ClipRRect(
            borderRadius: BorderRadius.circular(Responsive.scale(context, 6)),
            child: FractionallySizedBox(
              widthFactor: value,
              child: Container(
                height: barHeight,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [barColor.withAlpha(180), barColor],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Horizontally swipeable carousel of tier chips, styled like the frosted nav bar
class _TierCarousel extends ConsumerStatefulWidget {
  final AchievementDef def;
  final Widget Function(AchievementDef, int, {int index}) tierChipBuilder;

  const _TierCarousel({required this.def, required this.tierChipBuilder});

  @override
  ConsumerState<_TierCarousel> createState() => _TierCarouselState();
}

class _TierCarouselState extends ConsumerState<_TierCarousel> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final tiers = widget.def.tiers;

    return Align(
      alignment: Responsive.isDesktop(context)
          ? Alignment.center
          : Alignment.centerLeft,
      // cap width so chips don't spread across the full card on wide screens
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: Responsive.scale(context, 600)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(
                Responsive.scale(context, 16),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  height: Responsive.scale(context, 56),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(16),
                    borderRadius: BorderRadius.circular(
                      Responsive.scale(context, 16),
                    ),
                    border: Border.all(
                      color: Colors.white.withAlpha(28),
                      width: Responsive.width(context, 1),
                    ),
                  ),
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(
                      dragDevices: {
                        PointerDeviceKind.touch,
                        PointerDeviceKind.mouse,
                      },
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const ClampingScrollPhysics(),
                      child: Row(
                        children: [
                          SizedBox(width: Responsive.width(context, 6)),
                          for (int i = 0; i < tiers.length; i++) ...[
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: Responsive.width(context, 5),
                                vertical: Responsive.height(context, 8),
                              ),
                              child: widget.tierChipBuilder(
                                widget.def,
                                tiers[i],
                                index: i,
                              ),
                            ),
                          ],
                          SizedBox(width: Responsive.width(context, 6)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
