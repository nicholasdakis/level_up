import 'package:flutter/material.dart';
import '../services/user_data_manager.dart' show defaultAppColor;

class UserData {
  final String uid;
  String? pfpBase64;
  int level;
  int expPoints;
  bool canClaimDailyReward;
  bool notificationsEnabled;
  DateTime? lastDailyClaim;
  int dailyClaimStreak;
  int dailyClaimStreakBest;
  int foodLogStreak;
  int foodLogStreakBest;
  String? foodLogStreakLastDate;
  int workoutStreak;
  int workoutStreakBest;
  String? workoutStreakLastDate;
  String? username;
  Color appColor;
  List<String> fcmTokens;
  int? caloriesGoal;
  int? proteinGoal;
  int? carbsGoal;
  int? fatGoal;
  String? weightGoalType;
  int? weeklyWorkoutsGoal;
  int? waterMlGoal;
  double? weightKgGoal;
  String? referralCode;
  int referralCount = 0;
  bool referralUsed = false;
  String units;
  DateTime? createdAt;
  bool isPremium;
  DateTime? premiumExpiresAt;
  int shieldCount;
  DateTime? shieldsResetAt;
  int?
  recentFoodsMax; // null means use default (20), 0 means unlimited (premium only)

  // constructor
  UserData({
    required this.uid,
    this.pfpBase64,
    this.level = 1,
    this.expPoints = 0,
    this.canClaimDailyReward = true,
    this.notificationsEnabled = true,
    this.lastDailyClaim,
    this.dailyClaimStreak = 0,
    this.dailyClaimStreakBest = 0,
    this.foodLogStreak = 0,
    this.foodLogStreakBest = 0,
    this.workoutStreak = 0,
    this.workoutStreakBest = 0,
    this.workoutStreakLastDate,
    this.appColor = defaultAppColor,
    String? username,
    List<String>? fcmTokens,
    this.caloriesGoal,
    this.proteinGoal,
    this.carbsGoal,
    this.fatGoal,
    this.weightGoalType,
    this.weeklyWorkoutsGoal,
    this.waterMlGoal,
    this.weightKgGoal,
    this.referralCode,
    this.referralCount = 0,
    this.referralUsed = false,
    this.units = 'metric',
    this.createdAt,
    this.isPremium = false,
    this.premiumExpiresAt,
    this.shieldCount = 0,
    this.shieldsResetAt,
    this.recentFoodsMax,
  }) : fcmTokens = fcmTokens ?? [],
       username = username ?? uid; // Default username is the UID

  UserData copyWith({
    String? pfpBase64,
    int? level,
    int? expPoints,
    bool? canClaimDailyReward,
    bool? notificationsEnabled,
    DateTime? lastDailyClaim,
    int? dailyClaimStreak,
    int? dailyClaimStreakBest,
    int? foodLogStreak,
    int? foodLogStreakBest,
    String? foodLogStreakLastDate,
    int? workoutStreak,
    int? workoutStreakBest,
    String? workoutStreakLastDate,
    String? username,
    Color? appColor,
    List<String>? fcmTokens,
    int? caloriesGoal,
    int? proteinGoal,
    int? carbsGoal,
    int? fatGoal,
    String? weightGoalType,
    int? weeklyWorkoutsGoal,
    int? waterMlGoal,
    double? weightKgGoal,
    String? referralCode,
    int? referralCount,
    bool? referralUsed,
    String? units,
    DateTime? createdAt,
    bool? isPremium,
    DateTime? premiumExpiresAt,
    int? shieldCount,
    DateTime? shieldsResetAt,
    int? recentFoodsMax,
  }) {
    return UserData(
      uid: uid,
      pfpBase64: pfpBase64 ?? this.pfpBase64,
      level: level ?? this.level,
      expPoints: expPoints ?? this.expPoints,
      canClaimDailyReward: canClaimDailyReward ?? this.canClaimDailyReward,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      lastDailyClaim: lastDailyClaim ?? this.lastDailyClaim,
      dailyClaimStreak: dailyClaimStreak ?? this.dailyClaimStreak,
      dailyClaimStreakBest: dailyClaimStreakBest ?? this.dailyClaimStreakBest,
      foodLogStreak: foodLogStreak ?? this.foodLogStreak,
      foodLogStreakBest: foodLogStreakBest ?? this.foodLogStreakBest,
      workoutStreak: workoutStreak ?? this.workoutStreak,
      workoutStreakBest: workoutStreakBest ?? this.workoutStreakBest,
      workoutStreakLastDate:
          workoutStreakLastDate ?? this.workoutStreakLastDate,
      username: username ?? this.username,
      appColor: appColor ?? this.appColor,
      fcmTokens: fcmTokens ?? this.fcmTokens,
      caloriesGoal: caloriesGoal ?? this.caloriesGoal,
      proteinGoal: proteinGoal ?? this.proteinGoal,
      carbsGoal: carbsGoal ?? this.carbsGoal,
      fatGoal: fatGoal ?? this.fatGoal,
      weightGoalType: weightGoalType ?? this.weightGoalType,
      weeklyWorkoutsGoal: weeklyWorkoutsGoal ?? this.weeklyWorkoutsGoal,
      waterMlGoal: waterMlGoal ?? this.waterMlGoal,
      weightKgGoal: weightKgGoal ?? this.weightKgGoal,
      referralCode: referralCode ?? this.referralCode,
      referralCount: referralCount ?? this.referralCount,
      referralUsed: referralUsed ?? this.referralUsed,
      units: units ?? this.units,
      createdAt: createdAt ?? this.createdAt,
      isPremium: isPremium ?? this.isPremium,
      premiumExpiresAt: premiumExpiresAt ?? this.premiumExpiresAt,
      shieldCount: shieldCount ?? this.shieldCount,
      shieldsResetAt: shieldsResetAt ?? this.shieldsResetAt,
      recentFoodsMax: recentFoodsMax ?? this.recentFoodsMax,
    );
  }
}
