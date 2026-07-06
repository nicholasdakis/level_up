import 'dart:convert';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_data.dart';
import '../globals.dart' show userManager, isGuest;
import '../services/user_data_manager.dart'
    show authenticatedPost, authenticatedGet;

class UserDataNotifier extends AsyncNotifier<UserData?> {
  @override
  // starts as null, AppInitScreen calls setUserData() once loading is done
  Future<UserData?> build() async => null;

  // replaces the entire UserData object, called after a full backend load
  void setUserData(UserData? data) {
    state = AsyncData(data);
  }

  // updates one or more fields locally, used when the caller already has the new value and just needs to sync it into state
  void patch(UserData Function(UserData current) updater) {
    final current = state.value;
    if (current != null) state = AsyncData(updater(current));
  }

  // optimistically flips the flag locally, rolls back if the backend call fails
  Future<void> setNotificationsEnabled(bool value, BuildContext context) async {
    final previous = state.value;
    if (previous == null) return;
    state = AsyncData(previous.copyWith(notificationsEnabled: value));
    try {
      await userManager.updateNotificationsEnabled(value, context);
    } catch (e) {
      state = AsyncData(previous);
      rethrow;
    }
  }

  // applies all onboarding selections to local state and syncs each to the backend
  // TODO: move backend calls out of userManager and into this notifier
  Future<void> commitOnboarding({
    required BuildContext context,
    required String currentUnits,
    String? weightGoalType,
    String? selectedUnits,
    double? currentWeightKg,
    double? weightKgGoal,
    int? caloriesGoal,
    int? proteinGoal,
    int? carbsGoal,
    int? fatGoal,
    String? username,
    String? dateKey,
  }) async {
    patch((u) {
      var updated = u;
      if (weightGoalType != null) {
        updated = updated.copyWith(weightGoalType: weightGoalType);
      }
      if (selectedUnits != null && selectedUnits != currentUnits) {
        updated = updated.copyWith(units: selectedUnits);
      }
      if (currentWeightKg != null && dateKey != null) {
        final wb = Map<String, double>.from(updated.weightByDate)
          ..[dateKey] = currentWeightKg;
        updated = updated.copyWith(weightByDate: wb);
      }
      if (weightKgGoal != null) {
        updated = updated.copyWith(weightKgGoal: weightKgGoal);
      }
      if (caloriesGoal != null && caloriesGoal > 0) {
        updated = updated.copyWith(caloriesGoal: caloriesGoal);
      }
      if (proteinGoal != null && carbsGoal != null && fatGoal != null) {
        updated = updated.copyWith(
          proteinGoal: proteinGoal,
          carbsGoal: carbsGoal,
          fatGoal: fatGoal,
        );
      }
      if (username != null) updated = updated.copyWith(username: username);
      return updated;
    });

    if (weightGoalType != null) {
      userManager.updateWeightGoal(weightGoalType: weightGoalType);
    }
    if (selectedUnits != null && selectedUnits != currentUnits) {
      userManager.updateUnits(selectedUnits, context, showFeedback: false);
    }
    if (currentWeightKg != null && dateKey != null) {
      userManager.updateWeightLog(dateKey, currentWeightKg);
    }
    if (weightKgGoal != null) {
      userManager.updateWeightGoal(weightKgGoal: weightKgGoal);
    }
    if (caloriesGoal != null && caloriesGoal > 0) {
      userManager.updateGoals(caloriesGoal: caloriesGoal);
    }
    if (proteinGoal != null && carbsGoal != null && fatGoal != null) {
      userManager.updateGoals(
        proteinGoal: proteinGoal,
        carbsGoal: carbsGoal,
        fatGoal: fatGoal,
      );
    }
    if (username != null) {
      userManager.updateUsername(username, context, showFeedback: false);
    }
  }

