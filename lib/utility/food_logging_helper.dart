import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import '../globals.dart';
import 'responsive.dart';

class FoodLoggingHelper {
  // Method that puts DateTime objects in the form that foodDataByDate expects
  static String formatDateKey(DateTime date) {
    return "${date.year.toString().padLeft(4, '0')}-"
        "${date.month.toString().padLeft(2, '0')}-"
        "${date.day.toString().padLeft(2, '0')}";
  }

  // Make sure the food list is always a list of maps even when data is null
  static List<Map<String, dynamic>> castFoodList(dynamic raw) =>
      (raw as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

  static int extractCalories(String description) {
    final match = RegExp(
      r'Calories:\s*(\d+)kcal',
      caseSensitive: false,
    ).firstMatch(description);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }

  // Takes the "Per ..." from food_description and parses it into {amount, unit}
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

  static Map<String, double> extractMacros(String description) {
    double extract(String label) {
      final match = RegExp(
        '$label:\\s*([\\d.]+)',
        caseSensitive: false,
      ).firstMatch(description);
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
Widget calcSuffixIcon(BuildContext context, TextEditingController controller) {
  return GestureDetector(
    onTap: () async {
      final result = await showCalcDialog(
        context,
        initialValue: controller.text.trim(),
      );
      if (result != null) {
        controller.text = result;
        controller.selection = TextSelection.collapsed(
          offset:
              result.length, // move cursor to end so it doesn't look selected
        );
      }
    },
    child: Padding(
      padding: EdgeInsets.all(Responsive.scale(context, 8)),
      child: HugeIcon(
        icon: HugeIcons.strokeRoundedCalculator,
        color: Colors.white38,
        size: Responsive.scale(context, 18),
      ),
    ),
  );
}

// Opens a calculator dialog so the user can do quick math quickly
Future<String?> showCalcDialog(
  BuildContext context, {
  String initialValue = '',
}) {
  String expression = initialValue; // tracks the raw input string (e.g. "35x7")
  String display = initialValue.isNotEmpty
      ? initialValue
      : '0'; // show existing value instead of defaulting to 0

  // operator buttons get a tinted color to stand out from digit buttons
  final buttons = [
    ['7', '8', '9', '÷'],
    ['4', '5', '6', '×'],
    ['1', '2', '3', '-'],
    ['Clear', '0', '.', '+'],
  ];

  return showFrostedDialog<String>(
    context: context,
    child: StatefulBuilder(
      builder: (context, setState) {
        void press(String val) {
          setState(() {
            if (val == 'Clear') {
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
              ),
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
                                      appColorNotifier.value,
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
                                fontSize: Responsive.font(context, 16),
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
                          appColorNotifier.value,
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
                          appColorNotifier.value,
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
