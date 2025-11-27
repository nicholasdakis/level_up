import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../globals.dart';
import 'settings_buttons/personal_preferences.dart';
import 'settings_buttons/about_the_developer.dart';
import '../authentication/auth_services.dart';

Widget buildSettingsDrawer(
  double screenWidth,
  BuildContext context, {
  VoidCallback? onProfileImageUpdated,
}) {
  return Drawer(
    // The contents of the Settings gear icon button
    child: Container(
      color: appColorNotifier.value.withAlpha(
        128,
      ), // Body color of the settings popup
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(), // Header color of the settings popup
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                text: "Settings",
                style: GoogleFonts.dangrek(
                  fontSize: screenWidth * 0.15,
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
            screenWidth,
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
            screenWidth,
            context,
            destination: AboutTheDeveloper(),
            startOffset: Offset(-1, 0),
          ),
          Material(
            color: Colors.transparent,
            child: ListTile(
              leading: Icon(Icons.logout, color: Color(0xFF121212)),
              title: textWithFont(
                "Log Out",
                screenWidth,
                0.05,
                color: Colors.white,
                alignment: TextAlign.left,
              ),
              hoverColor: appColorNotifier.value.withAlpha(230),
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
                              // sign out
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
