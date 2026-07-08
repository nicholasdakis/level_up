import 'package:flutter_riverpod/flutter_riverpod.dart';

// flips to true once app init completes, resets on logout or guest exit
class AppReadyNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setReady() => state = true;
  void reset() => state = false;
}

final appReadyProvider = NotifierProvider<AppReadyNotifier, bool>(
  AppReadyNotifier.new,
);
