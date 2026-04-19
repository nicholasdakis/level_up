import 'package:flutter/material.dart';

enum ScreenType { mobile, tablet, desktop }

class Responsive {
  static const double _baseScreenWidth = 400;
  static const double _baseScreenHeight = 800;

  // Scale factors applied on top of proportional scaling
  static const double _tabletScale = 0.90;
  static const double _desktopScale = 0.85;

  // Breakpoints
  static const double _tabletBreakpoint = 600;
  static const double _desktopBreakpoint = 1024;

  // Font clamps
  static const double _minFontSize = 10;
  static const double _maxFontSize = 40;

  // Method that calculates the user's screen type
  static ScreenType screenType(BuildContext context) {
    final width = _safeSize(context).width;
    if (width < _tabletBreakpoint) return ScreenType.mobile;
    if (width < _desktopBreakpoint) return ScreenType.tablet;
    return ScreenType.desktop;
  }

  // Screen detection booleans
  static bool isMobile(BuildContext context) {
    return screenType(context) == ScreenType.mobile;
  }

  static bool isTablet(BuildContext context) {
    return screenType(context) == ScreenType.tablet;
  }

  static bool isDesktop(BuildContext context) {
    return screenType(context) == ScreenType.desktop;
  }

  // Returns the screen size safely with a fallback if the size is somehow <= 0
  static Size _safeSize(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (size.width <= 0 || size.height <= 0) {
      return const Size(_baseScreenWidth, _baseScreenHeight);
    }
    return size;
  }

  // Returns the scale factor for the current screen type
  static double _scaleFactor(ScreenType type) {
    switch (type) {
      case ScreenType.mobile:
        return 1.0;
      case ScreenType.tablet:
        return _tabletScale;
      case ScreenType.desktop:
        return _desktopScale;
    }
  }

  // Mobile: proportional to screen size relative to base dimensions.
  // Tablet/Desktop: proportional scaling with a scale factor applied on top.
  static double _scaleValue({
    required double base,
    required double screenDimension,
    required double baseDimension,
    required ScreenType type,
    double? clampMin,
    double? clampMax,
  }) {
    final scaled = type == ScreenType.mobile
        ? screenDimension * (base / baseDimension)
        : base * _scaleFactor(type);

    if (clampMin != null || clampMax != null) {
      return scaled.clamp(
        clampMin ?? double.negativeInfinity,
        clampMax ?? double.infinity,
      );
    }
    return scaled;
  }

  // Clamped to 90% of screen width so nothing ever overflows
  static double width(BuildContext context, double baseWidth) {
    final size = _safeSize(context);
    return _scaleValue(
      base: baseWidth,
      screenDimension: size.width,
      baseDimension: _baseScreenWidth,
      type: screenType(context),
      clampMin: 0,
      clampMax: size.width * 0.9,
    );
  }

  // Clamped to 90% of screen height
  static double height(BuildContext context, double baseHeight) {
    final size = _safeSize(context);
    return _scaleValue(
      base: baseHeight,
      screenDimension: size.height,
      baseDimension: _baseScreenHeight,
      type: screenType(context),
      clampMin: 0,
      clampMax: size.height * 0.9,
    );
  }

  // Scales a button height against screen width
  static double buttonHeight(BuildContext context, double baseHeight) {
    final type = screenType(context);
    return type == ScreenType.mobile
        ? baseHeight
        : baseHeight * _scaleFactor(type);
  }

  static double font(BuildContext context, double baseFontSize) {
    final type = screenType(context);
    final scaled = type == ScreenType.mobile
        ? baseFontSize
        : baseFontSize * _scaleFactor(type);
    return scaled.clamp(_minFontSize, _maxFontSize);
  }

  // Scales a padding or margin value
  static double padding(BuildContext context, double basePadding) {
    final size = _safeSize(context);
    return _scaleValue(
      base: basePadding,
      screenDimension: size.width,
      baseDimension: _baseScreenWidth,
      type: screenType(context),
      clampMin: 0,
    );
  }

  // Generic scaling method
  static double scale(BuildContext context, double baseSize) {
    final size = _safeSize(context);
    return _scaleValue(
      base: baseSize,
      screenDimension: size.width,
      baseDimension: _baseScreenWidth,
      type: screenType(context),
      clampMin: 0,
    );
  }
}
