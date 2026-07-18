import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import '../globals.dart';
import '../models/food_log.dart';
import '../services/user_data_manager.dart'
    show trackTrivialAchievement, defaultAppColor;
import 'responsive.dart';

class FoodLoggingHelper {
  // Formats a DateTime to the date string key used in food logs (YYYY-MM-DD)
  static String formatDateKey(DateTime date) {
    return "${date.year.toString().padLeft(4, '0')}-"
        "${date.month.toString().padLeft(2, '0')}-"
        "${date.day.toString().padLeft(2, '0')}";
  }

  static int extractCalories(String description) {
    final match = RegExp(
      r'Calories:\s*(\d+)kcal',
      caseSensitive: false,
    ).firstMatch(description);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }

  // Converts a raw API result map to FoodLog, injecting date and meal since the API doesn't return them
  static FoodLog foodLogFromApiMap(
    Map<String, dynamic> map, {
    required String date,
    required String meal,
  }) => FoodLog.fromJson({...map, 'date': date, 'meal': meal});

  // Takes the "Per ..." from food_description and parses it into {amount, unit}
  static Map<String, dynamic> parseServingFromLog(FoodLog food) =>
      parseServing(food.foodDescription ?? '');

  static Map<String, dynamic> parseServing(String description) {
    // Regular expression to find the amount and units
    final perMatch = RegExp(
      r'Per\s+(.+?)\s*-',
    ).firstMatch(description); // food_description parses as "Per xxx -"
    if (perMatch == null) {
      return {'amount': 1.0, 'unit': 'serving'}; // fallback if none was found
    }

    // token is the "xxx" part of "Per xxx"
    final token = perMatch.group(1)!.trim();
    // Regular expression to separate the amount and units in the serving size
    final numUnitMatch = RegExp(
      r'^(\d+(?:/\d+)?(?:\.\d+)?)\s*(.+)$',
    ).firstMatch(token);
    if (numUnitMatch != null) {
      return {
        'amount': _parseFraction(numUnitMatch.group(1)!),
        'unit': numUnitMatch.group(2)!.trim(),
      };
    }
    return {'amount': 1.0, 'unit': token}; // fallback
  }

  // Method that converts fractional serving sizes into a decimal
  static double _parseFraction(String value) {
    if (value.contains('/')) {
      final parts = value.split('/');
      final denominator = double.tryParse(parts[1]) ?? 1;
      if (denominator == 0) return 0;
      return double.parse(
        ((double.tryParse(parts[0]) ?? 0) / denominator).toStringAsFixed(2),
      );
    }
    return double.tryParse(value) ?? 1.0; // fallback
  }

  // Extracts macros from a FoodLog, reading typed fields first and falling back to parsing food_description
  static Map<String, double> extractMacrosFromFood(FoodLog food) {
    final hasDirectKeys =
        food.protein != null || food.carbs != null || food.fat != null;
    if (hasDirectKeys) {
      return {
        'calories': (food.calories ?? 0).toDouble(),
        'fat': food.fat ?? 0,
        'carbs': food.carbs ?? 0,
        'protein': food.protein ?? 0,
        'fiber': food.fiber ?? 0,
        'sugar': food.sugar ?? 0,
        'sodium': food.sodium ?? 0,
      };
    }
    // Fall back to parsing food_description string for legacy food items without direct keys
    final desc = food.foodDescription ?? '';
    double extract(String label) {
      final match = RegExp(
        '$label:\\s*([\\d.]+)',
        caseSensitive: false,
      ).firstMatch(desc);
      return double.tryParse(match?.group(1) ?? '') ?? 0;
    }

    return {
      'calories': extract('Calories'),
      'fat': extract('Fat'),
      'carbs': extract('Carbs'),
      'protein': extract('Protein'),
    };
  }

  // Method that automatically scales the nutritional information of food with serving size changes
  static Map<String, double> scaleFood(
    Map<String, double> base,
    double baseAmt,
    double newAmt,
  ) {
    if (baseAmt == 0) return base;
    final ratio = newAmt / baseAmt;
    // in (k, v) k is the nutritional field (calories, protein...) and v is its value
    return base.map(
      (k, v) => MapEntry(k, double.parse((v * ratio).toStringAsFixed(2))),
    );
  }

