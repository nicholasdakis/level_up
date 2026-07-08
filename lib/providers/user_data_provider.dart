import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_data.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../globals.dart' show isGuest, snackBarDuration, dailyRewardCooldown;
import '../guest.dart' show Guest;
import 'weight_logs_provider.dart';
import '../services/user_data_manager.dart'
    show
        authenticatedPost,
        authenticatedGet,
        isConnected,
        UserDataManager,
        defaultAppColor,
        initConnectivity;
import '../utility/image_crop_handler.dart';
import '../services/profile_image_service.dart';

class UserDataNotifierNew extends AsyncNotifier<UserData?> {
  bool lastLoadFailed = false;

  @override
  // starts as null, AppInitScreen calls setUserData() once loading is done
  Future<UserData?> build() async => null;

  // replaces the entire UserData object, called after a full backend load
  void setUserData(UserData? data) {
    state = AsyncData(data);
  }

  // safe to call from non-widget code that holds a notifier reference
  List<String> get currentFcmTokens => state.value?.fcmTokens ?? [];
  UserData? get currentUserData => state.value;

  int? get experienceNeeded {
    final level = state.value?.level;
    if (level == null) return null;
    final exp = (100 * pow(1.25, level - 0.5) * 1.05 + (level * 10)).round();
    return (exp / 10).round() * 10;
  }

  int? get totalXpEarned {
    final u = state.value;
    if (u == null) return null;
    int total = 0;
    for (int level = 1; level < u.level; level++) {
      final exp = (100 * pow(1.25, level - 0.5) * 1.05 + (level * 10)).round();
      total += (exp / 10).round() * 10;
    }
    return total + u.expPoints;
  }

