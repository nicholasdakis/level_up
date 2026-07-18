import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

Color darkenColor(Color color, [double amount = .1]) {
  final hsl = HSLColor.fromColor(color);
  final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
  return hslDark.toColor();
}

Color lightenColor(Color color, [double amount = .1]) {
  final hsl = HSLColor.fromColor(color);
  final hslLight = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
  return hslLight.toColor();
}

// sRGB gamma expansion (IEC 61966-2-1)
double _linearize(double c) =>
    c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4).toDouble();

// Relative luminance per WCAG 2.x, correctly weights red/green/blue for human vision
double _relativeLuminance(Color c) {
  final r = _linearize((c.r * 255).round() / 255);
  final g = _linearize((c.g * 255).round() / 255);
  final b = _linearize((c.b * 255).round() / 255);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

// Convert sRGB Color to Oklab [L, a, b]
// Oklab is perceptually uniform: equal L steps look equal to the eye on any hue
List<double> _toOklab(Color c) {
  final r = _linearize((c.r * 255).round() / 255);
  final g = _linearize((c.g * 255).round() / 255);
  final b = _linearize((c.b * 255).round() / 255);
  final l = pow(
    0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b,
    1 / 3,
  ).toDouble();
  final m = pow(
    0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b,
    1 / 3,
  ).toDouble();
  final s = pow(
    0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b,
    1 / 3,
  ).toDouble();
  return [
    0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
    1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
    0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
  ];
}

// Convert Oklab [L, a, b] to sRGB Color, clamping to valid range
Color _fromOklab(List<double> lab) {
  final l = lab[0], a = lab[1], b = lab[2];
  final lc = l + 0.3963377774 * a + 0.2158037573 * b;
  final mc = l - 0.1055613458 * a - 0.0638541728 * b;
  final sc = l - 0.0894841775 * a - 1.2914855480 * b;
  final ll = lc * lc * lc, mm = mc * mc * mc, ss = sc * sc * sc;
  double toSrgb(double x) {
    final linear = x <= 0.0031308
        ? 12.92 * x
        : 1.055 * pow(x.clamp(0.0, 1.0), 1 / 2.4) - 0.055;
    return linear.clamp(0.0, 1.0);
  }

  return Color.from(
    alpha: 1.0,
    red: toSrgb(4.0767416621 * ll - 3.3077115913 * mm + 0.2309699292 * ss),
    green: toSrgb(-1.2684380046 * ll + 2.6097574011 * mm - 0.3413193965 * ss),
    blue: toSrgb(-0.0041960863 * ll - 0.7034186147 * mm + 1.7076147010 * ss),
  );
}

// Shift a color's Oklab L channel by [amount] (positive = lighter, negative = darker)
Color _oklabShift(Color color, double amount) {
  final lab = _toOklab(color);
  lab[0] = (lab[0] + amount).clamp(0.0, 1.0);
  return _fromOklab(lab);
}

// Primary text/icon color for a given theme color
// Returns near-white on dark themes, dark tinted on light themes
// Use everywhere instead of hardcoded Colors.white or lightenColor(appColor, 0.45) for text
Color onTheme(Color base) {
  final lum = _relativeLuminance(base);
  if (lum < 0.18) return lightenColor(base, 0.45); // dark theme: light text
  if (lum < 0.40) return Colors.white; // medium theme: pure white reads cleanly
  return darkenColor(base, 0.40); // light theme: dark tinted text
}

// Button gradient colors: brighter/more saturated than card colors so the button stands out
({
  List<Color> gradient,
  Color border,
  Color label, // text/icon color on the button surface
})
buttonColors(Color base) {
  final isDark = _relativeLuminance(base) < 0.18;
  return (
    gradient: isDark
        ? [_oklabShift(base, 0.32), _oklabShift(base, 0.10)]
        : [_oklabShift(base, -0.04), _oklabShift(base, -0.14)],
    border: isDark
        ? _oklabShift(base, 0.35).withAlpha(180)
        : _oklabShift(base, -0.14).withAlpha(180),
    label: Colors.white,
  );
}

// Consistent card surface colors using perceptually uniform Oklab shifts
// Branches on relative luminance (not HSL lightness) so red/pink/purple are handled correctly
({
  List<Color> gradient,
  Color border,
  Color iconBox,
  Color iconBorder,
  Color splashColor,
  Color highlightColor,
  Color onCard, // text and icon color that stays readable on the card surface
})
cardColors(Color base) {
  // Relative luminance correctly identifies red (~0.06) as dark even though HSL calls it mid-tone
  final isDark = _relativeLuminance(base) < 0.18;
  return (
    gradient: isDark
        ? [_oklabShift(base, 0.15), _oklabShift(base, 0.10)]
        : [_oklabShift(base, -0.08), _oklabShift(base, -0.05)],
    border: isDark
        ? _oklabShift(base, 0.20).withAlpha(180)
        : _oklabShift(base, -0.22).withAlpha(220),
    iconBox: isDark ? _oklabShift(base, 0.20) : _oklabShift(base, -0.08),
    iconBorder: isDark
        ? _oklabShift(base, 0.30).withAlpha(180)
        : _oklabShift(base, -0.30).withAlpha(220),
    splashColor: isDark
        ? _oklabShift(base, 0.25).withAlpha(60)
        : _oklabShift(base, -0.20).withAlpha(60),
    highlightColor: isDark
        ? _oklabShift(base, 0.25).withAlpha(30)
        : _oklabShift(base, -0.20).withAlpha(30),
    onCard: onTheme(base),
  );
}

// Shared text style for dialog cancel/confirm buttons
TextStyle dialogButtonStyle({bool confirm = false}) => GoogleFonts.manrope(
  color: confirm ? Colors.white : Colors.white60,
  fontWeight: confirm ? FontWeight.w700 : FontWeight.w500,
);

// Reusable gradient for title and button text
LinearGradient subtleTextGradient(Color appColor) {
  return LinearGradient(
    colors: [
      lightenColor(appColor, 0.45),
      lightenColor(appColor, 0.50),
      lightenColor(appColor, 0.45),
    ],
  );
}

// Returns a flat solid background using the chosen theme color
Gradient buildThemeGradient(Color color) {
  return LinearGradient(colors: [color, color]);
}