  // Method so food info is all formatted like fatSecret's (originally that was the only tab in Food Logging so it was built with that in mind)
  static String buildDescription(
    Map<String, double> macros,
    double amount,
    String unit,
  ) {
    final amountStr = amount % 1 == 0
        ? amount.toInt().toString()
        : amount.toString();
    return 'Per $amountStr $unit - Calories: ${macros['calories']!.round()}kcal'
        ' | Fat: ${macros['fat']!.toStringAsFixed(2)}g'
        ' | Carbs: ${macros['carbs']!.toStringAsFixed(2)}g'
        ' | Protein: ${macros['protein']!.toStringAsFixed(2)}g';
  }

  // Method to format the time displayed to the user when the fatSecret API calls have been maxed out
  static String formatDuration(String rawTime) {
    final parts = rawTime.split('.')[0].split(':');
    final hours = int.parse(parts[0]);
    final minutes = int.parse(parts[1]);
    final seconds = int.parse(parts[2]);

    if (hours == 0 && minutes == 0 && seconds == 0) return "0 seconds";

    String plural(int n, String unit) => "$n $unit${n == 1 ? '' : 's'}";
    final segments = <String>[
      if (hours > 0) plural(hours, 'hour'),
      if (minutes > 0) plural(minutes, 'minute'),
      if (seconds > 0) plural(seconds, 'second'),
    ];
    if (segments.length == 1) return segments.first;
    return '${segments.take(segments.length - 1).join(', ')}, and ${segments.last}';
  }
}

// Calculator icon button for serving size fields
// onSet is called after the result is pasted in to trigger any recalculating food details based on the new amount
Widget calcSuffixIcon(
  BuildContext context,
  TextEditingController controller, {
  VoidCallback? onSet,
  Color? color,
}) {
  return GestureDetector(
    onTap: () async {
      final result = await showCalcDialog(
        context,
        initialValue: controller.text.trim(),
        appColor: color,
      );
      if (result != null) {
        // clamp to 99999 to match the 5-digit cap on the text field formatter
        final clamped = (double.tryParse(result) ?? 0).clamp(0, 99999);
        final clampedStr = clamped % 1 == 0
            ? clamped.toInt().toString()
            : clamped.toStringAsFixed(2);
        controller.text = clampedStr;
        controller.selection = TextSelection.collapsed(
          offset: clampedStr
              .length, // move cursor to end so it doesn't look selected
        );
        onSet
            ?.call(); // trigger recalculation since setting text programmatically doesn't fire onChanged
      }
    },
    child: Padding(
      padding: EdgeInsets.all(Responsive.scale(context, 8)),
      child: HugeIcon(
        icon: HugeIcons.strokeRoundedCalculator,
        color: color ?? lightenColor(defaultAppColor, 0.35),
        size: Responsive.scale(context, 18),
      ),
    ),
  );
}