  // loads all user data from the backend; builds a complete UserData and sets it once
  Future<void> loadUserData() async {
    initConnectivity();

    if (isGuest) {
      setUserData(Guest.defaultUserData);
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // initialize a blank placeholder if there's no data yet or the UID changed
    if (state.value == null || state.value!.uid != uid) {
      setUserData(UserData(uid: uid));
    }

    await _fetchAndSetUserData();
  }

  Future<void> _fetchAndSetUserData() async {
    final current = state.value;
    if (current == null) return;
    try {
      final response = await authenticatedGet('user_data');
      if (response.statusCode != 200) {
        throw Exception(
          'get_user_data failed: ${response.statusCode} ${response.body}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      // compute canClaimDailyReward from last_daily_claim
      DateTime? lastDailyClaim;
      bool canClaim = true;
      if (data['last_daily_claim'] != null) {
        lastDailyClaim = DateTime.parse(data['last_daily_claim']);
        final secondsSince = DateTime.now()
            .toUtc()
            .difference(lastDailyClaim.toUtc())
            .inSeconds;
        canClaim = secondsSince >= dailyRewardCooldown.inSeconds;
      }

      // fetch streaks (best-effort, non-fatal)
      int foodStreak = 0,
          foodStreakBest = 0,
          workoutStreak = 0,
          workoutStreakBest = 0,
          claimStreakBest = 0;
      String? foodStreakLastDate;
      try {
        final streaks = await UserDataManager.fetchStreaks();
        final foodRow = streaks.firstWhere(
          (s) => s['streak_type'] == 'food_streak',
          orElse: () => {},
        );
        final claimRow = streaks.firstWhere(
          (s) => s['streak_type'] == 'daily_consecutive_streak',
          orElse: () => {},
        );
        final workoutRow = streaks.firstWhere(
          (s) => s['streak_type'] == 'workout_streak',
          orElse: () => {},
        );
        foodStreak = (foodRow['streak'] as int?) ?? 0;
        foodStreakBest = (foodRow['highest_streak'] as int?) ?? 0;
        foodStreakLastDate = foodRow['last_date'] as String?;
        claimStreakBest = (claimRow['highest_streak'] as int?) ?? 0;
        workoutStreak = (workoutRow['streak'] as int?) ?? 0;
        workoutStreakBest = (workoutRow['highest_streak'] as int?) ?? 0;
      } catch (_) {}

      final goals = data['goals'] as Map<String, dynamic>?;

      setUserData(
        current.copyWith(
          level: data['level'] ?? current.level,
          expPoints: data['exp_points'] ?? current.expPoints,
          pfpBase64: data['pfp_base64'],
          username: data['username'] ?? current.uid,
          notificationsEnabled: data['notifications_enabled'] ?? true,
          fcmTokens:
              (data['fcm_tokens'] as List<dynamic>?)
                  ?.map((t) => t.toString())
                  .toList() ??
              [],
          appColor: data['app_color'] != null
              ? Color(data['app_color'] as int)
              : current.appColor,
          dailyClaimStreak: data['daily_streak'] ?? 0,
          lastDailyClaim: lastDailyClaim ?? current.lastDailyClaim,
          canClaimDailyReward: canClaim,
          caloriesGoal: goals?['calories_goal'] ?? current.caloriesGoal,
          proteinGoal: goals?['protein_goal'] ?? current.proteinGoal,
          carbsGoal: goals?['carbs_goal'] ?? current.carbsGoal,
          fatGoal: goals?['fat_goal'] ?? current.fatGoal,
          weightGoalType: goals?['weight_goal_type'] ?? current.weightGoalType,
          weeklyWorkoutsGoal:
              goals?['weekly_workouts_goal'] ?? current.weeklyWorkoutsGoal,
          waterMlGoal: goals?['water_ml_goal'] ?? current.waterMlGoal,
          weightKgGoal: goals?['weight_kg_goal'] != null
              ? (goals!['weight_kg_goal'] as num).toDouble()
              : current.weightKgGoal,
          referralCode: data['referral_code'] ?? current.referralCode,
          referralCount: data['referral_count'] ?? 0,
          referralUsed: data['referral_used'] ?? false,
          units: data['units'] ?? 'metric',
          createdAt: data['created_at'] != null
              ? DateTime.tryParse(data['created_at'])?.toLocal()
              : current.createdAt,
          foodLogStreak: foodStreak,
          foodLogStreakBest: foodStreakBest,
          foodLogStreakLastDate: foodStreakLastDate,
          dailyClaimStreakBest: claimStreakBest,
          workoutStreak: workoutStreak,
          workoutStreakBest: workoutStreakBest,
        ),
      );

      lastLoadFailed = false;
      ref.read(userDataLoadedProvider.notifier).setLoaded();
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading user data: $e');
      // signals fetch failed so username dialog is not shown and backend decides on claim
      patch((u) => u.copyWith(canClaimDailyReward: true));
      lastLoadFailed = true;
    }
  }

  // updates one or more fields locally, used when the caller already has the new value and just needs to sync it into state
  void patch(UserData Function(UserData current) updater) {
    final current = state.value;
    if (current != null) state = AsyncData(updater(current));
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
        // weight log is now stored in weightLogsProvider, not on UserData
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
      await updateWeightGoal(weightGoalType: weightGoalType);
    }
    if (selectedUnits != null && selectedUnits != currentUnits) {
      await updateUnits(selectedUnits, context, showFeedback: false);
    }
    if (currentWeightKg != null && dateKey != null) {
      ref
          .read(weightLogsProvider.notifier)
          .updateWeightLog(dateKey, currentWeightKg);
    }
    if (weightKgGoal != null) {
      await updateWeightGoal(weightKgGoal: weightKgGoal);
    }
    if (caloriesGoal != null && caloriesGoal > 0) {
      await updateGoals(caloriesGoal: caloriesGoal);
    }
    if (proteinGoal != null && carbsGoal != null && fatGoal != null) {
      await updateGoals(
        proteinGoal: proteinGoal,
        carbsGoal: carbsGoal,
        fatGoal: fatGoal,
      );
    }
    if (username != null) {
      updateUsername(username, context, showFeedback: false);
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

  // verifies uniqueness with the backend and patches username on success; returns false to keep dialog open on failure
  Future<bool> updateUsername(
    String updatedUsername,
    BuildContext context, {
    bool showFeedback = true,
  }) async {
    if (isGuest) {
      Guest.block(context);
      return false;
    }
    try {
      final response = await authenticatedPost(
        'update_username',
        body: {'username': updatedUsername},
      );
      final result = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 409) {
        final error = result['error'] as String? ?? 'Error updating username.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $error"), duration: snackBarDuration),
        );
        return false; // false to keep the dialog box open
      } else if (response.statusCode == 200) {
        patch((u) => u.copyWith(username: updatedUsername));
        if (showFeedback) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Success! Username updated."),
              duration: snackBarDuration,
            ),
          );
        }
        return true;
      } else {
        // Backend rejected the update (username taken)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? "Error updating username."),
            duration: snackBarDuration,
          ),
        );
        return false;
      }
    } catch (e) {
      // No connection, so show the local confirmation snackbar
      if (!isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Error updating username. Check your connection and try again.",
            ),
            duration: snackBarDuration,
          ),
        );
        return true; // to close the dialog
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error updating username: $e"),
          duration: snackBarDuration,
        ),
      );
      return false;
    }
  }

  // refreshes all user data from the backend, called on tab switch to keep data fresh across devices
  Future<void> refreshUserData() async {
    if (isGuest) return;
    await _fetchAndSetUserData();
  }

  // awards XP for watching a rewarded ad then refreshes user data
  Future<void> claimAdXp(BuildContext context) async {
    try {
      final response = await authenticatedPost('claim_ad_xp');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final xpGained = data['xp_gained'] ?? 0;
        await _fetchAndSetUserData();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("+$xpGained XP earned!"),
              duration: snackBarDuration,
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('claimAdXp failed: $e');
    }
  }

  // adds FCM token locally and syncs to backend; no-op if already present
  Future<void> initializeFcmToken(String deviceToken) async {
    if (isGuest) return;
    try {
      // Add token locally if not already present (guard against race condition where currentUserData may not be set yet)
      final tokens = state.value?.fcmTokens;
      if (tokens != null && !tokens.contains(deviceToken)) {
        patch((u) => u.copyWith(fcmTokens: [...u.fcmTokens, deviceToken]));
      }
      await authenticatedPost('add_fcm_token', body: {'token': deviceToken});
    } catch (e) {
      if (kDebugMode) debugPrint("Error initializing FCM token: $e");
    }
  }

  // removes stale token then adds new one (called on token refresh)
  Future<void> addFcmToken(String deviceToken, {String? oldToken}) async {
    if (isGuest) return;
    try {
      if (oldToken != null) await removeFcmToken(oldToken);
      final tokens = state.value?.fcmTokens;
      if (tokens != null && !tokens.contains(deviceToken)) {
        patch((u) => u.copyWith(fcmTokens: [...u.fcmTokens, deviceToken]));
      }
      await authenticatedPost('add_fcm_token', body: {'token': deviceToken});
    } catch (e) {
      if (kDebugMode) debugPrint("Error adding FCM token: $e");
    }
  }

  // removes FCM token locally and from backend (called on logout)
  Future<void> removeFcmToken(String deviceToken) async {
    if (isGuest) return;
    try {
      patch(
        (u) => u.copyWith(
          fcmTokens: u.fcmTokens.where((t) => t != deviceToken).toList(),
        ),
      );
      await authenticatedPost('remove_fcm_token', body: {'token': deviceToken});
    } catch (e) {
      if (kDebugMode) debugPrint("Error removing FCM token: $e");
    }
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
      final int argbInt = color.toARGB32();
      final bool isDefaultColor = argbInt == defaultAppColor.toARGB32();
      final response = await authenticatedPost(
        'update_app_color',
        body: {'app_color': argbInt},
      );
      if (response.statusCode != 200) {
        throw Exception('update_app_color failed: ${response.statusCode}');
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isDefaultColor ? "Theme color reset!" : "Theme color updated!",
            ),
            duration: snackBarDuration,
          ),
        );
      }
    } catch (e) {
      state = AsyncData(previous);
      if (context.mounted) {
        final message = e is TimeoutException
            ? "Connection is slow. Please try again."
            : isConnected
            ? "Error updating theme color."
            : "No connection. Please try again when online.";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), duration: snackBarDuration),
        );
      }
    }
  }

  Future<void> updateNotificationsEnabled(
    bool enabled,
    BuildContext context,
  ) async {
    if (isGuest) {
      Guest.block(context);
      return;
    }
    final previous = state.value;
    if (previous == null) return;
    state = AsyncData(previous.copyWith(notificationsEnabled: enabled));
    try {
      final response = await authenticatedPost(
        'update_notifications',
        body: {'enabled': enabled},
      );
      if (response.statusCode != 200) {
        throw Exception('update_notifications failed: ${response.statusCode}');
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Notification preferences updated successfully."),
            duration: Duration(milliseconds: 500),
          ),
        );
      }
    } catch (e) {
      state = AsyncData(previous);
      if (context.mounted) {
        final message = !isConnected
            ? "No connection. Please try again when online."
            : e is TimeoutException
            ? "Connection is slow. Please try again."
            : "Error updating notification preferences.";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), duration: snackBarDuration),
        );
      }
    }
  }

  Future<void> updateUnits(
    String units,
    BuildContext context, {
    bool showFeedback = true,
  }) async {
    if (isGuest) {
      Guest.block(context);
      return;
    }
    final previous = state.value;
    if (previous == null) return;
    state = AsyncData(previous.copyWith(units: units));
    try {
      final response = await authenticatedPost(
        'update_units',
        body: {'units': units},
      );
      if (response.statusCode != 200) {
        throw Exception('update_units failed: ${response.statusCode}');
      }
      if (showFeedback && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Units updated successfully."),
            duration: snackBarDuration,
          ),
        );
      }
    } catch (e) {
      state = AsyncData(previous);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              !isConnected
                  ? "No connection. Please try again when online."
                  : "Error updating unit preference.",
            ),
            duration: snackBarDuration,
          ),
        );
      }
    }
  }

  Future<void> updateGoals({
    int? caloriesGoal,
    int? proteinGoal,
    int? carbsGoal,
    int? fatGoal,
    String? weightGoalType,
    int? weeklyWorkoutsGoal,
    BuildContext? context,
  }) async {
    if (isGuest) {
      if (context != null) Guest.block(context);
      return;
    }
    final previous = state.value;
    if (previous == null) return;
    state = AsyncData(
      previous.copyWith(
        caloriesGoal: caloriesGoal ?? previous.caloriesGoal,
        proteinGoal: proteinGoal ?? previous.proteinGoal,
        carbsGoal: carbsGoal ?? previous.carbsGoal,
        fatGoal: fatGoal ?? previous.fatGoal,
        weightGoalType: weightGoalType ?? previous.weightGoalType,
        weeklyWorkoutsGoal: weeklyWorkoutsGoal ?? previous.weeklyWorkoutsGoal,
      ),
    );
    try {
      final response = await authenticatedPost(
        'update_goals',
        body: {
          'calories_goal': caloriesGoal,
          'protein_goal': proteinGoal,
          'carbs_goal': carbsGoal,
          'fat_goal': fatGoal,
          'weight_goal_type': weightGoalType,
          'weekly_workouts_goal': weeklyWorkoutsGoal,
        },
        timeout: const Duration(seconds: 2),
      );
      if (response.statusCode != 200) {
        throw Exception('update_goals failed: ${response.statusCode}');
      }
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Goals updated successfully."),
            duration: snackBarDuration,
          ),
        );
      }
    } catch (e) {
      state = AsyncData(previous);
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error updating goals: $e"),
            duration: snackBarDuration,
          ),
        );
      }
    }
  }

  Future<void> updateNutritionGoals({
    int? caloriesGoal,
    int? proteinGoal,
    int? carbsGoal,
    int? fatGoal,
    BuildContext? context,
  }) async {
    if (isGuest) {
      if (context != null) Guest.block(context);
      return;
    }
    final previous = state.value;
    if (previous == null) return;
    state = AsyncData(
      previous.copyWith(
        caloriesGoal: caloriesGoal ?? previous.caloriesGoal,
        proteinGoal: proteinGoal ?? previous.proteinGoal,
        carbsGoal: carbsGoal ?? previous.carbsGoal,
        fatGoal: fatGoal ?? previous.fatGoal,
      ),
    );
    try {
      final response = await authenticatedPost(
        'update_nutrition_goals',
        body: {
          'calories_goal': caloriesGoal,
          'protein_goal': proteinGoal,
          'carbs_goal': carbsGoal,
          'fat_goal': fatGoal,
        },
        timeout: const Duration(seconds: 2),
      );
      if (response.statusCode != 200) {
        throw Exception(
          'update_nutrition_goals failed: ${response.statusCode}',
        );
      }
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Nutrition goals updated."),
            duration: snackBarDuration,
          ),
        );
      }
    } catch (e) {
      state = AsyncData(previous);
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error updating nutrition goals: $e"),
            duration: snackBarDuration,
          ),
        );
      }
    }
  }

  Future<void> updateWeightGoal({
    String? weightGoalType,
    double? weightKgGoal,
    BuildContext? context,
  }) async {
    if (isGuest) {
      if (context != null) Guest.block(context);
      return;
    }
    final previous = state.value;
    if (previous == null) return;
    state = AsyncData(
      previous.copyWith(
        weightGoalType: weightGoalType ?? previous.weightGoalType,
        weightKgGoal: weightKgGoal ?? previous.weightKgGoal,
      ),
    );
    try {
      final response = await authenticatedPost(
        'update_weight_goal',
        body: {
          'weight_goal_type': weightGoalType,
          'weight_kg_goal': weightKgGoal,
        },
        timeout: const Duration(seconds: 2),
      );
      if (response.statusCode != 200) {
        throw Exception('update_weight_goal failed: ${response.statusCode}');
      }
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Weight goal updated."),
            duration: snackBarDuration,
          ),
        );
      }
    } catch (e) {
      state = AsyncData(previous);
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error updating weight goal: $e"),
            duration: snackBarDuration,
          ),
        );
      }
    }
  }

  Future<void> updateWaterGoal({
    int? waterMlGoal,
    BuildContext? context,
  }) async {
    if (isGuest) {
      if (context != null) Guest.block(context);
      return;
    }
    final previous = state.value;
    if (previous == null || waterMlGoal == null) return;
    state = AsyncData(previous.copyWith(waterMlGoal: waterMlGoal));
    try {
      final response = await authenticatedPost(
        'update_water_goal',
        body: {'water_ml_goal': waterMlGoal},
        timeout: const Duration(seconds: 2),
      );
      if (response.statusCode != 200) {
        throw Exception('update_water_goal failed: ${response.statusCode}');
      }
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Water goal updated."),
            duration: snackBarDuration,
          ),
        );
      }
    } catch (e) {
      state = AsyncData(previous);
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error updating water goal: $e"),
            duration: snackBarDuration,
          ),
        );
      }
    }
  }

  Future<void> updateWeeklyWorkoutsGoal({
    int? weeklyWorkoutsGoal,
    BuildContext? context,
  }) async {
    if (isGuest) {
      if (context != null) Guest.block(context);
      return;
    }
    final previous = state.value;
    if (previous == null || weeklyWorkoutsGoal == null) return;
    state = AsyncData(
      previous.copyWith(weeklyWorkoutsGoal: weeklyWorkoutsGoal),
    );
    try {
      final response = await authenticatedPost(
        'update_weekly_workouts_goal',
        body: {'weekly_workouts_goal': weeklyWorkoutsGoal},
        timeout: const Duration(seconds: 2),
      );
      if (response.statusCode != 200) {
        throw Exception(
          'update_weekly_workouts_goal failed: ${response.statusCode}',
        );
      }
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Workout goal updated."),
            duration: snackBarDuration,
          ),
        );
      }
    } catch (e) {
      state = AsyncData(previous);
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error updating workout goal: $e"),
            duration: snackBarDuration,
          ),
        );
      }
    }
  }

  Future<void> updateProfilePicture(
    File? file, {
    VoidCallback? onProfileUpdated,
    required BuildContext context,
    Uint8List? imageInBytes,
  }) async {
    if (isGuest) {
      Guest.block(context);
      return;
    }
    if (kIsWeb) {
      final cropped = await ImageCropHelper.cropPicture(
        webBytes: imageInBytes,
        context: context,
        appColor: state.value?.appColor ?? defaultAppColor,
      );
      if (cropped == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Profile picture update cancelled."),
            duration: snackBarDuration,
          ),
        );
        return;
      }
      imageInBytes = await ImageCropHelper.getBytes(cropped);
    } else {
      final cropped = await ImageCropHelper.cropPicture(
        mobileFile: file,
        context: context,
        appColor: state.value?.appColor ?? defaultAppColor,
      );
      if (cropped == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Profile picture update cancelled."),
            duration: snackBarDuration,
          ),
        );
        return;
      }
      file = File(cropped.path);
    }
    if (!await ProfileImageService.checkSize(
      file,
      context,
      isWeb: kIsWeb,
      webBytes: imageInBytes,
    )) {
      return;
    }
    try {
      final base64String = kIsWeb
          ? base64Encode(await ProfileImageService.compressWeb(imageInBytes!))
          : base64Encode(await ProfileImageService.compressMobile(file!));
      final response = await authenticatedPost(
        'update_pfp',
        body: {'pfp_base64': base64String},
        timeout: Duration(seconds: 5),
      );
      if (response.statusCode != 200) {
        throw Exception('update_pfp failed: ${response.statusCode}');
      }
      patch((u) => u.copyWith(pfpBase64: base64String));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Profile picture successfully updated."),
            duration: snackBarDuration,
          ),
        );
      }
      onProfileUpdated?.call();
    } catch (e) {
      if (context.mounted) {
        final message = !isConnected
            ? "No connection. Please try again when online."
            : e is TimeoutException
            ? "Connection is slow. Please try again."
            : "Profile picture update unsuccessful: $e";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), duration: snackBarDuration),
        );
      }
    }
  }

  Future<void> updateFoodLogStreak() async {
    final today = DateTime.now();
    final todayKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    if (state.value?.foodLogStreakLastDate == todayKey) return;
    try {
      final streaks = await UserDataManager.fetchStreaks();
      final foodRow = streaks.firstWhere(
        (s) => s['streak_type'] == 'food_streak',
        orElse: () => {},
      );
      patch(
        (u) => u.copyWith(
          foodLogStreak: (foodRow['streak'] as int?) ?? 0,
          foodLogStreakBest: (foodRow['highest_streak'] as int?) ?? 0,
          foodLogStreakLastDate: foodRow['last_date'] as String?,
        ),
      );
    } catch (_) {}
  }
}

final userDataProvider = AsyncNotifierProvider<UserDataNotifierNew, UserData?>(
  UserDataNotifierNew.new,
);

// flips to true once loadUserData completes successfully for the first time
class UserDataLoadedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setLoaded() => state = true;
}

final userDataLoadedProvider = NotifierProvider<UserDataLoadedNotifier, bool>(
  UserDataLoadedNotifier.new,
);
