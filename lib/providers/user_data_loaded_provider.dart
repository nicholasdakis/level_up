import 'package:flutter_riverpod/flutter_riverpod.dart';

// flips to true once loadUserData completes successfully for the first time
class UserDataLoadedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setLoaded() => state = true;
}

final userDataLoadedProvider = NotifierProvider<UserDataLoadedNotifier, bool>(
  UserDataLoadedNotifier.new,
);