  // claims a referral reward for the referrer; patches state only on backend success
  Future<Map<String, dynamic>?> claimReferralReward(String refereeUid) async {
    final res = await authenticatedPost(
      'claim_referral_reward',
      body: {'referee_uid': refereeUid},
    );
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    patch(
      (u) => u.copyWith(
        level: data['new_level'],
        expPoints: data['new_exp'],
        referralCount: u.referralCount + 1,
      ),
    );
    return data;
  }

  // redeems a referral code for the referee; patches state only on backend success
  Future<Map<String, dynamic>?> useReferralCode(String code) async {
    final res = await authenticatedPost(
      'use_referral',
      body: {'referral_code': code},
    );
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    patch(
      (u) => u.copyWith(
        level: data['new_level'],
        expPoints: data['new_exp'],
        referralUsed: true,
      ),
    );
    return data;
  }

  // fetches or generates a referral code and caches it locally
  Future<String?> fetchReferralCode() async {
    final cached = state.value?.referralCode;
    if (cached != null) return cached;
    try {
      final getRes = await authenticatedGet('referral_code');
      if (getRes.statusCode == 200) {
        final code =
            (jsonDecode(getRes.body) as Map<String, dynamic>)['referral_code']
                as String;
        patch((u) => u.copyWith(referralCode: code));
        return code;
      }
      if (getRes.statusCode == 404) {
        final postRes = await authenticatedPost('referral_code');
        if (postRes.statusCode == 201) {
          final code =
              (jsonDecode(postRes.body)
                      as Map<String, dynamic>)['referral_code']
                  as String;
          patch((u) => u.copyWith(referralCode: code));
          return code;
        }
      }
    } catch (_) {}
    return null;
  }

  // claims the daily reward from the backend and patches state on success
  Future<(int, int, int, double, int)?> claimDailyReward() async {
    if (isGuest) return null;
    try {
      final response = await authenticatedPost('claim_daily_reward');
      if (response.statusCode != 200) {
        throw Exception(
          'claimDailyReward failed: ${response.statusCode} ${response.body}',
        );
      }
      final result = jsonDecode(response.body) as Map<String, dynamic>;
      if (!result['claimed']) {
        patch((u) => u.copyWith(canClaimDailyReward: false));
        return null;
      }
      final newLevel = result['new_level'] as int;
      final prevLevel = state.value?.level ?? 1;
      if (prevLevel < 3 && newLevel >= 3) {
        FirebaseAnalytics.instance.logEvent(name: 'reached_level_3');
      }
      final xpGained = result['xp_gained'] as int;
      final baseXp = (result['base_xp'] ?? xpGained) as int;
      final streak = (result['daily_streak'] ?? 1) as int;
      final multiplier = ((result['streak_multiplier'] ?? 1.0) as num)
          .toDouble();
      patch(
        (u) => u.copyWith(
          level: newLevel,
          expPoints: result['new_exp'] as int,
          canClaimDailyReward: false,
          lastDailyClaim: DateTime.now().toUtc(),
          dailyClaimStreak: streak,
          dailyClaimStreakBest: streak > u.dailyClaimStreakBest
              ? streak
              : u.dailyClaimStreakBest,
        ),
      );
      return (xpGained, baseXp, streak, multiplier, prevLevel);
    } catch (e) {
      if (kDebugMode) debugPrint('claimDailyReward backend error: $e');
      return (-1, -1, -1, -1.0, -1); // sentinel for network failure
    }
  }

  // optimistically applies the color locally, rolls back if the backend call fails
  Future<void> setAppColor(Color color, BuildContext context) async {
    final previous = state.value;
    if (previous == null) return;
    state = AsyncData(previous.copyWith(appColor: color));
    try {
      await userManager.updateAppColor(color, context);
    } catch (e) {
      state = AsyncData(previous);
      rethrow;
    }
  }
}

final userDataProvider = AsyncNotifierProvider<UserDataNotifier, UserData?>(
  UserDataNotifier.new,
);
