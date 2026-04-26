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
