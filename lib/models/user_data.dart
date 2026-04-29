import 'package:flutter/material.dart';
import 'reminder_data.dart';

class UserData {
  final String uid;
  String? pfpBase64;
  int level;
  int expPoints;
  bool canClaimDailyReward;
  bool notificationsEnabled;
  DateTime? lastDailyClaim;
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
    this.appColor = const Color.fromARGB(255, 45, 45, 45), // default app color
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
