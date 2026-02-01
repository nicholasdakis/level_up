import 'package:flutter/material.dart';
import 'reminder_data.dart';

class UserData {
  final String uid;
  String? pfpBase64;
  int level;
  int expPoints;
  bool canClaimDailyReward;
  DateTime? lastDailyClaim;
  List<ReminderData> reminders;
  String? username;
  Color appColor;
  Map<String, Map<String, List<Map<String, dynamic>>>> foodDataByDate;

  // constructor
  UserData({
    required this.uid,
    this.pfpBase64,
    this.level = 1,
    this.expPoints = 0,
    this.canClaimDailyReward = true,
    this.lastDailyClaim,
    this.appColor = const Color.fromARGB(255, 45, 45, 45), // default app color
    Map<String, Map<String, List<Map<String, dynamic>>>>? foodDataByDate,
    String? username,
    this.reminders = const [],
  }) : foodDataByDate = foodDataByDate ?? {},
       username = username ?? uid; // Default username is the UID
}
