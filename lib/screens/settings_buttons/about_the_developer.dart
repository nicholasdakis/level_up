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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: buildThemeGradient()),
      child: Scaffold(
        backgroundColor: Colors.transparent, // Body color
        // Header box
        appBar: AppBar(
          backgroundColor: darkenColor(
            appColorNotifier.value,
            0.025,
          ), // Header color
          centerTitle: true,
          toolbarHeight: Responsive.buttonHeight(context, 120),
          title: createTitle("Developer", context),
        ),
        // scrollable
        body: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: Responsive.height(context, 800),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Placeholder image (Flutter logo)
                  Image.network(
                    "https://upload.wikimedia.org/wikipedia/commons/1/17/Google-flutter-logo.png",
                    width: Responsive.width(context, 300),
                    height: Responsive.height(context, 300),
                  ),
                  SizedBox(height: Responsive.height(context, 20)),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.padding(context, 75),
                    ),
                    child: Column(
                      children: [
                        textWithCard(
                          "Hi! I'm Nicholas Dakis, a Computer Science student at CUNY Queens College. I created Level Up! to learn Flutter while creating an app I believed to be useful.",
                          context,
                          Responsive.font(context, 40),
                        ),
                        SizedBox(height: Responsive.height(context, 20)),
                        textWithCard(
                          "Feel free to donate using the button below:",
                          context,
                          Responsive.font(context, 50),
                        ),
                        SizedBox(height: Responsive.height(context, 20)),
                        // PAYPAL DONATE BUTTON
                        Padding(
                          padding: EdgeInsets.all(
                            Responsive.padding(context, 20),
                          ),
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
                                width: Responsive.width(context, 280),
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
      ),
    );
  }
}
