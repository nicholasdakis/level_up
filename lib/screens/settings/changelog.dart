import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '/globals.dart';
import '/utility/responsive.dart';
import 'package:google_fonts/google_fonts.dart';

class ChangelogScreen extends StatefulWidget {
  const ChangelogScreen({super.key});

  @override
  State<ChangelogScreen> createState() => _ChangelogScreenState();
}

class _ChangelogScreenState extends State<ChangelogScreen> {
  @override
  void initState() {
    super.initState();
    FirebaseAnalytics.instance.logScreenView(
      screenName: '/settings/changelog',
      screenClass: 'ChangelogScreen',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: buildThemeGradient()),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          scrolledUnderElevation: 0,
          backgroundColor: darkenColor(appColorNotifier.value, 0.025),
          centerTitle: true,
          toolbarHeight: Responsive.appBarHeight(context, 120),
          leading: GestureDetector(
            onTap: () => context.pop(),
            child: Center(
              child: Container(
                padding: EdgeInsets.all(Responsive.scale(context, 12)),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: lightenColor(
                    appColorNotifier.value,
                    0.1,
                  ).withAlpha(20),
                  border: Border.all(
                    color: lightenColor(
                      appColorNotifier.value,
                      0.3,
                    ).withAlpha(180),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.arrow_back_ios_new,
                  color: lightenColor(
                    appColorNotifier.value,
                    0.3,
                  ).withAlpha(180),
                  size: Responsive.font(context, 13),
                ),
              ),
            ),
          ),
          title: createTitle("What's New", context),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: Colors.white.withAlpha(20)),
          ),
        ),
        body: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.centeredHorizontalPadding(context, 20),
            vertical: Responsive.height(context, 24),
          ),
          children: [
            _buildChangelogCard(
              context,
              date: 'June 11, 2026',
              version: '1.1.2',
              changes: [
                'New app icon: a pixelated heart design',
                'Added a changelog screen (this one!) to view a history of changes — tap the version number in the settings drawer to open it',
                'Badge cards now slide in on first load instead of replaying the animation on every tab switch',
                'Login screen updated to match the new brand colors',
                'Total lifetime XP is now shown on the home screen next to the progress bar',
                'Bug fixes and performance improvements',
              ],
            ),
            _buildChangelogCard(
              context,
              date: 'June 9, 2026',
              version: '1.1.1',
              changes: [
                'The Badges tab has been redesigned with a new frosted glass look, circular tier chips in a swipeable carousel, and milestone markers on progress bars.',
              ],
            ),
            _buildChangelogCard(
              context,
              date: 'June 8, 2026',
              version: '1.1.0',
              changes: [
                'Added a referral system to invite friends and earn XP together',
                'New social achievements for referrals',
                'Earn XP category added (rewarded ads coming soon)',
                'Explore tab can now generate nearby locations when real data is unavailable',
                'Calorie goals can now be updated directly from the Calorie Results tab',
                'UI improvements and consistency fixes across multiple screens',
                'Various backend stability improvements and bug fixes',
              ],
            ),
            _buildChangelogCard(
              context,
              date: 'May 31, 2026',
              version: '1.0.0',
              changes: ['Initial release'],
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildChangelogCard(
  BuildContext context, {
  required String date,
  required String version,
  required List<String> changes,
}) {
  final accent = lightenColor(appColorNotifier.value, 0.45);
  final dim = lightenColor(appColorNotifier.value, 0.35);

  return Padding(
    padding: EdgeInsets.only(bottom: Responsive.height(context, 16)),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(14),
        borderRadius: BorderRadius.circular(Responsive.scale(context, 16)),
        border: Border.all(color: Colors.white.withAlpha(18), width: 1),
      ),
      padding: EdgeInsets.all(Responsive.scale(context, 16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                date,
                style: GoogleFonts.manrope(
                  fontSize: Responsive.font(context, 13),
                  color: dim,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.width(context, 8),
                  vertical: Responsive.height(context, 3),
                ),
                decoration: BoxDecoration(
                  color: appColorNotifier.value.withAlpha(60),
                  borderRadius: BorderRadius.circular(
                    Responsive.scale(context, 20),
                  ),
                  border: Border.all(color: dim.withAlpha(80), width: 1),
                ),
                child: Text(
                  'v$version',
                  style: GoogleFonts.manrope(
                    fontSize: Responsive.font(context, 11),
                    color: dim,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.height(context, 12)),
          for (final change in changes) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(
                    top: Responsive.height(context, 5),
                    right: Responsive.width(context, 8),
                  ),
                  child: Container(
                    width: Responsive.scale(context, 5),
                    height: Responsive.scale(context, 5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    change,
                    style: GoogleFonts.manrope(
                      fontSize: Responsive.font(context, 13),
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: Responsive.height(context, 6)),
          ],
        ],
      ),
    ),
  );
}
