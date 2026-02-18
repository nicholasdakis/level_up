import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '/globals.dart';

class AboutTheDeveloper extends StatefulWidget {
  const AboutTheDeveloper({super.key});

  @override
  State<AboutTheDeveloper> createState() => _AboutTheDeveloperState();
}

class _AboutTheDeveloperState extends State<AboutTheDeveloper> {
  // Visually, simpleCustomButton. Opens an email to the developer with the appropriate subject
  Widget sendFeedbackButton(BuildContext context) {
    return simpleCustomButton(
      "Send Feedback",
      context,
      baseColor: appColorNotifier.value.withAlpha(64),
      onPressed: () async {
        final Uri emailLaunchUri = Uri(
          scheme: 'mailto',
          path: 'n1ch0lasd4k1s@gmail.com',
          query: Uri.encodeFull('subject=Feedback for Level Up!'),
        );
        if (await launchUrl(
          emailLaunchUri,
          mode: LaunchMode.externalApplication,
        )) {
          // Launched successfully, nothing extra needed
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
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight =
        1.sh; // Make widgets the size of the user's personal screen size
    double screenWidth =
        1.sw; // Make widgets the size of the user's personal screen size
    return Scaffold(
      backgroundColor: appColorNotifier.value.withAlpha(128), // Body color
      // Header box
      appBar: AppBar(
        backgroundColor: appColorNotifier.value.withAlpha(64), // Header color
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
                      sendFeedbackButton(context),
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
