import '../globals.dart';

class UnitConverter {
  // single source of truth for the user's unit preference
  static bool get isImperial => currentUserData?.units == 'imperial';

  // raw weight conversions used when storing or computing deltas
  static double kgToLbs(double kg) => kg * 2.20462;
  static double lbsToKg(double lbs) => lbs / 2.20462;

  // formats a kg value for display, converting to lbs if needed
  static String displayWeight(
    double kg, {
    bool imperial = false,
    int decimals = 1,
  }) {
    final val = imperial ? kgToLbs(kg) : kg;
    return val.toStringAsFixed(decimals);
  }

  // returns the correct weight label for the current unit preference
  static String weightUnit({bool imperial = false}) => imperial ? 'lbs' : 'kg';

  // raw water conversions used when storing or computing totals
  static double mlToOz(double ml) => ml / 29.5735;
  static double ozToMl(double oz) => oz * 29.5735;

  // formats an ml value for display, converting to oz if needed
  static String displayWater(
    int ml, {
    bool imperial = false,
    int decimals = 1,
  }) {
    if (imperial) return mlToOz(ml.toDouble()).toStringAsFixed(decimals);
    return '$ml';
  }

  // returns the correct water label for the current unit preference
  static String waterUnit({bool imperial = false}) => imperial ? 'oz' : 'ml';

  // convenience: value and unit together e.g. "250 ml" or "8.5 oz"
  static String displayWaterWithUnit(int ml, {bool imperial = false}) =>
      '${displayWater(ml, imperial: imperial)} ${waterUnit(imperial: imperial)}';

  // convenience: value and unit together e.g. "73.6 kg" or "162.3 lbs"
  static String displayWeightWithUnit(
    double kg, {
    bool imperial = false,
    int decimals = 1,
  }) =>
      '${displayWeight(kg, imperial: imperial, decimals: decimals)} ${weightUnit(imperial: imperial)}';
}
