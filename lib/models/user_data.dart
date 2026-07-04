import 'package:flutter/material.dart';
import 'reminder_data.dart';
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
  List<ReminderData> reminders;
  String? username;
  Color appColor;
  List<Map<String, dynamic>> foodLogs;
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
  Map<String, List<int>> waterEntriesByDate;
  Map<String, double> weightByDate;
  DateTime? createdAt;

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
    this.appColor = defaultAppColor,
    List<Map<String, dynamic>>? foodLogs,
    String? username,
    List<ReminderData>? reminders,
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
    Map<String, List<int>>? waterEntriesByDate,
    Map<String, double>? weightByDate,
    this.createdAt,
  }) : foodLogs = foodLogs ?? [],
       waterEntriesByDate = waterEntriesByDate ?? {},
       weightByDate = weightByDate ?? {},
       reminders = reminders ?? [],
       fcmTokens = fcmTokens ?? [],
       username = username ?? uid; // Default username is the UID
}
