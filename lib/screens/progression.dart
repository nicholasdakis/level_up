import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/providers/user_data_provider.dart';
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
    try {
      final data = await UserDataManager.fetchLeaderboardStanding();
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
    final accent = lightenColor(appColor, 0.45);
    final dim = lightenColor(appColor, 0.35);

    final rankLabel = isGuest
        ? "#--"
        : _standingLoading
        ? "..."
        : _rank == null
        ? "?"
        : "#$_rank";
    final topPercent =
        (!isGuest && _rank != null && _total != null && _total! > 0)
        ? ((_rank! / _total!) * 100).ceil()
        : null;
    final topLabel = isGuest
        ? "--%"
        : _standingLoading
        ? "..."
        : topPercent != null
        ? "$topPercent%"
        : "?";

    Widget statCard({
      required String label,
      required String value,
      required String sub,
    }) {
      return Expanded(
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
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: Responsive.font(context, 10),
                  color: dim,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(height: Responsive.height(context, 4)),
              Text(
                value,
                style: GoogleFonts.manrope(
                  fontSize: Responsive.font(context, 28),
                  color: accent,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
              Text(
                sub,
                style: GoogleFonts.manrope(
                  fontSize: Responsive.font(context, 11),
                  color: dim,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final cards = Skeletonizer(
      enabled:
          !isGuest && (_standingLoading || !ref.watch(userDataLoadedProvider)),
      effect: ShimmerEffect(
        baseColor: lightenColor(appColor, 0.3),
        highlightColor: lightenColor(appColor, 0.1),
        duration: const Duration(milliseconds: 1200),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            statCard(
              label: "YOUR RANK",
              value: rankLabel,
              sub: isGuest
                  ? "out of --"
                  : _total != null
                  ? "out of $_total"
                  : "loading",
            ),
            SizedBox(width: Responsive.width(context, 12)),
            statCard(
              label: "YOU'RE IN THE TOP",
              value: topLabel,
              sub: "of all players",
            ),
          ],
        ),
      ),
    );

    if (!isGuest) return cards;

    return GestureDetector(
      onTap: () => Guest.exit(),
      child: Stack(
        children: [
          IgnorePointer(child: Opacity(opacity: 0.35, child: cards)),
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

  Widget _buildCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final base = appColor;
    final c = cardColors(base);
    final accent = c.onCard;
    final dim = c.onCard.withAlpha(180);
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
          border: Border.all(color: c.border, width: 1),
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
                        border: Border.all(
                          color: lightenColor(base, 0.35).withAlpha(80),
                          width: 1,
                        ),
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
                      color: lightenColor(base, 0.35).withAlpha(200),
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
        body: ScrollConfiguration(
          behavior: NoGlowScrollBehavior(),
          child: SingleChildScrollView(
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
                  sectionHeader("BADGES", context, appColor: appColor),
                  _buildCard(
                    icon: HugeIcons.strokeRoundedCrown,
                    title: "Badges",
                    subtitle: "Track achievements and claim tier rewards",
                    onTap: isGuest
                        ? () => Guest.block(context)
                        : () => context.push('/badges'),
                  ),
                  SizedBox(height: Responsive.height(context, 20)),
                  sectionHeader("LEADERBOARD", context, appColor: appColor),
                  _buildCard(
                    icon: HugeIcons.strokeRoundedMedal01,
                    title: "Leaderboard",
                    subtitle: "See how you rank against other players",
                    onTap: isGuest
                        ? () => Guest.block(context)
                        : () => context.push('/leaderboard'),
                  ),
                  SizedBox(height: Responsive.height(context, 12)),
                  // Standing stat cards showing rank and total players
                  _buildStandingCard(context),
                  SizedBox(height: Responsive.height(context, 120)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
