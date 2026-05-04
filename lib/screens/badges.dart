import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:google_fonts/google_fonts.dart";
import "/globals.dart";
import "/utility/responsive.dart";
import 'dart:convert';
import 'package:http/http.dart' as http;
import '/utility/confetti.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../services/user_data_manager.dart';

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
const int tabReminders = 4;
const int tabPersonalization = 5;
const int tabMeta = 6;

// Tab definitions in display order
const List<String> tabSections = [
  "PROGRESSION",
  "EXPLORE",
  "TABS",
  "FOOD",
  "REMINDERS",
  "PERSONALIZATION",
  "META",
];

// Short labels for the tab bar
const List<String> tabLabels = [
  "Progress",
  "Explore",
  "Tabs",
  "Food",
  "Reminders",
  "Personal",
  "Meta",
];

bool _isLoading = true; // for the skeletonizer

// Icons stay client-side since IconData is Flutter-specific
const Map<String, IconData> _achievementIcons = {
  "level": Icons.arrow_upward,
  "daily_claims": Icons.calendar_today,
  "daily_claim_streak": Icons.local_fire_department,
  "poi_visits": Icons.explore,
  "poi_categories": Icons.category,
  "poi_regular": Icons.repeat,
  "open_food_logging": Icons.restaurant_menu,
  "open_explore": Icons.map,
  "open_reminders": Icons.alarm,
  "open_badges": Icons.emoji_events,
  "open_leaderboard": Icons.leaderboard,
  "food_logs": Icons.restaurant,
  "food_recent": Icons.history,
  "food_full_day": Icons.dinner_dining,
  "food_streak": Icons.date_range,
  "food_manual": Icons.edit,
  "food_barcode": Icons.qr_code_scanner,
  "food_search": Icons.search,
  "calorie_calculator": Icons.calculate,
  "set_reminder": Icons.notifications_active,
  "delete_reminder": Icons.delete_outline,
  "future_reminder": Icons.event,
  "active_reminders": Icons.notifications,
  "set_username": Icons.badge,
  "set_pfp": Icons.camera_alt,
  "change_app_color": Icons.palette,
  "send_feedback": Icons.feedback,
  "switch_imperial": Icons.straighten,
  "color_indecisive": Icons.color_lens,
  "change_username": Icons.swap_horiz,
  "total_achievements": Icons.stars,
};

class Badges extends StatefulWidget {
  const Badges({super.key});

  @override
  State<Badges> createState() {
    return _BadgesState();
  }
}

class _BadgesState extends State<Badges> {
  // Populated from the backend on init
  List<AchievementDef> _achievementDefs = [];
  final Map<String, int> progress = {};
  final Map<String, Set<int>> claimedTiers = {};
  final Map<String, int> highestStreaks = {};

  // Tracks which tiers are currently being claimed to prevent double taps
  final Set<String> _claimingInProgress = {};

  @override
  void initState() {
    super.initState();
    _fetchBadgesData();
  }

