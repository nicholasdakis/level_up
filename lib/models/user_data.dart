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
  List<ReminderData> reminders;
  String? username;
  Color appColor;
  Map<String, Map<String, List<Map<String, dynamic>>>> foodDataByDate;
  List<String> fcmTokens;
  int? caloriesGoal;
  int? proteinGoal;
  int? carbsGoal;
  int? fatGoal;
  String? weightGoalType;

  // constructor
  UserData({
    required this.uid,
    this.pfpBase64,
    this.level = 1,
    this.expPoints = 0,
    this.canClaimDailyReward = true,
    this.notificationsEnabled = true,
    this.lastDailyClaim,
    this.dailyClaimStreak = 1,
    this.appColor = defaultAppColor,
    Map<String, Map<String, List<Map<String, dynamic>>>>? foodDataByDate,
    String? username,
    List<ReminderData>? reminders,
    List<String>? fcmTokens,
    this.caloriesGoal,
    this.proteinGoal,
    this.carbsGoal,
    this.fatGoal,
    this.weightGoalType,
  }) : foodDataByDate = foodDataByDate ?? {},
       reminders = reminders ?? [],
       fcmTokens = fcmTokens ?? [],
       username = username ?? uid; // Default username is the UID
}
