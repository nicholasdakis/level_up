import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:google_fonts/google_fonts.dart';
import '/globals.dart';
import '/utility/responsive.dart';
import '/services/user_data_manager.dart';
import 'package:skeletonizer/skeletonizer.dart';

class Progression extends StatefulWidget {
  const Progression({super.key});

  @override
  State<Progression> createState() => _ProgressionState();
}

class _ProgressionState extends State<Progression> {
  late final VoidCallback _colorListener;
  int? _rank;
  int? _total;
  bool _standingLoading = true;

  @override
  void initState() {
    super.initState();
    _colorListener = () {
      if (mounted) setState(() {});
    };
    appColorNotifier.addListener(_colorListener);
    _fetchStanding();
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
    appColorNotifier.removeListener(_colorListener);
    super.dispose();
  }

  Widget _buildStandingCard(BuildContext context) {
    final accent = lightenColor(appColorNotifier.value, 0.45);

    Widget statCard(String title, String value, IconData icon) {
      final dim = lightenColor(appColorNotifier.value, 0.35);
      return Expanded(
        child: frostedGlassCard(
          context,
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.width(context, 16),
            vertical: Responsive.height(context, 14),
          ),
          child: Row(
            children: [
              HugeIcon(
                icon: icon,
                color: dim,
                size: Responsive.scale(context, 28),
              ),
              SizedBox(width: Responsive.width(context, 14)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.manrope(
                        fontSize: Responsive.font(context, 15),
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            value,
                            style: GoogleFonts.manrope(
                              fontSize: Responsive.font(context, 22),
                              color: accent,
                              fontWeight: FontWeight.w700,
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
    }

    final rankValue = _standingLoading
        ? "..."
        : _rank == null
        ? "?"
        : "#$_rank";
    final totalValue = _standingLoading
        ? "..."
        : _total == null
        ? "?"
        : "$_total";

    return Skeletonizer(
      enabled: _standingLoading,
      effect: ShimmerEffect(
        baseColor: lightenColor(appColorNotifier.value, 0.3),
        highlightColor: lightenColor(appColorNotifier.value, 0.1),
        duration: const Duration(milliseconds: 1200),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            statCard("Your Rank", rankValue, HugeIcons.strokeRoundedMedal02),
            SizedBox(width: Responsive.width(context, 12)),
            statCard(
              "Total Users",
              totalValue,
              HugeIcons.strokeRoundedUserGroup,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final accent = lightenColor(appColorNotifier.value, 0.45);
    final dim = lightenColor(appColorNotifier.value, 0.35);
    final barColor = lightenColor(appColorNotifier.value, 0.3);

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.only(bottom: Responsive.height(context, 4)),
        child: frostedGlassCard(
          context,
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.width(context, 20),
            vertical: Responsive.height(context, 20),
          ),
          child: Row(
            children: [
              HugeIcon(
                icon: icon,
                color: barColor,
                size: Responsive.scale(context, 26),
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
                color: Colors.white24,
                size: Responsive.scale(context, 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: buildThemeGradient()),
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
                  sectionHeader("BADGES", context),
                  SizedBox(height: Responsive.height(context, 12)),
                  _buildCard(
                    icon: HugeIcons.strokeRoundedCrown,
                    title: "Badges",
                    subtitle: "Track achievements and claim tier rewards",
                    onTap: () => context.push('/badges'),
                  ),
                  SizedBox(height: Responsive.height(context, 20)),
                  sectionHeader("LEADERBOARD", context),
                  SizedBox(height: Responsive.height(context, 12)),
                  _buildCard(
                    icon: HugeIcons.strokeRoundedMedal01,
                    title: "Leaderboard",
                    subtitle: "See how you rank against other players",
                    onTap: () => context.push('/leaderboard'),
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