  // Fetches all achievement progress, claimed tiers, and streaks from the backend in parallel
  Future<void> _fetchBadgesData() async {
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
                icon: _achievementIcons[d['id']] ?? Icons.star,
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
      debugPrint('Failed to fetch badges data: $e');
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
      final token = await getIdToken();
      final response = await http
          .post(
            Uri.parse('$backendBaseUrl/claim_achievement'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'id_token': token,
              'achievement_id': def.id,
              'tier': tier,
            }),
          )
          .timeout(const Duration(seconds: 5));

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
      debugPrint('Failed to claim tier: $e');
    }

    // Cooldown before allowing another claim attempt
    await Future.delayed(const Duration(seconds: 2));
    _claimingInProgress.remove(key);
  }

  // Builds a single tier chip showing the milestone, its status, and a claim button if ready
  Widget _buildTierChip(AchievementDef def, int tier) {
    final currentProgress =
        progress[def.id] ??
        0; // reads the progress in the achievement_progress table

    // For streak achievements, use the highest ever streak for claimability
    // so breaking a streak doesn't lock previously reached tiers
    final reachableProgress = highestStreaks.containsKey(def.id)
        ? (highestStreaks[def.id] ?? 0)
        : currentProgress;

    // Whether this tier has already been claimed by the user
    final claimed = claimedTiers[def.id]?.contains(tier) ?? false;

    // Whether the user has reached this tier (claimable if not already claimed)
    final reachable = reachableProgress >= tier;

    Color chipColor;
    Color textColor;
    IconData statusIcon;

    if (claimed) {
      chipColor = appColorNotifier.value.withAlpha(80);
      textColor = Colors.white;
      statusIcon = Icons.check_circle;
    } else if (reachable) {
      chipColor = appColorNotifier.value.withAlpha(160);
      textColor = Colors.white;
      statusIcon = Icons.star;
    } else {
      chipColor = Colors.white.withAlpha(12);
      textColor = Colors.white38;
      statusIcon = Icons.lock_outline;
    }

    return GestureDetector(
      onTap: (reachable && !claimed) ? () => _claimTier(def, tier) : null,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.width(context, 12),
          vertical: Responsive.height(context, 8),
        ),
        decoration: BoxDecoration(
          color: chipColor,
          borderRadius: BorderRadius.circular(Responsive.scale(context, 10)),
          border: (reachable && !claimed)
              ? Border.all(
                  color: appColorNotifier.value,
                  width: Responsive.width(context, 1.5),
                )
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              statusIcon,
              color: textColor,
              size: Responsive.scale(context, 14),
            ),
            SizedBox(width: Responsive.width(context, 6)),
            Text(
              "$tier",
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 13),
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Builds a single achievement card with icon, name, progress bar, and tier chips
  Widget _buildAchievementCard(AchievementDef def) {
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

    // Fill the bar fully if all tiers are done, otherwise show partial progress
    double progressFraction = 1.0;
    if (!allClaimed) {
      progressFraction = currentProgress / nextTier;
    }

    return Padding(
      padding: EdgeInsets.only(bottom: Responsive.height(context, 12)),
      child: frostedGlassCard(
        context,
        baseRadius: 16,
        padding: EdgeInsets.all(Responsive.scale(context, 18)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: icon, name, and progress count
            Row(
              children: [
                Icon(
                  def.icon,
                  color: appColorNotifier.value,
                  size: Responsive.scale(context, 24),
                ),
                SizedBox(width: Responsive.width(context, 14)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        def.name,
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 16),
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: Responsive.height(context, 2)),
                      Text(
                        def.description,
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 12),
                          color: Colors.white38,
                        ),
                      ),
                      SizedBox(height: Responsive.height(context, 2)),
                      Text(
                        allClaimed
                            ? "All tiers complete!"
                            : "$currentProgress / $nextTier ${def.unit}",
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 12),
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: Responsive.height(context, 14)),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(Responsive.scale(context, 6)),
              child: LinearProgressIndicator(
                value: progressFraction.clamp(0.0, 1.0),
                minHeight: Responsive.height(context, 8),
                backgroundColor: Colors.white.withAlpha(20),
                valueColor: AlwaysStoppedAnimation<Color>(
                  appColorNotifier.value,
                ),
              ),
            ),

            SizedBox(height: Responsive.height(context, 14)),

            // Tier chips row
            Wrap(
              spacing: Responsive.width(context, 8),
              runSpacing: Responsive.height(context, 8),
              children: [
                for (final tier in def.tiers) _buildTierChip(def, tier),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Returns the list of achievement cards for a given section
  List<Widget> _buildCardsForSection(String section) {
    List<Widget> cards = [];
    for (final def in _achievementDefs) {
      if (def.section == section) {
        cards.add(_buildAchievementCard(def));
      }
    }
    return cards;
  }

  // reset isLoading to true when the user revisits the tab
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    setState(() => _isLoading = true);
    _fetchBadgesData();
  }

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: _isLoading,
      effect: ShimmerEffect(
        baseColor: darkenColor(appColorNotifier.value, 0.1),
        highlightColor: lightenColor(appColorNotifier.value, 0.2),
        duration: const Duration(milliseconds: 1200),
      ),
      child: Container(
        decoration: BoxDecoration(gradient: buildThemeGradient()),
        child: DefaultTabController(
          length: tabSections.length,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: darkenColor(appColorNotifier.value, 0.025),
              centerTitle: true,
              toolbarHeight: Responsive.height(context, 100),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => context.pop(),
              ),
              title: createTitle("Badges", context),
              bottom: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: Colors.white,
                indicatorWeight: Responsive.height(context, 3),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white38,
                labelStyle: GoogleFonts.manrope(
                  fontSize: Responsive.font(context, 13),
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: GoogleFonts.manrope(
                  fontSize: Responsive.font(context, 13),
                  fontWeight: FontWeight.w500,
                ),
                tabs: [for (final label in tabLabels) Tab(text: label)],
                dividerColor: Colors.white.withAlpha(25),
              ),
            ),
            body: Stack(
              children: [
                TabBarView(
                  children: [
                    for (final section in tabSections)
                      SingleChildScrollView(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: Responsive.width(context, 50),
                            vertical: Responsive.height(context, 24),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ..._buildCardsForSection(section),
                              SizedBox(height: Responsive.height(context, 40)),
                            ],
                          ),
                        ),
                      ),
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
