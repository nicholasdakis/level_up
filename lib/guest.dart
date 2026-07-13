import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'globals.dart';
import 'models/food_log.dart';
import 'models/user_data.dart';
import 'providers/user_data_provider.dart';
import 'services/user_data_manager.dart' show defaultAppColor;
import 'utility/responsive.dart';

class _ShimmerSignUp extends StatelessWidget {
  const _ShimmerSignUp();

  @override
  Widget build(BuildContext context) {
    return ShimmerWidget(
      accent: lightenColor(defaultAppColor, 0.45),
      child: Text(
        'Sign Up',
        style: GoogleFonts.manrope(
          color: Colors.white,
          fontSize: Responsive.font(context, 14),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class Guest {
  // Fake food logs shown to guests so the food tab looks like a real account
  static List<FoodLog> fakeFoodLogs(String dateKey) => [
    FoodLog(
      date: dateKey,
      meal: 'breakfast',
      foodName: 'Greek Yogurt',
      foodDescription:
          'Per 200g - Calories: 190kcal | Protein: 18.0g | Carbs: 20.0g | Fat: 4.0g | Sugar: 14.0g | Sodium: 65.0mg',
      calories: 190,
      protein: 18,
      carbs: 20,
      fat: 4,
      sugar: 14,
      sodium: 65,
      servingSize: '200 g',
    ),
    FoodLog(
      date: dateKey,
      meal: 'breakfast',
      foodName: 'Banana',
      foodDescription:
          'Per 118g - Calories: 105kcal | Protein: 1.3g | Carbs: 27.0g | Fat: 0.4g | Fiber: 3.1g | Sugar: 14.4g',
      calories: 105,
      protein: 1.3,
      carbs: 27,
      fat: 0.4,
      fiber: 3.1,
      sugar: 14.4,
      servingSize: '118 g',
    ),
    FoodLog(
      date: dateKey,
      meal: 'lunch',
      foodName: 'Grilled Chicken Breast',
      foodDescription:
          'Per 150g - Calories: 248kcal | Protein: 46.5g | Carbs: 0.0g | Fat: 5.4g | Sodium: 134.0mg',
      calories: 248,
      protein: 46.5,
      carbs: 0,
      fat: 5.4,
      sodium: 134,
      servingSize: '150 g',
    ),
    FoodLog(
      date: dateKey,
      meal: 'lunch',
      foodName: 'Brown Rice',
      foodDescription:
          'Per 195g - Calories: 216kcal | Protein: 5.0g | Carbs: 45.0g | Fat: 1.8g | Fiber: 3.5g | Sodium: 10.0mg',
      calories: 216,
      protein: 5,
      carbs: 45,
      fat: 1.8,
      fiber: 3.5,
      sodium: 10,
      servingSize: '195 g',
    ),
    FoodLog(
      date: dateKey,
      meal: 'dinner',
      foodName: 'Salmon Fillet',
      foodDescription:
          'Per 170g - Calories: 354kcal | Protein: 16.2g | Carbs: 0.0g | Fat: 22.0g | Sodium: 86.0mg',
      calories: 354,
      protein: 16.2,
      carbs: 0,
      fat: 22,
      sodium: 86,
      servingSize: '170 g',
    ),
    FoodLog(
      date: dateKey,
      meal: 'dinner',
      foodName: 'Sweet Potato',
      foodDescription:
          'Per 130g - Calories: 112kcal | Protein: 2.1g | Carbs: 26.0g | Fat: 0.1g | Fiber: 3.8g | Sugar: 5.4g | Sodium: 72.0mg',
      calories: 112,
      protein: 2.1,
      carbs: 26,
      fat: 0.1,
      fiber: 3.8,
      sugar: 5.4,
      sodium: 72,
      servingSize: '130 g',
    ),
    FoodLog(
      date: dateKey,
      meal: 'snacks',
      foodName: 'Almonds',
      foodDescription:
          'Per 28g - Calories: 164kcal | Protein: 6.0g | Carbs: 6.0g | Fat: 14.0g | Fiber: 3.5g | Sugar: 1.2g | Sodium: 1.0mg',
      calories: 164,
      protein: 6,
      carbs: 6,
      fat: 14,
      fiber: 3.5,
      sugar: 1.2,
      sodium: 1,
      servingSize: '28 g',
    ),
    FoodLog(
      date: dateKey,
      meal: 'snacks',
      foodName: 'Protein Bar',
      foodDescription:
          'Per 60g - Calories: 200kcal | Protein: 20.0g | Carbs: 22.0g | Fat: 7.0g | Fiber: 14.0g | Sugar: 6.0g | Sodium: 180.0mg',
      calories: 200,
      protein: 20,
      carbs: 22,
      fat: 7,
      fiber: 14,
      sugar: 6,
      sodium: 180,
      servingSize: '60 g',
    ),
  ];

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // Fake recent workouts shown on the workout tab
  static List<Map<String, dynamic>> fakeRecentWorkouts() {
    final today = DateTime.now();
    String key(int daysAgo) =>
        _dateKey(today.subtract(Duration(days: daysAgo)));
    return [
      {'name': 'Push Day', 'date': key(1), 'duration_seconds': 3120},
      {'name': 'Leg Day', 'date': key(3), 'duration_seconds': 2700},
      {'name': 'Pull Day', 'date': key(5), 'duration_seconds': 2880},
    ];
  }

  static List<Map<String, dynamic>> fakeRoutines() => const [
    {'template_id': 'guest_1', 'name': 'Push Day', 'exercise_count': 5},
    {'template_id': 'guest_2', 'name': 'Pull Day', 'exercise_count': 4},
    {'template_id': 'guest_3', 'name': 'Leg Day', 'exercise_count': 6},
  ];

  static Map<String, int> fakeHeatmap() {
    final today = DateTime.now();
    String key(int daysAgo) =>
        _dateKey(today.subtract(Duration(days: daysAgo)));
    return {
      key(0): 1,
      key(1): 1,
      key(2): 1,
      key(3): 1,
      key(4): 1,
      key(6): 1,
      key(8): 2,
      key(11): 1,
      key(13): 1,
      key(15): 1,
      key(18): 2,
      key(21): 1,
      key(24): 1,
      key(27): 1,
      key(30): 2,
      key(33): 1,
      key(37): 1,
      key(41): 1,
      key(44): 2,
      key(48): 1,
      key(52): 1,
      key(55): 1,
      key(59): 2,
      key(63): 1,
      key(67): 1,
      key(71): 1,
      key(75): 2,
      key(80): 1,
      key(85): 1,
      key(90): 1,
    };
  }

  static Map<String, dynamic> fakeTodayOverview() => const {
    'volume_kg': 3240,
    'exercises': 5,
    'sets': 18,
    'reps': 72,
    'duration_seconds': 3120,
    'primary_muscles': ['Chest', 'Triceps', 'Shoulders'],
    'secondary_muscles': ['Core'],
  };

  // Fake water logs keyed by date, 1800ml today
  static Map<String, List<int>> fakeWaterLogs(String todayKey) => {
    todayKey: [300, 400, 300, 250, 300, 250],
  };

  // Blank user data used while browsing as a guest so the app has something to render
  static UserData get defaultUserData => UserData(
    uid: 'guest',
    pfpBase64: null,
    level: 12,
    expPoints: 780,
    canClaimDailyReward: true,
    notificationsEnabled: false,
    lastDailyClaim: null,
    username: 'Guest',
    appColor: defaultAppColor,
    fcmTokens: [],
    caloriesGoal: 2000,
    proteinGoal: 160,
    carbsGoal: 200,
    fatGoal: 55,
    fiberGoal: 30,
    sugarGoal: 50,
    sodiumGoal: 2300,
    waterMlGoal: 2500,
    weightKgGoal: 75.0,
    weeklyWorkoutsGoal: 4,
    foodLogStreak: 14,
    foodLogStreakBest: 67,
    workoutStreak: 5,
    workoutStreakBest: 12,
    workoutStreakLastDate: DateTime.now().toIso8601String().substring(0, 10),
    dailyClaimStreak: 98,
    dailyClaimStreakBest: 98,
  );

  // Called when the user taps "Continue as Guest", sets the flag and triggers the router to navigate past the login screen
  static void enter(WidgetRef ref) {
    isGuest = true;
    appInitialized = true;
    ref.read(userDataProvider.notifier).setUserData(Guest.defaultUserData);
    guestNotifier.value = true;
    appReadyNotifier.setReady();
    logAnalyticsEvent('guest_mode_entered');
  }

  // Called on sign out or when the guest taps "Sign Up" in the block dialog, clears all guest state and sends the router back to login
  static void exit() {
    isGuest = false;
    appInitialized = false;
    appReadyNotifier.reset();
    guestNotifier.value = false;
  }

  // Call from initState on screens that guests should not access, shows the block dialog as soon as the screen opens
  static void blockOnOpen(
    BuildContext context, {
    String title = 'Sign up to do this',
    String description = "Create a free account to use this feature.",
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        block(context, title: title, description: description);
      }
    });
  }

  // Shows a dialog telling the guest they need an account to use this feature
  // "Maybe Later" dismisses it, "Sign Up" calls exit() which redirects to the login screen
  static void block(
    BuildContext context, {
    String title = 'Sign up to do this',
    String description = "Create a free account to use this feature.",
  }) {
    logAnalyticsEvent('guest_block_shown', parameters: {'title': title});
    showFrostedAlertDialog(
      context: context,
      appColor: defaultAppColor,
      title: title,
      content: Text(
        description,
        textAlign: TextAlign.center,
        style: GoogleFonts.manrope(
          fontSize: Responsive.font(context, 14),
          color: Colors.white70,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          child: Text("Maybe Later", style: dialogButtonStyle()),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop();
            exit();
          },
          child: const _ShimmerSignUp(),
        ),
      ],
    );
  }
}
