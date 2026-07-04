// home_screen.dart
import 'package:firebase_analytics/firebase_analytics.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:level_up/utility/confetti.dart';
import 'screens/settings/settings_icon_button.dart';
import 'screens/settings.dart';
import 'screens/home/water_log_sheet.dart';
import 'screens/home/weight_log_sheet.dart';
import 'screens/home/home_logging_cards.dart';
import 'screens/home/home_greeting.dart';
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

  bool _adWatching = false;
  bool _shimmerPaused = false;
  bool _onboardingInProgress = false;

  Timer? _countdownTimer;
  Duration _timeUntilReward = Duration.zero;
  double _lastRenderedExp =
      0; // reset on each load so the bar always animates in
  Uint8List? _pfpBytes;
  bool _pfpVisible = false;
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

    if (appReadyNotifier.value && !userManager.lastLoadFailed && !isNewUser) {
      isLoading = false;
    }

    appReadyNotifier.addListener(_onAppReady);
    if (appReadyNotifier.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onAppReady();
      });
    }
  }

  Future<void> _showWaterLogSheet() => showWaterLogSheet(context);

  Future<void> _showWeightLogSheet() => showWeightLogSheet(context);

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
    if (newValue.inMinutes == _timeUntilReward.inMinutes &&
        !canClaimDailyReward()) {
      return;
    }
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
      appReadyNotifier.value &&
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
    setState(() => _shimmerPaused = true);
    await DailyRewardDialog().showDailyRewardDialog(
      context,
      dailyRewardConfettiController,
    );
    if (mounted) {
      _updateCountdown();
      setState(() => _shimmerPaused = false);
    }
  }

  Future<void> initializeUser() async {
    if (currentUserData == null) return;

    if (userManager.lastLoadFailed) {
      if (!mounted) return;
      await _retry();
      return;
    }

    if (mounted) {
      final pfp = currentUserData?.pfpBase64;
      final bytes = pfp != null
          ? (Uri.parse(pfp).data?.contentAsBytes() ?? base64Decode(pfp))
          : null;
      setState(() {
        isLoading = false;
        _greeting = _buildGreeting();
        _pfpBytes = bytes;
      });
      if (bytes != null) {
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) setState(() => _pfpVisible = true);
        });
      }
      if (kIsWeb &&
          !kDebugMode &&
          !isNewUser &&
          web_fcm.getNotificationPermission() != 'granted' &&
          currentUserData!.notificationsEnabled) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) showBrowserBlockedDialog(context);
        });
      }
      if (isNewUser) {
        setState(() => _onboardingInProgress = true);
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;

          // Steps 1-4: unified wizard (value pitch, goals, calorie setup, activation)
          final choice = await showOnboardingWizard(context);
          if (!mounted) return;

          setState(() => _onboardingInProgress = false);
          if (mounted) setState(() => _greeting = _buildGreeting());

          // re-read choice for navigation below
          if (!mounted) return;

          if (choice == 'food') {
            onboardingHintNotifier.value = 'food';
            context.go('/food-logging');
          } else if (choice == 'settings') {
            onboardingHintNotifier.value = 'settings';
            context.push('/settings/preferences');
          } else if (choice == 'workout') {
            onboardingHintNotifier.value = 'workout';
            context.go('/workout');
          } else {
            onboardingHintNotifier.value = 'reward';
            if (mounted) await requestNotificationPermissionIfNeeded(context);
          }
        });
        return;
      }

      if (!isGuest && mounted) {
        await checkPendingReferralReward(context, setState);
      }
    }
  }

  Future<void> _retry() async {
    while (mounted) {
      setState(() {
        loadFailed = false;
        isLoading = true;
      });
      await userManager.loadUserData();
      if (!mounted) return;
      if (!userManager.lastLoadFailed && currentUserData != null) {
        appColorNotifier.value = currentUserData!.appColor;
        expNotifier.value = currentUserData!.expPoints;
        // notifyListeners won't fire if value was already true, so call initializeUser directly
        appReadyNotifier.value = true;
        initializeUser();
        return;
      }
      // still failed, show the dialog again and wait for another retry tap
      setState(() => loadFailed = true);
      await showFrostedAlertDialog(
        context: context,
        dismissible: false,
        title: "Failed to load",
        content: Text(
          "Check your connection and try again.",
          style: GoogleFonts.manrope(color: Colors.white54, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            child: Text("Retry", style: dialogButtonStyle(confirm: true)),
          ),
        ],
      );
    }
  }

  bool isLoading = true;
  bool loadFailed = false;

  // Builds a greeting based on time of day plus a random variant from that pool

  int _foodLogStreak() => currentUserData?.foodLogStreak ?? 0;

  // Picks a fresh greeting and updates the question flag together
  String _buildGreeting() {
    final result = buildGreeting();
    _greetingIsQuestion = result.isQuestion;
    return result.greeting;
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
    String? overrideSubtitle,
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
                    Text(
                      overrideSubtitle ??
                          (best > 0
                              ? "Best: $best ${best == 1 ? 'day' : 'days'}"
                              : "No best yet"),
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
    final foodStreak = isGuest ? 0 : _foodLogStreak();
    final claimStreak = isGuest ? 0 : _dailyClaimStreak();
    final workoutStreak = isGuest ? 0 : (currentUserData?.workoutStreak ?? 0);
    final accentColor = lightenColor(appColorNotifier.value, 0.45);
    final foodStreakBest = isGuest
        ? 0
        : (currentUserData?.foodLogStreakBest ?? 0);
    final workoutStreakBest = isGuest
        ? 0
        : (currentUserData?.workoutStreakBest ?? 0);
    final guestSubtitle = "Create an account to track your streaks";
    return frostedGlassCard(
      context,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.width(context, 20),
        vertical: Responsive.height(context, 4),
      ),
      child: Column(
        children: [
          _buildStreakRow(
            icon: HugeIcons.strokeRoundedChartIncrease,
            label: "Daily reward streak",
            count: claimStreak,
            best: isGuest ? -1 : (currentUserData?.dailyClaimStreakBest ?? 0),
            accentColor: accentColor,
            isLast: false,
            overrideSubtitle: isGuest ? guestSubtitle : null,
          ),
          _buildStreakRow(
            icon: HugeIcons.strokeRoundedFire,
            label: "Food logging streak",
            count: foodStreak,
            best: foodStreakBest,
            accentColor: accentColor,
            isLast: false,
            overrideSubtitle: isGuest ? guestSubtitle : null,
          ),
          _buildStreakRow(
            icon: HugeIcons.strokeRoundedDumbbell01,
            label: "Workout streak",
            count: workoutStreak,
            best: workoutStreakBest,
            accentColor: accentColor,
            isLast: true,
            overrideSubtitle: isGuest ? guestSubtitle : null,
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

  // XP bar card: hero layout with level badge on the left and XP count on the right
  Widget _buildXpCard() {
    final base = appColorNotifier.value;
    final c = cardColors(base);
    final accent = c.onCard;
    final dim = c.onCard.withAlpha(180);
    final level = isGuest ? 0 : (currentUserData?.level ?? 1);

    return ValueListenableBuilder<int>(
      valueListenable: expNotifier,
      builder: (context, exp, _) {
        return TweenAnimationBuilder<double>(
          key: ValueKey(
            isLoading,
          ), // forces tween to restart from 0 once loading finishes
          tween: Tween(
            begin: _lastRenderedExp,
            end: isLoading ? 0.0 : exp.toDouble(),
          ),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOut,
          onEnd: () => _lastRenderedExp = exp.toDouble(),
          builder: (context, animatedExp, _) {
            final needed = (userManager.experienceNeeded ?? 1).toDouble();
            final progress = (animatedExp / needed).clamp(0.0, 1.0);
            final remaining = ((needed - animatedExp).ceil()).clamp(
              0,
              needed.toInt(),
            );

            return DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  Responsive.scale(context, 20),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: c.gradient,
                ),
                border: Border.all(color: c.border, width: 1),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.width(context, 20),
                  vertical: Responsive.height(context, 16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Level badge: white fill always visible, pfp fades in on top once decoded
                        Builder(
                          builder: (context) {
                            final hasPfp = _pfpBytes != null;
                            final borderRadius = BorderRadius.circular(
                              Responsive.scale(context, 10),
                            );
                            return Container(
                              decoration: BoxDecoration(
                                borderRadius: borderRadius,
                                border: hasPfp
                                    ? Border.all(
                                        color: Colors.white.withAlpha(180),
                                        width: Responsive.width(context, 1.5),
                                      )
                                    : null,
                              ),
                              child: ClipRRect(
                                borderRadius: borderRadius,
                                child: SizedBox(
                                  width: Responsive.scale(context, 44),
                                  height: Responsive.scale(context, 44),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Container(
                                        color: Colors.white.withAlpha(220),
                                      ),
                                      if (hasPfp)
                                        AnimatedOpacity(
                                          opacity: _pfpVisible ? 1.0 : 0.0,
                                          duration: const Duration(
                                            milliseconds: 400,
                                          ),
                                          child: Image.memory(
                                            _pfpBytes!,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: double.infinity,
                                          ),
                                        ),
                                      // Scrim fades in with the pfp so text stays readable
                                      if (hasPfp)
                                        AnimatedOpacity(
                                          opacity: _pfpVisible ? 1.0 : 0.0,
                                          duration: const Duration(
                                            milliseconds: 400,
                                          ),
                                          child: Container(
                                            color: Colors.black.withAlpha(100),
                                          ),
                                        ),
                                      Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            "LVL",
                                            style: GoogleFonts.manrope(
                                              color: hasPfp
                                                  ? Colors.white
                                                  : darkenColor(base, 0.05),
                                              fontSize: Responsive.font(
                                                context,
                                                8,
                                              ),
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          Text(
                                            "$level",
                                            style: GoogleFonts.manrope(
                                              color: hasPfp
                                                  ? Colors.white
                                                  : darkenColor(base, 0.05),
                                              fontSize: Responsive.font(
                                                context,
                                                18,
                                              ),
                                              fontWeight: FontWeight.w800,
                                              height: 1.1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        SizedBox(width: Responsive.width(context, 14)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    isGuest
                                        ? "Sign up to level up"
                                        : "Level $level",
                                    style: GoogleFonts.manrope(
                                      color: isGuest ? Colors.white54 : accent,
                                      fontSize: Responsive.font(context, 15),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (!isGuest)
                                    Text(
                                      "${animatedExp.round()} / ${userManager.experienceNeeded ?? 0} XP",
                                      style: GoogleFonts.manrope(
                                        color: dim,
                                        fontSize: Responsive.font(context, 12),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: Responsive.height(context, 14)),
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
                                  color: Colors.white.withAlpha(200),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "$remaining XP to Level ${level + 1}",
                            style: GoogleFonts.manrope(
                              color: accent,
                              fontSize: Responsive.font(context, 11),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            "Total: ${_formatNumber(userManager.totalXpEarned ?? 0)} XP",
                            style: GoogleFonts.manrope(
                              color: dim,
                              fontSize: Responsive.font(context, 11),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Daily reward card: same gradient tile style as the earn XP cards
  Widget _buildDailyRewardCard() {
    final base = appColorNotifier.value;
    final canClaim = canClaimDailyReward();
    final c = cardColors(base);
    final accent = c.onCard;
    final dim = c.onCard.withAlpha(180);
    final radius = BorderRadius.circular(Responsive.scale(context, 16));

    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: c.gradient,
        ),
        border: Border.all(color: c.border, width: 1),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: canClaim && !isGuest ? () => buildDailyRewardDialog() : null,
            splashColor: c.splashColor,
            highlightColor: c.highlightColor,
            child: Padding(
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
                    color: accent,
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
                            color: isGuest ? dim : accent,
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
                            color: dim,
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
                    color: canClaim && !isGuest ? accent : dim,
                    size: Responsive.scale(context, 18),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (!canClaim || isGuest || _shimmerPaused || _onboardingInProgress) {
      return card;
    }

    // shimmer effect on card for claimable daily reward
    return card
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          delay: 1200.ms,
          duration: 1000.ms,
          angle: 0,
          size: 0.6,
          color: accent.withAlpha(35),
        );
  }

  // Earn XP card: square action tile with icon on top and label below
  // Wrapped in a blur overlay while ads are unavailable
  Widget _buildEarnXpCard() {
    final base = appColorNotifier.value;
    final c = cardColors(base);
    final accent = c.onCard;
    final dim = c.onCard.withAlpha(180);
    final radius = BorderRadius.circular(Responsive.scale(context, 16));

    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: c.gradient,
        ),
        border: Border.all(color: c.border, width: 1),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Padding(
          padding: EdgeInsets.all(Responsive.scale(context, 12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              Container(
                padding: EdgeInsets.all(Responsive.scale(context, 8)),
                decoration: BoxDecoration(
                  color: c.iconBox,
                  borderRadius: BorderRadius.circular(
                    Responsive.scale(context, 10),
                  ),
                ),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedPlayCircle,
                  color: accent,
                  size: Responsive.scale(context, 22),
                ),
              ),
              SizedBox(height: Responsive.height(context, 8)),
              Text(
                "Watch an Ad",
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: Responsive.font(context, 14),
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                "Earn XP",
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: Responsive.font(context, 11),
                  color: dim,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return GestureDetector(
      onTap: _adWatching
          ? null
          : () async {
              if (!adService.isReady) {
                await showFrostedAlertDialog(
                  context: context,
                  title: "Not available right now",
                  content: Text(
                    "Rewarded ads are currently under review and will be available soon.",
                    style: GoogleFonts.manrope(
                      fontSize: Responsive.font(context, 13),
                      color: Colors.white60,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  actions: [
                    Expanded(
                      child: Center(
                        child: Builder(
                          builder: (ctx) => TextButton(
                            onPressed: () =>
                                Navigator.of(ctx, rootNavigator: true).pop(),
                            child: Text(
                              "Got it",
                              style: dialogButtonStyle(confirm: true),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
                return;
              }
              setState(() => _adWatching = true);
              await adService.showRewardedAd(
                onRewarded: () async {
                  if (isGuest) {
                    // show signup prompt after the ad reward fires (user finished watching)
                    if (mounted) {
                      await showFrostedAlertDialog(
                        context: context,
                        title: "Create a free account",
                        content: Text(
                          "Sign up to earn XP for every ad you watch and start leveling up.",
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 13),
                            color: Colors.white60,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(
                              context,
                              rootNavigator: true,
                            ).pop(),
                            child: Text(
                              "Maybe later",
                              style: dialogButtonStyle(),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.of(context, rootNavigator: true).pop();
                              await authService.value.signOut();
                            },
                            child: Text(
                              "Sign up",
                              style: dialogButtonStyle(confirm: true),
                            ),
                          ),
                        ],
                      );
                    }
                    return;
                  }
                  await userManager.loadUserData();
                  if (mounted) {
                    expNotifier.value = currentUserData?.expPoints ?? 0;
                    userDataNotifier.notifyListeners();
                  }
                },
              );
              if (mounted) setState(() => _adWatching = false);
            },
      child: card,
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
      children: [IgnorePointer(ignoring: loadFailed, child: _buildBody())],
    );
  }

  Widget _buildBody() {
    final username =
        (currentUserData?.username == null ||
            currentUserData?.username == currentUserData?.uid)
        ? null
        : currentUserData!.username!;

    return Skeletonizer(
      enabled: isLoading,
      effect: ShimmerEffect(
        baseColor: lightenColor(appColorNotifier.value, 0.10),
        highlightColor: lightenColor(appColorNotifier.value, 0.22),
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
                      right: Responsive.centeredHorizontalPadding(context, 24),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                        fontSize: Responsive.font(context, 14),
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
                                        fontSize: Responsive.font(context, 26),
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

                        ...[
                          sectionHeader("EARN XP", context),
                          _maybeAnimate(
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                            120.ms,
                          ),
                          SizedBox(height: Responsive.height(context, 12)),
                          // Daily reward sits below the earn XP tiles as a slim full-width row
                          _maybeAnimate(_buildDailyRewardCard(), 150.ms),
                          SizedBox(height: Responsive.height(context, 20)),
                        ],

                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 600),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: sectionHeader("LOGGING", context),
                            ),
                          ),
                        ),
                        _maybeAnimate(
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 600),
                              child: isGuest
                                  ? HomeLoggingCards(
                                      onShowWaterSheet: _showWaterLogSheet,
                                      onShowWeightSheet: _showWeightLogSheet,
                                    )
                                  : ListenableBuilder(
                                      listenable: userDataNotifier,
                                      builder: (context, _) => HomeLoggingCards(
                                        onShowWaterSheet: _showWaterLogSheet,
                                        onShowWeightSheet: _showWeightLogSheet,
                                      ),
                                    ),
                            ),
                          ),
                          160.ms,
                        ),
                        SizedBox(height: Responsive.height(context, 20)),

                        sectionHeader("STREAKS", context),
                        _maybeAnimate(_buildStreakCard(), 180.ms),
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
                                      trackTrivialAchievement("open_reminders");
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
                                            size: Responsive.scale(context, 18),
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
                                                    style: GoogleFonts.manrope(
                                                      color: lightenColor(
                                                        appColorNotifier.value,
                                                        0.45,
                                                      ),
                                                      fontSize: Responsive.font(
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
                                            size: Responsive.scale(context, 18),
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
                child: buildDailyRewardConfetti(dailyRewardConfettiController),
              ),
              // Onboarding hint for users who chose "claim daily reward"
              OnboardingHint(
                hintKey: 'reward',
                title: 'Welcome to your dashboard',
                description:
                    'Track XP, log food and water, claim your daily reward, build streaks, and more',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
