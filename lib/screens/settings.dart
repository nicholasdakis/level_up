import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../globals.dart';
import 'settings_buttons/personal_preferences.dart';
import 'settings_buttons/about_the_developer.dart';
import 'settings_buttons/donate.dart';
import '../authentication/auth_services.dart';

Widget buildSettingsDrawer(
  double screenWidth,
  BuildContext context, {
  VoidCallback? onProfileImageUpdated,
}) {
  return Drawer(
    // The contents of the Settings gear icon button
    child: Container(
      color: Color.fromARGB(
        255,
        43,
        43,
        43,
      ), // Body color of the settings popup
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Color(0xFF121212),
            ), // Header color of the settings popup
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                text: "Settings",
                style: GoogleFonts.pacifico(
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
              onProfileImageUpdated: onProfileImageUpdated,
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
          drawerItem(
            "Donate",
            Icons.monetization_on,
            screenWidth,
            context,
            destination: Donate(),
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
              hoverColor: Color.fromARGB(255, 43, 43, 43),
              onTap: () async {
                await authService.value.signOut();
              },
            ),
          ),
        ],
      ),
    ),
  );
}
