import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/providers/user_data_provider.dart';
import '/providers/user_data_loaded_provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:google_fonts/google_fonts.dart';
import '/globals.dart';
import '/guest.dart';
import '/utility/responsive.dart';
import '/services/user_data_manager.dart';
import 'package:skeletonizer/skeletonizer.dart';

class Progression extends ConsumerStatefulWidget {
  const Progression({super.key});

  @override
  ConsumerState<Progression> createState() => _ProgressionState();
}

class _ProgressionState extends ConsumerState<Progression> {
  Color get appColor => ref.watch(
    userDataProvider.select((s) => s.value?.appColor ?? defaultAppColor),
  );

  int? _rank;
  int? _total;
  bool _standingLoading = true;
  String _standingType = 'xp';

  static const _standingTypes = [
    ('xp', 'XP'),
    ('foods', 'Foods'),
    ('workouts', 'Workouts'),
  ];

  @override
  void initState() {
    super.initState();
    FirebaseAnalytics.instance.logScreenView(
      screenName: '/progression',
      screenClass: 'Progression',
    );
    if (!isGuest) _fetchStanding();
  }

  Future<void> _fetchStanding() async {
    setState(() => _standingLoading = true);
    try {
      final data = await UserDataManager.fetchLeaderboardStanding(
        type: _standingType,
      );
      if (mounted) {
        setState(() {
          _rank = data['rank'] as int?;
          _total = data['total'] as int?;
          _standingLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _standingLoading = false);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget _buildStandingCard(BuildContext context) {
    final accent = onTheme(appColor);
    final dim = onTheme(appColor);

    final rankLabel = isGuest
        ? "#--"
        : _standingLoading
        ? "..."
        : _rank == null
        ? "?"
        : "#$_rank";
    final topPercent =
        (!isGuest && _rank != null && _total != null && _total! > 0)
        ? (_rank == 1 ? 1 : ((_rank! / _total!) * 100).ceil().clamp(1, 100))
        : null;
    final topLabel = isGuest
        ? "--%"
        : _standingLoading
        ? "..."
        : topPercent != null
        ? "$topPercent%"
        : "?";

    final combined = Skeletonizer(
      enabled:
          !isGuest && (_standingLoading || !ref.watch(userDataLoadedProvider)),
      effect: ShimmerEffect(
        baseColor: cardColors(appColor).iconBox,
        highlightColor: cardColors(appColor).border,
        duration: const Duration(milliseconds: 1200),
      ),
      child: frostedGlassCard(
        context,
        color: appColor,
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.width(context, 16),
          vertical: Responsive.height(context, 14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type toggle, IntrinsicWidth makes all chips match the widest one
            Center(
              child: IntrinsicWidth(
                child: Row(
                  children: [
                    for (final (type, label) in _standingTypes) ...[
                      if (type != _standingTypes.first.$1)
                        SizedBox(width: Responsive.width(context, 8)),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (_standingType != type) {
                              logAnalyticsEvent(
                                'leaderboard_type_changed',
                                parameters: {'type': type},
                              );
                              setState(() => _standingType = type);
                              _fetchStanding();
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: EdgeInsets.symmetric(
                              horizontal: Responsive.width(context, 12),
                              vertical: Responsive.height(context, 7),
                            ),
                            decoration: BoxDecoration(
                              color: _standingType == type
                                  ? appColor.withAlpha(60)
                                  : Colors.white.withAlpha(10),
                              borderRadius: BorderRadius.circular(
                                Responsive.scale(context, 20),
                              ),
                              border: Border.all(
                                color: _standingType == type
                                    ? accent.withAlpha(180)
                                    : dim.withAlpha(60),
                                width: 1.2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                label,
                                style: GoogleFonts.manrope(
                                  fontSize: Responsive.font(context, 12),
                                  fontWeight: _standingType == type
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: _standingType == type ? accent : dim,
                                ),
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
            SizedBox(height: Responsive.height(context, 14)),
            // Stat row
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "YOUR RANK",
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 10),
                            color: dim,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                        SizedBox(height: Responsive.height(context, 4)),
                        Text(
                          rankLabel,
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 28),
                            color: accent,
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                          ),
                        ),
                        Text(
                          isGuest
                              ? "out of --"
                              : _total != null
                              ? "out of $_total"
                              : "loading",
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 11),
                            color: dim,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    margin: EdgeInsets.symmetric(
                      horizontal: Responsive.width(context, 16),
                    ),
                    color: dim.withAlpha(40),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "TOP",
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 10),
                            color: dim,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                        SizedBox(height: Responsive.height(context, 4)),
                        Text(
                          topLabel,
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 28),
                            color: accent,
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                          ),
                        ),
                        Text(
                          "of all players",
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 11),
                            color: dim,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return combined;
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final base = appColor;
    final c = cardColors(base);
    final accent = c.onCard;
    final dim = c.onCard;
    final radius = BorderRadius.circular(Responsive.scale(context, 20));

    return Padding(
      padding: EdgeInsets.only(bottom: Responsive.height(context, 4)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: c.gradient,
          ),
          border: Border.all(color: c.border, width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              splashColor: c.splashColor,
              highlightColor: c.highlightColor,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.width(context, 20),
                  vertical: Responsive.height(context, 20),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(Responsive.scale(context, 11)),
                      decoration: BoxDecoration(
                        color: c.iconBox,
                        borderRadius: BorderRadius.circular(
                          Responsive.scale(context, 13),
                        ),
                        border: Border.all(color: c.iconBorder, width: 1.5),
                      ),
                      child: HugeIcon(
                        icon: icon,
                        color: accent,
                        size: Responsive.scale(context, 22),
                      ),
                    ),
                    SizedBox(width: Responsive.width(context, 16)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.manrope(
                              fontSize: Responsive.font(context, 16),
                              color: accent,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: Responsive.height(context, 3)),
                          Text(
                            subtitle,
                            style: GoogleFonts.manrope(
                              fontSize: Responsive.font(context, 12),
                              color: dim,
                            ),
                          ),
                        ],
                      ),
                    ),
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowRight01,
                      color: onTheme(base),
                      size: Responsive.scale(context, 20),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: buildThemeGradient(appColor)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AppRefreshIndicator(
          onRefresh: () async {
            await _fetchStanding();
            await ref.read(userDataProvider.notifier).refreshUserData();
          },
          appColor: appColor,
          child: ScrollConfiguration(
            behavior: NoGlowScrollBehavior(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.centeredHorizontalPadding(context, 20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height:
                          MediaQuery.paddingOf(context).top +
                          Responsive.height(context, 24),
                    ),
                    sectionHeader("LEADERBOARDS", context, appColor: appColor),
                    isGuest
                        ? GestureDetector(
                            onTap: () => Guest.block(
                              context,
                              title: 'Sign up to compete',
                              description:
                                  'Create a free account to appear on the leaderboard and see how you rank.',
                            ),
                            child: Stack(
                              children: [
                                IgnorePointer(
                                  child: Opacity(
                                    opacity: 0.35,
                                    child: Column(
                                      children: [
                                        _buildCard(
                                          icon: HugeIcons.strokeRoundedMedal01,
                                          title: "Leaderboards",
                                          subtitle:
                                              "Compete across XP, foods logged, and workouts",
                                          onTap: () {},
                                        ),
                                        SizedBox(
                                          height: Responsive.height(
                                            context,
                                            12,
                                          ),
                                        ),
                                        _buildStandingCard(context),
                                      ],
                                    ),
                                  ),
                                ),
                                guestLockOverlay(context, appColor),
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              _buildCard(
                                icon: HugeIcons.strokeRoundedMedal01,
                                title: "Leaderboards",
                                subtitle:
                                    "Compete across XP, foods logged, and workouts",
                                onTap: () => context.push('/leaderboard'),
                              ),
                              SizedBox(height: Responsive.height(context, 12)),
                              _buildStandingCard(context),
                            ],
                          ),
                    SizedBox(height: Responsive.height(context, 20)),
                    sectionHeader("BADGES", context, appColor: appColor),
                    isGuest
                        ? GestureDetector(
                            onTap: () => Guest.block(
                              context,
                              title: 'Sign up to earn badges',
                              description:
                                  'Create a free account to unlock achievements and claim tier rewards.',
                            ),
                            child: Stack(
                              children: [
                                IgnorePointer(
                                  child: Opacity(
                                    opacity: 0.35,
                                    child: _buildCard(
                                      icon: HugeIcons.strokeRoundedCrown,
                                      title: "Badges",
                                      subtitle:
                                          "Track achievements and claim tier rewards",
                                      onTap: () {},
                                    ),
                                  ),
                                ),
                                guestLockOverlay(context, appColor),
                              ],
                            ),
                          )
                        : _buildCard(
                            icon: HugeIcons.strokeRoundedCrown,
                            title: "Badges",
                            subtitle:
                                "Track achievements and claim tier rewards",
                            onTap: () => context.push('/badges'),
                          ),
                    SizedBox(height: Responsive.height(context, 120)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
