import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/globals.dart';
import '/utility/responsive.dart';

// Tutorial screen for installing the app as a PWA on browsers that don't support
// the automatic install prompt (Safari, Firefox, etc.)
class InstallGuide extends StatelessWidget {
  const InstallGuide({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: buildThemeGradient()),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: darkenColor(appColorNotifier.value, 0.025),
          centerTitle: true,
          toolbarHeight: Responsive.height(context, 100),
          title: createTitle("Install App", context),
        ),
        body: Center(
          child: Text(
            "Coming soon",
            style: GoogleFonts.manrope(
              fontSize: Responsive.font(context, 16),
              color: Colors.white38,
            ),
          ),
        ),
      ),
    );
  }
}
