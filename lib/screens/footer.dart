import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../globals.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utility/responsive.dart';

class Footer extends StatefulWidget {
  final Widget profilePicture;
  final VoidCallback onProfileImageUpdated;

  const Footer({
    super.key,
    required this.profilePicture,
    required this.onProfileImageUpdated,
  });

  @override
  State<Footer> createState() => _FooterState();
}

class _FooterState extends State<Footer> {
  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.sizeOf(
      context,
    ).width; // Make widgets the size of the user's personal screen size

    Widget buildFooterClickablePfp(BuildContext context) {
      return SizedBox(
        width: Responsive.scale(context, 72),
        height: Responsive.scale(context, 72),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            splashColor: appColorNotifier.value.withAlpha(100),
            onTap: () {
              context.push(
                '/settings/preferences',
                extra: widget.onProfileImageUpdated,
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

    buildFooterPfpSection(BuildContext context, Widget pfpLevelText) {
      return Positioned(
        right: -Responsive.scale(context, 8),
        top: 0,
        child: Column(
          children: [
            buildFooterClickablePfp(context),
            SizedBox(height: Responsive.height(context, 2)),
            // Display current level under profile picture
            pfpLevelText,
          ],
        ),
      );
    }

    Widget buildFooterLevelText() {
      return Text(
        'Level ${currentUserData?.level ?? 1}',
        style: GoogleFonts.manrope(
          fontSize: Responsive.font(context, 12),
          color: Colors.white,
          shadows: [textDropShadow(context)],
        ),
      );
    }

    Widget buildExpBar(double fullWidth, double progressWidth) {
      final barRadius = BorderRadius.circular(Responsive.scale(context, 10));
      final borderWidth = Responsive.scale(context, 4);
      // Black outer border of the exp bar
      return Container(
        height: Responsive.height(context, 25),
        width: fullWidth,
        padding: EdgeInsets.all(borderWidth),
        decoration: BoxDecoration(color: Colors.black, borderRadius: barRadius),
        // Clips the inner contents to a rounded shape that fits inside the border
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            Responsive.scale(context, 10) - borderWidth,
          ),
          child: Stack(
            children: [
              // Gray unfilled portion of the exp bar
              Container(color: const Color.fromARGB(255, 175, 169, 169)),
              // Blue filled portion representing the user's current exp progress
              Align(
                alignment: Alignment.centerLeft,
                child: Container(width: progressWidth, color: Colors.blue),
              ),
            ],
          ),
        ),
      );
    }

    Widget buildFooterExperienceText(int exp) {
      return Positioned.fill(
        child: Center(
          child: Stack(
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
          ),
        ),
      );
    }

    return Container(
      width: double.infinity, // full width footer
      height: Responsive.height(context, 120),
      decoration: BoxDecoration(
        color: darkenColor(appColorNotifier.value, 0.025),
        border: Border(
          top: BorderSide(color: Colors.white.withAlpha(20), width: 1),
        ),
      ),
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
                  0.8, // EXP bar and profile picture container scales with screen width
              child: ValueListenableBuilder<int>(
                valueListenable: expNotifier, // reactive XP value
                builder: (context, exp, _) {
                  final fullWidth =
                      (screenWidth * 0.8) -
                      Responsive.scale(
                        context,
                        80,
                      ); // leave space for profile picture

                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: exp.toDouble()),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOut,
                    builder: (context, animatedExp, _) {
                      final progressWidth =
                          fullWidth *
                          (animatedExp / (userManager.experienceNeeded ?? 1));

                      // Footer components
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // SizedBox to force parent Stack hit-test area to 72px to match footer pfp
                          SizedBox(
                            height: Responsive.scale(context, 72),
                            width:
                                fullWidth, // constrain to leave space for pfp
                            child: Center(
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  buildExpBar(fullWidth, progressWidth),
                                  // Round the animated value so the counter ticks in whole numbers
                                  buildFooterExperienceText(
                                    animatedExp.round(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          buildFooterPfpSection(
                            context,
                            buildFooterLevelText(),
                          ),
                        ],
                      );
                    },
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
