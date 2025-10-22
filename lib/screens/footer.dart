import 'package:flutter/material.dart';
import 'package:level_up/screens/settings_buttons/personal_preferences.dart';
import '../globals.dart';

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
    return Container(
      height: widget.screenHeight * 0.15,
      width: widget.screenWidth,
      color: Color(0xFF121212),
      padding: EdgeInsets.all(25),
      child: Center(
        child: Row(
          children: [
            // Wrapper Container with sufficient width to contain the overlapping circle
            // ignore: sized_box_for_whitespace
            Container(
              width:
                  widget.screenWidth * 0.7 +
                  widget.screenHeight *
                      0.045, // EXP bar width + half circle width
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Outer EXP bar
                  Container(
                    height: widget.screenHeight * 0.03,
                    width: widget.screenWidth * 0.7,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  // Inner EXP bar
                  Positioned(
                    top: widget.screenHeight * 0.005,
                    left: widget.screenWidth * 0.025,
                    child: Container(
                      height: widget.screenHeight * 0.02,
                      width: widget.screenWidth * 0.65,
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 227, 210, 210),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  // Experience text
                  Positioned.fill(
                    child: Center(
                      child: Stack(
                        children: [
                          // black outline around text
                          Builder(
                            builder: (context) {
                              Paint outlinePaint = Paint();
                              outlinePaint.style = PaintingStyle.stroke;
                              outlinePaint.strokeWidth = 1;
                              outlinePaint.color = Colors.black;

                              return Text(
                                '${currentUserData?.expPoints ?? 0} / ${userManager.experienceNeeded ?? 0}',
                                style: TextStyle(
                                  fontSize: widget.screenHeight * 0.015,
                                  fontWeight: FontWeight.bold,
                                  foreground: outlinePaint,
                                ),
                              );
                            },
                          ),
                          // white color on the inside
                          Text(
                            '${currentUserData?.expPoints ?? 0} / ${userManager.experienceNeeded ?? 0}',
                            style: TextStyle(
                              fontSize: widget.screenHeight * 0.015,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Profile picture
                  Positioned(
                    right:
                        -widget.screenWidth *
                        0.02, // move both hitbox and profile picture to the right
                    top:
                        (widget.screenHeight * 0.03 -
                            widget.screenHeight * 0.09) /
                        2,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          debugPrint("Tapped");
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PersonalPreferences(
                                onProfileImageUpdated:
                                    widget.onProfileImageUpdated,
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(50),
                        child: Container(
                          width: widget.screenHeight * 0.09,
                          height: widget.screenHeight * 0.09,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black,
                          ),
                          child: ClipOval(child: widget.profilePicture),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
