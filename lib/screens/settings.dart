import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:pwa_install/pwa_install.dart';
import '../globals.dart';
import '../utility/responsive.dart';
import '../authentication/auth_services.dart';
import '../services/user_data_manager.dart' show trackTrivialAchievement;
import 'dart:js_interop';

@JS('isPwa')
external bool isPwa();

@JS('supportsNativePrompt')
external bool supportsNativePrompt();

@JS('hasInstallPrompt') // for PWA installation detection natively
external bool hasInstallPrompt();

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
  Widget buildActionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color iconColor = Colors.white,
    Color textColor = Colors.white,
    bool showChevron = true,
    String? tooltip,
  }) {
    final tile = Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: Responsive.width(context, 20),
          vertical: Responsive.height(context, 2),
        ),
        leading: Icon(
          icon,
          color: iconColor,
          size: Responsive.scale(context, 22),
        ),
        title: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: Responsive.font(context, 16),
            color: textColor,
          ),
        ),
        trailing: showChevron
            ? Icon(
                Icons.chevron_right,
                color: Colors.white38,
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

  return Drawer(
    backgroundColor: Colors.transparent, // Transparent so gradient shows
    child: Container(
      decoration: BoxDecoration(gradient: buildThemeGradient()),
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
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withAlpha(25), width: 3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: Responsive.scale(context, 52),
                  height: Responsive.scale(context, 52),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black,
                    border: Border.all(
                      color: Colors.white.withAlpha(60),
                      width: Responsive.scale(context, 2),
                    ),
                  ),
                  child: ClipOval(child: userManager.insertProfilePicture()),
                ),
                SizedBox(width: Responsive.width(context, 14)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: GoogleFonts.manrope(
                        fontSize: Responsive.font(context, 16),
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: Responsive.height(context, 2)),
                    Text(
                      "Level ${currentUserData?.level ?? 1}",
                      style: GoogleFonts.manrope(
                        fontSize: Responsive.font(context, 12),
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: Responsive.height(context, 8)),
          buildActionTile(
            icon: Icons.account_circle_outlined,
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
            icon: Icons.info_outline,
            label: "About The Developer",
            onTap: () async {
              Navigator.pop(context);
              await context.push('/settings/developer');
            },
          ),
          buildActionTile(
            icon: Icons.feedback_outlined,
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
          // Chromium browsers (Chrome/Edge): show native install prompt, or snackbar if already installed
          // Non-Chromium browsers (Safari/Firefox): always show install guide with manual instructions
          if (kIsWeb && !openedAsPwa)
            if (nativeSupported)
              buildActionTile(
                icon: Icons.install_mobile,
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
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                },
              )
            else // Safari, Firefox, etc.
              buildActionTile(
                icon: Icons.install_mobile,
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
            child: Divider(color: Colors.white.withAlpha(25), thickness: 3),
          ),
          buildActionTile(
            icon: Icons.logout,
            label: "Log Out",
            iconColor: Colors.red.withAlpha(200),
            textColor: Colors.red.withAlpha(200),
            showChevron: false,
            onTap: () async {
              // Dialog box for confirming logout
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text("Confirm Logout", textAlign: TextAlign.center),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                  ),
                  actions: [
                    Row(
                      mainAxisAlignment:
                          // spaceBetween so CANCEL appears in the left-most part of the box and CONFIRM at the right-most
                          MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          child: Text("CANCEL"),
                          // close if canceled
                          onPressed: () => Navigator.pop(context),
                        ),
                        TextButton(
                          child: Text("CONFIRM"),
                          // Handle logout
                          onPressed: () async {
                            // close the dialog box
                            Navigator.pop(context);
                            await authService.value.signOut();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    ),
  );
}
