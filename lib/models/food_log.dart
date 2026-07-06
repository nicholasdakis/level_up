// TODO: migrate screens to use FoodLog directly instead of Map<String, dynamic> and update FoodLoggingHelper accordingly
class FoodLog {
  final String? id;
  final String date;
  final String meal;
  final String foodName;
  final String? brandName;
  final String? foodDescription;
  final int? calories;
  final double? protein;
  final double? carbs;
  final double? fat;
  final double? fiber;
  final double? sugar;
  final double? sodium;
  final String? servingSize;
  final String? loggedAt;

  FoodLog({
    this.id,
    required this.date,
    required this.meal,
    required this.foodName,
    this.brandName,
    this.foodDescription,
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
    this.fiber,
    this.sugar,
    this.sodium,
    this.servingSize,
    this.loggedAt,
  });

  factory FoodLog.fromJson(Map<String, dynamic> json) {
    return FoodLog(
      id: json['id'] as String?,
      date: json['date'] as String,
      meal: json['meal'] as String,
      foodName: json['food_name'] as String? ?? '',
      brandName: json['brand_name'] as String?,
      foodDescription: json['food_description'] as String?,
      calories: json['calories'] != null
          ? (num.tryParse(json['calories'].toString()) ?? 0).toInt()
          : null,
      protein: json['protein'] != null
          ? (num.tryParse(json['protein'].toString()) ?? 0).toDouble()
          : null,
      carbs: json['carbs'] != null
          ? (num.tryParse(json['carbs'].toString()) ?? 0).toDouble()
          : null,
      fat: json['fat'] != null
          ? (num.tryParse(json['fat'].toString()) ?? 0).toDouble()
          : null,
      fiber: json['fiber'] != null
          ? (num.tryParse(json['fiber'].toString()) ?? 0).toDouble()
          : null,
      sugar: json['sugar'] != null
          ? (num.tryParse(json['sugar'].toString()) ?? 0).toDouble()
          : null,
      sodium: json['sodium'] != null
          ? (num.tryParse(json['sodium'].toString()) ?? 0).toDouble()
          : null,
      servingSize: json['serving_size'] as String?,
      loggedAt: json['logged_at'] as String?,
    );
  }

  // converts back to the map shape the rest of the app currently expects during migration
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'meal': meal,
      'food_name': foodName,
      'brand_name': brandName,
      'food_description': foodDescription,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'fiber': fiber,
      'sugar': sugar,
      'sodium': sodium,
      'serving_size': servingSize,
      'logged_at': loggedAt,
    };
  }
}
