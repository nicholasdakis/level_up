import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'user_data_provider.dart';
import 'food_logs_provider.dart';
import 'water_logs_provider.dart';
import 'weight_logs_provider.dart';
import 'workout_provider.dart';
import 'friends_provider.dart';

// Single place to invalidate all user-scoped providers on sign out or account switch.
// Add new providers here so sign out never silently skips one.
void invalidateAllProviders(WidgetRef ref) {
  ref.invalidate(userDataProvider);
  ref.read(foodLogsProvider.notifier).clear();
  ref.invalidate(waterLogsProvider);
  ref.invalidate(weightLogsProvider);
  ref.invalidate(workoutProvider);
  ref.invalidate(friendsProvider);
}
