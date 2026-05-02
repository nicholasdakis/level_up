import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:google_fonts/google_fonts.dart";
import "/globals.dart";
import "/utility/responsive.dart";
import '/services/user_data_manager.dart' show getIdToken, backendBaseUrl;
import 'dart:convert';
import 'package:http/http.dart' as http;
import '/utility/confetti.dart';
import 'package:skeletonizer/skeletonizer.dart';

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

const List<AchievementDef> achievementDefs = [
  // Progression
  AchievementDef(
    id: "level",
    name: "Level Up",
    description: "Reach the specified level",
    icon: Icons.arrow_upward,
    tiers: [3, 5, 10, 15, 20, 25, 30, 40, 50, 75, 100],
    unit: "levels",
    section: "PROGRESSION",
  ),
  AchievementDef(
    id: "daily_claims",
    name: "Daily Claims",
    description: "Claim your daily reward the specified number of times",
    icon: Icons.calendar_today,
    tiers: [1, 7, 30, 100, 365],
    unit: "claims",
    section: "PROGRESSION",
  ),
  AchievementDef(
    id: "daily_claim_streak",
    name: "On a Roll",
    description: "Claim your daily reward for the specified consecutive days",
    icon: Icons.local_fire_department,
    tiers: [2, 5, 10, 15, 20, 25, 30],
    unit: "consecutive days",
    section: "PROGRESSION",
  ),

  // Explore
  AchievementDef(
    id: "poi_visits",
    name: "Just Checking In",
    description: "Check in at the specified number of POIs",
    icon: Icons.explore,
    tiers: [1, 5, 10, 15, 20, 25, 50, 75, 100, 150, 200],
    unit: "visits",
    section: "EXPLORE",
  ),
  AchievementDef(
    id: "poi_categories",
    name: "Category Collector",
    description:
        "Check in at POIs from the specified number of unique categories",
    icon: Icons.category,
    tiers: [5, 10, 15, 20, 25, 30],
    unit: "different categories",
    section: "EXPLORE",
  ),
  AchievementDef(
    id: "poi_regular",
    name: "The Usual",
    description: "Check in at the same POI 5 times",
    icon: Icons.repeat,
    tiers: [5],
    unit: "visits to same POI",
    section: "EXPLORE",
  ),

  // Tabs
  AchievementDef(
    id: "open_food_logging",
    name: "Write That Down!",
    description: "Open the Food Logging tab",
    icon: Icons.restaurant_menu,
    tiers: [1],
    unit: "open",
    section: "TABS",
  ),
  AchievementDef(
    id: "open_explore",
    name: "First Steps",
    description: "Open the Explore tab",
    icon: Icons.map,
    tiers: [1],
    unit: "open",
    section: "TABS",
  ),
  AchievementDef(
    id: "open_reminders",
    name: "Always On Time",
    description: "Open the Reminders tab",
    icon: Icons.alarm,
    tiers: [1],
    unit: "open",
    section: "TABS",
  ),
  AchievementDef(
    id: "open_badges",
    name: "Badge Hunter",
    description: "Open the Badges tab (this one!)",
    icon: Icons.emoji_events,
    tiers: [1],
    unit: "open",
    section: "TABS",
  ),
  AchievementDef(
    id: "open_leaderboard",
    name: "Bring It On",
    description: "Open the Leaderboard tab",
    icon: Icons.leaderboard,
    tiers: [1],
    unit: "open",
    section: "TABS",
  ),

  // Food
  AchievementDef(
    id: "food_logs",
    name: "Food Logger",
    description: "Log the specified number of foods",
    icon: Icons.restaurant,
    tiers: [1, 10, 50, 100, 200],
    unit: "foods logged",
    section: "FOOD",
  ),
  AchievementDef(
    id: "food_recent",
    name: "Shortcut",
    description: "Log a food from the Recent Logs section",
    icon: Icons.history,
    tiers: [1],
    unit: "recent log used",
    section: "FOOD",
  ),
  AchievementDef(
    id: "food_full_day",
    name: "Full Course Meal",
    description:
        "Log breakfast, lunch, dinner, and snack foods in the same day",
    icon: Icons.dinner_dining,
    tiers: [1],
    unit: "day with all meals logged",
    section: "FOOD",
  ),
  AchievementDef(
    id: "food_streak",
    name: "Consistency",
    description: "Log food for 7 consecutive days",
    icon: Icons.date_range,
    tiers: [7],
    unit: "consecutive days logged",
    section: "FOOD",
  ),
  AchievementDef(
    id: "food_manual",
    name: "My Way",
    description: "Log a food using manual entry",
    icon: Icons.edit,
    tiers: [1],
    unit: "manual log",
    section: "FOOD",
  ),
  AchievementDef(
    id: "food_barcode",
    name: "Barcode Scanner",
    description: "Log a food by scanning a barcode",
    icon: Icons.qr_code_scanner,
    tiers: [1],
    unit: "barcode scan",
    section: "FOOD",
  ),
  AchievementDef(
    id: "food_search",
    name: "Food Search",
    description: "Log a food using the search bar",
    icon: Icons.search,
    tiers: [1],
    unit: "search log",
    section: "FOOD",
  ),
  AchievementDef(
    id: "calorie_calculator",
    name: "Goal Reacher",
    description: "Use the calorie calculator",
    icon: Icons.calculate,
    tiers: [1],
    unit: "use",
    section: "FOOD",
  ),

  // Reminders
  AchievementDef(
    id: "set_reminder",
    name: "Reminder Setter",
    description: "Set a reminder",
    icon: Icons.notifications_active,
    tiers: [1],
    unit: "reminder set",
    section: "REMINDERS",
  ),
  AchievementDef(
    id: "delete_reminder",
    name: "Honestly, Nevermind",
    description: "Delete a reminder",
    icon: Icons.delete_outline,
    tiers: [1],
    unit: "reminder deleted",
    section: "REMINDERS",
  ),
  AchievementDef(
    id: "future_reminder",
    name: "Planning Ahead",
    description: "Set a reminder at least one month in the future",
    icon: Icons.event,
    tiers: [1],
    unit: "reminder 1+ month out",
    section: "REMINDERS",
  ),
  AchievementDef(
    id: "active_reminders",
    name: "Busy Person",
    description: "Have 5 active reminders at once",
    icon: Icons.notifications,
    tiers: [5],
    unit: "active reminders at once",
    section: "REMINDERS",
  ),

  // Personalization
  AchievementDef(
    id: "set_username",
    name: "Only One Of Me",
    description: "Set your username",
    icon: Icons.badge,
    tiers: [1],
    unit: "username set",
    section: "PERSONALIZATION",
  ),
  AchievementDef(
    id: "set_pfp",
    name: "Say Cheese",
    description: "Set a profile picture",
    icon: Icons.camera_alt,
    tiers: [1],
    unit: "profile picture set",
    section: "PERSONALIZATION",
  ),
  AchievementDef(
    id: "change_app_color",
    name: "Fresh Coat Of Paint",
    description: "Change your app color",
    icon: Icons.palette,
    tiers: [1],
    unit: "color changed",
    section: "PERSONALIZATION",
  ),
  AchievementDef(
    id: "send_feedback",
    name: "The Critic",
    description: "Send feedback using the feedback button",
    icon: Icons.feedback,
    tiers: [1],
    unit: "feedback sent",
    section: "PERSONALIZATION",
  ),
  AchievementDef(
    id: "switch_imperial",
    name: "Freedom Units",
    description: "Switch your units to imperial in the Calorie Calculator tab",
    icon: Icons.straighten,
    tiers: [1],
    unit: "switched to imperial",
    section: "PERSONALIZATION",
  ),
  AchievementDef(
    id: "color_indecisive",
    name: "Indecisive",
    description: "Change the app color 5 times",
    icon: Icons.color_lens,
    tiers: [5],
    unit: "color changes",
    section: "PERSONALIZATION",
  ),
  AchievementDef(
    id: "change_username",
    name: "Identity Crisis",
    description: "Change your username after setting it",
    icon: Icons.swap_horiz,
    tiers: [1],
    unit: "username changed",
    section: "PERSONALIZATION",
  ),

  // Meta
  AchievementDef(
    id: "total_achievements",
    name: "Completionist",
    description: "Unlock the specified number of achievements",
    icon: Icons.stars,
    tiers: [10, 25, 50],
    unit: "achievements unlocked",
    section: "META",
  ),
];

