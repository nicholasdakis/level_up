import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/providers/user_data_provider.dart';
import '/services/user_data_manager.dart' show defaultAppColor;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '/globals.dart';
import '/utility/responsive.dart';
import 'package:google_fonts/google_fonts.dart';

class ChangelogScreen extends ConsumerStatefulWidget {
  const ChangelogScreen({super.key});

  @override
  ConsumerState<ChangelogScreen> createState() => _ChangelogScreenState();
}

class _ChangelogScreenState extends ConsumerState<ChangelogScreen> {
  Color get appColor => ref.watch(
    userDataProvider.select((s) => s.value?.appColor ?? defaultAppColor),
  );

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
      decoration: BoxDecoration(gradient: buildThemeGradient(appColor)),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListView(
            padding: EdgeInsets.only(
              left: Responsive.centeredHorizontalPadding(context, 20),
              right: Responsive.centeredHorizontalPadding(context, 20),
              bottom: Responsive.height(context, 24),
            ),
            children: [
              Padding(
                padding: EdgeInsets.only(
                  top: Responsive.height(context, 8),
                  bottom: Responsive.height(context, 12),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: themedIconBox(
                    context,
                    icon: Icons.arrow_back_ios_new,
                    color: appColor,
                    iconSize: 13,
                    padding: 12,
                    circle: true,
                    onTap: () => context.pop(),
                  ),
                ),
              ),
              _buildChangelogCard(
                context,
                appColor,
                date: 'July 16, 2026',
                version: '1.2.42',
                changes: [
                  'Badges tab redesigned with filters for greater convenience',
                  'Micronutrients have been better implemented into Food Analytics',
                  'Improved empty states, loading animations, and overall UI polish',
                  'Many performance improvements for a smoother app experience',
                ],
              ),
              _buildChangelogCard(
                context,
                appColor,
                date: 'July 15, 2026',
                version: '1.2.41',
                changes: ['Performance improvements to the Food Logging tab'],
              ),
              _buildChangelogCard(
                context,
                appColor,
                date: 'July 15, 2026',
                version: '1.2.4',
                changes: [
                  'New Workout Analytics screen with workout trends, muscle group insights, personal record tracking, and session statistics',
                  'The Workout tab and its internal screens have been completely overhauled for a more premium experience',
                  'Sets can now be deleted from exercises without having to delete the entire exercise',
                  'The workout rest timer can now be disabled',
                  'The workout duration timer can now be adjusted',
                  'Various bug fixes and polish across multiple screens',
                ],
              ),
              _buildChangelogCard(
                context,
                appColor,
                date: 'July 14, 2026',
                version: '1.2.3',
                changes: [
                  'Micronutrient tracking, goals, and analytics are now here. Track your fiber, sodium, and sugar intake.',
                  'Active workout sessions now show a persistent foreground notification for frictionless workout logging.',
                  'Guest mode and onboarding have been completely overhauled to provide a richer experience for new users browsing and joining the app.',
                  'Food logging and workout tracking have received numerous usability improvements.',
                  'Pull-to-refresh added to most screens',
                  'A smoother, faster experience with dozens of UI refinements, bug fixes, performance improvements, and security enhancements.',
                ],
              ),
              _buildChangelogCard(
                context,
                appColor,
                date: 'July 12, 2026',
                version: '1.2.21',
                changes: [
                  'Onboarding improvements and quality of life updates across the app',
                  'Several bug fixes for a smoother experience',
                ],
              ),
              _buildChangelogCard(
                context,
                appColor,
                date: 'July 10, 2026',
                version: '1.2.2',
                changes: [
                  'Level Up! Pro is now available. Subscribe to unlock premium features and support the app',
                ],
              ),
              _buildChangelogCard(
                context,
                appColor,
                date: 'July 9, 2026',
                version: '1.2.1',
                changes: [
                  'Major under-the-hood rewrite to improve app performance, responsiveness, and stability across all screens',
                  'New leaderboard types added with time-based filters: Foods logged and Workouts logged',
                  'Added a Suggested tab to the Log Food screen, showing your currently most frequently logged foods per meal',
                  'Logged foods can now be moved to different meal types',
                  'Inviting friends is now easier, with a native share button now in the referrals dialog and settings drawer',
                  'Your rank card on the Progression screen now shows your standing across XP, foods logged, and workouts',
                  'Badges screen redesigned with achievements grouped into scrollable sections so everything is visible at a glance',
                  '4 new workout achievements added: Double Down, Full Body, Early Bird, and Night Owl',
                ],
              ),
              _buildChangelogCard(
                context,
                appColor,
                date: 'July 4, 2026',
                version: '1.2.0',
                changes: [
                  'The Workout tab has been introduced',
                  'Log any workout with full set, weight, and rep tracking and a live elapsed timer',
                  'A collapsible mini bar stays above the nav bar while a session is active so you can use the rest of the app without losing your workout',
                  'Browse featured and community routines, or build your own with custom exercises',
                  'View your activity heatmap, recent workouts, muscles trained, and a daily overview of volume, sets, and reps',
                  'Completing a workout earns XP, with a bonus for longer sessions',
                  'New workout achievements to unlock',
                  'Replacing an exercise now shows recommended alternatives that target the same muscle group',
                ],
              ),
              _buildChangelogCard(
                context,
                appColor,
                date: 'June 27, 2026',
                version: '1.1.52',
                changes: [
                  'Onboarding is now a simple step-by-step setup that automatically calculates your calorie targets, macro splits, and goals based on your journey',
                  "Log food even faster with a new shortcut on the home dashboard's Calorie card",
                  'The Daily reward dialog no longer auto-opens on launch so you can claim it on your own terms',
                  'Voice input added to the reminders screen so you can speak your reminder message',
                  'Various visual fixes and polish across the app',
                ],
              ),
              _buildChangelogCard(
                context,
                appColor,
                date: 'June 25, 2026',
                version: '1.1.51',
                changes: [
                  'Food log SQL table updated to allow richer analytics data moving forward',
                  'Logged food cards now show the time of logging',
                  'Recent foods are now synced across devices instead of per-device',
                  'A "most logged foods" card has been added to Food Analytics',
                  'Bug fixes related to the leveling overlay screen',
                ],
              ),
              _buildChangelogCard(
                context,
                appColor,
                date: 'June 24, 2026',
                version: '1.1.5',
                changes: [
                  'Leveling up now triggers a celebration screen showing your new rank, XP earned, best streaks, days logged, weigh-ins, water logs, and friends referred',
                  'Water analytics added so you can see your hydration habits over time',
                  'Weight analytics added so you can track your progress with a goal line, stat tiles, and your full entry history',
                  'Food analytics completely overhauled with richer line charts, deeper breakdowns by meal, and cleaner calorie and macro summaries',
                  'Macro and calorie data now shown per meal on both the logging screen and in analytics',
                  'Macro chips in the serving size dialog are now tappable to edit values directly',
                  'Dozens of fixes and improvements across the app',
                ],
              ),
              _buildChangelogCard(
                context,
                appColor,
                date: 'June 21, 2026',
                version: '1.1.4',
                changes: [
                  'Metric and Imperial unit preferences added',
                  'Water logging with quick-add buttons, custom amounts, and per-entry deletion',
                  'Weight logging with date navigation and entry history',
                  'New goal types: Water intake and target weight',
                  'Logs Today card replaced with a Macros card',
                  'Calories card now has shortcuts to logging and analytics screens',
                  "The food search screen's UI has been overhauled",
                  'Numerous UI and usability polishing across all screens',
                  'Macro values can now be edited directly when logging or adjusting a food entry',
                ],
              ),
              _buildChangelogCard(
                context,
                appColor,
                date: 'June 16, 2026',
                version: '1.1.3',
                changes: [
                  'The Leaderboard and Badges tabs have been replaced with the new Progress tab, bringing them together in one place with more features planned ahead',
                  'Updated the app logo with a new blue gradient design',
                  'Completely redesigned the login screen with a cleaner two-step flow and refreshed branding',
                  'Added two new Progress cards showing your current rank and the percentage of players you are ahead of',
                  'All cards across the app now use a consistent style that adapts to your selected theme color',
                  'Light and vibrant theme colors now look significantly better throughout the app',
                  'The floating navigation bar now automatically adapts for both dark and light theme colors to improve readability',
                  'Added a Weekly Workout Goal to Personal Preferences in preparation for the upcoming Workout feature',
                  'Bug fixes and numerous visual consistency improvements',
                ],
              ),
              _buildChangelogCard(
                context,
                appColor,
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
                appColor,
                date: 'June 9, 2026',
                version: '1.1.1',
                changes: [
                  'The Badges tab has been redesigned with a new frosted glass look, circular tier chips in a swipeable carousel, and milestone markers on progress bars.',
                ],
              ),
              _buildChangelogCard(
                context,
                appColor,
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
                appColor,
                date: 'May 31, 2026',
                version: '1.0.0',
                changes: ['Initial release'],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buildChangelogCard(
  BuildContext context,
  Color appColor, {
  required String date,
  required String version,
  required List<String> changes,
}) {
  final c = cardColors(appColor);
  final accent = c.onCard;
  final dim = c.onCard;

  return Padding(
    padding: EdgeInsets.only(bottom: Responsive.height(context, 16)),
    child: frostedGlassCard(
      context,
      color: appColor,
      baseRadius: 16,
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
                  color: c.iconBox,
                  borderRadius: BorderRadius.circular(
                    Responsive.scale(context, 20),
                  ),
                  border: Border.all(color: c.border, width: 1.5),
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
                      color: accent,
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
