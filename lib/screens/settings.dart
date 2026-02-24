import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../globals.dart';
import '../utility/responsive.dart';
import 'settings_buttons/personal_preferences.dart';
import 'settings_buttons/about_the_developer.dart';
import '../authentication/auth_services.dart';

Widget buildSettingsDrawer(
  BuildContext context, {
  VoidCallback? onProfileImageUpdated,
}) {
  return Drawer(
    backgroundColor: appColorNotifier.value, // Drawer color
    // The contents of the Settings gear icon button
    child: ListView(
      padding: EdgeInsets.zero,
      children: [
        DrawerHeader(
          decoration: BoxDecoration(
            color: darkenColor(appColorNotifier.value, 0.025), // Header color
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
                color:
                    Colors.white, // defaults to white if no parameter is given
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
          context, // now only pass context
          destination: PersonalPreferences(
            onProfileImageUpdated:
                onProfileImageUpdated, // update the callback to update the Home Screen
          ),
          startOffset: Offset(-1, 0),
        ),
        drawerItem(
          "About The Developer",
          Icons.phone_iphone,
          context, // only context
          destination: AboutTheDeveloper(),
          startOffset: Offset(-1, 0),
        ),
        Material(
          color: Colors.transparent,
          child: ListTile(
            leading: Icon(Icons.logout, color: Color(0xFF121212)),
            title: Text(
              "Log Out",
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(
                  context,
                  18,
                ), // for scaling responsively
                color: Colors.white,
              ),
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
  );
}
