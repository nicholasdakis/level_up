// home_screen.dart
import 'package:firebase_analytics/firebase_analytics.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:level_up/utility/confetti.dart';
import 'screens/settings/settings_icon_button.dart';
import 'screens/settings.dart';
import 'screens/daily_rewards.dart';
import 'screens/referrals.dart';
import 'authentication/auth_services.dart';
import 'globals.dart';
import 'utility/responsive.dart';
import 'screens/onboarding.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:flutter_animate/flutter_animate.dart' hide ShimmerEffect;
import 'services/user_data_manager.dart' show trackTrivialAchievement;
import 'services/ad_service.dart';
import 'package:url_launcher/url_launcher.dart';
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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late VoidCallback _appColorListener;

  // 0 = dashboard step, 1 = nav bar step, 2 = settings step, -1 = tour not active
  int _tourStep = -1;

  Timer? _countdownTimer;
  Duration _timeUntilReward = Duration.zero;
  double _lastRenderedExp = 0;
  late String _greeting;
  bool _greetingIsQuestion = false;

  @override
  void initState() {
    super.initState();
    FirebaseAnalytics.instance.logScreenView(
      screenName: '/',
      screenClass: 'HomeScreen',
    );
    _greeting = _buildGreeting();

    _appColorListener = () {
      if (mounted) setState(() {});
    };
    appColorNotifier.addListener(_appColorListener);
    foodLogNotifier.addListener(_onFoodChanged);
    WidgetsBinding.instance.addObserver(this);

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

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  void _onFoodChanged() {
    if (mounted) setState(() {});
  }

  // Called every time this tab becomes active again, not just on first build
  @override
  void activate() {
    super.activate();
    if (appReadyNotifier.value) {
      _updateCountdown();
      if (mounted) setState(() {});
    }
  }

  // Called when the app resumes from background
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && appReadyNotifier.value) {
      _updateCountdown();
      if (mounted) setState(() {});
      if (canClaimDailyReward() && !isGuest && !isNewUser) {
        buildDailyRewardDialog();
      }
    }
  }

  void _onAppReady() {
    if (!mounted) return;
    initializeUser();
    _startCountdown();
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
    final next = last.add(dailyRewardCooldown);
    final remaining = next.difference(DateTime.now().toUtc());
    final newValue = remaining.isNegative ? Duration.zero : remaining;
    if (newValue.inMinutes == _timeUntilReward.inMinutes) return;
    if (mounted) setState(() => _timeUntilReward = newValue);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    appColorNotifier.removeListener(_appColorListener);
    foodLogNotifier.removeListener(_onFoodChanged);
    appReadyNotifier.removeListener(_onAppReady);
    dailyRewardConfettiController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get isNewUser =>
      currentUserData?.username != null &&
      currentUserData?.username == currentUserData?.uid;

  bool canClaimDailyReward() {
    final last = currentUserData?.lastDailyClaim;
    if (last == null) return true;
    final secondsSince = DateTime.now()
        .toUtc()
        .difference(last.toUtc())
        .inSeconds;
    return secondsSince >= dailyRewardCooldown.inSeconds;
  }

  Future<void> buildDailyRewardDialog() async {
    if (!mounted) return;
    await DailyRewardDialog().showDailyRewardDialog(
      context,
      dailyRewardConfettiController,
    );
    if (mounted) {
      _updateCountdown();
      setState(() {});
    }
  }

  Future<void> _onTourTap() async {
    if (_tourStep == 0) {
      setState(() => _tourStep = 1);
    } else if (_tourStep == 1) {
      setState(() => _tourStep = 2);
    } else if (_tourStep == 2) {
      setState(() => _tourStep = -1);
      await showUsernameSetupDialog(context);
      if (mounted) {
        setState(
          () => _greeting = _buildGreeting(),
        ); // refresh greeting and drawer with the new username
        await showNewUserAppReviewDialog(context);
      }
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
              Navigator.of(context, rootNavigator: true).pop();
              _retry();
            },
            child: const Text("Retry"),
          ),
        ],
      );
      return;
    }

    if (canClaimDailyReward() && mounted && !isNewUser && !isGuest) {
      await buildDailyRewardDialog();
    }

    if (!isGuest && !isNewUser && mounted) {
      await checkPendingReferralReward(context, setState);
    }

    if (mounted) {
      setState(() {
        isLoading = false;
        _greeting = _buildGreeting();
      });
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

  int _foodLogStreak() => currentUserData?.foodLogStreak ?? 0;

  String _buildGreeting() {
    final hour = DateTime.now().hour;
    final rng = Random();

    const universal = [
      ("BACK FOR MORE", true),
      ("WHAT'S ON TODAY'S AGENDA", true),
      ("MAKING MOVES", false),
      ("LET'S GET IT", false),
      ("HOW'S EVERYTHING GOING", true),
      ("READY TO LEVEL UP", true),
      ("WELCOME BACK", false),
    ];

    final timeSlot = <(String, bool)>[];
    if (hour < 5) {
      timeSlot.addAll([
        ("STILL UP", true),
        ("LATE NIGHT GRIND", false),
        ("UP LATE", true),
        ("CAN'T SLEEP", true),
        ("STILL AWAKE", true),
      ]);
    } else if (hour < 12) {
      timeSlot.addAll([
        ("GOOD MORNING", false),
        ("RISE & SHINE", false),
        ("MORNING", false),
        ("HOW'S IT GOING", true),
        ("UP EARLY", true),
        ("GOOD TO SEE YOU", false),
      ]);
    } else if (hour < 17) {
      timeSlot.addAll([
        ("GOOD AFTERNOON", false),
        ("AFTERNOON", false),
        ("KEEP IT UP", false),
        ("HOW'S THE DAY GOING", true),
        ("STAYING FOCUSED", true),
      ]);
    } else if (hour < 21) {
      timeSlot.addAll([
        ("GOOD EVENING", false),
        ("EVENING", false),
        ("WINDING DOWN", true),
        ("HOW WAS YOUR DAY", true),
        ("GOOD TO SEE YOU", false),
      ]);
    } else {
      timeSlot.addAll([
        ("UP LATE", true),
        ("NIGHT OWL", false),
        ("STILL GOING", true),
        ("CAN'T SLEEP", true),
      ]);
    }

    final pool = [...timeSlot, ...universal];
    final (base, isQ) = pool[rng.nextInt(pool.length)];
    _greetingIsQuestion = isQ;
    return "$base,";
  }

  String _timeOfDayLabel() => _greeting;

  // Reads the daily claim streak from the backend-populated UserData field
  int _dailyClaimStreak() => currentUserData?.dailyClaimStreak ?? 0;

  Widget _buildStreakRow({
    required IconData icon,
    required String label,
    required int count,
    required int best,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.manrope(
                        color: lightenColor(appColorNotifier.value, 0.45),
                        fontSize: Responsive.font(context, 14),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (best > 0)
                      Text(
                        "Best: $best ${best == 1 ? 'day' : 'days'}",
                        style: GoogleFonts.manrope(
                          color: lightenColor(appColorNotifier.value, 0.45),
                          fontSize: Responsive.font(context, 11),
                        ),
                      ),
                  ],
                ),
              ),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: "$count",
                      style: GoogleFonts.manrope(
                        color: accentColor,
                        fontSize: Responsive.font(context, 20),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextSpan(
                      text: " ${count == 1 ? 'day' : 'days'}",
                      style: GoogleFonts.manrope(
                        color: accentColor,
                        fontSize: Responsive.font(context, 15),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
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
    if (isGuest) return const SizedBox.shrink();
    final foodStreak = _foodLogStreak();
    final claimStreak = _dailyClaimStreak();
    if (foodStreak == 0 && claimStreak == 0) return const SizedBox.shrink();
    final accentColor = lightenColor(appColorNotifier.value, 0.45);
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
              best: currentUserData?.foodLogStreakBest ?? 0,
              accentColor: accentColor,
              isLast: claimStreak == 0,
            ),
          if (claimStreak > 0)
            _buildStreakRow(
              icon: HugeIcons.strokeRoundedChartIncrease,
              label: "Daily reward streak",
              count: claimStreak,
              best: currentUserData?.dailyClaimStreakBest ?? 0,
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
                    color: lightenColor(appColorNotifier.value, 0.45),
                    fontSize: Responsive.font(context, 14),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  "Create an account for the full experience",
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
            tween: Tween(begin: _lastRenderedExp, end: exp.toDouble()),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOut,
            onEnd: () => _lastRenderedExp = exp.toDouble(),
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
                        isGuest
                            ? "Sign up to level up"
                            : "Level ${currentUserData?.level ?? 1}",
                        style: GoogleFonts.manrope(
                          color: isGuest
                              ? Colors.white54
                              : lightenColor(appColorNotifier.value, 0.45),
                          fontSize: Responsive.font(context, 16),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (!isGuest)
                        Text(
                          "${animatedExp.round()} / ${userManager.experienceNeeded ?? 0} XP",
                          style: GoogleFonts.manrope(
                            color: lightenColor(appColorNotifier.value, 0.45),
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
                                color: lightenColor(
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
                  SizedBox(height: Responsive.height(context, 6)),
                  // XP to next level + total XP earned
                  if (!isGuest)
                    Builder(
                      builder: (context) {
                        final needed = userManager.experienceNeeded ?? 0;
                        final remaining = (needed - animatedExp.round()).clamp(
                          0,
                          needed,
                        );
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "$remaining XP to Level ${(currentUserData?.level ?? 1) + 1}",
                              style: GoogleFonts.manrope(
                                color: lightenColor(
                                  appColorNotifier.value,
                                  0.45,
                                ),
                                fontSize: Responsive.font(context, 11),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              "Total: ${_formatNumber(userManager.totalXpEarned ?? 0)} XP",
                              style: GoogleFonts.manrope(
                                color: lightenColor(
                                  appColorNotifier.value,
                                  0.35,
                                ),
                                fontSize: Responsive.font(context, 11),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
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
    final accentColor = lightenColor(appColorNotifier.value, 0.45);
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
              color: lightenColor(appColorNotifier.value, 0.45),
              size: Responsive.scale(context, 24),
            ),
            SizedBox(width: Responsive.width(context, 14)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isGuest
                        ? "Sign up to claim daily rewards"
                        : canClaim
                        ? "Daily reward ready!"
                        : "Daily reward claimed today!",
                    style: GoogleFonts.manrope(
                      color: isGuest
                          ? Colors.white54
                          : canClaim
                          ? lightenColor(appColorNotifier.value, 0.45)
                          : lightenColor(appColorNotifier.value, 0.45),
                      fontSize: Responsive.font(context, 14),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    isGuest
                        ? "Create an account to start earning XP"
                        : canClaim
                        ? "Tap to claim your XP bonus"
                        : _timeUntilReward.inSeconds > 0
                        ? "Next reward in ${_timeUntilReward.inHours}h ${_timeUntilReward.inMinutes.remainder(60)}m"
                        : "You've already claimed today's reward",
                    style: GoogleFonts.manrope(
                      color: isGuest
                          ? Colors.white38
                          : lightenColor(appColorNotifier.value, 0.45),
                      fontSize: Responsive.font(context, 12),
                    ),
                  ),
                ],
              ),
            ),
            HugeIcon(
              icon: canClaim && !isGuest
                  ? HugeIcons.strokeRoundedArrowRight01
                  : HugeIcons.strokeRoundedCheckmarkCircle02,
              color: canClaim && !isGuest ? accentColor : Colors.white24,
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

  // Earn XP card: watch a rewarded ad for XP
  Widget _buildEarnXpCard() {
    final accent = lightenColor(appColorNotifier.value, 0.45);
    final accentDim = lightenColor(appColorNotifier.value, 0.3);
    return GestureDetector(
      onTap: () async {
        if (kIsWeb) {
          showFrostedAlertDialog(
            context: context,
            title: "Watch an Ad",
            content: Text(
              "This feature is only available on Android.",
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 13),
                color: Colors.white60,
              ),
            ),
            actions: [
              Expanded(
                child: Center(
                  child: Builder(
                    builder: (ctx) => TextButton(
                      onPressed: () async {
                        Navigator.of(ctx, rootNavigator: true).pop();
                        await launchUrl(
                          Uri.parse(
                            'https://play.google.com/store/apps/details?id=com.nicholasdakis.levelup',
                          ),
                        );
                      },
                      child: const Text("Get the App"),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Builder(
                    builder: (ctx) => TextButton(
                      onPressed: () =>
                          Navigator.of(ctx, rootNavigator: true).pop(),
                      child: const Text("Dismiss"),
                    ),
                  ),
                ),
              ),
            ],
          );
          return;
        }
        // disabled until AdMob account is approved
        showFrostedAlertDialog(
          context: context,
          title: "Coming Soon",
          content: Text(
            "This feature will be available soon!",
            style: GoogleFonts.manrope(
              fontSize: Responsive.font(context, 13),
              color: Colors.white60,
            ),
          ),
          actions: [
            Expanded(
              child: Center(
                child: Builder(
                  builder: (ctx) => TextButton(
                    onPressed: () =>
                        Navigator.of(ctx, rootNavigator: true).pop(),
                    child: const Text("OK"),
                  ),
                ),
              ),
            ),
          ],
        );
        return;
        // ignore: dead_code
        await adService.showRewardedAd(
          onRewarded: () async {
            await Future.delayed(const Duration(seconds: 2));
            await userManager.refreshUserData();
            if (mounted) setState(() {});
          },
        );
      },
      child: Opacity(
        opacity: 0.45,
        child: frostedGlassCard(
          context,
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.width(context, 16),
            vertical: Responsive.height(context, 14),
          ),
          child: Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedPlayCircle,
                color: accentDim,
                size: Responsive.scale(context, 28),
              ),
              SizedBox(width: Responsive.width(context, 14)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Watch an Ad",
                      style: GoogleFonts.manrope(
                        fontSize: Responsive.font(context, 15),
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      "Coming soon",
                      style: GoogleFonts.manrope(
                        fontSize: Responsive.font(context, 12),
                        color: accentDim,
                      ),
                    ),
                  ],
                ),
              ),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                color: accent,
                size: Responsive.scale(context, 20),
              ),
            ],
          ),
        ),
      ),
    );
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
                        icon: HugeIcons.strokeRoundedFire,
                        color: lightenColor(appColorNotifier.value, 0.45),
                        size: Responsive.scale(context, 14),
                      ),
                      SizedBox(width: Responsive.width(context, 5)),
                      Text(
                        "Calories today",
                        style: GoogleFonts.manrope(
                          color: lightenColor(appColorNotifier.value, 0.45),
                          fontSize: Responsive.font(context, 11),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: Responsive.height(context, 6)),
                  Text(
                    "$calories",
                    style: GoogleFonts.manrope(
                      color: lightenColor(appColorNotifier.value, 0.45),
                      fontSize: Responsive.font(context, 22),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (goal > 0) ...[
                    Text(
                      "/ $goal goal",
                      style: GoogleFonts.manrope(
                        color: lightenColor(appColorNotifier.value, 0.45),
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
                        color: lightenColor(appColorNotifier.value, 0.45),
                        size: Responsive.scale(context, 14),
                      ),
                      SizedBox(width: Responsive.width(context, 5)),
                      Text(
                        "Logs today",
                        style: GoogleFonts.manrope(
                          color: lightenColor(appColorNotifier.value, 0.45),
                          fontSize: Responsive.font(context, 11),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: Responsive.height(context, 6)),
                  Text(
                    "$foodCount",
                    style: GoogleFonts.manrope(
                      color: lightenColor(appColorNotifier.value, 0.45),
                      fontSize: Responsive.font(context, 22),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    foodCount == 1 ? "item" : "items",
                    style: GoogleFonts.manrope(
                      color: lightenColor(appColorNotifier.value, 0.45),
                      fontSize: Responsive.font(context, 11),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
                          ? Responsive.height(context, 16) +
                                MediaQuery.of(context).padding.top
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
          highlightColor: lightenColor(appColorNotifier.value, 0.45),
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
            body: Stack(
              children: [
                ScrollConfiguration(
                  behavior: NoGlowScrollBehavior(),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: Responsive.centeredHorizontalPadding(context, 24),
                        right: Responsive.centeredHorizontalPadding(
                          context,
                          24,
                        ),
                        top:
                            MediaQuery.paddingOf(context).top +
                            Responsive.height(context, 16),
                        bottom: Responsive.height(context, 20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Guest banner
                          if (isGuest) ...[
                            _buildGuestBanner(),
                            SizedBox(height: Responsive.height(context, 16)),
                          ],

                          // Greeting: time of day small + name big, settings icon top right
                          _maybeAnimate(
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        username != null
                                            ? _timeOfDayLabel()
                                            : "WELCOME TO LEVEL UP!",
                                        style: GoogleFonts.manrope(
                                          color: lightenColor(
                                            appColorNotifier.value,
                                            0.45,
                                          ),
                                          fontSize: Responsive.font(
                                            context,
                                            14,
                                          ),
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: Responsive.scale(
                                            context,
                                            1.2,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        height: Responsive.height(context, 2),
                                      ),
                                      Text(
                                        username != null
                                            ? "$username${_greetingIsQuestion ? "?" : "!"}"
                                            : "",
                                        style: GoogleFonts.manrope(
                                          color: lightenColor(
                                            appColorNotifier.value,
                                            0.45,
                                          ),
                                          fontSize: Responsive.font(
                                            context,
                                            26,
                                          ),
                                          fontWeight: FontWeight.w800,
                                          height: 1.1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SettingsIconButton(
                                  onTap: () =>
                                      _scaffoldKey.currentState?.openDrawer(),
                                ),
                              ],
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

                          if (!isGuest) ...[
                            sectionHeader("EARN XP", context),
                            _maybeAnimate(
                              IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(child: _buildEarnXpCard()),
                                    SizedBox(
                                      width: Responsive.width(context, 12),
                                    ),
                                    Expanded(
                                      child: ListenableBuilder(
                                        listenable: userDataNotifier,
                                        builder: (context, _) =>
                                            buildReferralsCard(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              150.ms,
                            ),
                            SizedBox(height: Responsive.height(context, 20)),
                          ],

                          if (!isGuest) ...[
                            sectionHeader("STREAKS", context),
                            _maybeAnimate(_buildStreakCard(), 180.ms),
                            SizedBox(height: Responsive.height(context, 20)),
                          ],

                          sectionHeader("STATS", context),
                          _maybeAnimate(_buildQuickStats(), 220.ms),
                          SizedBox(height: Responsive.height(context, 20)),

                          sectionHeader("TOOLS", context),
                          // Tool tiles row
                          _maybeAnimate(
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        trackTrivialAchievement(
                                          "open_reminders",
                                        );
                                        context.push('/reminders');
                                      },
                                      child: frostedGlassCard(
                                        context,
                                        baseRadius: 14,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: Responsive.width(
                                            context,
                                            16,
                                          ),
                                          vertical: Responsive.height(
                                            context,
                                            14,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                HugeIcon(
                                                  icon: HugeIcons
                                                      .strokeRoundedAlarmClock,
                                                  color: lightenColor(
                                                    appColorNotifier.value,
                                                    0.35,
                                                  ),
                                                  size: Responsive.scale(
                                                    context,
                                                    20,
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: Responsive.width(
                                                    context,
                                                    8,
                                                  ),
                                                ),
                                                Text(
                                                  "Reminders",
                                                  style: GoogleFonts.manrope(
                                                    color: lightenColor(
                                                      appColorNotifier.value,
                                                      0.45,
                                                    ),
                                                    fontSize: Responsive.font(
                                                      context,
                                                      13,
                                                    ),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Icon(
                                              Icons.chevron_right,
                                              color: lightenColor(
                                                appColorNotifier.value,
                                                0.3,
                                              ),
                                              size: Responsive.scale(
                                                context,
                                                18,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: Responsive.width(context, 12),
                                  ),
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
                                        baseRadius: 14,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: Responsive.width(
                                            context,
                                            16,
                                          ),
                                          vertical: Responsive.height(
                                            context,
                                            14,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  HugeIcon(
                                                    icon: HugeIcons
                                                        .strokeRoundedCalculate,
                                                    color: lightenColor(
                                                      appColorNotifier.value,
                                                      0.35,
                                                    ),
                                                    size: Responsive.scale(
                                                      context,
                                                      20,
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: Responsive.width(
                                                      context,
                                                      8,
                                                    ),
                                                  ),
                                                  Flexible(
                                                    child: Text(
                                                      "Calorie Calculator",
                                                      style:
                                                          GoogleFonts.manrope(
                                                            color: lightenColor(
                                                              appColorNotifier
                                                                  .value,
                                                              0.45,
                                                            ),
                                                            fontSize:
                                                                Responsive.font(
                                                                  context,
                                                                  13,
                                                                ),
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Icon(
                                              Icons.chevron_right,
                                              color: lightenColor(
                                                appColorNotifier.value,
                                                0.3,
                                              ),
                                              size: Responsive.scale(
                                                context,
                                                18,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            240.ms,
                          ),

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