// Opens a calculator dialog so the user can do quick math quickly
Future<String?> showCalcDialog(
  BuildContext context, {
  String initialValue = '',
  Color? appColor,
}) {
  trackTrivialAchievement(
    'serving_calculator',
  ); // fire once each time the calc is opened
  String expression = initialValue; // tracks the raw input string (e.g. "35x7")
  String display = initialValue.isNotEmpty
      ? initialValue
      : '0'; // show existing value instead of defaulting to 0

  // operator buttons get a tinted color to stand out from digit buttons
  final buttons = [
    ['7', '8', '9', '÷'],
    ['4', '5', '6', '×'],
    ['1', '2', '3', '-'],
    ['C', '0', '.', '+'],
  ];

  return showFrostedDialog<String>(
    context: context,
    appColor: appColor ?? defaultAppColor,
    child: StatefulBuilder(
      builder: (context, setState) {
        void press(String val) {
          setState(() {
            if (val == '⌫') {
              // remove the last character from the expression
              if (expression.isNotEmpty) {
                expression = expression.substring(0, expression.length - 1);
                display = expression.isEmpty ? '0' : expression;
              }
            } else if (val == 'C') {
              // clear resets both the display and the running expression
              expression = '';
              display = '0';
            } else if (val == '=') {
              try {
                // swap display symbols to actual operators before evaluating
                final expr = expression
                    .replaceAll('×', '*')
                    .replaceAll('÷', '/');
                // regex splits between a digit and an operator in both directions
                // so "12+3*4" becomes ["12", "+", "3", "*", "4"]
                final tokens = expr.split(
                  RegExp(r'(?<=[0-9.])(?=[+\-*/])|(?<=[+\-*/])(?=[0-9.])'),
                );
                // separate into two parallel lists
                final nums = <double>[];
                final ops = <String>[];
                for (final t in tokens) {
                  if (t == '+' || t == '-' || t == '*' || t == '/') {
                    ops.add(t);
                  } else {
                    nums.add(double.parse(t));
                  }
                }
                // pass 1: collapse * and / in place so they take precedence over + and -
                int i = 0;
                while (i < ops.length) {
                  if (ops[i] == '*' || ops[i] == '/') {
                    if (ops[i] == '/' && nums[i + 1] == 0) throw Exception();
                    final res = ops[i] == '*'
                        ? nums[i] * nums[i + 1]
                        : nums[i] / nums[i + 1];
                    nums[i] = res; // overwrite left operand with result
                    nums.removeAt(i + 1); // right operand is absorbed
                    ops.removeAt(i); // operator is consumed
                  } else {
                    i++; // skip + and -
                  }
                }
                // pass 2: only + and - are left
                double result = nums[0];
                for (int j = 0; j < ops.length; j++) {
                  if (ops[j] == '+') {
                    result += nums[j + 1];
                  } else if (ops[j] == '-') {
                    result -= nums[j + 1];
                  }
                }
                if (result < 0) result = 0; // serving sizes can't be negative
                // drop the trailing .0 if the result is a whole number
                display = result % 1 == 0
                    ? result.toInt().toString()
                    : result.toStringAsFixed(2);
                expression =
                    display; // so pressing = again doesn't re-evaluate the old expression
              } catch (_) {
                display = 'Error';
                expression = '';
              }
            } else {
              expression += val;
              display = expression;
            }
          });
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Calculator",
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(context, 20),
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            SizedBox(height: Responsive.height(context, 16)),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.width(context, 12),
                vertical: Responsive.height(context, 10),
              ),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(15),
                borderRadius: BorderRadius.circular(
                  Responsive.scale(context, 10),
                ),
                border: Border.all(
                  color: Colors.white.withAlpha(40),
                  width: Responsive.width(context, 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      display,
                      textAlign: TextAlign.right,
                      style: GoogleFonts.manrope(
                        fontSize: Responsive.font(context, 24),
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(width: Responsive.width(context, 8)),
                  GestureDetector(
                    onTap: () => press('⌫'),
                    child: Icon(
                      Icons.backspace_outlined,
                      color: Colors.white38,
                      size: Responsive.scale(context, 18),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: Responsive.height(context, 12)),
            for (final row in buttons)
              Padding(
                padding: EdgeInsets.only(bottom: Responsive.height(context, 8)),
                child: Row(
                  children: [
                    for (final btn in row) ...[
                      Expanded(
                        child: GestureDetector(
                          onTap: () => press(btn),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              vertical: Responsive.height(context, 12),
                            ),
                            margin: EdgeInsets.symmetric(
                              horizontal: Responsive.width(context, 3),
                            ),
                            decoration: BoxDecoration(
                              color: ['+', '-', '×', '÷'].contains(btn)
                                  ? lightenColor(
                                      appColor ?? defaultAppColor,
                                      0.1,
                                    ).withAlpha(80)
                                  : Colors.white.withAlpha(20),
                              borderRadius: BorderRadius.circular(
                                Responsive.scale(context, 8),
                              ),
                            ),
                            child: Text(
                              btn,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.manrope(
                                fontSize: Responsive.font(
                                  context,
                                  ['+', '-', '×', '÷'].contains(btn) ? 22 : 16,
                                ),
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            SizedBox(height: Responsive.height(context, 4)),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        vertical: Responsive.height(context, 12),
                      ),
                      margin: EdgeInsets.symmetric(
                        horizontal: Responsive.width(context, 3),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(20),
                        borderRadius: BorderRadius.circular(
                          Responsive.scale(context, 8),
                        ),
                      ),
                      child: Text(
                        "Cancel",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 16),
                          color: Colors.white54,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => press('='),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        vertical: Responsive.height(context, 12),
                      ),
                      margin: EdgeInsets.symmetric(
                        horizontal: Responsive.width(context, 3),
                      ),
                      decoration: BoxDecoration(
                        color: lightenColor(
                          appColor ?? defaultAppColor,
                          0.1,
                        ).withAlpha(80),
                        borderRadius: BorderRadius.circular(
                          Responsive.scale(context, 8),
                        ),
                      ),
                      child: Text(
                        "=",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 16),
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      press('=');
                      Navigator.pop(
                        context,
                        display != 'Error' ? display : null,
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        vertical: Responsive.height(context, 12),
                      ),
                      margin: EdgeInsets.symmetric(
                        horizontal: Responsive.width(context, 3),
                      ),
                      decoration: BoxDecoration(
                        color: lightenColor(
                          appColor ?? defaultAppColor,
                          0.2,
                        ).withAlpha(120),
                        borderRadius: BorderRadius.circular(
                          Responsive.scale(context, 8),
                        ),
                      ),
                      child: Text(
                        "Set",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: Responsive.font(context, 16),
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );
}

// Return type for showServingAmountDialog: the serving amount string plus optional user-overridden macros.
typedef ServingDialogResult = ({
  String amt,
  Map<String, double>? macroOverrides,
  bool keepLogging,
});

// Shared serving-size dialog used by both the log-food and edit-serving flows.
Future<ServingDialogResult?> showServingAmountDialog({
  required BuildContext context,
  required FoodLog food,
  required TextEditingController controller,
  required String confirmLabel,
  Color? appColor,
  bool showLogMore = false,
}) {
  final serving = FoodLoggingHelper.parseServingFromLog(food);
  final baseAmt = serving['amount'] as double;
  final unit = serving['unit'] as String;
  final baseMacros = FoodLoggingHelper.extractMacrosFromFood(food);
  final accent = lightenColor(appColor ?? defaultAppColor, 0.45);
  final dim = lightenColor(appColor ?? defaultAppColor, 0.35);

  // Which macro is currently being edited (null = none)
  String? activeKey;
  // User-typed override values, keyed by macro name
  final Map<String, double> overrides = {};
  // Single controller reused for whichever macro is active
  final activeController = TextEditingController();

  Widget macroChip(
    BuildContext ctx,
    String key,
    String label,
    double value,
    void Function(void Function()) setDialogState, {
    String? unit,
    bool isNone = false,
  }) {
    final isCalories = key == 'calories';
    final suffix = unit ?? (isCalories ? 'kcal' : 'g');
    final displayValue = overrides[key] ?? value;
    final valueStr = isNone && !overrides.containsKey(key)
        ? 'None'
        : isCalories
        ? '${displayValue.round()}'
        : displayValue.toStringAsFixed(1);

    if (activeKey == key) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: Responsive.width(ctx, 52),
            child: TextField(
              controller: activeController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                TextInputFormatter.withFunction((old, val) {
                  if (val.text.isEmpty) return val;
                  return RegExp(r'^\d{0,5}(\.\d{0,2})?$').hasMatch(val.text)
                      ? val
                      : old;
                }),
              ],
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: accent,
                fontSize: Responsive.font(ctx, 14),
                fontWeight: FontWeight.w700,
              ),
              onChanged: (val) {
                final v = double.tryParse(val);
                if (v != null) overrides[key] = v;
              },
              onSubmitted: (_) => setDialogState(() => activeKey = null),
              decoration: InputDecoration(
                isDense: true,
                suffixText: suffix,
                suffixStyle: GoogleFonts.manrope(
                  color: dim,
                  fontSize: Responsive.font(ctx, 10),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Responsive.scale(ctx, 8)),
                  borderSide: BorderSide(color: dim.withAlpha(80)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Responsive.scale(ctx, 8)),
                  borderSide: BorderSide(color: accent, width: 1.5),
                ),
              ),
            ),
          ),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: Responsive.font(ctx, 11),
              color: dim,
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: () => setDialogState(() {
        activeKey = key;
        activeController.text = valueStr;
      }),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                valueStr == 'None' ? 'None' : '$valueStr$suffix',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: Responsive.font(ctx, 15),
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
              SizedBox(width: Responsive.width(ctx, 3)),
              Icon(Icons.edit, size: Responsive.scale(ctx, 14), color: dim),
            ],
          ),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: Responsive.font(ctx, 11),
              color: dim,
            ),
          ),
        ],
      ),
    );
  }

  return showFrostedDialog<ServingDialogResult>(
    context: context,
    appColor: appColor ?? defaultAppColor,
    child: StatefulBuilder(
      builder: (ctx, setDialogState) {
        final typedAmt = double.tryParse(controller.text) ?? baseAmt;
        final scaled = FoodLoggingHelper.scaleFood(
          baseMacros,
          baseAmt,
          typedAmt,
        );

        Widget microChip(
          String key,
          String label,
          double value,
          bool isNone,
          String unit,
        ) {
          final displayValue = overrides[key] ?? value;
          final displayStr = isNone
              ? 'None'
              : '${displayValue.toStringAsFixed(1)}$unit';
          if (activeKey == key) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: Responsive.width(ctx, 46),
                  child: TextField(
                    controller: activeController,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      color: dim,
                      fontSize: Responsive.font(ctx, 12),
                      fontWeight: FontWeight.w600,
                    ),
                    onChanged: (val) {
                      final v = double.tryParse(val);
                      if (v != null) overrides[key] = v;
                    },
                    onSubmitted: (_) => setDialogState(() => activeKey = null),
                    decoration: InputDecoration(
                      isDense: true,
                      suffixText: unit,
                      suffixStyle: GoogleFonts.manrope(
                        color: dim,
                        fontSize: Responsive.font(ctx, 9),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          Responsive.scale(ctx, 8),
                        ),
                        borderSide: BorderSide(color: dim.withAlpha(80)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          Responsive.scale(ctx, 8),
                        ),
                        borderSide: BorderSide(color: dim, width: 1.5),
                      ),
                    ),
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.manrope(
                    fontSize: Responsive.font(ctx, 10),
                    color: dim,
                  ),
                ),
              ],
            );
          }
          return GestureDetector(
            onTap: () => setDialogState(() {
              activeKey = key;
              activeController.text = isNone
                  ? ''
                  : displayValue.toStringAsFixed(1);
            }),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayStr,
                      style: GoogleFonts.manrope(
                        fontSize: Responsive.font(ctx, 12),
                        fontWeight: FontWeight.w600,
                        color: dim,
                      ),
                    ),
                    SizedBox(width: Responsive.width(ctx, 2)),
                    Icon(
                      Icons.edit,
                      size: Responsive.scale(ctx, 11),
                      color: dim.withAlpha(140),
                    ),
                  ],
                ),
                Text(
                  label,
                  style: GoogleFonts.manrope(
                    fontSize: Responsive.font(ctx, 10),
                    color: dim,
                  ),
                ),
              ],
            ),
          );
        }

        final cal = (overrides['calories'] ?? scaled['calories'] ?? 0).round();
        final protein = overrides['protein'] ?? scaled['protein'] ?? 0.0;
        final carbs = overrides['carbs'] ?? scaled['carbs'] ?? 0.0;
        final fat = overrides['fat'] ?? scaled['fat'] ?? 0.0;
        final ratio = typedAmt / baseAmt;
        final fiber = food.fiber != null ? food.fiber! * ratio : 0.0;
        final sugar = food.sugar != null ? food.sugar! * ratio : 0.0;
        final sodium = food.sodium != null ? food.sodium! * ratio : 0.0;
        final fiberIsNone =
            food.fiber == null && !overrides.containsKey('fiber');
        final sugarIsNone =
            food.sugar == null && !overrides.containsKey('sugar');
        final sodiumIsNone =
            food.sodium == null && !overrides.containsKey('sodium');

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              food.foodName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: Responsive.font(ctx, 18),
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
            if (food.brandName != null)
              Text(
                food.brandName!,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: Responsive.font(ctx, 12),
                  color: dim,
                ),
              ),
            SizedBox(height: Responsive.height(ctx, 16)),
            macroChip(ctx, 'calories', 'kcal', cal.toDouble(), setDialogState),
            SizedBox(height: Responsive.height(ctx, 8)),
            Row(
              children: [
                Expanded(
                  child: macroChip(
                    ctx,
                    'protein',
                    'protein',
                    protein,
                    setDialogState,
                  ),
                ),
                Expanded(
                  child: macroChip(
                    ctx,
                    'carbs',
                    'carbs',
                    carbs,
                    setDialogState,
                  ),
                ),
                Expanded(
                  child: macroChip(ctx, 'fat', 'fat', fat, setDialogState),
                ),
              ],
            ),
            SizedBox(height: Responsive.height(ctx, 4)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                microChip('fiber', 'Fiber', fiber, fiberIsNone, 'g'),
                microChip('sugar', 'Sugar', sugar, sugarIsNone, 'g'),
                microChip('sodium', 'Sodium', sodium, sodiumIsNone, 'mg'),
              ],
            ),
            SizedBox(height: Responsive.height(ctx, 16)),
            TextField(
              controller: controller,
              autofocus: false,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                TextInputFormatter.withFunction((old, val) {
                  if (val.text.isEmpty) return val;
                  return RegExp(r'^\d{0,5}(\.\d{0,2})?$').hasMatch(val.text)
                      ? val
                      : old;
                }),
              ],
              style: GoogleFonts.manrope(
                color: accent,
                fontSize: Responsive.font(ctx, 20),
                fontWeight: FontWeight.w700,
              ),
              onChanged: (_) => setDialogState(() {}),
              decoration: InputDecoration(
                labelText: 'Serving size',
                labelStyle: GoogleFonts.manrope(
                  color: dim,
                  fontSize: Responsive.font(ctx, 12),
                ),
                suffixText: unit,
                suffixStyle: GoogleFonts.manrope(color: dim),
                suffixIcon: calcSuffixIcon(
                  ctx,
                  controller,
                  color: dim,
                  onSet: () => setDialogState(() {}),
                ),
                filled: true,
                fillColor: Colors.white.withAlpha(12),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: Responsive.width(ctx, 16),
                  vertical: Responsive.height(ctx, 14),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    Responsive.scale(ctx, 12),
                  ),
                  borderSide: BorderSide(color: dim.withAlpha(80)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    Responsive.scale(ctx, 12),
                  ),
                  borderSide: BorderSide(color: accent, width: 1.5),
                ),
              ),
            ),
            SizedBox(height: Responsive.height(ctx, 20)),
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (showLogMore)
                      TextButton(
                        onPressed: () =>
                            Navigator.of(ctx, rootNavigator: true).pop((
                              amt: controller.text.trim(),
                              macroOverrides: overrides.isEmpty
                                  ? null
                                  : Map<String, double>.from(overrides),
                              keepLogging: true,
                            )),
                        child: Text(
                          "Log More",
                          style: dialogButtonStyle(confirm: true),
                        ),
                      )
                    else
                      TextButton(
                        onPressed: () =>
                            Navigator.of(ctx, rootNavigator: true).pop(),
                        child: Text("Cancel", style: dialogButtonStyle()),
                      ),
                    TextButton(
                      onPressed: () =>
                          Navigator.of(ctx, rootNavigator: true).pop((
                            amt: controller.text.trim(),
                            macroOverrides: overrides.isEmpty
                                ? null
                                : Map<String, double>.from(overrides),
                            keepLogging: false,
                          )),
                      child: Text(
                        confirmLabel,
                        style: dialogButtonStyle(confirm: true),
                      ),
                    ),
                  ],
                ),
                if (showLogMore)
                  TextButton(
                    onPressed: () =>
                        Navigator.of(ctx, rootNavigator: true).pop(),
                    child: Text("Cancel", style: dialogButtonStyle()),
                  ),
              ],
            ),
          ],
        );
      },
    ),
  );
}
