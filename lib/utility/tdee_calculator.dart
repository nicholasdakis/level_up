// Shared TDEE calculation logic used by onboarding and the calorie calculator

double tdeeActivityFactor(String level) {
  switch (level) {
    case 'Sedentary':
    case 'sedentary':
      return 1.2;
    case 'Light':
    case 'light':
      return 1.375;
    case 'Moderate':
    case 'moderate':
      return 1.55;
    case 'Active':
    case 'active':
      return 1.725;
    case 'Very Active':
    case 'very active':
      return 1.9;
    default:
      return 1.55;
  }
}

// Mifflin-St Jeor BMR, weight in kg, height in cm
double calculateBmr(String sex, double weightKg, double heightCm, int age) {
  if (sex == 'Female') {
    return (10 * weightKg) + (6.25 * heightCm) - (5 * age) - 161;
  }
  return (10 * weightKg) + (6.25 * heightCm) - (5 * age) + 5;
}

int? calculateTdee({
  required String sex,
  required double? weightKg,
  required double? heightCm,
  required int? age,
  required String activityLevel,
}) {
  if (weightKg == null || heightCm == null || age == null) return null;
  final bmr = calculateBmr(sex, weightKg, heightCm, age);
  return (bmr * tdeeActivityFactor(activityLevel)).round();
}
