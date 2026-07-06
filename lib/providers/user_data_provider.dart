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

  // applies a copyWith patch from a domain controller, e.g. AppColorController
  void patch(UserData Function(UserData current) updater) {
    final current = state.value;
    if (current != null) state = AsyncData(updater(current));
  }

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

  // optimistic color update with rollback on backend failure
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
