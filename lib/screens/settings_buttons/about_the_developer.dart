import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '/globals.dart';
import '/utility/responsive.dart';

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
      48,
      120,
      400,
      context,
      baseColor: darkenColor(appColorNotifier.value, 0.025),
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
    return Scaffold(
      backgroundColor: appColorNotifier.value, // Body color
      // Header box
      appBar: AppBar(
        backgroundColor: darkenColor(
          appColorNotifier.value,
          0.025,
        ), // Header color
        centerTitle: true,
        toolbarHeight: Responsive.buttonHeight(
          context,
          120,
        ), // Scale based on device
        title: createTitle("Developer", context), // Scale based on device
      ),
      // scrollable
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: Responsive.height(context, 800),
          ), // Scale based on device
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Placeholder image (Flutter logo)
                Image.network(
                  "https://upload.wikimedia.org/wikipedia/commons/1/17/Google-flutter-logo.png",
                  width: Responsive.width(
                    context,
                    300,
                  ), // Scale based on device
                  height: Responsive.height(
                    context,
                    300,
                  ), // Scale based on device
                ),
                SizedBox(
                  height: Responsive.height(context, 20),
                ), // Scale based on device
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.padding(context, 75),
                  ), // Scale based on device
                  child: Column(
                    children: [
                      textWithCard(
                        "Hi! I'm Nicholas Dakis, a Computer Science student at CUNY Queens College. I created Level Up! to learn Flutter while creating an app I believed to be useful.",
                        context,
                        Responsive.font(context, 40), // Scale based on device
                      ),
                      SizedBox(
                        height: Responsive.height(context, 20),
                      ), // Scale based on device
                      textWithCard(
                        "Feel free to send feedback or donate using the buttons below:",
                        context,
                        Responsive.font(context, 50), // Scale based on device
                      ),
                      SizedBox(
                        height: Responsive.height(context, 20),
                      ), // Scale based on device
                      // SEND FEEDBACK BUTTON
                      sendFeedbackButton(context),
                      // PAYPAL DONATE BUTTON
                      Padding(
                        padding: EdgeInsets.all(
                          Responsive.padding(context, 20),
                        ), // Scale based on device
                        child: InkWell(
                          onTap: () => launchUrl(
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
                              width: Responsive.width(
                                context,
                                280,
                              ), // Scale based on device
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
