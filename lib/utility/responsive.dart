import 'package:flutter/material.dart';

class Responsive {
  // boolean isDesktop for if other classes ever need it
  static bool isDesktop(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width / size.height > 1.5;
  }

  // Method that scales based on screen type. Context == null assumes mobile scaling (the default, ie baseSize)
  static double scale(BuildContext? context, double baseSize) {
    if (context == null) return baseSize; // fallback for base code (mobile)

    final rawSize = MediaQueryData.fromView(View.of(context)).size;
    bool isDesktop = rawSize.width / rawSize.height > 1.5;

    return isDesktop
        ? baseSize *
              0.85 // slightly smaller on desktop
        : baseSize; // keep base size on mobile
  }

  // Convenience method for font sizes
  static double font(BuildContext? context, double baseFontSize) {
    return scale(context, baseFontSize);
  }

  // Convenience method for button heights
  static double buttonHeight(BuildContext? context, double baseHeight) {
    return scale(context, baseHeight);
  }

  // Convenience method for paddings/margins
  static double padding(BuildContext? context, double basePadding) {
    return scale(context, basePadding);
  }

  // width based on screen width
  static double width(BuildContext context, double baseWidth) {
    final screenWidth = MediaQuery.of(context).size.width;
    bool isDesktop = screenWidth / MediaQuery.of(context).size.height > 1.5;

    double scaledWidth = isDesktop
        ? baseWidth *
              0.85 // slightly smaller on desktop
        : screenWidth * (baseWidth / 400); // mobile scaling

    // clamp so it never exceeds 90% of screen width
    return scaledWidth.clamp(0, screenWidth * 0.9);
  }

  // height based on screen height
  static double height(BuildContext context, double baseHeight) {
    final screenHeight = MediaQuery.of(context).size.height;
    bool isDesktop = MediaQuery.of(context).size.width / screenHeight > 1.5;

    return isDesktop
        ? baseHeight *
              0.85 // slightly smaller on desktop
        : screenHeight * (baseHeight / 800); // mobile scaling
  }
}
