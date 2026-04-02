import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pwa_install/pwa_install.dart';
import '../globals.dart';
import '../utility/responsive.dart';
import 'settings_buttons/personal_preferences.dart';
import 'settings_buttons/about_the_developer.dart';
import 'settings_buttons/install_guide.dart';
import '../authentication/auth_services.dart';
import 'dart:js_interop';

@JS('isPwa')
external bool isPwa();

@JS('supportsNativePrompt')
external bool supportsNativePrompt();

@JS('hasInstallPrompt') // for PWA installation detection natively
external bool hasInstallPrompt();

@JS(
  'wasEverInstalledAsPwa',
) // for PWA installation detection on unsupported browsers (i.e ones that have no beforeInstallPrompt) (Safari, Firefox)
external bool wasEverInstalledAsPwa();

Widget buildSettingsDrawer(
  BuildContext context, {
  VoidCallback? onProfileImageUpdated,
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
  final previouslyInstalled = kIsWeb
      ? wasEverInstalledAsPwa()
      : false; // true if the app was ever opened as an installed PWA
  return Drawer(
    backgroundColor: Colors.transparent, // Transparent so gradient shows
    // The contents of the Settings gear icon button
    child: Container(
      decoration: BoxDecoration(gradient: buildThemeGradient()),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.transparent, // let gradient show through
              border: Border(
                bottom: BorderSide(
                  color: darkenColor(appColorNotifier.value, 0.025),
                  width: 1,
                ),
              ),
            ),
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                text: "Settings",
                style: GoogleFonts.dangrek(
                  fontSize: Responsive.font(
                    context,
                    30,
                  ), // for scaling responsively
                  color: Colors
                      .white, // defaults to white if no parameter is given
                  shadows: [
                    Shadow(
                      offset: Offset(4, 4),
                      blurRadius: 10,
                      color: const Color.fromARGB(255, 0, 0, 0),
                    ),
                  ],
                ),
              ),
            ),
          ),
          drawerItem(
            "Personal Preferences",
            Icons.account_circle,
            context,
            destination: PersonalPreferences(
              onProfileImageUpdated:
                  onProfileImageUpdated, // update the callback to update the Home Screen
            ),
            startOffset: Offset(-1, 0),
          ),
          drawerItem(
            "About The Developer",
            Icons.phone_iphone,
            context,
            destination: AboutTheDeveloper(),
            startOffset: Offset(-1, 0),
          ),

          // Chromium browsers (Chrome/Edge), trigger the native install dialog
          // on other browsers (Safari/Firefox), show a tutorial screen with manual instructions
          if (kIsWeb && !openedAsPwa)
            if (nativeSupported &&
                promptAvailable) // Opened on web, supports native and app is not installed -> show native install prompt
              Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: Icon(Icons.install_mobile, color: Colors.white),
                  title: Tooltip(
                    message:
                        "PWA = Progressive Web App: a web app that feels like a native app and updates automatically.",
                    waitDuration: Duration(milliseconds: 0),
                    showDuration: Duration(seconds: 3),
                    child: textWithFont(
                      "Install App as PWA",
                      context,
                      Responsive.font(context, 18),
                      color: Colors.white,
                      alignment: TextAlign.left,
                    ),
                  ),
                  hoverColor: Colors.white.withAlpha(50),
                  onTap: () {
                    Navigator.pop(context); // close drawer
                    PWAInstall()
                        .promptInstall_(); // trigger the browser's native install dialog
                  },
                ),
              )
            else if (nativeSupported &&
                !promptAvailable) // Browser supports install but prompt not available -> already installed
              Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: Icon(Icons.check_circle, color: Colors.white70),
                  title: Tooltip(
                    message:
                        "This app is already installed on your device. Look for it on your home screen or app drawer.",
                    waitDuration: Duration(milliseconds: 0),
                    showDuration: Duration(seconds: 3),
                    child: textWithFont(
                      "Already Installed",
                      context,
                      Responsive.font(context, 18),
                      color: Colors.white70,
                      alignment: TextAlign.left,
                    ),
                  ),
                  hoverColor: Colors.white.withAlpha(50),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "This app is already installed. Check your home screen or app drawer.",
                        ),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  },
                ),
              )
            // Fallback for browsers that don't support beforeinstallprompt (Safari, Firefox etc)
            else if (!previouslyInstalled) // Not supported and not previously installed -> show manual installation guide screen
              drawerItem(
                "Install App as PWA",
                Icons.install_mobile,
                context,
                destination:
                    const InstallGuide(), // a tutorial screen with manual installation instructions
                startOffset: Offset(-1, 0),
                tooltip:
                    "PWA = Progressive Web App: a web app that feels like a native app and updates automatically.",
              )
            else // Not supported but previously installed -> show "Already Installed"
              Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: Icon(Icons.check_circle, color: Colors.white70),
                  title: Tooltip(
                    message:
                        "This app is already installed on your device. Look for it on your home screen or app drawer.",
                    waitDuration: Duration(milliseconds: 0),
                    showDuration: Duration(seconds: 3),
                    child: textWithFont(
                      "Already Installed",
                      context,
                      Responsive.font(context, 18),
                      color: Colors.white70,
                      alignment: TextAlign.left,
                    ),
                  ),
                  hoverColor: Colors.white.withAlpha(50),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "This app is already installed. Check your home screen or app drawer.",
                        ),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  },
                ),
              ),

          Material(
            color: Colors.transparent,
            child: ListTile(
              leading: Icon(Icons.logout, color: Colors.white),
              title: Text(
                "Log Out",
                style: GoogleFonts.manrope(
                  fontSize: Responsive.font(context, 18),
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      offset: Offset(
                        Responsive.scale(context, 4),
                        Responsive.scale(context, 4),
                      ),
                      blurRadius: Responsive.scale(context, 10),
                      color: const Color.fromARGB(255, 0, 0, 0),
                    ),
                  ],
                ),
              ),
              hoverColor: Colors.white.withAlpha(50),
              onTap: () async {
                // Dialog box for confirming logout
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: appColorNotifier.value.withAlpha(200),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    title: Text(
                      "Confirm Logout",
                      style: TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
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
                            child: Text(
                              "CANCEL",
                              style: TextStyle(color: Colors.white),
                            ),
                            // close if canceled
                            onPressed: () => Navigator.pop(context),
                          ),
                          TextButton(
                            child: Text(
                              "CONFIRM",
                              style: TextStyle(color: Colors.white),
                            ),
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
          ),
        ],
      ),
    ),
  );
}
