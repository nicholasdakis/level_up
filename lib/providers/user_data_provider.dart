import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_data.dart';
import '../globals.dart' show userManager;

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
      if (weightGoalType != null)
        updated = updated.copyWith(weightGoalType: weightGoalType);
      if (selectedUnits != null && selectedUnits != currentUnits)
        updated = updated.copyWith(units: selectedUnits);
      if (currentWeightKg != null && dateKey != null) {
        final wb = Map<String, double>.from(updated.weightByDate)
          ..[dateKey] = currentWeightKg;
        updated = updated.copyWith(weightByDate: wb);
      }
      if (weightKgGoal != null)
        updated = updated.copyWith(weightKgGoal: weightKgGoal);
      if (caloriesGoal != null && caloriesGoal > 0)
        updated = updated.copyWith(caloriesGoal: caloriesGoal);
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

    if (weightGoalType != null)
      userManager.updateWeightGoal(weightGoalType: weightGoalType);
    if (selectedUnits != null && selectedUnits != currentUnits)
      userManager.updateUnits(selectedUnits, context, showFeedback: false);
    if (currentWeightKg != null && dateKey != null)
      userManager.updateWeightLog(dateKey, currentWeightKg);
    if (weightKgGoal != null)
      userManager.updateWeightGoal(weightKgGoal: weightKgGoal);
    if (caloriesGoal != null && caloriesGoal > 0)
      userManager.updateGoals(caloriesGoal: caloriesGoal);
    if (proteinGoal != null && carbsGoal != null && fatGoal != null) {
      userManager.updateGoals(
        proteinGoal: proteinGoal,
        carbsGoal: carbsGoal,
        fatGoal: fatGoal,
      );
    }
    if (username != null)
      userManager.updateUsername(username, context, showFeedback: false);
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
