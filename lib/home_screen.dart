// home_screen.dart
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'dart:async';
import 'dart:convert';
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
import 'utility/food_logging_helper.dart' show FoodLoggingHelper;
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
  final TextEditingController _weightController = TextEditingController();
  late VoidCallback _appColorListener;

  // 0 = dashboard step, 1 = nav bar step, 2 = settings step, -1 = tour not active
  int _tourStep = -1;
  bool _tapHintVisible = false;
  Timer? _tapHintTimer;

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

  String _todayDateKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _showWaterLogSheet() async {
    final isImperial = currentUserData?.units == 'imperial';
    DateTime selectedDate = DateTime.now();
    final customController = TextEditingController();

    String? feedback;
    // keeps the pill text visible while it fades out, otherwise it blanks before the animation finishes
    String lastFeedback = 'ok';

    String dateKeyFor(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    String labelFor(DateTime d) {
      final today = DateTime.now();
      if (d.year == today.year &&
          d.month == today.month &&
          d.day == today.day) {
        return "Today";
      }
      final yesterday = today.subtract(const Duration(days: 1));
      if (d.year == yesterday.year &&
          d.month == yesterday.month &&
          d.day == yesterday.day) {
        return "Yesterday";
      }
      const months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      return '${months[d.month - 1]} ${d.day}';
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final dateKey = dateKeyFor(selectedDate);
          final entries = List<int>.from(
            currentUserData?.waterEntriesByDate[dateKey] ?? [],
          );

          final c = cardColors(appColorNotifier.value);
          final onCard = c.onCard;
          final onCardDim = c.onCard.withAlpha(140);
          // keyboard pushes up the sheet so we grow the height to match, then pad the bottom by the same amount
          return SizedBox(
            height:
                MediaQuery.of(ctx).size.height * 0.55 +
                MediaQuery.of(ctx).viewInsets.bottom,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: darkenColor(
                        appColorNotifier.value,
                        0.1,
                      ).withAlpha(210),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      border: Border(
                        top: BorderSide(color: c.border, width: 1),
                      ),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      Responsive.width(ctx, 24),
                      Responsive.height(ctx, 20),
                      Responsive.width(ctx, 24),
                      Responsive.height(ctx, 32),
                    ),
                    child: Stack(
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "LOG WATER",
                              style: GoogleFonts.manrope(
                                fontSize: Responsive.font(ctx, 11),
                                color: onCardDim,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                              ),
                            ),
                            SizedBox(height: Responsive.height(ctx, 12)),
                            // Date navigation row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                GestureDetector(
                                  onTap: () => setSheet(() {
                                    selectedDate = selectedDate.subtract(
                                      const Duration(days: 1),
                                    );
                                    customController.clear();
                                  }),
                                  child: Icon(
                                    Icons.chevron_left,
                                    color: onCard,
                                    size: Responsive.scale(ctx, 22),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: ctx,
                                      initialDate: selectedDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now(),
                                    );
                                    if (picked != null) {
                                      setSheet(() {
                                        selectedDate = picked;
                                        customController.clear();
                                      });
                                    }
                                  },
                                  child: Text(
                                    labelFor(selectedDate),
                                    style: GoogleFonts.manrope(
                                      color: onCard,
                                      fontSize: Responsive.font(ctx, 14),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                // null disables the tap, which grays out the arrow on today
                                GestureDetector(
                                  onTap:
                                      selectedDate.day == DateTime.now().day &&
                                          selectedDate.month ==
                                              DateTime.now().month &&
                                          selectedDate.year ==
                                              DateTime.now().year
                                      ? null
                                      : () => setSheet(() {
                                          selectedDate = selectedDate.add(
                                            const Duration(days: 1),
                                          );
                                          customController.clear();
                                        }),
                                  child: Icon(
                                    Icons.chevron_right,
                                    color:
                                        selectedDate.day == DateTime.now().day
                                        ? onCard.withAlpha(60)
                                        : onCard,
                                    size: Responsive.scale(ctx, 22),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: Responsive.height(ctx, 16)),
                            Row(
                              children: [
                                for (final amount
                                    in isImperial
                                        ? [8, 12, 16]
                                        : [250, 500, 750])
                                  Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        right: amount != (isImperial ? 16 : 750)
                                            ? Responsive.width(ctx, 8)
                                            : 0,
                                      ),
                                      child: GestureDetector(
                                        onTap: () async {
                                          // everything is stored as ml so oz gets converted before it goes in
                                          final ml = isImperial
                                              ? (amount * 29.5735).round()
                                              : amount;
                                          entries.add(ml);
                                          await userManager.updateWaterLog(
                                            dateKey,
                                            entries,
                                          );
                                          // setSheet throws if the user closed the sheet before this finished
                                          bool sheetMounted = true;
                                          try {
                                            setSheet(() {
                                              feedback = 'ok';
                                              lastFeedback = 'ok';
                                            });
                                          } catch (_) {
                                            sheetMounted = false;
                                          }
                                          if (!sheetMounted) {
                                            if (mounted) setState(() {});
                                            return;
                                          }
                                          await Future.delayed(
                                            const Duration(milliseconds: 1600),
                                          );
                                          // setting feedback to null starts the fade-out
                                          try {
                                            setSheet(() => feedback = null);
                                          } catch (_) {}
                                          if (mounted) setState(() {});
                                        },
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            vertical: Responsive.height(
                                              ctx,
                                              12,
                                            ),
                                          ),
                                          decoration: BoxDecoration(
                                            color: onCard.withAlpha(15),
                                            borderRadius: BorderRadius.circular(
                                              Responsive.scale(ctx, 12),
                                            ),
                                            border: Border.all(
                                              color: onCard.withAlpha(40),
                                            ),
                                          ),
                                          child: Text(
                                            isImperial
                                                ? "+${amount}oz"
                                                : "+${amount}ml",
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.manrope(
                                              color: onCard,
                                              fontSize: Responsive.font(
                                                ctx,
                                                14,
                                              ),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(height: Responsive.height(ctx, 16)),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: customController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(5),
                                    ],
                                    style: GoogleFonts.manrope(color: onCard),
                                    decoration: InputDecoration(
                                      hintText: isImperial
                                          ? "Custom amount (oz)"
                                          : "Custom amount (ml)",
                                      hintStyle: GoogleFonts.manrope(
                                        color: onCardDim,
                                      ),
                                      enabledBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: onCard.withAlpha(60),
                                        ),
                                      ),
                                      focusedBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(color: onCard),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: Responsive.width(ctx, 12)),
                                TextButton(
                                  onPressed: () async {
                                    // oz can be fractional so imperial parses as double, metric is always whole ml
                                    final val = isImperial
                                        ? ((double.tryParse(
                                                        customController.text
                                                            .trim(),
                                                      ) ??
                                                      0) *
                                                  29.5735)
                                              .round()
                                        : int.tryParse(
                                                customController.text.trim(),
                                              ) ??
                                              0;
                                    if (val > 0) {
                                      entries.add(val);
                                      await userManager.updateWaterLog(
                                        dateKey,
                                        entries,
                                      );
                                      bool sheetMounted = true;
                                      try {
                                        setSheet(() {
                                          feedback = 'ok';
                                          lastFeedback = 'ok';
                                          customController.clear();
                                        });
                                      } catch (_) {
                                        sheetMounted = false;
                                      }
                                      if (!sheetMounted) {
                                        if (mounted) setState(() {});
                                        return;
                                      }
                                      await Future.delayed(
                                        const Duration(milliseconds: 1600),
                                      );
                                      try {
                                        setSheet(() => feedback = null);
                                      } catch (_) {}
                                      if (mounted) setState(() {});
                                    }
                                  },
                                  child: Text(
                                    "Add",
                                    style: TextStyle(color: onCard),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: Responsive.height(ctx, 20)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "ENTRIES",
                                  style: GoogleFonts.manrope(
                                    fontSize: Responsive.font(ctx, 11),
                                    color: onCardDim,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                if (entries.isNotEmpty)
                                  Text(
                                    isImperial
                                        ? "${(entries.fold(0, (s, e) => s + e) / 29.5735).toStringAsFixed(1)} oz total"
                                        : "${entries.fold(0, (s, e) => s + e)} ml total",
                                    style: GoogleFonts.manrope(
                                      fontSize: Responsive.font(ctx, 12),
                                      color: onCard,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(height: Responsive.height(ctx, 8)),
                            if (entries.isEmpty)
                              Text(
                                "No entries today",
                                style: GoogleFonts.manrope(
                                  color: onCardDim,
                                  fontSize: Responsive.font(ctx, 13),
                                ),
                              )
                            else
                              // cap the list height so it doesn't push everything else off screen
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight:
                                      MediaQuery.of(ctx).size.height * 0.28,
                                ),
                                child: SingleChildScrollView(
                                  child: Column(
                                    children: [
                                      // Reversed so newest entry appears at top
                                      for (
                                        int i = entries.length - 1;
                                        i >= 0;
                                        i--
                                      ) ...[
                                        if (i < entries.length - 1)
                                          Divider(
                                            color: onCard.withAlpha(20),
                                            height: 1,
                                          ),
                                        Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: Responsive.height(
                                              ctx,
                                              10,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              HugeIcon(
                                                icon: HugeIcons
                                                    .strokeRoundedDroplet,
                                                color: onCardDim,
                                                size: Responsive.scale(ctx, 15),
                                              ),
                                              SizedBox(
                                                width: Responsive.width(
                                                  ctx,
                                                  10,
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  isImperial
                                                      ? "${(entries[i] / 29.5735).toStringAsFixed(1)} oz"
                                                      : "${entries[i]} ml",
                                                  style: GoogleFonts.manrope(
                                                    color: onCard,
                                                    fontSize: Responsive.font(
                                                      ctx,
                                                      14,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap: () async {
                                                  final confirmed =
                                                      await showFrostedAlertDialog<
                                                        bool
                                                      >(
                                                        context: ctx,
                                                        title: "Remove Entry",
                                                        content: Text(
                                                          isImperial
                                                              ? "Remove ${(entries[i] / 29.5735).toStringAsFixed(1)} oz from ${labelFor(selectedDate).toLowerCase()}?"
                                                              : "Remove ${entries[i]} ml from ${labelFor(selectedDate).toLowerCase()}?",
                                                          style:
                                                              GoogleFonts.manrope(
                                                                color: Colors
                                                                    .white54,
                                                                fontSize: 13,
                                                              ),
                                                          textAlign:
                                                              TextAlign.center,
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.of(
                                                                  ctx,
                                                                  rootNavigator:
                                                                      true,
                                                                ).pop(false),
                                                            child: const Text(
                                                              "Cancel",
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .white54,
                                                              ),
                                                            ),
                                                          ),
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.of(
                                                                  ctx,
                                                                  rootNavigator:
                                                                      true,
                                                                ).pop(true),
                                                            child: const Text(
                                                              "Remove",
                                                            ),
                                                          ),
                                                        ],
                                                      );
                                                  if (confirmed == true) {
                                                    entries.removeAt(i);
                                                    await userManager
                                                        .updateWaterLog(
                                                          dateKey,
                                                          entries,
                                                        );
                                                    bool sheetMounted = true;
                                                    try {
                                                      setSheet(() {
                                                        feedback = 'deleted';
                                                        lastFeedback =
                                                            'deleted';
                                                      });
                                                    } catch (_) {
                                                      sheetMounted = false;
                                                    }
                                                    if (!sheetMounted) {
                                                      if (mounted) {
                                                        setState(() {});
                                                      }
                                                      return;
                                                    }
                                                    await Future.delayed(
                                                      const Duration(
                                                        milliseconds: 1600,
                                                      ),
                                                    );
                                                    try {
                                                      setSheet(
                                                        () => feedback = null,
                                                      );
                                                    } catch (_) {}
                                                    if (mounted) {
                                                      setState(() {});
                                                    }
                                                  }
                                                },
                                                child: HugeIcon(
                                                  icon: HugeIcons
                                                      .strokeRoundedDelete02,
                                                  color: onCardDim,
                                                  size: Responsive.scale(
                                                    ctx,
                                                    18,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        // Pill anchored top-right, always in the tree so AnimatedOpacity/AnimatedSlide
                        // can transition smoothly. Visibility driven by opacity, not conditional render
                        Positioned(
                          top: 0,
                          right: 0,
                          child: IgnorePointer(
                            child: AnimatedOpacity(
                              opacity: feedback != null ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: Responsive.width(ctx, 10),
                                  vertical: Responsive.height(ctx, 5),
                                ),
                                decoration: BoxDecoration(
                                  color: onCard.withAlpha(40),
                                  borderRadius: BorderRadius.circular(
                                    Responsive.scale(ctx, 20),
                                  ),
                                  border: Border.all(
                                    color: onCard.withAlpha(60),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      feedback == 'error'
                                          ? Icons.wifi_off
                                          : Icons.check,
                                      color: onCard,
                                      size: Responsive.scale(ctx, 13),
                                    ),
                                    SizedBox(width: Responsive.width(ctx, 5)),
                                    Text(
                                      lastFeedback == 'error'
                                          ? "No connection"
                                          : lastFeedback == 'deleted'
                                          ? "Removed"
                                          : "Logged!",
                                      style: GoogleFonts.manrope(
                                        color: onCard,
                                        fontSize: Responsive.font(ctx, 12),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showWeightLogSheet() async {
    final isImperial = currentUserData?.units == 'imperial';
    DateTime selectedDate = DateTime.now();
    final controller = _weightController..clear();
    String? feedback;
    String lastFeedback = 'ok';

    String dateKeyFor(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    String displayFor(double kg) =>
        isImperial ? (kg * 2.20462).toStringAsFixed(1) : kg.toStringAsFixed(1);

    String labelFor(DateTime d) {
      final today = DateTime.now();
      if (d.year == today.year &&
          d.month == today.month &&
          d.day == today.day) {
        return "Today";
      }
      final yesterday = today.subtract(const Duration(days: 1));
      if (d.year == yesterday.year &&
          d.month == yesterday.month &&
          d.day == yesterday.day) {
        return "Yesterday";
      }
      const months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      return '${months[d.month - 1]} ${d.day}';
    }

    // Get last 7 days that have weight logged, sorted newest first
    List<MapEntry<String, double>> recentEntries() {
      final entries = currentUserData?.weightByDate.entries.toList() ?? [];
      entries.sort((a, b) => b.key.compareTo(a.key));
      return entries.take(7).toList();
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final c = cardColors(appColorNotifier.value);
          final onCard = c.onCard;
          final onCardDim = c.onCard.withAlpha(140);
          final dateKey = dateKeyFor(selectedDate);
          final existingKg = currentUserData?.weightByDate[dateKey];

          // Pre-fill on first build
          if (controller.text.isEmpty && existingKg != null) {
            controller.text = displayFor(existingKg);
          }

          Future<void> save() async {
            final input = double.tryParse(controller.text.trim());
            if (input == null || input <= 0) return;
            final kg = isImperial ? input / 2.20462 : input;
            final ok = await userManager.updateWeightLog(dateKey, kg);
            bool sheetMounted = true;
            try {
              setSheet(() {
                feedback = ok
                    ? (existingKg != null ? 'updated' : 'ok')
                    : 'error';
                lastFeedback = feedback!;
              });
            } catch (_) {
              sheetMounted = false;
            }
            if (!sheetMounted) {
              if (mounted) setState(() {});
              return;
            }
            await Future.delayed(const Duration(milliseconds: 1600));
            try {
              setSheet(() => feedback = null);
            } catch (_) {}
            if (mounted) setState(() {});
          }

          Widget pill() => Positioned(
            top: 0,
            right: 0,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: feedback != null ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.width(ctx, 10),
                    vertical: Responsive.height(ctx, 5),
                  ),
                  decoration: BoxDecoration(
                    color: onCard.withAlpha(40),
                    borderRadius: BorderRadius.circular(
                      Responsive.scale(ctx, 20),
                    ),
                    border: Border.all(color: onCard.withAlpha(60)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        feedback == 'error' ? Icons.wifi_off : Icons.check,
                        color: onCard,
                        size: Responsive.scale(ctx, 13),
                      ),
                      SizedBox(width: Responsive.width(ctx, 5)),
                      Text(
                        lastFeedback == 'error'
                            ? "No connection"
                            : lastFeedback == 'updated'
                            ? "Updated!"
                            : lastFeedback == 'deleted'
                            ? "Deleted!"
                            : "Logged!",
                        style: GoogleFonts.manrope(
                          color: onCard,
                          fontSize: Responsive.font(ctx, 12),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );

          // keyboard pushes up the sheet so we grow the height to match, then pad the bottom by the same amount
          return SizedBox(
            height:
                MediaQuery.of(ctx).size.height * 0.55 +
                MediaQuery.of(ctx).viewInsets.bottom,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: darkenColor(
                        appColorNotifier.value,
                        0.1,
                      ).withAlpha(210),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      border: Border(
                        top: BorderSide(color: c.border, width: 1),
                      ),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      Responsive.width(ctx, 24),
                      Responsive.height(ctx, 20),
                      Responsive.width(ctx, 24),
                      Responsive.height(ctx, 32),
                    ),
                    child: Stack(
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "LOG WEIGHT",
                              style: GoogleFonts.manrope(
                                fontSize: Responsive.font(ctx, 11),
                                color: onCardDim,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                              ),
                            ),
                            SizedBox(height: Responsive.height(ctx, 12)),
                            // Date navigation row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    final d = selectedDate.subtract(
                                      const Duration(days: 1),
                                    );
                                    final kg = currentUserData
                                        ?.weightByDate[dateKeyFor(d)];
                                    setSheet(() {
                                      selectedDate = d;
                                      controller.text = kg != null
                                          ? displayFor(kg)
                                          : '';
                                    });
                                  },
                                  child: Icon(
                                    Icons.chevron_left,
                                    color: onCard,
                                    size: Responsive.scale(ctx, 22),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: ctx,
                                      initialDate: selectedDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now(),
                                    );
                                    if (picked != null) {
                                      final kg = currentUserData
                                          ?.weightByDate[dateKeyFor(picked)];
                                      setSheet(() {
                                        selectedDate = picked;
                                        controller.text = kg != null
                                            ? displayFor(kg)
                                            : '';
                                      });
                                    }
                                  },
                                  child: Text(
                                    labelFor(selectedDate),
                                    style: GoogleFonts.manrope(
                                      color: onCard,
                                      fontSize: Responsive.font(ctx, 14),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap:
                                      selectedDate.day == DateTime.now().day &&
                                          selectedDate.month ==
                                              DateTime.now().month &&
                                          selectedDate.year ==
                                              DateTime.now().year
                                      ? null
                                      : () {
                                          final d = selectedDate.add(
                                            const Duration(days: 1),
                                          );
                                          final kg = currentUserData
                                              ?.weightByDate[dateKeyFor(d)];
                                          setSheet(() {
                                            selectedDate = d;
                                            controller.text = kg != null
                                                ? displayFor(kg)
                                                : '';
                                          });
                                        },
                                  child: Icon(
                                    Icons.chevron_right,
                                    color:
                                        selectedDate.day == DateTime.now().day
                                        ? onCard.withAlpha(60)
                                        : onCard,
                                    size: Responsive.scale(ctx, 22),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: Responsive.height(ctx, 16)),
                            // Input row
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: controller,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'^\d{0,3}(\.\d{0,1})?'),
                                      ),
                                    ],
                                    autofocus: false,
                                    style: GoogleFonts.manrope(
                                      color: onCard,
                                      fontSize: Responsive.font(ctx, 22),
                                      fontWeight: FontWeight.w700,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: () {
                                        // Use latest logged weight as hint base, offset randomly by -2 to +2
                                        final latest =
                                            recentEntries().isNotEmpty
                                            ? recentEntries().first.value
                                            : null;
                                        if (latest != null) {
                                          final offset =
                                              (Random().nextDouble() * 4 - 2);
                                          final hintKg = latest + offset;
                                          return isImperial
                                              ? "e.g. ${(hintKg * 2.20462).toStringAsFixed(1)}"
                                              : "e.g. ${hintKg.toStringAsFixed(1)}";
                                        }
                                        return isImperial
                                            ? "e.g. 154.0"
                                            : "e.g. 70.0";
                                      }(),
                                      hintStyle: GoogleFonts.manrope(
                                        color: onCardDim,
                                      ),
                                      suffix: Text(
                                        isImperial ? " lbs" : " kg",
                                        style: GoogleFonts.manrope(
                                          color: onCardDim,
                                          fontSize: Responsive.font(ctx, 16),
                                        ),
                                      ),
                                      enabledBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: onCard.withAlpha(60),
                                        ),
                                      ),
                                      focusedBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(color: onCard),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: Responsive.width(ctx, 16)),
                                GestureDetector(
                                  onTap: save,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: Responsive.width(ctx, 20),
                                      vertical: Responsive.height(ctx, 12),
                                    ),
                                    decoration: BoxDecoration(
                                      color: onCard.withAlpha(20),
                                      borderRadius: BorderRadius.circular(
                                        Responsive.scale(ctx, 12),
                                      ),
                                      border: Border.all(
                                        color: onCard.withAlpha(60),
                                      ),
                                    ),
                                    child: Text(
                                      existingKg != null ? "Update" : "Log",
                                      style: GoogleFonts.manrope(
                                        color: onCard,
                                        fontSize: Responsive.font(ctx, 14),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // Recent 7-day history
                            if (recentEntries().isNotEmpty) ...[
                              SizedBox(height: Responsive.height(ctx, 20)),
                              Text(
                                "RECENT",
                                style: GoogleFonts.manrope(
                                  fontSize: Responsive.font(ctx, 11),
                                  color: onCardDim,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              SizedBox(height: Responsive.height(ctx, 8)),
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight:
                                      MediaQuery.of(ctx).size.height * 0.25,
                                ),
                                child: SingleChildScrollView(
                                  child: Column(
                                    children: [
                                      for (
                                        int i = 0;
                                        i < recentEntries().length;
                                        i++
                                      ) ...[
                                        if (i > 0)
                                          Divider(
                                            color: onCard.withAlpha(20),
                                            height: 1,
                                          ),
                                        GestureDetector(
                                          // Tap a history row to jump to that date and prefill the input
                                          onTap: () {
                                            final d = DateTime.parse(
                                              recentEntries()[i].key,
                                            );
                                            final kg = recentEntries()[i].value;
                                            setSheet(() {
                                              selectedDate = d;
                                              controller.text = displayFor(kg);
                                            });
                                          },
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: Responsive.height(
                                                ctx,
                                                10,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                HugeIcon(
                                                  icon: HugeIcons
                                                      .strokeRoundedWeightScale,
                                                  color: onCardDim,
                                                  size: Responsive.scale(
                                                    ctx,
                                                    15,
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: Responsive.width(
                                                    ctx,
                                                    10,
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    labelFor(
                                                      DateTime.parse(
                                                        recentEntries()[i].key,
                                                      ),
                                                    ),
                                                    style: GoogleFonts.manrope(
                                                      color: onCardDim,
                                                      fontSize: Responsive.font(
                                                        ctx,
                                                        13,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  "${displayFor(recentEntries()[i].value)} ${isImperial ? 'lbs' : 'kg'}",
                                                  style: GoogleFonts.manrope(
                                                    color: onCard,
                                                    fontSize: Responsive.font(
                                                      ctx,
                                                      14,
                                                    ),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: Responsive.width(
                                                    ctx,
                                                    6,
                                                  ),
                                                ),
                                                // Trend arrow comparing to the previous (older) entry
                                                Builder(
                                                  builder: (_) {
                                                    final entries =
                                                        recentEntries();
                                                    if (i + 1 >=
                                                        entries.length) {
                                                      return SizedBox(
                                                        width: Responsive.scale(
                                                          ctx,
                                                          16,
                                                        ),
                                                      );
                                                    }
                                                    final diff =
                                                        entries[i].value -
                                                        entries[i + 1].value;
                                                    if (diff.abs() < 0.01) {
                                                      return HugeIcon(
                                                        icon: HugeIcons
                                                            .strokeRoundedRemove01,
                                                        color: onCardDim,
                                                        size: Responsive.scale(
                                                          ctx,
                                                          14,
                                                        ),
                                                      );
                                                    }
                                                    return HugeIcon(
                                                      icon: diff > 0
                                                          ? HugeIcons
                                                                .strokeRoundedChartUp
                                                          : HugeIcons
                                                                .strokeRoundedChartDown,
                                                      color: onCardDim,
                                                      size: Responsive.scale(
                                                        ctx,
                                                        14,
                                                      ),
                                                    );
                                                  },
                                                ),
                                                SizedBox(
                                                  width: Responsive.width(
                                                    ctx,
                                                    8,
                                                  ),
                                                ),
                                                GestureDetector(
                                                  onTap: () async {
                                                    final entryKey =
                                                        recentEntries()[i].key;
                                                    final entryDisplay =
                                                        displayFor(
                                                          recentEntries()[i]
                                                              .value,
                                                        );
                                                    final confirmed =
                                                        await showFrostedAlertDialog<
                                                          bool
                                                        >(
                                                          context: ctx,
                                                          title: "Delete Entry",
                                                          content: Text(
                                                            "Delete $entryDisplay ${isImperial ? 'lbs' : 'kg'} from ${labelFor(DateTime.parse(entryKey))}?",
                                                            style:
                                                                GoogleFonts.manrope(
                                                                  color: Colors
                                                                      .white54,
                                                                  fontSize: 13,
                                                                ),
                                                            textAlign: TextAlign
                                                                .center,
                                                          ),
                                                          actions: [
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.of(
                                                                    ctx,
                                                                    rootNavigator:
                                                                        true,
                                                                  ).pop(false),
                                                              child: const Text(
                                                                "Cancel",
                                                                style: TextStyle(
                                                                  color: Colors
                                                                      .white54,
                                                                ),
                                                              ),
                                                            ),
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.of(
                                                                    ctx,
                                                                    rootNavigator:
                                                                        true,
                                                                  ).pop(true),
                                                              child: const Text(
                                                                "Delete",
                                                              ),
                                                            ),
                                                          ],
                                                        );
                                                    if (confirmed == true) {
                                                      final ok =
                                                          await userManager
                                                              .deleteWeightLog(
                                                                entryKey,
                                                              );
                                                      bool sheetMounted = true;
                                                      try {
                                                        setSheet(() {
                                                          feedback = ok
                                                              ? 'deleted'
                                                              : 'error';
                                                          lastFeedback =
                                                              feedback!;
                                                        });
                                                      } catch (_) {
                                                        sheetMounted = false;
                                                      }
                                                      if (!sheetMounted) {
                                                        if (mounted) {
                                                          setState(() {});
                                                        }
                                                        return;
                                                      }
                                                      await Future.delayed(
                                                        const Duration(
                                                          milliseconds: 1600,
                                                        ),
                                                      );
                                                      try {
                                                        setSheet(
                                                          () => feedback = null,
                                                        );
                                                      } catch (_) {}
                                                      if (mounted) {
                                                        setState(() {});
                                                      }
                                                    }
                                                  },
                                                  child: HugeIcon(
                                                    icon: HugeIcons
                                                        .strokeRoundedDelete02,
                                                    color: onCardDim,
                                                    size: Responsive.scale(
                                                      ctx,
                                                      16,
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
                            ],
                          ],
                        ),
                        pill(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
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
    debugPrint('[Home] _onAppReady fired, mounted=$mounted');
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

  void _startTapHintTimer() {
    _tapHintTimer?.cancel();
    if (mounted) setState(() => _tapHintVisible = false);
    _tapHintTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _tapHintVisible = true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tapHintTimer?.cancel();
    _countdownTimer?.cancel();
    appColorNotifier.removeListener(_appColorListener);
    foodLogNotifier.removeListener(_onFoodChanged);
    appReadyNotifier.removeListener(_onAppReady);
    dailyRewardConfettiController.dispose();
    _scrollController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  bool get isNewUser =>
      appReadyNotifier
          .value && // guard against stub username matching uid before loadUserData finishes
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
    _tapHintTimer?.cancel();
    setState(() => _tapHintVisible = false);
    if (_tourStep == 0) {
      setState(() => _tourStep = 1);
      _startTapHintTimer();
    } else if (_tourStep == 1) {
      setState(() => _tourStep = 2);
      _startTapHintTimer();
    } else if (_tourStep == 2) {
      setState(() => _tourStep = -1);
      await showUsernameSetupDialog(context);
      if (mounted) {
        setState(
          () => _greeting = _buildGreeting(),
        ); // refresh greeting and drawer with the new username
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
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          await showWelcomeTourDialog(context);
          if (!mounted) return;
          setState(() => _tourStep = 0);
          _startTapHintTimer();
        });
      }

      if (canClaimDailyReward() && !isNewUser && !isGuest) {
        await buildDailyRewardDialog();
      }

      if (!isGuest && !isNewUser && mounted) {
        await checkPendingReferralReward(context, setState);
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
    final accentColor = lightenColor(appColorNotifier.value, 0.45);
    final foodStreakBest = isGuest
        ? 0
        : (currentUserData?.foodLogStreakBest ?? 0);
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
                              if (!isGuest) ...[
                                SizedBox(height: Responsive.height(context, 4)),
                                Text(
                                  "Keep it up!",
                                  style: GoogleFonts.manrope(
                                    color: dim,
                                    fontSize: Responsive.font(context, 11),
                                  ),
                                ),
                              ],
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

    return DecoratedBox(
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
  }

  // Counts total food items logged today across all meals
  // Returns today's total protein/carbs/fat in grams
  ({int protein, int carbs, int fat}) _todayMacros() {
    final key = _todayDateKey();
    final meals = currentUserData?.foodDataByDate[key];
    if (meals == null) return (protein: 0, carbs: 0, fat: 0);
    int protein = 0, carbs = 0, fat = 0;
    for (final foods in meals.values) {
      for (final food in foods) {
        // macros are never stored as top-level keys, they live inside food_description
        final parsed = FoodLoggingHelper.extractMacros(
          food['food_description']?.toString() ?? '',
        );
        protein += (parsed['protein'] ?? 0.0).toInt();
        carbs += (parsed['carbs'] ?? 0.0).toInt();
        fat += (parsed['fat'] ?? 0.0).toInt();
      }
    }
    return (protein: protein, carbs: carbs, fat: fat);
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
                "Coming soon",
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
      onTap: () => showFrostedAlertDialog(
        context: context,
        title: "Coming Soon",
        content: Text(
          "Rewarded ads are coming soon.",
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
                  onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
                  child: const Text("Got it"),
                ),
              ),
            ),
          ),
        ],
      ),
      child: Opacity(opacity: 0.4, child: card),
    );
  }

  Widget _buildLoggingCard({
    required IconData icon,
    required String label,
    required String value,
    required String subtext,
    bool showButtons = false,
    VoidCallback? onAdd,
    IconData onAddIcon = Icons.add, // icon for the primary action button
    VoidCallback? onChart,
    Widget? progressBar,
  }) {
    final accentColor = lightenColor(appColorNotifier.value, 0.45);

    Widget actionButton(IconData btnIcon, VoidCallback? onTap) =>
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: Responsive.scale(context, 34),
            height: Responsive.scale(context, 34),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withAlpha(18),
              border: Border.all(color: Colors.white.withAlpha(40), width: 1),
            ),
            child: Icon(
              btnIcon,
              color: accentColor,
              size: Responsive.scale(context, 16),
            ),
          ),
        );

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    HugeIcon(
                      icon: icon,
                      color: accentColor,
                      size: Responsive.scale(context, 14),
                    ),
                    SizedBox(width: Responsive.width(context, 5)),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          label,
                          style: GoogleFonts.manrope(
                            color: accentColor,
                            fontSize: Responsive.font(context, 11),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: Responsive.height(context, 6)),
                Text(
                  value,
                  style: GoogleFonts.manrope(
                    color: accentColor,
                    fontSize: Responsive.font(context, 22),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtext,
                  style: GoogleFonts.manrope(
                    color: accentColor,
                    fontSize: Responsive.font(context, 11),
                  ),
                ),
                if (progressBar != null) ...[
                  SizedBox(height: Responsive.height(context, 8)),
                  progressBar,
                ],
              ],
            ),
          ),
          if (showButtons) ...[
            SizedBox(width: Responsive.width(context, 8)),
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                actionButton(onAddIcon, onAdd),
                if (onChart != null) ...[
                  SizedBox(height: Responsive.height(context, 6)),
                  actionButton(HugeIcons.strokeRoundedAnalyticsUp, onChart),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMacrosCard() {
    final accentColor = lightenColor(appColorNotifier.value, 0.45);
    final dimColor = lightenColor(appColorNotifier.value, 0.35);
    final macros = isGuest ? (protein: 0, carbs: 0, fat: 0) : _todayMacros();

    Widget macroRow(String label, int value, int? goal) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: "$label: ",
                style: GoogleFonts.manrope(
                  color: dimColor,
                  fontSize: Responsive.font(context, 13),
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextSpan(
                text: "${value}g",
                style: GoogleFonts.manrope(
                  color: accentColor,
                  fontSize: Responsive.font(context, 13),
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (goal != null)
                TextSpan(
                  text: " /${goal}g",
                  style: GoogleFonts.manrope(
                    color: dimColor,
                    fontSize: Responsive.font(context, 11),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return frostedGlassCard(
      context,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.width(context, 16),
        vertical: Responsive.height(context, 14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedAppleStocks,
                color: accentColor,
                size: Responsive.scale(context, 14),
              ),
              SizedBox(width: Responsive.width(context, 5)),
              Text(
                "Macros today",
                style: GoogleFonts.manrope(
                  color: accentColor,
                  fontSize: Responsive.font(context, 11),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.height(context, 10)),
          macroRow("protein", macros.protein, currentUserData?.proteinGoal),
          SizedBox(height: Responsive.height(context, 4)),
          macroRow("carbs", macros.carbs, currentUserData?.carbsGoal),
          SizedBox(height: Responsive.height(context, 4)),
          macroRow("fat", macros.fat, currentUserData?.fatGoal),
        ],
      ),
    );
  }

  Widget _buildGuestLoggingCard() {
    final accent = lightenColor(appColorNotifier.value, 0.45);
    return GestureDetector(
      onTap: () async => authService.value.signOut(),
      child: Stack(
        children: [
          IgnorePointer(
            child: Opacity(opacity: 0.35, child: _buildLoggingCards()),
          ),
          Positioned.fill(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedLockPassword,
                    color: accent,
                    size: Responsive.scale(context, 28),
                  ),
                  SizedBox(height: Responsive.height(context, 6)),
                  Text(
                    "Sign up to unlock",
                    style: GoogleFonts.manrope(
                      color: accent,
                      fontSize: Responsive.font(context, 14),
                      fontWeight: FontWeight.w700,
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

  Widget _buildLoggingCards() {
    final isImperial = currentUserData?.units == 'imperial';
    final calories = _todayCalories();
    final goal = currentUserData?.caloriesGoal ?? 0;
    final progress = goal > 0 ? (calories / goal).clamp(0.0, 1.0) : 0.0;

    // water progress
    final totalWaterMl =
        (currentUserData?.waterEntriesByDate[_todayDateKey()] ?? []).fold(
          0,
          (s, e) => s + e,
        );
    final waterGoalMl = currentUserData?.waterMlGoal ?? 0;
    final waterProgress = waterGoalMl > 0
        ? (totalWaterMl / waterGoalMl).clamp(0.0, 1.0)
        : 0.0;

    Widget buildProgressBar(double fraction, {bool overIsRed = true}) =>
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Responsive.scale(context, 7)),
            border: Border.all(
              color: Colors.white.withAlpha(45),
              width: Responsive.scale(context, 1),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Responsive.scale(context, 6)),
            child: Stack(
              children: [
                Container(
                  height: Responsive.height(context, 8),
                  width: double.infinity,
                  color: Colors.white.withAlpha(18),
                ),
                FractionallySizedBox(
                  widthFactor: fraction,
                  child: Container(
                    height: Responsive.height(context, 8),
                    decoration: BoxDecoration(
                      color: overIsRed && fraction >= 1.0
                          ? lightenColor(appColorNotifier.value, 0.45)
                          : lightenColor(appColorNotifier.value, 0.3),
                      borderRadius: BorderRadius.circular(
                        Responsive.scale(context, 6),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

    final progressBar = goal > 0
        ? buildProgressBar(progress, overIsRed: true)
        : null;
    final waterProgressBar = waterGoalMl > 0
        ? buildProgressBar(waterProgress, overIsRed: false)
        : null;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _buildLoggingCard(
                    icon: HugeIcons.strokeRoundedFire,
                    label: "Calories today",
                    value: isGuest ? "--" : "$calories",
                    subtext: goal > 0 ? "/ $goal goal" : "kcal",
                    progressBar: progressBar,
                    showButtons: !isGuest,
                    onAdd: () => context.go(
                      '/food-logging',
                    ), // go() switches the tab, push() doesn't
                    onAddIcon: HugeIcons.strokeRoundedArrowRight01,
                    onChart: () => context.push(
                      '/food-logging/analytics',
                      extra: {
                        'initialDate': DateTime.now(),
                        'onDateChanged': null,
                      },
                    ),
                  ),
                ),
                SizedBox(height: Responsive.height(context, 12)),
                Expanded(
                  child: _buildLoggingCard(
                    icon: HugeIcons.strokeRoundedDroplet,
                    label: "Water",
                    value: isGuest
                        ? "--"
                        : isImperial
                        ? (totalWaterMl / 29.5735).toStringAsFixed(1)
                        : "$totalWaterMl",
                    subtext: () {
                      if (waterGoalMl <= 0) {
                        return isImperial ? "oz today" : "ml today";
                      }
                      final goalDisplay = isImperial
                          ? "${(waterGoalMl / 29.5735).toStringAsFixed(0)} oz"
                          : "$waterGoalMl ml";
                      return "/ $goalDisplay goal";
                    }(),
                    progressBar: waterProgressBar,
                    showButtons: !isGuest,
                    onAdd: _showWaterLogSheet,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: Responsive.width(context, 12)),
          Expanded(
            child: Column(
              children: [
                Expanded(child: _buildMacrosCard()),
                SizedBox(height: Responsive.height(context, 12)),
                Expanded(
                  child: _buildLoggingCard(
                    icon: HugeIcons.strokeRoundedWeightScale,
                    label: "Weight",
                    value: () {
                      // use today's entry, or fall back to the most recent logged weight
                      final byDate = currentUserData?.weightByDate ?? {};
                      final kg =
                          byDate[_todayDateKey()] ??
                          (byDate.entries.toList()
                                ..sort((a, b) => b.key.compareTo(a.key)))
                              .firstOrNull
                              ?.value;
                      if (kg == null) return "--";
                      return isImperial
                          ? (kg * 2.20462).toStringAsFixed(1)
                          : kg.toStringAsFixed(1);
                    }(),
                    subtext: () {
                      final byDate = currentUserData?.weightByDate ?? {};
                      // same fallback logic as the value above
                      final currentKg =
                          byDate[_todayDateKey()] ??
                          (byDate.entries.toList()
                                ..sort((a, b) => b.key.compareTo(a.key)))
                              .firstOrNull
                              ?.value;
                      final goalKg = currentUserData?.weightKgGoal;
                      final type = currentUserData?.weightGoalType;
                      // no goal at all
                      if (goalKg == null && type == null) {
                        return "No weight goal set";
                      }
                      // goal type set but missing either a logged weight or a target weight
                      if (currentKg == null || goalKg == null) {
                        final label = isImperial ? "lbs" : "kg";
                        return type != null
                            ? "${type[0].toUpperCase()}${type.substring(1)} · $label"
                            : label;
                      }
                      // how far the current weight is from the target, always positive
                      final delta = (currentKg - goalKg).abs();
                      final deltaDisplay = isImperial
                          ? "${(delta * 2.20462).toStringAsFixed(1)} lbs"
                          : "${delta.toStringAsFixed(1)} kg";
                      // direction-aware check: losing means at/under target, gaining means at/over, maintain is exact
                      final bool atOrPastGoal = type == 'lose'
                          ? currentKg <= goalKg
                          : type == 'gain'
                          ? currentKg >= goalKg
                          : currentKg == goalKg;
                      if (atOrPastGoal) return "You're at your goal weight!";
                      return "You're $deltaDisplay away from your goal";
                    }(),
                    showButtons: !isGuest,
                    onAdd: _showWeightLogSheet,
                  ),
                ),
              ],
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
                                      ? 'This is your dashboard: your XP progress, daily reward, and quick stats all live here. Use the tool buttons below to access Reminders and the Calorie Calculator.'
                                      : _tourStep == 1
                                      ? 'The floating bar at the bottom lets you switch between your main app tabs.'
                                      : 'The gear icon to the right opens a settings drawer where you can update your preferences, send feedback, and more.',
                                ).animate(key: ValueKey(_tourStep)).fadeIn(duration: 200.ms),
                              ),
                            ),
                    ),
                    if (_tapHintVisible)
                      Positioned.fill(
                        child: Center(
                          child:
                              HugeIcon(
                                    icon: HugeIcons.strokeRoundedTouch01,
                                    color: Colors.white70,
                                    size: Responsive.scale(context, 56),
                                  )
                                  .animate(onPlay: (c) => c.repeat())
                                  .fadeIn(duration: 300.ms)
                                  .then()
                                  .scaleXY(
                                    end: 0.85,
                                    duration: 600.ms,
                                    curve: Curves.easeInOut,
                                  )
                                  .then()
                                  .scaleXY(
                                    end: 1.0,
                                    duration: 600.ms,
                                    curve: Curves.easeInOut,
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
                              120.ms,
                            ),
                            SizedBox(height: Responsive.height(context, 12)),
                            // Daily reward sits below the earn XP tiles as a slim full-width row
                            _maybeAnimate(_buildDailyRewardCard(), 150.ms),
                            SizedBox(height: Responsive.height(context, 20)),
                          ],

                          if (isGuest) ...[
                            sectionHeader("DAILY REWARD", context),
                            _maybeAnimate(_buildDailyRewardCard(), 120.ms),
                            SizedBox(height: Responsive.height(context, 20)),
                          ],

                          sectionHeader("LOGGING", context),
                          _maybeAnimate(
                            isGuest
                                ? _buildGuestLoggingCard()
                                : ListenableBuilder(
                                    listenable: userDataNotifier,
                                    builder: (context, _) =>
                                        _buildLoggingCards(),
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
