import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:pwa_install/pwa_install.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../globals.dart';
import '../providers/user_data_provider.dart';
import '../providers/workout_provider.dart';
import '../utility/responsive.dart';
import '../authentication/auth_services.dart';
import 'premium_sheet.dart';
import 'widgets/profile_card.dart';
import 'settings_stub_utils.dart'
    if (dart.library.js_interop) 'settings_web_utils.dart';

Widget buildSettingsDrawer(
  BuildContext context,
  Color appColor,
  WidgetRef ref, {
  VoidCallback? onProfileImageUpdated,
  GlobalKey<ScaffoldState>?
  scaffoldKey, // for opening the settings drawer outside its build method
}) {
  final openedAsPwa = kIsWeb
      ? isPwa()
      : false; // fallback to prevent error if called before JS is loaded
  final nativeSupported = kIsWeb
      ? supportsNativePrompt()
      : false; // fallback to prevent error if called before JS is loaded
  final promptAvailable = kIsWeb
      ? hasInstallPrompt()
      : false; // true if install prompt was captured (app not yet installed)

  final userData = ref.read(userDataProvider).value;
  final username =
      (userData?.username == null || userData?.username == userData?.uid)
      ? "Unnamed"
      : userData!.username!;

  // Consistent tile for items that show a dialog or external action instead of navigating
  final accentColor = onTheme(appColor);

  Widget buildActionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
    bool showChevron = true,
    String? tooltip,
  }) {
    final tile = Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: Responsive.width(context, 20),
          vertical: Responsive.height(context, 6),
        ),
        leading: HugeIcon(
          icon: icon,
          color: iconColor ?? accentColor,
          size: Responsive.scale(context, 22),
        ),
        title: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 16),
            color: textColor ?? accentColor,
          ),
        ),
        trailing: showChevron
            ? HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                color: accentColor,
                size: Responsive.scale(context, 20),
              )
            : null,
        hoverColor: Colors.white.withAlpha(50),
        onTap: onTap,
      ),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip,
        waitDuration: Duration(milliseconds: 0),
        showDuration: Duration(seconds: 3),
        child: tile,
      );
    }
    return tile;
  }

  final navBarHeight = !Responsive.isDesktop(context)
      ? Responsive.height(context, 160) + MediaQuery.of(context).padding.bottom
      : 0.0;

  return Drawer(
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(),
    child: Padding(
      padding: EdgeInsets.only(bottom: navBarHeight),
      child: Container(
        decoration: BoxDecoration(
          gradient: buildThemeGradient(appColor),
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(28),
            bottomRight: Radius.circular(28),
          ),
          border: Border.all(color: cardColors(appColor).border, width: 3),
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Profile header (contains pfp, username, level)
                  GestureDetector(
                    onTap: () {
                      final uid = userData?.uid;
                      if (uid == null) return;
                      showProfileCard(
                        context,
                        uid: uid,
                        appColor: appColor,
                        isOwnProfile: true,
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.fromLTRB(
                        Responsive.width(context, 20),
                        Responsive.height(context, 28),
                        0,
                        Responsive.height(context, 12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: Responsive.scale(context, 48),
                            height: Responsive.scale(context, 48),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black,
                              border: Border.all(
                                color: darkenColor(appColor, 0.06),
                                width: Responsive.scale(context, 2),
                              ),
                            ),
                            child: ClipOval(
                              child: userData?.pfpBase64 != null
                                  ? Image.memory(
                                      base64Decode(userData!.pfpBase64!),
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                    )
                                  : Icon(
                                      Icons.person,
                                      color: onTheme(appColor),
                                      size: 40,
                                    ),
                            ),
                          ),
                          SizedBox(width: Responsive.width(context, 14)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  username,
                                  softWrap: true,
                                  style: GoogleFonts.manrope(
                                    fontSize: Responsive.font(context, 16),
                                    color: accentColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: Responsive.height(context, 2)),
                                Text(
                                  "Level ${userData?.level ?? 1}",
                                  style: GoogleFonts.manrope(
                                    fontSize: Responsive.font(context, 12),
                                    color: accentColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.width(context, 16),
                    ),
                    child: Divider(
                      color: onTheme(appColor).withAlpha(120),
                      thickness: 1.5,
                    ),
                  ),
                  buildActionTile(
                    icon: HugeIcons.strokeRoundedSlidersHorizontal,
                    label: "Personal Preferences",
                    onTap: () async {
                      Navigator.pop(context); // close drawer
                      await context.push(
                        '/settings/preferences',
                        extra: onProfileImageUpdated,
                      );
                    },
                  ),
                  buildActionTile(
                    icon: HugeIcons.strokeRoundedComment01,
                    label: "Contact Us",
                    onTap: () async {
                      Navigator.pop(context);
                      if (!context.mounted) return;
                      showContactDialog(context, appColor);
                    },
                  ),
                  buildActionTile(
                    icon: HugeIcons.strokeRoundedShare01,
                    label: "Invite a Friend",
                    onTap: () async {
                      logAnalyticsEvent('tap_invite_friend_settings');
                      Navigator.pop(context);
                      final code = await ref
                          .read(userDataProvider.notifier)
                          .fetchReferralCode();
                      if (!context.mounted) return;
                      final message = code != null
                          ? "I've been using Level Up! to track my health and it's actually fun. Join me and we both get XP bonuses!\n\nDownload it here: https://play.google.com/store/apps/details?id=com.nicholasdakis.levelup\n\nUse my referral code: $code"
                          : "I've been using Level Up! to track my health and it's actually fun.\n\nDownload it here: https://play.google.com/store/apps/details?id=com.nicholasdakis.levelup";
                      await SharePlus.instance.share(
                        ShareParams(text: message),
                      );
                    },
                  ),
                  buildActionTile(
                    icon: HugeIcons.strokeRoundedStar,
                    label: "Leave a Review",
                    onTap: () async {
                      Navigator.pop(context);
                      await url_launcher.launchUrl(
                        Uri.parse(
                          'https://play.google.com/store/apps/details?id=com.nicholasdakis.levelup',
                        ),
                        mode: url_launcher.LaunchMode.externalApplication,
                      );
                    },
                  ),
                  // Chromium browsers (Chrome/Edge): show native install prompt, or snackbar if already installed
                  // Non-Chromium browsers (Safari/Firefox): always show install guide with manual instructions
                  if (kIsWeb && !openedAsPwa)
                    if (nativeSupported)
                      buildActionTile(
                        icon: HugeIcons.strokeRoundedInstallingUpdates01,
                        label: "Install App as PWA",
                        tooltip:
                            "PWA = Progressive Web App: a web app that feels like a native app and updates automatically.",
                        onTap: () {
                          if (promptAvailable) {
                            Navigator.pop(context); // close drawer
                            PWAInstall()
                                .promptInstall_(); // trigger the browser's native install dialog
                          } else {
                            Navigator.pop(
                              context,
                            ); // close drawer so snackbar appears clearly
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "This app is already installed. Check your home screen or app drawer.",
                                ),
                                duration: snackBarDurationImportant,
                              ),
                            );
                          }
                        },
                      )
                    else // Safari, Firefox, etc.
                      buildActionTile(
                        icon: HugeIcons.strokeRoundedInstallingUpdates01,
                        label: "Install App as PWA",
                        tooltip:
                            "PWA = Progressive Web App: a web app that feels like a native app and updates automatically.",
                        onTap: () async {
                          Navigator.pop(context);
                          await context.push('/settings/install');
                        },
                      ),
                  if (!(userData?.isPremium ?? false))
                    buildActionTile(
                      icon: HugeIcons.strokeRoundedCrown,
                      label: "Go Premium",
                      onTap: () {
                        Navigator.pop(context);
                        logAnalyticsEvent('premium_sheet_opened_from_settings');
                        showPremiumSheet(context, ref);
                      },
                    ),
                  // Divider to visually separate Log Out
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.width(context, 16),
                      vertical: Responsive.height(context, 8),
                    ),
                    child: Divider(
                      color: onTheme(appColor).withAlpha(120),
                      thickness: 1.5,
                    ),
                  ),
                  buildActionTile(
                    icon: HugeIcons.strokeRoundedLogout01,
                    label: "Log Out",
                    showChevron: false,
                    onTap: () async {
                      if (isGuest) {
                        Navigator.pop(context);
                        await authService.value.signOut(
                          ref.read(userDataProvider.notifier),
                          ref.read(workoutProvider.notifier),
                          ref: ref,
                        );
                        return;
                      }
                      // Dialog box for confirming logout
                      final confirmed = await showFrostedAlertDialog<bool>(
                        context: context,
                        appColor: appColor,
                        title: "Confirm Logout",
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(
                              context,
                              rootNavigator: true,
                            ).pop(false),
                            child: Text("Cancel", style: dialogButtonStyle()),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(
                              context,
                              rootNavigator: true,
                            ).pop(true),
                            child: Text(
                              "Confirm",
                              style: dialogButtonStyle(confirm: true),
                            ),
                          ),
                        ],
                      );
                      if (confirmed == true) {
                        logAnalyticsEvent('logout_confirmed');
                        Navigator.pop(context); // close drawer on confirm
                        await authService.value.signOut(
                          ref.read(userDataProvider.notifier),
                          ref.read(workoutProvider.notifier),
                          ref: ref,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            // Version pill pinned to the bottom of the drawer
            Padding(
              padding: EdgeInsets.only(
                top: Responsive.height(context, 8),
                bottom: Responsive.height(context, 24),
              ),
              child: Center(
                child: GestureDetector(
                  onTap: () => context.push('/settings/changelog'),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.width(context, 10),
                      vertical: Responsive.height(context, 4),
                    ),
                    decoration: BoxDecoration(
                      color: cardColors(appColor).iconBox,
                      borderRadius: BorderRadius.circular(
                        Responsive.scale(context, 20),
                      ),
                      border: Border.all(
                        color: cardColors(appColor).border,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Release 1.2.51",
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 11),
                            color: cardColors(appColor).onCard,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                        SizedBox(width: Responsive.width(context, 4)),
                        Icon(
                          Icons.chevron_right,
                          color: cardColors(appColor).onCard,
                          size: Responsive.font(context, 13),
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
  );
}
