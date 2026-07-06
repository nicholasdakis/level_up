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

// Tab index constants so tab references are readable
const int tabProgression = 0;
const int tabExplore = 1;
const int tabTabs = 2;
const int tabFood = 3;
const int tabWorkout = 4;
const int tabReminders = 5;
const int tabPersonalization = 6;
const int tabMeta = 7;

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

// Short labels for the tab bar
const List<String> tabLabels = [
  "Progress",
  "Explore",
  "Tabs",
  "Food",
  "Workout",
  "Reminders",
  "Personal",
  "Social",
  "Meta",
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
  Color get appColor => ref.read(userDataProvider).value?.appColor ?? defaultAppColor;

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

  late final TabController _tabController;
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
    _tabController = TabController(length: tabSections.length, vsync: this);
    // Rebuild when tab changes so the fade hides when the last tab is selected
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

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

    if (isGuest) {
      // For guest users
      Guest.blockOnOpen(context);
      setState(() => _isLoading = false);
      return;
    }
    _fetchBadgesData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _evenPulse.dispose();
    _oddPulse.dispose();
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
    final appColor =
        ref.read(userDataProvider).value?.appColor ?? defaultAppColor;
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

    final size = Responsive.scale(context, 72);
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
                  size: Responsive.scale(context, 14),
                ),
                SizedBox(height: Responsive.height(context, 2)),
                Text(
                  "$tier",
                  style: GoogleFonts.manrope(
                    fontSize: Responsive.font(context, 12),
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
  Widget _buildAchievementCard(AchievementDef def) {
    final appColor =
        ref.read(userDataProvider).value?.appColor ?? defaultAppColor;
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

    return Padding(
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
  }

  Widget _buildSkeletonCard() {
    return Padding(
      padding: EdgeInsets.only(bottom: Responsive.height(context, 12)),
      child: frostedGlassCard(
        context,
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
                    color: Colors.white.withAlpha(30),
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
                        color: Colors.white.withAlpha(30),
                      ),
                      SizedBox(height: Responsive.height(context, 6)),
                      Container(
                        height: Responsive.height(context, 10),
                        width: Responsive.width(context, 180),
                        color: Colors.white.withAlpha(20),
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
                color: Colors.white.withAlpha(20),
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
                      color: Colors.white.withAlpha(20),
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

  Widget _buildCategoryTabBar(BuildContext context) {
    final tabBar = TabBar(
      controller: _tabController,
      isScrollable: true,
      physics: const BouncingScrollPhysics(),
      dividerHeight: 0,
      tabAlignment: Responsive.isDesktop(context)
          ? TabAlignment.center
          : TabAlignment.start,
      labelPadding: EdgeInsets.symmetric(
        horizontal: Responsive.width(context, 16),
      ),
      dividerColor: Colors.transparent,
      indicator: BoxDecoration(
        color: Colors.white.withAlpha(45),
        borderRadius: BorderRadius.circular(Responsive.scale(context, 20)),
        border: Border.all(
          color: Colors.white.withAlpha(60),
          width: Responsive.width(context, 1),
        ),
      ),
      indicatorSize: TabBarIndicatorSize.tab,
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.pressed)) {
          return Colors.white.withAlpha(15);
        }
        return Colors.transparent;
      }),
      splashBorderRadius: BorderRadius.circular(Responsive.scale(context, 20)),
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white38,
      labelStyle: GoogleFonts.manrope(
        fontSize: Responsive.font(context, 15),
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelStyle: GoogleFonts.manrope(
        fontSize: Responsive.font(context, 15),
        fontWeight: FontWeight.w500,
      ),
      tabs: [for (final label in tabLabels) Tab(text: label)],
    );
    // On mobile fade the right edge only when there are tabs scrolled out of view to the right
    final isAtEnd = _tabController.index >= tabSections.length - 2;
    if (Responsive.isDesktop(context) || isAtEnd) return tabBar;
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Colors.white, Colors.white, Colors.transparent],
        stops: [0.0, 0.95, 1.0],
      ).createShader(bounds),
      blendMode: BlendMode.dstIn,
      child: tabBar,
    );
  }

  // Returns the list of achievement cards for a given section
  List<Widget> _buildCardsForSection(String section) {
    if (_isLoading) {
      return [for (int i = 0; i < 4; i++) _buildSkeletonCard()];
    }
    final isActiveTab = tabSections[_tabController.index] == section;
    final animate = !_entranceAnimationPlayed && isActiveTab;
    if (animate) _entranceAnimationPlayed = true;
    List<Widget> cards = [];
    int cardIndex = 0;
    for (final def in _achievementDefs) {
      if (def.section == section) {
        final delay = (cardIndex * 60).ms;
        final card = _buildAchievementCard(def);
        cards.add(
          animate
              ? card.animate().slideY(
                  begin: 0.25,
                  end: 0,
                  delay: delay,
                  duration: 350.ms,
                  curve: Curves.easeOutCubic,
                )
              : card,
        );
        cardIndex++;
      }
    }
    if (cards.isEmpty && !_isLoading) {
      cards.add(
        Padding(
          padding: EdgeInsets.symmetric(
            vertical: Responsive.height(context, 48),
          ),
          child: Column(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedCrown,
                color: Colors.white24,
                size: Responsive.scale(context, 40),
              ),
              SizedBox(height: Responsive.height(context, 12)),
              Text(
                "No achievements here yet",
                style: GoogleFonts.manrope(
                  color: Colors.white30,
                  fontSize: Responsive.font(context, 14),
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: Responsive.height(context, 4)),
              Text(
                "Keep using the app to unlock them",
                style: GoogleFonts.manrope(
                  color: Colors.white24,
                  fontSize: Responsive.font(context, 12),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return cards;
  }

  @override
  Widget build(BuildContext context) {
    final appColor =
        ref.watch(userDataProvider).value?.appColor ?? defaultAppColor;
    if (isGuest && !_isLoading) {
      // For guest users
      return Container(
        decoration: BoxDecoration(gradient: buildThemeGradient()),
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
    return Skeletonizer(
      enabled: _isLoading,
      effect: ShimmerEffect(
        baseColor: darkenColor(appColor, 0.1),
        highlightColor: lightenColor(appColor, 0.2),
        duration: const Duration(milliseconds: 1200),
      ),
      child: Container(
        decoration: BoxDecoration(gradient: buildThemeGradient()),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: ScrollConfiguration(
            behavior: NoGlowScrollBehavior(),
            child: Column(
              children: [
                SizedBox(height: MediaQuery.paddingOf(context).top),
                // Back button + refresh button row
                Padding(
                  padding: EdgeInsets.only(
                    top: Responsive.height(context, 8),
                    bottom: Responsive.height(context, 12),
                    left: Responsive.centeredHorizontalPadding(context, 20),
                    right: Responsive.centeredHorizontalPadding(context, 20),
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
                      GestureDetector(
                        onTap: _fetchBadgesData,
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
                            Icons.refresh,
                            color: lightenColor(appColor, 0.3).withAlpha(180),
                            size: Responsive.font(context, 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Category tab bar
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.width(context, 12),
                    vertical: Responsive.height(context, 8),
                  ),
                  child: _buildCategoryTabBar(context),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      TabBarView(
                        controller: _tabController,
                        children: [
                          for (final section in tabSections)
                            SingleChildScrollView(
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal:
                                      Responsive.centeredHorizontalPadding(
                                        context,
                                        50,
                                      ),
                                  vertical: Responsive.height(context, 24),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    ..._buildCardsForSection(section),
                                    SizedBox(
                                      height: Responsive.height(context, 120),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.topCenter,
                        child: buildDailyRewardConfetti(
                          badgesConfettiController,
                        ),
                      ),
                    ],
                  ),
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
      child: ConstrainedBox(
        // cap width so chips don't spread across the full card on wide screens
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
                  height: Responsive.scale(context, 88),
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
                                horizontal: Responsive.width(context, 6),
                                vertical: Responsive.height(context, 10),
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
