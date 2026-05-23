// home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:level_up/utility/confetti.dart';
import 'screens/settings/settings_icon_button.dart';
import 'screens/settings.dart';
import 'screens/daily_rewards.dart';
import 'authentication/auth_services.dart';
import 'globals.dart';
import 'utility/responsive.dart';
import 'screens/onboarding.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:flutter_animate/flutter_animate.dart' hide ShimmerEffect;
import 'services/user_data_manager.dart' show trackTrivialAchievement;
import 'services/recent_foods_service.dart';
import 'services/fcm/notification_service.dart';
import 'services/fcm/web_fcm_token_stub.dart'
    if (dart.library.js_interop) 'services/fcm/web_fcm_token_web.dart'
    as web_fcm;

class _HomeAnimationState {
  static bool dashboardAnimated = false;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late VoidCallback _appColorListener;

  // 0 = dashboard step, 1 = nav bar step, 2 = settings step, -1 = tour not active
  int _tourStep = -1;

  Timer? _countdownTimer;
  Duration _timeUntilReward = Duration.zero;
  List<Map<String, dynamic>> _recentFoods = [];

  @override
  void initState() {
    super.initState();

    _appColorListener = () {
      if (mounted) setState(() {});
    };
    appColorNotifier.addListener(_appColorListener);

    confettiControllerinit();

    final needsOnboarding =
        currentUserData?.username != null &&
        currentUserData?.username == currentUserData?.uid;
    if (appReadyNotifier.value &&
        !userManager.lastLoadFailed &&
        !needsOnboarding) {
      isLoading = false;
    }

    appReadyNotifier.addListener(_onAppReady);
    if (appReadyNotifier.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onAppReady();
      });
    }
  }

  // Called every time this tab becomes active again, not just on first build
  @override
  void activate() {
    super.activate();
    if (appReadyNotifier.value) {
      _loadRecentFoods();
      _updateCountdown();
      if (mounted) setState(() {});
    }
  }

  void _onAppReady() {
    if (!mounted) return;
    initializeUser();
    _startCountdown();
    _loadRecentFoods();
    Future.delayed(const Duration(milliseconds: 850), () {
      _HomeAnimationState.dashboardAnimated = true;
    });
  }

  void _startCountdown() {
    _updateCountdown();
    _countdownTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _updateCountdown();
    });
  }

  void _updateCountdown() {
    final last = currentUserData?.lastDailyClaim;
    if (last == null) return;
    final next = last.add(const Duration(hours: 23));
    final remaining = next.difference(DateTime.now().toUtc());
    if (mounted)
      setState(
        () =>
            _timeUntilReward = remaining.isNegative ? Duration.zero : remaining,
      );
  }

  Future<void> _loadRecentFoods() async {
    final foods = await RecentFoodsService().getRecentFoods();
    if (mounted) setState(() => _recentFoods = foods.take(3).toList());
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    appColorNotifier.removeListener(_appColorListener);
    appReadyNotifier.removeListener(_onAppReady);
    dailyRewardConfettiController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get isNewUser =>
      currentUserData?.username != null &&
      currentUserData?.username == currentUserData?.uid;

  bool canClaimDailyReward() {
    return currentUserData?.canClaimDailyReward ?? true;
  }

  Future<void> buildDailyRewardDialog() async {
    if (!mounted) return;
    await DailyRewardDialog().showDailyRewardDialog(
      context,
      dailyRewardConfettiController,
    );
  }

  Future<void> _onTourTap() async {
    if (_tourStep == 0) {
      setState(() => _tourStep = 1);
    } else if (_tourStep == 1) {
      setState(() => _tourStep = 2);
    } else if (_tourStep == 2) {
      setState(() => _tourStep = -1);
      await showUsernameSetupDialog(context);
      if (mounted)
        setState(() {}); // refresh greeting and drawer with the new username
      if (canClaimDailyReward() && mounted) {
        await buildDailyRewardDialog();
        if (mounted) await requestNotificationPermissionIfNeeded(context);
      }
    }
  }

  Future<void> initializeUser() async {
    if (currentUserData == null) return;

    if (userManager.lastLoadFailed) {
      if (!mounted) return;
      setState(() => loadFailed = true);
      await showFrostedAlertDialog(
        context: context,
        title: "Failed to load",
        content: Text(
          "Check your connection and try again.",
          style: GoogleFonts.manrope(color: Colors.white54, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _retry();
            },
            child: const Text("Retry"),
          ),
        ],
      );
      return;
    }

    if (canClaimDailyReward() && mounted && !isNewUser && !isGuest) {
      buildDailyRewardDialog();
    }

    if (mounted) {
      setState(() => isLoading = false);
      if (kIsWeb &&
          !isNewUser &&
          web_fcm.getNotificationPermission() != 'granted' &&
          currentUserData!.notificationsEnabled) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) showBrowserBlockedDialog(context);
        });
      }
      if (isNewUser) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          await showWelcomeTourDialog(context);
          if (!mounted) return;
          setState(() => _tourStep = 0);
        });
      }
    }
  }

  Future<void> _retry() async {
    if (!mounted) return;
    setState(() {
      loadFailed = false;
      isLoading = true;
    });
    await userManager.loadUserData();
    if (currentUserData != null) {
      appColorNotifier.value = currentUserData!.appColor;
    }
    if (mounted) initializeUser();
  }

  bool isLoading = true;
  bool loadFailed = false;

  bool get _tourActive => _tourStep != -1;

  // Builds a greeting based on time of day plus a random variant from that pool
  String _buildGreeting(String? username) {
    final hour = DateTime.now().hour;
    final name = username != null ? ", $username" : "";

    final List<String> greetings;
    if (hour < 12) {
      greetings = [
        "Good morning$name!",
        "Morning$name!",
        "Hey$name, good morning!",
        "Rise and shine$name!",
        "What's on the agenda today$name?",
        "Ready to level up$name?",
        "New day, new goals$name!",
        "Let's make today count$name!",
      ];
    } else if (hour < 17) {
      greetings = [
        "Good afternoon$name!",
        "Hey$name, good afternoon!",
        "Welcome back$name!",
        "Hey$name!",
        "Back for more$name?",
        "What's on the agenda$name?",
        "Have you tried the Explore tab$name?",
        "Any achievements to unlock today$name?",
      ];
    } else if (hour < 21) {
      greetings = [
        "Good evening$name!",
        "Hey$name, good evening!",
        "Evening$name!",
        "Welcome back$name!",
        "Back for more$name?",
        "How's the day been$name?",
        "Log your dinner$name?",
        "Any achievements left to unlock$name?",
      ];
    } else {
      greetings = [
        "Hey$name, up late?",
        "Still at it$name?",
        "Good night$name!",
        "Hey$name!",
        "Burning the midnight oil$name?",
        "Log a late night snack$name?",
        "Night owl energy$name!",
        "Back for more$name?",
      ];
    }

    // Use the day of year as seed so it changes daily but stays consistent within a day
    final dayOfYear = DateTime.now()
        .difference(DateTime(DateTime.now().year))
        .inDays;
    return greetings[dayOfYear % greetings.length];
  }

  // Calculates total calories logged today
  int _todayCalories() {
    final today = DateTime.now();
    final key =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final meals = currentUserData?.foodDataByDate[key];
    if (meals == null) return 0;
    int total = 0;
    for (final foods in meals.values) {
      for (final food in foods) {
        total += (num.tryParse(food['calories'].toString()) ?? 0).toInt();
      }
    }
    return total;
  }

  // Counts consecutive days with at least one food logged, going back from today
  int _foodLogStreak() {
    final data = currentUserData?.foodDataByDate;
    if (data == null || data.isEmpty) return 0;
    int streak = 0;
    var day = DateTime.now();
    while (true) {
      final key =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final meals = data[key];
      final hasFood = meals != null && meals.values.any((f) => f.isNotEmpty);
      if (!hasFood) break;
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  // Reads the daily claim streak from the backend-populated UserData field
  int _dailyClaimStreak() => currentUserData?.dailyClaimStreak ?? 0;

  Widget _buildStreakRow({
    required IconData icon,
    required String label,
    required int count,
    required Color accentColor,
    required bool isLast,
  }) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            vertical: Responsive.height(context, 10),
          ),
          child: Row(
            children: [
              HugeIcon(
                icon: icon,
                color: accentColor,
                size: Responsive.scale(context, 22),
              ),
              SizedBox(width: Responsive.width(context, 14)),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.manrope(
                    color: Colors.white70,
                    fontSize: Responsive.font(context, 14),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                count == 1 ? "1 day" : "$count days",
                style: GoogleFonts.manrope(
                  color: accentColor,
                  fontSize: Responsive.font(context, 15),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(color: Colors.white.withAlpha(15), height: 1),
      ],
    );
  }

  // Streak card showing food log streak and daily claim streak
  Widget _buildStreakCard() {
    final foodStreak = _foodLogStreak();
    final claimStreak = _dailyClaimStreak();
    if (foodStreak == 0 && claimStreak == 0) return const SizedBox.shrink();
    final accentColor = lightenColor(appColorNotifier.value, 0.3);
    return frostedGlassCard(
      context,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.width(context, 20),
        vertical: Responsive.height(context, 4),
      ),
      child: Column(
        children: [
          if (foodStreak > 0)
            _buildStreakRow(
              icon: HugeIcons.strokeRoundedFire,
              label: "Food logging streak",
              count: foodStreak,
              accentColor: accentColor,
              isLast: claimStreak == 0,
            ),
          if (claimStreak > 0)
            _buildStreakRow(
              icon: HugeIcons.strokeRoundedCalendar02,
              label: "Daily reward claimed",
              count: claimStreak,
              accentColor: accentColor,
              isLast: true,
            ),
        ],
      ),
    );
  }

  // Guest banner card
  Widget _buildGuestBanner() {
    return frostedGlassCard(
      context,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.width(context, 16),
        vertical: Responsive.height(context, 14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "You're in guest mode",
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: Responsive.font(context, 14),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  "Create an account to save your progress",
                  style: GoogleFonts.manrope(
                    color: Colors.white54,
                    fontSize: Responsive.font(context, 12),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: Responsive.width(context, 12)),
          frostedButton(
            "Sign Up",
            context,
            onPressed: () async {
              await authService.value.signOut();
            },
          ),
        ],
      ),
    );
  }

  // XP bar card (moved from footer.dart)
  Widget _buildXpCard() {
    return ValueListenableBuilder<int>(
      valueListenable: expNotifier,
      builder: (context, exp, _) {
        return frostedGlassCard(
          context,
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.width(context, 20),
            vertical: Responsive.height(context, 16),
          ),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: exp.toDouble()),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOut,
            builder: (context, animatedExp, _) {
              final needed = (userManager.experienceNeeded ?? 1).toDouble();
              final progress = (animatedExp / needed).clamp(0.0, 1.0);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Level ${currentUserData?.level ?? 1}",
                        style: GoogleFonts.manrope(
                          color: Colors.white,
                          fontSize: Responsive.font(context, 16),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        "${animatedExp.round()} / ${userManager.experienceNeeded ?? 0} XP",
                        style: GoogleFonts.manrope(
                          color: Colors.white54,
                          fontSize: Responsive.font(context, 13),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: Responsive.height(context, 10)),
                  // XP bar, styled to match the calorie bar in food logging
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        Responsive.scale(context, 7),
                      ),
                      border: Border.all(
                        color: Colors.white.withAlpha(45),
                        width: Responsive.scale(context, 1),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        Responsive.scale(context, 6),
                      ),
                      child: Stack(
                        children: [
                          Container(
                            height: Responsive.height(context, 10),
                            width: double.infinity,
                            color: Colors.white.withAlpha(18),
                          ),
                          FractionallySizedBox(
                            widthFactor: progress,
                            child: Container(
                              height: Responsive.height(context, 10),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(
                                  Responsive.scale(context, 6),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: Responsive.height(context, 6)),
                  // XP to next level
                  Builder(
                    builder: (context) {
                      final needed = userManager.experienceNeeded ?? 0;
                      final remaining = (needed - animatedExp.round()).clamp(
                        0,
                        needed,
                      );
                      return Text(
                        "$remaining XP to Level ${(currentUserData?.level ?? 1) + 1}",
                        style: GoogleFonts.manrope(
                          color: Colors.white38,
                          fontSize: Responsive.font(context, 11),
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // Daily reward card
  Widget _buildDailyRewardCard() {
    final canClaim = canClaimDailyReward();
    final accentColor = lightenColor(appColorNotifier.value, 0.3);
    return GestureDetector(
      onTap: canClaim && !isGuest ? () => buildDailyRewardDialog() : null,
      child: frostedGlassCard(
        context,
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.width(context, 20),
          vertical: Responsive.height(context, 16),
        ),
        child: Row(
          children: [
            HugeIcon(
              icon: canClaim
                  ? HugeIcons.strokeRoundedGift
                  : HugeIcons.strokeRoundedCalendar02,
              color: canClaim ? accentColor : Colors.white38,
              size: Responsive.scale(context, 24),
            ),
            SizedBox(width: Responsive.width(context, 14)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    canClaim
                        ? "Daily reward ready!"
                        : "Daily reward claimed today!",
                    style: GoogleFonts.manrope(
                      color: canClaim ? Colors.white : Colors.white54,
                      fontSize: Responsive.font(context, 14),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    canClaim
                        ? "Tap to claim your XP bonus"
                        : _timeUntilReward.inSeconds > 0
                        ? "Next reward in ${_timeUntilReward.inHours}h ${_timeUntilReward.inMinutes.remainder(60)}m"
                        : "You've already claimed today's reward",
                    style: GoogleFonts.manrope(
                      color: Colors.white38,
                      fontSize: Responsive.font(context, 12),
                    ),
                  ),
                ],
              ),
            ),
            if (canClaim && !isGuest)
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                color: accentColor,
                size: Responsive.scale(context, 18),
              ),
          ],
        ),
      ),
    );
  }

  // Counts total food items logged today across all meals
  int _todayFoodCount() {
    final today = DateTime.now();
    final key =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final meals = currentUserData?.foodDataByDate[key];
    if (meals == null) return 0;
    return meals.values.fold(0, (sum, foods) => sum + foods.length);
  }

  // Quick stats row: calories with progress bar + foods logged today
  Widget _buildQuickStats() {
    final calories = _todayCalories();
    final goal = currentUserData?.caloriesGoal ?? 0;
    final progress = goal > 0 ? (calories / goal).clamp(0.0, 1.0) : 0.0;
    final foodCount = _todayFoodCount();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Calories card with mini progress bar
          Expanded(
            child: frostedGlassCard(
              context,
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.width(context, 16),
                vertical: Responsive.height(context, 14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedRestaurant03,
                        color: Colors.white38,
                        size: Responsive.scale(context, 14),
                      ),
                      SizedBox(width: Responsive.width(context, 5)),
                      Text(
                        "Calories today",
                        style: GoogleFonts.manrope(
                          color: Colors.white38,
                          fontSize: Responsive.font(context, 11),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: Responsive.height(context, 6)),
                  Text(
                    "$calories",
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontSize: Responsive.font(context, 22),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (goal > 0) ...[
                    Text(
                      "/ $goal goal",
                      style: GoogleFonts.manrope(
                        color: Colors.white38,
                        fontSize: Responsive.font(context, 11),
                      ),
                    ),
                    SizedBox(height: Responsive.height(context, 8)),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          Responsive.scale(context, 7),
                        ),
                        border: Border.all(
                          color: Colors.white.withAlpha(45),
                          width: Responsive.scale(context, 1),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          Responsive.scale(context, 6),
                        ),
                        child: Stack(
                          children: [
                            Container(
                              height: Responsive.height(context, 8),
                              width: double.infinity,
                              color: Colors.white.withAlpha(18),
                            ),
                            FractionallySizedBox(
                              widthFactor: progress,
                              child: Container(
                                height: Responsive.height(context, 8),
                                decoration: BoxDecoration(
                                  color: calories > goal
                                      ? Colors.redAccent
                                      : lightenColor(
                                          appColorNotifier.value,
                                          0.3,
                                        ),
                                  borderRadius: BorderRadius.circular(
                                    Responsive.scale(context, 6),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(width: Responsive.width(context, 12)),
          // Foods logged today
          Expanded(
            child: frostedGlassCard(
              context,
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.width(context, 16),
                vertical: Responsive.height(context, 14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedNote,
                        color: Colors.white38,
                        size: Responsive.scale(context, 14),
                      ),
                      SizedBox(width: Responsive.width(context, 5)),
                      Text(
                        "Foods logged",
                        style: GoogleFonts.manrope(
                          color: Colors.white38,
                          fontSize: Responsive.font(context, 11),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: Responsive.height(context, 6)),
                  Text(
                    "$foodCount",
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontSize: Responsive.font(context, 22),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_recentFoods.isNotEmpty)
                    Text(
                      "Last: ${_recentFoods.first['food_name'] ?? ''}",
                      style: GoogleFonts.manrope(
                        color: Colors.white38,
                        fontSize: Responsive.font(context, 11),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Recent activity section using local recent foods cache
  Widget _buildRecentActivity() {
    if (_recentFoods.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        sectionHeader("RECENTLY LOGGED", context),
        frostedGlassCard(
          context,
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.width(context, 16),
            vertical: Responsive.height(context, 4),
          ),
          child: Column(
            children: List.generate(_recentFoods.length, (i) {
              final food = _recentFoods[i];
              final name = food['food_name']?.toString() ?? '';
              final cal = food['calories']?.toString() ?? '—';
              return Column(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: Responsive.height(context, 10),
                    ),
                    child: Row(
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedRestaurant03,
                          color: Colors.white24,
                          size: Responsive.scale(context, 16),
                        ),
                        SizedBox(width: Responsive.width(context, 12)),
                        Expanded(
                          child: Text(
                            name,
                            style: GoogleFonts.manrope(
                              color: Colors.white70,
                              fontSize: Responsive.font(context, 13),
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          "$cal kcal",
                          style: GoogleFonts.manrope(
                            color: Colors.white38,
                            fontSize: Responsive.font(context, 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i < _recentFoods.length - 1)
                    Divider(color: Colors.white.withAlpha(15), height: 1),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _maybeAnimate(Widget widget, Duration delay) {
    if (_HomeAnimationState.dashboardAnimated) return widget;
    return widget
        .animate()
        .fadeIn(delay: delay, duration: 400.ms)
        .slideY(begin: 0.15, duration: 400.ms, curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IgnorePointer(ignoring: loadFailed, child: _buildBody()),
        if (_tourActive)
          DefaultTextStyle(
            style: const TextStyle(decoration: TextDecoration.none),
            child: Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _onTourTap,
                child: Stack(
                  children: [
                    Container(color: Colors.black.withAlpha(120)),
                    Positioned(
                      left: Responsive.width(context, 16),
                      right: (_tourStep == 2 && Responsive.isMobile(context))
                          ? null
                          : Responsive.width(context, 16),
                      top: (_tourStep == 0 || _tourStep == 2)
                          ? Responsive.height(context, 16)
                          : null,
                      bottom: _tourStep == 1
                          ? Responsive.height(context, 120)
                          : null,
                      child: (_tourStep == 2 && Responsive.isMobile(context))
                          ? ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width -
                                    Responsive.width(context, 120),
                              ),
                              child:
                                  buildShowcaseTooltip(
                                        context,
                                        title: 'Settings',
                                        description:
                                            'The gear icon to the right opens a settings drawer where you can update your preferences, send feedback, and more.',
                                      )
                                      .animate(key: ValueKey(_tourStep))
                                      .fadeIn(duration: 200.ms),
                            )
                          : Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 500,
                                ),
                                child: buildShowcaseTooltip(
                                  context,
                                  title: _tourStep == 0
                                      ? 'Your Dashboard'
                                      : _tourStep == 1
                                      ? 'Navigation Bar'
                                      : 'Settings',
                                  description: _tourStep == 0
                                      ? 'This is your dashboard — your XP progress, daily reward, and quick stats all live here. Use the tool buttons below to access Reminders and the Calorie Calculator.'
                                      : _tourStep == 1
                                      ? 'The floating bar at the bottom lets you switch between your five main tabs: Home, Food Logging, Explore, Leaderboard, and Badges.'
                                      : 'The gear icon to the right opens a settings drawer where you can update your preferences, send feedback, and more.',
                                ).animate(key: ValueKey(_tourStep)).fadeIn(duration: 200.ms),
                              ),
                            ),
                    ),
                    Positioned(
                      bottom: Responsive.height(context, 12),
                      left: 0,
                      right: 0,
                      child: Text(
                        _tourStep == 2
                            ? 'Tap anywhere to finish'
                            : 'Tap anywhere to continue',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 12),
                          color: Colors.white38,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBody() {
    final username =
        (currentUserData?.username == null ||
            currentUserData?.username == currentUserData?.uid)
        ? null
        : currentUserData!.username!;

    return IgnorePointer(
      ignoring: _tourActive,
      child: Skeletonizer(
        enabled: isLoading,
        effect: ShimmerEffect(
          baseColor: darkenColor(appColorNotifier.value, 0.1),
          highlightColor: lightenColor(appColorNotifier.value, 0.2),
          duration: const Duration(milliseconds: 1200),
        ),
        child: Container(
          decoration: BoxDecoration(gradient: buildThemeGradient()),
          child: Scaffold(
            key: _scaffoldKey,
            drawer: buildSettingsDrawer(
              context,
              scaffoldKey: _scaffoldKey,
              onProfileImageUpdated: () {
                if (!mounted) return;
                setState(() {});
              },
            ),
            backgroundColor: Colors.transparent,
            appBar: PreferredSize(
              preferredSize: Size.fromHeight(Responsive.height(context, 201)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppBar(
                    automaticallyImplyLeading: false,
                    scrolledUnderElevation: 0,
                    backgroundColor: darkenColor(appColorNotifier.value, 0.025),
                    centerTitle: true,
                    toolbarHeight: Responsive.buttonHeight(context, 120),
                    elevation: 0,
                    actions: [
                      SettingsIconButton(
                        onTap: () => _scaffoldKey.currentState?.openDrawer(),
                      ),
                    ],
                    flexibleSpace: Center(
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: kIsWeb
                              ? Responsive.width(context, 30)
                              : Responsive.height(context, 20) +
                                    MediaQuery.paddingOf(context).top * 1.5,
                          left: Responsive.width(context, 70),
                          right: Responsive.width(context, 70),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: ShaderMask(
                            shaderCallback: (bounds) =>
                                subtleTextGradient().createShader(
                                  Rect.fromLTWH(
                                    0,
                                    0,
                                    bounds.width,
                                    bounds.height,
                                  ),
                                ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Text(
                                  "LEVEL UP!",
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: Responsive.font(context, 55),
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: Responsive.scale(context, 2),
                                    foreground: Paint()
                                      ..style = PaintingStyle.stroke
                                      ..strokeWidth = Responsive.scale(
                                        context,
                                        3,
                                      )
                                      ..color = Colors.black.withAlpha(180),
                                  ),
                                ),
                                Text(
                                  "LEVEL UP!",
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: Responsive.font(context, 55),
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: Responsive.scale(context, 2),
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                        offset: const Offset(0, 0),
                                        blurRadius: Responsive.scale(
                                          context,
                                          25,
                                        ),
                                        color: appColorNotifier.value.withAlpha(
                                          200,
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
                    ),
                  ),
                  Container(
                    height: Responsive.height(context, 3),
                    color: Colors.white.withAlpha(25),
                  ),
                ],
              ),
            ),
            body: Stack(
              children: [
                ScrollConfiguration(
                  behavior: NoGlowScrollBehavior(),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.centeredHorizontalPadding(
                          context,
                          24,
                        ),
                        vertical: Responsive.height(context, 20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Guest banner
                          if (isGuest) ...[
                            _buildGuestBanner(),
                            SizedBox(height: Responsive.height(context, 16)),
                          ],

                          // Greeting
                          _maybeAnimate(
                            Text(
                              _buildGreeting(username),
                              style: GoogleFonts.manrope(
                                color: Colors.white,
                                fontSize: Responsive.font(context, 22),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            0.ms,
                          ),
                          SizedBox(height: Responsive.height(context, 16)),

                          sectionHeader("PROGRESS", context),
                          _maybeAnimate(_buildXpCard(), 60.ms),
                          SizedBox(height: Responsive.height(context, 20)),

                          sectionHeader("DAILY REWARD", context),
                          _maybeAnimate(_buildDailyRewardCard(), 120.ms),
                          SizedBox(height: Responsive.height(context, 20)),

                          sectionHeader("STREAKS", context),
                          _maybeAnimate(_buildStreakCard(), 180.ms),
                          SizedBox(height: Responsive.height(context, 20)),

                          sectionHeader("STATS", context),
                          _maybeAnimate(_buildQuickStats(), 220.ms),
                          SizedBox(height: Responsive.height(context, 20)),

                          sectionHeader("TOOLS", context),
                          // Tool tiles row
                          _maybeAnimate(
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      trackTrivialAchievement("open_reminders");
                                      context.push('/reminders');
                                    },
                                    child: frostedGlassCard(
                                      context,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: Responsive.width(
                                          context,
                                          16,
                                        ),
                                        vertical: Responsive.height(
                                          context,
                                          16,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          HugeIcon(
                                            icon: HugeIcons
                                                .strokeRoundedAlarmClock,
                                            color: lightenColor(
                                              appColorNotifier.value,
                                              0.3,
                                            ),
                                            size: Responsive.scale(context, 20),
                                          ),
                                          SizedBox(
                                            width: Responsive.width(
                                              context,
                                              10,
                                            ),
                                          ),
                                          Text(
                                            "Reminders",
                                            style: GoogleFonts.manrope(
                                              color: Colors.white,
                                              fontSize: Responsive.font(
                                                context,
                                                14,
                                              ),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: Responsive.width(context, 12)),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      trackTrivialAchievement(
                                        "calorie_calculator",
                                      );
                                      context.push('/calorie-calculator');
                                    },
                                    child: frostedGlassCard(
                                      context,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: Responsive.width(
                                          context,
                                          16,
                                        ),
                                        vertical: Responsive.height(
                                          context,
                                          16,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          HugeIcon(
                                            icon: HugeIcons
                                                .strokeRoundedCalculate,
                                            color: lightenColor(
                                              appColorNotifier.value,
                                              0.3,
                                            ),
                                            size: Responsive.scale(context, 20),
                                          ),
                                          SizedBox(
                                            width: Responsive.width(
                                              context,
                                              10,
                                            ),
                                          ),
                                          Flexible(
                                            child: Text(
                                              "Calculator",
                                              style: GoogleFonts.manrope(
                                                color: Colors.white,
                                                fontSize: Responsive.font(
                                                  context,
                                                  14,
                                                ),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            240.ms,
                          ),

                          SizedBox(height: Responsive.height(context, 20)),

                          // Recent activity
                          _maybeAnimate(_buildRecentActivity(), 300.ms),

                          // Extra bottom space so content clears the floating nav bar
                          SizedBox(height: Responsive.height(context, 100)),
                        ],
                      ),
                    ),
                  ),
                ),
                // Confetti on top
                Align(
                  alignment: Alignment.topCenter,
                  child: buildDailyRewardConfetti(
                    dailyRewardConfettiController,
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
