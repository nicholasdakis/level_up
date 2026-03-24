import 'package:flutter/material.dart';
import 'package:level_up/screens/settings_buttons/personal_preferences.dart';
import '../globals.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utility/responsive.dart';

class Footer extends StatefulWidget {
  final double screenHeight;
  final double screenWidth;
  final Widget profilePicture;
  final VoidCallback onProfileImageUpdated;

  const Footer({
    super.key,
    required this.screenHeight,
    required this.screenWidth,
    required this.profilePicture,
    required this.onProfileImageUpdated,
  });

  @override
  State<Footer> createState() => _FooterState();
}

class _FooterState extends State<Footer> {
  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(
      context,
    ).size.width; // Make widgets the size of the user's personal screen size

    Widget buildFooterPfp(BuildContext context) {
      return SizedBox(
        width: Responsive.scale(context, 72),
        height: Responsive.scale(context, 72),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PersonalPreferences(
                    onProfileImageUpdated: widget.onProfileImageUpdated,
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(50),
            child: Container(
              width: Responsive.scale(context, 72),
              height: Responsive.scale(context, 72),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black,
              ),
              // black border around profile picture
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.black,
                    width: Responsive.scale(context, 4),
                  ),
                ),
                child: ClipOval(child: widget.profilePicture),
              ),
            ),
          ),
        ),
      );
    }

    Widget buildFooterLevel() {
      return Text(
        'Level ${currentUserData?.level ?? 1}',
        style: GoogleFonts.manrope(
          fontSize: Responsive.font(context, 12),
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
      );
    }

    Widget buildFooterInnerExpBar(double progressWidth) {
      return Positioned(
        top: Responsive.height(context, 4),
        left: Responsive.width(context, 10),
        child: Container(
          height: Responsive.height(context, 16),
          width: progressWidth,
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(Responsive.scale(context, 10)),
          ),
        ),
      );
    }

    Widget buildFooterOuterExpBar(double fullWidth) {
      return Container(
        height: Responsive.height(context, 25),
        width: fullWidth,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(Responsive.scale(context, 10)),
        ),
      );
    }

    Widget buildFooterExperienceText(int exp) {
      return Stack(
        children: [
          // black outline around text
          Builder(
            builder: (context) {
              Paint outlinePaint = Paint();
              outlinePaint.style = PaintingStyle.stroke;
              outlinePaint.strokeWidth = Responsive.scale(context, 1);
              outlinePaint.color = Colors.black;

              return Text(
                '$exp / ${userManager.experienceNeeded ?? 0}',
                style: TextStyle(
                  fontSize: Responsive.font(context, 12),
                  fontWeight: FontWeight.bold,
                  foreground: outlinePaint,
                ),
              );
            },
          ),
          // white color on the inside
          Text(
            '$exp / ${userManager.experienceNeeded ?? 0}',
            style: TextStyle(
              fontSize: Responsive.font(context, 12),
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity, // full width footer
      height: Responsive.height(context, 120),
      color: darkenColor(appColorNotifier.value, 0.025), // Header color
      padding: EdgeInsets.all(Responsive.padding(context, 16)),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center, // center XP bar
          children: [
            // Wrapper Container with sufficient width to contain the overlapping circle
            // ignore: sized_box_for_whitespace
            Container(
              width:
                  screenWidth *
                  0.8, // EXP bar + profile picture container scales with screen width
              child: ValueListenableBuilder<int>(
                valueListenable: expNotifier, // reactive XP value
                builder: (context, exp, child) {
                  final fullWidth =
                      (screenWidth * 0.8) -
                      Responsive.scale(
                        context,
                        80,
                      ); // leave space for profile picture
                  final progressWidth =
                      fullWidth * (exp / (userManager.experienceNeeded ?? 1));

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // SizedBox to force parent Stack hit-test area to 72px to match footer pfp
                      SizedBox(
                        height: Responsive.scale(context, 72),
                        width: fullWidth, // constrain to leave space for pfp
                        child: Center(
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Outer EXP bar
                              buildFooterOuterExpBar(fullWidth),
                              // Light Gray bar
                              Positioned(
                                top: Responsive.height(context, 4),
                                left: Responsive.width(context, 10),
                                child: Container(
                                  height: Responsive.height(context, 16),
                                  width:
                                      fullWidth - Responsive.width(context, 20),
                                  decoration: BoxDecoration(
                                    color: const Color.fromARGB(
                                      255,
                                      175,
                                      169,
                                      169,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      Responsive.scale(context, 10),
                                    ),
                                  ),
                                ),
                              ),
                              // inner-most XP bar that fills up
                              buildFooterInnerExpBar(progressWidth),
                              // Experience text
                              Positioned.fill(
                                child: Center(
                                  child: buildFooterExperienceText(exp),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Profile picture
                      Positioned(
                        right: -Responsive.scale(context, 8),
                        top: 0,
                        child: Column(
                          children: [
                            buildFooterPfp(context),
                            SizedBox(height: Responsive.height(context, 2)),
                            // Display current level under profile picture
                            buildFooterLevel(),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