class Badges extends StatefulWidget {
  const Badges({super.key});

  @override
  State<Badges> createState() {
    return _BadgesState();
  }
}

class _BadgesState extends State<Badges> {
  // Populated from the backend on init
  final Map<String, int> progress = {};
  final Map<String, Set<int>> claimedTiers = {};

  // Tracks which tiers are currently being claimed to prevent double taps
  final Set<String> _claimingInProgress = {};

  @override
  void initState() {
    super.initState();
    _fetchAchievements();
  }

  // Fetches all achievement progress and claimed tiers from the backend
  Future<void> _fetchAchievements() async {
    try {
      final token = await getIdToken();
      final response = await http
          .post(
            Uri.parse('$backendBaseUrl/get_achievements'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'id_token': token}),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        throw Exception(
          'get_achievements failed: ${response.statusCode} ${response.body}',
        );
      }

      final data = jsonDecode(response.body);

      setState(() {
        // Populate progress map from the progress list
        for (final entry in data['progress']) {
          progress[entry['achievement_id']] = entry['progress'];
        }

        // Populate claimedTiers map from the claims list
        for (final claim in data['claims']) {
          claimedTiers[claim['achievement_id']] ??= {};
          claimedTiers[claim['achievement_id']]!.add(claim['tier']);
        }
        _isLoading = false; // stop the skeletonizer on a successful fetch
      });
    } catch (e) {
      debugPrint('Failed to fetch achievements: $e');
      _isLoading = false; // stop the skeletonizer on a failed fetch
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
    final currentProgress = progress[def.id] ?? 0;
    // Safe check: if no tiers claimed for this achievement yet, default to false
    final claimed = claimedTiers[def.id]?.contains(tier) ?? false;
    final reachable = currentProgress >= tier;

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
    for (final def in achievementDefs) {
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
    _fetchAchievements();
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
