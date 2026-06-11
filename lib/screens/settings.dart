import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:pwa_install/pwa_install.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import '../globals.dart';
import '../utility/responsive.dart';
import '../authentication/auth_services.dart';
import '../services/user_data_manager.dart' show trackTrivialAchievement;
import 'settings_stub_utils.dart'
    if (dart.library.js_interop) 'settings_web_utils.dart';

Widget buildSettingsDrawer(
  BuildContext context, {
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

  final username =
      (currentUserData?.username == null ||
          currentUserData?.username == currentUserData?.uid)
      ? "Unnamed"
      : currentUserData!.username!;

  // Consistent tile for items that show a dialog or external action instead of navigating
  final accentColor = lightenColor(appColorNotifier.value, 0.45);

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
          gradient: buildThemeGradient(),
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(28),
            bottomRight: Radius.circular(28),
          ),
          border: Border.all(color: Colors.white.withAlpha(25), width: 3),
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Profile header (contains pfp, username, level)
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      Responsive.width(context, 20),
                      Responsive.height(context, 60),
                      Responsive.width(context, 20),
                      Responsive.height(context, 20),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: Responsive.scale(context, 60),
                          height: Responsive.scale(context, 60),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black,
                            border: Border.all(
                              color: darkenColor(appColorNotifier.value, 0.06),
                              width: Responsive.scale(context, 2),
                            ),
                          ),
                          child: ClipOval(
                            child: userManager.insertProfilePicture(),
                          ),
                        ),
                        SizedBox(width: Responsive.width(context, 14)),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              username,
                              style: GoogleFonts.manrope(
                                fontSize: Responsive.font(context, 16),
                                color: accentColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: Responsive.height(context, 2)),
                            Text(
                              "Level ${currentUserData?.level ?? 1}",
                              style: GoogleFonts.manrope(
                                fontSize: Responsive.font(context, 12),
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.width(context, 16),
                    ),
                    child: Divider(
                      color: Colors.white.withAlpha(25),
                      thickness: 1,
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
                    icon: HugeIcons.strokeRoundedPhoneDeveloperMode,
                    label: "About The Developer",
                    onTap: () async {
                      Navigator.pop(context);
                      await context.push('/settings/developer');
                    },
                  ),
                  buildActionTile(
                    icon: HugeIcons.strokeRoundedComment01,
                    label: "Send Feedback",
                    onTap: () async {
                      Navigator.pop(context);
                      trackTrivialAchievement("send_feedback");
                      sendEmail(
                        context,
                        "n1ch0lasd4k1s@gmail.com",
                        "Feedback for Level up!",
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
                  // Divider to visually separate Log Out
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.width(context, 16),
                      vertical: Responsive.height(context, 8),
                    ),
                    child: Divider(
                      color: Colors.white.withAlpha(25),
                      thickness: 1,
                    ),
                  ),
                  buildActionTile(
                    icon: HugeIcons.strokeRoundedLogout01,
                    label: "Log Out",
                    iconColor: Colors.red.withAlpha(200),
                    textColor: Colors.red.withAlpha(200),
                    showChevron: false,
                    onTap: () async {
                      // Dialog box for confirming logout
                      final confirmed = await showFrostedAlertDialog<bool>(
                        context: context,
                        title: "Confirm Logout",
                        actions: [
                          TextButton(
                            child: Text("CANCEL"),
                            onPressed: () => Navigator.of(
                              context,
                              rootNavigator: true,
                            ).pop(false),
                          ),
                          TextButton(
                            child: Text("CONFIRM"),
                            onPressed: () => Navigator.of(
                              context,
                              rootNavigator: true,
                            ).pop(true),
                          ),
                        ],
                      );
                      if (confirmed == true) {
                        Navigator.pop(context); // close drawer on confirm
                        await authService.value.signOut();
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
                      color: Colors.white.withAlpha(12),
                      borderRadius: BorderRadius.circular(
                        Responsive.scale(context, 20),
                      ),
                      border: Border.all(
                        color: Colors.white.withAlpha(20),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Release 1.1.2",
                          style: GoogleFonts.manrope(
                            fontSize: Responsive.font(context, 11),
                            color: Colors.white.withAlpha(80),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                        SizedBox(width: Responsive.width(context, 4)),
                        Icon(
                          Icons.chevron_right,
                          color: Colors.white.withAlpha(80),
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
