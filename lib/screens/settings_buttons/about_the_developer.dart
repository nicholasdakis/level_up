import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '/globals.dart';

class AboutTheDeveloper extends StatefulWidget {
  const AboutTheDeveloper({super.key});

  @override
  State<AboutTheDeveloper> createState() => _AboutTheDeveloperState();
}

class _AboutTheDeveloperState extends State<AboutTheDeveloper> {
  // customButton() altered for the send feedback button's logic
  Widget sendFeedbackButton(
    double screenHeight,
    double screenWidth,
    BuildContext context,
  ) {
    return SizedBox(
      height: screenHeight * 0.10, // height of button
      width: screenWidth * 0.90, // width of button
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          backgroundColor: Color(0xFF2A2A2A),
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.black, width: screenWidth * 0.005),
        ),
        onPressed: () async {
          final Uri emailLaunchUri = Uri(
            scheme: 'mailto',
            path: 'n1ch0lasd4k1s@gmail.com',
            query: Uri.encodeFull('subject=Feedback for Level Up!'),
          );
          await launchUrl(emailLaunchUri, mode: LaunchMode.externalApplication);
          if (await launchUrl(
            emailLaunchUri,
            mode: LaunchMode.externalApplication,
          )) {
            await launchUrl(
              emailLaunchUri,
              mode: LaunchMode
                  .externalApplication, // open the email app externally
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "Failed to open email app. Please manually send an email to n1ch0lasd4k1s@gmail.com.",
                ),
              ),
            );
          }
        },
        child: Text(
          "Send Feedback",
          textAlign: TextAlign.center,
          style: GoogleFonts.dangrek(
            fontSize: screenWidth * 0.1,
            color: Colors.white,
            shadows: [
              Shadow(offset: Offset(-1, -1), color: Colors.black),
              Shadow(offset: Offset(1, -1), color: Colors.black),
              Shadow(offset: Offset(-1, 1), color: Colors.black),
              Shadow(offset: Offset(1, 1), color: Colors.black),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight =
        1.sh; // Make widgets the size of the user's personal screen size
    double screenWidth =
        1.sw; // Make widgets the size of the user's personal screen size
    return Scaffold(
      backgroundColor: Color(0xFF1E1E1E),
      // Header box
      appBar: AppBar(
        backgroundColor: Color(0xFF121212),
        centerTitle: true,
        toolbarHeight: screenHeight * 0.15,
        title: createTitle("Developer", screenWidth),
      ),
      // scrollable
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: screenHeight),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Placeholder image (Flutter logo)
                Image.network(
                  "https://upload.wikimedia.org/wikipedia/commons/1/17/Google-flutter-logo.png",
                  width: screenWidth * 0.3,
                  height: screenHeight * 0.3,
                ),
                SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      textWithCard(
                        "Hi! I'm Nicholas Dakis, a third year Computer Science student at CUNY Queens College.",
                        screenWidth,
                        0.055,
                      ),
                      SizedBox(height: screenHeight * 0.025),
                      textWithCard(
                        "I created Level Up! to learn Flutter and improve my coding skills by creating an app I aimed to be genuinely useful and enjoyable.",
                        screenWidth,
                        0.055,
                      ),
                      SizedBox(height: screenHeight * 0.025),
                      textWithCard(
                        "Feel free to send feedback or donate using the buttons below:",
                        screenWidth,
                        0.055,
                      ),
                      SizedBox(height: screenHeight * 0.025),
                      // SEND FEEDBACK BUTTON
                      sendFeedbackButton(screenHeight, screenWidth, context),
                      // PAYPAL DONATE BUTTON
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: InkWell(
                          onTap: () => launchUrl(
                            // open the link
                            Uri.parse(
                              "https://www.paypal.com/donate/?business=UR3VZ962M4F4N&item_name=Support+the+developer+of+Level+Up%21&currency_code=USD",
                            ),
                            mode: LaunchMode.externalApplication,
                          ),
                          // svg rendering of the asset
                          child: Align(
                            alignment: Alignment.center,
                            child: SvgPicture.network(
                              "https://upload.wikimedia.org/wikipedia/commons/b/b5/PayPal.svg",
                              width: screenWidth * 0.7,
                              placeholderBuilder: (context) =>
                                  CircularProgressIndicator(), // if image fails to load
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
        ),
      ),
    );
  }
}
